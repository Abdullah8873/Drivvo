import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/backup/backup_format.dart';
import 'package:motolog/core/backup/backup_service.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/settings/app_settings.dart';
import 'package:motolog/core/sync/sync_engine.dart';

import 'helpers.dart';
import 'history_fixtures.dart';

Uint8List _bytesOf(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  late AppDatabase db;
  const service = BackupService();

  setUp(() async {
    db = testDatabase();
  });

  tearDown(() => db.close());

  /// Every synced table's live (non-deleted) rows, as JSON, keyed by id —
  /// a snapshot to compare before/after a restore.
  Future<Map<String, Map<String, dynamic>>> snapshot(TableInfo table) async {
    final rows = await db
        .customSelect('SELECT * FROM ${table.actualTableName}')
        .get();
    final out = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      out[row.data['id'] as String] = row.data;
    }
    return out;
  }

  test(
    'round-trip: backup, wipe/modify, restore reproduces every row',
    () async {
      final vid = await addTestVehicle(db, name: 'Honda');
      final refuelId = await addRefuel(
        db,
        vid,
        date: DateTime(2026, 1, 1),
        odometer: 100,
        volume: 5.125,
        price: 293.03,
      );
      // A soft-deleted record: the backup must carry it, and a restore must
      // keep it deleted (not resurrect it).
      final deletedId = await addRefuel(
        db,
        vid,
        date: DateTime(2026, 1, 2),
        odometer: 150,
        volume: 3,
      );
      await (db.update(db.refuelings)..where((r) => r.id.equals(deletedId)))
          .write(RefuelingsCompanion(deletedAt: Value(DateTime.now())));

      await db
          .into(db.settingsEntries)
          .insert(
            SettingsEntriesCompanion.insert(
              key: 'app_settings',
              value: jsonEncode(
                const AppSettings(currencyCode: 'USD').toJson(),
              ),
            ),
            mode: InsertMode.insertOrReplace,
          );

      final beforeRefuelings = await snapshot(db.refuelings);
      final beforeVehicles = await snapshot(db.vehicles);

      final bytes = await service.createBackupBytes(db);

      // Modify the db after the backup: change an existing row, and add one
      // that isn't in the backup at all.
      await (db.update(db.refuelings)..where((r) => r.id.equals(refuelId)))
          .write(const RefuelingsCompanion(totalCost: Value(99999)));
      final extraId = await addRefuel(
        db,
        vid,
        date: DateTime(2026, 3, 1),
        odometer: 999,
        volume: 1,
      );
      await db
          .into(db.settingsEntries)
          .insert(
            SettingsEntriesCompanion.insert(
              key: 'app_settings',
              value: jsonEncode(
                const AppSettings(currencyCode: 'EUR').toJson(),
              ),
            ),
            mode: InsertMode.insertOrReplace,
          );

      final restoreStart = DateTime.now();
      final json = service.parseAndValidate(bytes, db.schemaVersion);
      await service.restore(db, json);

      // Every original row is back, byte-for-byte except `updated_at`.
      final afterRefuelings = await snapshot(db.refuelings);
      final afterVehicles = await snapshot(db.vehicles);
      for (final id in beforeRefuelings.keys) {
        final before = Map<String, dynamic>.from(beforeRefuelings[id]!)
          ..remove('updated_at');
        final after = Map<String, dynamic>.from(afterRefuelings[id]!)
          ..remove('updated_at');
        expect(after, before, reason: 'refueling $id');
      }
      for (final id in beforeVehicles.keys) {
        final before = Map<String, dynamic>.from(beforeVehicles[id]!)
          ..remove('updated_at');
        final after = Map<String, dynamic>.from(afterVehicles[id]!)
          ..remove('updated_at');
        expect(after, before, reason: 'vehicle $id');
      }

      // The soft-deleted refueling is still soft-deleted, not resurrected.
      final restoredDeleted = await (db.select(
        db.refuelings,
      )..where((r) => r.id.equals(deletedId))).getSingle();
      expect(restoredDeleted.deletedAt, isNotNull);

      // The modification made after the backup was overwritten back.
      final restoredRefuel = await (db.select(
        db.refuelings,
      )..where((r) => r.id.equals(refuelId))).getSingle();
      expect(restoredRefuel.totalCost, closeTo(5.125 * 293.03, 0.0001));

      // updatedAt was bumped to (about) now on every restored row.
      expect(
        restoredRefuel.updatedAt.isAfter(restoredDeleted.createdAt),
        isTrue,
      );
      expect(
        restoredRefuel.updatedAt.difference(restoreStart).inSeconds.abs() < 5,
        isTrue,
      );

      // The row created after the backup (never in it) is soft-deleted, not
      // hard-deleted.
      final extra = await (db.select(
        db.refuelings,
      )..where((r) => r.id.equals(extraId))).getSingleOrNull();
      expect(extra, isNotNull);
      expect(extra!.deletedAt, isNotNull);

      // Settings were replaced back to the backup's values.
      final settingsRow = await (db.select(
        db.settingsEntries,
      )..where((s) => s.key.equals('app_settings'))).getSingle();
      final restoredSettings = AppSettings.fromJson(
        jsonDecode(settingsRow.value) as Map<String, dynamic>,
      );
      expect(restoredSettings.currencyCode, 'USD');
    },
  );

  test('rejects a backup with a newer schemaVersion', () async {
    await addTestVehicle(db);
    final bytes = await service.createBackupBytes(db);
    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    json['schemaVersion'] = db.schemaVersion + 1;
    final tampered = _bytesOf(jsonEncode(json));

    expect(
      () => service.parseAndValidate(tampered, db.schemaVersion),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('rejects a malformed file', () {
    expect(
      () => service.parseAndValidate(
        _bytesOf('not json at all'),
        db.schemaVersion,
      ),
      throwsA(isA<BackupFormatException>()),
    );
    expect(
      () => service.parseAndValidate(
        _bytesOf(jsonEncode({'hello': 'world'})),
        db.schemaVersion,
      ),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('rejects a file from a different app', () {
    final json = {
      'app': 'SomeOtherApp',
      'format': BackupFormat.currentFormat,
      'schemaVersion': db.schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': <String, dynamic>{},
    };
    expect(
      () => service.parseAndValidate(
        _bytesOf(jsonEncode(json)),
        db.schemaVersion,
      ),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test(
    'sync progress is neither backed up nor overwritten by a restore',
    () async {
      Future<void> put(String key, String value) => db
          .into(db.settingsEntries)
          .insert(
            SettingsEntriesCompanion.insert(key: key, value: value),
            mode: InsertMode.insertOrReplace,
          );
      Future<String?> get(String key) async => (await (db.select(
        db.settingsEntries,
      )..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

      await put(SyncEngine.stateKey, 'at-backup');
      await put('other', 'from-backup');
      final bytes = await service.createBackupBytes(db);
      expect(utf8.decode(bytes), isNot(contains(SyncEngine.stateKey)));

      await put(SyncEngine.stateKey, 'device-now');
      await put('other', 'changed');
      await service.restore(
        db,
        service.parseAndValidate(bytes, db.schemaVersion),
      );

      expect(await get(SyncEngine.stateKey), 'device-now');
      expect(await get('other'), 'from-backup');
    },
  );
}
