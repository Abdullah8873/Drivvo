import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/providers.dart';
import 'package:motolog/core/settings/app_settings.dart';
import 'package:motolog/features/history/history_providers.dart';
import 'package:motolog/features/history/history_queries.dart';
import 'package:motolog/features/refueling/refueling_providers.dart';

import 'helpers.dart';
import 'history_fixtures.dart';

/// History's per-refuel efficiency comes from the shared consumption engine
/// (`historyConsumptionProvider`), per tank and position-aware.
void main() {
  late AppDatabase db;
  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  /// Engine output + timeline for [vid], with [settings] applied.
  Future<(HistoryConsumption, List<TimelineRecord>)> load(
    String vid, {
    AppSettings settings = const AppSettings(),
  }) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialSettingsProvider.overrideWithValue(settings),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(historyConsumptionProvider(vid), (_, _) {});
    await container.read(refuelSamplesProvider(vid).future);
    return (sub.read(), await db.loadTimeline(vid));
  }

  TimelineRecord byId(List<TimelineRecord> t, String id) =>
      t.firstWhere((r) => r.id == id);

  test('two-tank vehicle: each tank is measured on its own', () async {
    final v = await db
        .into(db.vehicles)
        .insertReturning(
          VehiclesCompanion.insert(
            name: 'Bi-fuel',
            type: VehicleType.car,
            tankCount: const Value(2),
            tank1Capacity: const Value(40),
            tank2Kind: const Value(FuelKind.gas),
          ),
        );
    final r1 = await addRefuel(
      db,
      v.id,
      date: DateTime(2026, 9, 1),
      odometer: 1000,
      lines: [
        (fuel: 'Petrol', volume: 10, tank: 1),
        (fuel: 'CNG', volume: 5, tank: 2),
      ],
    );
    final r2 = await addRefuel(
      db,
      v.id,
      date: DateTime(2026, 9, 10),
      odometer: 1200,
      fuel: 'CNG',
      tank: 2,
      volume: 4,
    );
    final r3 = await addRefuel(
      db,
      v.id,
      date: DateTime(2026, 9, 20),
      odometer: 1500,
      lines: [
        (fuel: 'Petrol', volume: 20, tank: 1),
        (fuel: 'CNG', volume: 5, tank: 2),
      ],
    );

    final (c, t) = await load(v.id);
    final first = c.tanksOf(byId(t, r1));
    expect(first.map((x) => x.tank), [1, 2]);
    expect(first[0].kind, FuelKind.liquid);
    expect(first[0].efficiency, 25); // 500 km / 20 L (r1 → r3)
    expect(first[1].kind, FuelKind.gas);
    expect(first[1].efficiency, 50); // 200 km / 4 kg (r1 → r2)
    expect(first[1].volume, 5);

    final second = c.tanksOf(byId(t, r2));
    expect(second.single.tank, 2);
    expect(second.single.efficiency, 60); // 300 km / 5 kg

    expect(c.tanksOf(byId(t, r3)).every((x) => x.efficiency == null), isTrue);
    expect(c.tank2.cycles, hasLength(2));
  });

  group('missed previous refueling', () {
    late String vid;
    late List<String> ids;

    setUp(() async {
      vid = await addTestVehicle(db);
      ids = [
        await addRefuel(
          db,
          vid,
          date: DateTime(2026, 9, 1),
          odometer: 0,
          volume: 10,
        ),
        await addRefuel(
          db,
          vid,
          date: DateTime(2026, 9, 10),
          odometer: 200,
          volume: 10,
        ),
        await addRefuel(
          db,
          vid,
          date: DateTime(2026, 9, 20),
          odometer: 400,
          volume: 10,
          missedPrevious: true,
        ),
        await addRefuel(
          db,
          vid,
          date: DateTime(2026, 10, 1),
          odometer: 600,
          volume: 8,
        ),
      ];
    });

    test('breaks the chain (economy shown on cycle start)', () async {
      final (c, t) = await load(vid);
      double? eff(int i) => c.tanksOf(byId(t, ids[i])).single.efficiency;
      expect(eff(0), 20);
      expect(eff(1), isNull); // its cycle ends at the "missed" refuel
      expect(eff(2), 25);
      expect(eff(3), isNull);
    });

    test('honours "show on cycle end"', () async {
      final (c, t) = await load(
        vid,
        settings: const AppSettings(economyPosition: EconomyPosition.cycleEnd),
      );
      double? eff(int i) => c.tanksOf(byId(t, ids[i])).single.efficiency;
      expect(eff(0), isNull);
      expect(eff(1), 20);
      expect(eff(2), isNull);
      expect(eff(3), 25);
      expect(
        c.tanksOf(byId(t, ids[3])).single.costPerDistance,
        closeTo(8 * 293.03 / 200, 1e-9),
      );
    });
  });
}
