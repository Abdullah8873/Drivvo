import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:motolog/core/calc/checklist_math.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/theme/record_module.dart';
import 'package:motolog/features/checklists/checklist_queries.dart';
import 'package:motolog/features/history/history_calc.dart';
import 'package:motolog/features/history/history_queries.dart';

import 'helpers.dart';
import 'history_fixtures.dart';
import 'route_reading_test_utils.dart';

void main() {
  group('ChecklistCounts', () {
    test('counts and summarizes', () {
      final c = ChecklistCounts.of([
        ChecklistStatus.ok,
        ChecklistStatus.ok,
        ChecklistStatus.problem,
        ChecklistStatus.na,
        null,
      ]);
      expect((c.ok, c.problem, c.na, c.unchecked, c.total), (2, 1, 1, 1, 5));
      expect(c.summary, '2 OK · 1 problem · 1 N/A');
      expect(
        ChecklistCounts.of([ChecklistStatus.problem, ChecklistStatus.problem])
            .summary,
        '2 problems',
      );
      expect(ChecklistCounts.of([null]).summary, 'Not checked');
    });
  });

  late AppDatabase db;
  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  Future<List<Checklist>> checklists(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.checklists).get()))!;

  Future<List<ChecklistAnswer>> answers(WidgetTester tester, String id) async =>
      (await tester.runAsync(
        () => db.getChecklist(id).then((d) => d!.answers),
      ))!;

  testWidgets('fills in, saves and edits a checklist', (tester) async {
    useTallScreen(tester);
    final vid = await seedVehicle(tester, db, lastOdometer: 1400);
    await tester.pumpWidget(testApp(db));
    await tester.pumpAndSettle();
    await openForm(tester, 'Checklist');

    // No form chosen yet.
    await save(tester);
    expect(find.text('Choose a form'), findsOneWidget);

    expect(find.text('Last odometer: 1400 km'), findsOneWidget);
    await tester.tap(find.byKey(const Key('checklist-form-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pre-trip inspection'));
    await tester.pumpAndSettle();
    expect(find.text('Engine oil level'), findsOneWidget);

    await tester.enterText(field('Odometer (optional)'), '1500');
    await tester.tap(find.byKey(const Key('status-ok-Tires')));
    await tester.tap(find.byKey(const Key('status-ok-Brakes')));
    await tester.tap(find.byKey(const Key('status-problem-Lights')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('note-Lights')), 'Bulb out');
    await tester.tap(find.byKey(const Key('status-na-Horn')));
    await save(tester);
    expect(find.text('Checklist saved'), findsOneWidget);

    final saved = (await checklists(tester)).single;
    expect(saved.vehicleId, vid);
    expect(saved.title, 'Pre-trip inspection');
    expect(saved.odometer, 1500);
    final list = await answers(tester, saved.id);
    expect(list, hasLength(9));
    final lights = list.firstWhere((a) => a.label == 'Lights');
    expect(lights.status, ChecklistStatus.problem);
    expect(lights.note, 'Bulb out');
    expect(
      list.firstWhere((a) => a.label == 'Horn').status,
      ChecklistStatus.na,
    );
    expect(list.firstWhere((a) => a.label == 'Mirrors').status, isNull);

    // History shows it as a blue row without an amount.
    expect(find.text('Pre-trip inspection'), findsOneWidget);
    expect(find.text('1500 km · 2 OK · 1 problem · 1 N/A'), findsOneWidget);

    // Edit: the answers load; a change is saved in place (same ids).
    GoRouter.of(tester.element(find.text('History')))
        .push('/edit/checklist/${saved.id}');
    await tester.pumpAndSettle();
    expect(find.text('Bulb out'), findsOneWidget);
    await tester.tap(find.byKey(const Key('status-ok-Mirrors')));
    // Un-marking the problem drops its note.
    await tester.tap(find.byKey(const Key('status-problem-Lights')));
    await tester.pump();
    expect(find.byKey(const Key('note-Lights')), findsNothing);
    await save(tester);

    final after = await answers(tester, saved.id);
    expect(after.map((a) => a.id), list.map((a) => a.id));
    expect(
      after.firstWhere((a) => a.label == 'Mirrors').status,
      ChecklistStatus.ok,
    );
    final lightsAfter = after.firstWhere((a) => a.label == 'Lights');
    expect(lightsAfter.status, isNull);
    expect(lightsAfter.note, isNull);
    await finish(tester);
  });

  testWidgets('template editor creates, edits and deletes forms', (
    tester,
  ) async {
    useTallScreen(tester);
    await tester.pumpWidget(testApp(db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forms'));
    await tester.pumpAndSettle();
    expect(find.text('Pre-trip inspection'), findsOneWidget);
    expect(find.text('9 items'), findsOneWidget);

    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('form-name')), 'Walkaround');
    await tester.enterText(find.byKey(const Key('form-item-0')), 'Tires');
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('form-item-1')), 'Lights');
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('form-item-2')), 'Horn');
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(find.text('Walkaround'), findsOneWidget);
    expect(find.text('3 items'), findsOneWidget);

    // Edit: drag "Horn" to the top, remove "Lights".
    await tester.tap(find.text('Walkaround'));
    await tester.pumpAndSettle();
    final handles = find.byIcon(Icons.drag_handle);
    await tester.drag(handles.at(2), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove item').at(2)); // Lights
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(find.text('2 items'), findsOneWidget);

    final forms = (await tester.runAsync(
      () => db.watchChecklistForms().first,
    ))!;
    final walk = forms.firstWhere((f) => f.form.name == 'Walkaround');
    final details = await tester.runAsync(
      () => db.getChecklistForm(walk.form.id),
    );
    expect(details!.items.map((i) => i.label), ['Horn', 'Tires']);

    // Delete (soft): gone from the list.
    await tester.tap(find.text('Walkaround'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DELETE'));
    await tester.pumpAndSettle();
    expect(find.text('Walkaround'), findsNothing);
    await finish(tester);
  });

  test('checklists are never costs in the month totals', () async {
    final vid = await addTestVehicle(db);
    await addRefuel(
      db,
      vid,
      date: DateTime(2026, 9, 5),
      odometer: 1000,
      volume: 10,
      price: 100,
    );
    await db.saveChecklist(
      ChecklistDraft(
        vehicleId: vid,
        date: DateTime(2026, 9, 6),
        odometer: 99999, // a typo must not inflate the month's distance
        title: 'Pre-trip inspection',
        answers: const [
          ChecklistAnswerDraft(
            label: 'Tires',
            status: ChecklistStatus.problem,
            note: 'Low',
          ),
        ],
      ),
    );
    final timeline = await db.loadTimeline(vid);
    final checklist = timeline.firstWhere(
      (r) => r.module == RecordModule.checklist,
    );
    expect(checklist.isCost, isFalse);
    expect(checklist.isIncome, isFalse);
    expect(checklist.amount, 0);
    expect(checklist.title, 'Pre-trip inspection');
    final month = groupByMonth(timeline).single;
    expect(month.records, hasLength(2));
    expect(month.spent, 1000);
    expect(month.costByModule.keys, [RecordModule.refueling]);
    expect(month.odometers, [1000]);
  });

  testWidgets('history row expands to the problem items', (tester) async {
    useTallScreen(tester);
    await tester.runAsync(() async {
      final vid = await addTestVehicle(db);
      await addRefuel(
        db,
        vid,
        date: DateTime(2026, 9, 5),
        odometer: 1000,
        volume: 10,
        price: 100,
      );
      await db.saveChecklist(
        ChecklistDraft(
          vehicleId: vid,
          date: DateTime(2026, 9, 6),
          title: 'Pre-trip inspection',
          answers: const [
            ChecklistAnswerDraft(label: 'Tires', status: ChecklistStatus.ok),
            ChecklistAnswerDraft(
              label: 'Brakes',
              status: ChecklistStatus.problem,
              note: 'Squeaky',
            ),
          ],
        ),
      );
    });
    await tester.pumpWidget(testApp(db));
    await tester.pumpAndSettle();

    expect(find.text('1 OK · 1 problem'), findsOneWidget);
    // Month spend only counts the refuel.
    expect(find.text('PKR1,000.00'), findsWidgets);
    await tester.tap(find.text('Pre-trip inspection'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Squeaky'), findsOneWidget);

    // Search matches item labels and notes.
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('history-search-field')),
      'squeak',
    );
    await tester.pumpAndSettle();
    expect(find.text('Pre-trip inspection'), findsOneWidget);
    await finish(tester);
  });
}
