import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/calc/fuel_math.dart';
import '../../core/db/app_database.dart';
import '../../core/format/formatters.dart';
import '../../core/providers.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/record_module.dart';
import '../../core/widgets/module_form_scaffold.dart';
import '../refueling/catalog_picker.dart';
import '../refueling/refueling_queries.dart';

/// Refueling form — the reference pattern for every module form.
///
/// Create mode (`id == null`) starts on the current vehicle with its last
/// used fuel; edit mode loads the record and adds a delete action.
class RefuelingFormScreen extends ConsumerStatefulWidget {
  const RefuelingFormScreen({super.key, this.id});

  /// Null = create a new refueling; otherwise edit this one.
  final String? id;

  @override
  ConsumerState<RefuelingFormScreen> createState() =>
      _RefuelingFormScreenState();
}

class _RefuelingFormScreenState extends ConsumerState<RefuelingFormScreen> {
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();

  // The form loads its lookups once (like a fetch in useEffect) instead of
  // subscribing to live queries: nothing here needs to update while typing.
  List<Vehicle> _vehicles = const [];
  bool _vehiclesLoaded = false;
  String? _vehicleId;
  double? _lastOdometer;
  final _odometer = TextEditingController();
  final _lines = <_FuelLine>[_FuelLine()];

  /// True while line 1's fuel is our default (not picked by the user), so
  /// switching vehicle can replace it.
  bool _fuelIsDefault = true;
  bool _fullTank = true;
  bool _moreOptions = false;
  bool _missedPrevious = false;
  CatalogItem? _station;
  CatalogItem? _paymentMethod;
  CatalogItem? _reason;
  final _driver = TextEditingController();
  final _discount = TextEditingController();
  final _notes = TextEditingController();

  bool _loading = false;
  bool _notFound = false;
  bool _saving = false;

