import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/app.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/files/file_sharer.dart';
import 'package:motolog/core/providers.dart';

import 'helpers.dart';

/// Records every share instead of touching a real share sheet/file system —
/// the interface `FileSharer` exists specifically so tests can swap this in.
class FakeFileSharer implements FileSharer {
  int callCount = 0;
  String? filename;
  Uint8List? bytes;
  String? mimeType;

  @override
  Future<void> shareBytes({
    required String filename,
    required Uint8List bytes,
    required String mimeType,
    String? subject,
  }) async {
    callCount++;
    this.filename = filename;
    this.bytes = bytes;
    this.mimeType = mimeType;
  }
}

Widget appWithFakeSharer(AppDatabase db, FakeFileSharer sharer) =>
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        fileSharerProvider.overrideWithValue(sharer),
      ],
      child: const MotoLogApp(),
    );

void main() {
  late AppDatabase db;
  late FakeFileSharer sharer;

  setUp(() {
    db = testDatabase();
    sharer = FakeFileSharer();
  });

  tearDown(() => db.close());

  Future<void> openExportScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(appWithFakeSharer(db, sharer));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Export'));
    await tester.pumpAndSettle();
  }

  testWidgets('defaults: current vehicle, all time, every type, CSV', (
    tester,
  ) async {
    await addTestVehicle(db, name: 'Honda');
    await openExportScreen(tester);

    expect(find.text('Export'), findsOneWidget); // app bar title
    expect(find.text('Honda'), findsOneWidget); // current vehicle option
    expect(find.text('All vehicles'), findsOneWidget);
    expect(find.text('All time'), findsOneWidget);
    // The custom-range tile still reads "Custom range" (no dates picked),
    // proving "All time" (period == null) is what's actually selected.
    expect(find.text('Custom range'), findsOneWidget);

    for (final label in [
      'Refueling',
      'Expense',
      'Service',
      'Income',
      'Route',
      'Reading',
      'Reminder',
    ]) {
      final checkbox = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, label),
      );
      expect(checkbox.value, isTrue, reason: label);
    }

    for (final format in ['CSV', 'Excel', 'PDF']) {
      expect(find.text(format), findsOneWidget);
    }

    await unmountApp(tester);
  });

  testWidgets('EXPORT calls the file sharer exactly once', (tester) async {
    await addTestVehicle(db, name: 'Honda');
    await openExportScreen(tester);

    await tester.tap(find.text('EXPORT'));
    await tester.pump(); // loading state
    await tester.pumpAndSettle();

    expect(sharer.callCount, 1);
    // All 7 record types are ticked by default with CSV chosen, so the
    // result is a zip bundling one CSV per type (see ExportService).
    expect(sharer.filename, matches(RegExp(r'^motolog-honda-\d{8}\.zip$')));
    expect(sharer.mimeType, 'application/zip');
    expect(sharer.bytes, isNotNull);
    expect(sharer.bytes!.isNotEmpty, isTrue);

    await unmountApp(tester);
  });

  testWidgets('unticking every record type disables EXPORT', (tester) async {
    await addTestVehicle(db, name: 'Honda');
    await openExportScreen(tester);

    for (final label in [
      'Refueling',
      'Expense',
      'Service',
      'Income',
      'Route',
      'Reading',
      'Reminder',
    ]) {
      await tester.tap(find.widgetWithText(CheckboxListTile, label));
      await tester.pump();
    }

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await unmountApp(tester);
  });
}
