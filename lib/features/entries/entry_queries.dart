import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import 'installments.dart';

/// One typed line of an entry with its catalog name ("Oil Change — 1200").
class EntryLine {
  const EntryLine({required this.item, required this.typeName});

  final EntryItem item;
  final String typeName;

  String get typeId => item.typeId;
  double get amount => item.amount;
  String? get partNumber => item.partNumber;
}

/// An expense/service/income row plus everything a list or detail view
/// needs to show it (line items and the names of linked catalog items).
class EntryWithItems {
  const EntryWithItems({
    required this.entry,
    required this.items,
    this.placeName,
    this.paymentMethodName,
    this.reasonName,
  });

  final Entry entry;
  final List<EntryLine> items;
  final String? placeName;
  final String? paymentMethodName;
  final String? reasonName;

  /// Sum of the line items before discount.
  double get itemsTotal => items.fold(0, (sum, l) => sum + l.amount);

  /// History row title: "Oil Change +2 more" (Drivvo style).
  String get typeSummary {
    if (items.isEmpty) return entry.title ?? '';
    final first = items.first.typeName;
    return items.length == 1 ? first : '$first +${items.length - 1} more';
  }

  bool get isInstallment => entry.installmentCount > 1;

  /// Id shared by every installment of a group (the parent row's id).
  String get groupId => entry.parentId ?? entry.id;
}

/// A line of an [EntryDraft].
class EntryItemDraft {
  const EntryItemDraft({
    required this.typeId,
    required this.amount,
    this.typeName,
    this.partNumber,
  });

  final String typeId;

  /// Whole amount for the entry (before splitting into installments).
  final double amount;

  /// Display only (filled when loading for edit); not saved.
  final String? typeName;

  /// Service items only: the replaced part's number or brand. Not split
  /// across installments — every installment carries the same value.
  final String? partNumber;
}

/// What the form submits: the *whole* entry, before it is split into
/// installments. Think of it as the form's DTO.
class EntryDraft {
  const EntryDraft({
    required this.vehicleId,
    required this.kind,
    required this.date,
    required this.items,
    this.odometer,
    this.title,
    this.placeId,
    this.paymentMethodId,
    this.reasonId,
    this.driver,
    this.discount = 0,
    this.notes,
    this.installments = 1,
    this.interval = InstallmentInterval.monthly,
  });

  final String vehicleId;
  final EntryKind kind;

  /// Date of the first installment.
  final DateTime date;
  final List<EntryItemDraft> items;
  final double? odometer;
  final String? title;
  final String? placeId;
  final String? paymentMethodId;
  final String? reasonId;
  final String? driver;
  final double discount;
  final String? notes;
  final int installments;
  final InstallmentInterval interval;

  /// Sum of items minus discount.
  double get total => items.fold(0.0, (s, i) => s + i.amount) - discount;
}

/// An entry loaded for the edit form: the whole installment group merged
/// back into one [EntryDraft].
class EditableEntry {
  const EditableEntry({
    required this.draft,
    required this.groupId,
    required this.openedInstallmentNo,
    required this.names,
  });

  final EntryDraft draft;
  final String groupId;

  /// Which installment the user tapped (for the "Installment 2 of 3" note).
  final int openedInstallmentNo;

  /// Catalog id → name for the place / payment method / reason / types.
  final Map<String, String> names;
}

/// Expense / service / income queries. An extension (like adding methods to
/// a class from another file) so this feature doesn't touch app_database.dart.
extension EntryQueries on AppDatabase {
  /// Live list of a vehicle's entries (newest first), optionally one kind.
  Stream<List<EntryWithItems>> watchEntries(
    String vehicleId, {
    EntryKind? kind,
  }) {
    Expression<bool> filter = entries.vehicleId.equals(vehicleId);
    if (kind != null) filter = filter & entries.kind.equalsValue(kind);
    final join = _EntryJoin(this);
    return join.query(filter).watch().map(join.group);
  }