  bool get _isEdit => widget.id != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loading = true;
      _load(widget.id!).then((_) => _loadVehicles());
    } else {
      _loadVehicles();
    }
  }

  @override
  void dispose() {
    for (final c in [_odometer, _driver, _discount, _notes]) {
      c.dispose();
    }
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  // ---- Loading & defaults ---------------------------------------------------

  Future<void> _load(String id) async {
    final details = await ref.read(databaseProvider).getRefueling(id);
    if (!mounted) return;
    if (details == null) {
      setState(() {
        _loading = false;
        _notFound = true;
      });
      return;
    }
    final r = details.refueling;
    setState(() {
      _vehicleId = r.vehicleId;
      _date = r.date;
      _time = TimeOfDay.fromDateTime(r.date);
      _odometer.text = _plain(r.odometer, 1);
      for (final l in _lines) {
        l.dispose();
      }
      _lines
        ..clear()
        ..addAll([
          for (final l in details.lines)
            _FuelLine(fuel: l.fuel)
              ..price.text = _plain(l.line.pricePerUnit, 3)
              ..total.text = _plain(l.line.total, 2)
              ..volume.text = _plain(l.line.volume, 3)
              ..edited = [FuelField.price, FuelField.volume],
        ]);
      if (_lines.isEmpty) _lines.add(_FuelLine());
      _fuelIsDefault = false;
      _fullTank = r.fullTank;
      _missedPrevious = r.missedPrevious;
      _station = details.gasStation;
      _paymentMethod = details.paymentMethod;
      _reason = details.reason;
      _driver.text = r.driver ?? '';
      _discount.text = r.discount == null ? '' : _plain(r.discount!, 2);
      _notes.text = r.notes ?? '';
      _moreOptions =
          _lines.length > 1 ||
          r.missedPrevious ||
          r.discount != null ||
          r.paymentMethodId != null ||
          r.reasonId != null ||
          (r.notes?.isNotEmpty ?? false);
      _loading = false;
    });
  }

  /// Loads the vehicle list and selects the form's vehicle: the record's in
  /// edit mode, else the current vehicle (same rule as
  /// `currentVehicleProvider`).
  Future<void> _loadVehicles() async {
    final list = await ref.read(databaseProvider).watchVehicles().first;
    if (!mounted) return;
    setState(() {
      _vehicles = list;
      _vehiclesLoaded = true;
    });
    final selectedId = ref.read(settingsProvider).selectedVehicleId;
    final vehicle =
        list.where((v) => v.id == _vehicleId).firstOrNull ??
        list.where((v) => v.id == selectedId).firstOrNull ??
        list.firstOrNull;
    if (vehicle != null) await _useVehicle(vehicle);
  }

  /// Switches the form to [vehicle], loads its last odometer and, unless the
  /// user already chose a fuel, preselects the last fuel used on it (or its
  /// only matching fuel).
  Future<void> _useVehicle(Vehicle vehicle) async {
    setState(() => _vehicleId = vehicle.id);
    final db = ref.read(databaseProvider);
    final lastOdometer = await db.watchLastOdometer(vehicle.id).first;
    if (!mounted || _vehicleId != vehicle.id) return;
    setState(() => _lastOdometer = lastOdometer);

    if (!_fuelIsDefault) return;
    final fuels = await db.watchCatalog(CatalogKind.fuel).first;
    final lastId = await db.lastFuelIdFor(vehicle.id);
    var fuel = fuels.where((f) => f.id == lastId).firstOrNull;
    if (fuel == null) {
      final matching = _fuelsFor(vehicle, fuels);
      if (matching.length == 1) fuel = matching.single;
    }
    if (!mounted || !_fuelIsDefault || _vehicleId != vehicle.id) return;
    setState(() => _lines.first.fuel = fuel);
  }

  /// Fuels whose kind matches one of the vehicle's tanks (all fuels if none
  /// match, so the list is never empty).
  static List<CatalogItem> _fuelsFor(
    Vehicle? vehicle,
    List<CatalogItem> fuels,
  ) {
    if (vehicle == null) return fuels;
    final kinds = {
      vehicle.tank1Kind,
      if (vehicle.tankCount > 1 && vehicle.tank2Kind != null)
        vehicle.tank2Kind!,
    };
    final matching = fuels
        .where((f) => f.fuelKind == null || kinds.contains(f.fuelKind))
        .toList();
    return matching.isEmpty ? fuels : matching;
  }

  /// Which tank a fuel goes into: tank 2 only when it matches tank 2's kind.
  static int _tankFor(Vehicle vehicle, CatalogItem fuel) =>
      vehicle.tankCount > 1 &&
          fuel.fuelKind != vehicle.tank1Kind &&
          fuel.fuelKind == vehicle.tank2Kind
      ? 2
      : 1;

  // ---- Pickers ----------------------------------------------------------------

  Future<void> _pickVehicle(List<Vehicle> vehicles) async {
    final picked = await showDialog<Vehicle>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Vehicle'),
        children: [
          for (final v in vehicles)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, v),
              child: ListTile(
                leading: Icon(_vehicleIcon(v)),
                title: Text(v.name),
                subtitle: v.model == null ? null : Text(v.model!),
              ),
            ),
        ],
      ),
    );
    if (picked == null) return;
    await _useVehicle(picked);
  }

  Future<void> _addVehicle() async {
    await context.push('/vehicles/new');
    if (mounted) await _loadVehicles();
  }

  Future<void> _pickFuel(_FuelLine line, Vehicle? vehicle) async {
    final fuels = await ref
        .read(databaseProvider)
        .watchCatalog(CatalogKind.fuel)
        .first;
    if (!mounted) return;
    final fuel = await pickCatalogItem(
      context,
      ref,
      kind: CatalogKind.fuel,
      title: 'Fuel',
      items: _fuelsFor(vehicle, fuels),
      newFuelKind: vehicle?.tank1Kind ?? FuelKind.liquid,
    );
    if (fuel == null) return;
    setState(() {
      line.fuel = fuel;
      if (identical(line, _lines.first)) _fuelIsDefault = false;
    });
  }

  Future<CatalogItem?> _pickCatalog(CatalogKind kind, String title) =>
      pickCatalogItem(context, ref, kind: kind, title: title);

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  // ---- Save & delete ------------------------------------------------------------

  Future<void> _save(Vehicle? vehicle) async {
    if (_saving) return;
    final messenger = ScaffoldMessenger.of(context);
    void error(String message) =>
        messenger.showSnackBar(SnackBar(content: Text(message)));

    if (vehicle == null) return error('Add a vehicle first');
    final odometer = _parse(_odometer.text);
    if (odometer == null) return error('Enter the odometer');

    final lines = <FuelLineDraft>[];
    for (final l in _lines) {
      final total = _parse(l.total.text);
      final volume = _parse(l.volume.text);
      if (l.fuel == null) return error('Select the fuel');
      if (total == null || volume == null || volume <= 0) {
        return error('Enter the total cost and the ${_volumeWord()}');
      }
      lines.add(
        FuelLineDraft(
          fuelId: l.fuel!.id,
          pricePerUnit: _parse(l.price.text) ?? total / volume,
          total: total,
          volume: volume,
          tank: _tankFor(vehicle, l.fuel!),
        ),
      );
    }

    final db = ref.read(databaseProvider);
    final date = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );

    // Odometer going backwards is usually a typo — warn, but allow it.
    final previous = await db.previousRefueling(
      vehicle.id,
      date,
      excludeId: widget.id,
    );
    if (previous != null && odometer < previous.odometer) {
      if (!mounted) return;
      final fmt = ref.read(formattersProvider);
      final ok = await _confirm(
        title: 'Check the odometer',
        message:
            'The odometer is lower than the previous refueling '
            '(${fmt.distance(previous.odometer, vehicle.distanceUnit)} on '
            '${fmt.date(previous.date)}). Save anyway?',
        action: 'SAVE',
      );
      if (!ok) return;
    }

    setState(() => _saving = true);
    final draft = RefuelingDraft(
      vehicleId: vehicle.id,
      date: date,
      odometer: odometer,
      lines: lines,
      fullTank: _fullTank,
      missedPrevious: _missedPrevious,
      gasStationId: _station?.id,
      paymentMethodId: _paymentMethod?.id,
      reasonId: _reason?.id,
      driver: _text(_driver),
      discount: _parse(_discount.text),
      notes: _text(_notes),
    );
    try {
      await db.saveRefueling(draft, id: widget.id);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    _close();
    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Refueling saved')));
  }

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _confirm(
      title: 'Delete refueling',
      message: 'This refueling will be removed from your history.',
      action: 'DELETE',
    );
    if (!ok) return;
    await ref.read(databaseProvider).deleteRefueling(widget.id!);
    if (!mounted) return;
    _close();
    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Refueling deleted')));
  }

  void _close() => context.canPop() ? context.pop() : context.go('/history');

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  // ---- Helpers ------------------------------------------------------------------

  static double? _parse(String s) => double.tryParse(s.trim());

  static String? _text(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  /// "54682" instead of "54682.0", "293.03" instead of "293.030".
  static String _plain(double v, int maxDecimals) {
    final s = v.toStringAsFixed(maxDecimals);
    return s.contains('.')
        ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
        : s;
  }

  static IconData _vehicleIcon(Vehicle? v) => v?.type == VehicleType.motorcycle
      ? Icons.two_wheeler
      : Icons.directions_car;

  String _volumeWord() {
    final kind = _lines.first.fuel?.fuelKind ?? FuelKind.liquid;
    return _volumeLabel(ref.read(settingsProvider), kind).toLowerCase();
  }

  /// "Liters", "Gallons", "kg", "m³", "kWh".
  static String _volumeLabel(AppSettings s, FuelKind kind) {
    if (kind != FuelKind.liquid) return Formatters(s).volumeUnitLabel(kind);
    return s.volumeUnit == VolumeUnit.liter ? 'Liters' : 'Gallons';
  }

  // ---- UI -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    const module = RecordModule.refueling;
    if (_loading || _notFound) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: module.color,
          title: Text(module.label),
        ),
        body: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : const Text('This refueling no longer exists.'),
        ),
      );
    }

    final fmt = ref.watch(formattersProvider);
    final vehicles = _vehicles;
    final vehicle = vehicles.where((v) => v.id == _vehicleId).firstOrNull;
    final lastOdometer = _lastOdometer;

    return ModuleFormScaffold(
      module: module,
      onSave: () => _save(vehicle),
      actions: [
        if (_isEdit)
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete),
            onPressed: _delete,
          ),
      ],
      children: [
        if (_vehiclesLoaded && vehicles.isEmpty)
          _NoVehicleCard(onAdd: _addVehicle),
        FieldRow(
          icon: _vehicleIcon(vehicle),
          child: PickerField(
            label: 'Vehicle',
            value: vehicle?.name,
            onTap: () =>
                vehicles.isEmpty ? _addVehicle() : _pickVehicle(vehicles),
          ),
        ),
        FieldRow(
          icon: Icons.event,
          child: Row(
            children: [
              Expanded(
                child: PickerField(
                  label: 'Date',
                  value: fmt.date(_date),
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: PickerField(
                  label: 'Time',
                  value: _time.format(context),
                  onTap: _pickTime,
                ),
              ),
            ],
          ),
        ),
        FieldRow(
          icon: Icons.speed,
          helper: vehicle == null || lastOdometer == null
              ? null
              : 'Last odometer: '
                    '${fmt.distance(lastOdometer, vehicle.distanceUnit)}',
          child: TextField(
            controller: _odometer,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Odometer',
              suffixText: Formatters.distanceUnitLabel(
                vehicle?.distanceUnit ?? DistanceUnit.km,
              ),
            ),
          ),
        ),
        for (final (i, line) in _lines.indexed)
          _FuelLineFields(
            key: ObjectKey(line),
            line: line,
            unitLabel: fmt.volumeUnitLabel(
              line.fuel?.fuelKind ?? FuelKind.liquid,
            ),
            volumeLabel: _volumeLabel(
              fmt.settings,
              line.fuel?.fuelKind ?? FuelKind.liquid,
            ),
            onPickFuel: () => _pickFuel(line, vehicle),
            onRemove: i == 0
                ? null
                : () {
                    setState(() => _lines.remove(line));
                    line.dispose();
                  },
          ),
        FieldRow(
          icon: Icons.local_gas_station_outlined,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Are you filling up the tank?'),
            value: _fullTank,
            onChanged: (v) => setState(() => _fullTank = v),
          ),
        ),
        if (_moreOptions)
          _AddButton(
            label: 'Fuel',
            onPressed: () => setState(() => _lines.add(_FuelLine())),
          ),
        FieldRow(
          icon: Icons.place,
          child: PickerField(
            label: 'Gas station',
            value: _station?.name,
            onTap: () async {
              final s = await _pickCatalog(
                CatalogKind.gasStation,
                'Gas stations',
              );
              if (s != null) setState(() => _station = s);
            },
          ),
        ),
        FieldRow(
          icon: Icons.badge,
          child: TextField(
            controller: _driver,
            decoration: const InputDecoration(labelText: 'Driver'),
          ),
        ),
        if (!_moreOptions)
          _AddButton(
            label: 'More options',
            onPressed: () => setState(() => _moreOptions = true),
          )
        else ...[
          FieldRow(
            icon: Icons.paid,
            child: PickerField(
              label: 'Payment method',
              value: _paymentMethod?.name,
              onTap: () async {
                final p = await _pickCatalog(
                  CatalogKind.paymentMethod,
                  'Payment methods',
                );
                if (p != null) setState(() => _paymentMethod = p);
              },
            ),
          ),
          FieldRow(
            icon: Icons.local_offer,
            child: TextField(
              controller: _discount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Discount'),
            ),
          ),
          FieldRow(
            icon: Icons.work,
            child: PickerField(
              label: 'Reason',
              value: _reason?.name,
              onTap: () async {
                final r = await _pickCatalog(CatalogKind.reason, 'Reasons');
                if (r != null) setState(() => _reason = r);
              },
            ),
          ),
          FieldRow(
            icon: Icons.error,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Missed previous refueling?'),
              value: _missedPrevious,
              onChanged: (v) => setState(() => _missedPrevious = v),
            ),
          ),
          // TODO(milestone-6): attachments via Supabase Storage.
          _AddButton(label: 'Attach file', onPressed: () {}),
          FieldRow(
            icon: Icons.notes,
            child: TextField(
              controller: _notes,
              maxLines: null,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
          ),
        ],
      ],
    );
  }
}

