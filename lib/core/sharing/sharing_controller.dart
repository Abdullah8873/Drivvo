import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/auth_state.dart';
import '../cloud/cloud_config.dart';
import '../sync/sync_controller.dart';
import 'active_account.dart';
import 'sharing_api.dart';
import 'supabase_sharing_api.dart';

/// The sharing RPC client, or null in an offline-only build. Tests
/// override it with `InMemorySharingServer.api(userId)`.
final sharingApiProvider = Provider<SharingApi?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseSharingApi(client);
});

@immutable
class SharingState {
  const SharingState({
    this.available = false,
    this.loading = false,
    this.invitations = const [],
    this.memberships = const [],
    this.error,
  });

  /// Signed in with a cloud: invitations and shared accounts exist.
  final bool available;
  final bool loading;

  /// Invitations waiting for an answer (the banner).
  final List<Invitation> invitations;

  /// Accounts the user joined (the account switcher).
  final List<Membership> memberships;
  final String? error;
}

/// Invitations, joined accounts and account switching for the signed-in
/// user — like a React Query cache of `my_invitations` / `my_memberships`
/// plus the mutations that change them.
///
/// After every refresh it reconciles the active shared account with the
/// server: a membership that is gone (removed, or the user left) wipes
/// that account's local copy and switches back to the user's own data; a
/// changed profile or vehicle assignment re-downloads the account, since
/// rows that became invisible can't be removed by a normal pull.
class SharingController extends Notifier<SharingState> {
  @override
  SharingState build() {
    final userId = ref.watch(authUserIdProvider).value;
    if (userId == null) return const SharingState();
    final SharingApi? api;
    try {
      api = ref.watch(sharingApiProvider);
    } catch (_) {
      // No usable Supabase client (a widget test that fakes a configured
      // build): sharing simply isn't available.
      return const SharingState();
    }
    if (api == null) return const SharingState();
    // A finished sync of a shared account is a good moment to pick up
    // access changes.
    ref.listen(syncControllerProvider, (previous, next) {
      if (previous?.phase == SyncPhase.syncing &&
          next.phase == SyncPhase.idle &&
          next.isShared) {
        refresh();
      }
    });
    Future.microtask(refresh);
    return const SharingState(available: true, loading: true);
  }

  Future<void>? _refreshing;

  /// Reloads invitations and memberships (joins a refresh in flight).
  Future<void> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<void> _refresh() async {
    final api = ref.read(sharingApiProvider);
    if (api == null || !state.available) return;
    try {
      final (invitations, memberships) = await (
        api.myInvitations(),
        api.myMemberships(),
      ).wait;
      if (!ref.mounted) return;
      state = SharingState(
        available: true,
        invitations: invitations,
        memberships: memberships,
      );
      await _reconcile(memberships);
    } catch (e) {
      if (!ref.mounted) return;
      state = SharingState(
        available: true,
        invitations: state.invitations,
        memberships: state.memberships,
        error: _describe(e),
      );
    }
  }

  static String _describe(Object e) {
    if (e is SharingException) return e.message;
    if (e is ParallelWaitError) {
      final errors = e.errors as (AsyncError?, AsyncError?);
      final first = errors.$1?.error ?? errors.$2?.error;
      if (first is SharingException) return first.message;
    }
    return e.toString();
  }

  Future<void> _reconcile(List<Membership> memberships) async {
    final active = ref.read(activeAccountProvider);
    if (active == null) return;
    final current = memberships
        .where(
          (m) => m.ownerId == active.ownerId && m.memberId == active.memberId,
        )
        .firstOrNull;
    if (current == null) {
      await _wipeActive(active.ownerId);
      if (ref.mounted) await ref.read(activeAccountProvider.notifier).set(null);
      return;
    }
    if (current.scopeKey != active.scopeKey) {
      final sync = ref.read(syncControllerProvider.notifier);
      // Upload what is still pending under the old rules first.
      await sync.syncNow();
      if (!ref.mounted) return;
      await _wipeActive(active.ownerId);
      if (!ref.mounted) return;
      await ref.read(activeAccountProvider.notifier).set(current);
      await sync.syncNow();
    } else if (current.ownerName != active.ownerName ||
        current.profile.name != active.profile.name) {
      await ref.read(activeAccountProvider.notifier).set(current);
    }
  }

  /// Empties the active shared account's local database.
  Future<void> _wipeActive(String ownerId) async {
    final engine = ref.read(syncEngineProvider);
    if (engine == null || engine.db.seedDefaults) return; // never own data
    await engine.adoptAccount(ownerId, keepLocalData: false);
  }

  /// Accepts [invitation]; returns the joined account (null if the server
  /// didn't list it yet). Throws [SharingException].
  Future<Membership?> accept(Invitation invitation) async {
    final api = ref.read(sharingApiProvider);
    if (api == null) return null;
    await api.acceptInvitation(invitation);
    await refresh();
    return state.memberships
        .where((m) => m.ownerId == invitation.ownerId)
        .firstOrNull;
  }

  /// Declines [invitation]. Throws [SharingException].
  Future<void> decline(Invitation invitation) async {
    final api = ref.read(sharingApiProvider);
    if (api == null) return;
    await api.declineInvitation(invitation);
    await refresh();
  }

  /// Works on [account] from now on (null = the user's own data). The
  /// database, every screen and the sync switch over; the new account
  /// syncs right away.
  Future<void> switchTo(Membership? account) =>
      ref.read(activeAccountProvider.notifier).set(account);

  /// Leaves [account]; when it is the active one, its local copy is wiped
  /// and the user's own data becomes active. Throws [SharingException].
  Future<void> leave(Membership account) async {
    final api = ref.read(sharingApiProvider);
    if (api == null) return;
    await api.leaveAccount(account.ownerId);
    await refresh();
  }
}

final sharingControllerProvider =
    NotifierProvider<SharingController, SharingState>(SharingController.new);