  /// Live single entry (null once deleted).
  Stream<EntryWithItems?> watchEntry(String id) {
    final join = _EntryJoin(this);
    return join
        .query(entries.id.equals(id))
        .watch()
        .map((rows) => join.group(rows).firstOrNull);
  }

  /// One entry with its items (null if missing or deleted).
  Future<EntryWithItems?> getEntry(String id) async {
    final join = _EntryJoin(this);
    final rows = await join.query(entries.id.equals(id)).get();
    return join.group(rows).firstOrNull;
  }

  /// Live rows of an installment group, in installment order.
  Future<List<Entry>> _groupEntries(String groupId) {
    return (select(entries)
          ..where(
            (e) =>
                (e.id.equals(groupId) | e.parentId.equals(groupId)) &
                e.deletedAt.isNull(),
          )
          ..orderBy([(e) => OrderingTerm.asc(e.installmentNo)]))
        .get();
  }

  /// Creates the entry (split into installments), or — when [id] is given —
  /// replaces the whole installment group [id] belongs to. Returns the
  /// parent (installment 1) id.
  Future<String> saveEntry(EntryDraft draft, {String? id}) {
    final count = draft.installments < 1 ? 1 : draft.installments;
    final shares = planInstallments(
      firstDate: draft.date,
      count: count,
      interval: draft.interval,
      total: draft.total,
      discount: draft.discount,
      itemAmounts: [for (final i in draft.items) i.amount],
    );

    EntriesCompanion row(InstallmentShare s, String? parentId) =>
        EntriesCompanion(
          vehicleId: Value(draft.vehicleId),
          kind: Value(draft.kind),
          date: Value(s.date),
          // Only the first installment carries the odometer reading.
          odometer: Value(s.number == 1 ? draft.odometer : null),
          title: Value(draft.title),
          placeId: Value(draft.placeId),
          paymentMethodId: Value(draft.paymentMethodId),
          reasonId: Value(draft.reasonId),
          driver: Value(draft.driver),
          discount: Value(s.discount == 0 ? null : s.discount),
          totalCost: Value(s.totalCost),
          parentId: Value(parentId),
          installmentNo: Value(s.number),
          installmentCount: Value(count),
          notes: Value(draft.notes),
          updatedAt: Value(DateTime.now()),
        );

    Future<void> insertItems(String entryId, InstallmentShare s) async {
      for (final (i, item) in draft.items.indexed) {
        await into(entryItems).insert(
          EntryItemsCompanion.insert(
            entryId: entryId,
            typeId: item.typeId,
            amount: s.itemAmounts[i],
            partNumber: Value(item.partNumber),
          ),
        );
      }
    }

    // A transaction = all-or-nothing, like `BEGIN ... COMMIT` in SQL.
    return transaction(() async {
      String parentId;
      if (id == null) {
        parentId = (await into(
          entries,
        ).insertReturning(row(shares.first, null))).id;
      } else {
        // Edit: keep the parent row (stable id), drop the rest, regenerate.
        final current = await (select(
          entries,
        )..where((e) => e.id.equals(id))).getSingle();
        parentId = current.parentId ?? current.id;
        await _softDeleteGroup(parentId, keepParent: true);
        // `deletedAt: null` revives a parent that was deleted on its own
        // (e.g. by a sync), so the edit never writes into a dead row.
        final updated =
            await (update(entries)..where((e) => e.id.equals(parentId))).write(
              row(shares.first, null).copyWith(deletedAt: const Value(null)),
            );
        if (updated == 0) {
          // Parent row is gone entirely: rebuild the group around a new one.
          parentId = (await into(
            entries,
          ).insertReturning(row(shares.first, null))).id;
        }
      }
      await insertItems(parentId, shares.first);

      for (final share in shares.skip(1)) {
        final child = await into(entries).insertReturning(row(share, parentId));
        await insertItems(child.id, share);
      }
      return parentId;
    });
  }