/// Shown above the form when there are no vehicles yet: refuelings need one.
class _NoVehicleCard extends StatelessWidget {
  const _NoVehicleCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 4, 0, 8),
      child: ListTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('Add a vehicle to save refuelings'),
        trailing: TextButton(onPressed: onAdd, child: const Text('ADD')),
      ),
    );
  }
}

/// Left-aligned "+ Label" text button used for optional form sections.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 40),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.add),
          label: Text(label),
        ),
      ),
    );
  }
}

/// State for one fuel line (a refueling can contain several fuels).
class _FuelLine {
  _FuelLine({this.fuel});

  CatalogItem? fuel;
  final price = TextEditingController();
  final total = TextEditingController();
  final volume = TextEditingController();
  List<FuelField> edited = [];

  void dispose() {
    price.dispose();
    total.dispose();
    volume.dispose();
  }
}

class _FuelLineFields extends StatelessWidget {
  const _FuelLineFields({
    super.key,
    required this.line,
    required this.unitLabel,
    required this.volumeLabel,
    required this.onPickFuel,
    this.onRemove,
  });

  final _FuelLine line;

  /// Unit for the price label ("L" → "Price / L").
  final String unitLabel;

  /// Label of the volume field ("Liters", "kWh"…).
  final String volumeLabel;
  final VoidCallback onPickFuel;
  final VoidCallback? onRemove;

