import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/record_module.dart';

/// SQL table name of a module's records — the `attachments.parent_table`
/// value. Reminders can't carry attachments (null).
String? attachmentParentTable(RecordModule module) => switch (module) {
  RecordModule.refueling => 'refuelings',
  RecordModule.expense ||
  RecordModule.service ||
  RecordModule.income => 'entries',
  RecordModule.route => 'routes',
  RecordModule.reading => 'readings',
  RecordModule.checklist => 'checklists',
  RecordModule.reminder => null,
};

/// A file picked in a form but not saved yet (bytes held in memory).
class PendingAttachment {
  const PendingAttachment({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });

  final String fileName;
  final String mimeType;
  final Uint8List bytes;
}

/// One row of a form's attachment list: either an already-saved
/// [Attachment] ([saved]) or a [PendingAttachment] ([pending]).
class AttachmentItem {
  const AttachmentItem.saved(Attachment this.saved) : pending = null;
  const AttachmentItem.pending(PendingAttachment this.pending) : saved = null;

  final Attachment? saved;
  final PendingAttachment? pending;

  String get fileName => saved?.fileName ?? pending!.fileName;
  String get mimeType => saved?.mimeType ?? pending!.mimeType;
  int get sizeBytes => saved?.sizeBytes ?? pending!.bytes.length;
  bool get isImage => mimeType.startsWith('image/');
}

/// Attachment usage of one module, for More → Storage.
class ModuleStorage {
  const ModuleStorage({
    required this.module,
    required this.count,
    required this.bytes,
  });

  final RecordModule module;
  final int count;
  final int bytes;
}

/// Totals for More → Storage.
class StorageUsage {
  const StorageUsage({required this.byModule, required this.notUploaded});

  /// Modules that have at least one attachment, largest first.
  final List<ModuleStorage> byModule;

  /// Live attachments with local bytes that aren't in cloud storage yet.
  final int notUploaded;

  int get count => byModule.fold(0, (s, m) => s + m.count);
  int get bytes => byModule.fold(0, (s, m) => s + m.bytes);
}

/// Attachment database queries (see the note on [AppDatabase]).
extension AttachmentQueries on AppDatabase {
  /// Live attachments of one record, oldest first.
  Future<List<Attachment>> getAttachments(
    String parentTable,
    String parentId,
  ) => _attachmentsOf(parentTable, parentId).get();

  Stream<List<Attachment>> watchAttachments(
    String parentTable,
    String parentId,
  ) => _attachmentsOf(parentTable, parentId).watch();

  SimpleSelectStatement<$AttachmentsTable, Attachment> _attachmentsOf(
    String parentTable,
    String parentId,
  ) => select(attachments)
    ..where(
      (a) =>
          a.parentTable.equals(parentTable) &
          a.parentId.equals(parentId) &
          a.deletedAt.isNull(),
    )
    ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]);

  /// Writes a form's attachment changes for the record
  /// ([parentTable], [parentId]): inserts [added] (metadata + local bytes)
  /// and soft-deletes [removedIds] (their bytes go with them, see
  /// `AppDatabase.createAttachmentTriggers`). Call it inside the same
  /// transaction as the record's own save.
  Future<void> applyAttachmentChanges({
    required String parentTable,
    required String parentId,
    required String? vehicleId,
    List<PendingAttachment> added = const [],
    Iterable<String> removedIds = const [],
  }) => transaction(() async {
    final now = DateTime.now();
    final removed = removedIds.toList();
    if (removed.isNotEmpty) {
      await (update(
        attachments,
      )..where((a) => a.id.isIn(removed) & a.deletedAt.isNull())).write(
        AttachmentsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
    }
    for (final (i, p) in added.indexed) {
      final row = await into(attachments).insertReturning(
        AttachmentsCompanion.insert(
          vehicleId: Value(vehicleId),
          parentTable: parentTable,
          parentId: parentId,
          fileName: p.fileName,
          mimeType: p.mimeType,
          sizeBytes: p.bytes.length,
          // Staggered so the list keeps the order the files were added.
          createdAt: Value(now.add(Duration(microseconds: i))),
          updatedAt: Value(now),
        ),
      );
      await into(attachmentFiles).insert(
        AttachmentFilesCompanion.insert(attachmentId: row.id, bytes: p.bytes),
      );
    }
  });

  /// The on-device bytes of an attachment, or null (e.g. synced from
  /// another device and not downloaded yet).
  Future<Uint8List?> localAttachmentBytes(String attachmentId) async =>
      (await (select(attachmentFiles)
                ..where((f) => f.attachmentId.equals(attachmentId)))
              .getSingleOrNull())
          ?.bytes;

  /// Stores downloaded bytes as the local copy.
  Future<void> cacheAttachmentBytes(String attachmentId, Uint8List bytes) =>
      into(attachmentFiles).insert(
        AttachmentFilesCompanion.insert(
          attachmentId: attachmentId,
          bytes: bytes,
        ),
        mode: InsertMode.insertOrReplace,
      );

  /// `"<parentTable>|<parentId>"` of every record with a live attachment —
  /// History's paperclip icons.
  Future<Set<String>> parentsWithAttachments() async {
    final rows = await customSelect(
      'SELECT DISTINCT parent_table, parent_id FROM attachments '
      'WHERE deleted_at IS NULL',
      readsFrom: {attachments},
    ).get();
    return {
      for (final r in rows)
        '${r.read<String>('parent_table')}|${r.read<String>('parent_id')}',
    };
  }

  /// Live attachment usage per module (entries split by kind), for
  /// More → Storage.
  Stream<StorageUsage> watchStorageUsage() {
    return customSelect(
      '''
      SELECT a.parent_table AS parent, e.kind AS kind, COUNT(*) AS n,
        COALESCE(SUM(a.size_bytes), 0) AS size,
        SUM(CASE WHEN a.storage_path IS NULL AND f.attachment_id IS NOT NULL
          THEN 1 ELSE 0 END) AS pending
      FROM attachments a
      LEFT JOIN entries e ON a.parent_table = 'entries' AND e.id = a.parent_id
      LEFT JOIN attachment_files f ON f.attachment_id = a.id
      WHERE a.deleted_at IS NULL
      GROUP BY a.parent_table, e.kind
      ''',
      readsFrom: {attachments, attachmentFiles, entries},
    ).watch().map((rows) {
      final counts = <RecordModule, (int, int)>{};
      var pending = 0;
      for (final r in rows) {
        final module = _moduleOf(
          r.read<String>('parent'),
          r.readNullable<String>('kind'),
        );
        pending += r.read<int>('pending');
        if (module == null) continue;
        final (n, size) = counts[module] ?? (0, 0);
        counts[module] = (n + r.read<int>('n'), size + r.read<int>('size'));
      }
      final list = [
        for (final e in counts.entries)
          ModuleStorage(module: e.key, count: e.value.$1, bytes: e.value.$2),
      ]..sort((a, b) => b.bytes.compareTo(a.bytes));
      return StorageUsage(byModule: list, notUploaded: pending);
    });
  }

  static RecordModule? _moduleOf(String parentTable, String? entryKind) =>
      switch (parentTable) {
        'refuelings' => RecordModule.refueling,
        'routes' => RecordModule.route,
        'readings' => RecordModule.reading,
        'checklists' => RecordModule.checklist,
        'entries' => switch (entryKind) {
          'expense' => RecordModule.expense,
          'service' => RecordModule.service,
          'income' => RecordModule.income,
          _ => null,
        },
        _ => null,
      };
}

/// "1.2 MB", "340 KB", "12 B".
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
