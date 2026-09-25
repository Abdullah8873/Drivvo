import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';

/// A template in the Forms list: the form plus its live item count.
class ChecklistFormSummary {
  const ChecklistFormSummary({required this.form, required this.itemCount});

  final ChecklistForm form;
  final int itemCount;
}

/// A template with its live items, in order.
class ChecklistFormDetails {
  const ChecklistFormDetails({required this.form, required this.items});

  final ChecklistForm form;
  final List<ChecklistFormItem> items;
}

/// One template line as edited in the template editor ([id] null = new).
typedef FormItemDraft = ({String? id, String label});

/// One answered line as edited in the checklist form ([id] null = new).
class ChecklistAnswerDraft {
  const ChecklistAnswerDraft({
    this.id,
    required this.label,
    this.status,
    this.note,
  });

  final String? id;
  final String label;
  final ChecklistStatus? status;
  final String? note;
}

/// Everything the checklist form saves.
class ChecklistDraft {
  const ChecklistDraft({
    required this.vehicleId,
    required this.date,
    required this.title,
    required this.answers,
    this.odometer,
    this.formId,
    this.driver,
    this.notes,
  });

  final String vehicleId;
  final DateTime date;
  final double? odometer;
  final String? formId;
  final String title;
  final String? driver;
  final String? notes;
  final List<ChecklistAnswerDraft> answers;
}

/// A saved checklist run with its live answers, in order.
class ChecklistDetails {
  const ChecklistDetails({required this.checklist, required this.answers});

  final Checklist checklist;
  final List<ChecklistAnswer> answers;
}

/// Checklist templates ("Forms") and checklist records.
extension ChecklistQueries on AppDatabase {
  // ---- Templates ------------------------------------------------------------

  /// Live templates, alphabetically, with their item counts.
  Stream<List<ChecklistFormSummary>> watchChecklistForms() {
    return customSelect(
      '''
      SELECT f.id AS id, (
        SELECT COUNT(*) FROM checklist_form_items i
        WHERE i.form_id = f.id AND i.deleted_at IS NULL
      ) AS n
      FROM checklist_forms f WHERE f.deleted_at IS NULL
      ''',
      readsFrom: {checklistForms, checklistFormItems},
    ).watch().asyncMap((rows) async {
      final counts = {
        for (final r in rows) r.read<String>('id'): r.read<int>('n'),
      };
      final forms =
          await (select(checklistForms)
                ..where((f) => f.deletedAt.isNull())
                ..orderBy([
                  (f) => OrderingTerm.asc(f.name.collate(Collate.noCase)),
                ]))
              .get();
      return [
        for (final f in forms)
          ChecklistFormSummary(form: f, itemCount: counts[f.id] ?? 0),
      ];
    });
  }

  Future<ChecklistFormDetails?> getChecklistForm(String id) async {
    final form = await (select(
      checklistForms,
    )..where((f) => f.id.equals(id) & f.deletedAt.isNull())).getSingleOrNull();
    if (form == null) return null;
    final items =
        await (select(checklistFormItems)
              ..where((i) => i.formId.equals(id) & i.deletedAt.isNull())
              ..orderBy([(i) => OrderingTerm.asc(i.position)]))
            .get();
    return ChecklistFormDetails(form: form, items: items);
  }

