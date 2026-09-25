import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/calc/access_profile.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/db/seed_data.dart';
import 'package:motolog/core/sharing/in_memory_sharing_api.dart';
import 'package:motolog/core/sharing/sharing_api.dart';
import 'package:motolog/core/sync/in_memory_remote_store.dart';
import 'package:motolog/core/sync/remote_store.dart';
import 'package:motolog/core/sync/sync_engine.dart';
import 'package:motolog/features/readings/reading_queries.dart';
import 'package:motolog/features/refueling/refueling_queries.dart';
import 'package:motolog/features/sharing/sharing_queries.dart';

import 'helpers.dart';

/// An owner shares their account with a member through the fake cloud,
/// whose row-level security mirrors `20260926000001_sharing.sql`.
void main() {
  const owner = 'owner-1';
  const member = 'member-1';
  final petrol = SeedData.idFor(CatalogKind.fuel, 'Petrol');

  late InMemoryRemoteStore cloud;
  late InMemorySharingServer server;
  late AppDatabase ownerDb;
  late AppDatabase memberDb;
  late SyncEngine ownerSync;
  late SyncEngine memberSync;
  late String v1;
  late String v2;

  RefuelingDraft draft(String vid, double odo) => RefuelingDraft(
    vehicleId: vid,
    date: DateTime(2026, 9, 1, 10),
    odometer: odo,
    lines: [
      FuelLineDraft(fuelId: petrol, pricePerUnit: 3, total: 30, volume: 10),
    ],
  );

  /// Owner invites [member] with [profileId]; the member accepts.
  Future<Membership> join(
    String profileId, {
    Set<String> vehicles = const {},
  }) async {
    await ownerDb.inviteMember(
      email: 'Member@Example.com',
      profileId: profileId,
      vehicleIds: vehicles,
    );
    await ownerSync.sync(owner);
    final api = server.api(member);
    final invitations = await api.myInvitations();
    expect(invitations, hasLength(1));
    expect(invitations.single.ownerName, 'Olivia Owner');
    await api.acceptInvitation(invitations.single);
    return (await api.myMemberships()).single;
  }

  Future<List<String>> ids(AppDatabase db, TableInfo table) async => [
    for (final r
        in await db
            .customSelect(
              'SELECT id FROM ${table.actualTableName} '
              'WHERE deleted_at IS NULL ORDER BY id',
            )
            .get())
      r.read<String>('id'),
  ];

  setUp(() async {
    cloud = InMemoryRemoteStore();
    server = InMemorySharingServer(cloud)
      ..users[owner] = const InMemoryUser(
        email: 'owner@example.com',
        name: 'Olivia Owner',
      )
      ..users[member] = const InMemoryUser(email: 'member@example.com');
    ownerDb = testDatabase();
    memberDb = testDatabase(seedDefaults: false);
    ownerSync = SyncEngine(ownerDb, cloud);
    memberSync = SyncEngine(memberDb, cloud.asUser(member));
    v1 = await addTestVehicle(ownerDb, name: 'Assigned');
    v2 = await addTestVehicle(ownerDb, name: 'Other');
    await ownerDb.saveRefueling(draft(v1, 100));
    await ownerDb.saveRefueling(draft(v2, 200));
  });
  tearDown(() async {
    await ownerDb.close();
    await memberDb.close();
  });

  test('a stranger sees nothing and can write nothing', () async {
    await ownerSync.sync(owner);
    await memberSync.sync(owner, shared: true);
    expect(await ids(memberDb, memberDb.vehicles), isEmpty);
    expect(
      () => cloud.asUser(member).push('vehicles', owner, [
        {
          'id': 'x',
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-01T00:00:00.000Z',
          'name': 'Mine now',
          'type': 'car',
        },
      ]),
      throwsA(isA<RemotePermissionDenied>()),
    );
  });

  test(
    'a driver gets assigned vehicles, catalogs, and only own records',
    () async {
      final m = await join(BuiltInProfile.driver.id, vehicles: {v1});
      expect(m.profile.id, BuiltInProfile.driver.id);
      expect(m.vehicleIds, {v1});

      final report = await memberSync.sync(owner, shared: true);
      expect(report.rejected, 0);
      expect(await ids(memberDb, memberDb.vehicles), [v1]);
      // The owner's refuelings are someone else's records.
      expect(await ids(memberDb, memberDb.refuelings), isEmpty);
      // Pick lists come from the owner's account (the local copy starts empty).
      expect(
        (await memberDb.select(memberDb.catalogItems).get()).map((c) => c.id),
        contains(petrol),
      );
      // Users/profiles (administration) stay hidden from a driver.
      expect(await ids(memberDb, memberDb.accountMembers), isEmpty);

      // The driver registers a refueling: uploaded, stamped as theirs.
      final rid = await memberDb.saveRefueling(draft(v1, 150));
      expect((await memberSync.sync(owner, shared: true)).rejected, 0);
      expect(cloud.row('refuelings', owner, rid)!['created_by'], member);

      // The owner receives it, with who created it.
      await ownerSync.sync(owner);
      final got = await (ownerDb.select(
        ownerDb.refuelings,
      )..where((r) => r.id.equals(rid))).getSingle();
      expect(got.createdBy, member);
    },
  );

  test(
    'changes a driver may not make are refused and undone locally',
    () async {
      await join(BuiltInProfile.driver.id, vehicles: {v1});
      await memberSync.sync(owner, shared: true);
      final own = await memberDb.saveRefueling(draft(v1, 150));
      await memberSync.sync(owner, shared: true);

      // A reading on a vehicle that isn't assigned (not even visible there,
      // but a stale device could still hold it) and a delete (no Delete
      // switch for drivers).
      await memberDb
          .into(memberDb.vehicles)
          .insert(
            VehiclesCompanion.insert(
              id: Value(v2),
              name: 'Other',
              type: VehicleType.car,
              createdAt: Value(DateTime(2026)),
              updatedAt: Value(DateTime(2026)),
            ),
          );
      final reading = await memberDb.saveReading(
        ReadingsCompanion.insert(
          vehicleId: v2,
          date: DateTime(2026, 9, 2),
          odometer: 500,
        ),
      );
      await memberDb.deleteRefueling(own);

      final report = await memberSync.sync(owner, shared: true);
      // The vehicle edit, the reading and the refueling (+ its fuel line).
      expect(report.rejected, greaterThanOrEqualTo(3));
      expect(cloud.row('readings', owner, reading), isNull);
      expect(cloud.row('refuelings', owner, own)!['deleted_at'], isNull);
      expect(await memberDb.getReading(reading), isNull);

      // Undone: the next sync brings the server's copy of the refueling back.
      await memberSync.sync(owner, shared: true);
      final back = await (memberDb.select(
        memberDb.refuelings,
      )..where((r) => r.id.equals(own))).getSingleOrNull();
      expect(back, isNotNull);
      expect(back!.deletedAt, isNull);
      expect(await ids(memberDb, memberDb.vehicles), [v1]);
    },
  );

  test('a manager sees and changes everything', () async {
    await join(BuiltInProfile.manager.id);
    await memberSync.sync(owner, shared: true);
    expect(await ids(memberDb, memberDb.vehicles), ([v1, v2]..sort()));
    expect(await ids(memberDb, memberDb.refuelings), hasLength(2));
    expect(await ids(memberDb, memberDb.accountMembers), hasLength(1));

    final rid = (await ids(memberDb, memberDb.refuelings)).first;
    await memberDb.deleteRefueling(rid);
    final report = await memberSync.sync(owner, shared: true);
    expect(report.rejected, 0);
    expect(cloud.row('refuelings', owner, rid)!['deleted_at'], isNotNull);
  });

  test('a custom profile from access_profiles applies', () async {
    // All vehicles, all records; view refuelings and fuels, nothing else.
    final custom = AccessProfile(
      id: '',
      name: 'Accountant',
      vehicleScope: VehicleScope.all,
      recordScope: RecordScope.all,
      permissions: const {
        AccessArea.refueling: {AccessAction.view},
        AccessArea.fuel: {AccessAction.view},
      },
    );
    final pid = await ownerDb.saveProfile(custom, isNew: true);
    final m = await join(pid);
    expect(m.profile.name, 'Accountant');
    expect(m.profile.can(AccessArea.refueling, AccessAction.register), isFalse);

    await memberSync.sync(owner, shared: true);
    expect(await ids(memberDb, memberDb.refuelings), hasLength(2));
    // Only the pick lists the profile may view.
    final kinds = {
      for (final c in await memberDb.select(memberDb.catalogItems).get())
        c.kind,
    };
    expect(kinds, {CatalogKind.fuel});

    await memberDb.saveRefueling(draft(v1, 300));
    final report = await memberSync.sync(owner, shared: true);
    expect(report.rejected, greaterThanOrEqualTo(1));
    expect(cloud.rows('refuelings', owner), hasLength(2));
  });

  test('removing a member cuts access on the server', () async {
    await join(BuiltInProfile.manager.id);
    final row = (await ownerDb.watchMembers().first).single;
    expect(row.status, MemberStatus.pending); // not pulled yet
    await ownerSync.sync(owner);
    final accepted = (await ownerDb.watchMembers().first).single;
    expect(accepted.status, MemberStatus.active);
    expect(accepted.memberId, member);

    await ownerDb.removeMember(accepted.id);
    await ownerSync.sync(owner);
    expect(await server.api(member).myMemberships(), isEmpty);
    expect(cloud.accessFor(owner, member), isNull);
  });

  test('clients cannot attach a user or activate a membership', () async {
    await ownerDb
        .into(ownerDb.accountMembers)
        .insert(
          AccountMembersCompanion.insert(
            id: const Value('m1'),
            email: 'Member@Example.com',
            profileId: BuiltInProfile.administrator.id,
            memberId: const Value(member),
            status: const Value(MemberStatus.active),
          ),
        );
    await ownerSync.sync(owner);
    final stored = cloud.row('account_members', owner, 'm1')!;
    expect(stored['member_id'], isNull);
    expect(stored['status'], 'pending');
    expect(stored['email'], 'member@example.com');
    expect(cloud.accessFor(owner, member), isNull);
  });

  test('an access change is visible in my_memberships', () async {
    final before = await join(BuiltInProfile.driver.id, vehicles: {v1});
    await ownerSync.sync(owner);
    final row = (await ownerDb.watchMembers().first).single;
    await ownerDb.updateMember(
      row.id,
      profileId: BuiltInProfile.driver.id,
      vehicleIds: {v1, v2},
    );
    await ownerSync.sync(owner);
    final after = (await server.api(member).myMemberships()).single;
    expect(after.vehicleIds, {v1, v2});
    expect(after.scopeKey, isNot(before.scopeKey));
    expect(jsonDecode(after.scopeKey), isA<Map>());
  });

  test('invitations need a verified, matching email', () async {
    server.users[member] = const InMemoryUser(
      email: 'member@example.com',
      emailVerified: false,
    );
    await ownerDb.inviteMember(
      email: 'member@example.com',
      profileId: BuiltInProfile.driver.id,
      vehicleIds: const {},
    );
    await ownerSync.sync(owner);
    expect(await server.api(member).myInvitations(), isEmpty);
    server.users['someone'] = const InMemoryUser(email: 'someone@example.com');
    expect(await server.api('someone').myInvitations(), isEmpty);
  });
}
