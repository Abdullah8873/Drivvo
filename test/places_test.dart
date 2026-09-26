import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/geo/map_tile_provider.dart';
import 'package:motolog/core/widgets/module_form_scaffold.dart';
import 'package:motolog/features/catalog/catalog_queries.dart';
import 'package:motolog/features/places/location_picker_screen.dart';

import 'catalog_test_utils.dart';
import 'helpers.dart';

/// Pushes [LocationPickerScreen] with [initial], taps the map's center (so
/// the resulting `LatLng` is deterministic — see [MapOptions.initialCenter]),
/// then confirms. Returns the picked point, or null if never confirmed.
Future<LatLng?> pickViaCenterTap(WidgetTester tester, {LatLng? initial}) async {
  LatLng? result;
  var opened = false;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapTileProviderProvider.overrideWithValue(NoNetworkTileProvider()),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.of(context).push<LatLng>(
                MaterialPageRoute(
                  builder: (_) => LocationPickerScreen(initial: initial),
                ),
              );
              opened = true;
            },
            child: const Text('open picker'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open picker'));
  await tester.pumpAndSettle();

  // Disabled before anything is picked: tapping it does nothing.
  final confirm = find.widgetWithIcon(IconButton, Icons.check);
  await tester.tap(confirm);
  await tester.pumpAndSettle();
  expect(opened, isFalse);

  await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
  // flutter_map's tap recognizer waits out the double-tap window before
  // firing `onTap` (to rule out a double-tap-to-zoom); `pumpAndSettle`
  // alone can miss that since a bare Timer without a scheduled frame
  // doesn't count as "unsettled".
  await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
  await tester.pumpAndSettle();

  await tester.tap(confirm);
  await tester.pumpAndSettle();
  expect(opened, isTrue);
  return result;
}

void main() {
  testWidgets('My places list shows items with a "No location" hint', (
    tester,
  ) async {
    // "My places" is near the bottom of the More list — a tall viewport
    // keeps it (and the section headers below it) actually built, the same
    // trick `openFromMore` uses (see test/catalog_test_utils.dart): a plain
    // `ListView` still virtualizes off-screen children.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = testDatabase();
    await db.addCatalogItem(
      kind: CatalogKind.place,
      name: 'Home',
      address: 'My street',
    );
    await db.addCatalogItem(
      kind: CatalogKind.gasStation,
      name: 'Shell',
      address: 'Main Rd',
      latitude: 24.9,
      longitude: 67.0,
    );
    await tester.pumpWidget(testApp(db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My places'));
    await tester.pumpAndSettle();

    expect(find.text('LIST'), findsOneWidget);
    expect(find.text('MAP'), findsOneWidget);
    expect(find.text('Gas stations'), findsOneWidget);
    expect(find.text('Places'), findsOneWidget);
    expect(find.text('Shell'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('My street'), findsOneWidget);
    // Only "Home" lacks coordinates.
    expect(find.text('No location'), findsOneWidget);

    // Tapping a row opens the same edit form as More → Places.
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Place'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Name'), findsOneWidget);

    await closeApp(tester, db);
  });

  testWidgets('the MAP tab shows a marker for the located item', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = testDatabase();
    await db.addCatalogItem(
      kind: CatalogKind.gasStation,
      name: 'Shell',
      latitude: 24.9,
      longitude: 67.0,
    );
    await tester.pumpWidget(testApp(db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My places'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MAP'));
    await tester.pumpAndSettle();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.textContaining('OpenStreetMap'), findsOneWidget);
    expect(find.byIcon(Icons.my_location), findsOneWidget);
    expect(find.byIcon(Icons.ev_station), findsOneWidget); // the marker

    await tester.tap(find.byIcon(Icons.ev_station));
    await tester.pumpAndSettle();
    expect(find.text('Shell'), findsOneWidget);
    expect(find.text('EDIT'), findsOneWidget);

    await closeApp(tester, db);
  });

  testWidgets('the location picker returns the tapped coordinates', (
    tester,
  ) async {
    final picked = await pickViaCenterTap(tester);
    expect(picked, isNotNull);
    // Tapping dead-center of the map maps back to `initialCenter`
    // regardless of zoom.
    expect(picked!.latitude, closeTo(20, 0.5));
    expect(picked.longitude, closeTo(0, 0.5));
  });

  testWidgets('the catalog form saves the picked location', (tester) async {
    final db = await openFromMore(tester, 'Gas stations');
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Shell Blue Area',
    );

    await tester.tap(find.widgetWithText(PickerField, 'Not set'));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    // See the comment in `pickViaCenterTap` above about this extra pump.
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Confirm'));
    await tester.pumpAndSettle();

    // Back on the form: the field no longer reads "Not set" and a clear
    // button appeared.
    expect(find.widgetWithText(PickerField, 'Not set'), findsNothing);
    expect(find.byTooltip('Clear location'), findsOneWidget);

    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    final rows = await (db.select(
      db.catalogItems,
    )..where((c) => c.kind.equalsValue(CatalogKind.gasStation))).get();
    final saved = rows.single;
    expect(saved.latitude, isNotNull);
    expect(saved.longitude, isNotNull);
    expect(saved.latitude, closeTo(20, 0.5));
    expect(saved.longitude, closeTo(0, 0.5));

    await closeApp(tester, db);
  });
}
