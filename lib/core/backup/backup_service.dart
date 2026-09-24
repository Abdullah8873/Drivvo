import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../sync/sync_engine.dart';
import 'backup_format.dart';

/// Encodes `DateTime` columns as ISO-8601 strings (with microseconds)
/// instead of drift's default millisecond unix timestamp, so a backup
/// round-trips `createdAt`/`updatedAt` down to the microsecond — the
/// default would silently truncate them, which is exactly the kind of
/// "quietly alters a stored value" bug this feature exists to avoid.
const _serializer = ValueSerializer.defaults(
  serializeDateTimeValuesAsString: true,
);

/// Builds and restores the JSON backup file described in
/// [BackupFormat]'s doc comment — think "export the whole Prisma database
/// to a JSON seed file, and load it back".
///
/// Stateless: every method takes the [AppDatabase] to work on, so it needs
/// no Riverpod provider of its own and is trivial to unit test against an
/// in-memory database.
class BackupService {
  const BackupService();

  /// Builds the backup JSON as UTF-8 bytes, ready to hand to a [FileSharer].
  Future<Uint8List> createBackupBytes(AppDatabase db) async {
    final tables = <String, List<Map<String, dynamic>>>{
      BackupFormat.tableVehicles: [
        for (final r in await db.select(db.vehicles).get())
          r.toJson(serializer: _serializer),
      ],
      BackupFormat.tableCatalogItems: [
        for (final r in await db.select(db.catalogItems).get())
          r.toJson(serializer: _serializer),
      ],
      BackupFormat.tableRefuelings: [
        for (final r in await db.select(db.refuelings).get())
          r.toJson(serializer: _serializer),
      ],
      BackupFormat.tableRefuelingFuels: [
        for (final r in await db.select(db.refuelingFuels).get())
          r.toJson(serializer: _serializer),
      ],
      BackupFormat.tableEntries: [
        for (final r in await db.select(db.entries).get())
          r.toJson(serializer: _serializer),
      ],
      BackupFormat.tableEntryItems: [
        for (final r in await db.select(db.entryItems).get())
          r.toJson(serializer: _serializer),
      ],
      BackupFormat.tableRoutes: [
        for (final r in await db.select(db.routes).get())
          r.toJson(serializer: _serializer),
      ],
      BackupFormat.tableReadings: [
        for (final r in await db.select(db.readings).get())
          r.toJson(serializer: _serializer),
      ],
      BackupFormat.tableReminders: [
        for (final r in await db.select(db.reminders).get())
          r.toJson(serializer: _serializer),
      ],
      BackupFormat.tableSettings: [
        for (final r in await db.select(db.settingsEntries).get())
          // Sync progress is device state, not a user setting.
          if (r.key != SyncEngine.stateKey) r.toJson(serializer: _serializer),
      ],
    };
    final json = {
      'app': BackupFormat.appName,
      'format': BackupFormat.currentFormat,
      'schemaVersion': db.schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'tables': tables,
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(json)));
  }

  /// `motolog-backup-<yyyyMMdd-HHmm>.json`, using the local time of [when]
  /// (defaults to now).
  String backupFilename([DateTime? when]) {
    final d = when ?? DateTime.now();
    String p2(int n) => n.toString().padLeft(2, '0');
    return 'motolog-backup-${d.year}${p2(d.month)}${p2(d.day)}-'
        '${p2(d.hour)}${p2(d.minute)}.json';
  }

  /// Parses and validates a backup file's bytes. Throws
  /// [BackupFormatException] for anything that isn't a readable MotoLog
  /// backup, or whose `schemaVersion` is newer than [currentSchemaVersion]
  /// (see the compatibility rule in [BackupFormat]'s doc comment). On
  /// success, returns the decoded JSON so the caller can show a
  /// [BackupSummary] and, on confirmation, pass it to [restore].
  Map<String, dynamic> parseAndValidate(
    Uint8List bytes,
    int currentSchemaVersion,
  ) {
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const BackupFormatException(
        'This file could not be read. Choose a MotoLog backup (.json) file.',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const BackupFormatException('This is not a MotoLog backup file.');
    }
    if (decoded['app'] != BackupFormat.appName) {
      throw const BackupFormatException('This is not a MotoLog backup file.');
    }
    if (decoded['format'] != BackupFormat.currentFormat) {
      throw const BackupFormatException(
        'This backup file uses an unsupported format.',
      );
    }
    final schemaVersion = decoded['schemaVersion'];
    if (schemaVersion is! int) {
      throw const BackupFormatException('This backup file is corrupted.');
    }
    if (schemaVersion > currentSchemaVersion) {
      throw const BackupFormatException(
        'This backup was made with a newer version of MotoLog. '
        'Update the app before restoring it.',
      );
    }
    if (decoded['tables'] is! Map<String, dynamic>) {
      throw const BackupFormatException('This backup file is corrupted.');
    }
    return decoded;
  }

  /// Summarizes an already-[parseAndValidate]d backup for the "this
  /// replaces all data" confirm dialog.
  BackupSummary summarize(Map<String, dynamic> backup) {
    final tables = backup['tables'] as Map<String, dynamic>;
    int liveCount(String table) =>
        _rowsOf(tables, table).where((r) => r['deletedAt'] == null).length;
    return BackupSummary(
      exportedAt: DateTime.parse(backup['exportedAt'] as String).toLocal(),
      schemaVersion: backup['schemaVersion'] as int,
      vehicleCount: liveCount(BackupFormat.tableVehicles),
      recordCount:
          liveCount(BackupFormat.tableRefuelings) +
          liveCount(BackupFormat.tableEntries) +
          liveCount(BackupFormat.tableRoutes) +
          liveCount(BackupFormat.tableReadings) +
          liveCount(BackupFormat.tableReminders),
    );
  }

  /// Replaces every MotoLog table's contents with [backup] in one
  /// transaction (already validated by [parseAndValidate]).
  ///
  /// Sync-safety rules (a future Supabase sync relies on `updatedAt`/
  /// `deletedAt`, last-write-wins):
  /// - Every restored row's `updatedAt` is bumped to now, so sync treats it
  ///   as the latest version — including rows the backup itself already
  ///   marked `deletedAt` (they stay deleted, just freshly so).
  /// - A row that exists on this device but not in the backup is
  ///   soft-deleted (`deletedAt`/`updatedAt` = now), never hard-deleted —
  ///   sync still needs to propagate that removal to other devices.
  /// - `settings` has no sync columns; it's simply replaced.
  Future<void> restore(AppDatabase db, Map<String, dynamic> backup) async {
    final tables = backup['tables'] as Map<String, dynamic>;
    final now = DateTime.now();

    await db.transaction(() async {
      final vehicleIds = await _restoreTable(
        db,
        db.vehicles,
        _rowsOf(tables, BackupFormat.tableVehicles),
        (j) => Vehicle.fromJson(j, serializer: _serializer),
        (r) => r.id,
        now,
      );
      final catalogIds = await _restoreTable(
        db,
        db.catalogItems,
        _rowsOf(tables, BackupFormat.tableCatalogItems),
        (j) => CatalogItem.fromJson(j, serializer: _serializer),
        (r) => r.id,
        now,
      );
      final refuelingIds = await _restoreTable(
        db,
        db.refuelings,
        _rowsOf(tables, BackupFormat.tableRefuelings),
        (j) => Refueling.fromJson(j, serializer: _serializer),
        (r) => r.id,
        now,
      );
      final refuelingFuelIds = await _restoreTable(
        db,
        db.refuelingFuels,
        _rowsOf(tables, BackupFormat.tableRefuelingFuels),
        (j) => RefuelingFuel.fromJson(j, serializer: _serializer),
        (r) => r.id,
        now,
      );
      final entryIds = await _restoreTable(
        db,
        db.entries,
        _rowsOf(tables, BackupFormat.tableEntries),
        (j) => Entry.fromJson(j, serializer: _serializer),
        (r) => r.id,
        now,
      );
      final entryItemIds = await _restoreTable(
        db,
        db.entryItems,
        _rowsOf(tables, BackupFormat.tableEntryItems),
        (j) => EntryItem.fromJson(j, serializer: _serializer),
        (r) => r.id,
        now,
      );
      final routeIds = await _restoreTable(
        db,
        db.routes,
        _rowsOf(tables, BackupFormat.tableRoutes),
        (j) => Route.fromJson(j, serializer: _serializer),
        (r) => r.id,
        now,
      );
      final readingIds = await _restoreTable(
        db,
        db.readings,
        _rowsOf(tables, BackupFormat.tableReadings),
        (j) => Reading.fromJson(j, serializer: _serializer),
        (r) => r.id,
        now,
      );
      final reminderIds = await _restoreTable(
        db,
        db.reminders,
        _rowsOf(tables, BackupFormat.tableReminders),
        (j) => Reminder.fromJson(j, serializer: _serializer),
        (r) => r.id,
        now,
      );

      // Rows on the device that aren't in the backup: soft-delete, never
      // hard-delete (see the doc comment above).
      await _softDeleteMissing(db, db.vehicles, vehicleIds, now);
      await _softDeleteMissing(db, db.catalogItems, catalogIds, now);
      await _softDeleteMissing(db, db.refuelings, refuelingIds, now);
      await _softDeleteMissing(db, db.refuelingFuels, refuelingFuelIds, now);
      await _softDeleteMissing(db, db.entries, entryIds, now);
      await _softDeleteMissing(db, db.entryItems, entryItemIds, now);
      await _softDeleteMissing(db, db.routes, routeIds, now);
      await _softDeleteMissing(db, db.readings, readingIds, now);
      await _softDeleteMissing(db, db.reminders, reminderIds, now);

      // Settings have no sync columns: just replace them wholesale — except
      // this device's sync progress, which stays as it is (restored rows
      // are queued for upload by the sync outbox triggers anyway).
      await (db.delete(
        db.settingsEntries,
      )..where((s) => s.key.equals(SyncEngine.stateKey).not())).go();
      for (final row in _rowsOf(tables, BackupFormat.tableSettings)) {
        final entry = SettingsEntry.fromJson(row);
        if (entry.key == SyncEngine.stateKey) continue;
        await db
            .into(db.settingsEntries)
            .insert(entry.toCompanion(false), mode: InsertMode.insertOrReplace);
      }
    });
  }

  static List<Map<String, dynamic>> _rowsOf(
    Map<String, dynamic> tables,
    String table,
  ) {
    final list = tables[table];
    if (list is! List) return const [];
    return [for (final r in list) Map<String, dynamic>.from(r as Map)];
  }

  /// Inserts/replaces every row of one synced table from its backup JSON,
  /// stamping `updatedAt = now` on each, and returns the set of ids that
  /// are now in the backup (used to soft-delete the rest).
  ///
  /// Built on `Insertable.toColumns` (raw sql column name -> `Variable`) so
  /// it works generically for every table without needing that table's
  /// specific Companion type — `customInsert` maps each `Variable` to SQL
  /// the same way a typed `into(table).insert(...)` would (correct types
  /// for bools/enums/dates), and its `updates:` set tells drift's streams
  /// to re-run, exactly like a typed write would.
  Future<Set<String>> _restoreTable<D extends Object, T extends Table>(
    AppDatabase db,
    TableInfo<T, D> table,
    List<Map<String, dynamic>> rows,
    D Function(Map<String, dynamic>) fromJson,
    String Function(D row) idOf,
    DateTime now,
  ) async {
    final ids = <String>{};
    for (final json in rows) {
      final row = fromJson(json);
      ids.add(idOf(row));
      final columns = (row as Insertable<D>).toColumns(false);
      columns['updated_at'] = Variable.withDateTime(now);
      await db.customInsert(
        _upsertSql(table.actualTableName, columns.keys),
        variables: columns.values.cast<Variable>().toList(),
        updates: {table},
      );
    }
    return ids;
  }

  /// `INSERT OR REPLACE INTO t (a, b) VALUES (?, ?)` for the given column
  /// names (already the raw sql column names `toColumns` returns).
  String _upsertSql(String table, Iterable<String> columns) {
    final cols = columns.join(', ');
    final placeholders = List.filled(columns.length, '?').join(', ');
    return 'INSERT OR REPLACE INTO $table ($cols) VALUES ($placeholders)';
  }

  /// Soft-deletes every non-deleted row of [table] whose id is not in
  /// [keepIds] (raw SQL by table name, the same approach
  /// `AppDatabase._dedupeCatalogs` uses, generic over every synced table).
  Future<void> _softDeleteMissing<D extends Object, T extends Table>(
    AppDatabase db,
    TableInfo<T, D> table,
    Set<String> keepIds,
    DateTime now,
  ) async {
    final placeholders = List.generate(
      keepIds.length,
      (i) => '?${i + 2}',
    ).join(', ');
    final notIn = keepIds.isEmpty ? '' : 'AND id NOT IN ($placeholders)';
    await db.customUpdate(
      'UPDATE ${table.actualTableName} SET deleted_at = ?1, updated_at = ?1 '
      'WHERE deleted_at IS NULL $notIn',
      variables: [
        Variable.withDateTime(now),
        ...keepIds.map(Variable.withString),
      ],
      updateKind: UpdateKind.update,
      updates: {table},
    );
  }
}
