import 'dart:convert';

import 'package:drift/drift.dart' show InsertMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/app_database.dart';
import 'format/formatters.dart';
import 'settings/app_settings.dart';

/// Shared Riverpod providers — think "global stores / React contexts".
/// Read them in widgets with `ref.watch(xxxProvider)` inside a
/// ConsumerWidget (the equivalent of `useContext` / `useQuery`).

/// The database. `main.dart` overrides it with the opened instance; tests
/// override it with an in-memory database.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

/// Settings loaded before `runApp` (overridden in main / tests).
final initialSettingsProvider = Provider<AppSettings>(
  (ref) => const AppSettings(),
);

const _settingsKey = 'app_settings';

Future<AppSettings> loadSettings(AppDatabase db) async {
  final row = await (db.select(
    db.settingsEntries,
  )..where((s) => s.key.equals(_settingsKey))).getSingleOrNull();
  if (row == null) return const AppSettings();
  return AppSettings.fromJson(jsonDecode(row.value) as Map<String, Object?>);
}

/// Current settings. Call `ref.read(settingsProvider.notifier).update(...)`
/// to change them; the change is persisted and every screen rebuilds.
class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(initialSettingsProvider);

  Future<void> update(AppSettings Function(AppSettings s) change) async {
    state = change(state);
    final db = ref.read(databaseProvider);
    await db
        .into(db.settingsEntries)
        .insert(
          SettingsEntriesCompanion.insert(
            key: _settingsKey,
            value: jsonEncode(state.toJson()),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Re-reads settings straight from the database, bypassing the cached
  /// [state]. Unlike [update], this doesn't write anything back — call it
  /// after something *else* changed the `settings_entries` row directly
  /// (a backup restore), so the UI picks up rows it didn't write itself.
  Future<void> reload() async {
    state = await loadSettings(ref.read(databaseProvider));
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

/// Number/date/money formatting that follows the user's settings.
final formattersProvider = Provider<Formatters>(
  (ref) => Formatters(ref.watch(settingsProvider)),
);

// ---- Vehicles ---------------------------------------------------------------

final vehiclesProvider = StreamProvider<List<Vehicle>>(
  (ref) => ref.watch(databaseProvider).watchVehicles(),
);

/// The vehicle shown in the main tabs: the one picked in settings, else the
/// first vehicle, else null (no vehicles yet).
final currentVehicleProvider = Provider<AsyncValue<Vehicle?>>((ref) {
  final selectedId = ref.watch(
    settingsProvider.select((s) => s.selectedVehicleId),
  );
  return ref.watch(vehiclesProvider).whenData((list) {
    if (list.isEmpty) return null;
    return list.where((v) => v.id == selectedId).firstOrNull ?? list.first;
  });
});

/// Switch the vehicle shown in the main tabs.
Future<void> selectVehicle(WidgetRef ref, String vehicleId) {
  return ref
      .read(settingsProvider.notifier)
      .update((s) => s.copyWith(selectedVehicleId: vehicleId));
}

final lastOdometerProvider = StreamProvider.family<double?, String>(
  (ref, vehicleId) => ref.watch(databaseProvider).watchLastOdometer(vehicleId),
);

// ---- Catalogs ---------------------------------------------------------------

final catalogProvider = StreamProvider.family<List<CatalogItem>, CatalogKind>(
  (ref, kind) => ref.watch(databaseProvider).watchCatalog(kind),
);
