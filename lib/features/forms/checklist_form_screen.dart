import 'package:flutter/material.dart' hide Route;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/format/formatters.dart';
import '../../core/providers.dart';
import '../../core/theme/record_module.dart';
import '../../core/widgets/module_form_scaffold.dart';
import '../../core/widgets/select_list_screen.dart';
import '../attachments/attachments_field.dart';
import '../checklists/checklist_form_editor_screen.dart';
import '../checklists/checklist_queries.dart';
import '../routes/record_form_parts.dart';

/// Checklist record form (`/add/checklist`, `/edit/checklist/<id>`): pick a
/// template ("Form"), then mark each item OK / Problem / N/A — a Problem
/// gets an inline note. Drivvo locks checklists behind its Fleet plan, so
/// this layout is our own, built from the same parts as the Reading form.
class ChecklistFormScreen extends ConsumerStatefulWidget {
  const ChecklistFormScreen({super.key, this.id});

  /// Null = new checklist; otherwise edit this one.
  final String? id;

  @override
  ConsumerState<ChecklistFormScreen> createState() =>
      _ChecklistFormScreenState();
}

/// One answer line in the form. Its label is a copy of the template item's.
class _AnswerRow {
  _AnswerRow({this.id, required this.label, this.status, String? note})
    : note = TextEditingController(text: note ?? '');

  final String? id;
  final String label;
  ChecklistStatus? status;
  final TextEditingController note;
}

class _ChecklistFormScreenState extends ConsumerState<ChecklistFormScreen> {
  bool get _editing => widget.id != null;
  late bool _loading = _editing;

  bool _dirty = false;
  void _touch() {
    if (!_dirty) setState(() => _dirty = true);
  }

  String? _vehicleId;
  DateTime _date = _nowToMinute();
  final _odometer = TextEditingController();
  final _driver = TextEditingController();
  final _notes = TextEditingController();
  final _attachments = AttachmentsController('checklists');

  /// Chosen template (may be null on an old record whose template is gone)
  /// and the title copied from it.
  String? _formId;
  String? _title;
  final _answers = <_AnswerRow>[];

  static DateTime _nowToMinute() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, n.hour, n.minute);
  }

  @override
  void initState() {
    super.initState();
    if (_editing) {
      _load();
    } else {
      _adoptVehicle(ref.read(vehiclesProvider).value);
      ref.listenManual(vehiclesProvider, (_, next) {
        if (_vehicleId == null) setState(() => _adoptVehicle(next.value));
      });
    }
  }

  void _adoptVehicle(List<Vehicle>? vehicles) {
    if (vehicles == null || vehicles.isEmpty) return;
    final selected = ref.read(settingsProvider).selectedVehicleId;
    _vehicleId =
        (vehicles.where((v) => v.id == selected).firstOrNull ?? vehicles.first)
            .id;
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final details = await db.getChecklist(widget.id!);
    if (!mounted) return;
    if (details == null) {
      Navigator.of(context).pop();
      return;
    }
    await _attachments.load(db, details.checklist.id);
    if (!mounted) return;
    final c = details.checklist;
    setState(() {
      _vehicleId = c.vehicleId;
      _date = c.date;
      _odometer.text = numberInput(c.odometer);
      _formId = c.formId;
      _title = c.title;
      _driver.text = c.driver ?? '';
      _notes.text = c.notes ?? '';
      _answers.addAll([
        for (final a in details.answers)
          _AnswerRow(id: a.id, label: a.label, status: a.status, note: a.note),
      ]);
      _loading = false;
    });
  }

  @override
  void dispose() {
    for (final c in [_odometer, _driver, _notes]) {
      c.dispose();
    }
    for (final a in _answers) {
      a.note.dispose();
    }
    _attachments.dispose();
    super.dispose();
  }

  void _snack(String message) => showFormMessage(context, message);

  /// Forms pick list with "+" (opens the template editor). Choosing a form
  /// copies its items into fresh answers.
  Future<void> _pickForm() async {
    final db = ref.read(databaseProvider);
    var forms = await db.watchChecklistForms().first;
    if (!mounted) return;
    final picked = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => SelectListScreen(
          title: 'Forms',
          items: [for (final f in forms) f.form.name],
          selected: _title,
          onAddNew: () async {
            final id = await Navigator.of(context).push<String>(
              MaterialPageRoute(
                builder: (_) => const ChecklistFormEditorScreen(),
              ),
            );
            if (id == null) return null;
            forms = await db.watchChecklistForms().first;
            return forms.where((f) => f.form.id == id).firstOrNull?.form.name;
          },
        ),
      ),
    );
    final name = picked?.firstOrNull;
    final summary = forms.where((f) => f.form.name == name).firstOrNull;
    if (summary == null || !mounted) return;
    final details = await db.getChecklistForm(summary.form.id);
    if (details == null || !mounted) return;
    _touch();
    setState(() {
      _formId = details.form.id;
      _title = details.form.name;
      for (final a in _answers) {
        a.note.dispose();
      }
      _answers
        ..clear()
        ..addAll([for (final i in details.items) _AnswerRow(label: i.label)]);
    });
  }

  Future<void> _save() async {
    final vehicleId = _vehicleId;
    final title = _title;
    final odometerText = _odometer.text.trim();
    final odometer = parseNumber(odometerText);
    if (vehicleId == null) return _snack('Choose a vehicle');
    if (title == null) return _snack('Choose a form');
    if (odometerText.isNotEmpty && odometer == null) {
      return _snack('Enter a valid odometer');
    }
    final draft = ChecklistDraft(
      vehicleId: vehicleId,
      date: _date,
      odometer: odometer,
      formId: _formId,
      title: title,
      driver: textOrNull(_driver),
      notes: textOrNull(_notes),
      answers: [
        for (final a in _answers)
          ChecklistAnswerDraft(
            id: a.id,
            label: a.label,
            status: a.status,
            note: textOrNull(a.note),
          ),
      ],
    );
    final db = ref.read(databaseProvider);
    await db.transaction(() async {
      final id = await db.saveChecklist(draft, id: widget.id);
      await _attachments.save(db, parentId: id, vehicleId: vehicleId);
    });
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Checklist saved')));
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'checklist')) return;
    await ref.read(databaseProvider).deleteChecklist(widget.id!);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const module = RecordModule.checklist;
    final vehiclesAsync = ref.watch(vehiclesProvider);
    if (_loading || !vehiclesAsync.hasValue) {
      return const FormLoadingView(module: module);
    }
    final vehicles = vehiclesAsync.requireValue;
    if (!_editing && vehicles.isEmpty) {
      return const NoVehicleView(module: module);
    }

    final fmt = ref.watch(formattersProvider);
    final vehicle = vehicles.where((v) => v.id == _vehicleId).firstOrNull;
    final unit = vehicle?.distanceUnit ?? DistanceUnit.km;
    final last = _vehicleId == null
        ? null
        : ref.watch(lastOdometerProvider(_vehicleId!)).value;

    return ModuleFormScaffold(
      module: module,
      onSave: _save,
      isDirty: () => _dirty,
      actions: [
        if (_editing)
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete),
            onPressed: _delete,
          ),
      ],
      children: [
        VehicleField(
          vehicles: vehicles,
          vehicleId: _vehicleId,
          onChanged: (id) {
            _touch();
            setState(() => _vehicleId = id);
          },
        ),
        DateTimeRow(
          value: _date,
          onChanged: (d) {
            _touch();
            setState(() => _date = d);
          },
        ),
        FieldRow(
          icon: Icons.speed,
          helper: last == null
              ? null
              : 'Last odometer: ${fmt.distance(last, unit)}',
          child: TextField(
            controller: _odometer,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Odometer (optional)',
              suffixText: Formatters.distanceUnitLabel(unit),
            ),
            onChanged: (_) => _touch(),
          ),
        ),
        FieldRow(
          icon: Icons.description,
          child: PickerField(
            key: const Key('checklist-form-picker'),
            label: 'Form',
            value: _title,
            onTap: _pickForm,
          ),
        ),
        for (final (i, a) in _answers.indexed)
          _AnswerTile(
            key: ValueKey('answer-$i-${a.label}'),
            answer: a,
            onStatus: (s) {
              _touch();
              setState(() => a.status = s);
            },
            onNoteChanged: _touch,
          ),
        FieldRow(
          icon: Icons.badge,
          child: TextField(
            controller: _driver,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Driver'),
            onChanged: (_) => _touch(),
          ),
        ),
        AttachmentsField(controller: _attachments, onChanged: _touch),
        FieldRow(
          icon: Icons.notes,
          child: TextField(
            controller: _notes,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Notes'),
            onChanged: (_) => _touch(),
          ),
        ),
      ],
    );
  }
}

