import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:motolog/core/db/app_database.dart';

import 'helpers.dart';
import 'history_fixtures.dart';

/// Widget tests for the small "extras" screens: About, Translation, Share
/// app and the Reports share sheet. Contact isn't covered here beyond what
/// Share app already exercises (both go through `FileSharer.shareText`) —
/// its bottom sheet is trivial `ListTile`s with no state of its own.
void main() {
  late AppDatabase db;
  late FakeFileSharer sharer;

  setUp(() {
    db = testDatabase();
    sharer = FakeFileSharer();
    PackageInfo.setMockInitialValues(
      appName: 'MotoLog',
      packageName: 'com.motolog.app',
      version: '1.2.3',
      buildNumber: '45',
      buildSignature: '',
    );
  });

  tearDown(() => db.close());

  Future<void> openMore(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(appWithFakeSharer(db, sharer));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
  }

  testWidgets('About shows the app name and version', (tester) async {
    await openMore(tester);
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();

    expect(find.text('About'), findsWidgets); // app bar + list item behind
    expect(find.text('MotoLog'), findsOneWidget);
    expect(find.text('Version 1.2.3 (45)'), findsOneWidget);
    expect(find.text('Open-source licenses'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('Translation shows English as the only option', (
    tester,
  ) async {
    await openMore(tester);
    await tester.tap(find.text('Translation'));
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsOneWidget); // app bar title
    expect(find.text('English'), findsOneWidget);
    expect(find.text('More languages are coming.'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('Share app shares the pitch text', (tester) async {
    await openMore(tester);
    await tester.tap(find.text('Share app'));
    await tester.pumpAndSettle();

    expect(sharer.textCallCount, 1);
    expect(
      sharer.sharedText,
      contains(
        'MotoLog — track fuel, expenses, services and reminders for your '
        'vehicles.',
      ),
    );

    await unmountApp(tester);
  });

  group('Reports share', () {
    Future<void> openReports(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final vid = await addTestVehicle(db);
      await addRefuel(
        db,
        vid,
        date: DateTime(2026, 8, 10, 9),
        odometer: 1000,
        volume: 5,
      );
      await tester.pumpWidget(appWithFakeSharer(db, sharer));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();
    }

    testWidgets('sheet offers image and PDF', (tester) async {
      await openReports(tester);
      await tester.tap(find.byTooltip('Share'));
      await tester.pumpAndSettle();

      expect(find.text('Share as image'), findsOneWidget);
      expect(find.text('Share as PDF'), findsOneWidget);

      await unmountApp(tester);
    });

    testWidgets('Share as image calls the file sharer with a .png name', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await openReports(tester);
        await tester.tap(find.byTooltip('Share'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Share as image'));
        await tester.pumpAndSettle();
      });

      expect(sharer.callCount, 1);
      expect(sharer.filename, matches(RegExp(r'^motolog-report-general-\d{4}-\d{2}-\d{2}\.png$')));
      expect(sharer.mimeType, 'image/png');
      expect(sharer.bytes, isNotNull);
      expect(sharer.bytes!.isNotEmpty, isTrue);

      await unmountApp(tester);
    });
  });
}
