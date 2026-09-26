import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/calc/access_profile.dart';
import '../../core/db/app_database.dart';
import '../../core/sharing/sharing_api.dart';

/// Users and custom profiles of the active account (local tables, synced
/// like every other table).
extension SharingQueries on AppDatabase {
  /// Members that still matter (pending, active, declined), by email.
  Stream<List<AccountMember>> watchMembers() {
    return (select(accountMembers)
          ..where(
            (m) =>
                m.deletedAt.isNull() &
                m.status.isNotValue(MemberStatus.removed.name),
          )
          ..orderBy([(m) => OrderingTerm.asc(m.email)]))
        .watch();
  }

  Future<AccountMember?> getMember(String id) =>
      (select(accountMembers)..where((m) => m.id.equals(id))).getSingleOrNull();

  /// A live (not removed) member with [email] other than [exceptId].
  Future<bool> memberEmailTaken(String email, {String? exceptId}) async {
    final rows =
        await (select(accountMembers)..where(
              (m) =>
                  m.deletedAt.isNull() &
                  m.status.isNotValue(MemberStatus.removed.name) &
                  m.email.lower().equals(email.trim().toLowerCase()),
            ))
            .get();
    return rows.any((m) => m.id != exceptId);
  }

  /// Invites [email] (or re-invites a removed/declined address).
  Future<String> inviteMember({
    required String email,
    required String profileId,
    required Set<String> vehicleIds,
  }) async {
    final normalized = email.trim().toLowerCase();
    final old =
        await (select(accountMembers)
              ..where(
                (m) =>
                    m.deletedAt.isNull() & m.email.lower().equals(normalized),
              )
              ..limit(1))
            .getSingleOrNull();
    final now = DateTime.now();
    if (old != null) {
      await (update(accountMembers)..where((m) => m.id.equals(old.id))).write(
        AccountMembersCompanion(
          profileId: Value(profileId),
          vehicleIds: Value(Membership.encodeVehicleIds(vehicleIds)),
          status: const Value(MemberStatus.pending),
          memberId: const Value(null),
          memberName: const Value(null),
          updatedAt: Value(now),
        ),
      );
      return old.id;
    }
    final row = await into(accountMembers).insertReturning(
      AccountMembersCompanion.insert(
        email: normalized,
        profileId: profileId,
        vehicleIds: Value(Membership.encodeVehicleIds(vehicleIds)),
      ),
    );
    return row.id;
  }

  Future<void> updateMember(
    String id, {
    required String profileId,
    required Set<String> vehicleIds,
  }) => (update(accountMembers)..where((m) => m.id.equals(id))).write(
    AccountMembersCompanion(
      profileId: Value(profileId),
      vehicleIds: Value(Membership.encodeVehicleIds(vehicleIds)),
      updatedAt: Value(DateTime.now()),
    ),
  );

  /// Takes the member's access away (they fall back to their own data on
  /// their next sync).
  Future<void> removeMember(String id) =>
      (update(accountMembers)..where((m) => m.id.equals(id))).write(
        AccountMembersCompanion(
          status: const Value(MemberStatus.removed),
          updatedAt: Value(DateTime.now()),
        ),
      );

  // ---- Custom profiles -------------------------------------------------------

  Stream<List<AccessProfile>> watchCustomProfiles() {
    return (select(accessProfiles)
          ..where((p) => p.deletedAt.isNull())
          ..orderBy([(p) => OrderingTerm.asc(p.name.collate(Collate.noCase))]))
        .watch()
        .map((rows) => rows.map(profileFromRow).toList());
  }

  /// A built-in profile, or a live custom one; null when unknown.
  Future<AccessProfile?> getProfile(String id) async {
    final builtIn = AccessProfile.builtInById(id);
    if (builtIn != null) return builtIn;
    final row = await (select(
      accessProfiles,
    )..where((p) => p.id.equals(id) & p.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : profileFromRow(row);
  }

  /// Inserts or updates a custom profile; returns its id.
  Future<String> saveProfile(
    AccessProfile profile, {
    bool isNew = false,
  }) async {
    final permissions = jsonEncode(profile.permissionsToJson());
    if (!isNew) {
      await (update(
        accessProfiles,
      )..where((p) => p.id.equals(profile.id))).write(
        AccessProfilesCompanion(
          name: Value(profile.name),
          permissions: Value(permissions),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return profile.id;
    }
    final row = await into(accessProfiles).insertReturning(
      AccessProfilesCompanion.insert(
        name: profile.name,
        permissions: permissions,
      ),
    );
    return row.id;
  }

  /// Live members using profile [id] (a profile in use can't be deleted).
  Future<int> profileUsage(String id) async {
    final rows =
        await (select(accountMembers)..where(
              (m) =>
                  m.deletedAt.isNull() &
                  m.profileId.equals(id) &
                  m.status.isNotValue(MemberStatus.removed.name),
            ))
            .get();
    return rows.length;
  }

  Future<void> deleteProfile(String id) {
    final now = DateTime.now();
    return (update(accessProfiles)..where((p) => p.id.equals(id))).write(
      AccessProfilesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }
}

AccessProfile profileFromRow(AccessProfileRow row) {
  Map<String, Object?> json;
  try {
    json = (jsonDecode(row.permissions) as Map).cast<String, Object?>();
  } on FormatException {
    json = const {};
  }
  return AccessProfile.fromPermissionsJson(
    id: row.id,
    name: row.name,
    json: json,
  );
}
