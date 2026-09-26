import '../calc/transfer_code.dart';
import '../sync/in_memory_remote_store.dart';
import '../sync/remote_store.dart';
import 'sharing_api.dart';
import 'supabase_sharing_api.dart';

/// A test user of [InMemorySharingServer] (what `auth.users` + `profiles`
/// hold on Supabase).
class InMemoryUser {
  const InMemoryUser({
    required this.email,
    this.name = '',
    this.emailVerified = true,
  });

  final String email;
  final String name;
  final bool emailVerified;
}

/// The sharing RPCs of `20260926000001_sharing.sql` over an
/// [InMemoryRemoteStore] — the test double for [SupabaseSharingApi], like
/// the store itself is for the REST tables. Call [api] for one signed-in
/// user's client.
class InMemorySharingServer {
  InMemorySharingServer(this.store, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final InMemoryRemoteStore store;
  final DateTime Function() _clock;

  /// user id → user.
  final users = <String, InMemoryUser>{};

  /// code → transfer (plus who owns / redeemed it).
  final transfers =
      <String, ({String ownerId, TransferInfo info, String? redeemedBy})>{};

  /// user id → times of their failed redeems (unknown code), like the
  /// server's `transfer_attempts` table: after
  /// [maxFailedRedeemsPerHour] in an hour, redeeming is refused.
  final failedRedeems = <String, List<DateTime>>{};

  /// Mirrors `redeem_transfer()` in
  /// `supabase/migrations/20260928000001_security_hardening.sql`.
  static const maxFailedRedeemsPerHour = 10;

  /// Throw from it to simulate a network error on any call.
  void Function(String fn)? beforeCall;

  SharingApi api(String userId) => _InMemorySharingApi(this, userId);

  String displayName(String userId) {
    final u = users[userId];
    if (u == null) return '';
    return u.name.isNotEmpty ? u.name : u.email;
  }

  String profileLabel(String ownerId, String profileId) =>
      store.profileFor(ownerId, profileId)?.name ??
      (store.row('access_profiles', ownerId, profileId)?['name'] as String?) ??
      'Custom profile';
}

class _InMemorySharingApi implements SharingApi {
  _InMemorySharingApi(this.server, this.uid);

  final InMemorySharingServer server;
  final String uid;

  InMemoryRemoteStore get store => server.store;

  Never _fail(String key) =>
      throw SharingException(sharingErrorMessage('motolog:$key'));

  void _enter(String fn) {
    server.beforeCall?.call(fn);
    if (!server.users.containsKey(uid)) _fail('not_signed_in');
  }

  String get _email => server.users[uid]!.email.toLowerCase();

  String _bump(RemoteRow row) {
    final old = DateTime.parse(row['updated_at']! as String);
    final now = server._clock().toUtc();
    final next = now.isAfter(old)
        ? now
        : old.add(const Duration(milliseconds: 1));
    return next.toUtc().toIso8601String();
  }

  RemoteRow? _pending(Invitation inv) {
    final row = store.row('account_members', inv.ownerId, inv.id);
    if (row == null ||
        row['status'] != 'pending' ||
        row['deleted_at'] != null ||
        (row['email'] as String).toLowerCase() != _email) {
      return null;
    }
    return row;
  }

  @override
  Future<List<Invitation>> myInvitations() async {
    _enter('my_invitations');
    if (!server.users[uid]!.emailVerified) return const [];
    return [
      for (final m in store.allRows('account_members'))
        if (m['status'] == 'pending' &&
            m['deleted_at'] == null &&
            m['owner_id'] != uid &&
            (m['email'] as String).toLowerCase() == _email)
          Invitation(
            ownerId: m['owner_id']! as String,
            id: m['id']! as String,
            ownerName: server.displayName(m['owner_id']! as String),
            profileName: server.profileLabel(
              m['owner_id']! as String,
              m['profile_id']! as String,
            ),
          ),
    ];
  }

