import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/app.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/providers.dart';
import 'package:motolog/features/reports/report_providers.dart';
import 'package:motolog/features/reports/widgets/chart_style.dart';
import 'package:motolog/features/reports/widgets/line_chart_card.dart';
import 'package:motolog/features/reports/widgets/stat_card.dart';

import 'helpers.dart';
import 'history_fixtures.dart';

/// Narrow-phone layout checks for the report widgets (Drivvo keeps a 2×2
/// stat grid on phones) and the axis-label formatting.
void main() {
  void useNarrowScreen(WidgetTester tester, {double height = 800}) {
    tester.view.physicalSize = Size(320, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  StatCard card(String key) => StatCard(
    key: Key(key),
    title: 'Fuel efficiency',
    icon: Icons.speed,
    color: Colors.orange,
    valueLabel: 'General average',
    value: 'PKR1,234,567.89',
    subValues: const [
      (label: 'By day', value: 'PKR12,345.67'),
      (label: 'By km', value: 'PKR123.456/km'),
    ],
    lower: 'PKR300.000/L',
    higher: 'PKR5,000.000/L',
  );

  group('StatGrid', () {
    testWidgets('stays 2 columns on a 320px phone', (tester) async {
      useNarrowScreen(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                StatGrid(
                  children: [card('a'), card('b'), card('c'), card('d')],
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      final a = tester.getTopLeft(find.byKey(const Key('a')));
      final b = tester.getTopLeft(find.byKey(const Key('b')));
      final c = tester.getTopLeft(find.byKey(const Key('c')));
      final d = tester.getTopLeft(find.byKey(const Key('d')));
      // 2×2: a b / c d.
      expect(b.dy, a.dy);
      expect(b.dx, greaterThan(a.dx));
      expect(c.dx, a.dx);
      expect(c.dy, greaterThan(a.dy));
      expect(d.dy, c.dy);
      expect(tester.getSize(find.byKey(const Key('a'))).width, lessThan(150));
    });
  });

  testWidgets('ChartLegend ellipsizes long names instead of overflowing', (
    tester,
  ) async {
    useNarrowScreen(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: ChartLegend(
              items: [
                (
                  label: 'A very long gas station name that never ends at all',
                  color: Colors.teal,
                ),
                (label: 'Short', color: Colors.orange),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(
      find.textContaining('A very long gas station'),
    );
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('LineChartCard shows a repeated x label only once', (
    tester,
  ) async {
    useNarrowScreen(tester);
    // Two points on the same "day": both inner ticks format to "day 100".
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LineChartCard(
            points: const [
              LinePoint(x: 100.1, y: 280),
              LinePoint(x: 100.2, y: 290),
            ],
            color: Colors.orange,
            formatX: (x) => 'day ${x.floor()}',
            formatY: (y) => '$y',
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('day 100'), findsOneWidget);
  });

  group('ChartStyle.compact', () {
    test('picks decimals from the axis step so labels never repeat', () {
      final labels = [
        for (final v in [280.5, 281.0, 281.5, 282.0])
          ChartStyle.compact(v, step: 0.5),
      ];
      expect(labels, ['280.5', '281.0', '281.5', '282.0']);
      expect(labels.toSet().length, labels.length);
    });

    test('quarter steps keep two decimals', () {
      final labels = [
        for (final v in [10.0, 10.25, 10.5, 10.75])
          ChartStyle.compact(v, step: 0.25),
      ];
      expect(labels.toSet().length, 4);
      expect(labels[1], '10.25');
    });

    test('large values still use K / M, with enough decimals', () {
      expect(ChartStyle.compact(1500, step: 500), '1.5K');
      expect(ChartStyle.compact(2000, step: 500), '2.0K');
      expect(ChartStyle.compact(20000, step: 5000), '20K');
      expect(ChartStyle.compact(2500000, step: 500000), '2.5M');
      expect(ChartStyle.compact(0, step: 500), '0');
      // Tiny steps on big numbers skip the suffix rather than lose digits.
      expect(
        {
          for (final v in [1000.0, 1000.5, 1001.0])
            ChartStyle.compact(v, step: 0.5),
        }.length,
        3,
      );
    });

    test('without a step it falls back to the plain compact format', () {
      expect(ChartStyle.compact(1200), '1.2K');
    });
  });

  group('Reports on a 320px phone', () {
    late AppDatabase db;
    setUp(() => db = testDatabase());
    tearDown(() => db.close());

    testWidgets('every tab lays out without overflow', (tester) async {
      useNarrowScreen(tester, height: 6000);
      await tester.runAsync(() async {
        final vid = await addTestVehicle(db);
        await addRefuel(
          db,
          vid,
          date: DateTime(2026, 8, 5),
          odometer: 1000,
          volume: 5,
        );
        await addRefuel(
          db,
          vid,
          date: DateTime(2026, 8, 20),
          odometer: 1100,
          volume: 5.5,
          price: 1234.567,
        );
        await addRefuel(
          db,
          vid,
          date: DateTime(2026, 9, 5),
          odometer: 1212,
          volume: 4.2,
          price: 987.654,
        );
        await addEntry(
          db,
          vid,
          kind: EntryKind.service,
          date: DateTime(2026, 8, 25),
          odometer: 1150,
          items: {'Air Conditioning': 123456, 'Brake Fluid': 300},
        );
        await addEntry(
          db,
          vid,
          kind: EntryKind.expense,
          date: DateTime(2026, 8, 26),
          items: {'Registration': 50000},
        );
        await addEntry(
          db,
          vid,
          kind: EntryKind.income,
          date: DateTime(2026, 9, 1),
          items: {'Transport application': 70000},
        );
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            reportNowProvider.overrideWithValue(
              () => DateTime(2026, 10, 15, 12),
            ),
          ],
          child: const MotoLogApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (final tab in ['REFUELING', 'EXPENSE', 'INCOME', 'SERVICE']) {
        final finder = find.text(tab);
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$tab tab');
      }
      await unmountApp(tester);
    });
  });
}
