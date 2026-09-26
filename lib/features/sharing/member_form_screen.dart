import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/calc/access_profile.dart';
import '../../core/db/app_database.dart';
import '../../core/providers.dart';
import '../../core/sharing/active_account.dart';
import '../../core/sharing/sharing_api.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/max_width_body.dart';
import 'sharing_queries.dart';
import 'sharing_widgets.dart';
import 'users_screen.dart';

/// Invite a user (`/users/new`) or change a member's profile and vehicles
/// (`/users/<id>`). Invitations are not emailed (no SMTP, owner decision):
/// the invited person sees them when they sign in, and SHARE sends them a
/// short note.
class MemberFormScreen extends ConsumerStatefulWidget {
  const MemberFormScreen({super.key, this.id});

  /// null = new invitation.
  final String? id;

  @override
  ConsumerState<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends ConsumerState<MemberFormScreen> {
  final _email = TextEditingController();
  String _profileId = BuiltInProfile.driver.id;
  Set<String> _vehicleIds = {};
  AccountMember? _member;
  bool _loading = true;
  bool _saving = false;
  String? _emailError;

  bool get _isNew => widget.id == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.id;
    if (id != null) {
      final m = await ref.read(databaseProvider).getMember(id);
      if (m != null) {
        _member = m;
        _email.text = m.email;
        _profileId = m.profileId;
        _vehicleIds = Membership.parseVehicleIds(m.vehicleIds);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    final email = _email.text.trim().toLowerCase();
    if (_isNew) {
      if (!_emailPattern.hasMatch(email)) {
        setState(() => _emailError = 'Enter a valid email address');
        return;
      }
      if (await db.memberEmailTaken(email)) {
        setState(() => _emailError = 'This address is already invited');
        return;
      }
    }
    setState(() {
      _emailError = null;
      _saving = true;
    });
    final scoped = _selectedProfile?.vehicleScope == VehicleScope.assigned;
    final vehicles = scoped ? _vehicleIds : <String>{};
    if (_isNew) {
      await db.inviteMember(
        email: email,
        profileId: _profileId,
        vehicleIds: vehicles,
      );
    } else {
      await db.updateMember(
        widget.id!,
        profileId: _profileId,
        vehicleIds: vehicles,
      );
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (_isNew) await _offerShare(email);
    if (mounted) context.pop();
  }

  String _inviteText(String email) {
    final owner = ref.read(activeAccountProvider)?.ownerName;
    final profile = _selectedProfile?.name ?? '';
    return 'You are invited to ${owner == null ? 'my' : "$owner's"} vehicles '
        'on MotoLog as $profile. Sign in to MotoLog with $email '
        '(More → My account) and accept the invitation.';
  }

  Future<void> _offerShare(String email) async {
    final share = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invitation saved'),
        content: Text(
          'When $email signs in to MotoLog, they will be asked to accept '
          'it. Send them a note so they know?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('NOT NOW'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('SHARE'),
          ),
        ],
      ),
    );
    if (share == true) await ref.read(textSharerProvider)(_inviteText(email));
  }

  Future<void> _remove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove user?'),
        content: const Text(
          'They lose access to this account on their next sync. Records '
          'they added stay here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(databaseProvider).removeMember(widget.id!);
    if (mounted) context.pop();
  }

  AccessProfile? get _selectedProfile => ref
      .read(allProfilesProvider)
      .where((p) => p.id == _profileId)
      .firstOrNull;

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(currentAccessProvider);
    final profiles = ref.watch(allProfilesProvider);
    final vehicles = ref.watch(vehiclesProvider).value ?? const <Vehicle>[];
    final selected = profiles.where((p) => p.id == _profileId).firstOrNull;
    final member = _member;
    final canRemove =
        !_isNew && access.can(AccessArea.users, AccessAction.delete);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Invite user' : 'User'),
        actions: [
          if (!_isNew && member?.status == MemberStatus.pending)
            IconButton(
              tooltip: 'Share invitation',
              icon: const Icon(Icons.share),
              onPressed: () =>
                  ref.read(textSharerProvider)(_inviteText(member!.email)),
            ),
          if (canRemove)
            IconButton(
              tooltip: 'Remove user',
              icon: const Icon(Icons.person_remove_outlined),
              onPressed: _remove,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : MaxWidthBody(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (member?.memberName?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        member!.memberName!,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  TextField(
                    key: const Key('member-email'),
                    controller: _email,
                    readOnly: !_isNew,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      errorText: _emailError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: const Key('member-profile'),
                    initialValue: profiles.any((p) => p.id == _profileId)
                        ? _profileId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Profile',
                      prefixIcon: Icon(Icons.manage_accounts_outlined),
                    ),
                    items: [
                      for (final p in profiles)
                        DropdownMenuItem(value: p.id, child: Text(p.name)),
                    ],
                    onChanged: (id) => setState(() => _profileId = id!),
                  ),
                  if (selected?.vehicleScope == VehicleScope.assigned) ...[
                    const SizedBox(height: 24),
                    Text(
                      'ASSIGNED VEHICLES',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (vehicles.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No vehicles yet.'),
                      ),
                    for (final v in vehicles)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _vehicleIds.contains(v.id),
                        title: Text(v.name),
                        onChanged: (on) => setState(() {
                          _vehicleIds = {..._vehicleIds};
                          on == true
                              ? _vehicleIds.add(v.id)
                              : _vehicleIds.remove(v.id);
                        }),
                      ),
                  ],
                  const SizedBox(height: 32),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: _saving ? null : _save,
                    child: Text(_isNew ? 'INVITE' : 'SAVE'),
                  ),
                ],
              ),
            ),
    );
  }
}