  @override
  Future<void> acceptInvitation(Invitation invitation) async {
    _enter('accept_invitation');
    if (invitation.ownerId == uid) _fail('own_account');
    if (!server.users[uid]!.emailVerified) _fail('email_not_verified');
    final row = _pending(invitation) ?? _fail('invitation_not_found');
    store.serverWrite('account_members', invitation.ownerId, {
      ...row,
      'member_id': uid,
      'member_name': server.displayName(uid),
      'status': 'active',
      'updated_at': _bump(row),
    });
  }

  @override
  Future<void> declineInvitation(Invitation invitation) async {
    _enter('decline_invitation');
    final row = _pending(invitation) ?? _fail('invitation_not_found');
    store.serverWrite('account_members', invitation.ownerId, {
      ...row,
      'status': 'declined',
      'updated_at': _bump(row),
    });
  }

  @override
  Future<List<Membership>> myMemberships() async {
    _enter('my_memberships');
    return [
      for (final m in store.allRows('account_members'))
        if (m['member_id'] == uid &&
            m['status'] == 'active' &&
            m['deleted_at'] == null &&
            m['owner_id'] != uid)
          Membership.fromJson({
            'ownerId': m['owner_id'],
            'memberId': uid,
            'ownerName': server.displayName(m['owner_id']! as String),
            'profileId': m['profile_id'],
            'profileName': server.profileLabel(
              m['owner_id']! as String,
              m['profile_id']! as String,
            ),
            'permissions': store
                .profileFor(
                  m['owner_id']! as String,
                  m['profile_id']! as String,
                )
                ?.permissionsToJson(),
            'vehicleIds': m['vehicle_ids'],
          }),
    ];
  }

  @override
  Future<void> leaveAccount(String ownerId) async {
    _enter('leave_account');
    for (final m in store.allRows('account_members')) {
      if (m['owner_id'] == ownerId &&
          m['member_id'] == uid &&
          m['status'] == 'active') {
        store.serverWrite('account_members', ownerId, {
          ...m,
          'status': 'removed',
          'updated_at': _bump(m),
        });
      }
    }
  }

  @override
  Future<TransferInfo> createTransfer(String vehicleId) async {
    _enter('create_transfer');
    final vehicle = store.row('vehicles', uid, vehicleId);
    if (vehicle == null || vehicle['deleted_at'] != null) {
      _fail('vehicle_not_found');
    }
    var code = TransferCode.generate();
    while (server.transfers.containsKey(code)) {
      code = TransferCode.generate();
    }
    final now = server._clock();
    final info = TransferInfo(
      code: code,
      vehicleId: vehicleId,
      vehicleName: vehicle['name'] as String? ?? '',
      createdAt: now,
      expiresAt: now.add(TransferCode.validity),
    );
    server.transfers[code] = (ownerId: uid, info: info, redeemedBy: null);
    return info;
  }

