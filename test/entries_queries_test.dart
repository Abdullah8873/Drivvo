import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/features/entries/entry_queries.dart';
import 'package:motolog/features/entries/installments.dart';

import 'helpers.dart';

void main() {
  late AppDatabase db;
  late String vehicleId;
  late Map<String, String> types; // service type name → id

  setUp(() async {
    db = testDatabase();
    vehicleId = await addTestVehicle(db);
    final catalog = await db.watchCatalog(CatalogKind.serviceType).first;
    types = {for (final c in catalog) c.name: c.id};
  });
  tearDown(() => db.close());

  EntryDraft draft({int installments = 1, double discount = 0}) => EntryDraft(
    vehicleId: vehicleId,
    kind: EntryKind.service,
    date: DateTime(2026, 9, 1, 9),
    odometer: 56403,
    discount: discount,
    installments: installments,
    interval: InstallmentInterval.weekly,
    items: [
      EntryItemDraft(typeId: types['Oil Change']!, amount: 1200),
      EntryItemDraft(typeId: types['Air Filter']!, amount: 800),
    ],
  );

  test('saves an entry with items and type names', () async {
    final id = await db.saveEntry(draft(discount: 100));
    final e = (await db.getEntry(id))!;
    expect(e.entry.totalCost, 1900);
    expect(e.entry.discount, 100);
    expect(e.items.map((l) => (l.typeName, l.amount)), [
      ('Oil Change', 1200),
      ('Air Filter', 800),
    ]);
    expect(e.typeSummary, 'Oil Change +1 more');

    final listed = await db
        .watchEntries(vehicleId, kind: EntryKind.service)
        .first;
    expect(listed, hasLength(1));
    expect(
      await db.watchEntries(vehicleId, kind: EntryKind.expense).first,
      isEmpty,
    );
  });

  test('installments create a linked group', () async {
    final parentId = await db.saveEntry(draft(installments: 3));
    final rows = (await db.watchEntries(vehicleId).first).reversed.toList();
    expect(rows, hasLength(3));
    expect(rows.first.entry.id, parentId);
    expect(rows.first.entry.parentId, isNull);
    expect(rows.first.entry.odometer, 56403);
    expect(rows[1].entry.odometer, isNull);
    for (final (i, r) in rows.indexed) {
      expect(r.entry.installmentNo, i + 1);
      expect(r.entry.installmentCount, 3);
      expect(r.groupId, parentId);
    }
    expect(rows.map((r) => r.entry.totalCost), [666.68, 666.66, 666.66]);
    expect(rows[2].entry.date, DateTime(2026, 9, 15, 9));
    expect(rows[1].items.map((l) => l.amount), [400, 266.66]);
  });

  test('editing an installment regenerates the whole group', () async {
    final parentId = await db.saveEntry(draft(installments: 3));
    final child = (await db.watchEntries(vehicleId).first).first.entry;

    final loaded = (await db.loadEditableEntry(child.id))!;
    expect(loaded.groupId, parentId);
    expect(loaded.openedInstallmentNo, 3);
    expect(loaded.draft.installments, 3);
    expect(loaded.draft.interval, InstallmentInterval.weekly);
    expect(loaded.draft.items.map((i) => i.amount), [1200, 800]);
    expect(loaded.draft.items.first.typeName, 'Oil Change');

    await db.saveEntry(draft(installments: 2), id: child.id);
    final rows = await db.watchEntries(vehicleId).first;
    expect(rows, hasLength(2));
    expect(rows.map((r) => r.groupId).toSet(), {parentId});
    expect(rows.fold(0.0, (s, r) => s + r.entry.totalCost), 2000);
  });

  test('deleting any installment soft-deletes the group', () async {
    final parentId = await db.saveEntry(draft(installments: 2));
    final child = (await db.watchEntries(vehicleId).first).first.entry;
    expect(child.parentId, parentId);

    await db.deleteEntry(child.id);
    expect(await db.watchEntries(vehicleId).first, isEmpty);
    expect(await db.getEntry(parentId), isNull);
    // Soft delete: the rows are still there, just marked.
    final all = await db.select(db.entries).get();
    expect(all.every((e) => e.deletedAt != null), isTrue);
    final items = await db.select(db.entryItems).get();
    expect(items.every((i) => i.deletedAt != null), isTrue);
  });

  test('addCatalogItem creates a pickable item', () async {
    final created = await db.addCatalogItem(CatalogKind.place, 'Workshop');
    final places = await db.watchCatalog(CatalogKind.place).first;
    expect(places.map((p) => p.id), [created.id]);
  });
}
