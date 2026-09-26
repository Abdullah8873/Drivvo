import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart' hide Route;
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/theme/record_module.dart';
import 'package:motolog/features/catalog/catalog_queries.dart';
import 'package:motolog/features/entries/entry_queries.dart'
    show EntryDraft, EntryItemDraft, EntryQueries;
import 'package:motolog/features/entries/installments.dart';
import 'package:motolog/features/export/csv_writer.dart';
import 'package:motolog/features/export/export_data.dart';
import 'package:motolog/features/export/export_models.dart';
import 'package:motolog/features/export/export_rows.dart';
import 'package:motolog/features/import/csv_import.dart';
import 'package:motolog/features/import/csv_import_flow.dart';
import 'package:motolog/features/import/csv_import_service.dart';

import 'helpers.dart';
import 'history_fixtures.dart';

const _service = CsvImportService();

/// Exports [modules] of [vehicleIds] with the real export code (zip when
/// several modules, plain CSV for one).
Future<List<int>> _export(
  AppDatabase db,
  List<String> vehicleIds, {
  Set<RecordModule>? modules,
}) async {
  final picked = modules ?? {...exportableModules};
  final options = ExportOptions(
    vehicleIds: vehicleIds,
    vehicleLabel: 'x',
    period: null,
    modules: picked,
    format: ExportFormat.csv,
  );
  final data = await loadExportData(db, options);
  return buildCsvOrZipBytes(buildExportSections(data, picked, 'PKR'));
}

/// Every live record of [db] as comparable strings — catalog/vehicle ids
/// replaced by names, installment parents by their date + number — so two
/// databases with different ids compare field by field.
Future<List<String>> _snapshot(AppDatabase db) async {
  final names = {
    for (final c in await db.select(db.catalogItems).get()) c.id: c.name,
  };
  final vehicles = {
    for (final v in await db.select(db.vehicles).get()) v.id: v.name,
  };
  final out = <String>[];

  final fuels = await (db.select(
    db.refuelingFuels,
  )..where((f) => f.deletedAt.isNull())).get();
  for (final r in await (db.select(
    db.refuelings,
  )..where((r) => r.deletedAt.isNull())).get()) {
    final lines = [
      for (final f in fuels)
        if (f.refuelingId == r.id)
          '${names[f.fuelId]}/${f.tank}/${f.pricePerUnit}/${f.volume}/'
              '${f.total}',
    ]..sort();
    out.add(
      'refueling ${vehicles[r.vehicleId]} ${r.date} ${r.odometer} '
      '${r.fullTank} ${r.missedPrevious} ${names[r.gasStationId]} '
      '${names[r.paymentMethodId]} ${names[r.reasonId]} ${r.driver} '
      '${r.discount} ${r.totalCost} ${r.notes} $lines',
    );
  }

  final entries = await (db.select(
    db.entries,
  )..where((e) => e.deletedAt.isNull())).get();
  final byId = {for (final e in entries) e.id: e};
  final items = await (db.select(
    db.entryItems,
  )..where((i) => i.deletedAt.isNull())).get();
  for (final e in entries) {
    final parent = e.parentId == null ? null : byId[e.parentId];
    final lines = [
      for (final i in items)
        if (i.entryId == e.id) '${names[i.typeId]}/${i.amount}',
    ]..sort();
    out.add(
      'entry ${e.kind.name} ${vehicles[e.vehicleId]} ${e.date} ${e.odometer} '
      '${e.title} ${names[e.placeId]} ${names[e.paymentMethodId]} '
      '${names[e.reasonId]} ${e.driver} ${e.discount} ${e.totalCost} '
      '${e.installmentNo}/${e.installmentCount} '
      'parent=${parent == null ? '-' : '${parent.date}#${parent.installmentNo}'} '
      '${e.notes} $lines',
    );
  }

  for (final r in await (db.select(
    db.routes,
  )..where((r) => r.deletedAt.isNull())).get()) {
    out.add(
      'route ${vehicles[r.vehicleId]} ${r.mode.name} ${r.origin} '
      '${r.startDate} ${r.startOdometer} ${r.destination} ${r.endDate} '
      '${r.endOdometer} ${r.valuePerDistance} ${r.total} ${r.cargoType} '
      '${r.contractor} ${r.cargoUnit} ${r.cargoAmount} ${r.cargoWeight} '
      '${r.cargoVolume} ${r.freightValue} ${r.installments} ${r.driver} '
      '${names[r.reasonId]} ${r.notes}',
    );
  }

  for (final r in await (db.select(
    db.readings,
  )..where((r) => r.deletedAt.isNull())).get()) {
    out.add(
      'reading ${vehicles[r.vehicleId]} ${r.date} ${r.odometer} '
      '${r.driver} ${r.notes}',
    );
  }

  for (final r in await (db.select(
    db.reminders,
  )..where((r) => r.deletedAt.isNull())).get()) {
    out.add(
      'reminder ${vehicles[r.vehicleId]} ${r.target.name} ${names[r.typeId]} '
      '${r.repeat} ${r.byDistance} ${r.dueOdometer} ${r.everyDistance} '
      '${r.byDate} ${r.dueDate} ${r.everyAmount} ${r.everyUnit?.name} '
      '${r.lastDoneOdometer} ${r.lastDoneDate} ${r.active} ${r.notes}',
    );
  }
  return out..sort();
}

