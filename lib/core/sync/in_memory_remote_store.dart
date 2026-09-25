import 'remote_store.dart';

/// A fake Supabase that lives in memory — the sync engine's test double
/// (like `msw` mocking a REST API in a web app).
///
/// It follows the same rules as the SQL in
/// `supabase/migrations/20260924000001_sync_tables.sql`: rows are keyed by
/// `(owner_id, id)`, writes are last-write-wins on `updated_at` (an older
/// row, or an identical row with the same `updated_at`, is ignored), every
/// real write stamps an increasing `server_updated_at`, and pulls page over
/// `(server_updated_at, id)`. Several app databases can sync through one
/// instance, like several devices sharing one cloud account.
class InMemoryRemoteStore implements RemoteStore {
  InMemoryRemoteStore({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  DateTime _lastStamp = DateTime.utc(1970);

  /// table → "owner|id" → stored row.
  final _tables = <String, Map<String, RemoteRow>>{};

  /// table → every owner's rows in feed order, rebuilt lazily after a
  /// write (the fake's "index on (server_updated_at, id)"). Without it every
  /// pulled page re-sorted the whole table, which made big-dataset
  /// benchmarks measure the fake instead of the sync engine.
  final _sortedFeeds = <String, List<_FeedEntry>>{};

  /// Called before every [push] / [pull]; throw from it to simulate a
  /// network or server error for that call.
  void Function(String table, List<RemoteRow> rows)? beforePush;
  void Function(String table, RemoteCursor? after)? beforePull;

  /// Number of rows actually written (inserted or changed) so far. A re-sync
  /// that changes nothing must leave it untouched.
  int writes = 0;

  /// Number of [pull] calls so far (pages requested).
  int pulls = 0;

  /// Number of [push] calls so far (batches received).
  int pushes = 0;

  /// Snapshot of [ownerId]'s rows of [table] (copies), in feed order.
  List<RemoteRow> rows(String table, String ownerId) =>
      _feed(table, ownerId).map((r) => {...r}).toList();

  /// One stored row (a copy), or null.
  RemoteRow? row(String table, String ownerId, String id) {
    final r = _tables[table]?['$ownerId|$id'];
    return r == null ? null : {...r};
  }

  @override
  Future<void> push(String table, String ownerId, List<RemoteRow> rows) async {
    pushes++;
    beforePush?.call(table, rows);
    if (rows.length > RemoteStore.maxPushBatch) {
      throw ArgumentError('Batch of ${rows.length} rows is too large');
    }
    // Validate everything first so a bad batch stores nothing (the real
    // upsert is one SQL statement, so it is all-or-nothing too).
    for (final r in rows) {
      final owner = r['owner_id'] ?? ownerId;
      if (owner != ownerId) {
        throw StateError('Row-level security: owner_id must be $ownerId');
      }
      if (r['id'] is! String || r['updated_at'] is! String) {
        throw ArgumentError('Row without id/updated_at: $r');
      }
    }
    final stored = _tables.putIfAbsent(table, () => {});
    for (final r in rows) {
      final incoming = {...r, 'owner_id': ownerId};
      final key = '$ownerId|${incoming['id']}';
      final old = stored[key];
      if (old != null && !_shouldApply(old, incoming)) continue;
      incoming['server_updated_at'] = _stamp().toIso8601String();
      stored[key] = incoming;
      _sortedFeeds.remove(table);
      writes++;
    }
  }

  @override
  Future<List<RemoteRow>> pull(
    String table,
    String ownerId, {
    RemoteCursor? after,
    int limit = RemoteStore.maxPullPage,
  }) async {
    pulls++;
    beforePull?.call(table, after);
    if (limit > RemoteStore.maxPullPage) limit = RemoteStore.maxPullPage;
    final from = after == null ? null : _FeedEntry.key(after);
    return _entries(table)
        .where(
          (e) => e.owner == ownerId && (from == null || e.compareTo(from) > 0),
        )
        .take(limit)
        .map((e) => {...e.row!})
        .toList();
  }

  /// The `BEFORE UPDATE` trigger's rule: last write wins; an identical row
  /// with the same `updated_at` is a no-op.
  static bool _shouldApply(RemoteRow old, RemoteRow incoming) {
    final oldAt = DateTime.parse(old['updated_at']! as String);
    final newAt = DateTime.parse(incoming['updated_at']! as String);
    final cmp = newAt.compareTo(oldAt);
    if (cmp < 0) return false;
    if (cmp > 0) return true;
    return !_sameData(old, incoming);
  }

  static bool _sameData(RemoteRow a, RemoteRow b) {
    bool counts(String k) => k != 'server_updated_at';
    final keys = {...a.keys.where(counts), ...b.keys.where(counts)};
    return keys.every((k) => a[k] == b[k]);
  }

  List<RemoteRow> _feed(String table, String ownerId) => [
    for (final e in _entries(table))
      if (e.owner == ownerId) e.row!,
  ];

  List<_FeedEntry> _entries(String table) => _sortedFeeds[table] ??= [
    for (final r in (_tables[table] ?? const {}).values) _FeedEntry.of(r),
  ]..sort((a, b) => a.compareTo(b));

  /// Strictly increasing server time (like `clock_timestamp()`).
  DateTime _stamp() {
    var now = _clock().toUtc();
    if (!now.isAfter(_lastStamp)) {
      now = _lastStamp.add(const Duration(microseconds: 1));
    }
    return _lastStamp = now;
  }
}

/// A stored row with its feed position pre-parsed, ordered exactly like
/// [RemoteCursor.compareTo] (time, then the timestamp text, then id).
class _FeedEntry {
  _FeedEntry(this.micros, this.ts, this.id, {this.owner = '', this.row});

  factory _FeedEntry.of(RemoteRow r) {
    final ts = r['server_updated_at']! as String;
    return _FeedEntry(
      DateTime.parse(ts).microsecondsSinceEpoch,
      ts,
      r['id']! as String,
      owner: r['owner_id']! as String,
      row: r,
    );
  }

  factory _FeedEntry.key(RemoteCursor c) =>
      _FeedEntry(c.time.microsecondsSinceEpoch, c.serverUpdatedAt, c.id);

  final int micros;
  final String ts;
  final String id;
  final String owner;
  final RemoteRow? row;

  int compareTo(_FeedEntry other) {
    final byTime = micros.compareTo(other.micros);
    if (byTime != 0) return byTime;
    final byText = ts.compareTo(other.ts);
    if (byText != 0) return byText;
    return id.compareTo(other.id);
  }
}
