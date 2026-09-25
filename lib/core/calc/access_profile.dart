/// Permission model for sharing an account with other users (More → Users /
/// Profiles) — pure Dart, no Flutter imports, so it's unit-testable and can
/// be shared by the UI, the sync layer and the server-side SQL (which stores
/// [AccessProfile.toJson] in a `jsonb` column and checks the same keys).
///
/// Mirrors Drivvo's profile screen (see `docs/SPEC.md` "Users, Profiles,
/// Transfer"): a vehicle scope (all / assigned), a record scope (all / own)
/// and View · Register · Edit · Delete switches per [AccessArea].
library;

/// What a permission switch allows. `register` = create a new record
/// (Drivvo's wording).
enum AccessAction { view, register, edit, delete }

/// Which part of the permission screen an [AccessArea] is listed under.
enum AccessGroup { modules, catalogs, administration }

/// One row of the permission screen. The `name`s of the module areas match
/// `RecordModule` values, and the catalog area names match `CatalogKind`
/// values, so callers can map with `AccessArea.values.byName(...)`.
enum AccessArea {
  refueling(AccessGroup.modules),
  expense(AccessGroup.modules),
  income(AccessGroup.modules),
  service(AccessGroup.modules),
  route(AccessGroup.modules),
  checklist(AccessGroup.modules),
  reminder(AccessGroup.modules),
  reading(AccessGroup.modules),

  /// Reports only have a View switch.
  report(AccessGroup.modules, actions: [AccessAction.view]),

  fuel(AccessGroup.catalogs),
  gasStation(AccessGroup.catalogs),
  place(AccessGroup.catalogs),
  expenseType(AccessGroup.catalogs),
  serviceType(AccessGroup.catalogs),
  incomeType(AccessGroup.catalogs),
  reason(AccessGroup.catalogs),
  paymentMethod(AccessGroup.catalogs),

  vehicles(AccessGroup.administration),
  users(AccessGroup.administration),
  profiles(AccessGroup.administration),
  forms(AccessGroup.administration);

  const AccessArea(this.group, {this.actions = AccessAction.values});

  final AccessGroup group;

  /// The switches shown for this area (all four unless noted).
  final List<AccessAction> actions;
}

/// Vehicle scope: every vehicle in the account, or only those assigned to the
/// member.
enum VehicleScope { all, assigned }

/// Record scope: everyone's records, or only those the member created.
enum RecordScope { all, own }

/// The three fixed profiles every account has. Their ids are deterministic so
/// every device and the server agree on them.
enum BuiltInProfile {
  administrator('builtin:administrator', 'Administrator'),
  manager('builtin:manager', 'Manager'),
  driver('builtin:driver', 'Driver');

  const BuiltInProfile(this.id, this.label);

  final String id;
  final String label;
}

/// A named set of permissions (built-in or custom).
///
/// Custom profiles are editable; built-in ones are fixed ([isBuiltIn]).
/// The account owner is always an administrator regardless of any profile.
class AccessProfile {
  const AccessProfile({
    required this.id,
    required this.name,
    required this.vehicleScope,
    required this.recordScope,
    required this.permissions,
  });

  /// Administrator: all vehicles, all records, every switch on.
  factory AccessProfile.administrator() => _full(BuiltInProfile.administrator);

  /// Manager: same switches as Administrator (verified in Drivvo); what a
  /// manager can't do (delete or transfer the owner's account, remove the
  /// owner) is enforced by ownership, not by the profile.
  factory AccessProfile.manager() => _full(BuiltInProfile.manager);

  /// Driver: assigned vehicles, own records, View + Register + Edit (no
  /// Delete) on modules and catalogs, no Report, no Administration.
  factory AccessProfile.driver() => AccessProfile(
    id: BuiltInProfile.driver.id,
    name: BuiltInProfile.driver.label,
    vehicleScope: VehicleScope.assigned,
    recordScope: RecordScope.own,
    permissions: {
      for (final area in AccessArea.values)
        if (area.group != AccessGroup.administration &&
            area != AccessArea.report)
          area: const {
            AccessAction.view,
            AccessAction.register,
            AccessAction.edit,
          },
    },
  );

  static AccessProfile _full(BuiltInProfile p) => AccessProfile(
    id: p.id,
    name: p.label,
    vehicleScope: VehicleScope.all,
    recordScope: RecordScope.all,
    permissions: {
      for (final area in AccessArea.values) area: area.actions.toSet(),
    },
  );

