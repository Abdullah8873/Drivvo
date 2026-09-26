import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'remote_file_store.dart';
import 'remote_store.dart';

/// How the signed-in user relates to the data already on this device.
enum AccountMatch {
  /// Nobody has synced on this device yet: local data (made before signing
  /// in) is attached to this account on the first sync.
  firstSignIn,

  /// The same user synced here before: a normal sync.
  sameUser,

  /// Another user synced here before: the app must ask whether to merge
  /// this device's data into the new account or replace it (see
  /// [SyncEngine.adoptAccount]). [SyncEngine.sync] refuses until then.
  differentUser,
}

/// Thrown by [SyncEngine.sync] when [AccountMatch.differentUser] still needs
/// the user's decision.
class SyncAccountMismatch implements Exception {
  const SyncAccountMismatch(this.previousUserId, this.userId);

  final String previousUserId;
  final String userId;

  @override
  String toString() =>
      'This device was last synced with another account; choose whether to '
      'keep or replace its data first.';
}

/// What one [SyncEngine.sync] run did (handy for tests and debugging).
class SyncReport {
  /// Rows received from the server (including already-known ones).
  int pulled = 0;

  /// Received rows that were written to the local database.
  int applied = 0;

  /// Rows uploaded.
  int pushed = 0;

  /// Attachment files uploaded to Storage.
  int filesUploaded = 0;

  /// Attachment files that failed to upload (retried next run).
  int fileUploadFailures = 0;

  /// Storage objects of deleted attachments removed.
  int filesRemoved = 0;

  /// Attachment files copied from another account's folder (a redeemed
  /// transfer) into this account's.
  int filesRehomed = 0;

  /// Local changes the server refused (shared accounts only: the member's
  /// profile doesn't allow them). They were undone on this device.
  int rejected = 0;

  @override
  String toString() =>
      'SyncReport(pulled: $pulled, applied: $applied, pushed: $pushed, '
      'filesUploaded: $filesUploaded, fileUploadFailures: '
      '$fileUploadFailures, filesRemoved: $filesRemoved, '
      'filesRehomed: $filesRehomed, rejected: $rejected)';
}

/// Two-way sync between the local drift database and a [RemoteStore]
/// (Supabase) — the "offline-first" part: the app always reads and writes
/// SQLite, and this class reconciles it with the cloud in the background,
/// like a service worker replaying a queue of offline requests.
///
/// **Upload (push)**: SQLite triggers queue every changed row in
/// `sync_outbox` ([SyncOutbox]); push uploads the queued rows table by table
/// in batches and then removes exactly the queue entries it read. A failed
/// batch leaves its entries queued for the next run. This replaces a
/// "rows with `updatedAt` > last push" cursor, which misses edits made in
/// the same (milli)second as the previous push or after the device clock
/// jumped back.
///
/// **Download (pull)**: per user and per table, a keyset cursor over the
/// server's `server_updated_at` (see [RemoteCursor]) is kept in
/// `settings_entries` under [stateKey]. Each page is applied and its cursor
/// saved in one transaction, so a failed page never advances the cursor. Each
/// run re-reads a small [pullOverlap] window before the cursor: a server row
/// can become visible slightly after a later-stamped one (concurrent
/// transactions), and re-applying known rows is a no-op.
///
/// **Conflicts**: last-write-wins on `updatedAt`. A pulled row replaces the
/// local one only when it is newer, or when the local row is missing;
/// pulled rows keep the server's `updatedAt` (applying them is not an edit).
/// On an exact tie with different data the server's copy wins unless the
/// local row is still queued, in which case it is uploaded and wins there
/// (the server applies equal-timestamp rows that differ) — either way every
/// device converges.
///
/// **Order**: pull first, then push. Pulling first resolves conflicts
/// locally, so a queued row that lost to a newer server row is dropped
/// instead of being uploaded just to be rejected; the local edits that won
/// stay queued and are pushed right after. Parents go before children in
/// both directions: tables are grouped in dependency tiers
/// ([AppDatabase.syncedTableTiers]); the tables of one tier sync in
/// parallel (their network round trips overlap — a pull used to wait for
/// 14 tables one by one), and a tier starts only after the previous one
/// finished. A failed push stops the run before the next tier, so the
/// server never gets a child without its parent.
/// Pulled rows are still applied with SQLite foreign keys off: another
/// device may upload a vehicle and its refueling between our "vehicles" and
/// "refuelings" pulls, and a missing parent must not block sync forever (it
/// arrives next run; reads use joins, so an orphan is simply not shown).
class SyncEngine {
  SyncEngine(
    this.db,
    this.remote, {
    this.pushBatchSize = RemoteStore.maxPushBatch,
    this.pullPageSize = RemoteStore.maxPullPage,
    this.pullOverlap = const Duration(seconds: 30),
    this.files,
    DateTime Function()? clock,
  }) : assert(pushBatchSize > 0 && pushBatchSize <= RemoteStore.maxPushBatch),
       assert(pullPageSize > 0 && pullPageSize <= RemoteStore.maxPullPage),
       _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final RemoteStore remote;
  final int pushBatchSize;
  final int pullPageSize;
  final Duration pullOverlap;

