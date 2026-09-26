import 'package:supabase_flutter/supabase_flutter.dart';

import '../sync/remote_store.dart' show cloudFullMessage;
import 'sharing_api.dart';

/// [SharingApi] over the Postgres functions of
/// `supabase/migrations/20260926000001_sharing.sql` (`client.rpc(...)` is
/// a POST to `/rest/v1/rpc/<name>`).
class SupabaseSharingApi implements SharingApi {
  SupabaseSharingApi(this._client);

  final SupabaseClient _client;

  Future<Object?> _call(String fn, [Map<String, Object?>? params]) async {
    try {
      return await _client.rpc(fn, params: params);
    } on PostgrestException catch (e) {
      throw SharingException(sharingErrorMessage(e.message));
    } on SharingException {
      rethrow;
    } catch (_) {
      throw const SharingException(
        "Couldn't reach the server. Check your internet connection and try "
        'again.',
      );
    }
  }

  List<Map<String, Object?>> _rows(Object? result) => [
    if (result is List)
      for (final r in result)
        if (r is Map) r.cast<String, Object?>(),
  ];

  @override
  Future<List<Invitation>> myInvitations() async => [
    for (final r in _rows(await _call('my_invitations')))
      Invitation(
        ownerId: r['owner_id']! as String,
        id: r['id']! as String,
        ownerName: r['owner_name'] as String? ?? '',
        profileName: r['profile_name'] as String? ?? '',
      ),
  ];

  @override
  Future<void> acceptInvitation(Invitation invitation) => _call(
    'accept_invitation',
    {'p_owner': invitation.ownerId, 'p_id': invitation.id},
  );

  @override
  Future<void> declineInvitation(Invitation invitation) => _call(
    'decline_invitation',
    {'p_owner': invitation.ownerId, 'p_id': invitation.id},
  );

  @override
  Future<List<Membership>> myMemberships() async => [
    for (final r in _rows(await _call('my_memberships')))
      Membership.fromJson({
        'ownerId': r['owner_id'],
        'memberId': r['member_id'],
        'ownerName': r['owner_name'],
        'profileId': r['profile_id'],
        'profileName': r['profile_name'],
        'permissions': r['permissions'],
        'vehicleIds': r['vehicle_ids'],
      }),
  ];

  @override
  Future<void> leaveAccount(String ownerId) =>
      _call('leave_account', {'p_owner': ownerId});

  @override
  Future<TransferInfo> createTransfer(String vehicleId) async {
    final rows = _rows(
      await _call('create_transfer', {'p_vehicle_id': vehicleId}),
    );
    if (rows.isEmpty) {
      throw const SharingException("Couldn't create a transfer code.");
    }
    return _transfer(rows.first);
  }

  @override
  Future<List<TransferInfo>> myTransfers() async => [
    for (final r in _rows(await _call('my_transfers'))) _transfer(r),
  ];

  @override
  Future<void> cancelTransfer(String code) =>
      _call('cancel_transfer', {'p_code': code});

  @override
  Future<RedeemedTransfer> redeemTransfer(String code) async {
    final rows = _rows(await _call('redeem_transfer', {'p_code': code}));
    // The server answers an unknown code with no rows rather than an
    // error, so that it can count the failed try (rate limit).
    if (rows.isEmpty) {
      throw SharingException(sharingErrorMessage('motolog:transfer_not_found'));
    }
    return RedeemedTransfer(
      vehicleId: rows.first['vehicle_id']! as String,
      vehicleName: rows.first['vehicle_name'] as String? ?? '',
    );
  }

  static TransferInfo _transfer(Map<String, Object?> r) {
    DateTime? at(String key) =>
        r[key] == null ? null : DateTime.parse(r[key]! as String).toLocal();
    return TransferInfo(
      code: r['code']! as String,
      vehicleId: r['vehicle_id']! as String,
      vehicleName: r['vehicle_name'] as String? ?? '',
      createdAt: at('created_at')!,
      expiresAt: at('expires_at')!,
      redeemedAt: at('redeemed_at'),
      cancelledAt: at('cancelled_at'),
    );
  }
}

/// Maps the `motolog:<key>` exceptions raised by the sharing SQL (and the
/// in-memory test server) to sentences for the user.
String sharingErrorMessage(String raw) {
  final key = RegExp(r'motolog:(\w+)').firstMatch(raw)?.group(1);
  return switch (key) {
    'not_signed_in' => 'Sign in first.',
    'own_account' => "That's your own account.",
    'email_not_verified' =>
      'Confirm your email address first (open the link we sent you).',
    'invitation_not_found' =>
      'This invitation is no longer available. Ask for a new one.',
    'vehicle_not_found' =>
      "This vehicle isn't in the cloud yet. Synchronize and try again.",
    'transfer_not_found' => 'No transfer with this code. Check the code.',
    'transfer_own' => "This is your own code — send it to the buyer.",
    'transfer_used' => 'This code was already used.',
    'transfer_cancelled' => 'This code was cancelled by the seller.',
    'transfer_expired' =>
      'This code has expired. Ask the seller for a new one.',
    'vehicle_exists' => 'You already have this vehicle.',
    'transfer_rate_limited' => 'Too many tries with codes that don\'t exist. Wait an hour and try again.',
    'quota_exceeded' => cloudFullMessage,
    _ => 'Something went wrong: $raw',
  };
}
