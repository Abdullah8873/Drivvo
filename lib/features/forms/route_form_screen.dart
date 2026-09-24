import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
// drift's row class is also called `Route`, so hide Flutter's.
import 'package:flutter/material.dart' hide Route;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/format/formatters.dart';
import '../../core/providers.dart';
import '../../core/theme/record_module.dart';
import '../../core/widgets/module_form_scaffold.dart';
import '../routes/record_form_parts.dart';
import '../routes/route_math.dart';
import '../routes/route_queries.dart';

/// Route form (TRIP | FREIGHT). Leaving the final odometer empty saves an
/// OPEN route that the user finishes later by editing it.
class RouteFormScreen extends ConsumerStatefulWidget {
  const RouteFormScreen({super.key, this.id});

  /// Null = create a new route; otherwise edit this one.
  final String? id;

  @override
  ConsumerState<RouteFormScreen> createState() => _RouteFormScreenState();
}

class _RouteFormScreenState extends ConsumerState<RouteFormScreen> {
  bool get _editing => widget.id != null;
  late bool _loading = _editing;

  /// True once the user has changed something — drives the unsaved-changes
  /// back guard. Only flips once (further edits don't need another rebuild).
  bool _dirty = false;
  void _touch() {
    if (!_dirty) setState(() => _dirty = true);
  }

  String? _vehicleId;
  RouteMode _mode = RouteMode.trip;
  DateTime _start = _nowToMinute();
  late DateTime _end = _start.add(const Duration(hours: 1));

  /// Once the user picks an end date we stop auto-moving it with the start.
  bool _endTouched = false;
  String? _reasonId;
  String? _reasonName;

  final _origin = TextEditingController();
  final _startOdo = TextEditingController();
  final _destination = TextEditingController();
  final _endOdo = TextEditingController();
  final _valuePerDistance = TextEditingController();
  final _cargoType = TextEditingController();
  final _contractor = TextEditingController();
  final _cargoUnit = TextEditingController();
  final _cargoAmount = TextEditingController();
  final _cargoWeight = TextEditingController();
  final _cargoVolume = TextEditingController();
  final _freightValue = TextEditingController();
  final _installments = TextEditingController(text: '1');
  final _driver = TextEditingController();
  final _notes = TextEditingController();