  // "Enter any two, the third is calculated" (see FuelMath).
  void _onChanged(FuelField field) {
    line.edited = FuelMath.touch(line.edited, field);
    final result = FuelMath.solve(
      edited: line.edited,
      price: double.tryParse(line.price.text),
      total: double.tryParse(line.total.text),
      volume: double.tryParse(line.volume.text),
    );
    if (result == null) return;
    final (controller, digits) = switch (result.field) {
      FuelField.price => (line.price, 3),
      FuelField.total => (line.total, 2),
      FuelField.volume => (line.volume, 3),
    };
    controller.text = result.value.toStringAsFixed(digits);
  }

  Widget _number(String label, TextEditingController c, FuelField f) =>
      Expanded(
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label),
          onChanged: (_) => _onChanged(f),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FieldRow(
          icon: Icons.local_gas_station,
          child: Row(
            children: [
              Expanded(
                child: PickerField(
                  label: 'Fuel',
                  value: line.fuel?.name,
                  onTap: onPickFuel,
                ),
              ),
              if (onRemove != null)
                IconButton(icon: const Icon(Icons.close), onPressed: onRemove),
            ],
          ),
        ),
        FieldRow(
          icon: Icons.payments_outlined,
          child: Row(
            children: [
              _number('Price / $unitLabel', line.price, FuelField.price),
              const SizedBox(width: 12),
              _number('Total cost', line.total, FuelField.total),
              const SizedBox(width: 12),
              _number(volumeLabel, line.volume, FuelField.volume),
            ],
          ),
        ),
      ],
    );
  }
}
