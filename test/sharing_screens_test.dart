import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/app.dart';
import 'package:motolog/core/calc/access_profile.dart';
import 'package:motolog/core/cloud/auth_state.dart';
import 'package:motolog/core/cloud/cloud_config.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/db/seed_data.dart';
import 'package:motolog/core/geo/map_tile_provider.dart';
import 'package:motolog/core/sharing/active_account.dart';
import 'package:motolog/core/sharing/in_memory_sharing_api.dart';
import 'package:motolog/core/sharing/sharing_api.dart';
import 'package:motolog/core/sharing/sharing_controller.dart';
import 'package:motolog/core/sync/in_memory_remote_store.dart';
import 'package:motolog/core/sync/remote_file_store.dart';
import 'package:motolog/core/sync/sync_controller.dart';
import 'package:motolog/core/sync/sync_engine.dart';
import 'package:motolog/features/account/auth_service.dart';
import 'package:motolog/features/account/fake_auth_service.dart';
import 'package:motolog/features/refueling/refueling_queries.dart';
import 'package:motolog/features/sharing/sharing_queries.dart';
import 'package:motolog/features/sharing/sharing_widgets.dart';

import 'helpers.dart';

const _owner = 'owner-1';
const _member = 'member-1';

/// Users, Profiles, the invitation banner, account switching, Transfer and
/// permission-driven hiding, against the in-memory cloud.
void main() {
  late InMemoryRemoteStore cloud;
  late InMemorySharingServer server;
  late AppDatabase home;
  late List<String> shared;
  final opened = <AppDatabase>[];

  setUp(() {
    cloud = InMemoryRemoteStore();
    server = InMemorySharingServer(cloud)
      ..users[_owner] = const InMemoryUser(
        email: 'owner@example.com',
        name: 'Olivia Owner',
      )
      ..users[_member] = const InMemoryUser(email: 'member@example.com');
    home = testDatabase();
    shared = [];
    opened.clear();
  });

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
    await tester.runAsync(() async {
      await home.close();
      for (final db in opened) {
        await db.close();
      }
    });
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    String? userId,
    Membership? active,
    AppDatabase? sharedDb,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeDatabaseProvider.overrideWithValue(home),
          accountDatabaseOpenerProvider.overrideWithValue((name) {
            final db = sharedDb ?? testDatabase(seedDefaults: false);
            opened.add(db);
            return db;
          }),
          initialActiveAccountProvider.overrideWithValue(active),
          cloudConfigProvider.overrideWithValue(
            const CloudConfig(
              supabaseUrl: 'https://example.supabase.co',
              supabasePublishableKey: 'sb_publishable_test',
            ),
          ),
          authServiceProvider.overrideWithValue(FakeAuthService()),
          authUserIdProvider.overrideWith((ref) => Stream.value(userId)),
          sharingApiProvider.overrideWithValue(
            userId == null ? null : server.api(userId),
          ),
          remoteStoreProvider.overrideWithValue(
            userId == null ? null : cloud.asUser(userId),
          ),
          remoteFileStoreProvider.overrideWithValue(InMemoryRemoteFileStore()),
          autoSyncProvider.overrideWithValue(false),
          textSharerProvider.overrideWithValue(
            (text) async => shared.add(text),
          ),
          mapTileProviderProvider.overrideWithValue(NoNetworkTileProvider()),
        ],
        child: const MotoLogApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMore(WidgetTester tester, String item) async {
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item));
    await tester.pumpAndSettle();
  }

  testWidgets('Users and Transfer ask signed-out users to sign in', (
    tester,
  ) async {
    await pumpApp(tester);
    await openMore(tester, 'Users');
    expect(find.textContaining('Sign in to invite'), findsOneWidget);
    expect(find.byTooltip('Invite'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sign in to send or receive'), findsOneWidget);
    await close(tester);
  });

  testWidgets('the owner invites a driver with an assigned vehicle', (
    tester,
  ) async {
    final vid = await tester.runAsync(() => addTestVehicle(home, name: 'Van'));
    await pumpApp(tester, userId: _owner);
    await openMore(tester, 'Users');
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Administrator'), findsOneWidget);

    await tester.tap(find.byTooltip('Invite'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('member-email')), 'bad');
    await tester.tap(find.text('INVITE'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('member-email')),
      'Driver@Example.com',
    );
    // Driver (the default) works on assigned vehicles.
    expect(find.text('ASSIGNED VEHICLES'), findsOneWidget);
    await tester.tap(find.text('Van'));
    await tester.tap(find.text('INVITE'));
    await tester.pumpAndSettle();
    expect(find.text('Invitation saved'), findsOneWidget);
    await tester.tap(find.text('SHARE'));
    await tester.pumpAndSettle();
    expect(shared.single, contains('driver@example.com'));

    expect(
      find.text('driver@example.com · Invitation pending'),
      findsOneWidget,
    );
    expect(find.text('Driver'), findsOneWidget);
    final row = (await tester.runAsync(() => home.watchMembers().first))!
        .single;
    expect(row.vehicleIds, '["$vid"]');
    expect(row.profileId, BuiltInProfile.driver.id);
    await close(tester);
  });

  testWidgets('Profiles lists the built-ins and saves a custom profile', (
    tester,
  ) async {
    await pumpApp(tester, userId: _owner);
    await openMore(tester, 'Profiles');
    for (final name in ['Administrator', 'Manager', 'Driver']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.textContaining("fixed and can't be edited"), findsOneWidget);

    // Built-ins open read-only.
    await tester.tap(find.text('Driver'));
    await tester.pumpAndSettle();
    expect(find.text('SAVE'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profile-name')), 'Night');
    await tester.tap(find.text('ALL VEHICLES'));
    await tester.tap(find.byKey(const Key('area-report')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('switch-report-view')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('SAVE'));
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(find.text('Night'), findsOneWidget);
    final saved = (await tester.runAsync(
      () => home.watchCustomProfiles().first,
    ))!.single;
    expect(saved.vehicleScope, VehicleScope.all);
    expect(saved.can(AccessArea.report, AccessAction.view), isTrue);
    // Started from the Driver defaults.
    expect(saved.can(AccessArea.refueling, AccessAction.register), isTrue);
    expect(saved.can(AccessArea.refueling, AccessAction.delete), isFalse);
    await close(tester);
  });

  testWidgets('accepting an invitation switches to the shared account', (
    tester,
  ) async {
    // The owner's device invites the member and syncs.
    await tester.runAsync(() async {
      final ownerDb = testDatabase();
      await ownerDb.inviteMember(
        email: 'member@example.com',
        profileId: BuiltInProfile.driver.id,
        vehicleIds: const {},
      );
      await SyncEngine(ownerDb, cloud).sync(_owner);
      await ownerDb.close();
    });

    await pumpApp(tester, userId: _member);
    expect(find.byKey(const Key('invitation-banner')), findsOneWidget);
    expect(
      find.text('Olivia Owner invited you to their account as Driver.'),
      findsOneWidget,
    );
    await tester.tap(find.text('ACCEPT'));
    await tester.pumpAndSettle();
    expect(find.text("Open Olivia Owner's account?"), findsOneWidget);
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('invitation-banner')), findsNothing);
    // The vehicle chip says whose data this is.
    expect(find.text("Olivia Owner's account"), findsOneWidget);
    final saved = await tester.runAsync(() => loadActiveAccount(home));
    expect(saved!.ownerId, _owner);
    expect(opened, hasLength(1));

    // My account → Account switches back to My data.
    await openMore(tester, 'My account');
    expect(find.byKey(const Key('account-switcher')), findsOneWidget);
    await tester.tap(find.byKey(const Key('account-switcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My data'));
    await tester.pumpAndSettle();
    expect(find.text("Olivia Owner's account"), findsNothing);
    expect(await tester.runAsync(() => loadActiveAccount(home)), isNull);
    await close(tester);
  });

  testWidgets('a driver does not see what their profile hides', (tester) async {
    final sharedDb = testDatabase();
    final ids = await tester.runAsync(() async {
      final vid = await addTestVehicle(sharedDb, name: 'Fleet van');
      final rid = await sharedDb.saveRefueling(
        RefuelingDraft(
          vehicleId: vid,
          date: DateTime(2026, 9, 1),
          odometer: 100,
          lines: [
            FuelLineDraft(
              fuelId: SeedData.idFor(CatalogKind.fuel, 'Petrol'),
              pricePerUnit: 3,
              total: 30,
              volume: 10,
            ),
          ],
        ),
      );
      // Created by the owner (pulled from the cloud).
      await (sharedDb.update(sharedDb.refuelings)
            ..where((r) => r.id.equals(rid)))
          .write(const RefuelingsCompanion(createdBy: Value(_owner)));
      return (vid, rid);
    });
    // The server knows the membership (else the app drops the account).
    cloud.serverWrite('account_members', _owner, {
      'id': 'm1',
      'created_at': '2026-09-01T00:00:00.000Z',
      'updated_at': '2026-09-01T00:00:00.000Z',
      'deleted_at': null,
      'email': 'member@example.com',
      'member_id': _member,
      'member_name': 'Member',
      'profile_id': BuiltInProfile.driver.id,
      'status': 'active',
      'vehicle_ids': Membership.encodeVehicleIds({ids!.$1}),
    });
    final membership = Membership(
      ownerId: _owner,
      memberId: _member,
      ownerName: 'Olivia Owner',
      profile: AccessProfile.driver(),
      vehicleIds: {ids.$1},
    );
    await pumpApp(
      tester,
      userId: _member,
      active: membership,
      sharedDb: sharedDb,
    );
    // Someone else's record: no Edit / Delete.
    await tester.tap(find.byKey(Key('row-${ids.$2}')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('View'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsNothing);
    expect(find.byTooltip('Delete'), findsNothing);

    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(find.textContaining("don't have access to reports"), findsOneWidget);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    for (final hidden in [
      'Users',
      'Profiles',
      'Vehicles',
      'Forms',
      'Transfer',
    ]) {
      expect(find.text(hidden), findsNothing, reason: hidden);
    }
    expect(find.text('Fuel'), findsOneWidget);
    await close(tester);
  });

  testWidgets('Transfer generates a code for a synced vehicle', (tester) async {
    await tester.runAsync(() => addTestVehicle(home, name: 'Sold car'));
    await pumpApp(tester, userId: _owner);
    await openMore(tester, 'Transfer');
    expect(find.textContaining('Did you sell your vehicle?'), findsOneWidget);

    await tester.tap(find.byTooltip('Transfer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate transfer code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sold car'));
    // syncNow + the RPC run on real async I/O (drift).
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Transfer code'), findsOneWidget);
    final code = tester
        .widget<SelectableText>(find.byKey(const Key('transfer-code')))
        .data!;
    expect(code, matches(RegExp(r'^[A-Z2-9]{4}-[A-Z2-9]{4}$')));
    await tester.tap(find.text('SHARE'));
    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
    expect(shared.single, contains(code));
    expect(find.text(code), findsOneWidget);

    // A malformed code is caught before calling the server.
    await tester.tap(find.byTooltip('Transfer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Redeem transfer code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('redeem-code')), 'abc');
    await tester.tap(find.text('REDEEM'));
    await tester.pumpAndSettle();
    expect(find.textContaining('8 letters and digits'), findsOneWidget);
    await close(tester);
  });

  test('sharing controller drops a membership that is gone', () async {
    final container = ProviderContainer(
      overrides: [
        homeDatabaseProvider.overrideWithValue(home),
        accountDatabaseOpenerProvider.overrideWithValue((name) {
          final db = testDatabase(seedDefaults: false);
          opened.add(db);
          return db;
        }),
        initialActiveAccountProvider.overrideWithValue(
          Membership(
            ownerId: _owner,
            memberId: _member,
            ownerName: 'Olivia Owner',
            profile: AccessProfile.driver(),
          ),
        ),
        authUserIdProvider.overrideWith((ref) => Stream.value(_member)),
        sharingApiProvider.overrideWithValue(server.api(_member)),
        remoteStoreProvider.overrideWithValue(cloud.asUser(_member)),
        remoteFileStoreProvider.overrideWithValue(null),
        autoSyncProvider.overrideWithValue(false),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await home.close();
      for (final db in opened) {
        await db.close();
      }
    });
    container.listen(sharingControllerProvider, (_, _) {});
    await container.read(authUserIdProvider.future);
    expect(container.read(activeAccountProvider), isNotNull);
    // Nothing on the server: the refresh finds no membership.
    await container.read(sharingControllerProvider.notifier).refresh();
    expect(container.read(activeAccountProvider), isNull);
    expect(await loadActiveAccount(home), isNull);
  });
}