  List<TextEditingController> get _controllers => [
    _origin,
    _startOdo,
    _destination,
    _endOdo,
    _valuePerDistance,
    _cargoType,
    _contractor,
    _cargoUnit,
    _cargoAmount,
    _cargoWeight,
    _cargoVolume,
    _freightValue,
    _installments,
    _driver,
    _notes,
  ];

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
      // Pick the vehicle shown in the main tabs. If vehicles are still
      // loading (or the user adds the first one), the listener catches up.
      _adoptVehicle(ref.read(vehiclesProvider).value);
      ref.listenManual(vehiclesProvider, (_, next) {
        if (_vehicleId == null) setState(() => _adoptVehicle(next.value));
      });
    }
  }

  void _adoptVehicle(List<Vehicle>? vehicles) {
    if (vehicles == null || vehicles.isEmpty) return;
    final selected = ref.read(settingsProvider).selectedVehicleId;
    final v =
        vehicles.where((v) => v.id == selected).firstOrNull ?? vehicles.first;
    _vehicleId = v.id;
    _prefillOdometer();
  }

  /// New routes start where the vehicle's last record left off.
  Future<void> _prefillOdometer() async {
    final vid = _vehicleId;
    if (vid == null) return;
    final last = await ref.read(databaseProvider).watchLastOdometer(vid).first;
    if (!mounted || last == null || _startOdo.text.isNotEmpty) return;
    setState(() => _startOdo.text = numberInput(last));
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final r = await db.getRoute(widget.id!);
    if (!mounted) return;
    if (r == null) {
      Navigator.of(context).pop();
      return;
    }
    final reason = r.reasonId == null
        ? null
        : await (db.select(
            db.catalogItems,
          )..where((c) => c.id.equals(r.reasonId!))).getSingleOrNull();
    if (!mounted) return;
    setState(() {
      _vehicleId = r.vehicleId;
      _mode = r.mode;
      _start = r.startDate;
      // Open route: suggest "now" as the end when finishing it.
      final now = _nowToMinute();
      _end =
          r.endDate ??
          (now.isAfter(r.startDate)
              ? now
              : r.startDate.add(const Duration(hours: 1)));
      _endTouched = true;
      _origin.text = r.origin ?? '';
      _startOdo.text = numberInput(r.startOdometer);
      _destination.text = r.destination ?? '';
      _endOdo.text = numberInput(r.endOdometer);
      _valuePerDistance.text = numberInput(r.valuePerDistance);
      _cargoType.text = r.cargoType ?? '';
      _contractor.text = r.contractor ?? '';
      _cargoUnit.text = r.cargoUnit ?? '';
      _cargoAmount.text = numberInput(r.cargoAmount);
      _cargoWeight.text = numberInput(r.cargoWeight);
      _cargoVolume.text = numberInput(r.cargoVolume);
      _freightValue.text = numberInput(r.freightValue);
      _installments.text = r.installments.toString();
      _driver.text = r.driver ?? '';
      _notes.text = r.notes ?? '';
      _reasonId = r.reasonId;
      _reasonName = reason?.name;
      _loading = false;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _tripTotal => RouteMath.tripTotal(
    startOdometer: parseNumber(_startOdo.text) ?? 0,
    endOdometer: parseNumber(_endOdo.text),
    valuePerDistance: parseNumber(_valuePerDistance.text),
  );

  void _snack(String message) => showFormMessage(context, message);

  /// Validates, then inserts/updates. Shows a snackbar and stays on the form
  /// when something is wrong (like a web form's inline validation).
  Future<void> _save() async {
    final vehicleId = _vehicleId;
    final startOdo = parseNumber(_startOdo.text);
    final endOdo = parseNumber(_endOdo.text);
    if (vehicleId == null) return _snack('Choose a vehicle');
    if (startOdo == null) return _snack('Enter the initial odometer');
    if (_endOdo.text.trim().isNotEmpty && endOdo == null) {
      return _snack('Final odometer is not a valid number');
    }
    if (endOdo != null && endOdo < startOdo) {
      return _snack('Final odometer must not be lower than the initial one');
    }
    final finished = endOdo != null;
    if (finished && _end.isBefore(_start)) {
      return _snack('End date must be after the start date');
    }

    final trip = _mode == RouteMode.trip;
    final valuePerDistance = parseNumber(_valuePerDistance.text);
    final data = RoutesCompanion(
      vehicleId: Value(vehicleId),
      mode: Value(_mode),
      origin: Value(textOrNull(_origin)),
      startDate: Value(_start),
      startOdometer: Value(startOdo),
      destination: Value(textOrNull(_destination)),
      endDate: Value(finished ? _end : null),
      endOdometer: Value(endOdo),
      // Store only the active mode's fields so reports never double count.
      valuePerDistance: Value(trip ? valuePerDistance : null),
      total: Value(trip ? _tripTotal : null),
      cargoType: Value(trip ? null : textOrNull(_cargoType)),
      contractor: Value(trip ? null : textOrNull(_contractor)),
      cargoUnit: Value(trip ? null : textOrNull(_cargoUnit)),
      cargoAmount: Value(trip ? null : parseNumber(_cargoAmount.text)),
      cargoWeight: Value(trip ? null : parseNumber(_cargoWeight.text)),
      cargoVolume: Value(trip ? null : parseNumber(_cargoVolume.text)),
      freightValue: Value(trip ? null : parseNumber(_freightValue.text)),
      installments: Value(
        trip ? 1 : math.max(1, int.tryParse(_installments.text.trim()) ?? 1),
      ),
      driver: Value(textOrNull(_driver)),
      reasonId: Value(_reasonId),
      notes: Value(textOrNull(_notes)),
    );
    await ref.read(databaseProvider).saveRoute(data, id: widget.id);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            finished ? 'Route saved' : 'Route saved — finish it later',
          ),
        ),
      );
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'route')) return;
    await ref.read(databaseProvider).deleteRoute(widget.id!);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _pickReason() async {
    final r = await pickReason(context, ref.read(databaseProvider));
    if (r != null) {
      _touch();
      setState(() {
        _reasonId = r.id;
        _reasonName = r.name;
      });
    }
  }

  void _setStart(DateTime d) => setState(() {
    _start = d;
    if (!_endTouched) _end = d.add(const Duration(hours: 1));
  });

  Widget _text(
    TextEditingController c,
    String label, {
    bool number = false,
    String? helper,
    String? suffixText,
    String? prefixText,
    ValueChanged<String>? onChanged,
  }) => TextField(
    controller: c,
    keyboardType: number
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    textCapitalization: number
        ? TextCapitalization.none
        : TextCapitalization.sentences,
    decoration: InputDecoration(
      labelText: label,
      helperText: helper,
      suffixText: suffixText,
      prefixText: prefixText,
    ),
    onChanged: (v) {
      _touch();
      onChanged?.call(v);
    },
  );

  @override
  Widget build(BuildContext context) {
    const module = RecordModule.route;
    final vehiclesAsync = ref.watch(vehiclesProvider);
    if (_loading || !vehiclesAsync.hasValue) {
      return const FormLoadingView(module: module);
    }
    final vehicles = vehiclesAsync.requireValue;
    if (!_editing && vehicles.isEmpty) {
      return const NoVehicleView(module: module);
    }

    final fmt = ref.watch(formattersProvider);
    final currency = ref.watch(settingsProvider).currencyCode;
    final vehicle = vehicles.where((v) => v.id == _vehicleId).firstOrNull;
    final unit = vehicle?.distanceUnit ?? DistanceUnit.km;
    final unitLabel = Formatters.distanceUnitLabel(unit);
    final last = _vehicleId == null
        ? null
        : ref.watch(lastOdometerProvider(_vehicleId!)).value;
    final total = _tripTotal;

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
            setState(() {
              _vehicleId = id;
              if (!_editing) _startOdo.clear();
            });
            if (!_editing) _prefillOdometer();
          },
        ),
        FieldRow(icon: Icons.trip_origin, child: _text(_origin, 'Origin')),
        DateTimeRow(
          value: _start,
          onChanged: (d) {
            _touch();
            _setStart(d);
          },
          dateLabel: 'Start date',
          timeLabel: 'Start time',
        ),
        FieldRow(
          icon: Icons.speed,
          helper: last == null
              ? null
              : 'Last odometer: ${fmt.distance(last, unit)}',
          child: _text(
            _startOdo,
            'Initial odometer',
            number: true,
            suffixText: unitLabel,
            onChanged: (_) => setState(() {}),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 48, top: 8, bottom: 8),
          child: Divider(height: 1),
        ),
        FieldRow(icon: Icons.flag, child: _text(_destination, 'Destination')),
        DateTimeRow(
          value: _end,
          onChanged: (d) {
            _touch();
            setState(() {
              _end = d;
              _endTouched = true;
            });
          },
          icon: Icons.event_available,
          dateLabel: 'End date',
          timeLabel: 'End time',
        ),
        FieldRow(
          icon: Icons.speed,
          child: _text(
            _endOdo,
            'Final odometer',
            number: true,
            suffixText: unitLabel,
            helper: 'Leave empty to finish the route later',
            onChanged: (_) => setState(() {}),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 48, top: 12, bottom: 8),
          child: SegmentedButton<RouteMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: RouteMode.trip, label: Text('TRIP')),
              ButtonSegment(value: RouteMode.freight, label: Text('FREIGHT')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) {
              _touch();
              setState(() => _mode = s.first);
            },
          ),
        ),
        if (_mode == RouteMode.trip)
          FieldRow(
            icon: Icons.attach_money,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _text(
                    _valuePerDistance,
                    'Value per $unitLabel',
                    number: true,
                    prefixText: '$currency ',
                    helper: '*optional',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InputDecorator(
                    isEmpty: total == null,
                    decoration: const InputDecoration(
                      labelText: 'Total',
                      enabled: false,
                    ),
                    child: Text(total == null ? '' : fmt.money(total)),
                  ),
                ),
              ],
            ),
          )
        else ...[
          FieldRow(
            icon: Icons.inventory_2,
            child: _text(_cargoType, 'Cargo type'),
          ),
          FieldRow(
            icon: Icons.business,
            child: _text(_contractor, 'Contractor'),
          ),
          FieldRow(icon: Icons.straighten, child: _text(_cargoUnit, 'Unit')),
          FieldRow(
            icon: Icons.scale,
            child: Row(
              children: [
                Expanded(child: _text(_cargoAmount, 'Amount', number: true)),
                const SizedBox(width: 12),
                Expanded(
                  child: _text(_cargoWeight, 'Weight (kg)', number: true),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _text(_cargoVolume, 'Volume (m³)', number: true),
                ),
              ],
            ),
          ),
          FieldRow(
            icon: Icons.payments,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _text(
                    _freightValue,
                    'Freight value',
                    number: true,
                    prefixText: '$currency ',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _installments,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Installments',
                    ),
                    onChanged: (_) => _touch(),
                  ),
                ),
              ],
            ),
          ),
        ],
        FieldRow(icon: Icons.badge, child: _text(_driver, 'Driver')),
        FieldRow(
          icon: Icons.work,
          child: PickerField(
            label: 'Reason',
            value: _reasonName,
            onTap: _pickReason,
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
