import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/app.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/providers.dart';
import 'package:motolog/core/router/app_router.dart';
import 'package:motolog/core/widgets/select_list_screen.dart';
import 'package:motolog/core/widgets/speed_dial_menu.dart';
import 'package:motolog/features/reminders/reminder_queries.dart';

import 'helpers.dart';
import 'history_fixtures.dart';

/// Layout smoke matrix: pumps every main screen at phone / tablet /
/// landscape sizes and several text-scale factors and asserts nothing
/// overflows (`tester.takeException()` surfaces a `RenderFlex overflowed`
/// error the same way a real device would show the yellow/black stripes).
///
/// Every screen is checked at 320×568 @ 2.0× text (worst case for width —
/// the smallest phone Drivvo is expected to run on, biggest system font)
/// and at 1280×800 @ 1.0× (worst case for a form/list stretching edge to
/// edge on a wide tablet/landscape window). A rotating subset of screens
/// also covers 360×640 and 800×1280 at 1.3× so the whole matrix gets
/// exercised without every screen paying for every combination — this file
/// should run in well under a minute.
void main() {
  late AppDatabase db;
  late String vehicleId;

  /// Sets the test view's logical size, device pixel ratio 1 (so the size
  /// above is exactly the logical/layout size) and a text-scale override —
  /// the harness-level equivalent of "Settings > Display size" on a phone.
  void setViewport(
    WidgetTester tester, {
    required double width,
    required double height,
    required double textScale,
  }) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  setUp(() async {
    db = testDatabase();
    vehicleId = await addTestVehicle(db, name: 'Honda');
    await addRefuel(
      db,
      vehicleId,
      date: DateTime(2026, 8, 5),
      odometer: 1000,
      volume: 5,
      station: 'Shell Main St',
    );
    await addRefuel(
      db,
      vehicleId,
      date: DateTime(2026, 9, 1),
      odometer: 1200,
      volume: 5.4,
      price: 1234.567,
    );
    await addEntry(
      db,
      vehicleId,
      kind: EntryKind.service,
      date: DateTime(2026, 8, 20),
      odometer: 1100,
      items: {'Oil Change': 4500},
    );
    await addEntry(
      db,
      vehicleId,
      kind: EntryKind.expense,
      date: DateTime(2026, 8, 22),
      items: {'Tax': 200},
    );
    await addEntry(
      db,
      vehicleId,
      kind: EntryKind.income,
      date: DateTime(2026, 8, 23),
      items: {'Transport application': 3000},
    );
    await db
        .into(db.routes)
        .insert(
          RoutesCompanion.insert(
            vehicleId: vehicleId,
            mode: const Value(RouteMode.trip),
            startDate: DateTime(2026, 8, 24, 8),
            startOdometer: 1100,
            origin: const Value('Home'),
            destination: const Value('Work'),
            endOdometer: const Value(1112),
            valuePerDistance: const Value(15),
            total: const Value(180),
          ),
        );
    await db
        .into(db.readings)
        .insert(
          ReadingsCompanion.insert(
            vehicleId: vehicleId,
            date: DateTime(2026, 9, 2),
            odometer: 1250,
          ),
        );
    final oilTypeId = await catalogId(
      db,
      CatalogKind.serviceType,
      'Oil Change',
    );
    await db.insertReminder(
      RemindersCompanion.insert(
        vehicleId: vehicleId,
        target: ReminderTarget.service,
        typeId: oilTypeId,
        dueOdometer: const Value(2000),
      ),
    );
  });
  tearDown(() => db.close());

  Widget app() => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: const MotoLogApp(),
  );

  /// Runs [body] at [width]x[height] @ [textScale], asserting no exception
  /// surfaced during or after the pump.
  Future<void> at(
    WidgetTester tester,
    double width,
    double height,
    double textScale,
    Future<void> Function(WidgetTester tester) body,
  ) async {
    setViewport(tester, width: width, height: height, textScale: textScale);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await body(tester);
    expect(
      tester.takeException(),
      isNull,
      reason: '${width.toInt()}x${height.toInt()} @ $textScale×',
    );
    await unmountApp(tester);
  }

  /// The two combinations every screen is checked at, plus [extra] more
  /// (size, height, textScale) triples for a rotating subset.
  List<(double, double, double)> combos([
    List<(double, double, double)> extra = const [],
  ]) => [(320, 568, 2.0), (1280, 800, 1.0), ...extra];

  group('History', () {
    for (final (w, h, ts) in combos([(360, 640, 1.3), (800, 1280, 1.3)])) {
      testWidgets('history screen at ${w}x$h @ $ts', (tester) async {
        await at(tester, w, h, ts, (tester) async {
          // Already on History (the initial route); nothing to navigate.
        });
      });
    }
  });

  group('Reports', () {
    for (final (w, h, ts) in combos([(800, 1280, 1.3)])) {
      testWidgets('reports tabs at ${w}x$h @ $ts', (tester) async {
        await at(tester, w, h, ts, (tester) async {
          await tester.tap(find.text('Reports'));
          await tester.pumpAndSettle();
          for (final tab in ['REFUELING', 'EXPENSE', 'ROUTE']) {
            final finder = find.text(tab);
            await tester.ensureVisible(finder);
            await tester.pumpAndSettle();
            await tester.tap(finder);
            await tester.pumpAndSettle();
          }
        });
      });
    }
  });

  group('Reminders', () {
    for (final (w, h, ts) in combos()) {
      testWidgets('reminders screen at ${w}x$h @ $ts', (tester) async {
        await at(tester, w, h, ts, (tester) async {
          await tester.tap(find.text('Reminders'));
          await tester.pumpAndSettle();
        });
      });
    }
  });

  group('More', () {
    for (final (w, h, ts) in combos([(360, 640, 1.3)])) {
      testWidgets('more screen at ${w}x$h @ $ts', (tester) async {
        await at(tester, w, h, ts, (tester) async {
          await tester.tap(find.text('More'));
          await tester.pumpAndSettle();
        });
      });
    }
  });

  group('Settings', () {
    for (final (w, h, ts) in combos()) {
      testWidgets('settings screen at ${w}x$h @ $ts', (tester) async {
        await at(tester, w, h, ts, (tester) async {
          await tester.tap(find.text('More'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Settings'));
          await tester.pumpAndSettle();
        });
      });
    }
  });

  group('Vehicle form', () {
    for (final (w, h, ts) in combos([(800, 1280, 1.3)])) {
      testWidgets('vehicle form at ${w}x$h @ $ts', (tester) async {
        await at(tester, w, h, ts, (tester) async {
          await tester.tap(find.text('More'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Vehicles'));
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(Icons.add));
          await tester.pumpAndSettle();
        });
      });
    }
  });

  group('Places', () {
    for (final (w, h, ts) in combos()) {
      testWidgets('places list at ${w}x$h @ $ts', (tester) async {
        await at(tester, w, h, ts, (tester) async {
          await tester.tap(find.text('More'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('My places'));
          await tester.pumpAndSettle();
        });
      });
    }
  });

  group('Storage', () {
    for (final (w, h, ts) in combos()) {
      testWidgets('storage screen at ${w}x$h @ $ts', (tester) async {
        await at(tester, w, h, ts, (tester) async {
          await tester.tap(find.text('More'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Storage'));
          await tester.pumpAndSettle();
        });
      });
    }
  });

  group('Sync', () {
    for (final (w, h, ts) in combos()) {
      testWidgets('sync screen at ${w}x$h @ $ts', (tester) async {
        await at(tester, w, h, ts, (tester) async {
          await tester.tap(find.text('More'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Synchronize data'));
          await tester.pumpAndSettle();
        });
      });
    }
  });

  group('Export', () {
    for (final (w, h, ts) in combos()) {
      testWidgets('export screen at ${w}x$h @ $ts', (tester) async {
        await at(tester, w, h, ts, (tester) async {
          await tester.tap(find.byTooltip('Export'));
          await tester.pumpAndSettle();
        });
      });
    }
  });

  group('Flex calculator', () {
    for (final (w, h, ts) in combos()) {
      testWidgets('flex screen at ${w}x$h @ $ts', (tester) async {
        await at(tester, w, h, ts, (tester) async {
          await tester.tap(find.text('More'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Flex calculator'));
          await tester.pumpAndSettle();
        });
      });
    }
  });

  group('Achievements', () {
    for (final (w, h, ts) in combos()) {
      testWidgets('achievements screen at ${w}x$h @ $ts', (tester) async {
        await at(tester, w, h, ts, (tester) async {
          await tester.tap(find.text('More'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Achievements'));
          await tester.pumpAndSettle();
        });
      });
    }
  });

  group('Record forms', () {
    for (final module in [
      'Refueling',
      'Expense',
      'Service',
      'Income',
      'Route',
      'Reading',
      'Reminder',
      'Checklist',
    ]) {
      for (final (w, h, ts) in combos()) {
        testWidgets('$module form at ${w}x$h @ $ts', (tester) async {
          await at(tester, w, h, ts, (tester) async {
            await tester.tap(find.byIcon(Icons.add));
            await tester.pumpAndSettle();
            await tester.tap(
              find.descendant(
                of: find.byType(SpeedDialMenu),
                matching: find.text(module),
              ),
            );
            await tester.pumpAndSettle();
          });
        });
      }
    }
  });

  group('Select list screen', () {
    for (final (w, h, ts) in combos()) {
      testWidgets('currency picker at ${w}x$h @ $ts', (tester) async {
        await at(tester, w, h, ts, (tester) async {
          await tester.tap(find.text('More'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Settings'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Currency format'));
          await tester.pumpAndSettle();
          expect(find.byType(SelectListScreen), findsOneWidget);
        });
      });
    }
  });

  group('Record detail', () {
    for (final (w, h, ts) in combos()) {
      testWidgets('refueling record detail at ${w}x$h @ $ts', (tester) async {
        await at(tester, w, h, ts, (tester) async {
          // Tap the first (newest) timeline row to expand it, then its
          // "View details" affordance — simpler: push the route directly,
          // like the History row's onTap does, via the active router.
          final router = activeRouter;
          expect(router, isNotNull);
          final refuels = await db.select(db.refuelings).get();
          if (refuels.isNotEmpty) {
            router!.push('/record/refueling/${refuels.first.id}');
            await tester.pumpAndSettle();
          }
        });
      });
    }
  });
}