  /// Attachment file storage; null = attachments stay local-only (rows
  /// still sync, the files don't).
  final RemoteFileStore? files;
  final DateTime Function() _clock;

  /// `settings_entries` key holding the sync state as JSON.
  static const stateKey = 'sync_state';

  /// The synced tables, parents first.
  late final List<TableInfo<Table, Object?>> tables = [
    for (final tier in tiers) ...tier,
  ];

  /// [AppDatabase.syncedTableTiers] as drift tables: each tier only depends
  /// on earlier ones, so a tier's tables sync in parallel.
  late final List<List<TableInfo<Table, Object?>>> tiers = [
    for (final tier in AppDatabase.syncedTableTiers)
      [
        for (final name in tier)
          db.allTables.firstWhere((t) => t.actualTableName == name),
      ],
  ];

  // Runs sync / adopt one at a time (a tiny async mutex).
  final _runs = _SerialQueue();

  Future<T> _exclusive<T>(Future<T> Function() body) => _runs.run(body);

  // Applies pulled pages one at a time (see [_pullTable]).
  final _pages = _SerialQueue();

  /// Runs [body] for every table of every tier: the tables of one tier in
  /// parallel (network round trips overlap), tier after tier. A failure
  /// lets the rest of its tier finish, then stops before the next tier
  /// (so children never go without their parents).
  Future<void> _byTier(
    Future<void> Function(TableInfo<Table, Object?> table) body,
  ) async {
    for (final tier in tiers) {
      await Future.wait([for (final table in tier) body(table)]);
    }
  }

  // ---- Public API -----------------------------------------------------------

  /// The user this device last synced with (null = never synced).
  Future<String?> lastSyncedUserId() async => (await _loadState()).lastUserId;

  /// When [userId] last completed a sync on this device.
  Future<DateTime?> lastSyncedAt(String userId) async =>
      (await _loadState()).users[userId]?.lastSyncedAt;

  Future<AccountMatch> checkAccount(String userId) async {
    final last = await lastSyncedUserId();
    if (last == null) return AccountMatch.firstSignIn;
    return last == userId ? AccountMatch.sameUser : AccountMatch.differentUser;
  }

  /// True when local changes are waiting to be uploaded.
  Future<bool> hasPendingChanges() async => await pendingCount() > 0;

