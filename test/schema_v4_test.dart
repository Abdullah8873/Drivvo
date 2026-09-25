import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/db/seed_data.dart';
import 'package:motolog/features/attachments/attachment_queries.dart';
import 'package:motolog/features/checklists/checklist_queries.dart';
import 'package:motolog/features/readings/reading_queries.dart';

import 'helpers.dart';

/// Schema v4: attachments + checklists tables, their triggers, the seeded
/// "Pre-trip inspection" template and the v3 -> v4 migration.
void main() {
  final preTrip = SeedData.formIdFor('Pre-trip inspection');

  Future<List<String>> queued(AppDatabase db) async => [
    for (final r
        in await db
            .customSelect(
              'SELECT target_table, row_id FROM sync_outbox ORDER BY seq',
            )
            .get())
      '${r.read<String>('target_table')}:${r.read<String>('row_id')}',
  ];

  group('fresh database', () {
    late AppDatabase db;
    setUp(() => db = testDatabase());
    tearDown(() => db.close());

    test('seeds the default checklist template once', () async {
      final form = await db.getChecklistForm(preTrip);
      expect(form, isNotNull);
      expect(form!.form.name, 'Pre-trip inspection');
      expect(form.items.map((i) => i.label), [
        'Tires',
        'Lights',
        'Brakes',
        'Engine oil level',
        'Coolant level',
        'Windshield & wipers',
        'Horn',
        'Mirrors',
        'Documents',
      ]);
      expect(
        form.form.updatedAt.isAtSameMomentAs(AppDatabase.seedTimestamp),
        isTrue,
      );
      // Idempotent, and a deleted default is never resurrected.
      await db.deleteChecklistForm(preTrip);
      await db.seedCatalogs();
      final forms = await db.select(db.checklistForms).get();
      expect(forms, hasLength(1));
      expect(forms.single.deletedAt, isNotNull);
    });

    test('outbox triggers queue every new synced table', () async {
      await db.customStatement('DELETE FROM sync_outbox');
      final vid = await addTestVehicle(db);
      final formId = await db.saveChecklistForm(
        name: 'Walkaround',
        items: [(id: null, label: 'Tires')],
      );
      final checklistId = await db.saveChecklist(
        ChecklistDraft(
          vehicleId: vid,
          date: DateTime(2026, 9, 1),
          title: 'Walkaround',
          formId: formId,
          answers: const [
            ChecklistAnswerDraft(label: 'Tires', status: ChecklistStatus.ok),
          ],
        ),
      );
      await db.applyAttachmentChanges(
        parentTable: 'checklists',
        parentId: checklistId,
        vehicleId: vid,
        added: [
          PendingAttachment(
            fileName: 'a.jpg',
            mimeType: 'image/jpeg',
            bytes: Uint8List.fromList([1, 2, 3]),
          ),
        ],
      );
      final tables = (await queued(db)).map((q) => q.split(':').first).toSet();
      expect(
        tables,
        containsAll([
          'vehicles',
          'checklist_forms',
          'checklist_form_items',
          'checklists',
          'checklist_answers',
          'attachments',
        ]),
      );
      // The local bytes table is never synced.
      expect(tables, isNot(contains('attachment_files')));
    });

    test('deleting a record soft-deletes its attachments and bytes', () async {
      final vid = await addTestVehicle(db);
      final readingId = await db.saveReading(
        ReadingsCompanion.insert(
          vehicleId: vid,
          date: DateTime(2026, 9, 1),
          odometer: 100,
        ),
      );
      await db.applyAttachmentChanges(
        parentTable: 'readings',
        parentId: readingId,
        vehicleId: vid,
        added: [
          PendingAttachment(
            fileName: 'odo.jpg',
            mimeType: 'image/jpeg',
            bytes: Uint8List.fromList([9]),
          ),
        ],
      );
      final a = (await db.getAttachments('readings', readingId)).single;
      expect(await db.localAttachmentBytes(a.id), [9]);

      await db.deleteReading(readingId);

      expect(await db.getAttachments('readings', readingId), isEmpty);
      final row = await (db.select(
        db.attachments,
      )..where((x) => x.id.equals(a.id))).getSingle();
      final reading = await (db.select(
        db.readings,
      )..where((x) => x.id.equals(readingId))).getSingle();
      // Same deletion time as the record, so every device agrees.
      expect(row.deletedAt, reading.deletedAt);
      expect(await db.localAttachmentBytes(a.id), isNull);
    });
  });

  test('v3 -> v4 migration keeps data and adds the new tables', () async {
    // Current schema minus everything v4 added = a v3 database.
    final fresh = testDatabase();
    final rows = await fresh
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT "
          "LIKE 'sqlite_%' AND name NOT LIKE '%checklist%' AND name NOT LIKE "
          "'%attachment%' ORDER BY CASE type WHEN 'table' THEN 0 "
          "WHEN 'index' THEN 1 ELSE 2 END",
        )
        .get();
    final schema = [for (final r in rows) r.read<String>('sql')];
    await fresh.close();
    expect(schema.any((s) => s.contains('attachments')), isFalse);

    const t0 = '2026-01-01T10:00:00.000Z';
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final old = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(
          setup: (raw) {
            for (final sql in schema) {
              raw.execute(sql);
            }
            raw.execute(
              'INSERT INTO vehicles (id, created_at, updated_at, name, type) '
              "VALUES ('v1', '$t0', '$t0', 'Honda', 'motorcycle')",
            );
            raw.execute(
              'INSERT INTO readings (id, created_at, updated_at, vehicle_id, '
              "date, odometer) VALUES ('r1', '$t0', '$t0', 'v1', '$t0', 500)",
            );
            raw.execute(
              "INSERT INTO settings_entries VALUES ('catalog_seed_version', '1')",
            );
            raw.execute('DELETE FROM sync_outbox');
            raw.execute('PRAGMA user_version = 3');
          },
        ),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(old.close);

    // Old data intact.
    final reading = await old.getReading('r1');
    expect(reading!.odometer, 500);
    expect((await old.select(old.vehicles).get()).single.name, 'Honda');

    // New tables exist; the default template was seeded by the migration.
    final form = await old.getChecklistForm(preTrip);
    expect(form!.items, hasLength(9));
    final version = await old.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 4);

    // Triggers fire on the upgraded database.
    await old.customStatement('DELETE FROM sync_outbox');
    await old.applyAttachmentChanges(
      parentTable: 'readings',
      parentId: 'r1',
      vehicleId: 'v1',
      added: [
        PendingAttachment(
          fileName: 'x.pdf',
          mimeType: 'application/pdf',
          bytes: Uint8List.fromList([1]),
        ),
      ],
    );
    expect((await queued(old)).single, startsWith('attachments:'));
    await old.deleteReading('r1');
    expect(await old.getAttachments('readings', 'r1'), isEmpty);
    expect(await old.select(old.attachmentFiles).get(), isEmpty);
  });
}
