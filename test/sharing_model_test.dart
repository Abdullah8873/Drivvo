import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/calc/access_profile.dart';
import 'package:motolog/core/calc/member_access.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/sharing/sharing_api.dart';
import 'package:motolog/core/sharing/supabase_sharing_api.dart';

import 'helpers.dart';

/// Pure sharing rules, the v6 schema, and the SQL migration's copy of the
/// built-in profiles.
void main() {
  group('MemberAccess', () {
    test('the owner may do everything', () {
      final owner = MemberAccess.owner();
      expect(owner.isOwner, isTrue);
      expect(owner.can(AccessArea.users, AccessAction.delete), isTrue);
      expect(owner.canVehicle(AccessAction.edit, 'any'), isTrue);
      expect(
        owner.canRecord(
          AccessArea.refueling,
          AccessAction.delete,
          vehicleId: 'v',
          createdBy: 'someone',
        ),
        isTrue,
      );
    });

    test('a driver: assigned vehicles, own records, no delete', () {
      final driver = MemberAccess(
        profile: AccessProfile.driver(),
        memberId: 'me',
        vehicleIds: const {'v1'},
      );
      expect(driver.canSeeVehicle('v1'), isTrue);
      expect(driver.canSeeVehicle('v2'), isFalse);
      expect(driver.canVehicle(AccessAction.view, 'v1'), isTrue);
      expect(driver.canVehicle(AccessAction.edit, 'v1'), isFalse);
      bool rec(AccessAction a, {String v = 'v1', String? by}) => driver
          .canRecord(AccessArea.refueling, a, vehicleId: v, createdBy: by);
      expect(rec(AccessAction.edit), isTrue); // not uploaded yet = mine
      expect(rec(AccessAction.edit, by: 'me'), isTrue);
      expect(rec(AccessAction.edit, by: 'owner'), isFalse);
      expect(rec(AccessAction.delete, by: 'me'), isFalse);
      expect(rec(AccessAction.register, v: 'v2'), isFalse);
      expect(driver.can(AccessArea.report, AccessAction.view), isFalse);
      expect(driver.canAdminister, isFalse);
    });

    test('a manager sees all records of all vehicles', () {
      final manager = MemberAccess(
        profile: AccessProfile.manager(),
        memberId: 'me',
      );
      expect(
        manager.canRecord(
          AccessArea.expense,
          AccessAction.delete,
          vehicleId: 'v9',
          createdBy: 'owner',
        ),
        isTrue,
      );
      expect(manager.canAdminister, isTrue);
    });
  });

  group('Membership', () {
    test('JSON round trip (the saved active account)', () {
      final custom = AccessProfile.driver().copyWith(
        id: 'p1',
        name: 'Night shift',
      );
      final m = Membership(
        ownerId: 'o',
        memberId: 'm',
        ownerName: 'Olivia',
        profile: custom,
        vehicleIds: const {'b', 'a'},
      );
      final back = Membership.fromJson(m.toJson());
      expect(back.profile.name, 'Night shift');
      expect(back.profile.permissionsToJson(), custom.permissionsToJson());
      expect(back.vehicleIds, {'a', 'b'});
      expect(back.scopeKey, m.scopeKey);
      expect(back.databaseName, 'motolog_acct_o_m');
      expect(Membership.encodeVehicleIds({'b', 'a'}), '["a","b"]');
      expect(Membership.parseVehicleIds('not json'), isEmpty);
    });

    test('built-in profile ids resolve to the code definitions', () {
      final m = Membership.fromJson({
        'ownerId': 'o',
        'memberId': 'm',
        'profileId': BuiltInProfile.driver.id,
        'permissions': '{"areas":{}}',
      });
      expect(
        m.profile.permissionsToJson(),
        AccessProfile.driver().permissionsToJson(),
      );
    });

    test('server errors become sentences', () {
      expect(
        sharingErrorMessage('ERROR: motolog:transfer_expired'),
        contains('expired'),
      );
      expect(
        sharingErrorMessage('motolog:transfer_rate_limited'),
        contains('Too many tries'),
      );
      expect(
        sharingErrorMessage('motolog:quota_exceeded'),
        contains('cloud space is full'),
      );
      expect(sharingErrorMessage('boom'), contains('boom'));
    });
  });

  group('schema v6', () {
    test('fresh database has created_by and the sharing tables', () async {
      final db = testDatabase();
      addTearDown(db.close);
      for (final table in AppDatabase.createdByTables) {
        final cols = await db.customSelect('PRAGMA table_info($table)').get();
        expect(
          cols.map((c) => c.read<String>('name')),
          contains('created_by'),
          reason: table,
        );
      }
      expect(AppDatabase.syncedTableNames, contains('access_profiles'));
      expect(AppDatabase.syncedTableNames, contains('account_members'));
      // Both are tracked by the outbox like every synced table.
      await db
          .into(db.accountMembers)
          .insert(
            AccountMembersCompanion.insert(email: 'a@b.c', profileId: 'x'),
          );
      final queued = await db.select(db.syncOutbox).get();
      expect(queued.map((q) => q.targetTable), contains('account_members'));
    });

    test('a shared account copy starts without seeded catalogs', () async {
      final db = testDatabase(seedDefaults: false);
      addTearDown(db.close);
      expect(await db.select(db.catalogItems).get(), isEmpty);
      expect(await db.select(db.checklistForms).get(), isEmpty);
    });

    test('v5 -> v6 migration adds the columns and tables', () async {
      // Today's schema minus the v6 additions = a v5 database.
      final fresh = testDatabase();
      final rows = await fresh
          .customSelect(
            "SELECT sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT "
            "LIKE 'sqlite_%' AND tbl_name NOT IN "
            "('access_profiles', 'account_members') "
            "ORDER BY CASE type WHEN 'table' THEN 0 ELSE 1 END",
          )
          .get();
      await fresh.close();
      final schema = [
        for (final r in rows)
          r
              .read<String>('sql')
              .replaceAll(RegExp(r',\s*"created_by" TEXT NULL'), ''),
      ];
      expect(schema.any((s) => s.contains('created_by')), isFalse);

      const t0 = '2026-01-01T10:00:00.000Z';
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final old = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(
            setup: (raw) {
              for (final sql in schema) {
                raw.execute(sql);
              }
              raw.execute(
                'INSERT INTO vehicles (id, created_at, updated_at, name, '
                "type) VALUES ('v1', '$t0', '$t0', 'Honda', 'motorcycle')",
              );
              raw.execute(
                'INSERT INTO settings_entries VALUES '
                "('catalog_seed_version', '1')",
              );
              raw.execute('PRAGMA user_version = 5');
            },
          ),
          closeStreamsSynchronously: true,
        ),
      );
      addTearDown(old.close);
      expect((await old.select(old.vehicles).get()).single.name, 'Honda');
      final cols = await old.customSelect('PRAGMA table_info(readings)').get();
      expect(cols.map((c) => c.read<String>('name')), contains('created_by'));
      expect(await old.select(old.accessProfiles).get(), isEmpty);
      final version = await old.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), old.schemaVersion);
      // The new tables got their outbox triggers.
      await old
          .into(old.accessProfiles)
          .insert(AccessProfilesCompanion.insert(name: 'P', permissions: '{}'));
      final queued = await old.select(old.syncOutbox).get();
      expect(queued.map((q) => q.targetTable), contains('access_profiles'));
    });
  });

  group('sharing SQL', () {
    final sql = File('supabase/migrations/20260926000001_sharing.sql')
        .readAsStringSync();

    /// The `'{...}'::jsonb` constant that follows [marker].
    Map<String, Object?> jsonAfter(String marker) {
      final start = sql.indexOf(marker);
      expect(start, isNot(-1), reason: marker);
      final literal = RegExp(r"'(\{[^']*\})'::jsonb")
          .firstMatch(sql.substring(start))!
          .group(1)!;
      return (jsonDecode(literal) as Map).cast<String, Object?>();
    }

    test('administrator/manager JSON matches AccessProfile', () {
      final json = jsonAfter("('builtin:administrator', 'builtin:manager')");
      expect(json, AccessProfile.administrator().permissionsToJson());
      expect(json, AccessProfile.manager().permissionsToJson());
    });

    test('driver JSON matches AccessProfile.driver()', () {
      expect(
        jsonAfter("p_profile_id = 'builtin:driver'"),
        AccessProfile.driver().permissionsToJson(),
      );
    });

    test('transfer code alphabet matches', () {
      expect(sql, contains("'ABCDEFGHJKMNPQRSTUVWXYZ23456789'"));
    });

    test('every synced table gets sharing policies', () {
      for (final table in AppDatabase.syncedTableNames) {
        expect(sql, contains("('$table', "), reason: table);
      }
    });
  });
}
