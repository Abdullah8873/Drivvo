/// What the signed-in user may do in the account that is active on this
/// device — pure Dart, built on [AccessProfile], and the single source of
/// the sharing rules for both the UI (hiding buttons) and the in-memory
/// server used by tests (which mirrors `public.can_access` in
/// `supabase/migrations/20260926000001_sharing.sql`).
///
/// The account owner may do everything ([MemberAccess.owner]). A member's
/// rights come from their profile plus, for the "assigned vehicles" scope,
/// the vehicles the owner assigned to them.
library;

import 'access_profile.dart';

class MemberAccess {
  const MemberAccess({
    required this.profile,
    required this.memberId,
    this.vehicleIds = const {},
  });

  /// The account owner: everything is allowed.
  factory MemberAccess.owner() =>
      MemberAccess(profile: AccessProfile.administrator(), memberId: null);

  final AccessProfile profile;

  /// The member's user id; null for the account owner.
  final String? memberId;

  /// Vehicles assigned to the member (only used by [VehicleScope.assigned]).
  final Set<String> vehicleIds;

  bool get isOwner => memberId == null;

  /// Whether [action] is allowed on [area] at all (ignoring vehicle and
  /// record scope) — e.g. whether to offer "Register" in the + menu.
  bool can(AccessArea area, AccessAction action) =>
      isOwner || profile.can(area, action);

  /// Whether records of [vehicleId] are visible.
  bool canSeeVehicle(String vehicleId) =>
      isOwner ||
      profile.vehicleScope == VehicleScope.all ||
      vehicleIds.contains(vehicleId);

  /// A vehicle row: drivers can always *view* the vehicles in their scope;
  /// changing vehicles needs the Vehicles (administration) switch too.
  bool canVehicle(AccessAction action, String vehicleId) {
    if (!canSeeVehicle(vehicleId)) return false;
    return action == AccessAction.view || can(AccessArea.vehicles, action);
  }

  /// A record of module [area] on [vehicleId] created by [createdBy].
  ///
  /// [createdBy] null counts as the member's own record: on a device, a
  /// record without `created_by` hasn't been uploaded yet, so this user
  /// made it (the server passes `coalesce(created_by, owner_id)` instead,
  /// which is never null).
  bool canRecord(
    AccessArea area,
    AccessAction action, {
    required String vehicleId,
    String? createdBy,
  }) {
    if (isOwner) return true;
    if (!can(area, action) || !canSeeVehicle(vehicleId)) return false;
    return profile.recordScope == RecordScope.all ||
        createdBy == null ||
        createdBy == memberId;
  }

  /// The permission areas shown under More → Administration that this
  /// user can at least view.
  bool get canAdminister => [
    AccessArea.vehicles,
    AccessArea.users,
    AccessArea.profiles,
    AccessArea.forms,
  ].any((a) => can(a, AccessAction.view));
}
