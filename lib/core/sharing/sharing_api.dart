import 'dart:convert';

import '../calc/access_profile.dart';
import '../calc/member_access.dart';
import '../calc/transfer_code.dart';

/// A user-facing error from a sharing call ("This code has expired") —
/// screens show [message] as is.
class SharingException implements Exception {
  const SharingException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// `<Owner> invited you to their account as <profile>` — a pending
/// `account_members` row addressed to the signed-in user's email.
class Invitation {
  const Invitation({
    required this.ownerId,
    required this.id,
    required this.ownerName,
    required this.profileName,
  });

  final String ownerId;

  /// The `account_members` row id.
  final String id;
  final String ownerName;
  final String profileName;
}

/// An account the signed-in user joined (an active membership), with the
/// permissions that apply to them there.
class Membership {
  const Membership({
    required this.ownerId,
    required this.memberId,
    required this.ownerName,
    required this.profile,
    this.vehicleIds = const {},
  });

  factory Membership.fromJson(Map<String, Object?> json) {
    final profileId = json['profileId'] as String? ?? '';
    final profileName = json['profileName'] as String? ?? '';
    final perms = json['permissions'];
    return Membership(
      ownerId: json['ownerId']! as String,
      memberId: json['memberId']! as String,
      ownerName: json['ownerName'] as String? ?? '',
      profile:
          AccessProfile.builtInById(profileId) ??
          AccessProfile.fromPermissionsJson(
            id: profileId,
            name: profileName,
            json: perms is Map
                ? perms.cast<String, Object?>()
                : perms is String && perms.isNotEmpty
                ? (jsonDecode(perms) as Map).cast<String, Object?>()
                : const {},
          ),
      vehicleIds: parseVehicleIds(json['vehicleIds']),
    );
  }

  final String ownerId;

  /// The signed-in user's id (the member).
  final String memberId;
  final String ownerName;
  final AccessProfile profile;
  final Set<String> vehicleIds;

  MemberAccess get access => MemberAccess(
    profile: profile,
    memberId: memberId,
    vehicleIds: vehicleIds,
  );

  /// Local database of this account on this device. Per member too, so a
  /// second person signing in on the same device never sees the first
  /// one's cached (possibly broader) data.
  String get databaseName => 'motolog_acct_${ownerId}_$memberId';

  /// Anything that changes which rows the member may see: when it differs
  /// from the copy the local database was downloaded with, the device
  /// re-downloads the account (rows that became invisible can't be
  /// "deleted" by a pull).
  String get scopeKey => jsonEncode({
    'profile': profile.id,
    'perms': profile.permissionsToJson(),
    'vehicles': (vehicleIds.toList()..sort()),
  });

  Map<String, Object?> toJson() => {
    'ownerId': ownerId,
    'memberId': memberId,
    'ownerName': ownerName,
    'profileId': profile.id,
    'profileName': profile.name,
    'permissions': profile.permissionsToJson(),
    'vehicleIds': vehicleIds.toList()..sort(),
  };

  /// JSON text for `account_members.vehicle_ids`.
  static String encodeVehicleIds(Iterable<String> ids) =>
      jsonEncode(ids.toList()..sort());

  /// `account_members.vehicle_ids` (JSON array text, or a decoded list).
  static Set<String> parseVehicleIds(Object? raw) {
    Object? list = raw;
    if (raw is String) {
      try {
        list = jsonDecode(raw);
      } on FormatException {
        return const {};
      }
    }
    return list is List ? {for (final v in list) v.toString()} : const {};
  }
}

enum TransferStatus { pending, redeemed, expired, cancelled }

/// A transfer code the signed-in user generated.
class TransferInfo {
  const TransferInfo({
    required this.code,
    required this.vehicleId,
    required this.vehicleName,
    required this.createdAt,
    required this.expiresAt,
    this.redeemedAt,
    this.cancelledAt,
  });

  /// Normalized (`K7QM3XPD`); show it with [TransferCode.format].
  final String code;
  final String vehicleId;
  final String vehicleName;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? redeemedAt;
  final DateTime? cancelledAt;

  TransferStatus statusAt(DateTime now) {
    if (redeemedAt != null) return TransferStatus.redeemed;
    if (cancelledAt != null) return TransferStatus.cancelled;
    if (!now.isBefore(expiresAt)) return TransferStatus.expired;
    return TransferStatus.pending;
  }

  String get displayCode => TransferCode.format(code);
}

/// What `redeem_transfer` copied into the buyer's account.
class RedeemedTransfer {
  const RedeemedTransfer({required this.vehicleId, required this.vehicleName});

  final String vehicleId;
  final String vehicleName;
}

/// The server calls behind Users (invitations), account switching and
/// Transfer — Postgres functions in
/// `supabase/migrations/20260926000001_sharing.sql`, called as RPCs (like
/// a small REST API client). [SupabaseSharingApi] is the real one;
/// `InMemorySharingApi` backs tests. Every method throws [SharingException]
/// with a message the UI can show.
abstract interface class SharingApi {
  /// Pending invitations for the signed-in user's (verified) email.
  Future<List<Invitation>> myInvitations();

  Future<void> acceptInvitation(Invitation invitation);

  Future<void> declineInvitation(Invitation invitation);

  /// Accounts the signed-in user is an active member of.
  Future<List<Membership>> myMemberships();

  /// Leaves [ownerId]'s account (the membership becomes `removed`).
  Future<void> leaveAccount(String ownerId);

  /// Creates a transfer code for one of the signed-in user's vehicles
  /// (already uploaded to the cloud).
  Future<TransferInfo> createTransfer(String vehicleId);

  /// Codes the signed-in user generated, newest first.
  Future<List<TransferInfo>> myTransfers();

  Future<void> cancelTransfer(String code);

  /// Copies the vehicle behind [code] (any format) into the signed-in
  /// user's account.
  Future<RedeemedTransfer> redeemTransfer(String code);
}
