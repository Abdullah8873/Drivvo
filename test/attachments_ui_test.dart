import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:motolog/app.dart';
import 'package:motolog/core/cloud/auth_state.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/files/file_sharer.dart';
import 'package:motolog/core/providers.dart';
import 'package:motolog/core/sync/remote_file_store.dart';
import 'package:motolog/features/attachments/attachment_picker.dart';
import 'package:motolog/features/attachments/attachment_queries.dart';

import 'route_reading_test_utils.dart';
import 'helpers.dart';

/// Picker that hands back canned files instead of opening system dialogs.
class FakePicker implements AttachmentPicker {
  PendingAttachment? next;

  @override
  bool get canTakePhoto => false;

  @override
  Future<PendingAttachment?> takePhoto() async => next;

  @override
  Future<PendingAttachment?> pickImage() async => next;

  @override
  Future<PendingAttachment?> pickPdf() async => next;
}

class FakeSharer implements FileSharer {
  final shared = <String>[];

  @override
  Future<void> shareBytes({
    required String filename,
    required Uint8List bytes,
    required String mimeType,
    String? subject,
  }) async => shared.add(filename);

  @override
  Future<void> shareText(String text, {String? subject}) async =>
      shared.add(text);
}

void main() {
  late AppDatabase db;
  late FakePicker picker;
  late FakeSharer sharer;
  setUp(() {
    db = testDatabase();
    picker = FakePicker();
    sharer = FakeSharer();
  });
  tearDown(() => db.close());

  Widget app({String? userId}) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      attachmentPickerProvider.overrideWithValue(picker),
      fileSharerProvider.overrideWithValue(sharer),
      authUserIdProvider.overrideWith((ref) => Stream.value(userId)),
    ],
    child: const MotoLogApp(),
  );

  PendingAttachment pdf(String name, int size) => PendingAttachment(
    fileName: name,
    mimeType: 'application/pdf',
    bytes: Uint8List(size),
  );

  Future<void> attach(WidgetTester tester, PendingAttachment file) async {
    picker.next = file;
    await tester.tap(find.byKey(const Key('attach-file')));
    await tester.pumpAndSettle();
    expect(find.text('Take photo'), findsNothing); // not offered here
    expect(find.text('Choose image'), findsOneWidget);
    await tester.tap(find.text('Choose file (PDF)'));
    await tester.pumpAndSettle();
  }

  testWidgets('attach, save, view, and remove on the reading form', (
    tester,
  ) async {
    useTallScreen(tester);
    await seedVehicle(tester, db);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await openForm(tester, 'Reading');

    // Too big: rejected with a message.
    await attach(tester, pdf('huge.pdf', RemoteFileStore.maxBytes + 1));
    expect(
      find.text("Files larger than 10 MB can't be attached."),
      findsOneWidget,
    );
    expect(find.text('huge.pdf'), findsNothing);

    await attach(tester, pdf('bill.pdf', 2048));
    expect(find.text('bill.pdf'), findsOneWidget);
    expect(find.text('2 KB'), findsOneWidget);

    // An attachment alone counts as an unsaved change.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('KEEP EDITING'));
    await tester.pumpAndSettle();

    // Viewer: PDFs get a share/open button.
    await tester.tap(find.text('bill.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SHARE / OPEN'));
    await tester.pumpAndSettle();
    expect(sharer.shared, ['bill.pdf']);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.enterText(field('Odometer'), '1234');
    await save(tester);

    final reading = (await tester.runAsync(
      () => db.select(db.readings).getSingle(),
    ))!;
    final saved = (await tester.runAsync(
      () => db.getAttachments('readings', reading.id),
    ))!;
    expect(saved.single.fileName, 'bill.pdf');
    expect(saved.single.sizeBytes, 2048);
    expect(saved.single.vehicleId, reading.vehicleId);
    final bytes = (await tester.runAsync(
      () => db.localAttachmentBytes(saved.single.id),
    ))!;
    expect(bytes, hasLength(2048));

    // History shows a paperclip on the row.
    expect(find.byKey(Key('clip-${reading.id}')), findsOneWidget);

    // Edit: the saved file is listed; ✕ + SAVE removes it.
    GoRouter.of(tester.element(find.text('History')))
        .push('/edit/reading/${reading.id}');
    await tester.pumpAndSettle();
    expect(find.text('bill.pdf'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('bill.pdf'), findsNothing);
    await save(tester);
    expect(
      (await tester.runAsync(() => db.getAttachments('readings', reading.id)))!,
      isEmpty,
    );
    expect(
      (await tester.runAsync(() => db.select(db.attachmentFiles).get()))!,
      isEmpty,
    );
    expect(find.byKey(Key('clip-${reading.id}')), findsNothing);
    await finish(tester);
  });

  testWidgets('backing out discards picked files', (tester) async {
    useTallScreen(tester);
    await seedVehicle(tester, db);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await openForm(tester, 'Reading');
    await attach(tester, pdf('bill.pdf', 10));
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DISCARD'));
    await tester.pumpAndSettle();
    expect(
      (await tester.runAsync(() => db.select(db.attachments).get()))!,
      isEmpty,
    );
    await finish(tester);
  });

  testWidgets('storage screen totals usage per module', (tester) async {
    useTallScreen(tester);
    await tester.runAsync(() async {
      final vid = await addTestVehicle(db);
      await db.applyAttachmentChanges(
        parentTable: 'readings',
        parentId: 'r1',
        vehicleId: vid,
        added: [pdf('a.pdf', 1024), pdf('b.pdf', 1024)],
      );
      await db.applyAttachmentChanges(
        parentTable: 'refuelings',
        parentId: 'f1',
        vehicleId: vid,
        added: [pdf('c.pdf', 2048)],
      );
    });
    await tester.pumpWidget(app(userId: 'u1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Storage'));
    await tester.pumpAndSettle();

    expect(find.text('3 files'), findsOneWidget);
    expect(find.text('4 KB'), findsOneWidget);
    expect(find.text('2 · 2 KB'), findsOneWidget); // reading
    expect(find.text('1 · 2 KB'), findsOneWidget); // refueling
    expect(find.text('0 · 0 B'), findsNWidgets(5));
    expect(find.text('3 files not uploaded yet'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('storage screen hides the upload line when signed out', (
    tester,
  ) async {
    useTallScreen(tester);
    await tester.runAsync(
      () => db.applyAttachmentChanges(
        parentTable: 'readings',
        parentId: 'r1',
        vehicleId: null,
        added: [pdf('a.pdf', 10)],
      ),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Storage'));
    await tester.pumpAndSettle();
    expect(find.text('1 file'), findsOneWidget);
    expect(find.textContaining('not uploaded'), findsNothing);
    await finish(tester);
  });
}
