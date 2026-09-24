import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/auth_state.dart';
import '../cloud/cloud_config.dart';
import '../providers.dart';
import 'remote_store.dart';
import 'remote_file_store.dart';
import 'supabase_remote_file_store.dart';
import 'supabase_remote_store.dart';
import 'sync_engine.dart';

/// The cloud API client, or null in an offline-only build. Tests override it
/// with an `InMemoryRemoteStore`.
final remoteStoreProvider = Provider<RemoteStore?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseRemoteStore(client);
});

/// The sync engine for this app's database, or null without a cloud.
final syncEngineProvider = Provider<SyncEngine?>((ref) {
  final remote = ref.watch(remoteStoreProvider);
  if (remote == null) return null;
  return SyncEngine(
    ref.watch(databaseProvider),
    remote,
    files: ref.watch(remoteFileStoreProvider),
  );
});

/// Attachment file storage (Supabase Storage), or null in an offline-only
/// build — then attachments stay on this device. Tests override it with an
/// `InMemoryRemoteFileStore`.
final remoteFileStoreProvider = Provider<RemoteFileStore?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseRemoteFileStore(client);
});

/// Whether sync runs by itself (on sign-in, on app resume and a few seconds
/// after local edits). Widget tests override it with `false` so no timers or
/// lifecycle listeners are left behind.
final autoSyncProvider = Provider<bool>((ref) => true);

/// Delay between the last local edit and the automatic sync it triggers
/// (overridable so tests don't have to wait).
final autoSyncDebounceProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 5),
);

enum SyncPhase {
  /// This build has no cloud config: sync doesn't exist.
  unavailable,

  /// Nobody is signed in: nothing syncs, local data stays as it is.
  signedOut,

  /// Signed in and not syncing right now.
  idle,

  /// A sync is running.
  syncing,

  /// Another account synced on this device before; the user must choose
  /// to keep or replace the local data ([SyncController.resolveAccountSwitch]).
  needsDecision,

  /// The last sync failed ([SyncStatus.error] says why). The next sync
  /// retries from where it stopped.
  error,
}

/// What the "Synchronize data" screen shows — the sync controller's state
/// (think of it as the `{ status, error, data }` of a React Query mutation).
@immutable
class SyncStatus {
  const SyncStatus({
    required this.phase,
    this.userId,
    this.lastSyncedAt,
    this.error,
  });

  final SyncPhase phase;

  /// Signed-in user (null when [SyncPhase.unavailable] / [SyncPhase.signedOut]).
  final String? userId;

  /// When this user last completed a sync on this device.
  final DateTime? lastSyncedAt;

  /// Human-readable reason of the last failure.
  final String? error;

  bool get isSyncing => phase == SyncPhase.syncing;

  SyncStatus copyWith({SyncPhase? phase, DateTime? lastSyncedAt}) => SyncStatus(
    phase: phase ?? this.phase,
    userId: userId,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    error: null,
  );
}

/// Runs the sync for the signed-in user and exposes its [SyncStatus].
///
/// Inert without a cloud config or while signed out — then it holds no
/// listeners at all, so the app (and its tests) behave exactly as before.
/// Signing out rebuilds it into [SyncPhase.signedOut]: syncing stops and
/// the local data is kept.
class SyncController extends Notifier<SyncStatus> {
  Future<void>? _running;

  @override
  SyncStatus build() {
    final engine = ref.watch(syncEngineProvider);
    if (engine == null) return const SyncStatus(phase: SyncPhase.unavailable);
    final userId = ref.watch(authUserIdProvider).value;
    if (userId == null) return const SyncStatus(phase: SyncPhase.signedOut);

    final auto = ref.watch(autoSyncProvider);
    if (auto) _startAutoSync(engine);
    // Read the saved state (and sync, when automatic) once built.
    Future.microtask(() => _load(engine, userId, syncAfter: auto));
    return SyncStatus(phase: SyncPhase.idle, userId: userId);
  }

