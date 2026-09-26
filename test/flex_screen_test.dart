import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/features/flex/flex_screen.dart';

import 'helpers.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  Future<void> openFlexCalculator(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flex calculator'));
    await tester.pumpAndSettle();
    expect(find.byType(FlexCalculatorScreen), findsOneWidget);
  }

  Future<void> enterPrices(
    WidgetTester tester, {
    required String gas,
    required String ethanol,
  }) async {
    await tester.enterText(find.byKey(const Key('flexGasPrice')), gas);
    await tester.enterText(find.byKey(const Key('flexEthanolPrice')), ethanol);
  }

  testWidgets('ethanol case: 280 gas / 190 ethanol -> recommend ethanol', (
    tester,
  ) async {
    await openFlexCalculator(tester);
    await enterPrices(tester, gas: '280', ethanol: '190');
    await tester.tap(find.byKey(const Key('flexCalculateButton')));
    await tester.pumpAndSettle();

    expect(find.text('We recommend using ethanol'), findsOneWidget);
    expect(find.text('67.9 %'), findsOneWidget);
    expect(find.text('100.0 %'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('gasoline case: ethanol too expensive -> recommend gasoline', (
    tester,
  ) async {
    await openFlexCalculator(tester);
    await enterPrices(tester, gas: '280', ethanol: '220');
    await tester.tap(find.byKey(const Key('flexCalculateButton')));
    await tester.pumpAndSettle();

    expect(find.text('We recommend using gasoline'), findsOneWidget);
    expect(find.text('78.6 %'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('validation: empty prices show inline errors, no result', (
    tester,
  ) async {
    await openFlexCalculator(tester);
    await tester.tap(find.byKey(const Key('flexCalculateButton')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a price'), findsNWidgets(2));
    expect(find.text('We recommend using ethanol'), findsNothing);
    expect(find.text('We recommend using gasoline'), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('validation: zero/negative price is rejected', (tester) async {
    await openFlexCalculator(tester);
    await enterPrices(tester, gas: '0', ethanol: '-5');
    await tester.tap(find.byKey(const Key('flexCalculateButton')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a price'), findsNWidgets(2));
    await unmountApp(tester);
  });

  testWidgets('the numeric field syncs the slider (default 70%)', (
    tester,
  ) async {
    await openFlexCalculator(tester);
    expect(
      tester.widget<Slider>(find.byKey(const Key('flexAutonomySlider'))).value,
      70,
    );

    await tester.enterText(find.byKey(const Key('flexAutonomyField')), '85');
    await tester.pump();

    expect(
      tester.widget<Slider>(find.byKey(const Key('flexAutonomySlider'))).value,
      85,
    );
    await unmountApp(tester);
  });

  testWidgets('dragging the slider updates the numeric field', (tester) async {
    await openFlexCalculator(tester);
    final before = tester
        .widget<TextField>(find.byKey(const Key('flexAutonomyField')))
        .controller!
        .text;
    expect(before, '70');

    await tester.drag(
      find.byKey(const Key('flexAutonomySlider')),
      const Offset(200, 0),
    );
    await tester.pump();

    final after = tester
        .widget<TextField>(find.byKey(const Key('flexAutonomyField')))
        .controller!
        .text;
    // Dragging right increases the value away from the default 70.
    expect(after, isNot('70'));
    expect(int.parse(after), greaterThan(70));
    await unmountApp(tester);
  });
}
