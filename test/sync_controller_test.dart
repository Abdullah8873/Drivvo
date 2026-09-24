import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/cloud/auth_state.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/providers.dart';
import 'package:motolog/core/sync/in_memory_remote_store.dart';
import 'package:motolog/core/sync/sync_controller.dart';

import 'helpers.dart';

/// Auto-sync wiring: on sign-in, after local edits (debounced), and nothing
/// at all once signed out.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late InMemoryRemoteStore cloud;
  late StreamController<String?> auth;
  late ProviderContainer container;

  setUp(() {
    db = testDatabase();
    cloud = InMemoryRemoteStore();
    auth = StreamController<String?>.broadcast();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        remoteStoreProvider.overrideWithValue(cloud),
        authUserIdProvider.overrideWith((ref) => auth.stream),
        autoSyncDebounceProvider.overrideWithValue(
          const Duration(milliseconds: 20),
        ),
      ],
    );
    container.listen(syncControllerProvider, (_, _) {});
  });
  tearDown(() async {
    container.dispose();
    await auth.close();
    await db.close();
  });

  SyncStatus status() => container.read(syncControllerProvider);

  /// Polls until [done] (real async: the database and timers run for real).
  Future<void> waitFor(bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(done(), isTrue);
  }

  test('offline build: unavailable and inert', () {
    final offline = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(offline.dispose);
    expect(offline.read(syncControllerProvider).phase, SyncPhase.unavailable);
  });

  test('syncs on sign-in, after edits, and stops on sign-out', () async {
    expect(status().phase, SyncPhase.signedOut);

    auth.add('u1');
    await waitFor(
      () => status().phase == SyncPhase.idle && status().lastSyncedAt != null,
    );
    expect(cloud.rows('catalog_items', 'u1'), isNotEmpty);

    // A local edit goes up by itself after the debounce.
    await addTestVehicle(db, name: 'Auto');
    await waitFor(() => cloud.rows('vehicles', 'u1').isNotEmpty);

    // Signed out: nothing syncs, local data stays.
    auth.add(null);
    await waitFor(() => status().phase == SyncPhase.signedOut);
    await addTestVehicle(db, name: 'Offline');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(cloud.rows('vehicles', 'u1'), hasLength(1));
    expect(await db.watchVehicles().first, hasLength(2));
  });
}
