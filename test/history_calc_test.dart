import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/calc/consumption.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/features/entries/entry_queries.dart';
import 'package:motolog/core/format/formatters.dart';
import 'package:motolog/core/settings/app_settings.dart';
import 'package:motolog/core/theme/record_module.dart';
import 'package:motolog/features/history/history_calc.dart';
import 'package:motolog/features/history/history_queries.dart';
import 'package:motolog/features/history/history_search_screen.dart';

import 'helpers.dart';
import 'history_fixtures.dart';

void main() {
  late AppDatabase db;
  late String vid;
  late String serviceId;

  setUp(() async {
    db = testDatabase();
    vid = await addTestVehicle(db);
    await addRefuel(
      db,
      vid,
      date: DateTime(2026, 8, 10),
      odometer: 1000,
      volume: 5,
    );
    serviceId = await addEntry(
      db,
      vid,
      kind: EntryKind.service,
      date: DateTime(2026, 8, 20),
      odometer: 1100,
      items: {'Oil Change': 1200, 'Oil Filter': 300},
    );
    await addRefuel(
      db,
      vid,
      date: DateTime(2026, 9, 5),
      odometer: 1200,
      volume: 5,
    );
    await addRefuel(
      db,
      vid,
      date: DateTime(2026, 9, 17),
      odometer: 1400,
      volume: 4,
    );
    await db
        .into(db.readings)
        .insert(
          ReadingsCompanion.insert(
            vehicleId: vid,
            date: DateTime(2026, 9, 18),
            odometer: 1450,
          ),
        );
    await addEntry(
      db,
      vid,
      kind: EntryKind.income,
      date: DateTime(2026, 9, 20),
      items: {'Refund': 500},
    );
  });
  tearDown(() => db.close());

  test('timeline is newest first with resolved titles', () async {
    final t = await db.loadTimeline(vid);
    expect(t.map((r) => r.module), [
      RecordModule.income,
      RecordModule.reading,
      RecordModule.refueling,
      RecordModule.refueling,
      RecordModule.service,
      RecordModule.refueling,
    ]);
    expect(t.first.title, 'Refund');
    expect(t[2].title, 'Petrol');
    expect(t[4].title, 'Oil Change +1');
    expect(t[4].items.map((i) => i.amount), [1200, 300]);
  });

  test('groups by month with spend, distance and change', () async {
    final months = groupByMonth(await db.loadTimeline(vid));
    expect(months.map((m) => m.month), [DateTime(2026, 9), DateTime(2026, 8)]);

    final sep = months.first;
    expect(sep.records, hasLength(4));
    expect(sep.spent, closeTo(9 * 293.03, 1e-6)); // income excluded
    expect(sep.previousOdometer, 1100); // August's highest odometer
    expect(sep.distance, 350); // 1450 − 1100, not just 1450 − 1200
    expect(sep.changeVsPrevious, closeTo(-0.1106, 1e-3));

    final aug = months.last;
    expect(aug.spent, closeTo(5 * 293.03 + 1500, 1e-6));
    expect(aug.previousOdometer, isNull);
    expect(aug.distance, 100); // earliest month: in-month range 1100 − 1000
    expect(aug.changeVsPrevious, isNull); // no July data
    expect(aug.costByModule[RecordModule.service], 1500);
  });

  test('month distance spans months; single-record months get one', () async {
    // October has a single reading; November has nothing; December one refuel.
    await db
        .into(db.readings)
        .insert(
          ReadingsCompanion.insert(
            vehicleId: vid,
            date: DateTime(2026, 10, 3),
            odometer: 1600,
          ),
        );
    await addRefuel(
      db,
      vid,
      date: DateTime(2026, 12, 1),
      odometer: 1900,
      volume: 5,
    );
    final months = groupByMonth(await db.loadTimeline(vid));
    expect(months.map((m) => m.month.month), [12, 10, 9, 8]);
    expect(months[0].distance, 300); // 1900 − October's 1600
    expect(months[1].distance, 150); // 1600 − September's 1450
    expect(months[2].distance, 350);
  });

  test('earliest month with one record has no distance', () async {
    final other = await addTestVehicle(db, name: 'Other');
    await addRefuel(
      db,
      other,
      date: DateTime(2026, 9, 1),
      odometer: 500,
      volume: 5,
    );
    final months = groupByMonth(await db.loadTimeline(other));
    expect(months.single.distance, isNull);
  });

  group('monthEfficiency (engine cycles ending in the month)', () {
    RefuelSample s(
      String id,
      DateTime date,
      double odo,
      double volume, {
      bool full = true,
      bool missed = false,
    }) => RefuelSample(
      id: id,
      date: date,
      odometer: odo,
      volume: volume,
      cost: volume * 300,
      fullTank: full,
      missedPrevious: missed,
    );

    test('counts cycles that start in the previous month', () {
      final stats = ConsumptionStats.compute([
        s('a', DateTime(2026, 8, 10), 1000, 5),
        s('b', DateTime(2026, 9, 5), 1200, 5),
        s('c', DateTime(2026, 9, 17), 1400, 4),
      ]);
      // Both cycles (a→b from August, b→c) close in September.
      expect(
        monthEfficiency(stats.cycles, DateTime(2026, 9)),
        closeTo(400 / 9, 1e-9),
      );
      expect(monthEfficiency(stats.cycles, DateTime(2026, 8)), isNull);
    });

    test('partial fills accumulate across the month boundary', () {
      final stats = ConsumptionStats.compute([
        s('a', DateTime(2026, 8, 1), 0, 10),
        s('b', DateTime(2026, 8, 20), 150, 3, full: false),
        s('c', DateTime(2026, 9, 3), 300, 4),
      ]);
      expect(
        monthEfficiency(stats.cycles, DateTime(2026, 9)),
        closeTo(300 / 7, 1e-9),
      );
      expect(monthEfficiency(stats.cycles, DateTime(2026, 8)), isNull);
    });

    test('a missed refuel drops the broken cycle', () {
      final stats = ConsumptionStats.compute([
        s('a', DateTime(2026, 9, 1), 0, 10),
        s('b', DateTime(2026, 9, 10), 200, 10),
        s('c', DateTime(2026, 9, 20), 400, 10, missed: true),
        s('d', DateTime(2026, 10, 1), 600, 8),
      ]);
      expect(monthEfficiency(stats.cycles, DateTime(2026, 9)), 20);
      expect(monthEfficiency(stats.cycles, DateTime(2026, 10)), 25);
    });
  });

  test('distance since previous record of the same module', () async {
    final t = await db.loadTimeline(vid);
    final refuels = t.where((r) => r.module == RecordModule.refueling).toList();
    expect(distanceSincePrevious(t, refuels.first), 200);
    expect(distanceSincePrevious(t, refuels.last), isNull);
  });

  test('deleting any installment deletes the whole group', () async {
    final type = await catalogId(db, CatalogKind.expenseType, 'Insurance');
    final parentId = await db.saveEntry(
      EntryDraft(
        vehicleId: vid,
        kind: EntryKind.expense,
        date: DateTime(2026, 9, 1),
        items: [EntryItemDraft(typeId: type, amount: 3000)],
        installments: 3,
      ),
    );
    final group = await (db.select(
      db.entries,
    )..where((e) => e.id.equals(parentId) | e.parentId.equals(parentId))).get();
    expect(group, hasLength(3));
    final child = group.firstWhere((e) => e.parentId != null);

    await db.softDeleteRecord(RecordModule.expense, child.id);
    final after = await (db.select(
      db.entries,
    )..where((e) => e.id.equals(parentId) | e.parentId.equals(parentId))).get();
    expect(after.every((e) => e.deletedAt != null), isTrue);
    final t = await db.loadTimeline(vid);
    expect(t.where((r) => r.module == RecordModule.expense), isEmpty);
  });

  test('soft delete hides the record and its items; stream updates', () async {
    final stream = db.watchTimeline(vid);
    expect((await stream.first), hasLength(6));

    await db.softDeleteRecord(RecordModule.service, serviceId);
    expect(await stream.first, hasLength(5));
    final items = await (db.select(
      db.entryItems,
    )..where((i) => i.entryId.equals(serviceId))).get();
    expect(items.every((i) => i.deletedAt != null), isTrue);
  });

  test('timeline items expose the service part number', () async {
    final type = await catalogId(db, CatalogKind.serviceType, 'Oil Change');
    final id =
        (await db
                .into(db.entries)
                .insertReturning(
                  EntriesCompanion.insert(
                    vehicleId: vid,
                    kind: EntryKind.service,
                    date: DateTime(2026, 9, 25),
                    totalCost: 1200,
                  ),
                ))
            .id;
    await db
        .into(db.entryItems)
        .insert(
          EntryItemsCompanion.insert(
            entryId: id,
            typeId: type,
            amount: 1200,
            partNumber: const Value('Bosch WS10130'),
          ),
        );
    final t = await db.loadTimeline(vid);
    expect(
      t.firstWhere((r) => r.id == id).items.single.partNumber,
      'Bosch WS10130',
    );
  });

  test('search matches names, amounts and notes', () async {
    final fmt = Formatters(const AppSettings());
    final t = await db.loadTimeline(vid);
    List<RecordModule> hits(String q) => [
      for (final r in t)
        if (recordMatches(r, q, fmt)) r.module,
    ];
    expect(hits('oil filter'), [RecordModule.service]);
    expect(hits('1500'), [RecordModule.service]);
    expect(hits('petrol'), hasLength(3));
    expect(hits(''), hasLength(6));
  });
}
