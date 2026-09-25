import 'dart:convert';

import '../calc/access_profile.dart';
import '../calc/member_access.dart';
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
  Future<void> push(String table, String ownerId, List<RemoteRow> rows) =>
      _push(table, ownerId, rows, caller: ownerId);

  /// The same server seen by signed-in user [userId]: pushes and pulls in
  /// other owners' accounts follow the sharing rules (row-level security of
  /// `20260926000001_sharing.sql`, via [accessFor]) — like a second
  /// Supabase client with another user's session.
  RemoteStore asUser(String userId) => _UserView(this, userId);

  Future<void> _push(
    String table,
    String ownerId,
    List<RemoteRow> rows, {
    required String caller,
  }) async {
    pushes++;
    beforePush?.call(table, rows);
    if (rows.length > RemoteStore.maxPushBatch) {
      throw ArgumentError('Batch of ${rows.length} rows is too large');
    }
    // Validate everything first so a bad batch stores nothing (the real
    // upsert is one SQL statement, so it is all-or-nothing too).
    for (final r in rows) {
      final owner = r['owner_id'] ?? ownerId;
      if (owner != ownerId ||
          (caller != ownerId && !_isMember(ownerId, caller))) {
        throw RemotePermissionDenied(table, 'owner_id must be $caller');
      }
      if (r['id'] is! String || r['updated_at'] is! String) {
        throw ArgumentError('Row without id/updated_at: $r');
      }
    }
    final stored = _tables.putIfAbsent(table, () => {});
    final prepared = <RemoteRow>[];
    for (final r in rows) {
      final incoming = {...r, 'owner_id': ownerId};
      final old = stored['$ownerId|${incoming['id']}'];
      _beforeWrite(table, incoming, old, caller: caller);
      if (caller != ownerId &&
          !_allowsWrite(table, ownerId, incoming, old, caller)) {
        throw RemotePermissionDenied(table, 'row ${incoming['id']}');
      }
      prepared.add(incoming);
    }
    for (final incoming in prepared) {
      final key = '$ownerId|${incoming['id']}';
      final old = stored[key];
      if (old != null && !_shouldApply(old, incoming)) continue;
      incoming['server_updated_at'] = _stamp().toIso8601String();
      stored[key] = incoming;
      _sortedFeeds.remove(table);
      writes++;
    }
  }

  /// A write made by a server function (an RPC: accepting an invitation,
  /// redeeming a transfer), bypassing the client rules — still
  /// last-write-wins and still stamped. Returns whether it was applied.
  bool serverWrite(String table, String ownerId, RemoteRow row) {
    final stored = _tables.putIfAbsent(table, () => {});
    final incoming = {...row, 'owner_id': ownerId};
    final key = '$ownerId|${incoming['id']}';
    final old = stored[key];
    if (old != null && !_shouldApply(old, incoming)) return false;
    incoming['server_updated_at'] = _stamp().toIso8601String();
    stored[key] = incoming;
    _sortedFeeds.remove(table);
    writes++;
    return true;
  }

  /// Every stored row of [table], all owners (copies).
  List<RemoteRow> allRows(String table) => [
    for (final r in (_tables[table] ?? const {}).values) {...r},
  ];

  // ---- Sharing rules (mirror of 20260926000001_sharing.sql) ---------------

  /// Tables with a server-stamped `created_by`.
  static const createdByTables = {
    'refuelings',
    'entries',
    'routes',
    'readings',
    'reminders',
    'checklists',
    'attachments',
  };

  /// The triggers that run before a client write: `created_by` stamping
  /// and the `account_members` guard.
  void _beforeWrite(
    String table,
    RemoteRow incoming,
    RemoteRow? old, {
    required String caller,
  }) {
    final owner = incoming['owner_id'];
    if (createdByTables.contains(table)) {
      if (old != null) {
        if (old.containsKey('created_by') ||
            incoming.containsKey('created_by')) {
          incoming['created_by'] = old['created_by'];
        }
      } else if (caller != owner) {
        incoming['created_by'] = caller;
      } else if (incoming.containsKey('created_by')) {
        incoming['created_by'] = null;
      }
    }
    if (table == 'account_members') {
      incoming['email'] = (incoming['email'] as String? ?? '')
          .trim()
          .toLowerCase();
      if (old == null) {
        incoming['member_id'] = null;
        incoming['member_name'] = null;
        if (incoming['status'] != 'pending' &&
            incoming['status'] != 'removed') {
          incoming['status'] = 'pending';
        }
        return;
      }
      incoming['member_id'] = old['member_id'];
      incoming['member_name'] = old['member_name'];
      final from = old['status'];
      final to = incoming['status'];
      if (to != from) {
        if (to == 'removed') {
          // always allowed
        } else if (to == 'pending' &&
            (from == 'declined' || from == 'removed')) {
          incoming['member_id'] = null;
          incoming['member_name'] = null;
        } else {
          incoming['status'] = from;
        }
      }
      if (incoming['member_id'] != null) incoming['email'] = old['email'];
    }
  }

  bool _isMember(String ownerId, String userId) =>
      accessFor(ownerId, userId) != null;

  /// What [userId] may do in [ownerId]'s account (`can_access`'s
  /// membership + profile lookup); null = nothing (not an active member).
  MemberAccess? accessFor(String ownerId, String userId) {
    if (ownerId == userId) return MemberAccess.owner();
    RemoteRow? member;
    for (final m in _feed('account_members', ownerId)) {
      if (m['member_id'] != userId ||
          m['status'] != 'active' ||
          m['deleted_at'] != null) {
        continue;
      }
      if (member == null ||
          DateTime.parse(m['updated_at']! as String)
              .isAfter(DateTime.parse(member['updated_at']! as String))) {
        member = m;
      }
    }
    if (member == null) return null;
    final profile = profileFor(ownerId, member['profile_id']! as String);
    if (profile == null) return null;
    return MemberAccess(
      profile: profile,
      memberId: userId,
      vehicleIds: {
        for (final v
            in (jsonDecode(member['vehicle_ids'] as String? ?? '[]') as List))
          v.toString(),
      },
    );
  }

  /// `profile_permissions()`: a built-in profile, or [ownerId]'s live
  /// custom profile with that id.
  AccessProfile? profileFor(String ownerId, String profileId) {
    final builtIn = AccessProfile.builtInById(profileId);
    if (builtIn != null) return builtIn;
    final row = this.row('access_profiles', ownerId, profileId);
    if (row == null || row['deleted_at'] != null) return null;
    return AccessProfile.fromPermissionsJson(
      id: profileId,
      name: row['name'] as String? ?? '',
      json: (jsonDecode(row['permissions']! as String) as Map)
          .cast<String, Object?>(),
    );
  }

  /// `can_access()` for [access] (null area = skip the switch check).
  static bool _can(
    MemberAccess access,
    String? area,
    String action, {
    String? vehicleId,
    String? createdBy,
  }) {
    if (access.isOwner) return true;
    if (area != null) {
      final a = AccessArea.values.where((x) => x.name == area).firstOrNull;
      final act = AccessAction.values.byName(action);
      if (a == null || !access.profile.can(a, act)) return false;
    }
    if (vehicleId != null && !access.canSeeVehicle(vehicleId)) return false;
    if (createdBy != null &&
        access.profile.recordScope != RecordScope.all &&
        createdBy != access.memberId) {
      return false;
    }
    return true;
  }

  static const _recordAreas = {
    'refuelings': 'refueling',
    'routes': 'route',
    'readings': 'reading',
    'reminders': 'reminder',
    'checklists': 'checklist',
  };

  static const _childParents = {
    'refueling_fuels': ('refuelings', 'refueling_id'),
    'entry_items': ('entries', 'entry_id'),
    'checklist_answers': ('checklists', 'checklist_id'),
  };

  bool _isChild(String table) =>
      _childParents.containsKey(table) || table == 'attachments';

  /// The per-table policy expression for [action] on [row].
  bool _check(
    String table,
    String ownerId,
    RemoteRow row,
    String action,
    MemberAccess access,
  ) {
    if (access.isOwner) return true;
    String? createdBy() => (row['created_by'] as String?) ?? ownerId;
    switch (table) {
      case 'vehicles':
        return action == 'view'
            ? _can(access, null, 'view', vehicleId: row['id'] as String)
            : _can(access, 'vehicles', action, vehicleId: row['id'] as String);
      case 'catalog_items':
        return _can(access, row['kind'] as String?, action);
      case 'entries':
        return _can(
          access,
          row['kind'] as String?,
          action,
          vehicleId: row['vehicle_id'] as String?,
          createdBy: createdBy(),
        );
      case 'checklist_forms' || 'checklist_form_items':
        return action == 'view'
            ? _can(access, 'forms', 'view') || _can(access, 'checklist', 'view')
            : _can(access, 'forms', action);
      case 'access_profiles':
        return _can(access, 'profiles', action);
      case 'account_members':
        return _can(access, 'users', action);
      case 'attachments':
        return _checkParent(
          row['parent_table'] as String,
          ownerId,
          row['parent_id'] as String,
          action,
          access,
        );
    }
    if (_recordAreas[table] case final area?) {
      return _can(
        access,
        area,
        action,
        vehicleId: row['vehicle_id'] as String?,
        createdBy: createdBy(),
      );
    }
    if (_childParents[table] case (final parent, final column)) {
      return _checkParent(
        parent,
        ownerId,
        row[column] as String,
        action,
        access,
      );
    }
    return false;
  }

  bool _checkParent(
    String parentTable,
    String ownerId,
    String parentId,
    String action,
    MemberAccess access,
  ) {
    if (parentTable != 'entries' && !_recordAreas.containsKey(parentTable)) {
      return false;
    }
    final parent = row(parentTable, ownerId, parentId);
    if (parent == null) return false;
    return _check(parentTable, ownerId, parent, action, access);
  }

  /// Row-level security for a member's upsert of [incoming] over [old].
  bool _allowsWrite(
    String table,
    String ownerId,
    RemoteRow incoming,
    RemoteRow? old,
    String caller,
  ) {
    final access = accessFor(ownerId, caller);
    if (access == null) return false;
    bool check(String action) =>
        _check(table, ownerId, incoming, action, access);
    if (old == null) {
      return _isChild(table)
          ? check('register') || check('edit')
          : check('register');
    }
    if (!_check(table, ownerId, old, 'view', access)) return false;
    if (_isChild(table)) return check('edit');
    return check(incoming['deleted_at'] == null ? 'edit' : 'delete');
  }

  /// Whether [userId] may see [row] (the select policy).
  bool canView(String table, String ownerId, RemoteRow row, String userId) {
    final access = accessFor(ownerId, userId);
    return access != null && _check(table, ownerId, row, 'view', access);
  }

  @override
  Future<List<RemoteRow>> pull(
    String table,
    String ownerId, {
    RemoteCursor? after,
    int limit = RemoteStore.maxPullPage,
  }) => _pull(table, ownerId, after: after, limit: limit, caller: ownerId);

  Future<List<RemoteRow>> _pull(
    String table,
    String ownerId, {
    required String caller,
    RemoteCursor? after,
    int limit = RemoteStore.maxPullPage,
  }) async {
    pulls++;
    beforePull?.call(table, after);
    if (limit > RemoteStore.maxPullPage) limit = RemoteStore.maxPullPage;
    final from = after == null ? null : _FeedEntry.key(after);
    final access = caller == ownerId ? null : accessFor(ownerId, caller);
    if (caller != ownerId && access == null) return const [];
    return _entries(table)
        .where(
          (e) =>
              e.owner == ownerId &&
              (from == null || e.compareTo(from) > 0) &&
              (access == null ||
                  _check(table, ownerId, e.row!, 'view', access)),
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

/// [InMemoryRemoteStore] as seen by one signed-in user.
class _UserView implements RemoteStore {
  _UserView(this.store, this.userId);

  final InMemoryRemoteStore store;
  final String userId;

  @override
  Future<void> push(String table, String ownerId, List<RemoteRow> rows) =>
      store._push(table, ownerId, rows, caller: userId);

  @override
  Future<List<RemoteRow>> pull(
    String table,
    String ownerId, {
    RemoteCursor? after,
    int limit = RemoteStore.maxPullPage,
  }) => store._pull(table, ownerId, caller: userId, after: after, limit: limit);
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
