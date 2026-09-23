import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart' hide Route;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/providers.dart';
import '../../core/theme/record_module.dart';
import '../../core/widgets/module_form_scaffold.dart';
import '../readings/reading_queries.dart';
import '../routes/record_form_parts.dart';

/// Reading form — a quick odometer update (no cost).
class ReadingFormScreen extends ConsumerStatefulWidget {
  const ReadingFormScreen({super.key, this.id});

  /// Null = create a new reading; otherwise edit this one.
  final String? id;

  @override
  ConsumerState<ReadingFormScreen> createState() => _ReadingFormScreenState();
}

class _ReadingFormScreenState extends ConsumerState<ReadingFormScreen> {
  bool get _editing => widget.id != null;
  late bool _loading = _editing;

  String? _vehicleId;
  DateTime _date = _nowToMinute();
  final _odometer = TextEditingController();
  final _driver = TextEditingController();
  final _notes = TextEditingController();

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
      // Same vehicle as the main tabs; the listener handles late loading
      // and a first vehicle added from the "no vehicle" screen.
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
    final r = await ref.read(databaseProvider).getReading(widget.id!);
    if (!mounted) return;
    if (r == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _vehicleId = r.vehicleId;
      _date = r.date;
      _odometer.text = numberInput(r.odometer);
      _driver.text = r.driver ?? '';
      _notes.text = r.notes ?? '';
      _loading = false;
    });
  }

  @override
  void dispose() {
    _odometer.dispose();
    _driver.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _snack(String message) => showFormMessage(context, message);

  Future<void> _save() async {
    final vehicleId = _vehicleId;
    final odometer = parseNumber(_odometer.text);
    if (vehicleId == null) return _snack('Choose a vehicle');
    if (odometer == null) return _snack('Enter the odometer');

    await ref
        .read(databaseProvider)
        .saveReading(
          ReadingsCompanion(
            vehicleId: Value(vehicleId),
            date: Value(_date),
            odometer: Value(odometer),
            driver: Value(textOrNull(_driver)),
            notes: Value(textOrNull(_notes)),
          ),
          id: widget.id,
        );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Reading saved')));
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'reading')) return;
    await ref.read(databaseProvider).deleteReading(widget.id!);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const module = RecordModule.reading;
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
    final odometer = parseNumber(_odometer.text);
    // Only warn for new readings: when editing, "last" includes this one.
    final lower =
        !_editing && odometer != null && last != null && odometer < last;

    return ModuleFormScaffold(
      module: module,
      onSave: _save,
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
          onChanged: (id) => setState(() => _vehicleId = id),
        ),
        DateTimeRow(value: _date, onChanged: (d) => setState(() => _date = d)),
        FieldRow(
          icon: Icons.speed,
          helper: last == null
              ? null
              : 'Last odometer: ${fmt.distance(last, unit)}',
          child: TextField(
            controller: _odometer,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Odometer',
              helperText: lower ? 'Lower than the last odometer' : null,
              helperStyle: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        FieldRow(
          icon: Icons.badge,
          child: TextField(
            controller: _driver,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Driver'),
          ),
        ),
        const AttachFilePlaceholder(),
        FieldRow(
          icon: Icons.notes,
          child: TextField(
            controller: _notes,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
        ),
      ],
    );
  }
}
