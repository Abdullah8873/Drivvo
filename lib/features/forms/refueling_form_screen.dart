import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/calc/fuel_math.dart';
import '../../core/db/seed_data.dart';
import '../../core/theme/record_module.dart';
import '../../core/widgets/module_form_scaffold.dart';
import '../../core/widgets/select_list_screen.dart';

/// Refueling form — the reference pattern for every module form.
/// UI only for now; milestone 2 wires it to the local database.
class RefuelingFormScreen extends StatefulWidget {
  const RefuelingFormScreen({super.key, this.id});

  /// Null = create a new refueling; otherwise edit this one.
  final String? id;

  @override
  State<RefuelingFormScreen> createState() => _RefuelingFormScreenState();
}

class _RefuelingFormScreenState extends State<RefuelingFormScreen> {
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  final _odometer = TextEditingController();
  final _lines = <_FuelLine>[_FuelLine(fuel: 'Petrol')];
  bool _fullTank = true;
  bool _moreOptions = false;
  bool _missedPrevious = false;
  String? _station;
  String? _paymentMethod;
  String? _reason;
  final _driver = TextEditingController();
  final _discount = TextEditingController();
  final _notes = TextEditingController();

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

  Future<String?> _pick(String title, List<String> items) async {
    final result = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => SelectListScreen(title: title, items: items),
      ),
    );
    return result?.firstOrNull;
  }

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

  void _save() {
    final hasOdometer = double.tryParse(_odometer.text) != null;
    final hasTotal = _lines.every((l) => double.tryParse(l.total.text) != null);
    if (!hasOdometer || !hasTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the odometer and the total cost')),
      );
      return;
    }
    // TODO(milestone-2): persist to the local database.
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Refueling saved (demo — no database yet)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final module = RecordModule.refueling;
    return ModuleFormScaffold(
      module: module,
      onSave: _save,
      children: [
        const FieldRow(
          icon: Icons.two_wheeler,
          child: TextField(
            enabled: false,
            decoration: InputDecoration(labelText: 'Vehicle'),
            controller: null,
          ),
        ),
        FieldRow(
          icon: Icons.event,
          child: Row(
            children: [
              Expanded(
                child: PickerField(
                  label: 'Date',
                  value: DateFormat('yyyy-MM-dd').format(_date),
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
          // TODO(milestone-2): real last odometer from the database.
          helper: 'Last odometer: —',
          child: TextField(
            controller: _odometer,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Odometer'),
          ),
        ),
        for (final (i, line) in _lines.indexed)
          _FuelLineFields(
            key: ObjectKey(line),
            line: line,
            onPickFuel: () async {
              final f = await _pick('Fuel', SeedData.fuels);
              if (f != null) setState(() => line.fuel = f);
            },
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
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _lines.add(_FuelLine())),
                icon: const Icon(Icons.add),
                label: const Text('Fuel'),
              ),
            ),
          ),
        FieldRow(
          icon: Icons.place,
          child: PickerField(
            label: 'Gas station',
            value: _station,
            onTap: () async {
              final s = await _pick('Gas stations', const []);
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
          FieldRow(
            icon: Icons.paid,
            child: PickerField(
              label: 'Payment method',
              value: _paymentMethod,
              onTap: () async {
                final p = await _pick(
                  'Payment methods',
                  SeedData.paymentMethods,
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
              value: _reason,
              onTap: () async {
                final r = await _pick('Reasons', SeedData.reasons);
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
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                // TODO(milestone-6): attachments via Supabase Storage.
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('Attach file'),
              ),
            ),
          ),
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

/// State for one fuel line (a refueling can contain several fuels).
class _FuelLine {
  _FuelLine({this.fuel});

  String? fuel;
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
    required this.onPickFuel,
    this.onRemove,
  });

  final _FuelLine line;
  final VoidCallback onPickFuel;
  final VoidCallback? onRemove;

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
                  value: line.fuel,
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
              _number('Price / L', line.price, FuelField.price),
              const SizedBox(width: 12),
              _number('Total cost', line.total, FuelField.total),
              const SizedBox(width: 12),
              _number('Liters', line.volume, FuelField.volume),
            ],
          ),
        ),
      ],
    );
  }
}
