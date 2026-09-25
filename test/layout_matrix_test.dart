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

  /// `pumpAndSettle()` with a 10s cap instead of its 10-minute default — a
  /// perpetually-loading spinner should fail this file fast, not burn ten
  /// real minutes per combination before reporting anything.
  Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 10),
  );

  /// `testWidgets` with a hard 25s per-test timeout — belt and suspenders
  /// alongside [settle]'s bound, in case something hangs outside a
  /// `pumpAndSettle` call (e.g. a real `setUp`/`tearDown` await).
  void testLayout(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) => testWidgets(
    description,
    body,
    timeout: const Timeout(Duration(seconds: 25)),
  );

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
    await settle(tester);
    // try/finally: always unmount, even when `body` throws (e.g. a finder
    // that can't find its target) — otherwise the drift-backed widget tree
    // stays live into the next test, which reliably wedges it (the next
    // test's own navigation then fails too, cascading failures through the
    // rest of the file instead of isolating the one real bug).
    Object? failure;
    try {
      await body(tester);
      failure = tester.takeException();
    } catch (e) {
      failure = e;
    } finally {
      await unmountApp(tester);
    }
    expect(
      failure,
      isNull,
      reason: '${width.toInt()}x${height.toInt()} @ $textScale×',
    );
  }

  /// Taps the "More" tab, then taps the menu row labelled [label] — scrolling
  /// it into view first if needed. `more_screen.dart`'s list is long enough
  /// that rows past the first few sections (Settings, My places, Flex
  /// calculator, Achievements, …) sit outside the initial viewport + the
  /// `Scrollable`'s default cache extent, so they aren't mounted yet and a
  /// plain `find.text(label)` finds nothing — same fix as the speed-dial
  /// "Reminder" scroll in narrow_ui_test.dart.
  Future<void> openFromMore(WidgetTester tester, String label) async {
    await tester.tap(find.text('More'));
    await settle(tester);
    final finder = find.text(label);
    if (finder.evaluate().isEmpty) {
      await tester.dragUntilVisible(
        finder,
        find.byType(Scrollable).first,
        const Offset(0, -300),
      );
      await settle(tester);
    }
    await tester.tap(finder);
    await settle(tester);
  }

  /// The two combinations every screen is checked at, plus [extra] more
  /// (size, height, textScale) triples for a rotating subset.
  List<(double, double, double)> combos([
    List<(double, double, double)> extra = const [],
  ]) => [(320, 568, 2.0), (1280, 800, 1.0), ...extra];

  group('History', () {
    for (final (w, h, ts) in combos([(360, 640, 1.3), (800, 1280, 1.3)])) {
      testLayout('history screen at ${w}x$h @ $ts', (tester) async {
        await at(tester, w, h, ts, (tester) async {
          // Already on History (the initial route); nothing to navigate.
        });
      });
    }
  });

  group('Reports', () {
    for (final (w, h, ts) in combos([(800, 1280, 1.3)])) {
      testLayout('reports tabs at ${w}x$h @ $ts', (tester) async {
        await at(tester, w, h, ts, (tester) async {
          await tester.tap(find.text('Reports'));
          await settle(tester);
          for (final tab in ['REFUELING', 'EXPENSE', 'ROUTE']) {
            final finder = find.text(tab);
            await tester.ensureVisible(finder);
            await settle(tester);
            await tester.tap(finder);
            await settle(tester);
          }
        });
      });
    }
  });

  group('Reminders', () {
    for (final (w, h, ts) in combos()) {
      testLayout('reminders screen at ${w}x$h @ $ts', (tester) async {
        await at(tester, w, h, ts, (tester) async {
          await tester.tap(find.text('Reminders'));
          await settle(tester);
        });
      });
    }
  });

  group('More', () {
    for (final (w, h, ts) in combos([(360, 640, 1.3)])) {
      testLayout('more screen at ${w}x$h @ $ts', (tester) async {
        await at(tester, w, h, ts, (tester) async {
          await tester.tap(find.text('More'));
          await settle(tester);
        });
      });
    }
  });

  group('Settings', () {
    for (final (w, h, ts) in combos()) {
      testLayout('settings screen at ${w}x$h @ $ts', (tester) async {
        await at(tester, w, h, ts, (tester) async {
          await openFromMore(tester, 'Settings');
        });
      });
    }
  });

  group('Vehicle form', () {
    for (final (w, h, ts) in combos([(800, 1280, 1.3)])) {
      testLayout('vehicle form at ${w}x$h @ $ts', (tester) async {
        await at(tester, w, h, ts, (tester) async {
          await openFromMore(tester, 'Vehicles');
          await tester.tap(find.byIcon(Icons.add));
          await settle(tester);
        });
      });
    }
  });

  group('Places', () {
    for (final (w, h, ts) in combos()) {
      testLayout('places list at ${w}x$h @ $ts', (tester) async {
        await at(tester, w, h, ts, (tester) async {
          await openFromMore(tester, 'My places');
        });
      });
    }
  });

  group('Storage', () {
    for (final (w, h, ts) in combos()) {
      testLayout('storage screen at ${w}x$h @ $ts', (tester) async {
        await at(tester, w, h, ts, (tester) async {
          await openFromMore(tester, 'Storage');
        });
      });
    }
  });

  group('Sync', () {
    for (final (w, h, ts) in combos()) {
      testLayout('sync screen at ${w}x$h @ $ts', (tester) async {
        await at(tester, w, h, ts, (tester) async {
          await openFromMore(tester, 'Synchronize data');
        });
      });
    }
  });

  group('Export', () {
    for (final (w, h, ts) in combos()) {
      testLayout('export screen at ${w}x$h @ $ts', (tester) async {
        await at(tester, w, h, ts, (tester) async {
          await tester.tap(find.byTooltip('Export'));
          await settle(tester);
        });
      });
    }
  });

  group('Flex calculator', () {
    for (final (w, h, ts) in combos()) {
      testLayout('flex screen at ${w}x$h @ $ts', (tester) async {
        await at(tester, w, h, ts, (tester) async {
          await openFromMore(tester, 'Flex calculator');
        });
      });
    }
  });

  group('Achievements', () {
    for (final (w, h, ts) in combos()) {
      testLayout('achievements screen at ${w}x$h @ $ts', (tester) async {
        await at(tester, w, h, ts, (tester) async {
          await openFromMore(tester, 'Achievements');
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
        testLayout('$module form at ${w}x$h @ $ts', (tester) async {
          await at(tester, w, h, ts, (tester) async {
            await tester.tap(find.byIcon(Icons.add));
            await settle(tester);
            await tester.tap(
              find.descendant(
                of: find.byType(SpeedDialMenu),
                matching: find.text(module),
              ),
            );
            await settle(tester);
          });
        });
      }
    }
  });

  group('Select list screen', () {
    for (final (w, h, ts) in combos()) {
      testLayout('currency picker at ${w}x$h @ $ts', (tester) async {
        await at(tester, w, h, ts, (tester) async {
          await openFromMore(tester, 'Settings');
          // "Currency format" is a few rows down Settings' own list — at a
          // short screen + large text it can be built but scrolled out of
          // the hit-testable viewport, same as the More-list rows above.
          final finder = find.text('Currency format');
          await tester.ensureVisible(finder);
          await settle(tester);
          await tester.tap(finder);
          await settle(tester);
          expect(find.byType(SelectListScreen), findsOneWidget);
        });
      });
    }
  });

  group('Record detail', () {
    for (final (w, h, ts) in combos()) {
      testLayout('refueling record detail at ${w}x$h @ $ts', (tester) async {
        await at(tester, w, h, ts, (tester) async {
          // Tap the first (newest) timeline row to expand it, then its
          // "View details" affordance — simpler: push the route directly,
          // like the History row's onTap does, via the active router.
          final router = activeRouter;
          expect(router, isNotNull);
          final refuels = await db.select(db.refuelings).get();
          if (refuels.isNotEmpty) {
            router!.push('/record/refueling/${refuels.first.id}');
            await settle(tester);
          }
        });
      });
    }
  });
}
