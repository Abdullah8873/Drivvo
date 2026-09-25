import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/db/seed_data.dart';
import 'package:motolog/core/sync/in_memory_remote_store.dart';
import 'package:motolog/core/sync/remote_file_store.dart';
import 'package:motolog/core/sync/sync_engine.dart';
import 'package:motolog/features/attachments/attachment_loader.dart';
import 'package:motolog/features/attachments/attachment_queries.dart';
import 'package:motolog/features/checklists/checklist_queries.dart';
import 'package:motolog/features/readings/reading_queries.dart';

import 'helpers.dart';

/// Sync of the schema-v4 tables (checklists, attachments) and the
/// attachment file step, with two devices sharing a fake cloud + bucket.
void main() {
  const u1 = 'user-1';

  late AppDatabase phone;
  late AppDatabase laptop;
  late InMemoryRemoteStore cloud;
  late InMemoryRemoteFileStore bucket;
  late SyncEngine phoneSync;
  late SyncEngine laptopSync;

  setUp(() {
    phone = testDatabase();
    laptop = testDatabase();
    cloud = InMemoryRemoteStore();
    bucket = InMemoryRemoteFileStore();
    phoneSync = SyncEngine(phone, cloud, files: bucket);
    laptopSync = SyncEngine(laptop, cloud, files: bucket);
  });
  tearDown(() async {
    await phone.close();
    await laptop.close();
  });

  PendingAttachment photo([List<int> bytes = const [1, 2, 3]]) =>
      PendingAttachment(
        fileName: 'receipt 1.jpg',
        mimeType: 'image/jpeg',
        bytes: Uint8List.fromList(bytes),
      );

  /// A reading with one attachment on [db]; returns (readingId, attachment).
  Future<(String, Attachment)> readingWithPhoto(AppDatabase db) async {
    final vid = await addTestVehicle(db);
    final rid = await db.saveReading(
      ReadingsCompanion.insert(
        vehicleId: vid,
        date: DateTime(2026, 9, 1),
        odometer: 100,
      ),
    );
    await db.applyAttachmentChanges(
      parentTable: 'readings',
      parentId: rid,
      vehicleId: vid,
      added: [photo()],
    );
    return (rid, (await db.getAttachments('readings', rid)).single);
  }

  test('checklists travel with their answers, parents first', () async {
    final vid = await addTestVehicle(phone);
    final formId = await phone.saveChecklistForm(
      name: 'Walkaround',
      items: [(id: null, label: 'Tires'), (id: null, label: 'Lights')],
    );
    final cid = await phone.saveChecklist(
      ChecklistDraft(
        vehicleId: vid,
        date: DateTime(2026, 9, 2),
        formId: formId,
        title: 'Walkaround',
        odometer: 1200,
        answers: const [
          ChecklistAnswerDraft(label: 'Tires', status: ChecklistStatus.ok),
          ChecklistAnswerDraft(
            label: 'Lights',
            status: ChecklistStatus.problem,
            note: 'Left bulb out',
          ),
        ],
      ),
    );
    // Order of the pushes: every parent table before its children.
    final pushed = <String>[];
    cloud.beforePush = (table, _) => pushed.add(table);
    await phoneSync.sync(u1);
    expect(
      pushed.indexOf('checklist_forms'),
      lessThan(pushed.indexOf('checklist_form_items')),
    );
    expect(
      pushed.indexOf('checklists'),
      lessThan(pushed.indexOf('checklist_answers')),
    );
    expect(pushed.indexOf('vehicles'), lessThan(pushed.indexOf('checklists')));

    await laptopSync.sync(u1);
    final got = await laptop.getChecklist(cid);
    expect(got!.checklist.title, 'Walkaround');
    expect(got.checklist.odometer, 1200);
    expect(got.answers.map((a) => a.status), [
      ChecklistStatus.ok,
      ChecklistStatus.problem,
    ]);
    expect(got.answers.last.note, 'Left bulb out');
    expect((await laptop.getChecklistForm(formId))!.items, hasLength(2));
    // The seeded template is not duplicated across devices.
    final preTrip = SeedData.formIdFor('Pre-trip inspection');
    expect(
      (await laptop.select(laptop.checklistForms).get()).where(
        (f) => f.id == preTrip,
      ),
      hasLength(1),
    );
  });

  test('uploads new files and stores the storage path', () async {
    final (_, a) = await readingWithPhoto(phone);
    final report = await phoneSync.sync(u1);

    final path = '$u1/${a.id}/receipt_1.jpg';
    expect(report.filesUploaded, 1);
    expect(bucket.objects[path], [1, 2, 3]);
    expect(bucket.mimeTypes[path], 'image/jpeg');
    final row = await (phone.select(
      phone.attachments,
    )..where((x) => x.id.equals(a.id))).getSingle();
    expect(row.storagePath, path);
    // The path went up in the same run.
    expect(cloud.row('attachments', u1, a.id)!['storage_path'], path);
    expect(await phoneSync.pendingCount(), 0);

    // A second run uploads nothing.
    expect((await phoneSync.sync(u1)).filesUploaded, 0);
    expect(bucket.uploads, 1);
  });

  test('another device downloads the file on demand and caches it', () async {
    final (_, a) = await readingWithPhoto(phone);
    await phoneSync.sync(u1);
    await laptopSync.sync(u1);

    final synced = await (laptop.select(
      laptop.attachments,
    )..where((x) => x.id.equals(a.id))).getSingle();
    expect(await laptop.localAttachmentBytes(a.id), isNull);

    // Signed out: a clear message, no download.
    await expectLater(
      loadAttachmentBytes(laptop, synced, files: bucket, signedIn: false),
      throwsA(isA<AttachmentUnavailable>()),
    );
    expect(bucket.downloads, 0);

    final bytes = await loadAttachmentBytes(
      laptop,
      synced,
      files: bucket,
      signedIn: true,
    );
    expect(bytes, [1, 2, 3]);
    expect(await laptop.localAttachmentBytes(a.id), [1, 2, 3]);
    // Cached: the next open reads the local copy.
    await loadAttachmentBytes(laptop, synced, files: bucket, signedIn: true);
    expect(bucket.downloads, 1);

    // Offline: a clear message.
    bucket.beforeDownload = (_) => throw Exception('offline');
    await laptop.customStatement('DELETE FROM attachment_files');
    await expectLater(
      loadAttachmentBytes(laptop, synced, files: bucket, signedIn: true),
      throwsA(
        isA<AttachmentUnavailable>().having(
          (e) => e.message,
          'message',
          contains('internet'),
        ),
      ),
    );
  });

  test('a file not uploaded yet explains where it is', () async {
    final (_, a) = await readingWithPhoto(phone);
    // Only the rows reach the cloud (e.g. the phone has no file store).
    await SyncEngine(phone, cloud).sync(u1);
    await laptopSync.sync(u1);
    final synced = await (laptop.select(
      laptop.attachments,
    )..where((x) => x.id.equals(a.id))).getSingle();
    expect(synced.storagePath, isNull);
    await expectLater(
      loadAttachmentBytes(laptop, synced, files: bucket, signedIn: true),
      throwsA(
        isA<AttachmentUnavailable>().having(
          (e) => e.message,
          'message',
          contains("hasn't been uploaded"),
        ),
      ),
    );
  });

  test('deleting removes the stored object (best effort)', () async {
    final (rid, a) = await readingWithPhoto(phone);
    await phoneSync.sync(u1);
    final path = '$u1/${a.id}/receipt_1.jpg';
    expect(bucket.objects, contains(path));

    await phone.deleteReading(rid);
    // A failing remove never fails the sync; it retries next time.
    bucket.beforeRemove = (_) => throw Exception('offline');
    await phoneSync.sync(u1);
    expect(bucket.objects, contains(path));

    bucket.beforeRemove = null;
    final report = await phoneSync.sync(u1);
    expect(report.filesRemoved, 1);
    expect(bucket.objects, isNot(contains(path)));
    final row = await (phone.select(
      phone.attachments,
    )..where((x) => x.id.equals(a.id))).getSingle();
    expect(row.deletedAt, isNotNull);
    expect(row.storagePath, isNull);
    // The other device learns about the deletion.
    await laptopSync.sync(u1);
    expect(await laptop.getAttachments('readings', rid), isEmpty);
  });

  test('a failed upload does not fail the sync and is retried', () async {
    final (_, a) = await readingWithPhoto(phone);
    bucket.beforeUpload = (_) => throw Exception('timeout');
    final report = await phoneSync.sync(u1);
    expect(report.fileUploadFailures, 1);
    expect(cloud.row('attachments', u1, a.id), isNotNull);
    expect(cloud.row('attachments', u1, a.id)!['storage_path'], isNull);

    bucket.beforeUpload = null;
    expect((await phoneSync.sync(u1)).filesUploaded, 1);
  });

  test('without a file store attachments stay local-only', () async {
    final (_, a) = await readingWithPhoto(phone);
    await SyncEngine(phone, cloud).sync(u1);
    expect(bucket.objects, isEmpty);
    expect(await phone.localAttachmentBytes(a.id), [1, 2, 3]);
  });

  test('replacing local data also drops local file bytes', () async {
    await readingWithPhoto(phone);
    await phoneSync.sync(u1);
    await phoneSync.adoptAccount('user-2', keepLocalData: false);
    expect(await phone.select(phone.attachmentFiles).get(), isEmpty);
    expect(await phone.select(phone.attachments).get(), isEmpty);
  });
}
