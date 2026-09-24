import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import '../../core/format/formatters.dart';
import '../../core/providers.dart';
import '../../core/theme/record_module.dart';
import '../../core/widgets/module_form_scaffold.dart';
import '../../core/widgets/select_list_screen.dart';
import '../routes/record_form_parts.dart' show parseNumber;
import '../vehicles/vehicle_labels.dart';
import 'reminder_queries.dart';

/// Create / edit a reminder (purple Reminder module).
///
/// EXPENSE | SERVICE → type → JUST ONE TIME | REPEAT EVERY → triggers:
/// - one time: at an odometer and/or on a date;
/// - repeat: every N km and/or every N days/months/years.
class ReminderFormScreen extends ConsumerStatefulWidget {
  const ReminderFormScreen({super.key, this.id});

  /// Null = new reminder; otherwise edit this one.
  final String? id;

  @override
  ConsumerState<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends ConsumerState<ReminderFormScreen> {
  static const _module = RecordModule.reminder;

  /// The row being edited (null for a new reminder).
  Reminder? _existing;
  late bool _loading = widget.id != null;

  /// True once the user has changed something — drives the unsaved-changes
  /// back guard. Only flips once (further edits don't need another rebuild).
  bool _dirty = false;
  void _touch() {
    if (!_dirty) setState(() => _dirty = true);
  }

  String? _vehicleId;
  ReminderTarget _target = ReminderTarget.service;
  String? _typeId;
  bool _repeat = false;
  bool _byDistance = true;
  bool _byDate = false;
  DateTime? _dueDate;
  PeriodUnit _everyUnit = PeriodUnit.month;
  final _dueOdometer = TextEditingController();
  final _everyDistance = TextEditingController();
  final _everyAmount = TextEditingController();
  final _notes = TextEditingController();

  AppDatabase get _db => ref.read(databaseProvider);

  CatalogKind get _typeKind => _target == ReminderTarget.service
      ? CatalogKind.serviceType
      : CatalogKind.expenseType;

  @override
  void initState() {
    super.initState();
    if (widget.id != null) _load(widget.id!);
  }

  @override
  void dispose() {
    for (final c in [_dueOdometer, _everyDistance, _everyAmount, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load(String id) async {
    final r = await _db.getReminder(id);
    if (!mounted) return;
    String text(double? v) => v == null ? '' : _trim(v);
    setState(() {
      _loading = false;
      _existing = r;
      if (r == null) return;
      _vehicleId = r.vehicleId;
      _target = r.target;
      _typeId = r.typeId;
      _repeat = r.repeat;
      _byDistance = r.byDistance;
      _byDate = r.byDate;
      _dueDate = r.dueDate;
      _everyUnit = r.everyUnit ?? PeriodUnit.month;
      _dueOdometer.text = text(r.dueOdometer);
      _everyDistance.text = text(r.everyDistance);
      _everyAmount.text = r.everyAmount?.toString() ?? '';
      _notes.text = r.notes ?? '';
    });
  }

  /// "57132" instead of "57132.0".
  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  void _snack(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  // ---- Pickers --------------------------------------------------------------

  Future<void> _pickVehicle(List<Vehicle> vehicles) async {
    final picked = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => SelectListScreen(
          title: 'Vehicles',
          items: [for (final v in vehicles) v.name],
        ),
      ),
    );
    final name = picked?.firstOrNull;
    if (name == null) return;
    _touch();
    setState(() => _vehicleId = vehicles.firstWhere((v) => v.name == name).id);
  }

  Future<void> _pickType() async {
    final kind = _typeKind;
    final types = await _db.getCatalog(kind);
    if (!mounted) return;
    final picked = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => SelectListScreen(
          title: kind == CatalogKind.serviceType
              ? 'Types of service'
              : 'Types of expense',
          items: [for (final t in types) t.name],
          onAddNew: () => _addType(kind),
        ),
      ),
    );
    final name = picked?.firstOrNull;
    if (name == null) return;
    // Re-read so a type created with "+" is included.
    final fresh = await _db.getCatalog(kind);
    final match = fresh.where((t) => t.name == name).firstOrNull;
    if (match != null && mounted) {
      _touch();
      setState(() => _typeId = match.id);
    }
  }

  /// The "+" in the type picker: ask for a name and add it to the catalog.
  Future<String?> _addType(CatalogKind kind) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          kind == CatalogKind.serviceType
              ? 'New type of service'
              : 'New type of expense',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return null;
    await _db.addCatalogItem(kind, name);
    return name;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 30),
    );
    if (d != null) {
      _touch();
      setState(() => _dueDate = d);
    }
  }

  // ---- Save / delete ----------------------------------------------------------

  Future<void> _save() async {
    final vehicleId = _vehicleId ?? ref.read(currentVehicleProvider).value?.id;
    final dueOdo = parseNumber(_dueOdometer.text);
    final everyDist = parseNumber(_everyDistance.text);
    final everyAmount = int.tryParse(_everyAmount.text.trim());

    // First failing rule wins (like a form validator returning one message).
    String? validate() {
      if (vehicleId == null) return 'Select a vehicle';
      if (_typeId == null) return 'Select the type';
      if (!_byDistance && !_byDate) return 'Choose at least one: km or date';
      if (_byDistance) {
        final v = _repeat ? everyDist : dueOdo;
        if (v == null || v <= 0) {
          return _repeat ? 'Enter the distance' : 'Enter the odometer';
        }
      }
      if (_byDate) {
        if (!_repeat && _dueDate == null) return 'Select the date';
        if (_repeat && (everyAmount == null || everyAmount <= 0)) {
          return 'Enter the period';
        }
      }
      return null;
    }

    final error = validate();
    if (error != null) return _snack(error);

    final data = RemindersCompanion(
      vehicleId: Value(vehicleId!),
      target: Value(_target),
      typeId: Value(_typeId!),
      repeat: Value(_repeat),
      byDistance: Value(_byDistance),
      dueOdometer: Value(!_repeat && _byDistance ? dueOdo : null),
      everyDistance: Value(_repeat && _byDistance ? everyDist : null),
      byDate: Value(_byDate),
      dueDate: Value(!_repeat && _byDate ? _dueDate : null),
      everyAmount: Value(_repeat && _byDate ? everyAmount : null),
      everyUnit: Value(_repeat && _byDate ? _everyUnit : null),
      notes: Value(_notes.text.trim().isEmpty ? null : _notes.text.trim()),
    );

    final existing = _existing;
    // Freeze "where the interval starts" (odometer + date now) so a repeating
    // reminder with nothing logged yet doesn't drift as you keep driving.
    final needsBaseline =
        existing == null ||
        existing.lastDoneDate == null ||
        existing.vehicleId != vehicleId;
    final baseline = needsBaseline
        ? data.copyWith(
            lastDoneOdometer: Value(
              await ref.read(lastOdometerProvider(vehicleId).future),
            ),
            lastDoneDate: Value(DateTime.now()),
          )
        : data;

    if (existing == null) {
      await _db.insertReminder(baseline);
    } else {
      await _db.updateReminder(existing.id, baseline);
    }
    // TODO(notifications): schedule/cancel the local notification here
    // (flutter_local_notifications) using the next due date/predicted date.
    if (!mounted) return;
    Navigator.of(context).pop();
    _snack('Reminder saved');
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this reminder?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (ok != true || _existing == null) return;
    await _db.softDeleteReminder(_existing!.id);
    // TODO(notifications): cancel this reminder's scheduled notification.
    if (!mounted) return;
    Navigator.of(context).pop();
    _snack('Reminder deleted');
  }

  // ---- UI -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final vehicles = vehiclesAsync.value;

    if (_loading || vehicles == null) {
      return _plainPage(const Center(child: CircularProgressIndicator()));
    }
    if (widget.id != null && _existing == null) {
      return _plainPage(const Center(child: Text('Reminder not found')));
    }
    if (vehicles.isEmpty) return _plainPage(const _NoVehicle());

    final vehicle =
        vehicles.where((v) => v.id == _vehicleId).firstOrNull ??
        ref.watch(currentVehicleProvider).value ??
        vehicles.first;
    final unit = Formatters.distanceUnitLabel(vehicle.distanceUnit);
    final lastOdo = ref.watch(lastOdometerProvider(vehicle.id)).value;
    final fmt = ref.watch(formattersProvider);
    final types = ref.watch(catalogProvider(_typeKind)).value ?? const [];
    final typeName = types.where((t) => t.id == _typeId).firstOrNull?.name;

    return ModuleFormScaffold(
      module: _module,
      onSave: _save,
      isDirty: () => _dirty,
      actions: [
        if (_existing != null)
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete),
            onPressed: _delete,
          ),
      ],
      children: [
        FieldRow(
          icon: vehicle.type.icon,
          child: PickerField(
            label: 'Vehicle',
            value: vehicle.name,
            onTap: () => _pickVehicle(vehicles),
          ),
        ),
        FieldRow(
          child: _Toggle<ReminderTarget>(
            value: _target,
            options: const {
              ReminderTarget.expense: 'EXPENSE',
              ReminderTarget.service: 'SERVICE',
            },
            onChanged: (t) {
              _touch();
              setState(() {
                if (t != _target) _typeId = null;
                _target = t;
              });
            },
          ),
        ),
        FieldRow(
          icon: _target == ReminderTarget.service
              ? Icons.build
              : Icons.receipt_long,
          child: PickerField(
            label: _target == ReminderTarget.service
                ? 'Type of service'
                : 'Type of expense',
            value: typeName,
            onTap: _pickType,
          ),
        ),
        FieldRow(
          child: _Toggle<bool>(
            value: _repeat,
            options: const {false: 'JUST ONE TIME', true: 'REPEAT EVERY'},
            onChanged: (v) {
              _touch();
              setState(() => _repeat = v);
            },
          ),
        ),
        ..._repeat
            ? _repeatTriggers(unit)
            : _oneTimeTriggers(
                unit,
                odometerHelper: lastOdo == null
                    ? null
                    : 'Last odometer: '
                          '${fmt.distance(lastOdo, vehicle.distanceUnit)}',
              ),
        FieldRow(
          icon: Icons.notes,
          child: TextField(
            controller: _notes,
            maxLines: null,
            decoration: const InputDecoration(labelText: 'Notes'),
            onChanged: (_) => _touch(),
          ),
        ),
      ],
    );
  }

  List<Widget> _oneTimeTriggers(String unit, {String? odometerHelper}) => [
    _TriggerRow(
      icon: Icons.speed,
      label: unit,
      helper: odometerHelper,
      checked: _byDistance,
      onChanged: (v) {
        _touch();
        setState(() => _byDistance = v);
      },
      child: TextField(
        controller: _dueOdometer,
        enabled: _byDistance,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Odometer'),
        onChanged: (_) => _touch(),
      ),
    ),
    _TriggerRow(
      icon: Icons.event,
      label: 'Date',
      checked: _byDate,
      onChanged: (v) {
        _touch();
        setState(() => _byDate = v);
      },
      child: PickerField(
        label: 'Date',
        value: _dueDate == null
            ? null
            : ref.read(formattersProvider).date(_dueDate!),
        onTap: _byDate
            ? _pickDate
            : () {
                _touch();
                setState(() => _byDate = true);
              },
      ),
    ),
  ];

  List<Widget> _repeatTriggers(String unit) => [
    _TriggerRow(
      icon: Icons.speed,
      label: unit,
      checked: _byDistance,
      onChanged: (v) {
        _touch();
        setState(() => _byDistance = v);
      },
      child: TextField(
        controller: _everyDistance,
        enabled: _byDistance,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: 'Every ($unit)'),
        onChanged: (_) => _touch(),
      ),
    ),
    _TriggerRow(
      icon: Icons.event_repeat,
      label: 'Time',
      checked: _byDate,
      onChanged: (v) {
        _touch();
        setState(() => _byDate = v);
      },
      child: TextField(
        controller: _everyAmount,
        enabled: _byDate,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Amount'),
        onChanged: (_) => _touch(),
      ),
    ),
    if (_byDate)
      FieldRow(
        child: _Toggle<PeriodUnit>(
          value: _everyUnit,
          options: const {
            PeriodUnit.day: 'DAYS',
            PeriodUnit.month: 'MONTHS',
            PeriodUnit.year: 'YEARS',
          },
          onChanged: (u) {
            _touch();
            setState(() => _everyUnit = u);
          },
        ),
      ),
  ];

  /// Purple page without a SAVE button (loading / not found / no vehicle).
  Widget _plainPage(Widget body) => Scaffold(
    appBar: AppBar(backgroundColor: _module.color, title: Text(_module.label)),
    body: body,
  );
}

