/// MotoLog backup file format (JSON) — a full local dump of the database,
/// the offline equivalent of a `pg_dump`/Prisma seed file.
///
/// ```json
/// {
///   "app": "MotoLog",
///   "format": 1,
///   "schemaVersion": 2,
///   "exportedAt": "2026-09-24T10:00:00.000Z",
///   "tables": {
///     "vehicles": [ { "id": "...", "createdAt": 1234, ... }, ... ],
///     "catalog_items": [ ... ],
///     "refuelings": [ ... ],
///     "refueling_fuels": [ ... ],
///     "entries": [ ... ],
///     "entry_items": [ ... ],
///     "routes": [ ... ],
///     "readings": [ ... ],
///     "reminders": [ ... ],
///     "checklist_forms": [ ... ], "checklist_form_items": [ ... ],
///     "checklists": [ ... ], "checklist_answers": [ ... ],
///     "attachments": [ ... ],
///     "attachment_files": [ { "attachmentId": "...", "bytes": "<base64>" } ],
///     "settings": [ { "key": "app_settings", "value": "{...}" }, ... ]
///   }
/// }
/// ```
///
/// Every row (except `settings`) is exactly one drift `DataClass.toJson()`
/// for that table — every column, in its Dart field name, including
/// soft-deleted rows (`deletedAt` set). That's what makes a restore exact:
/// nothing is summarized or reshaped, so `Vehicle.fromJson(row)` on restore
/// reconstructs the row byte-for-byte (like `JSON.parse(JSON.stringify(x))`
/// round-tripping a Prisma record). `settings` rows are the app's own
/// `settings_entries` key/value table (no sync columns). `attachment_files`
/// rows are the local attachment bytes, base64-encoded, so a restore brings
/// photos back even on a device that never synced.
///
/// **Compatibility rule**: `format` is the shape of *this JSON file itself*
/// (bumped only if the top-level structure above changes — a renamed or
/// reshaped key; NEW table keys are additive and don't bump it: an older
/// file simply lacks them and restores as "no rows" for those tables, e.g.
/// a v3 backup without attachments); `schemaVersion` is `AppDatabase.schemaVersion` at
/// export time. A restore is refused when the file's `schemaVersion` is
/// *newer* than the running app's, because an older app has no migration
/// for columns/tables it doesn't know about yet. An equal or older
/// `schemaVersion` is accepted: the drift migration that already runs on
/// every app start (`AppDatabase.migration`) brings the just-restored rows
/// up to the current schema, the same way it does for an old on-disk
/// database file.
class BackupFormat {
  const BackupFormat._();

  static const appName = 'MotoLog';

  /// Bump only when the JSON *shape* above changes, not on every schema
  /// migration (see the compatibility rule in the file doc comment).
  static const currentFormat = 1;

  static const tableVehicles = 'vehicles';
  static const tableCatalogItems = 'catalog_items';
  static const tableRefuelings = 'refuelings';
  static const tableRefuelingFuels = 'refueling_fuels';
  static const tableEntries = 'entries';
  static const tableEntryItems = 'entry_items';
  static const tableRoutes = 'routes';
  static const tableReadings = 'readings';
  static const tableReminders = 'reminders';
  static const tableChecklistForms = 'checklist_forms';
  static const tableChecklistFormItems = 'checklist_form_items';
  static const tableChecklists = 'checklists';
  static const tableChecklistAnswers = 'checklist_answers';
  static const tableAttachments = 'attachments';

  /// Local attachment bytes (not a synced table): see the file doc comment.
  static const tableAttachmentFiles = 'attachment_files';
  static const tableSettings = 'settings';

  /// The synced tables (id/createdAt/updatedAt/deletedAt), parents before
  /// children so a restore can insert them in this order without violating
  /// foreign keys (`PRAGMA foreign_keys = ON`). Does not include
  /// [tableSettings], which has no sync columns and is just replaced.
  static const syncedTablesInRestoreOrder = [
    tableVehicles,
    tableCatalogItems,
    tableRefuelings,
    tableRefuelingFuels,
    tableEntries,
    tableEntryItems,
    tableRoutes,
    tableReadings,
    tableReminders,
    tableChecklistForms,
    tableChecklistFormItems,
    tableChecklists,
    tableChecklistAnswers,
    tableAttachments,
  ];
}

/// Thrown by [BackupService] when a file isn't a MotoLog backup, is
/// corrupted, or was made by a newer app version than this one.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// What a backup file contains, for the "this replaces all data" confirm
/// dialog before [BackupService.restore] runs.
class BackupSummary {
  const BackupSummary({
    required this.exportedAt,
    required this.schemaVersion,
    required this.vehicleCount,
    required this.recordCount,
  });

  final DateTime exportedAt;
  final int schemaVersion;

  /// Non-deleted vehicles in the file.
  final int vehicleCount;

  /// Non-deleted refuelings + entries + routes + readings + reminders +
  /// checklists.
  final int recordCount;
}
