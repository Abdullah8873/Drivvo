import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/format/formatters.dart';
import 'package:motolog/core/providers.dart';
import 'package:motolog/core/settings/app_settings.dart';
import 'package:motolog/features/refueling/efficiency_text.dart';
import 'package:motolog/features/refueling/refueling_providers.dart';

import 'helpers.dart';

void main() {
  late AppDatabase db;
  late String vid;
  late Map<String, CatalogItem> fuels;

  setUp(() async {
    db = testDatabase();
    vid = await addTestVehicle(db);
    final list = await db.watchCatalog(CatalogKind.fuel).first;
    fuels = {for (final f in list) f.name: f};
  });
  tearDown(() => db.close());

  RefuelingDraft draft(
    DateTime date,
    double odo,
    double volume, {
    double price = 300,
    bool full = true,
    String fuel = 'Petrol',
    double? discount,
    String? stationId,
  }) => RefuelingDraft(
    vehicleId: vid,
    date: date,
    odometer: odo,
    fullTank: full,
    discount: discount,
    gasStationId: stationId,
    lines: [
      FuelLineDraft(
        fuelId: fuels[fuel]!.id,
        pricePerUnit: price,
        total: price * volume,
        volume: volume,
      ),
    ],
  );

  test('save inserts the refueling and its lines in one go', () async {
    final station = await db
        .into(db.catalogItems)
        .insertReturning(
          CatalogItemsCompanion.insert(
            kind: CatalogKind.gasStation,
            name: 'Shell Canal Rd',
          ),
        );
    final id = await db.saveRefueling(
      RefuelingDraft(
        vehicleId: vid,
        date: DateTime(2026, 9, 1, 10, 30),
        odometer: 56935,
        discount: 20,
        gasStationId: station.id,
        lines: [
          FuelLineDraft(
            fuelId: fuels['Petrol']!.id,
            pricePerUnit: 293.03,
            total: 1470.13,
            volume: 5.017,
          ),
          FuelLineDraft(
            fuelId: fuels['CNG']!.id,
            pricePerUnit: 200,
            total: 400,
            volume: 2,
            tank: 2,
          ),
        ],
      ),
    );

    final list = await db.watchRefuelings(vid).first;
    expect(list, hasLength(1));
    final r = list.single;
    expect(r.id, id);
    expect(r.refueling.totalCost, closeTo(1470.13 + 400 - 20, 1e-9));
    expect(r.title, 'Petrol + CNG');
    expect(r.gasStation?.name, 'Shell Canal Rd');
    expect(r.volume, closeTo(7.017, 1e-9));
    // Discount is split between tanks in proportion to their cost.
    expect(r.costForTank(1) + r.costForTank(2), closeTo(1850.13, 1e-9));
    expect(r.toSample(tank: 2)!.volume, 2);
  });

  test('update replaces the fuel lines and bumps updatedAt', () async {
    final id = await db.saveRefueling(draft(DateTime(2026, 9, 1), 100, 5));
    final before = (await db.getRefueling(id))!;
    await db.saveRefueling(
      draft(DateTime(2026, 9, 2), 120, 6, fuel: 'Diesel', discount: 10),
      id: id,
    );

    final after = (await db.getRefueling(id))!;
    expect(after.refueling.odometer, 120);
    expect(after.lines.single.fuelName, 'Diesel');
    expect(after.refueling.totalCost, 6 * 300 - 10);
    expect(
      after.refueling.updatedAt.isBefore(before.refueling.updatedAt),
      isFalse,
    );
    // The old line is soft-deleted, not removed.
    final allLines = await db.select(db.refuelingFuels).get();
    expect(allLines, hasLength(2));
    expect(allLines.where((l) => l.deletedAt != null), hasLength(1));
  });

  test('delete is a soft delete of the refueling and its lines', () async {
    final id = await db.saveRefueling(draft(DateTime(2026, 9, 1), 100, 5));
    await db.deleteRefueling(id);
    expect(await db.watchRefuelings(vid).first, isEmpty);
    expect(await db.getRefueling(id), isNull);
    final row = await (db.select(
      db.refuelings,
    )..where((r) => r.id.equals(id))).getSingle();
    expect(row.deletedAt, isNotNull);
    final lines = await db.select(db.refuelingFuels).get();
    expect(lines.every((l) => l.deletedAt != null), isTrue);
  });

  test('lastFuelIdFor and previousRefueling', () async {
    expect(await db.lastFuelIdFor(vid), isNull);
    final a = await db.saveRefueling(draft(DateTime(2026, 9, 1), 100, 5));
    await db.saveRefueling(
      draft(DateTime(2026, 9, 5), 300, 5, fuel: 'Gas Premium'),
    );
    expect(await db.lastFuelIdFor(vid), fuels['Gas Premium']!.id);

    final prev = await db.previousRefueling(vid, DateTime(2026, 9, 3));
    expect(prev?.id, a);
    expect(
      await db.previousRefueling(vid, DateTime(2026, 9, 3), excludeId: a),
      isNull,
    );
  });

  test('watchRefuelings lists newest first and skips other vehicles', () async {
    final other = await addTestVehicle(db, name: 'Other');
    await db.saveRefueling(draft(DateTime(2026, 9, 1), 100, 5));
    await db.saveRefueling(draft(DateTime(2026, 9, 3), 200, 5));
    await db.saveRefueling(
      RefuelingDraft(
        vehicleId: other,
        date: DateTime(2026, 9, 2),
        odometer: 1,
        lines: [
          FuelLineDraft(
            fuelId: fuels['Petrol']!.id,
            pricePerUnit: 1,
            total: 1,
            volume: 1,
          ),
        ],
      ),
    );
    final list = await db.watchRefuelings(vid).first;
    expect(list.map((r) => r.refueling.odometer), [200, 100]);
  });

  test('watchRefuelSamples matches toSample of watchRefuelings', () async {
    // Two tanks, several lines per tank, a discount, an edited refueling
    // (soft-deleted old line), a deleted refueling and a line-less tank 2.
    final a = await db.saveRefueling(
      RefuelingDraft(
        vehicleId: vid,
        date: DateTime(2026, 9, 1),
        odometer: 1000,
        discount: 37.5,
        lines: [
          FuelLineDraft(
            fuelId: fuels['Petrol']!.id,
            pricePerUnit: 293.03,
            total: 1470.13,
            volume: 5.017,
          ),
          FuelLineDraft(
            fuelId: fuels['Ethanol']!.id,
            pricePerUnit: 250,
            total: 500,
            volume: 2,
          ),
          FuelLineDraft(
            fuelId: fuels['CNG']!.id,
            pricePerUnit: 200,
            total: 400.7,
            volume: 2.1,
            tank: 2,
          ),
        ],
      ),
    );
    await db.saveRefueling(draft(DateTime(2026, 9, 3), 1300, 9.3), id: a);
    await db.saveRefueling(draft(DateTime(2026, 9, 5), 1500, 7.1, full: false));
    await db.saveRefueling(draft(DateTime(2026, 9, 5), 1500, 3.3));
    final gone = await db.saveRefueling(draft(DateTime(2026, 9, 6), 1600, 4));
    await db.deleteRefueling(gone);
    await db.saveRefueling(
      RefuelingDraft(
        vehicleId: vid,
        date: DateTime(2026, 9, 8),
        odometer: 1800,
        discount: 10,
        lines: [
          FuelLineDraft(
            fuelId: fuels['Petrol']!.id,
            pricePerUnit: 300,
            total: 1500,
            volume: 5,
          ),
          FuelLineDraft(
            fuelId: fuels['CNG']!.id,
            pricePerUnit: 200,
            total: 300,
            volume: 1.5,
            tank: 2,
          ),
        ],
      ),
    );

    final details = await db.watchRefuelings(vid).first;
    final samples = await db.watchRefuelSamples(vid).first;
    String key(RefuelSample s) =>
        '${s.id}|${s.date.toIso8601String()}|${s.odometer}|${s.volume}|'
        '${s.cost}|${s.fullTank}|${s.missedPrevious}';
    for (final tank in [1, 2]) {
      expect(
        (samples[tank] ?? const []).map(key).toList(),
        details.map((d) => d.toSample(tank: tank)).nonNulls.map(key).toList(),
        reason: 'tank $tank',
      );
    }
    expect(samples[2], hasLength(1));
  });

  group('providers', () {
    late ProviderContainer container;
    setUp(() {
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
    });
    tearDown(() => container.dispose());

    Future<ConsumptionStats> stats() async {
      final sub = container.listen(refuelingStatsProvider(vid), (_, _) {});
      addTearDown(sub.close);
      await container.read(refuelSamplesProvider(vid).future);
      return sub.read().requireValue;
    }

    test('refuelingStatsProvider runs the consumption engine', () async {
      await db.saveRefueling(draft(DateTime(2026, 8, 1), 54682, 7.368));
      final second = await db.saveRefueling(
        draft(DateTime(2026, 8, 6), 54985, 5.063),
      );
      await db.saveRefueling(
        draft(DateTime(2026, 8, 10), 55150, 2, full: false),
      );

      final s = await stats();
      expect(s.count, 3);
      expect(s.averageEfficiency, closeTo(303 / 5.063, 1e-9));
      expect(s.resultFor(second)!.distanceSincePrevious, 303);
      // Default "cycle start": shown on the first refuel, not the second.
      expect(s.results.first.efficiency, closeTo(59.846, 0.001));
      expect(s.resultFor(second)!.efficiency, isNull);
    });

    test('economy position setting moves the efficiency', () async {
      await db.saveRefueling(draft(DateTime(2026, 8, 1), 1000, 5));
      final end = await db.saveRefueling(draft(DateTime(2026, 8, 6), 1200, 5));
      await container
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(economyPosition: EconomyPosition.cycleEnd));
      final s = await stats();
      expect(s.resultFor(end)!.efficiency, 40);
    });
  });

  test('efficiencyText follows the settings format and fuel kind', () {
    final fmt = Formatters(const AppSettings());
    expect(efficiencyText(fmt, DistanceUnit.km, 42.765), '42.765 km/L');
    expect(efficiencyText(fmt, DistanceUnit.km, null), isNull);
    final l100 = Formatters(
      const AppSettings(efficiencyFormat: EfficiencyFormat.litersPer100Km),
    );
    expect(efficiencyText(l100, DistanceUnit.km, 10), '10.000 L/100km');
    expect(
      efficiencyText(fmt, DistanceUnit.km, 6.5, kind: FuelKind.electric),
      '6.500 km/kWh',
    );
    expect(efficiencyText(fmt, DistanceUnit.hours, 0.5), '2.000 L/h');
  });
}
