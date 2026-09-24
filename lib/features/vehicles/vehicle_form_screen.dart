import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import '../../core/providers.dart';
import '../../core/widgets/module_form_scaffold.dart';
import '../routes/record_form_parts.dart' show parseNumber;
import 'vehicle_labels.dart';
import 'vehicle_queries.dart';
import 'vehicle_widgets.dart';

/// Create / edit a vehicle (Drivvo's vehicle form).
class VehicleFormScreen extends ConsumerStatefulWidget {
  const VehicleFormScreen({super.key, this.id});

  /// Null = create a new vehicle.
  final String? id;

  @override
  ConsumerState<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends ConsumerState<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();

  VehicleType _type = VehicleType.car;
  int _tankCount = 1;
  FuelKind _tank1Kind = FuelKind.liquid;
  FuelKind _tank2Kind = FuelKind.gas;
  DistanceUnit _distanceUnit = DistanceUnit.km;
  bool _active = true;
  bool _moreOptions = false;

  final _name = TextEditingController();
  final _manufacturer = TextEditingController();
  final _model = TextEditingController();
  final _plate = TextEditingController();
  final _year = TextEditingController();
  final _tank1Capacity = TextEditingController();
  final _tank2Capacity = TextEditingController();
  final _vin = TextEditingController();
  final _registrationId = TextEditingController();
  final _purchasePrice = TextEditingController();
  final _salePrice = TextEditingController();
  final _notes = TextEditingController();

  /// True while an existing vehicle is being loaded (edit mode).
  late bool _loading = widget.id != null;
  bool _notFound = false;

  /// True once the user has changed something — drives the unsaved-changes
  /// back guard. Only flips once (further edits don't need another rebuild).
  bool _dirty = false;
  void _touch() {
    if (!_dirty) setState(() => _dirty = true);
  }

