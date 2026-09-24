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

  @override
  String toString() =>
      'SyncReport(pulled: $pulled, applied: $applied, pushed: $pushed, '
      'filesUploaded: $filesUploaded, fileUploadFailures: '
      '$fileUploadFailures, filesRemoved: $filesRemoved)';
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
/// stay queued and are pushed right after. Parents go before children
/// ([AppDatabase.syncedTableNames]) in both directions, and a failed push
/// stops the run, so the server never gets a child without its parent.
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
    for (final name in AppDatabase.syncedTableNames)
      db.allTables.firstWhere((t) => t.actualTableName == name),
  ];

  // Runs sync / adopt one at a time (a tiny async mutex).
  Future<void> _tail = Future.value();

  Future<T> _exclusive<T>(Future<T> Function() body) {
    final result = _tail.then((_) => body());
    _tail = result.then((_) {}, onError: (Object _) {});
    return result;
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
  Future<SyncReport> sync(String userId) => _exclusive(() async {
    final state = await _loadState();
    final last = state.lastUserId;
    if (last == null) {
      await _attach(state, userId, keepLocalData: true);
    } else if (last != userId) {
      throw SyncAccountMismatch(last, userId);
    }

    final report = SyncReport();
    await _withoutForeignKeys(() async {
      for (final table in tables) {
        await _pullTable(state, userId, table, report);
      }
    });
    for (final table in tables) {
      await _pushTable(userId, table, report);
    }
    if (files case final store?) {
      await _syncFiles(store, userId, report);
      // Rows the file step changed (storage_path set/cleared) go up now
      // rather than on the next run.
      await _pushTable(userId, _attachmentsTable, report);
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
    await db.seedCatalogs();
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
      await db.transaction(() async {
        report.applied += await _applyRows(table, rows);
        final current = user.cursors[name];
        if (current == null || last.compareTo(current) > 0) {
          user.cursors[name] = last;
        }
        await _saveState(state);
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
    var applied = 0;
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
        await _upsert(table, theirs);
        await _unqueue(name, id);
        applied++;
      } else if (same) {
        await _unqueue(name, id); // nothing left to upload
      } else if (cmp < 0 && !queued.contains(id)) {
        await _queue(name, id); // local copy is newer: make sure it goes up
      }
      // Otherwise the local row is newer (or wins the tie) and is already
      // queued: the push below uploads it.
    }
    return applied;
  }

  Future<void> _upsert(TableInfo table, Map<String, Object?> values) {
    final cols = values.keys.toList();
    final names = cols.map((c) => '"$c"').join(', ');
    final marks = List.filled(cols.length, '?').join(', ');
    final set = cols
        .where((c) => c != 'id')
        .map((c) => '"$c" = excluded."$c"')
        .join(', ');
    return db.customUpdate(
      'INSERT INTO ${table.actualTableName} ($names) VALUES ($marks) '
      'ON CONFLICT(id) DO UPDATE SET $set',
      variables: [for (final v in values.values) Variable<Object>(v)],
      updates: {table},
      updateKind: UpdateKind.update,
    );
  }

  // ---- Push -----------------------------------------------------------------

  Future<void> _pushTable(
    String userId,
    TableInfo table,
    SyncReport report,
  ) async {
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
      if (payload.isNotEmpty) await remote.push(name, userId, payload);
      // Only the entries we read: a row edited during the upload was
      // re-queued with a newer seq and goes up in the next batch.
      await db.customStatement(
        'DELETE FROM sync_outbox WHERE seq IN (${seqs.join(', ')})',
      );
      report.pushed += payload.length;
      if (queued.length < pushBatchSize) return;
    }
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
  /// Best effort: a failed file never fails the sync (the rows are already
  /// safe); it is simply retried on the next run.
  Future<void> _syncFiles(
    RemoteFileStore store,
    String userId,
    SyncReport report,
  ) async {
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

  Future<void> _unqueue(String table, String id) => db.customStatement(
    'DELETE FROM sync_outbox WHERE target_table = ? AND row_id = ?',
    [table, id],
  );

  Future<void> _queue(String table, String id) async {
    await _unqueue(table, id);
    await db.customStatement(
      'INSERT INTO sync_outbox (target_table, row_id) VALUES (?, ?)',
      [table, id],
    );
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