  /// Soft-deletes the entry's whole installment group and its items.
  Future<void> deleteEntry(String id) {
    return transaction(() async {
      final current = await (select(
        entries,
      )..where((e) => e.id.equals(id))).getSingleOrNull();
      if (current == null) return;
      await _softDeleteGroup(current.parentId ?? current.id);
    });
  }

  /// Marks the group's items (and rows, optionally except the parent) deleted.
  /// The parent's items are included even when the parent row itself is
  /// already deleted, so reviving it on edit can't leave stale lines behind.
  Future<void> _softDeleteGroup(
    String groupId, {
    bool keepParent = false,
  }) async {
    final now = DateTime.now();
    final ids = {groupId, for (final e in await _groupEntries(groupId)) e.id};
    await (update(
      entryItems,
    )..where((i) => i.entryId.isIn(ids) & i.deletedAt.isNull())).write(
      EntryItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
    await (update(entries)..where(
          (e) =>
              e.id.isIn(ids) &
              e.deletedAt.isNull() &
              (keepParent ? e.parentId.isNotNull() : const Constant(true)),
        ))
        .write(EntriesCompanion(deletedAt: Value(now), updatedAt: Value(now)));
  }

  /// Loads [id]'s installment group merged back into one draft for editing:
  /// item amounts (line by line), discount and the installment count are
  /// summed over the group; the interval is inferred from the first two
  /// dates.
  Future<EditableEntry?> loadEditableEntry(String id) async {
    final opened = await (select(
      entries,
    )..where((e) => e.id.equals(id) & e.deletedAt.isNull())).getSingleOrNull();
    if (opened == null) return null;
    final groupId = opened.parentId ?? opened.id;
    final rows = await _groupEntries(groupId);
    final parent = rows.first;

    // Every installment stores the same lines in the same order, so line k
    // of the whole entry = the sum of line k of each row. Summing by
    // position (not by type) keeps two lines of the same type apart.
    final type = alias(catalogItems, 'item_type');
    final itemRows =
        await (select(entryItems)
                .join([innerJoin(type, type.id.equalsExp(entryItems.typeId))])
              ..where(
                entryItems.entryId.isIn([for (final r in rows) r.id]) &
                    entryItems.deletedAt.isNull(),
              )
              ..orderBy([
                OrderingTerm.asc(
                  const CustomExpression<int>('"entry_items"."rowid"'),
                ),
              ]))
            .get();
    final names = <String, String>{};
    final itemsByEntry = <String, List<EntryItem>>{};
    for (final r in itemRows) {
      final item = r.readTable(entryItems);
      itemsByEntry.putIfAbsent(item.entryId, () => []).add(item);
      names[item.typeId] = r.readTable(type).name;
    }
    final lineTypes = <String>[];
    final lineCents = <int>[];
    // Not split across installments (unlike the amount), so this is
    // whichever installment's row is read first for that line — they all
    // carry the same value (see `insertItems`).
    final linePartNumbers = <String?>[];
    for (final row in rows) {
      for (final (k, item) in (itemsByEntry[row.id] ?? const []).indexed) {
        if (k == lineTypes.length) {
          lineTypes.add(item.typeId);
          lineCents.add(0);
          linePartNumbers.add(item.partNumber);
        }
        lineCents[k] += (item.amount * 100).round();
      }
    }

    final linked = [
      parent.placeId,
      parent.paymentMethodId,
      parent.reasonId,
    ].nonNulls.toList();
    if (linked.isNotEmpty) {
      final catalog = await (select(
        catalogItems,
      )..where((c) => c.id.isIn(linked))).get();
      for (final c in catalog) {
        names[c.id] = c.name;
      }
    }

    final discount = rows.fold(0.0, (s, r) => s + (r.discount ?? 0));
    return EditableEntry(
      groupId: groupId,
      openedInstallmentNo: opened.installmentNo,
      names: names,
      draft: EntryDraft(
        vehicleId: parent.vehicleId,
        kind: parent.kind,
        date: parent.date,
        odometer: parent.odometer,
        title: parent.title,
        placeId: parent.placeId,
        paymentMethodId: parent.paymentMethodId,
        reasonId: parent.reasonId,
        driver: parent.driver,
        discount: (discount * 100).round() / 100,
        notes: parent.notes,
        installments: rows.length,
        interval: rows.length > 1
            ? inferInterval(rows[0].date, rows[1].date)
            : InstallmentInterval.monthly,
        items: [
          for (final (k, typeId) in lineTypes.indexed)
            EntryItemDraft(
              typeId: typeId,
              amount: lineCents[k] / 100,
              typeName: names[typeId],
              partNumber: linePartNumbers[k],
            ),
        ],
      ),
    );
  }

  /// Adds a user-created catalog item (from a picker's "+") and returns it.
  Future<CatalogItem> addCatalogItem(CatalogKind kind, String name) {
    return into(catalogItems)
        .insertReturning(CatalogItemsCompanion.insert(kind: kind, name: name));
  }
}

/// Entries JOIN items JOIN catalog names. The catalog table is joined four
/// times, so each join gets its own SQL alias (`AS item_type`, `AS place`…).
/// The same alias objects must be used to build the query and to read rows.
class _EntryJoin {
  _EntryJoin(this.db)
    : type = db.alias(db.catalogItems, 'item_type'),
      place = db.alias(db.catalogItems, 'place'),
      payment = db.alias(db.catalogItems, 'payment'),
      reason = db.alias(db.catalogItems, 'reason');

