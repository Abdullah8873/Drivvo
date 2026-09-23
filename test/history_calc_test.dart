import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/app_database.dart';
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

  test('groups by month with spend, distance, efficiency and change', () async {
    final months = groupByMonth(await db.loadTimeline(vid));
    expect(months.map((m) => m.month), [DateTime(2026, 9), DateTime(2026, 8)]);

    final sep = months.first;
    expect(sep.records, hasLength(4));
    expect(sep.spent, closeTo(9 * 293.03, 1e-6)); // income excluded
    expect(sep.distance, 250); // 1450 − 1200
    expect(sep.efficiency, 50); // 200 km / 4 L
    expect(sep.changeVsPrevious, closeTo(-0.1106, 1e-3));

    final aug = months.last;
    expect(aug.spent, closeTo(5 * 293.03 + 1500, 1e-6));
    expect(aug.changeVsPrevious, isNull); // no July data
    expect(aug.costByModule[RecordModule.service], 1500);
  });

  test('refuel cycle and distance since previous', () async {
    final t = await db.loadTimeline(vid);
    final refuels = t.where((r) => r.module == RecordModule.refueling).toList();
    final sep5 = refuels[1];
    final cycle = refuelCycle(t, sep5)!;
    expect(cycle.distance, 200);
    expect(cycle.efficiency, 40);
    expect(cycle.costPerDistance, closeTo(5 * 293.03 / 200, 1e-9));
    expect(refuelCycle(t, refuels.last), isNull); // first refuel ever
    expect(distanceSincePrevious(t, refuels.first), 200);
    expect(distanceSincePrevious(t, refuels.last), isNull);
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
