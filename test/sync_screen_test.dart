import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/app.dart';
import 'package:motolog/core/cloud/auth_state.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/providers.dart';
import 'package:motolog/core/sync/in_memory_remote_store.dart';
import 'package:motolog/core/sync/sync_controller.dart';
import 'package:motolog/core/sync/sync_engine.dart';

import 'helpers.dart';

void main() {
  late AppDatabase db;
  late InMemoryRemoteStore cloud;
  setUp(() {
    db = testDatabase();
    cloud = InMemoryRemoteStore();
  });
  tearDown(() => db.close());

  /// The app with a fake cloud; [userId] null = signed out, [cloudBuild]
  /// false = a build without cloud config (like every other widget test).
  Widget app({String? userId, bool cloudBuild = true}) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      autoSyncProvider.overrideWithValue(false),
      if (cloudBuild) remoteStoreProvider.overrideWithValue(cloud),
      authUserIdProvider.overrideWith((ref) => Stream.value(userId)),
    ],
    child: const MotoLogApp(),
  );

  Future<void> openSync(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Synchronize data'));
    await tester.pumpAndSettle();
  }

  testWidgets('offline-only build explains sync is not configured', (
    tester,
  ) async {
    await openSync(tester, app(cloudBuild: false));
    expect(find.text('Cloud sync is not available'), findsOneWidget);
    expect(find.text('SYNC NOW'), findsNothing);
    expect(find.text('SIGN IN'), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('signed out: sync is optional, with a sign-in button', (
    tester,
  ) async {
    await openSync(tester, app());
    expect(find.text('Sync is optional'), findsOneWidget);
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text('SYNC NOW'), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('signed in: sync now uploads and shows the last sync', (
    tester,
  ) async {
    await openSync(tester, app(userId: 'u1'));
    expect(find.text('Never'), findsOneWidget);
    expect(find.text('SYNC NOW'), findsOneWidget);

    await tester.tap(find.text('SYNC NOW'));
    await tester.pumpAndSettle();
    expect(find.text('Up to date'), findsOneWidget);
    expect(find.text('Never'), findsNothing);
    expect(cloud.rows('catalog_items', 'u1'), isNotEmpty);
    await unmountApp(tester);
  });

  testWidgets('signed in: a failed sync shows the error', (tester) async {
    cloud.beforePull = (_, _) => throw Exception('No connection');
    await openSync(tester, app(userId: 'u1'));
    await tester.tap(find.text('SYNC NOW'));
    await tester.pumpAndSettle();
    expect(find.text('Last sync failed'), findsOneWidget);
    expect(find.text('No connection'), findsOneWidget);
    await unmountApp(tester);
  });

  group('another account synced here before', () {
    setUp(() async {
      await SyncEngine(db, cloud).sync('u0');
      await addTestVehicle(db, name: 'Old account bike');
    });

    testWidgets('asks, and "add" merges this device into the account', (
      tester,
    ) async {
      await openSync(tester, app(userId: 'u1'));
      expect(find.text('Another account used this device'), findsOneWidget);

      await tester.tap(find.text("ADD THIS DEVICE'S DATA TO THE ACCOUNT"));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Up to date'), findsOneWidget);
      expect(cloud.rows('vehicles', 'u1').map((r) => r['name']), [
        'Old account bike',
      ]);
      await unmountApp(tester);
    });

    testWidgets('"replace" swaps local data for the account\'s', (
      tester,
    ) async {
      await openSync(tester, app(userId: 'u1'));
      await tester.tap(find.text("REPLACE WITH THE ACCOUNT'S DATA"));
      await tester.pumpAndSettle();
      expect(find.text('Up to date'), findsOneWidget);
      expect(cloud.rows('vehicles', 'u1'), isEmpty);
      final vehicles = await tester.runAsync(
        () => db.select(db.vehicles).get(),
      );
      expect(vehicles, isEmpty);
      await unmountApp(tester);
    });
  });
}