  /// Creates ([id] null) or updates a template and its items, returning its
  /// id. Items keep their ids (only changed rows are rewritten, so a sync
  /// uploads just what changed); items no longer listed are soft-deleted.
  /// Past checklists are unaffected: they hold copies of the labels.
  Future<String> saveChecklistForm({
    String? id,
    required String name,
    String? notes,
    required List<FormItemDraft> items,
  }) => transaction(() async {
    final now = DateTime.now();
    final String formId;
    if (id == null) {
      formId = (await into(checklistForms).insertReturning(
        ChecklistFormsCompanion.insert(name: name, notes: Value(notes)),
      )).id;
    } else {
      formId = id;
      final current = await (select(
        checklistForms,
      )..where((f) => f.id.equals(id))).getSingle();
      if (current.name != name || current.notes != notes) {
        await (update(checklistForms)..where((f) => f.id.equals(id))).write(
          ChecklistFormsCompanion(
            name: Value(name),
            notes: Value(notes),
            updatedAt: Value(now),
          ),
        );
      }
    }
    final existing = {
      for (final i in await (select(
        checklistFormItems,
      )..where((i) => i.formId.equals(formId) & i.deletedAt.isNull())).get())
        i.id: i,
    };
    final kept = <String>{};
    for (final (position, item) in items.indexed) {
      final old = item.id == null ? null : existing[item.id];
      if (old == null) {
        await into(checklistFormItems).insert(
          ChecklistFormItemsCompanion.insert(
            formId: formId,
            position: position,
            label: item.label,
          ),
        );
        continue;
      }
      kept.add(old.id);
      if (old.position != position || old.label != item.label) {
        await (update(
          checklistFormItems,
        )..where((i) => i.id.equals(old.id))).write(
          ChecklistFormItemsCompanion(
            position: Value(position),
            label: Value(item.label),
            updatedAt: Value(now),
          ),
        );
      }
    }
    final dropped = existing.keys.where((k) => !kept.contains(k)).toList();
    if (dropped.isNotEmpty) {
      await (update(
        checklistFormItems,
      )..where((i) => i.id.isIn(dropped))).write(
        ChecklistFormItemsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }
    return formId;
  });

  /// Soft-deletes a template and its items.
  Future<void> deleteChecklistForm(String id) => transaction(() async {
    final now = Value(DateTime.now());
    await (update(checklistFormItems)
          ..where((i) => i.formId.equals(id) & i.deletedAt.isNull()))
        .write(ChecklistFormItemsCompanion(deletedAt: now, updatedAt: now));
    await (update(checklistForms)..where((f) => f.id.equals(id))).write(
      ChecklistFormsCompanion(deletedAt: now, updatedAt: now),
    );
  });

  // ---- Checklist records ------------------------------------------------------

  Future<ChecklistDetails?> getChecklist(String id) async {
    final c = await (select(
      checklists,
    )..where((c) => c.id.equals(id) & c.deletedAt.isNull())).getSingleOrNull();
    if (c == null) return null;
    final answers =
        await (select(checklistAnswers)
              ..where((a) => a.checklistId.equals(id) & a.deletedAt.isNull())
              ..orderBy([(a) => OrderingTerm.asc(a.position)]))
            .get();
    return ChecklistDetails(checklist: c, answers: answers);
  }

  /// Inserts ([id] null) or updates a checklist and its answers in one
  /// transaction, returning its id. Answers with an id are updated in place
  /// (when changed), new ones inserted, missing ones soft-deleted.
  Future<String> saveChecklist(
    ChecklistDraft draft, {
    String? id,
  }) => transaction(() async {
    final now = DateTime.now();
    final row = ChecklistsCompanion(
      vehicleId: Value(draft.vehicleId),
      date: Value(draft.date),
      odometer: Value(draft.odometer),
      formId: Value(draft.formId),
      title: Value(draft.title),
      driver: Value(draft.driver),
      notes: Value(draft.notes),
      updatedAt: Value(now),
    );
    final String checklistId;
    if (id == null) {
      checklistId = (await into(checklists).insertReturning(row)).id;
    } else {
      checklistId = id;
      await (update(checklists)..where((c) => c.id.equals(id))).write(row);
    }
    final existing = {
      for (final a
          in await (select(checklistAnswers)..where(
                (a) => a.checklistId.equals(checklistId) & a.deletedAt.isNull(),
              ))
              .get())
        a.id: a,
    };
    final kept = <String>{};
    for (final (position, a) in draft.answers.indexed) {
      final old = a.id == null ? null : existing[a.id];
      final note = a.status == ChecklistStatus.problem ? a.note : null;
      if (old == null) {
        await into(checklistAnswers).insert(
          ChecklistAnswersCompanion.insert(
            checklistId: checklistId,
            position: position,
            label: a.label,
            status: Value(a.status),
            note: Value(note),
          ),
        );
        continue;
      }
      kept.add(old.id);
      if (old.position != position ||
          old.label != a.label ||
          old.status != a.status ||
          old.note != note) {
        await (update(
          checklistAnswers,
        )..where((r) => r.id.equals(old.id))).write(
          ChecklistAnswersCompanion(
            position: Value(position),
            label: Value(a.label),
            status: Value(a.status),
            note: Value(note),
            updatedAt: Value(now),
          ),
        );
      }
    }
    final dropped = existing.keys.where((k) => !kept.contains(k)).toList();
    if (dropped.isNotEmpty) {
      await (update(checklistAnswers)..where((r) => r.id.isIn(dropped))).write(
        ChecklistAnswersCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
    }
    return checklistId;
  });

  /// Soft-deletes a checklist and its answers (its attachments follow via
  /// the database trigger, see `AppDatabase.createAttachmentTriggers`).
  Future<void> deleteChecklist(String id) => transaction(() async {
    final now = Value(DateTime.now());
    await (update(checklistAnswers)
          ..where((a) => a.checklistId.equals(id) & a.deletedAt.isNull()))
        .write(ChecklistAnswersCompanion(deletedAt: now, updatedAt: now));
    await (update(checklists)..where((c) => c.id.equals(id))).write(
      ChecklistsCompanion(deletedAt: now, updatedAt: now),
    );
  });
}