  List<TextEditingController> get _controllers => [
    _name,
    _manufacturer,
    _model,
    _plate,
    _year,
    _tank1Capacity,
    _tank2Capacity,
    _vin,
    _registrationId,
    _purchasePrice,
    _salePrice,
    _notes,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.id != null) _load(widget.id!);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  /// Edit mode: copy the stored vehicle into the form state.
  Future<void> _load(String id) async {
    final v = await ref.read(databaseProvider).getVehicle(id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (v == null) {
        _notFound = true;
        return;
      }
      String fmt(num? n) => n == null ? '' : _trimZeros(n);
      _type = v.type;
      _name.text = v.name;
      _manufacturer.text = v.manufacturer ?? '';
      _model.text = v.model ?? '';
      _plate.text = v.plate ?? '';
      _year.text = v.year?.toString() ?? '';
      _tankCount = v.tankCount;
      _tank1Kind = v.tank1Kind;
      _tank1Capacity.text = fmt(v.tank1Capacity);
      _tank2Kind = v.tank2Kind ?? FuelKind.gas;
      _tank2Capacity.text = fmt(v.tank2Capacity);
      _distanceUnit = v.distanceUnit;
      _vin.text = v.vin ?? '';
      _registrationId.text = v.registrationId ?? '';
      _purchasePrice.text = fmt(v.purchasePrice);
      _salePrice.text = fmt(v.salePrice);
      _active = v.active;
      _notes.text = v.notes ?? '';
      // Open the expander if any of its fields has data.
      _moreOptions = [
        _vin,
        _registrationId,
        _purchasePrice,
        _salePrice,
        _notes,
      ].any((c) => c.text.isNotEmpty);
    });
  }

  /// "45.0" -> "45", "12.5" -> "12.5".
  static String _trimZeros(num n) =>
      n == n.roundToDouble() ? n.toInt().toString() : n.toString();

  /// Empty text -> null so optional columns stay NULL in the database.
  static String? _text(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  /// Lenient number parsing shared with the record forms: accepts "1,5" as
  /// well as "1.5", and rejects blank text, garbage, NaN, Infinity and
  /// negative numbers — see [parseNumber].
  static double? _number(TextEditingController c) => parseNumber(c.text);

  /// The form as a drift "companion" (a partial row, like a Prisma
  /// `data: {...}` object).
  VehiclesCompanion _companion() {
    final twoTanks = _tankCount == 2;
    return VehiclesCompanion(
      name: Value(_name.text.trim()),
      type: Value(_type),
      manufacturer: Value(_text(_manufacturer)),
      model: Value(_text(_model)),
      plate: Value(_text(_plate)),
      year: Value(int.tryParse(_year.text.trim())),
      tankCount: Value(_tankCount),
      tank1Kind: Value(_tank1Kind),
      tank1Capacity: Value(_number(_tank1Capacity)),
      tank2Kind: Value(twoTanks ? _tank2Kind : null),
      tank2Capacity: Value(twoTanks ? _number(_tank2Capacity) : null),
      distanceUnit: Value(_distanceUnit),
      vin: Value(_text(_vin)),
      registrationId: Value(_text(_registrationId)),
      purchasePrice: Value(_number(_purchasePrice)),
      salePrice: Value(_number(_salePrice)),
      active: Value(_active),
      notes: Value(_text(_notes)),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final db = ref.read(databaseProvider);
    final id = widget.id;
    if (id == null) {
      final isFirst = await db.countVehicles() == 0;
      final newId = await db.insertVehicle(_companion());
      // The very first vehicle becomes the one shown in the main tabs.
      if (isFirst) await selectVehicle(ref, newId);
    } else {
      await db.updateVehicle(id, _companion());
    }
    _close();
  }

  Future<void> _delete() async {
    final db = ref.read(databaseProvider);
    // Count first so the dialog can warn what else goes with the vehicle
    // (soft-deleting the vehicle alone would leave its records as orphans).
    final recordCount = await db.countVehicleRecords(widget.id!);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete vehicle?'),
        content: Text(
          '"${_name.text}" and its $recordCount '
          '${recordCount == 1 ? 'record' : 'records'} will be deleted.',
        ),
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
    if (confirmed != true) return;
    await db.softDeleteVehicleAndRecords(widget.id!);
    _close();
  }

  /// Back to wherever we came from (or the vehicle list after a deep link).
  void _close() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/vehicles');
    }
  }

  /// Same radio-list pattern as [showChoiceDialog], but with narrower
  /// `insetPadding` (more width for the dialog) and ellipsized labels so
  /// "Motorcycle" doesn't wrap to "Motorcycl / e" on narrow phones.
  Future<void> _pickType() async {
    final t = await showDialog<VehicleType>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Type of vehicle'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        content: SingleChildScrollView(
          child: RadioGroup<VehicleType>(
            groupValue: _type,
            onChanged: (v) => Navigator.pop(context, v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in VehicleType.values)
                  RadioListTile<VehicleType>(
                    value: option,
                    secondary: Icon(option.icon),
                    title: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (t != null) {
      _touch();
      setState(() => _type = t);
    }
  }

  Future<void> _pickDistanceUnit() async {
    final u = await showChoiceDialog<DistanceUnit>(
      context,
      title: 'Distance unit',
      options: DistanceUnit.values,
      selected: _distanceUnit,
      label: (u) => u.label,
    );
    if (u != null) {
      _touch();
      setState(() => _distanceUnit = u);
    }
  }

  Widget _textField(
    TextEditingController c,
    String label, {
    IconData? icon,
    bool multiline = false,
    String? Function(String?)? validator,
    TextCapitalization caps = TextCapitalization.sentences,
    String? prefixText,
  }) {
    return FieldRow(
      icon: icon,
      child: TextFormField(
        controller: c,
        textCapitalization: caps,
        maxLines: multiline ? null : 1,
        validator: validator,
        decoration: InputDecoration(labelText: label, prefixText: prefixText),
        onChanged: (_) => _touch(),
      ),
    );
  }

  /// Fuel type + capacity for one tank.
  List<Widget> _tankFields({
    required int tank,
    required FuelKind kind,
    required ValueChanged<FuelKind> onKind,
    required TextEditingController capacity,
  }) {
    final unit = ref.watch(formattersProvider).volumeUnitLabel(kind);
    return [
      if (_tankCount == 2)
        Padding(
          padding: const EdgeInsets.only(left: 48, top: 8),
          child: Text(
            'TANK $tank',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      FieldRow(
        icon: Icons.local_gas_station,
        child: PickerField(
          label: 'Fuel type',
          value: kind.label,
          onTap: () async {
            final k = await showChoiceDialog<FuelKind>(
              context,
              title: 'Fuel type',
              options: FuelKind.values,
              selected: kind,
              label: (k) => k.label,
            );
            if (k != null) {
              _touch();
              setState(() => onKind(k));
            }
          },
        ),
      ),
      FieldRow(
        icon: Icons.propane_tank_outlined,
        child: TextFormField(
          controller: capacity,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Tank capacity',
            suffixText: unit,
          ),
          onChanged: (_) => _touch(),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.id != null;
    if (_loading || _notFound) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vehicle')),
        body: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : const Text('Vehicle not found'),
        ),
      );
    }

    final currency = ref.watch(settingsProvider).currencyCode;

    return UnsavedChangesGuard(
      isDirty: () => _dirty,
      child: TealFormScaffold(
        title: 'Vehicle',
        formKey: _formKey,
        onSave: _save,
        actions: [
          if (isEdit)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete),
              onPressed: _delete,
            ),
        ],
        children: [
          FieldRow(
            icon: _type.icon,
            child: PickerField(
              label: 'Type of vehicle',
              value: _type.label,
              onTap: _pickType,
            ),
          ),
          _textField(
            _name,
            'Name',
            icon: Icons.label_outline,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
          ),
          _textField(_manufacturer, 'Manufacturer', icon: Icons.factory),
          _textField(_model, 'Model', icon: Icons.directions_car_outlined),
          FieldRow(
            icon: Icons.pin_outlined,
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _plate,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'License plate',
                    ),
                    onChanged: (_) => _touch(),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 96,
                  child: TextFormField(
                    controller: _year,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Year'),
                    onChanged: (_) => _touch(),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 48, top: 12, bottom: 4),
            child: SegmentedToggle<int>(
              options: const [(1, 'ONE TANK'), (2, 'TWO TANKS')],
              selected: _tankCount,
              onChanged: (n) {
                _touch();
                setState(() => _tankCount = n);
              },
            ),
          ),
          ..._tankFields(
            tank: 1,
            kind: _tank1Kind,
            onKind: (k) => _tank1Kind = k,
            capacity: _tank1Capacity,
          ),
          if (_tankCount == 2)
            ..._tankFields(
              tank: 2,
              kind: _tank2Kind,
              onKind: (k) => _tank2Kind = k,
              capacity: _tank2Capacity,
            ),
          FieldRow(
            icon: Icons.straighten,
            child: PickerField(
              label: 'Distance unit',
              value: _distanceUnit.label,
              onTap: _pickDistanceUnit,
            ),
          ),
          FieldRow(
            icon: Icons.check_circle_outline,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: _active,
              onChanged: (v) {
                _touch();
                setState(() => _active = v);
              },
            ),
          ),
          if (!_moreOptions)
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _moreOptions = true),
                  icon: const Icon(Icons.add),
                  label: const Text('More options'),
                ),
              ),
            )
          else ...[
            _textField(
              _vin,
              'VIN',
              icon: Icons.qr_code,
              caps: TextCapitalization.characters,
            ),
            _textField(
              _registrationId,
              'Registration ID',
              icon: Icons.badge_outlined,
              caps: TextCapitalization.characters,
            ),
            FieldRow(
              icon: Icons.payments_outlined,
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _purchasePrice,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Purchase price',
                        prefixText: '$currency ',
                      ),
                      onChanged: (_) => _touch(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _salePrice,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Sale price',
                        prefixText: '$currency ',
                      ),
                      onChanged: (_) => _touch(),
                    ),
                  ),
                ],
              ),
            ),
            _textField(_notes, 'Notes', icon: Icons.notes, multiline: true),
          ],
        ],
      ),
    );
  }
}