/// A source database with every module and the awkward cases: two fuel
/// lines, custom catalog names, a 3-installment plan, notes with commas,
/// quotes and a newline, an open route, a freight route, a checklist.
Future<void> _seedEverything(AppDatabase db, String honda, String civic) async {
  final shell = await CatalogQueries(db)
      .addCatalogItem(kind: CatalogKind.gasStation, name: 'Shell, Ring Road');
  final e85 = await CatalogQueries(db).addCatalogItem(
    kind: CatalogKind.fuel,
    name: 'E85',
    fuelKind: FuelKind.liquid,
  );
  final r1 = await db
      .into(db.refuelings)
      .insertReturning(
        RefuelingsCompanion.insert(
          vehicleId: honda,
          date: DateTime(2024, 1, 5, 8, 30),
          odometer: 10000,
          totalCost: 3663.375,
          fullTank: const Value(false),
          missedPrevious: const Value(true),
          gasStationId: Value(shell.id),
          paymentMethodId: const Value('seed:paymentMethod:money'),
          reasonId: const Value('seed:reason:work'),
          driver: const Value('Ali'),
          discount: const Value(0.5),
          notes: const Value('line one\nline "two", with comma'),
        ),
      );
  for (final (fuel, tank, price, volume, total) in [
    ('seed:fuel:petrol', 1, 293.03, 12.5, 3662.875),
    (e85.id, 2, 0.1, 10.0, 1.0),
  ]) {
    await db
        .into(db.refuelingFuels)
        .insert(
          RefuelingFuelsCompanion.insert(
            refuelingId: r1.id,
            fuelId: fuel,
            pricePerUnit: price,
            total: total,
            volume: volume,
            tank: Value(tank),
          ),
        );
  }
  await addRefuel(
    db,
    honda,
    date: DateTime(2024, 1, 20, 18, 5),
    odometer: 10321.7,
    volume: 9.87,
  );
  await addRefuel(
    db,
    civic,
    date: DateTime(2024, 1, 21, 7),
    odometer: 500,
    volume: 30,
    fuel: 'Diesel',
  );

  // Entries: plain, multi-item, custom type + place, and an installment
  // plan through the real save API.
  await addEntry(
    db,
    honda,
    kind: EntryKind.service,
    date: DateTime(2024, 2, 1, 10),
    items: {'Oil Change': 1200, 'Oil Filter': 450.25},
    odometer: 10500,
  );
  await addEntry(
    db,
    honda,
    kind: EntryKind.income,
    date: DateTime(2024, 2, 2, 11),
    items: {'Ride': 800},
  );
  final place = await CatalogQueries(db)
      .addCatalogItem(kind: CatalogKind.place, name: 'City Garage');
  final wash = await CatalogQueries(db)
      .addCatalogItem(kind: CatalogKind.expenseType, name: 'Detailing');
  final detail = await db
      .into(db.entries)
      .insertReturning(
        EntriesCompanion.insert(
          vehicleId: honda,
          kind: EntryKind.expense,
          date: DateTime(2024, 2, 3, 12, 15),
          totalCost: 999.99,
          title: const Value('Full detail'),
          placeId: Value(place.id),
          paymentMethodId: const Value('seed:paymentMethod:credit-card'),
          driver: const Value('Sara'),
          discount: const Value(0.01),
          notes: const Value('a,b'),
        ),
      );
  await db
      .into(db.entryItems)
      .insert(
        EntryItemsCompanion.insert(
          entryId: detail.id,
          typeId: wash.id,
          amount: 1000,
        ),
      );
  await db.saveEntry(
    EntryDraft(
      vehicleId: honda,
      kind: EntryKind.expense,
      date: DateTime(2024, 3, 1, 9),
      items: const [
        EntryItemDraft(typeId: 'seed:expenseType:insurance', amount: 1000),
      ],
      odometer: 11000,
      title: 'Yearly insurance',
      installments: 3,
      interval: InstallmentInterval.monthly,
    ),
  );

  // Routes: finished trip, open trip, freight.
  await db
      .into(db.routes)
      .insert(
        RoutesCompanion.insert(
          vehicleId: honda,
          origin: const Value('Lahore'),
          startDate: DateTime(2024, 4, 1, 6),
          startOdometer: 12000,
          destination: const Value('Islamabad'),
          endDate: Value(DateTime(2024, 4, 1, 11, 45)),
          endOdometer: const Value(12380.5),
          valuePerDistance: const Value(12.3),
          total: const Value(4680.015),
          driver: const Value('Ali'),
          reasonId: const Value('seed:reason:trip'),
        ),
      );
  await db
      .into(db.routes)
      .insert(
        RoutesCompanion.insert(
          vehicleId: honda,
          startDate: DateTime(2024, 4, 2, 7),
          startOdometer: 12400,
        ),
      );
  await db
      .into(db.routes)
      .insert(
        RoutesCompanion.insert(
          vehicleId: civic,
          mode: const Value(RouteMode.freight),
          startDate: DateTime(2024, 4, 3, 5),
          startOdometer: 600,
          endDate: Value(DateTime(2024, 4, 3, 20)),
          endOdometer: const Value(900),
          cargoType: const Value('Rice'),
          contractor: const Value('ACME'),
          cargoUnit: const Value('bags'),
          cargoAmount: const Value(40),
          cargoWeight: const Value(2000.5),
          cargoVolume: const Value(3.25),
          freightValue: const Value(15000),
          installments: const Value(2),
          notes: const Value('fragile'),
        ),
      );

  await db
      .into(db.readings)
      .insert(
        ReadingsCompanion.insert(
          vehicleId: honda,
          date: DateTime(2024, 5, 1, 9, 59),
          odometer: 12555.5,
          driver: const Value('Ali'),
          notes: const Value('dashboard'),
        ),
      );

  await db
      .into(db.reminders)
      .insert(
        RemindersCompanion.insert(
          vehicleId: honda,
          target: ReminderTarget.service,
          typeId: 'seed:serviceType:oil-change',
          repeat: const Value(true),
          byDistance: const Value(true),
          everyDistance: const Value(5000),
          byDate: const Value(true),
          everyAmount: const Value(6),
          everyUnit: const Value(PeriodUnit.month),
          lastDoneOdometer: const Value(10500),
          lastDoneDate: Value(DateTime(2024, 2, 1)),
          notes: const Value('synthetic oil'),
        ),
      );
  await db
      .into(db.reminders)
      .insert(
        RemindersCompanion.insert(
          vehicleId: civic,
          target: ReminderTarget.expense,
          typeId: 'seed:expenseType:tax',
          byDistance: const Value(false),
          byDate: const Value(true),
          dueDate: Value(DateTime(2025, 6, 30)),
          active: const Value(false),
        ),
      );

  await db
      .into(db.checklists)
      .insert(
        ChecklistsCompanion.insert(
          vehicleId: honda,
          date: DateTime(2024, 5, 2, 8),
          title: 'Pre-trip inspection',
        ),
      );
}

