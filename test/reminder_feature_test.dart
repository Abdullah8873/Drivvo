import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/calc/reminder_math.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/providers.dart';
import 'package:motolog/core/theme/record_module.dart';
import 'package:motolog/core/widgets/module_form_scaffold.dart';
import 'package:motolog/core/widgets/select_list_screen.dart';
import 'package:motolog/features/reminders/reminder_providers.dart';
import 'package:motolog/features/reminders/reminder_queries.dart';
import 'package:motolog/features/reminders/upcoming_reminders_strip.dart';

import 'helpers.dart';

Future<String> typeId(AppDatabase db, CatalogKind kind, String name) async =>
    (await db.watchCatalog(kind).first).firstWhere((c) => c.name == name).id;

Future<void> addRefuel(AppDatabase db, String vid, DateTime date, double odo) =>
    db
        .into(db.refuelings)
        .insert(
          RefuelingsCompanion.insert(
            vehicleId: vid,
            date: date,
            odometer: odo,
            totalCost: 1000,
          ),
        );

/// Logs a service entry with one item of [type]; returns the entry id.
Future<String> addService(
  AppDatabase db,
  String vid,
  String type,
  DateTime date,
  double? odo,
) async {
  final e = await db
      .into(db.entries)
      .insertReturning(
        EntriesCompanion.insert(
          vehicleId: vid,
          kind: EntryKind.service,
          date: date,
          totalCost: 500,
          odometer: Value(odo),
        ),
      );
  await db
      .into(db.entryItems)
      .insert(
        EntryItemsCompanion.insert(entryId: e.id, typeId: type, amount: 500),
      );
  return e.id;
}

