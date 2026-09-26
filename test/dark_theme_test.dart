import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/app.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/geo/map_tile_provider.dart';
import 'package:motolog/core/providers.dart';
import 'package:motolog/core/settings/app_settings.dart';

import 'catalog_test_utils.dart' show closeApp;
import 'helpers.dart';

/// The full app wired to [db], forced into dark mode via
/// `initialSettingsProvider` — the same seam `main.dart` uses to load
/// settings before the first build (see `core/providers.dart`). Also
/// overrides the map tile provider like `testApp` does, in case a pumped
/// screen reaches My places / the location picker.
///
/// [selectedVehicleId] is folded into the same override (rather than
/// written to the database separately) since `initialSettingsProvider`
/// replaces whatever `loadSettings` would otherwise have read.
Widget darkTestApp(AppDatabase db, {String? selectedVehicleId}) =>
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialSettingsProvider.overrideWithValue(
          AppSettings(
            themeMode: ThemeMode.dark,
            selectedVehicleId: selectedVehicleId,
          ),
        ),
        mapTileProviderProvider.overrideWithValue(NoNetworkTileProvider()),
      ],
      child: const MotoLogApp(),
    );

/// The outermost `Scaffold`'s resolved background — `Scaffold.backgroundColor`
/// is usually left null (falling back to the theme), so read it the same way
/// Flutter does at paint time: via the ambient `Theme`.
Color scaffoldBackground(WidgetTester tester) {
  final scaffold = find.byType(Scaffold).first;
  final color = tester.widget<Scaffold>(scaffold).backgroundColor;
  return color ?? Theme.of(tester.element(scaffold)).scaffoldBackgroundColor;
}

void main() {
  testWidgets('main tabs build in dark mode with a dark scaffold', (
    tester,
  ) async {
    final db = testDatabase();
    await tester.pumpWidget(darkTestApp(db));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    for (final tab in ['History', 'Reports', 'Reminders', 'More']) {
      expect(find.text(tab), findsOneWidget);
    }
    // A real dark background, not the light theme's near-white default.
    expect(scaffoldBackground(tester).computeLuminance(), lessThan(0.5));

    await closeApp(tester, db);
  });

  testWidgets('a record form builds in dark mode', (tester) async {
    final db = testDatabase();
    await tester.pumpWidget(darkTestApp(db));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refueling'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Are you filling up the tank?'), findsOneWidget);
    // The form's own Scaffold (ModuleFormScaffold) is module-colored in its
    // app bar, but its body still sits on the dark theme's scaffold color.
    expect(scaffoldBackground(tester).computeLuminance(), lessThan(0.5));

    await closeApp(tester, db);
  });

  testWidgets('the Reports tab builds in dark mode', (tester) async {
    final db = testDatabase();
    final vehicleId = await addTestVehicle(db);
    await tester.pumpWidget(darkTestApp(db, selectedVehicleId: vehicleId));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(scaffoldBackground(tester).computeLuminance(), lessThan(0.5));

    await closeApp(tester, db);
  });
}