String _csv(List<String> lines) => '${lines.join('\r\n')}\r\n';

List<int> _bytes(String text) => utf8.encode(text);

void main() {
  late AppDatabase source;
  late AppDatabase target;
  late String honda;
  late String civic;
  late String targetHonda;
  late String targetCivic;

  setUp(() async {
    source = testDatabase();
    target = testDatabase();
    honda = await addTestVehicle(source, name: 'Honda');
    civic = await addTestVehicle(source, name: 'Civic');
    targetHonda = await addTestVehicle(target, name: 'Honda');
    targetCivic = await addTestVehicle(target, name: 'civic');
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  group('round trip', () {
    test('export → import reproduces every record field by field', () async {
      await _seedEverything(source, honda, civic);
      final bytes = await _export(source, [honda, civic]);

      final batch = parseImportFile(bytes, fileName: 'motolog-all.zip');
      expect(batch.issues, isEmpty);
      expect(batch.needsEntryKind, isFalse);
      expect(batch.notices.single, contains('1 checklist not imported'));

      final preview = await _service.preview(
        target,
        batch,
        currentVehicleId: targetHonda,
      );
      expect(preview.newCounts, {
        'refuelings': 3,
        'expenses': 4,
        'services': 1,
        'incomes': 1,
        'routes': 3,
        'readings': 1,
        'reminders': 2,
      });
      expect(preview.duplicateCount, 0);
      expect(preview.vehicleNotes, isEmpty); // "Civic" matched "civic"
      expect(
        preview.newCatalogItems,
        containsAll([
          'Gas station "Shell, Ring Road"',
          'Fuel "E85"',
          'Place "City Garage"',
          'Expense type "Detailing"',
        ]),
      );
      expect(preview.countsLabel, contains('3 refuelings'));

      final result = await _service.run(
        target,
        batch,
        currentVehicleId: targetHonda,
      );
      expect(result.importedCount, 15);
      expect(result.duplicateCount, 0);

      // Vehicle names differ only in case ("Civic" vs "civic"): normalize.
      final expected = (await _snapshot(
        source,
      )).map((s) => s.replaceAll(' Civic ', ' civic ')).toList()..sort();
      expect(await _snapshot(target), expected);

      // The imported installment plan is linked like a typed one.
      final plan = await (target.select(
        target.entries,
      )..where((e) => e.title.equals('Yearly insurance'))).get();
      expect(plan, hasLength(3));
      final parent = plan.singleWhere((e) => e.installmentNo == 1);
      expect(
        plan.where((e) => e.parentId == parent.id).map((e) => e.installmentNo),
        unorderedEquals([2, 3]),
      );
      expect(plan.every((e) => e.vehicleId == targetHonda), isTrue);

      // New fuels take the kind of the tank they went into.
      final e85 = await (target.select(
        target.catalogItems,
      )..where((c) => c.name.equals('E85'))).getSingle();
      expect(e85.fuelKind, FuelKind.liquid);
      expect(
        (await target.select(target.refuelings).get()).where(
          (r) => r.vehicleId == targetCivic,
        ),
        hasLength(1),
      );
    });

    test('importing the same file twice skips every duplicate', () async {
      await _seedEverything(source, honda, civic);
      final bytes = await _export(source, [honda, civic]);
      final batch = parseImportFile(bytes, fileName: 'motolog-all.zip');

      await _service.run(target, batch, currentVehicleId: targetHonda);
      final once = await _snapshot(target);

      final again = parseImportFile(bytes, fileName: 'motolog-all.zip');
      final preview = await _service.preview(
        target,
        again,
        currentVehicleId: targetHonda,
      );
      expect(preview.newCount, 0);
      expect(preview.duplicateCount, 15);
      expect(preview.newCatalogItems, isEmpty);

      final result = await _service.run(
        target,
        again,
        currentVehicleId: targetHonda,
      );
      expect(result.importedCount, 0);
      expect(result.duplicateCount, 15);
      expect(result.message, 'Imported 0 records, skipped 15 duplicates.');
      expect(await _snapshot(target), once);
    });

    test('a single-type CSV names its type and imports as that type', () async {
      await addEntry(
        source,
        honda,
        kind: EntryKind.income,
        date: DateTime(2024, 6, 1, 12),
        items: {'Refund': 55.5},
      );
      final bytes = await _export(
        source,
        [honda],
        modules: {RecordModule.income},
      );
      // What ExportService names it.
      final batch = parseImportFile(
        bytes,
        fileName: 'motolog-honda-20240601-income.csv',
      );
      expect(batch.needsEntryKind, isFalse);
      expect(batch.entries.single.kind, EntryKind.income);

      // Without a type in the name the user has to choose.
      final unnamed = parseImportFile(bytes, fileName: 'data.csv');
      expect(unnamed.needsEntryKind, isTrue);
      final chosen = parseImportFile(
        bytes,
        fileName: 'data.csv',
        entryKind: EntryKind.income,
      );
      expect(chosen.entries.single.kind, EntryKind.income);

      await _service.run(target, batch, currentVehicleId: targetHonda);
      expect(await _snapshot(target), await _snapshot(source));
    });

    test('a service item\'s part number round-trips through CSV', () async {
      final oilChange = await catalogId(
        source,
        CatalogKind.serviceType,
        'Oil Change',
      );
      final entry = await source
          .into(source.entries)
          .insertReturning(
            EntriesCompanion.insert(
              vehicleId: honda,
              kind: EntryKind.service,
              date: DateTime(2024, 6, 1, 9),
              totalCost: 1200,
            ),
          );
      await source
          .into(source.entryItems)
          .insert(
            EntryItemsCompanion.insert(
              entryId: entry.id,
              typeId: oilChange,
              amount: 1200,
              partNumber: const Value('Bosch WS10130'),
            ),
          );

      final bytes = await _export(
        source,
        [honda],
        modules: {RecordModule.service},
      );
      final batch = parseImportFile(bytes, fileName: 'service.csv');
      expect(batch.issues, isEmpty);
      await _service.run(target, batch, currentVehicleId: targetHonda);

      final items = await target.select(target.entryItems).get();
      expect(items.single.partNumber, 'Bosch WS10130');
    });

    test('a CSV exported before Part Number existed still imports', () async {
      final bytes = _bytes(
        _csv([
          'Vehicle,Date,Time,Odometer,Title,Type,Item Amount,Place,'
              'Payment Method,Reason,Driver,Discount,Installment No,'
              'Installment Count,Total Cost,Currency,Notes',
          'Honda,2024-06-01,09:00,,,Oil Change,1200,,,,,,1,1,1200,PKR,',
        ]),
      );
      final batch = parseImportFile(bytes, fileName: 'old-service-export.csv');
      expect(batch.issues, isEmpty);
      expect(batch.needsEntryKind, isFalse);
      expect(batch.entries.single.items.single.partNumber, isNull);

      await _service.run(target, batch, currentVehicleId: targetHonda);
      final items = await target.select(target.entryItems).get();
      expect(items.single.partNumber, isNull);
    });
  });

  group('preview dialog', () {
    testWidgets('lists counts and problems; asks which type a lone entry '
        'table is', (tester) async {
      final text = _csv([
        'Vehicle,Date,Time,Odometer,Title,Type,Item Amount,Place,'
            'Payment Method,Reason,Driver,Discount,Installment No,'
            'Installment Count,Total Cost,Currency,Notes',
        'Honda,2024-01-01,08:00,,,Refund,150,,,,,,1,1,150,PKR,',
        'Honda,2024-13-01,08:00,,,Refund,150,,,,,,1,1,150,PKR,',
      ]);
      CsvImportBatch? popped;
      await tester.pumpWidget(
        MaterialApp(
          // Ripple, not the M3 sparkle shader (not in the test renderer).
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => popped = await showDialog(
                context: context,
                builder: (_) => CsvImportPreviewDialog(
                  db: target,
                  bytes: _bytes(text),
                  fileName: 'sheet.csv',
                  currentVehicleId: targetHonda,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(find.text('Adds 1 expense.'), findsOneWidget);
      expect(find.textContaining('sheet.csv line 3:'), findsOneWidget);
      expect(find.text('These rows are:'), findsOneWidget);

      await tester.tap(find.text('Income'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.text('Adds 1 income.'), findsOneWidget);

      await tester.tap(find.text('IMPORT'));
      await tester.pumpAndSettle();
      expect(popped!.entries.single.kind, EntryKind.income);
    });

    /// Pumps a button that opens the dialog for [bytes]; returns a getter
    /// for what the dialog popped with.
    Future<CsvImportBatch? Function()> openPreview(
      WidgetTester tester,
      List<int> bytes,
      String fileName,
    ) async {
      CsvImportBatch? popped;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => popped = await showDialog(
                context: context,
                builder: (_) => CsvImportPreviewDialog(
                  db: target,
                  bytes: bytes,
                  fileName: fileName,
                  currentVehicleId: targetHonda,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      return () => popped;
    }

    bool importEnabled(WidgetTester tester) =>
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'IMPORT'))
            .onPressed !=
        null;

    final readingCsv = _csv([
      'Vehicle,Date,Time,Odometer,Driver,Notes',
      'Honda,2024-01-01,08:00,100,,',
    ]);

    testWidgets('CANCEL closes without importing anything', (tester) async {
      final popped = await openPreview(
        tester,
        _bytes(readingCsv),
        'Reading.csv',
      );
      expect(find.text('Adds 1 reading.'), findsOneWidget);
      expect(importEnabled(tester), isTrue);

      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      expect(find.text('Import CSV'), findsNothing);
      expect(popped(), isNull);
    });

    testWidgets('a file already imported offers nothing to import', (
      tester,
    ) async {
      await tester.runAsync(
        () => _service.run(
          target,
          parseImportFile(_bytes(readingCsv), fileName: 'Reading.csv'),
          currentVehicleId: targetHonda,
        ),
      );
      await openPreview(tester, _bytes(readingCsv), 'Reading.csv');
      expect(
        find.text('1 already on this device — skipped as duplicates.'),
        findsOneWidget,
      );
      expect(importEnabled(tester), isFalse);
    });

    testWidgets('a file that is not an export shows why, IMPORT disabled', (
      tester,
    ) async {
      await openPreview(
        tester,
        _bytes(_csv(['Name,Amount', 'x,1'])),
        'other.csv',
      );
      expect(find.textContaining('Not a MotoLog export'), findsOneWidget);
      expect(importEnabled(tester), isFalse);
    });

    testWidgets('a damaged zip is reported, IMPORT disabled', (tester) async {
      // Zip magic number followed by garbage.
      await openPreview(tester, [0x50, 0x4B, 0x03, 0x04, 1, 2, 3], 'x.zip');
      expect(find.textContaining('The .zip file is damaged.'), findsOneWidget);
      expect(importEnabled(tester), isFalse);
    });
  });

  group('errors', () {
    test('malformed rows are reported with line numbers and skipped', () async {
      final text = _csv([
        'Vehicle,Date,Time,Odometer,Driver,Notes',
        'Honda,2024-01-01,08:00,100,,', // line 2: fine
        'Honda,01/02/2024,08:00,200,,', // line 3: bad date
        'Honda,2024-01-03,08:00,"1,5",,', // line 4: comma number
        '', // line 5: blank, ignored
        'Honda,2024-02-30,08:00,300,,', // line 6: no such day
        'Honda,2024-01-04,25:00,400,,', // line 7: bad time
        'Honda,2024-01-05,,,,', // line 8: odometer missing
        'Honda,2024-01-06,,500,,"multi', // line 9: multi-line note...
        'line note"', // ...still line 9 of the spreadsheet
        'Honda,2024-01-07,09:10,600,,', // line 10: fine
      ]);
      final batch = parseImportFile(_bytes(text), fileName: 'Reading.csv');
      expect(batch.readings.map((r) => r.odometer), [100, 500, 600]);
      expect(batch.readings[1].notes, 'multi\r\nline note');
      expect(batch.readings[1].date, DateTime(2024, 1, 6));
      expect(batch.issues.map((i) => i.line), [3, 4, 6, 7, 8]);
      expect(batch.issues[0].message, contains('not a date'));
      expect(batch.issues[1].message, contains('not a number'));
      expect(batch.issues[3].message, contains('not a time'));
      expect(batch.issues[4].message, contains('Odometer is missing'));
      expect(batch.issues.first.toString(), startsWith('Reading.csv line 3:'));

      final preview = await _service.preview(
        target,
        batch,
        currentVehicleId: targetHonda,
      );
      expect(preview.errorRowCount, 5);
      final result = await _service.run(
        target,
        batch,
        currentVehicleId: targetHonda,
      );
      expect(result.importedCount, 3);
      expect(result.errorRowCount, 5);
      expect(await target.select(target.readings).get(), hasLength(3));
    });

    test('a record with one bad line is skipped whole, not half', () async {
      const header =
          'Vehicle,Date,Time,Odometer,Fuel,Tank,Price/Unit,Volume,Line Total,'
          'Full Tank,Missed Previous,Gas Station,Payment Method,Reason,Driver,'
          'Discount,Total Cost,Currency,Notes';
      final text = _csv([
        header,
        'Honda,2024-01-01,08:00,100,Petrol,1,2,10,20,Yes,No,,,,,,25,PKR,',
        'Honda,2024-01-01,08:00,100,CNG,2,1,abc,5,Yes,No,,,,,,25,PKR,',
        'Honda,2024-01-02,08:00,200,Petrol,1,2,10,20,Maybe,No,,,,,,20,PKR,',
        'Honda,2024-01-03,08:00,300,Petrol,1,2,10,20,Yes,No,,,,,,20.000001,PKR,',
      ]);
      final batch = parseImportFile(_bytes(text), fileName: 'Refueling.csv');
      expect(batch.refuelings, hasLength(1));
      expect(batch.refuelings.single.totalCost, 20.000001);
      expect(batch.errorRowCount, 3);
      expect(batch.issues.map((i) => (i.line, i.message)), [
        (
          3,
          'Volume "abc" is not a number (use a dot for decimals, no '
              'thousands separators).',
        ),
        (4, 'Full Tank "Maybe" must be Yes or No.'),
      ]);
      // Rows 2+3 formed one record: its good line wasn't imported alone.
      await _service.run(target, batch, currentVehicleId: targetHonda);
      final stored = await target.select(target.refuelings).get();
      expect(stored.single.odometer, 300);
      expect(stored.single.totalCost, 20.000001); // stored exactly as typed
    });

    test('a file that is not an export is reported, not guessed', () {
      final batch = parseImportFile(
        _bytes(_csv(['Name,Amount', 'x,1'])),
        fileName: 'other.csv',
      );
      expect(batch.recordCount, 0);
      expect(batch.issues.single.message, contains('Not a MotoLog export'));
    });

    test('no vehicle to import into is reported per record', () async {
      final batch = parseImportFile(
        _bytes(
          _csv([
            'Vehicle,Date,Time,Odometer,Driver,Notes',
            'Truck,2024-01-01,08:00,100,,',
          ]),
        ),
        fileName: 'Reading.csv',
      );
      final preview = await _service.preview(
        target,
        batch,
        currentVehicleId: null,
      );
      expect(preview.newCount, 0);
      expect(preview.issues.single.line, 2);
      expect(preview.issues.single.message, contains('No vehicle named'));
    });
  });

  group('matching', () {
    test('unknown catalog names become new custom items', () async {
      final text = _csv([
        'Vehicle,Date,Time,Odometer,Title,Type,Item Amount,Place,'
            'Payment Method,Reason,Driver,Discount,Installment No,'
            'Installment Count,Total Cost,Currency,Notes',
        'Honda,2024-01-01,08:00,,,Toll Plaza Fee,150,Motorway M2,crypto,'
            'WORK,,,1,1,150,PKR,',
        'Honda,2024-01-01,08:00,,,tolls,10,Motorway M2,crypto,WORK,,,1,1,'
            '150,PKR,',
      ]);
      final batch = parseImportFile(_bytes(text), fileName: 'Expense.csv');
      expect(batch.entries.single.items, hasLength(2));
      final preview = await _service.preview(
        target,
        batch,
        currentVehicleId: targetHonda,
      );
      expect(preview.newCatalogItems, [
        'Expense type "Toll Plaza Fee"',
        'Place "Motorway M2"',
        'Payment method "crypto"',
      ]);

      final before = await target.select(target.catalogItems).get();
      await _service.run(target, batch, currentVehicleId: targetHonda);
      final after = await target.select(target.catalogItems).get();
      expect(after.length, before.length + 3);

      final entry = await target.select(target.entries).getSingle();
      // "WORK" and "tolls" matched the seeded "Work" / "Tolls".
      expect(entry.reasonId, 'seed:reason:work');
      final items = await target.select(target.entryItems).get();
      expect(items.map((i) => i.typeId), contains('seed:expenseType:tolls'));
      expect(
        after.map((c) => (c.kind, c.name)),
        containsAll([
          (CatalogKind.expenseType, 'Toll Plaza Fee'),
          (CatalogKind.place, 'Motorway M2'),
          (CatalogKind.paymentMethod, 'crypto'),
        ]),
      );
    });

    test('unknown vehicle names go to the selected vehicle', () async {
      final text = _csv([
        'Vehicle,Date,Time,Odometer,Driver,Notes',
        'Old Bike,2024-01-01,08:00,100,,',
        ',2024-01-02,08:00,200,,',
        'HONDA,2024-01-03,08:00,300,,',
      ]);
      final batch = parseImportFile(_bytes(text), fileName: 'Reading.csv');
      final preview = await _service.preview(
        target,
        batch,
        currentVehicleId: targetCivic,
      );
      expect(preview.vehicleNotes, [
        'No vehicle named "Old Bike" — its records go to "civic".',
        'Rows without a vehicle go to "civic".',
      ]);
      await _service.run(target, batch, currentVehicleId: targetCivic);
      final readings = await target.select(target.readings).get();
      expect(
        {for (final r in readings) r.odometer: r.vehicleId},
        {100.0: targetCivic, 200.0: targetCivic, 300.0: targetHonda},
      );
    });

    test('a semicolon-separated re-save is read too', () {
      final text = _csv([
        'Vehicle;Date;Time;Odometer;Driver;Notes',
        'Honda;2024-01-01;08:00;100.25;Ali;x',
      ]);
      final batch = parseImportFile(_bytes(text), fileName: 'Reading.csv');
      expect(batch.issues, isEmpty);
      expect(batch.readings.single.odometer, 100.25);
      expect(batch.readings.single.driver, 'Ali');
    });

    test('a failed import leaves nothing behind', () async {
      final batch = parseImportFile(
        _bytes(
          _csv([
            'Vehicle,Date,Time,Odometer,Driver,Notes',
            'Honda,2024-01-01,08:00,100,,',
          ]),
        ),
        fileName: 'Reading.csv',
      );
      batch.reminders.addAll(
        parseImportFile(
          _bytes(
            _csv([
              'Vehicle,Target,Type,Repeat,By Distance,Due Odometer,'
                  'Every Distance,By Date,Due Date,Every Amount,Every Unit,'
                  'Last Done Odometer,Last Done Date,Active,Notes',
              'Honda,service,Brand New Type,No,Yes,5000,,No,,,,,,Yes,',
            ]),
          ),
          fileName: 'Reminders.csv',
        ).reminders,
      );
      // Reminders are written after readings (and after the new catalog
      // type); make that last insert fail like a full disk would.
      await target.customStatement(
        "CREATE TRIGGER fail_reminder BEFORE INSERT ON reminders "
        "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );
      final catalogBefore = await target.select(target.catalogItems).get();
      await expectLater(
        _service.run(target, batch, currentVehicleId: targetHonda),
        throwsA(anything),
      );
      expect(await target.select(target.readings).get(), isEmpty);
      expect(
        await target.select(target.catalogItems).get(),
        hasLength(catalogBefore.length),
      );
    });
  });
}