  /// Number of rows waiting to be uploaded.
  Future<int> pendingCount() async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS n FROM sync_outbox')
        .getSingle();
    return row.read<int>('n');
  }

  /// Makes [userId] this device's account. With [keepLocalData] every local
  /// row is queued for upload into that account (merged with what it
  /// already holds); otherwise the local synced data is wiped (the default
  /// catalogs are re-seeded) and the account's data is downloaded on the
  /// next [sync]. Either way the pull starts from scratch.
  ///
  /// Wiping loses whatever the previous account hadn't received yet — the
  /// UI must warn about that.
  Future<void> adoptAccount(String userId, {required bool keepLocalData}) =>
      _exclusive(() async {
        final state = await _loadState();
        await _attach(state, userId, keepLocalData: keepLocalData);
      });

  /// Pulls then pushes everything for [userId]. On the very first sync of
  /// this device the local data is attached to the account; when another
  /// user synced here before, throws [SyncAccountMismatch] until
  /// [adoptAccount] is called.
  ///
  /// [userId] is the account's owner: the signed-in user for their own
  /// data, or the owner of a [shared] account the signed-in user joined
  /// (this database is then that account's local copy). In a shared
  /// account, rows the server refuses ([RemotePermissionDenied]) are
  /// undone locally — deleted, and downloaded again if the member may see
  /// them — and counted in [SyncReport.rejected]; in the user's own
  /// account a refusal can't happen legitimately, so it fails the sync.
  Future<SyncReport> sync(String userId, {bool shared = false}) =>
      _exclusive(() async {
        final state = await _loadState();
        final last = state.lastUserId;
        if (last == null) {
          await _attach(state, userId, keepLocalData: true);
        } else if (last != userId) {
          throw SyncAccountMismatch(last, userId);
        }

        final report = SyncReport();
        await _withoutForeignKeys(
          () => _byTier((table) => _pullTable(state, userId, table, report)),
        );
        final rejectedBy = shared ? state : null;
        await _byTier((table) => _pushTable(userId, table, report, rejectedBy));
        if (files case final store?) {
          await _syncFiles(store, userId, report);
          // Rows the file step changed (storage_path set/cleared) go up now
          // rather than on the next run.
          await _pushTable(userId, _attachmentsTable, report, rejectedBy);
        }
        state.user(userId).lastSyncedAt = _clock();
        await _saveState(state);
        return report;
      });

  // ---- Account attach / wipe -----------------------------------------------

  Future<void> _attach(
    _SyncState state,
    String userId, {
    required bool keepLocalData,
  }) async {
    if (keepLocalData) {
      await db.transaction(() async {
        // Files uploaded under another account's folder can't be read by
        // this one: re-upload the ones this device still has.
        await db.customStatement(
          'UPDATE attachments SET storage_path = NULL '
          'WHERE storage_path IS NOT NULL AND substr(storage_path, 1, ?) != ? '
          'AND id IN (SELECT attachment_id FROM attachment_files)',
          [userId.length + 1, '$userId/'],
        );
        await db.customStatement('DELETE FROM sync_outbox');
        for (final name in AppDatabase.syncedTableNames) {
          await db.customStatement(
            'INSERT INTO sync_outbox (target_table, row_id) '
            "SELECT '$name', id FROM $name",
          );
        }
        state.lastUserId = userId;
        state.users[userId] = _UserState();
        await _saveState(state);
      });
      return;
    }
    await _withoutForeignKeys(
      () => db.transaction(() async {
        // Local-only bytes of the attachments being wiped.
        await db.customUpdate(
          'DELETE FROM attachment_files',
          updates: {db.attachmentFiles},
          updateKind: UpdateKind.delete,
        );
        for (final table in tables.reversed) {
          await db.customUpdate(
            'DELETE FROM ${table.actualTableName}',
            updates: {table},
            updateKind: UpdateKind.delete,
          );
        }
        await db.customStatement('DELETE FROM sync_outbox');
        state.lastUserId = userId;
        state.users[userId] = _UserState();
        await _saveState(state);
      }),
    );
    // Never leave the app without pick lists, even if the download fails.
    // Seed rows have shared ids and an old timestamp, so the account's own
    // versions replace them on the next pull.
    if (db.seedDefaults) await db.seedCatalogs();
  }

  // ---- Pull -----------------------------------------------------------------

  Future<void> _pullTable(
    _SyncState state,
    String userId,
    TableInfo table,
    SyncReport report,
  ) async {
    final name = table.actualTableName;
    final user = state.user(userId);
    final saved = user.cursors[name];
    var after = saved == null || pullOverlap == Duration.zero
        ? saved
        : RemoteCursor.at(saved.time.subtract(pullOverlap));
    while (true) {
      final rows = await remote.pull(
        name,
        userId,
        after: after,
        limit: pullPageSize,
      );
      if (rows.isEmpty) return;
      final last = RemoteCursor.lastOf(rows)!;
      // Tables download in parallel but pages are applied one at a time:
      // every page saves the whole state (all cursors), so a page whose
      // transaction fails must have its cursor rolled back in memory
      // before another table's page can save it.
      await _pages.run(() async {
        final previous = user.cursors[name];
        try {
          await db.transaction(() async {
            report.applied += await _applyRows(table, rows);
            if (previous == null || last.compareTo(previous) > 0) {
              user.cursors[name] = last;
            }
            await _saveState(state);
          });
        } catch (_) {
          if (previous == null) {
            user.cursors.remove(name);
          } else {
            user.cursors[name] = previous;
          }
          rethrow;
        }
      });
      report.pulled += rows.length;
      if (rows.length < pullPageSize) return;
      after = last;
    }
  }

  /// Merges one page of server rows into [table]; returns how many were
  /// written. Runs inside a transaction.
  Future<int> _applyRows(TableInfo table, List<RemoteRow> rows) async {
    final name = table.actualTableName;
    final ids = [for (final r in rows) r['id']! as String];
    final local = await _readLocal(table, ids);
    final queued = await _queuedIds(name, ids);
    // Decide every row first, then write in bulk (one prepared statement
    // reused for the whole page instead of 2–3 statements per row).
    final upserts = <Map<String, Object?>>[];
    final unqueue = <String>[];
    final requeue = <String>[];
    for (final raw in rows) {
      final theirs = _decode(table, raw);
      final id = theirs['id']! as String;
      final mine = local[id];
      final int cmp;
      if (mine == null) {
        cmp = 1;
      } else {
        cmp = (theirs['updated_at']! as DateTime).compareTo(
          mine['updated_at']! as DateTime,
        );
      }
      final same = mine != null && cmp == 0 && _sameValues(theirs, mine);
      if (cmp > 0 || (cmp == 0 && !same && !queued.contains(id))) {
        // Remote wins: write it as-is (keeping its updatedAt) and forget any
        // local edit of this row that it superseded.
        upserts.add(theirs);
        unqueue.add(id);
      } else if (same) {
        unqueue.add(id); // nothing left to upload
      } else if (cmp < 0 && !queued.contains(id)) {
        requeue.add(id); // local copy is newer: make sure it goes up
      }
      // Otherwise the local row is newer (or wins the tie) and is already
      // queued: the push below uploads it.
    }
    await _upsertAll(table, upserts);
    // After the upserts: their outbox triggers queued the rows again.
    await _unqueueAll(name, unqueue);
    await _queueAll(name, requeue);
    return upserts.length;
  }

  /// `INSERT … ON CONFLICT(id) DO UPDATE` for every row, in one batch.
  Future<void> _upsertAll(
    TableInfo table,
    List<Map<String, Object?>> rows,
  ) async {
    if (rows.isEmpty) return;
    final sqlByColumns = <String, String>{};
    final update = {TableUpdate.onTable(table, kind: UpdateKind.update)};
    await db.batch((b) {
      for (final values in rows) {
        final cols = values.keys.toList();
        final sql = sqlByColumns.putIfAbsent(cols.join(','), () {
          final names = cols.map((c) => '"$c"').join(', ');
          final set = cols
              .where((c) => c != 'id')
              .map((c) => '"$c" = excluded."$c"')
              .join(', ');
          return 'INSERT INTO ${table.actualTableName} ($names) '
              'VALUES (${_marks(cols.length)}) '
              'ON CONFLICT(id) DO UPDATE SET $set';
        });
        b.customStatement(sql, [
          for (final v in values.values) db.typeMapping.mapToSqlVariable(v),
        ], update);
      }
    });
  }

  // ---- Push -----------------------------------------------------------------

  /// Uploads [table]'s queued rows. With [shared] (the sync state of a
  /// shared account) a refused batch is retried row by row and the refused
  /// rows are rolled back; without it the refusal is rethrown.
  Future<void> _pushTable(
    String userId,
    TableInfo table,
    SyncReport report, [
    _SyncState? shared,
  ]) async {
    final name = table.actualTableName;
    while (true) {
      final queued = await db
          .customSelect(
            'SELECT seq, row_id FROM sync_outbox WHERE target_table = ? '
            'ORDER BY seq LIMIT ?',
            variables: [
              Variable.withString(name),
              Variable.withInt(pushBatchSize),
            ],
          )
          .get();
      if (queued.isEmpty) return;
      final ids = [for (final q in queued) q.read<String>('row_id')];
      final seqs = [for (final q in queued) q.read<int>('seq')];
      final local = await _readLocal(table, ids);
      final payload = [
        for (final id in ids)
          if (local[id] case final row?) _encode(row),
      ];
      // Throws on failure: the entries stay queued for the next run.
      var sent = payload;
      if (payload.isNotEmpty) {
        try {
          await remote.push(name, userId, payload);
        } on RemotePermissionDenied {
          if (shared == null) rethrow;
          final refused = await _pushOneByOne(name, userId, payload);
          await _rollBack(shared, table, refused);
          report.rejected += refused.length;
          sent = [
            for (final r in payload)
              if (!refused.contains(r['id'])) r,
          ];
        }
      }
      // Only the entries we read: a row edited during the upload was
      // re-queued with a newer seq and goes up in the next batch.
      await db.customStatement(
        'DELETE FROM sync_outbox WHERE seq IN (${seqs.join(', ')})',
      );
      report.pushed += sent.length;
      if (queued.length < pushBatchSize) return;
    }
  }

  /// Uploads [rows] one at a time; returns the ids the server refused.
  /// Any other error still fails the run (the rows stay queued).
  Future<Set<String>> _pushOneByOne(
    String table,
    String ownerId,
    List<RemoteRow> rows,
  ) async {
    final refused = <String>{};
    for (final row in rows) {
      try {
        await remote.push(table, ownerId, [row]);
      } on RemotePermissionDenied {
        refused.add(row['id']! as String);
      }
    }
    return refused;
  }

  /// Undoes refused local changes: the rows are deleted on this device
  /// and [table]'s pull restarts from the beginning, so the server's
  /// version (if the member may see one) comes back on the next sync.
  Future<void> _rollBack(
    _SyncState state,
    TableInfo table,
    Set<String> ids,
  ) async {
    if (ids.isEmpty) return;
    final name = table.actualTableName;
    await _withoutForeignKeys(() async {
      for (final chunk in _chunks(ids.toList())) {
        if (name == 'attachments') {
          await db.customStatement(
            'DELETE FROM attachment_files WHERE attachment_id IN '
            '(${_marks(chunk.length)})',
            chunk,
          );
        }
        await db.customUpdate(
          'DELETE FROM $name WHERE id IN (${_marks(chunk.length)})',
          variables: [for (final id in chunk) Variable.withString(id)],
          updates: {table},
          updateKind: UpdateKind.delete,
        );
        await _unqueueAll(name, chunk);
      }
    });
    await _pages.run(() async {
      for (final user in state.users.values) {
        user.cursors.remove(name);
      }
      await _saveState(state);
    });
  }

  // ---- Attachment files -------------------------------------------------------

  TableInfo get _attachmentsTable =>
      tables.firstWhere((t) => t.actualTableName == 'attachments');

  /// The file step, run after the row push:
  /// - every live attachment that has local bytes but no `storage_path` is
  ///   uploaded to `<userId>/<attachmentId>/<fileName>`, then its
  ///   `storage_path` is set (a normal row edit, so it syncs and other
  ///   devices can download the file on demand);
  /// - every deleted attachment that still has a `storage_path` gets its
  ///   object removed and the path cleared.
  ///
  /// - every live attachment whose file sits in *another* account's
  ///   folder and has no local bytes (copied by a redeemed transfer) is
  ///   downloaded and its `storage_path` cleared, so the step above
  ///   uploads it again under this account's folder.
  ///
  /// Best effort: a failed file never fails the sync (the rows are already
  /// safe); it is simply retried on the next run.
  Future<void> _syncFiles(
    RemoteFileStore store,
    String userId,
    SyncReport report,
  ) async {
    await _rehomeFiles(store, userId, report);
    final pending = await db
        .customSelect(
          'SELECT a.id, a.file_name, a.mime_type FROM attachments a '
          'JOIN attachment_files f ON f.attachment_id = a.id '
          'WHERE a.deleted_at IS NULL AND a.storage_path IS NULL',
          readsFrom: {db.attachments, db.attachmentFiles},
        )
        .get();
    for (final row in pending) {
      final id = row.read<String>('id');
      final bytes = await (db.select(
        db.attachmentFiles,
      )..where((f) => f.attachmentId.equals(id))).getSingleOrNull();
      if (bytes == null) continue; // deleted meanwhile
      final path = RemoteFileStore.pathFor(
        userId,
        id,
        row.read<String>('file_name'),
      );
      try {
        await store.upload(
          path,
          bytes.bytes,
          mimeType: row.read<String>('mime_type'),
        );
      } catch (_) {
        report.fileUploadFailures++;
        continue;
      }
      await (db.update(
        db.attachments,
      )..where((a) => a.id.equals(id) & a.storagePath.isNull())).write(
        AttachmentsCompanion(
          storagePath: Value(path),
          updatedAt: Value(_clock()),
        ),
      );
      report.filesUploaded++;
    }

    final deleted = await (db.select(
      db.attachments,
    )..where((a) => a.deletedAt.isNotNull() & a.storagePath.isNotNull())).get();
    if (deleted.isEmpty) return;
    try {
      await store.remove([for (final a in deleted) a.storagePath!]);
    } catch (_) {
      return; // retried next run
    }
    for (final a in deleted) {
      await (db.update(db.attachments)..where(
            (r) => r.id.equals(a.id) & r.storagePath.equals(a.storagePath!),
          ))
          .write(
            AttachmentsCompanion(
              storagePath: const Value(null),
              updatedAt: Value(_clock()),
            ),
          );
    }
    report.filesRemoved += deleted.length;
  }

  Future<void> _rehomeFiles(
    RemoteFileStore store,
    String userId,
    SyncReport report,
  ) async {
    final foreign = await db
        .customSelect(
          'SELECT a.id, a.storage_path FROM attachments a '
          'WHERE a.deleted_at IS NULL AND a.storage_path IS NOT NULL '
          'AND substr(a.storage_path, 1, ?) != ? '
          'AND a.id NOT IN (SELECT attachment_id FROM attachment_files)',
          variables: [
            Variable.withInt(userId.length + 1),
            Variable.withString('$userId/'),
          ],
          readsFrom: {db.attachments, db.attachmentFiles},
        )
        .get();
    for (final row in foreign) {
      final id = row.read<String>('id');
      final path = row.read<String>('storage_path');
      final Uint8List bytes;
      try {
        bytes = await store.download(path);
      } catch (_) {
        continue; // not readable (yet): retried next run
      }
      await db.transaction(() async {
        await db
            .into(db.attachmentFiles)
            .insert(
              AttachmentFilesCompanion.insert(attachmentId: id, bytes: bytes),
              mode: InsertMode.insertOrReplace,
            );
        await (db.update(
          db.attachments,
        )..where((a) => a.id.equals(id) & a.storagePath.equals(path))).write(
          AttachmentsCompanion(
            storagePath: const Value(null),
            updatedAt: Value(_clock()),
          ),
        );
      });
      report.filesRehomed++;
    }
  }

  // ---- Outbox helpers --------------------------------------------------------

  Future<Set<String>> _queuedIds(String table, List<String> ids) async {
    final result = <String>{};
    for (final chunk in _chunks(ids)) {
      final rows = await db
          .customSelect(
            'SELECT row_id FROM sync_outbox WHERE target_table = ? '
            'AND row_id IN (${_marks(chunk.length)})',
            variables: [
              Variable.withString(table),
              for (final id in chunk) Variable.withString(id),
            ],
          )
          .get();
      result.addAll(rows.map((r) => r.read<String>('row_id')));
    }
    return result;
  }

  Future<void> _unqueueAll(String table, List<String> ids) async {
    for (final chunk in _chunks(ids)) {
      await db.customStatement(
        'DELETE FROM sync_outbox WHERE target_table = ? '
        'AND row_id IN (${_marks(chunk.length)})',
        [table, ...chunk],
      );
    }
  }

  /// Queues [ids] at the end of the outbox (a fresh `seq`).
  Future<void> _queueAll(String table, List<String> ids) async {
    if (ids.isEmpty) return;
    await _unqueueAll(table, ids);
    await db.batch((b) {
      for (final id in ids) {
        b.customStatement(
          'INSERT INTO sync_outbox (target_table, row_id) VALUES (?, ?)',
          [table, id],
        );
      }
    });
  }

  // ---- Row conversion -------------------------------------------------------

  /// Local rows by id, as `column name → Dart value` (DateTime, bool, …).
  Future<Map<String, Map<String, Object?>>> _readLocal(
    TableInfo table,
    List<String> ids,
  ) async {
    final result = <String, Map<String, Object?>>{};
    for (final chunk in _chunks(ids)) {
      final rows = await db
          .customSelect(
            'SELECT * FROM ${table.actualTableName} '
            'WHERE id IN (${_marks(chunk.length)})',
            variables: [for (final id in chunk) Variable.withString(id)],
            readsFrom: {table},
          )
          .get();
      for (final row in rows) {
        final values = {
          for (final c in table.$columns)
            c.$name: db.typeMapping.read(c.type, row.data[c.$name]),
        };
        result[values['id']! as String] = values;
      }
    }
    return result;
  }

  /// Local Dart values → JSON for the server (timestamps in UTC).
  static RemoteRow _encode(Map<String, Object?> values) => {
    for (final MapEntry(:key, :value) in values.entries)
      key: value is DateTime ? value.toUtc().toIso8601String() : value,
  };

  /// Server JSON → local Dart values, for the columns this app knows (the
  /// server's `owner_id` / `server_updated_at` are dropped). Timestamps are
  /// converted to local time so they are stored exactly like local edits
  /// (drift stores them as text with the UTC offset, and some queries sort
  /// that text).
  static Map<String, Object?> _decode(TableInfo table, RemoteRow raw) {
    final out = <String, Object?>{};
    for (final c in table.$columns) {
      if (!raw.containsKey(c.$name)) continue;
      out[c.$name] = _fromJson(c.type, raw[c.$name]);
    }
    return out;
  }

  static Object? _fromJson(Object type, Object? v) {
    if (v == null) return null;
    if (type == DriftSqlType.dateTime) {
      return DateTime.parse(v as String).toLocal();
    }
    if (type == DriftSqlType.bool) {
      return v is bool ? v : (v == 1 || v == 'true');
    }
    if (type == DriftSqlType.int) return (v as num).toInt();
    if (type == DriftSqlType.double) return (v as num).toDouble();
    if (type == DriftSqlType.string) return v.toString();
    return v;
  }

  /// Same values for every column the server sent.
  static bool _sameValues(
    Map<String, Object?> theirs,
    Map<String, Object?> mine,
  ) {
    for (final MapEntry(:key, :value) in theirs.entries) {
      final other = mine[key];
      if (value is DateTime && other is DateTime) {
        if (!value.isAtSameMomentAs(other)) return false;
      } else if (value != other) {
        return false;
      }
    }
    return true;
  }

  static Iterable<List<String>> _chunks(List<String> ids) sync* {
    const size = 500; // well under SQLite's bound-variable limit
    for (var i = 0; i < ids.length; i += size) {
      yield ids.sublist(i, i + size > ids.length ? ids.length : i + size);
    }
  }

  static String _marks(int n) => List.filled(n, '?').join(', ');

  Future<T> _withoutForeignKeys<T>(Future<T> Function() body) async {
    await db.customStatement('PRAGMA foreign_keys = OFF');
    try {
      return await body();
    } finally {
      await db.customStatement('PRAGMA foreign_keys = ON');
    }
  }

  // ---- Persisted state --------------------------------------------------------

  Future<_SyncState> _loadState() async {
    final row = await (db.select(
      db.settingsEntries,
    )..where((s) => s.key.equals(stateKey))).getSingleOrNull();
    if (row == null) return _SyncState();
    try {
      return _SyncState.fromJson(jsonDecode(row.value));
    } on FormatException {
      return _SyncState();
    }
  }

  Future<void> _saveState(_SyncState state) => db
      .into(db.settingsEntries)
      .insert(
        SettingsEntriesCompanion.insert(
          key: stateKey,
          value: jsonEncode(state.toJson()),
        ),
        mode: InsertMode.insertOrReplace,
      );
}