  /// Syncs now (no-op while one is already running, signed out, or waiting
  /// for the account decision). Errors end up in [SyncStatus.error].
  Future<void> syncNow() {
    final running = _running;
    if (running != null) return running;
    final future = _sync();
    _running = future;
    return future.whenComplete(() {
      if (identical(_running, future)) _running = null;
    });
  }

  /// Answers [SyncPhase.needsDecision]: merge this device's data into the
  /// signed-in account ([keepLocalData]) or replace it with the account's.
  Future<void> resolveAccountSwitch({required bool keepLocalData}) async {
    final engine = ref.read(syncEngineProvider);
    final userId = state.userId;
    if (engine == null || userId == null) return;
    state = state.copyWith(phase: SyncPhase.syncing);
    try {
      await engine.adoptAccount(userId, keepLocalData: keepLocalData);
    } catch (e) {
      if (_isCurrent(userId)) state = _failed(e);
      return;
    }
    if (!_isCurrent(userId)) return;
    state = state.copyWith(phase: SyncPhase.idle);
    await syncNow();
  }

  Future<void> _load(
    SyncEngine engine,
    String userId, {
    required bool syncAfter,
  }) async {
    try {
      final match = await engine.checkAccount(userId);
      final last = await engine.lastSyncedAt(userId);
      if (!_isCurrent(userId)) return;
      state = SyncStatus(
        phase: match == AccountMatch.differentUser
            ? SyncPhase.needsDecision
            : state.phase,
        userId: userId,
        lastSyncedAt: last,
        error: state.error,
      );
      if (syncAfter && state.phase == SyncPhase.idle) await syncNow();
    } catch (e) {
      if (_isCurrent(userId)) state = _failed(e);
    }
  }

  Future<void> _sync() async {
    final engine = ref.read(syncEngineProvider);
    final userId = state.userId;
    if (engine == null ||
        userId == null ||
        state.phase == SyncPhase.needsDecision) {
      return;
    }
    state = state.copyWith(phase: SyncPhase.syncing);
    try {
      await engine.sync(userId);
      final last = await engine.lastSyncedAt(userId);
      if (!_isCurrent(userId)) return;
      state = state.copyWith(phase: SyncPhase.idle, lastSyncedAt: last);
    } on SyncAccountMismatch {
      if (_isCurrent(userId)) {
        state = state.copyWith(phase: SyncPhase.needsDecision);
      }
    } catch (e) {
      if (_isCurrent(userId)) state = _failed(e);
    }
  }

  SyncStatus _failed(Object e) => SyncStatus(
    phase: SyncPhase.error,
    userId: state.userId,
    lastSyncedAt: state.lastSyncedAt,
    error: _describe(e),
  );

  static String _describe(Object e) {
    final text = e.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  /// False once the provider was rebuilt (other user / signed out) or
  /// disposed, so a slow sync can't overwrite the newer state.
  bool _isCurrent(String userId) => ref.mounted && state.userId == userId;

  void _startAutoSync(SyncEngine engine) {
    final db = engine.db;
    final delay = ref.watch(autoSyncDebounceProvider);
    Timer? debounce;
    // Local edits: sync a few seconds after the last one, if anything is
    // actually waiting in the outbox (rows written by the sync itself also
    // notify, but leave nothing queued).
    final sub = db
        .tableUpdates(TableUpdateQuery.onAllTables(engine.tables))
        .listen((_) {
          debounce?.cancel();
          debounce = Timer(delay, () async {
            if (!ref.mounted) return;
            if (await engine.hasPendingChanges() && ref.mounted) {
              await syncNow();
            }
          });
        });
    final lifecycle = AppLifecycleListener(onResume: () => syncNow());
    ref.onDispose(() {
      debounce?.cancel();
      sub.cancel();
      lifecycle.dispose();
    });
  }
}

/// Sync status + actions: `ref.watch(syncControllerProvider)` for the
/// status, `ref.read(syncControllerProvider.notifier).syncNow()` to sync.
final syncControllerProvider = NotifierProvider<SyncController, SyncStatus>(
  SyncController.new,
);
