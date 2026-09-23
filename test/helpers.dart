import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motolog/app.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/providers.dart';

/// Fresh in-memory database (seeded with default catalogs) for tests.
AppDatabase testDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

/// The full app wired to [db] — pump this in widget tests.
Widget testApp(AppDatabase db) => ProviderScope(
  overrides: [databaseProvider.overrideWithValue(db)],
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