/// Removes the app while still inside the test's fake clock, so drift can
/// flush the zero-length timer it schedules when its streams close
/// (otherwise the test fails with "A Timer is still pending").
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  // `pump()` alone doesn't advance the fake clock; a tick fires the timer.
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  group('ReminderQueries', () {
    late AppDatabase db;
    setUp(() => db = testDatabase());
    tearDown(() => db.close());

    test('odometer history merges every record table', () async {
      final vid = await addTestVehicle(db);
      await addRefuel(db, vid, DateTime(2026, 9, 10), 56500);
      await db
          .into(db.readings)
          .insert(
            ReadingsCompanion.insert(
              vehicleId: vid,
              date: DateTime(2026, 9, 1),
              odometer: 56000,
            ),
          );
      await db
          .into(db.routes)
          .insert(
            RoutesCompanion.insert(
              vehicleId: vid,
              startDate: DateTime(2026, 9, 12),
              startOdometer: 56600,
              endDate: Value(DateTime(2026, 9, 13)),
              endOdometer: const Value(56800),
            ),
          );
      final history = await db.watchOdometerHistory(vid).first;
      expect(history.map((p) => p.odometer), [56000, 56500, 56600, 56800]);
      expect(history.first.date, DateTime(2026, 9, 1));
    });

    test('last logged by type ignores deleted entries', () async {
      final vid = await addTestVehicle(db);
      final oil = await typeId(db, CatalogKind.serviceType, 'Oil Change');
      await addService(db, vid, oil, DateTime(2026, 6, 1), 55000);
      final newer = await addService(db, vid, oil, DateTime(2026, 8, 1), 56000);
      var logged = await db.watchLastLoggedByType(vid).first;
      expect(logged[oil], (date: DateTime(2026, 8, 1), odometer: 56000.0));

      await (db.update(db.entries)..where((e) => e.id.equals(newer))).write(
        EntriesCompanion(deletedAt: Value(DateTime.now())),
      );
      logged = await db.watchLastLoggedByType(vid).first;
      expect(logged[oil]!.odometer, 55000);
    });

    test('insert, update and soft delete', () async {
      final vid = await addTestVehicle(db);
      final oil = await typeId(db, CatalogKind.serviceType, 'Oil Change');
      final id = await db.insertReminder(
        RemindersCompanion.insert(
          vehicleId: vid,
          target: ReminderTarget.service,
          typeId: oil,
          dueOdometer: const Value(60000),
        ),
      );
      final before = (await db.getReminder(id))!;
      await db.updateReminder(
        id,
        const RemindersCompanion(dueOdometer: Value(61000)),
      );
      final after = (await db.getReminder(id))!;
      expect(after.dueOdometer, 61000);
      expect(after.updatedAt.isBefore(before.updatedAt), isFalse);

      await db.softDeleteReminder(id);
      expect(await db.getReminder(id), isNull);
      expect(await db.watchReminders(vid).first, isEmpty);
      // Still in the table (soft delete) for sync.
      expect(await db.select(db.reminders).get(), hasLength(1));
    });
  });

  group('upcomingRemindersProvider', () {
    test('next refueling first, then reminders by urgency', () async {
      final db = testDatabase();
      addTearDown(db.close);
      final container = ProviderContainer.test(
        overrides: [
          databaseProvider.overrideWithValue(db),
          reminderClockProvider.overrideWithValue(
            () => DateTime(2026, 9, 23, 9),
          ),
        ],
      );

      final vid = await addTestVehicle(db);
      await addRefuel(db, vid, DateTime(2026, 9, 1), 56000);
      await addRefuel(db, vid, DateTime(2026, 9, 11), 56200);
      await addRefuel(db, vid, DateTime(2026, 9, 21), 56400);
      await db
          .into(db.readings)
          .insert(
            ReadingsCompanion.insert(
              vehicleId: vid,
              date: DateTime(2026, 9, 23),
              odometer: 56450,
            ),
          );
      final oil = await typeId(db, CatalogKind.serviceType, 'Oil Change');
      final tires = await typeId(db, CatalogKind.serviceType, 'New Tires');
      final tax = await typeId(db, CatalogKind.expenseType, 'Tax');
      // Oil changed at 55600 → every 1000 km → due 56600 (150 left: soon).
      await addService(db, vid, oil, DateTime(2026, 8, 1), 55600);
      await db.insertReminder(
        RemindersCompanion.insert(
          vehicleId: vid,
          target: ReminderTarget.service,
          typeId: oil,
          repeat: const Value(true),
          everyDistance: const Value(1000),
          createdAt: Value(DateTime(2026, 1, 1)),
          lastDoneOdometer: const Value(50000),
          lastDoneDate: Value(DateTime(2026, 1, 1)),
        ),
      );
      // Far away tires reminder (ok).
      await db.insertReminder(
        RemindersCompanion.insert(
          vehicleId: vid,
          target: ReminderTarget.service,
          typeId: tires,
          dueOdometer: const Value(70000),
        ),
      );
      // Tax due yesterday (overdue), inactive → only in the tab list.
      await db.insertReminder(
        RemindersCompanion.insert(
          vehicleId: vid,
          target: ReminderTarget.expense,
          typeId: tax,
          byDistance: const Value(false),
          byDate: const Value(true),
          dueDate: Value(DateTime(2026, 9, 22)),
          active: const Value(false),
        ),
      );

      container.listen(upcomingRemindersProvider(vid), (_, _) {});
      final items = await container.read(upcomingRemindersProvider(vid).future);
      expect(items.map((i) => i.title), [
        'Next refueling',
        'Oil Change',
        'New Tires',
      ]);

      final refuel = items[0];
      expect(refuel.isPrediction, isTrue);
      expect(refuel.module, RecordModule.refueling);
      expect(refuel.dueText, '56600 km · 01 oct');
      expect(refuel.remainingText, 'in 150 km · in 8 days');

      final oilItem = items[1];
      expect(oilItem.module, RecordModule.service);
      expect(oilItem.status, ReminderStatus.soon);
      expect(oilItem.dueText, startsWith('56600 km · '));
      expect(oilItem.remainingText, startsWith('in 150 km · in '));

      container.listen(reminderItemsProvider(vid), (_, _) {});
      final all = await container.read(reminderItemsProvider(vid).future);
      expect(all.first.title, 'Tax');
      expect(all.first.status, ReminderStatus.overdue);
      expect(all.first.remainingText, 'overdue by 1 day');
      expect(all.first.module, RecordModule.expense);
    });
  });

  group('screens', () {
    testWidgets('create, list, edit and delete a reminder', (tester) async {
      final db = testDatabase();
      addTearDown(db.close);
      await addTestVehicle(db);
      await tester.pumpWidget(testApp(db));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reminders'));
      await tester.pumpAndSettle();
      expect(find.text('Add your first reminder'), findsOneWidget);

      // Open the form from the + speed dial.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reminder'));
      await tester.pumpAndSettle();
      expect(find.text('JUST ONE TIME'), findsOneWidget);

      // Saving without a type shows a validation message.
      await tester.ensureVisible(find.text('SAVE'));
      await tester.tap(find.text('SAVE'));
      await tester.pump();
      expect(find.text('Select the type'), findsOneWidget);

      await tester.tap(find.widgetWithText(PickerField, 'Type of service'));
      await tester.pumpAndSettle();
      // The list is lazy (only visible rows exist), so search first.
      await tester.enterText(
        find.descendant(
          of: find.byType(SelectListScreen),
          matching: find.byType(TextField),
        ),
        'Oil',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oil Change'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Odometer'),
        '60000',
      );
      await tester.ensureVisible(find.text('SAVE'));
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      expect(find.text('Oil Change'), findsOneWidget);
      expect(find.textContaining('60000 km'), findsOneWidget);

      // Edit: loads the saved values; delete from the app bar.
      await tester.tap(find.text('Oil Change'));
      await tester.pumpAndSettle();
      expect(find.text('Oil Change'), findsOneWidget);
      expect(find.text('60000'), findsOneWidget);
      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DELETE'));
      await tester.pumpAndSettle();

      expect(find.text('Add your first reminder'), findsOneWidget);
      expect(await db.select(db.reminders).get(), hasLength(1));
      await unmount(tester);
    });

    testWidgets('strip shows the next refueling card', (tester) async {
      final db = testDatabase();
      addTearDown(db.close);
      final vid = await addTestVehicle(db);
      await addRefuel(db, vid, DateTime(2026, 9, 1), 56000);
      await addRefuel(db, vid, DateTime(2026, 9, 11), 56200);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            reminderClockProvider.overrideWithValue(
              () => DateTime(2026, 9, 12),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: UpcomingRemindersStrip(vehicleId: vid)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('REMINDERS'), findsOneWidget);
      expect(find.text('Next refueling'), findsOneWidget);
      expect(find.text('56400 km · 21 sep'), findsOneWidget);
      expect(find.text('in 200 km · in 9 days'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('form asks for a vehicle when there is none', (tester) async {
      final db = testDatabase();
      addTearDown(db.close);
      await tester.pumpWidget(testApp(db));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reminder'));
      await tester.pumpAndSettle();
      expect(
        find.text('Add a vehicle before creating reminders'),
        findsOneWidget,
      );
      expect(find.text('ADD VEHICLE'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('repeat mode shows the interval fields', (tester) async {
      final db = testDatabase();
      addTearDown(db.close);
      await addTestVehicle(db);
      await tester.pumpWidget(testApp(db));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reminder'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('REPEAT EVERY'));
      await tester.pumpAndSettle();
      expect(find.text('Every (km)'), findsOneWidget);
      expect(find.text('MONTHS'), findsNothing);
      // Tick the "Time" trigger → amount + period appear.
      await tester.tap(find.byType(Checkbox).last);
      await tester.pumpAndSettle();
      expect(find.text('MONTHS'), findsOneWidget);
      await unmount(tester);
    });
  });
}
