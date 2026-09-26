import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/calc/access_profile.dart';

void main() {
  group('built-in profiles', () {
    test('administrator and manager can do everything', () {
      for (final p in [
        AccessProfile.administrator(),
        AccessProfile.manager(),
      ]) {
        expect(p.vehicleScope, VehicleScope.all);
        expect(p.recordScope, RecordScope.all);
        for (final area in AccessArea.values) {
          for (final action in area.actions) {
            expect(p.can(area, action), isTrue, reason: '${p.name} $area');
          }
          expect(p.grantedCount(area), area.actions.length);
        }
      }
    });

    test('driver: assigned vehicles, own records, no delete/report/admin', () {
      final d = AccessProfile.driver();
      expect(d.vehicleScope, VehicleScope.assigned);
      expect(d.recordScope, RecordScope.own);
      expect(d.can(AccessArea.refueling, AccessAction.register), isTrue);
      expect(d.can(AccessArea.refueling, AccessAction.edit), isTrue);
      expect(d.can(AccessArea.refueling, AccessAction.delete), isFalse);
      expect(d.can(AccessArea.fuel, AccessAction.view), isTrue);
      expect(d.can(AccessArea.report, AccessAction.view), isFalse);
      expect(d.can(AccessArea.vehicles, AccessAction.view), isFalse);
      expect(d.grantedCount(AccessArea.expense), 3);
      expect(d.grantedCount(AccessArea.users), 0);
    });

    test('built-ins are recognised by id', () {
      expect(AccessProfile.driver().isBuiltIn, isTrue);
      expect(
        AccessProfile.builtInById(BuiltInProfile.manager.id)?.name,
        'Manager',
      );
      expect(
        AccessProfile.driver().copyWith(id: 'custom-1').isBuiltIn,
        isFalse,
      );
    });
  });

  group('toggled', () {
    final empty = AccessProfile.driver().copyWith(
      id: 'c',
      permissions: const {},
    );

    test('turning an action on also turns view on', () {
      final p = empty.toggled(AccessArea.service, AccessAction.delete, true);
      expect(p.permissions[AccessArea.service], {
        AccessAction.delete,
        AccessAction.view,
      });
      expect(p.can(AccessArea.service, AccessAction.delete), isTrue);
    });

    test('turning view off clears the area', () {
      final p = AccessProfile.administrator().toggled(
        AccessArea.income,
        AccessAction.view,
        false,
      );
      expect(p.grantedCount(AccessArea.income), 0);
      expect(p.can(AccessArea.income, AccessAction.edit), isFalse);
    });

    test('actions the area does not offer are ignored', () {
      final p = empty.toggled(AccessArea.report, AccessAction.delete, true);
      expect(p.grantedCount(AccessArea.report), 0);
      expect(p.can(AccessArea.report, AccessAction.delete), isFalse);
    });
  });

  test('can() requires view even if stored state is incoherent', () {
    final p = AccessProfile.driver().copyWith(
      permissions: const {
        AccessArea.route: {AccessAction.edit},
      },
    );
    expect(p.can(AccessArea.route, AccessAction.edit), isFalse);
  });

  group('json', () {
    test('round-trips', () {
      final p = AccessProfile.driver().toggled(
        AccessArea.reading,
        AccessAction.delete,
        true,
      );
      final back = AccessProfile.fromPermissionsJson(
        id: p.id,
        name: p.name,
        json: p.permissionsToJson(),
      );
      expect(back.vehicleScope, p.vehicleScope);
      expect(back.recordScope, p.recordScope);
      for (final area in AccessArea.values) {
        expect(
          back.permissions[area] ?? const {},
          p.permissions[area] ?? const {},
          reason: '$area',
        );
      }
    });

    test('omits empty areas and uses stable names', () {
      final json = AccessProfile.driver().permissionsToJson();
      final areas = json['areas']! as Map;
      expect(areas.containsKey('report'), isFalse);
      expect(areas['refueling'], ['view', 'register', 'edit']);
      expect(json['vehicleScope'], 'assigned');
    });

    test('unknown keys are ignored, missing scopes are restrictive', () {
      final p = AccessProfile.fromPermissionsJson(
        id: 'x',
        name: 'X',
        json: {
          'areas': {
            'refueling': ['view', 'teleport'],
            'hovercraft': ['view'],
            'report': ['view', 'delete'],
          },
        },
      );
      expect(p.vehicleScope, VehicleScope.assigned);
      expect(p.recordScope, RecordScope.own);
      expect(p.permissions[AccessArea.refueling], {AccessAction.view});
      expect(p.permissions[AccessArea.report], {AccessAction.view});
      expect(p.permissions.length, 2);
    });
  });
}
