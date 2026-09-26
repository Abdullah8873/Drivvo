/// A row as it travels between the app and the cloud: snake_case column
/// names (the same as the local SQLite columns) mapped to JSON values —
/// timestamps as ISO-8601 UTC strings, booleans as `true`/`false`. Rows
/// coming *from* the server also carry `owner_id` and `server_updated_at`.
typedef RemoteRow = Map<String, Object?>;

/// Position in one table's server-side change feed.
///
/// The server orders every table by `(server_updated_at, id)` — a "keyset"
/// (a.k.a. seek) cursor, like paginating a REST API with
/// `?after=<timestamp>,<id>` instead of `?page=3`, so rows written while we
/// page never shift the pages. [serverUpdatedAt] is kept as the exact string
/// the server sent: parsing it into a `DateTime` would drop microseconds on
/// the web and make the next page repeat rows.
class RemoteCursor {
  const RemoteCursor(this.serverUpdatedAt, this.id);

  /// Cursor at [time] that sorts before every row with that timestamp.
  RemoteCursor.at(DateTime time)
    : serverUpdatedAt = time.toUtc().toIso8601String(),
      id = '';

  /// The last row seen on [page] (null for an empty page).
  static RemoteCursor? lastOf(List<RemoteRow> page) {
    if (page.isEmpty) return null;
    final row = page.last;
    return RemoteCursor(
      row['server_updated_at']! as String,
      row['id']! as String,
    );
  }

  final String serverUpdatedAt;
  final String id;

  DateTime get time => DateTime.parse(serverUpdatedAt);

  /// Feed order: by time, then by id.
  int compareTo(RemoteCursor other) {
    final byTime = time.compareTo(other.time);
    if (byTime != 0) return byTime;
    final byText = serverUpdatedAt.compareTo(other.serverUpdatedAt);
    if (byText != 0) return byText;
    return id.compareTo(other.id);
  }

  Map<String, Object?> toJson() => {'ts': serverUpdatedAt, 'id': id};

  static RemoteCursor? fromJson(Object? json) {
    if (json is! Map) return null;
    final ts = json['ts'];
    final id = json['id'];
    if (ts is! String || id is! String) return null;
    return RemoteCursor(ts, id);
  }

  @override
  String toString() => 'RemoteCursor($serverUpdatedAt, $id)';
}

/// Shown when the server refuses more data for an account
/// (`motolog:quota_exceeded`: 25 MB of records, see
/// `supabase/migrations/20260928000001_security_hardening.sql`).
const cloudFullMessage =
    'Your cloud space is full. Delete records you no longer need, then '
    'sync again.';

/// Thrown by [RemoteStore.push] when the server's row-level security
/// refused the batch — only possible in a shared account, where a member
/// uploaded something their profile doesn't allow (Postgres error 42501).
/// Nothing of the batch was stored.
class RemotePermissionDenied implements Exception {
  const RemotePermissionDenied(this.table, [this.detail = '']);

  final String table;
  final String detail;

  @override
  String toString() =>
      'Permission denied on $table${detail.isEmpty ? '' : ': $detail'}';
}

/// The cloud side of the sync — an interface so the engine can be tested
/// against [InMemoryRemoteStore] and run for real against Supabase
/// ([SupabaseRemoteStore]); think of it as the "API client" layer.
///
/// Server rules every implementation must follow (they mirror
/// `supabase/migrations/20260924000001_sync_tables.sql`):
/// - rows are scoped by owner: a user only ever reads/writes their own rows,
///   and the key is `(owner_id, id)` (seeded catalog ids repeat per user);
/// - last-write-wins on `updated_at`: an incoming row older than the stored
///   one is ignored, and so is an identical row with the same `updated_at`
///   (so re-uploading never changes anything); an equal `updated_at` with
///   different data is applied;
/// - every row that is actually written gets a fresh, increasing
///   `server_updated_at`, which is what [pull] pages over.
abstract interface class RemoteStore {
  /// Largest batch [push] should receive (one HTTP request / statement).
  static const maxPushBatch = 500;

  /// Largest page [pull] may return (Supabase's default "Max rows").
  static const maxPullPage = 1000;

  /// Upserts [rows] of [table] for [ownerId]. All-or-nothing: throws when the
  /// batch failed, in which case nothing was stored
  /// ([RemotePermissionDenied] when row-level security refused it).
  Future<void> push(String table, String ownerId, List<RemoteRow> rows);

  /// Up to [limit] rows of [table] owned by [ownerId] that come strictly
  /// after [after] in `(server_updated_at, id)` order (from the start when
  /// null), oldest first.
  Future<List<RemoteRow>> pull(
    String table,
    String ownerId, {
    RemoteCursor? after,
    int limit = maxPullPage,
  });
}