  final AppDatabase db;
  final $CatalogItemsTable type;
  final $CatalogItemsTable place;
  final $CatalogItemsTable payment;
  final $CatalogItemsTable reason;

  /// Items come back in insertion order (SQLite's hidden `rowid`), so lines
  /// keep the order the user picked them in.
  JoinedSelectStatement<HasResultSet, dynamic> query(Expression<bool> filter) {
    final e = db.entries;
    final items = db.entryItems;
    return db.select(e).join([
        leftOuterJoin(
          items,
          items.entryId.equalsExp(e.id) & items.deletedAt.isNull(),
        ),
        leftOuterJoin(type, type.id.equalsExp(items.typeId)),
        leftOuterJoin(place, place.id.equalsExp(e.placeId)),
        leftOuterJoin(payment, payment.id.equalsExp(e.paymentMethodId)),
        leftOuterJoin(reason, reason.id.equalsExp(e.reasonId)),
      ])
      ..where(e.deletedAt.isNull() & filter)
      ..orderBy([
        OrderingTerm.desc(e.date),
        OrderingTerm.asc(e.id),
        OrderingTerm.asc(const CustomExpression<int>('"entry_items"."rowid"')),
      ]);
  }

  /// Flat JOIN rows (one per item) → one [EntryWithItems] per entry.
  List<EntryWithItems> group(List<TypedResult> rows) {
    // Dart map literals keep insertion order, so the SQL order survives.
    final byId = <String, (TypedResult, List<EntryLine>)>{};
    for (final row in rows) {
      final entry = row.readTable(db.entries);
      final group = byId.putIfAbsent(entry.id, () => (row, []));
      final item = row.readTableOrNull(db.entryItems);
      if (item != null) {
        group.$2.add(
          EntryLine(
            item: item,
            typeName: row.readTableOrNull(type)?.name ?? '',
          ),
        );
      }
    }
    return [
      for (final (row, items) in byId.values)
        EntryWithItems(
          entry: row.readTable(db.entries),
          items: items,
          placeName: row.readTableOrNull(place)?.name,
          paymentMethodName: row.readTableOrNull(payment)?.name,
          reasonName: row.readTableOrNull(reason)?.name,
        ),
    ];
  }
}