  @override
  Future<List<TransferInfo>> myTransfers() async {
    _enter('my_transfers');
    return [
      for (final t in server.transfers.values)
        if (t.ownerId == uid) t.info,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> cancelTransfer(String code) async {
    _enter('cancel_transfer');
    final key = TransferCode.normalize(code);
    final t = server.transfers[key];
    if (t == null ||
        t.ownerId != uid ||
        t.info.redeemedAt != null ||
        t.info.cancelledAt != null) {
      return;
    }
    server.transfers[key] = (
      ownerId: t.ownerId,
      redeemedBy: null,
      info: _copyInfo(t.info, cancelledAt: server._clock()),
    );
  }

  @override
  Future<RedeemedTransfer> redeemTransfer(String code) async {
    _enter('redeem_transfer');
    final key = TransferCode.normalize(code);
    final hourAgo = server._clock().subtract(const Duration(hours: 1));
    final failed = server.failedRedeems.putIfAbsent(uid, () => [])
      ..removeWhere((t) => t.isBefore(hourAgo));
    if (failed.length >= InMemorySharingServer.maxFailedRedeemsPerHour) {
      _fail('transfer_rate_limited');
    }
    final t = server.transfers[key];
    if (t == null) {
      failed.add(server._clock());
      _fail('transfer_not_found');
    }
    final seller = t.ownerId;
    final v = t.info.vehicleId;
    if (seller == uid) _fail('transfer_own');
    if (t.info.redeemedAt != null) _fail('transfer_used');
    if (t.info.cancelledAt != null) _fail('transfer_cancelled');
    if (!server._clock().isBefore(t.info.expiresAt)) _fail('transfer_expired');
    if (store.row('vehicles', uid, v) != null) _fail('vehicle_exists');
    final vehicle = store.row('vehicles', seller, v);
    if (vehicle == null || vehicle['deleted_at'] != null) {
      _fail('vehicle_not_found');
    }

    List<RemoteRow> live(String table) => [
      for (final r in store.rows(table, seller))
        if (r['deleted_at'] == null) r,
    ];
    Set<String> ids(Iterable<RemoteRow> rows, String column) => {
      for (final r in rows)
        if (r[column] case final String id) id,
    };
    final byVehicle = {
      for (final table in const [
        'refuelings',
        'entries',
        'routes',
        'readings',
        'reminders',
        'checklists',
        'attachments',
      ])
        table: [
          for (final r in live(table))
            if (r['vehicle_id'] == v) r,
        ],
    };
    final refuelingIds = ids(byVehicle['refuelings']!, 'id');
    final entryIds = ids(byVehicle['entries']!, 'id');
    final checklistIds = ids(byVehicle['checklists']!, 'id');
    final children = {
      'refueling_fuels': [
        for (final r in live('refueling_fuels'))
          if (refuelingIds.contains(r['refueling_id'])) r,
      ],
      'entry_items': [
        for (final r in live('entry_items'))
          if (entryIds.contains(r['entry_id'])) r,
      ],
      'checklist_answers': [
        for (final r in live('checklist_answers'))
          if (checklistIds.contains(r['checklist_id'])) r,
      ],
    };
    final catalogIds = {
      for (final c in const [
        'gas_station_id',
        'payment_method_id',
        'reason_id',
      ])
        ...ids(byVehicle['refuelings']!, c),
      ...ids(children['refueling_fuels']!, 'fuel_id'),
      for (final c in const ['place_id', 'payment_method_id', 'reason_id'])
        ...ids(byVehicle['entries']!, c),
      ...ids(children['entry_items']!, 'type_id'),
      ...ids(byVehicle['routes']!, 'reason_id'),
      ...ids(byVehicle['reminders']!, 'type_id'),
    };
    final formIds = ids(byVehicle['checklists']!, 'form_id');

    void copy(String table, Iterable<RemoteRow> rows) {
      for (final r in rows) {
        if (store.row(table, uid, r['id']! as String) != null) continue;
        final copy = {...r}..remove('server_updated_at');
        if (copy.containsKey('created_by')) copy['created_by'] = null;
        store.serverWrite(table, uid, copy);
      }
    }

    copy('vehicles', [vehicle]);
    copy('catalog_items', [
      for (final r in store.rows('catalog_items', seller))
        if (catalogIds.contains(r['id'])) r,
    ]);
    copy('checklist_forms', [
      for (final r in store.rows('checklist_forms', seller))
        if (formIds.contains(r['id'])) r,
    ]);
    copy('checklist_form_items', [
      for (final r in live('checklist_form_items'))
        if (formIds.contains(r['form_id'])) r,
    ]);
    for (final table in const [
      'refuelings',
      'entries',
      'routes',
      'readings',
      'reminders',
      'checklists',
    ]) {
      copy(table, byVehicle[table]!);
    }
    for (final e in children.entries) {
      copy(e.key, e.value);
    }
    copy('attachments', byVehicle['attachments']!);

    server.transfers[key] = (
      ownerId: seller,
      redeemedBy: uid,
      info: _copyInfo(t.info, redeemedAt: server._clock()),
    );
    return RedeemedTransfer(
      vehicleId: v,
      vehicleName: vehicle['name'] as String? ?? '',
    );
  }

  static TransferInfo _copyInfo(
    TransferInfo i, {
    DateTime? redeemedAt,
    DateTime? cancelledAt,
  }) => TransferInfo(
    code: i.code,
    vehicleId: i.vehicleId,
    vehicleName: i.vehicleName,
    createdAt: i.createdAt,
    expiresAt: i.expiresAt,
    redeemedAt: redeemedAt ?? i.redeemedAt,
    cancelledAt: cancelledAt ?? i.cancelledAt,
  );
}