/// Runs async tasks one at a time, in call order — a tiny async mutex
/// (like chaining every job onto one shared `Promise`).
class _SerialQueue {
  Future<void> _tail = Future.value();

  Future<T> run<T>(Future<T> Function() body) {
    final result = _tail.then((_) => body());
    _tail = result.then((_) {}, onError: (Object _) {});
    return result;
  }
}

/// `sync_state` JSON: which user this device syncs with, and per user the
/// last successful sync time and the pull cursor of every table.
class _SyncState {
  _SyncState();

  factory _SyncState.fromJson(Object? json) {
    final state = _SyncState();
    if (json is! Map) return state;
    final last = json['lastUserId'];
    state.lastUserId = last is String ? last : null;
    final users = json['users'];
    if (users is Map) {
      for (final MapEntry(:key, :value) in users.entries) {
        if (key is String) state.users[key] = _UserState.fromJson(value);
      }
    }
    return state;
  }

  String? lastUserId;
  final users = <String, _UserState>{};

  _UserState user(String id) => users.putIfAbsent(id, _UserState.new);

  Map<String, Object?> toJson() => {
    'lastUserId': lastUserId,
    'users': {for (final e in users.entries) e.key: e.value.toJson()},
  };
}

class _UserState {
  _UserState();

  factory _UserState.fromJson(Object? json) {
    final user = _UserState();
    if (json is! Map) return user;
    final at = json['lastSyncedAt'];
    user.lastSyncedAt = at is String ? DateTime.tryParse(at)?.toLocal() : null;
    final cursors = json['cursors'];
    if (cursors is Map) {
      for (final MapEntry(:key, :value) in cursors.entries) {
        final cursor = RemoteCursor.fromJson(value);
        if (key is String && cursor != null) user.cursors[key] = cursor;
      }
    }
    return user;
  }

  DateTime? lastSyncedAt;
  final cursors = <String, RemoteCursor>{};

  Map<String, Object?> toJson() => {
    'lastSyncedAt': lastSyncedAt?.toUtc().toIso8601String(),
    'cursors': {for (final e in cursors.entries) e.key: e.value.toJson()},
  };
}
