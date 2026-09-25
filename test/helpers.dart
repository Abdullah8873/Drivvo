import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motolog/app.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/geo/map_tile_provider.dart';
import 'package:motolog/core/providers.dart';

/// Fresh in-memory database (seeded with default catalogs) for tests.
///
/// `closeStreamsSynchronously` stops drift from scheduling a zero-length
/// timer when a watched query loses its last listener — otherwise every
/// widget test that watches the database fails with "A Timer is still
/// pending even after the widget tree was disposed".
///
/// [seedDefaults] = false builds a shared account's local copy (no default
/// catalogs), like `AppDatabase.named(..., seedDefaults: false)`.
AppDatabase testDatabase({bool seedDefaults = true}) {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
    seedDefaults: seedDefaults,
  );
}

/// The full app wired to [db] — pump this in widget tests.
///
/// Also swaps in [NoNetworkTileProvider] for any flutter_map `TileLayer`
/// (My places map, the location picker) so pumping a screen with a map never
/// makes a real HTTP request — see `map_tile_provider.dart`.
Widget testApp(AppDatabase db) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(db),
    mapTileProviderProvider.overrideWithValue(NoNetworkTileProvider()),
  ],
  child: const MotoLogApp(),
);

/// Inserts a vehicle and returns its id.
Future<String> addTestVehicle(AppDatabase db, {String name = 'Honda'}) async {
  final v = await db
      .into(db.vehicles)
      .insertReturning(
        VehiclesCompanion.insert(name: name, type: VehicleType.motorcycle),
      );
  return v.id;
}

/// Call at the end of widget tests that show database data: unmounts the app
/// and lets drift's stream-cleanup timers fire, avoiding
/// "A Timer is still pending even after the widget tree was disposed".
Future<void> unmountApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}
