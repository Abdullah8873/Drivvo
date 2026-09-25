import 'dart:convert';

import 'package:drift/drift.dart' show InsertMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../calc/member_access.dart';
import '../cloud/auth_state.dart';
import '../db/app_database.dart';
import 'sharing_api.dart';

/// Which account this device works on: the signed-in user's own data
/// (`null`) or a shared account they joined ([Membership]). One at a time,
/// each with its own local database — see docs/SHARING.md "One active
/// account per device session". Think of it as the "current workspace"
/// context of a multi-tenant web app.

/// The user's own database (`motolog`), opened in `main.dart`. It also
/// holds this device's preferences (settings, the active account), which
/// don't belong to any one account. Null in tests that override
/// `databaseProvider` directly (then switching accounts is off).
final homeDatabaseProvider = Provider<AppDatabase?>((ref) => null);

/// Opens a shared account's local database by name
/// ([Membership.databaseName]); tests return an in-memory one.
final accountDatabaseOpenerProvider = Provider<AppDatabase Function(String)>(
  (ref) =>
      (name) => AppDatabase.named(name, seedDefaults: false),
);

/// The active account saved on this device, loaded before `runApp`.
final initialActiveAccountProvider = Provider<Membership?>((ref) => null);

/// `settings_entries` key of the active account (in the home database).
const activeAccountKey = 'active_account';

/// Reads the saved active account (null = own data).
Future<Membership?> loadActiveAccount(AppDatabase home) async {
  final row = await (home.select(
    home.settingsEntries,
  )..where((s) => s.key.equals(activeAccountKey))).getSingleOrNull();
  if (row == null) return null;
  try {
    return Membership.fromJson(
      (jsonDecode(row.value) as Map).cast<String, Object?>(),
    );
  } catch (_) {
    return null; // unreadable: fall back to own data
  }
}

/// The active account; `ref.read(activeAccountProvider.notifier)` to
/// switch. Falls back to own data when the signed-in user changes (or
/// signs out): a membership belongs to one user.
class ActiveAccountNotifier extends Notifier<Membership?> {
  @override
  Membership? build() {
    ref.listen(authUserIdProvider, (_, next) {
      // Only a resolved value counts (not "still loading").
      if (!next.hasValue) return;
      final current = state;
      if (current != null && next.value != current.memberId) set(null);
    });
    final initial = ref.watch(initialActiveAccountProvider);
    final auth = ref.read(authUserIdProvider);
    if (initial != null && auth.hasValue && auth.value != initial.memberId) {
      Future.microtask(() => set(null));
      return null;
    }
    return initial;
  }

  /// Switches to [account] (null = own data) and remembers it on this
  /// device. Also used to refresh the saved permissions of the active
  /// account (the database stays open when only those change).
  Future<void> set(Membership? account) async {
    state = account;
    final home = ref.read(homeDatabaseProvider);
    if (home == null) return;
    if (account == null) {
      await (home.delete(
        home.settingsEntries,
      )..where((s) => s.key.equals(activeAccountKey))).go();
    } else {
      await home
          .into(home.settingsEntries)
          .insert(
            SettingsEntriesCompanion.insert(
              key: activeAccountKey,
              value: jsonEncode(account.toJson()),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
  }
}

final activeAccountProvider =
    NotifierProvider<ActiveAccountNotifier, Membership?>(
      ActiveAccountNotifier.new,
    );

/// What the signed-in user may do in the active account (everything in
/// their own). UI checks are a convenience; row-level security on the
/// server is the real guard.
final currentAccessProvider = Provider<MemberAccess>(
  (ref) => ref.watch(activeAccountProvider)?.access ?? MemberAccess.owner(),
);
