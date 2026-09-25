import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/calc/access_profile.dart';
import '../../core/providers.dart';
import '../../core/sharing/active_account.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/max_width_body.dart';
import 'sharing_queries.dart';
import 'sharing_widgets.dart';

/// The profile screen (`/profiles/new`, `/profiles/<id>`): name, vehicle
/// scope, record scope and a row per permission area with a dot per
/// granted switch; tapping a row expands its View · Register · Edit ·
/// Delete switches (docs/SPEC.md "Profile screen"). Built-in profiles
/// open read-only.
class ProfileEditorScreen extends ConsumerStatefulWidget {
  const ProfileEditorScreen({super.key, this.id});

  /// null = new custom profile.
  final String? id;

  @override
  ConsumerState<ProfileEditorScreen> createState() =>
      _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends ConsumerState<ProfileEditorScreen> {
  final _name = TextEditingController();
  AccessProfile? _profile;
  final _expanded = <AccessArea>{};
  bool _loading = true;
  String? _nameError;

  bool get _isNew => widget.id == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.id;
    AccessProfile? p;
    if (id == null) {
      // A new profile starts from the Driver defaults (the common case).
      p = AccessProfile.driver().copyWith(id: '', name: '');
    } else {
      p = await ref.read(databaseProvider).getProfile(id);
    }
    if (!mounted) return;
    setState(() {
      _profile = p;
      _name.text = p?.name ?? '';
      _loading = false;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _readOnly {
    final p = _profile;
    if (p == null || p.isBuiltIn) return true;
    final access = ref.read(currentAccessProvider);
    return !access.can(
      AccessArea.profiles,
      _isNew ? AccessAction.register : AccessAction.edit,
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Enter a name');
      return;
    }
    final taken = AccessProfile.builtIns.any(
      (b) => b.name.toLowerCase() == name.toLowerCase(),
    );
    if (taken) {
      setState(() => _nameError = 'A built-in profile has this name');
      return;
    }
    await ref
        .read(databaseProvider)
        .saveProfile(_profile!.copyWith(name: name), isNew: _isNew);
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final db = ref.read(databaseProvider);
    final used = await db.profileUsage(widget.id!);
    if (!mounted) return;
    if (used > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Profile in use'),
          content: Text(
            '$used ${used == 1 ? 'user has' : 'users have'} this profile. '
            'Give them another profile first.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete profile?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await db.deleteProfile(widget.id!);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    final readOnly = _readOnly;
    final canDelete =
        !_isNew &&
        p != null &&
        !p.isBuiltIn &&
        ref
            .watch(currentAccessProvider)
            .can(AccessArea.profiles, AccessAction.delete);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New profile' : 'Profile'),
        actions: [
          if (canDelete)
            IconButton(
              tooltip: 'Delete profile',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : p == null
          ? const Center(child: Text('This profile no longer exists.'))
          : MaxWidthBody(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  if (p.isBuiltIn)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Built-in profiles are fixed and can't be "
                              'edited.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  TextField(
                    key: const Key('profile-name'),
                    controller: _name,
                    readOnly: readOnly,
                    decoration: InputDecoration(
                      labelText: 'Profile name',
                      errorText: _nameError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ScopeToggle<VehicleScope>(
                    value: p.vehicleScope,
                    enabled: !readOnly,
                    options: const [
                      (VehicleScope.all, 'ALL VEHICLES'),
                      (VehicleScope.assigned, 'ASSIGNED VEHICLES'),
                    ],
                    helper: p.vehicleScope == VehicleScope.all
                        ? 'Can see all vehicles in the fleet.'
                        : 'Can only see vehicles they have access to.',
                    onChanged: (v) =>
                        setState(() => _profile = p.copyWith(vehicleScope: v)),
                  ),
                  const SizedBox(height: 12),
                  _ScopeToggle<RecordScope>(
                    value: p.recordScope,
                    enabled: !readOnly,
                    options: const [
                      (RecordScope.all, 'ALL RECORDS'),
                      (RecordScope.own, 'OWN RECORDS'),
                    ],
                    helper: p.recordScope == RecordScope.all
                        ? 'Can see records from everyone in the account.'
                        : 'Can only see records they created or are linked '
                              'to.',
                    onChanged: (v) =>
                        setState(() => _profile = p.copyWith(recordScope: v)),
                  ),
                  for (final group in AccessGroup.values) ...[
                    const SizedBox(height: 16),
                    Text(
                      switch (group) {
                        AccessGroup.modules => 'MODULES',
                        AccessGroup.catalogs => 'TYPES AND CATEGORIES',
                        AccessGroup.administration =>
                          'ADMINISTRATION · ADMIN AND MANAGER ONLY',
                      },
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    for (final area in AccessArea.values)
                      if (area.group == group)
                        _AreaRow(
                          area: area,
                          profile: p,
                          expanded: _expanded.contains(area),
                          readOnly: readOnly,
                          onExpand: () => setState(
                            () => _expanded.contains(area)
                                ? _expanded.remove(area)
                                : _expanded.add(area),
                          ),
                          onToggle: (action, on) => setState(
                            () => _profile = p.toggled(area, action, on),
                          ),
                        ),
                  ],
                  if (!readOnly) ...[
                    const SizedBox(height: 24),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: _save,
                      child: const Text('SAVE'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _ScopeToggle<T> extends StatelessWidget {
  const _ScopeToggle({
    required this.value,
    required this.options,
    required this.helper,
    required this.enabled,
    required this.onChanged,
  });

  final T value;
  final List<(T, String)> options;
  final String helper;
  final bool enabled;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<T>(
          showSelectedIcon: false,
          segments: [
            for (final (v, label) in options)
              ButtonSegment(
                value: v,
                label: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
              ),
          ],
          selected: {value},
          onSelectionChanged: enabled ? (s) => onChanged(s.single) : null,
        ),
        const SizedBox(height: 4),
        Text(
          helper,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// One permission area: colored dot, label, a dot per switch that is on,
/// chevron; expanded = its switches.
class _AreaRow extends StatelessWidget {
  const _AreaRow({
    required this.area,
    required this.profile,
    required this.expanded,
    required this.readOnly,
    required this.onExpand,
    required this.onToggle,
  });

  final AccessArea area;
  final AccessProfile profile;
  final bool expanded;
  final bool readOnly;
  final VoidCallback onExpand;
  final void Function(AccessAction action, bool on) onToggle;

  @override
  Widget build(BuildContext context) {
    final color = accessAreaColor(area);
    final granted = profile.grantedCount(area);
    return Column(
      children: [
        ListTile(
          key: Key('area-${area.name}'),
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(radius: 6, backgroundColor: color),
          minLeadingWidth: 12,
          title: Text(accessAreaLabel(area)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < area.actions.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: CircleAvatar(
                    radius: 4,
                    backgroundColor: i < granted
                        ? color
                        : color.withValues(alpha: 0.2),
                  ),
                ),
              Icon(expanded ? Icons.expand_less : Icons.expand_more),
            ],
          ),
          onTap: onExpand,
        ),
        if (expanded)
          for (final action in area.actions)
            SwitchListTile(
              key: Key('switch-${area.name}-${action.name}'),
              contentPadding: const EdgeInsets.only(left: 24),
              dense: true,
              title: Text(accessActionLabel(action)),
              value: (profile.permissions[area] ?? const {}).contains(action),
              activeThumbColor: AppTheme.primary,
              onChanged: readOnly ? null : (on) => onToggle(action, on),
            ),
      ],
    );
  }
}
