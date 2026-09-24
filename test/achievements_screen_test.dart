import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/app.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/providers.dart';
import 'package:motolog/features/achievements/achievement_badge.dart';
import 'package:motolog/features/reports/report_providers.dart';

import 'helpers.dart';
import 'history_fixtures.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  /// "Today" pinned so `years_N` badges are deterministic.
  Widget app() => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      reportNowProvider.overrideWithValue(() => DateTime(2026, 9, 24, 12)),
    ],
    child: const MotoLogApp(),
  );

  Future<void> openAchievements(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Achievements'));
    await tester.pumpAndSettle();
  }

  testWidgets('grid shows earned vs locked badges for seeded data', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final vid = await addTestVehicle(db);
      await addRefuel(db, vid, date: DateTime(2026, 1, 5), odometer: 100);
    });

    await openAchievements(tester);

    expect(find.byType(AchievementBadge), findsNWidgets(20));

    final firstRecord = tester.widget<AchievementBadge>(
      find.byKey(const Key('badge-first_record')),
    );
    expect(firstRecord.achievement.earned, isTrue);

    final firstRefuel = tester.widget<AchievementBadge>(
      find.byKey(const Key('badge-refuels_1')),
    );
    expect(firstRefuel.achievement.earned, isTrue);

    // Only had 1 refueling, at 1 station once: none of these should be
    // earned yet.
    for (final id in ['stations_10', 'refuels_25', 'same_station_15']) {
      final badge = tester.widget<AchievementBadge>(
        find.byKey(Key('badge-$id')),
      );
      expect(badge.achievement.earned, isFalse, reason: id);
    }
    await unmountApp(tester);
  });

  testWidgets('tapping an earned badge shows its text and earned date', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final vid = await addTestVehicle(db);
      await addRefuel(db, vid, date: DateTime(2026, 1, 5), odometer: 100);
    });

    await openAchievements(tester);
    await tester.tap(find.byKey(const Key('badge-refuels_1')));
    await tester.pumpAndSettle();

    expect(find.text('First refueling.'), findsOneWidget);
    expect(find.text('2026-01-05'), findsOneWidget); // default date format
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await unmountApp(tester);
  });

  testWidgets('tapping a locked badge shows "Not achieved"', (tester) async {
    await tester.runAsync(() async {
      final vid = await addTestVehicle(db);
      await addRefuel(db, vid, date: DateTime(2026, 1, 5), odometer: 100);
    });

    await openAchievements(tester);
    await tester.tap(find.byKey(const Key('badge-stations_10')));
    await tester.pumpAndSettle();

    expect(find.text('Refueled at 10 different gas stations.'), findsOneWidget);
    expect(find.text('Not achieved'), findsOneWidget);
    await unmountApp(tester);
  });
}
