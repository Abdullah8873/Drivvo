import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'remote_store.dart';

/// [RemoteStore] backed by Supabase's auto-generated REST API (PostgREST) —
/// the tables from `supabase/migrations/20260924000001_sync_tables.sql`.
///
/// Row-level security on the server already limits every query to the
/// signed-in user's rows; the explicit `owner_id` filter/value just keeps
/// the queries honest and index-friendly. Last-write-wins is enforced by a
/// database trigger, so a plain upsert is safe to repeat.
class SupabaseRemoteStore implements RemoteStore {
  SupabaseRemoteStore(this._client);

  final SupabaseClient _client;

  @override
  Future<void> push(String table, String ownerId, List<RemoteRow> rows) async {
    for (var i = 0; i < rows.length; i += RemoteStore.maxPushBatch) {
      final chunk = [
        for (final r in rows.sublist(
          i,
          math.min(i + RemoteStore.maxPushBatch, rows.length),
        ))
          {...r, 'owner_id': ownerId},
      ];
      // `INSERT ... ON CONFLICT (owner_id, id) DO UPDATE` — the trigger
      // turns stale or identical rows into no-ops.
      await _client.from(table).upsert(chunk, onConflict: 'owner_id,id');
    }
  }

  @override
  Future<List<RemoteRow>> pull(
    String table,
    String ownerId, {
    RemoteCursor? after,
    int limit = RemoteStore.maxPullPage,
  }) async {
    var query = _client.from(table).select().eq('owner_id', ownerId);
    if (after != null) {
      // Keyset: (server_updated_at, id) > (after.ts, after.id). Values are
      // double-quoted so the `:` in timestamps/seed ids can't break the
      // PostgREST filter syntax; the timestamp is sent in UTC ("Z", no "+").
      final ts = _quote(_utc(after.serverUpdatedAt));
      final id = _quote(after.id);
      query = query.or(
        'server_updated_at.gt.$ts,'
        'and(server_updated_at.eq.$ts,id.gt.$id)',
      );
    }
    final rows = await query
        .order('server_updated_at', ascending: true)
        .order('id', ascending: true)
        .limit(math.min(limit, RemoteStore.maxPullPage));
    return [for (final r in rows) Map<String, Object?>.from(r)];
  }

  /// The server's own string (full microsecond precision, even on the web
  /// where `DateTime` stops at milliseconds), with `+00:00` written as `Z`.
  static String _utc(String ts) {
    if (ts.endsWith('Z')) return ts;
    if (ts.endsWith('+00:00')) return '${ts.substring(0, ts.length - 6)}Z';
    return DateTime.parse(ts).toUtc().toIso8601String();
  }

  static String _quote(String value) =>
      '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
}