  /// All built-in profiles in the order the Profiles screen lists them.
  static List<AccessProfile> get builtIns => [
    AccessProfile.administrator(),
    AccessProfile.manager(),
    AccessProfile.driver(),
  ];

  /// A built-in profile by id, or `null` for a custom id.
  static AccessProfile? builtInById(String id) {
    for (final p in builtIns) {
      if (p.id == id) return p;
    }
    return null;
  }

  final String id;
  final String name;
  final VehicleScope vehicleScope;
  final RecordScope recordScope;

  /// Switches that are on, per area. Missing area = nothing allowed.
  final Map<AccessArea, Set<AccessAction>> permissions;

  bool get isBuiltIn => builtInById(id) != null;

  /// Whether [action] is allowed on [area]. Any action other than view
  /// also requires view (a member can't edit what they can't see), and an
  /// action the area doesn't offer (e.g. deleting a report) is never allowed.
  bool can(AccessArea area, AccessAction action) {
    if (!area.actions.contains(action)) return false;
    final granted = permissions[area] ?? const {};
    return granted.contains(action) && granted.contains(AccessAction.view);
  }

  /// How many switches are on for [area] (the little dots on the row).
  int grantedCount(AccessArea area) =>
      (permissions[area] ?? const {}).where(area.actions.contains).length;

  AccessProfile copyWith({
    String? id,
    String? name,
    VehicleScope? vehicleScope,
    RecordScope? recordScope,
    Map<AccessArea, Set<AccessAction>>? permissions,
  }) => AccessProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    vehicleScope: vehicleScope ?? this.vehicleScope,
    recordScope: recordScope ?? this.recordScope,
    permissions: permissions ?? this.permissions,
  );

  /// Returns a copy with [action] on [area] switched [on]. Turning view off
  /// clears the other switches too; turning any other switch on also turns
  /// view on — like Drivvo's switches, the stored state is always coherent.
  AccessProfile toggled(AccessArea area, AccessAction action, bool on) {
    if (!area.actions.contains(action)) return this;
    final next = {...(permissions[area] ?? const <AccessAction>{})};
    if (on) {
      next
        ..add(action)
        ..add(AccessAction.view);
    } else if (action == AccessAction.view) {
      next.clear();
    } else {
      next.remove(action);
    }
    return copyWith(permissions: {...permissions, area: next});
  }

  /// JSON stored in the server's `permissions` column, e.g.
  /// `{"vehicleScope":"assigned","recordScope":"own",
  ///   "areas":{"refueling":["view","register","edit"]}}`.
  /// Areas with nothing granted are omitted.
  Map<String, Object?> permissionsToJson() => {
    'vehicleScope': vehicleScope.name,
    'recordScope': recordScope.name,
    'areas': {
      for (final area in AccessArea.values)
        if ((permissions[area] ?? const {}).isNotEmpty)
          area.name: [
            for (final a in AccessAction.values)
              if (permissions[area]!.contains(a)) a.name,
          ],
    },
  };

  /// Parses [permissionsToJson] output. Unknown areas/actions (from a newer
  /// app version) are ignored; missing scopes default to the most
  /// restrictive value.
  static AccessProfile fromPermissionsJson({
    required String id,
    required String name,
    required Map<String, Object?> json,
  }) {
    T parse<T extends Enum>(List<T> values, Object? raw, T fallback) {
      for (final v in values) {
        if (v.name == raw) return v;
      }
      return fallback;
    }

    final areas = <AccessArea, Set<AccessAction>>{};
    final rawAreas = json['areas'];
    if (rawAreas is Map) {
      for (final entry in rawAreas.entries) {
        final area = AccessArea.values
            .where((a) => a.name == entry.key)
            .firstOrNull;
        if (area == null || entry.value is! List) continue;
        areas[area] = {
          for (final raw in entry.value as List)
            for (final a in AccessAction.values)
              if (a.name == raw && area.actions.contains(a)) a,
        };
      }
    }
    return AccessProfile(
      id: id,
      name: name,
      vehicleScope: parse(
        VehicleScope.values,
        json['vehicleScope'],
        VehicleScope.assigned,
      ),
      recordScope: parse(
        RecordScope.values,
        json['recordScope'],
        RecordScope.own,
      ),
      permissions: areas,
    );
  }
}