/// Shown instead of the form when there are no vehicles yet.
class _NoVehicle extends StatelessWidget {
  const _NoVehicle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.two_wheeler, size: 96, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Add a vehicle before creating reminders',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: RecordModule.reminder.color,
                shape: const StadiumBorder(),
              ),
              onPressed: () => context.push('/vehicles/new'),
              child: const Text('ADD VEHICLE'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Drivvo-style segmented toggle (e.g. EXPENSE | SERVICE) in the module
/// color. Generic over the value type, like a TS `Toggle<T>` component.
class _Toggle<T> extends StatelessWidget {
  const _Toggle({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = RecordModule.reminder.color;
    return SegmentedButton<T>(
      showSelectedIcon: false,
      segments: [
        for (final e in options.entries)
          ButtonSegment(value: e.key, label: Text(e.value)),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: color,
        selectedForegroundColor: Colors.white,
        foregroundColor: color,
        side: BorderSide(color: color),
        textStyle: const TextStyle(fontSize: 12, letterSpacing: 0.5),
      ),
    );
  }
}

/// A trigger line: grey icon, checkbox + short label ("km", "Date"), then
/// the field, which is disabled while unchecked.
class _TriggerRow extends StatelessWidget {
  const _TriggerRow({
    required this.icon,
    required this.label,
    required this.checked,
    required this.onChanged,
    required this.child,
    this.helper,
  });

  final IconData icon;
  final String label;
  final bool checked;
  final ValueChanged<bool> onChanged;
  final Widget child;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return FieldRow(
      icon: icon,
      helper: helper,
      child: Row(
        children: [
          Checkbox(value: checked, onChanged: (v) => onChanged(v ?? false)),
          SizedBox(width: 40, child: Text(label)),
          Expanded(child: child),
        ],
      ),
    );
  }
}
