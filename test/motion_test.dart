import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/theme/app_theme.dart';
import 'package:motolog/core/widgets/motion.dart';
import 'package:motolog/core/widgets/speed_dial_menu.dart';
import 'package:motolog/features/attachments/storage_screen.dart';

import 'helpers.dart';

/// Opacity of the speed dial menu (1 = fully shown).
double _menuOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find
          .ancestor(
            of: find.byType(SpeedDialMenu),
            matching: find.byType(Opacity),
          )
          .first,
    )
    .opacity;

void main() {
  late AppDatabase db;
  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(db));
    await tester.pumpAndSettle();
  }

  void reduceMotion(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  testWidgets('speed dial grows in, then closes and unmounts', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(_menuOpacity(tester), inExclusiveRange(0, 1));

    await tester.pumpAndSettle();
    expect(_menuOpacity(tester), 1);
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byType(SpeedDialMenu), findsOneWidget); // animating out
    await tester.pumpAndSettle();
    expect(find.byType(SpeedDialMenu), findsNothing);
    expect(find.byIcon(Icons.add), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('with reduced motion the speed dial opens at once', (
    tester,
  ) async {
    reduceMotion(tester);
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.pump();
    expect(_menuOpacity(tester), 1);
    await unmountApp(tester);
  });

  testWidgets('switching main tabs fades the page in', (tester) async {
    await pumpApp(tester);
    FadeTransition shellFade() => tester.widget<FadeTransition>(
      find
          .ancestor(
            of: find.byType(StatefulNavigationShell),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    await tester.tap(find.text('Reports'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(shellFade().opacity.value, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(shellFade().opacity.value, 1);
    await unmountApp(tester);
  });

  testWidgets('pushed screens slide in on Android and web', (tester) async {
    expect(
      AppTheme.light().pageTransitionsTheme.builders[TargetPlatform.android],
      isA<SlideFadePageTransitionsBuilder>(),
    );
    await pumpApp(tester);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Storage'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final slide = tester.widget<SlideTransition>(
      find
          .ancestor(
            of: find.byType(StorageScreen),
            matching: find.byType(SlideTransition),
          )
          .first,
    );
    expect(slide.position.value.dx, greaterThan(0)); // still sliding in
    await tester.pumpAndSettle();
    expect(slide.position.value.dx, 0);
    await unmountApp(tester);
  });

  testWidgets('with reduced motion screens appear without sliding', (
    tester,
  ) async {
    reduceMotion(tester);
    await pumpApp(tester);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Storage'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.ancestor(
        of: find.byType(StorageScreen),
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
    );
    await tester.pumpAndSettle();
    await unmountApp(tester);
  });

  group('FadeSlideIn', () {
    Widget host({int index = 0}) => MaterialApp(
      home: FadeSlideIn(index: index, child: const Text('card')),
    );

    double opacity(WidgetTester tester) => tester
        .widget<Opacity>(
          find.ancestor(of: find.text('card'), matching: find.byType(Opacity)),
        )
        .opacity;

    testWidgets('eases in once and is not replayed on rebuild', (tester) async {
      await tester.pumpWidget(host());
      expect(opacity(tester), 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacity(tester), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(opacity(tester), 1);

      await tester.pumpWidget(host()); // e.g. new report data
      expect(opacity(tester), 1);
    });

    testWidgets('later items start later', (tester) async {
      await tester.pumpWidget(host(index: 3));
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacity(tester), 0); // still waiting its turn
      await tester.pumpAndSettle();
      expect(opacity(tester), 1);
    });

    testWidgets('reduced motion shows the child as is', (tester) async {
      reduceMotion(tester);
      await tester.pumpWidget(host());
      expect(
        find.ancestor(of: find.text('card'), matching: find.byType(Opacity)),
        findsNothing,
      );
    });
  });
}
