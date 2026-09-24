import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/theme/record_module.dart';
import 'package:motolog/features/export/export_data.dart';
import 'package:motolog/features/export/export_models.dart';
import 'package:motolog/features/export/export_rows.dart';

import 'helpers.dart';
import 'history_fixtures.dart';

/// Row builders + the database loader together (export_data.dart is a thin
/// pass-through, so testing them as a pair covers the filters without
/// hand-building drift row objects for every case).
void main() {
  late AppDatabase db;
  late String vid;

  setUp(() async {
    db = testDatabase();
    vid = await addTestVehicle(db, name: 'Honda');
  });

  tearDown(() => db.close());

  Future<List<ExportSection>> sectionsFor({
    List<String>? vehicleIds,
    ExportPeriod? period,
    Set<RecordModule> modules = const {
      RecordModule.refueling,
      RecordModule.expense,
      RecordModule.service,
      RecordModule.income,
      RecordModule.route,
      RecordModule.reading,
      RecordModule.reminder,
    },
  }) async {
    final options = ExportOptions(
      vehicleIds: vehicleIds ?? [vid],
      vehicleLabel: 'Honda',
      period: period,
      modules: modules,
      format: ExportFormat.csv,
    );
    final data = await loadExportData(db, options);
    return buildExportSections(data, modules, 'PKR');
  }

  ExportSection section(List<ExportSection> sections, RecordModule module) =>
      sections.firstWhere((s) => s.module == module);

  test(
    'multi-fuel refueling: one row per line, exact numbers verbatim',
    () async {
      await addRefuel(
        db,
        vid,
        date: DateTime(2026, 1, 10, 8, 30),
        odometer: 5000,
        lines: [
          (fuel: 'Petrol', volume: 5.125, tank: 1),
          (fuel: 'CNG', volume: 2, tank: 2),
        ],
        price: 293.03,
      );

      final refueling = section(await sectionsFor(), RecordModule.refueling);
      expect(refueling.recordCount, 1);
      expect(refueling.rows, hasLength(2));

      final row1 = refueling.rows[0];
      expect(row1[0], 'Honda'); // vehicle
      expect(row1[1], '2026-01-10'); // date
      expect(row1[2], '08:30'); // time
      expect(row1[4], 'Petrol'); // fuel
      expect(row1[6], '293.03'); // price/unit, verbatim
      expect(row1[7], '5.125'); // volume, verbatim

      final row2 = refueling.rows[1];
      expect(row2[4], 'CNG');
      expect(row2[5], '2'); // tank
    },
  );

  test('entry with several items and a discount', () async {
    final oilChange = await catalogId(db, CatalogKind.expenseType, 'Fine');
    final tolls = await catalogId(db, CatalogKind.expenseType, 'Tolls');
    final entry = await db
        .into(db.entries)
        .insertReturning(
          EntriesCompanion.insert(
            vehicleId: vid,
            kind: EntryKind.expense,
            date: DateTime(2026, 2, 1, 9),
            totalCost: 2300,
            discount: const Value(200),
            title: const Value('Road trip costs'),
          ),
        );
    await db
        .into(db.entryItems)
        .insert(
          EntryItemsCompanion.insert(
            entryId: entry.id,
            typeId: oilChange,
            amount: 1500,
          ),
        );
    await db
        .into(db.entryItems)
        .insert(
          EntryItemsCompanion.insert(
            entryId: entry.id,
            typeId: tolls,
            amount: 1000,
          ),
        );

    final expense = section(await sectionsFor(), RecordModule.expense);
    expect(expense.recordCount, 1);
    expect(expense.rows, hasLength(2));
    expect(expense.rows.map((r) => r[5]), containsAll(['Fine', 'Tolls']));
    expect(expense.rows.first[11], '200'); // discount repeated per row
    expect(expense.moneyTotal, 2300);
  });

  test('route: trip and freight modes', () async {
    await db
        .into(db.routes)
        .insert(
          RoutesCompanion.insert(
            vehicleId: vid,
            mode: const Value(RouteMode.trip),
            startDate: DateTime(2026, 3, 1, 7),
            startOdometer: 100,
            origin: const Value('Lahore'),
            destination: const Value('Multan'),
            endDate: const Value(null),
            valuePerDistance: const Value(15),
            total: const Value(4500),
          ),
        );
    await db
        .into(db.routes)
        .insert(
          RoutesCompanion.insert(
            vehicleId: vid,
            mode: const Value(RouteMode.freight),
            startDate: DateTime(2026, 3, 5, 7),
            startOdometer: 200,
            cargoType: const Value('Furniture'),
            freightValue: const Value(8000),
          ),
        );

    final route = section(await sectionsFor(), RecordModule.route);
    expect(route.recordCount, 2);
    expect(route.moneyTotal, 4500 + 8000);
    final trip = route.rows.firstWhere((r) => r[1] == 'trip');
    expect(trip[2], 'Lahore');
    expect(trip[6], 'Multan');
    final freight = route.rows.firstWhere((r) => r[1] == 'freight');
    expect(freight[12], 'Furniture');
    expect(freight[18], '8000');
  });

  test('reading', () async {
    await db
        .into(db.readings)
        .insert(
          ReadingsCompanion.insert(
            vehicleId: vid,
            date: DateTime(2026, 4, 1, 12),
            odometer: 9999,
            driver: const Value('Ali'),
          ),
        );
    final reading = section(await sectionsFor(), RecordModule.reading);
    expect(reading.recordCount, 1);
    expect(reading.rows.single, [
      'Honda',
      '2026-04-01',
      '12:00',
      '9999',
      'Ali',
      '',
    ]);
  });

  test('reminders', () async {
    final typeId = await catalogId(db, CatalogKind.serviceType, 'Oil Change');
    await db
        .into(db.reminders)
        .insert(
          RemindersCompanion.insert(
            vehicleId: vid,
            target: ReminderTarget.service,
            typeId: typeId,
            repeat: const Value(true),
            byDistance: const Value(true),
            everyDistance: const Value(3000),
            byDate: const Value(false),
          ),
        );
    final reminder = section(await sectionsFor(), RecordModule.reminder);
    expect(reminder.recordCount, 1);
    final row = reminder.rows.single;
    expect(row[1], 'service');
    expect(row[2], 'Oil Change');
    expect(row[3], 'Yes'); // repeat
    expect(row[6], '3000'); // every distance
  });

  test('soft-deleted records are excluded', () async {
    final id = await addRefuel(
      db,
      vid,
      date: DateTime(2026, 1, 1),
      odometer: 100,
      volume: 5,
    );
    await (db.update(db.refuelings)..where((r) => r.id.equals(id))).write(
      RefuelingsCompanion(deletedAt: Value(DateTime.now())),
    );

    final refueling = section(await sectionsFor(), RecordModule.refueling);
    expect(refueling.recordCount, 0);
    expect(refueling.rows, isEmpty);
  });

  test('period filter excludes records outside the range', () async {
    await addRefuel(
      db,
      vid,
      date: DateTime(2026, 1, 5),
      odometer: 100,
      volume: 5,
    );
    await addRefuel(
      db,
      vid,
      date: DateTime(2026, 2, 15),
      odometer: 200,
      volume: 5,
    );

    final sections = await sectionsFor(
      period: ExportPeriod(
        from: DateTime(2026, 2, 1),
        to: DateTime(2026, 2, 28),
      ),
    );
    final refueling = section(sections, RecordModule.refueling);
    expect(refueling.recordCount, 1);
    expect(refueling.rows.single[1], '2026-02-15');
  });

  test('vehicle filter only includes the chosen vehicle', () async {
    final otherVehicle = await addTestVehicle(db, name: 'Suzuki');
    await addRefuel(
      db,
      vid,
      date: DateTime(2026, 1, 1),
      odometer: 100,
      volume: 5,
    );
    await addRefuel(
      db,
      otherVehicle,
      date: DateTime(2026, 1, 2),
      odometer: 50,
      volume: 3,
    );

    final refueling = section(
      await sectionsFor(vehicleIds: [vid]),
      RecordModule.refueling,
    );
    expect(refueling.recordCount, 1);
    expect(refueling.rows.single[0], 'Honda');
  });
}