/// One checklist line: label + OK / Problem / N/A, and a Note field once
/// Problem is chosen.
class _AnswerTile extends StatelessWidget {
  const _AnswerTile({
    super.key,
    required this.answer,
    required this.onStatus,
    required this.onNoteChanged,
  });

  final _AnswerRow answer;
  final ValueChanged<ChecklistStatus?> onStatus;
  final VoidCallback onNoteChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 48, top: 4, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(answer.label)),
              ChecklistStatusChoice(
                label: answer.label,
                value: answer.status,
                onChanged: onStatus,
              ),
            ],
          ),
          if (answer.status == ChecklistStatus.problem)
            TextField(
              key: Key('note-${answer.label}'),
              controller: answer.note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Note'),
              onChanged: (_) => onNoteChanged(),
            ),
        ],
      ),
    );
  }
}

/// Compact 3-way toggle: OK (green ✓) · Problem (red !) · N/A (grey).
/// Tapping the selected choice again clears it (back to "not checked").
class ChecklistStatusChoice extends StatelessWidget {
  const ChecklistStatusChoice({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  /// The item's label, used in the buttons' keys and tooltips.
  final String label;
  final ChecklistStatus? value;
  final ValueChanged<ChecklistStatus?> onChanged;

  static const okColor = Color(0xFF2E7D32);
  static const problemColor = Color(0xFFD32F2F);

  @override
  Widget build(BuildContext context) {
    Widget button(ChecklistStatus s, Widget icon, Color color, String tip) {
      final selected = value == s;
      return Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Tooltip(
          message: tip,
          child: InkResponse(
            key: Key('status-${s.name}-$label'),
            radius: 20,
            onTap: () => onChanged(selected ? null : s),
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? color : Colors.transparent,
                border: Border.all(
                  color: selected ? color : Colors.grey.shade400,
                ),
              ),
              child: IconTheme(
                data: IconThemeData(
                  size: 18,
                  color: selected ? Colors.white : Colors.grey.shade600,
                ),
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.white : Colors.grey.shade600,
                  ),
                  child: icon,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(ChecklistStatus.ok, const Icon(Icons.check), okColor, 'OK'),
        button(
          ChecklistStatus.problem,
          const Icon(Icons.priority_high),
          problemColor,
          'Problem',
        ),
        button(
          ChecklistStatus.na,
          const Text('N/A'),
          Colors.grey.shade600,
          'Not applicable',
        ),
      ],
    );
  }
}
