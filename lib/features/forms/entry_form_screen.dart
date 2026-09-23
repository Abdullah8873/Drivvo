import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import '../../core/format/formatters.dart';
import '../../core/providers.dart';
import '../../core/theme/record_module.dart';
import '../../core/widgets/module_form_scaffold.dart';
import '../../core/widgets/select_list_screen.dart';
import '../entries/catalog_picker.dart';
import '../entries/entry_queries.dart';
import '../entries/installments.dart';

/// Expense, Service and Income form — one screen, three flavours (colors,
/// labels and a few fields differ by [kind]).
///
/// Saving writes one `Entries` row per installment plus its `EntryItems`;
/// editing any installment rewrites the whole group.
class EntryFormScreen extends ConsumerStatefulWidget {
  const EntryFormScreen({super.key, required this.kind, this.id});

  final EntryKind kind;

  /// Null = create; otherwise edit this entry.
  final String? id;

  @override
  ConsumerState<EntryFormScreen> createState() => _EntryFormScreenState();
}

/// A catalog reference the form holds (id to save, name to show).
typedef _Ref = ({String id, String name});

/// One "type + amount" line (expense/service can have several).
class _TypeLine {
  _TypeLine(this.type, [double? amount])
    : amount = TextEditingController(text: _plain(amount));

  final _Ref type;
  final TextEditingController amount;
}

/// Number → text field value without a trailing ".0" ("1200", "12.5").
String _plain(double? v) {
  if (v == null) return '';
  return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

/// Lenient number parsing: accepts "1,5" as well as "1.5".
double? _parse(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

class _EntryFormScreenState extends ConsumerState<EntryFormScreen> {
  String? _vehicleId;
  DateTime _date = _nowToMinute();
  final _odometer = TextEditingController();
  final _title = TextEditingController();
  final _discount = TextEditingController();
  final _installments = TextEditingController(text: '1');
  final _value = TextEditingController(); // income only
  final _driver = TextEditingController();
  final _notes = TextEditingController();
  final _lines = <_TypeLine>[];
  _Ref? _incomeType;
  _Ref? _place;
  _Ref? _paymentMethod;
  _Ref? _reason;
  InstallmentInterval _interval = InstallmentInterval.monthly;

  /// Edit mode: true until the existing entry has loaded.
  late bool _loading = widget.id != null;
  bool _notFound = false;
  EditableEntry? _loaded;

  static DateTime _nowToMinute() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, n.hour, n.minute);
  }

  EntryKind get _kind => widget.kind;
  bool get _isIncome => _kind == EntryKind.income;
  RecordModule get _module => RecordModule.values.byName(_kind.name);

  String get _typeLabel => switch (_kind) {
    EntryKind.expense => 'Type of expense',
    EntryKind.service => 'Type of service',
    EntryKind.income => 'Type of income',
  };

  String get _typesTitle => switch (_kind) {
    EntryKind.expense => 'Types of expense',
    EntryKind.service => 'Types of service',
    EntryKind.income => 'Types of income',
  };

  CatalogKind get _typeCatalog => switch (_kind) {
    EntryKind.expense => CatalogKind.expenseType,
    EntryKind.service => CatalogKind.serviceType,
    EntryKind.income => CatalogKind.incomeType,
  };

  int get _installmentCount => int.tryParse(_installments.text.trim()) ?? 1;

  double get _linesTotal =>
      _lines.fold(0.0, (s, l) => s + (_parse(l.amount.text) ?? 0));

  double get _total => _isIncome
      ? (_parse(_value.text) ?? 0)
      : _linesTotal - (_parse(_discount.text) ?? 0);

  @override
  void initState() {
    super.initState();
    if (widget.id != null) _load(widget.id!);
  }

  @override
  void dispose() {
    for (final c in [
      _odometer,
      _title,
      _discount,
      _installments,
      _value,
      _driver,
      _notes,
    ]) {
      c.dispose();
    }
    for (final l in _lines) {
      l.amount.dispose();
    }
    super.dispose();
  }

  /// Edit mode: fill the fields from the saved installment group.
  Future<void> _load(String id) async {
    final loaded = await ref.read(databaseProvider).loadEditableEntry(id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (loaded == null) {
        _notFound = true;
        return;
      }
      _loaded = loaded;
      final d = loaded.draft;
      _Ref? named(String? id) =>
          id == null ? null : (id: id, name: loaded.names[id] ?? '');

      _vehicleId = d.vehicleId;
      _date = d.date;
      _odometer.text = _plain(d.odometer);
      _title.text = d.title ?? '';
      _discount.text = d.discount == 0 ? '' : _plain(d.discount);
      _installments.text = '${d.installments}';
      _interval = d.interval;
      _driver.text = d.driver ?? '';
      _notes.text = d.notes ?? '';
      _place = named(d.placeId);
      _paymentMethod = named(d.paymentMethodId);
      _reason = named(d.reasonId);
      if (_isIncome) {
        final item = d.items.firstOrNull;
        _incomeType = named(item?.typeId);
        _value.text = _plain(item?.amount);
      } else {
        _lines.addAll([
          for (final i in d.items)
            _TypeLine((id: i.typeId, name: i.typeName ?? ''), i.amount),
        ]);
      }
    });
  }

  // ---- Pickers --------------------------------------------------------------

  AppDatabase get _db => ref.read(databaseProvider);

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
    if (name == null || !mounted) return;
    setState(() => _vehicleId = vehicles.firstWhere((v) => v.name == name).id);
  }

  /// Multi-select types: keeps amounts of types still selected, adds new
  /// lines for newly selected ones, drops unselected ones.
  Future<void> _pickTypes() async {
    final picked = await pickCatalogItems(
      context,
      _db,
      kind: _typeCatalog,
      title: _typesTitle,
      multiSelect: true,
      selectedIds: {for (final l in _lines) l.type.id},
    );
    if (picked == null || !mounted) return;
    final pickedIds = {for (final p in picked) p.id};
    setState(() {
      for (final l in _lines.where((l) => !pickedIds.contains(l.type.id))) {
        _disposeLater(l.amount);
      }
      _lines.removeWhere((l) => !pickedIds.contains(l.type.id));
      final existing = {for (final l in _lines) l.type.id};
      _lines.addAll([
        for (final p in picked)
          if (!existing.contains(p.id)) _TypeLine((id: p.id, name: p.name)),
      ]);
    });
  }

  void _removeLine(_TypeLine line) {
    setState(() => _lines.remove(line));
    _disposeLater(line.amount);
  }

  /// The removed TextField still uses its controller until the next frame
  /// is built, so dispose it after that frame (like cleanup in a useEffect).
  void _disposeLater(TextEditingController c) =>
      WidgetsBinding.instance.addPostFrameCallback((_) => c.dispose());

  /// Single-select catalog picker; returns the new value, or [current] if
  /// the user backed out.
  Future<_Ref?> _pickOne(CatalogKind kind, String title, _Ref? current) async {
    final item = await pickCatalogItem(context, _db, kind: kind, title: title);
    return item == null ? current : (id: item.id, name: item.name);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (d == null || !mounted) return;
    setState(
      () => _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute),
    );
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (t == null || !mounted) return;
    setState(
      () => _date = DateTime(
        _date.year,
        _date.month,
        _date.day,
        t.hour,
        t.minute,
      ),
    );
  }

  // ---- Save / delete --------------------------------------------------------

  void _error(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? _textOrNull(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save(String vehicleId) async {
    final odometerText = _odometer.text.trim();
    final odometer = odometerText.isEmpty ? null : _parse(odometerText);
    if (odometerText.isNotEmpty && odometer == null) {
      return _error('Enter a valid odometer');
    }
    final count = int.tryParse(_installments.text.trim());
    if (count == null || count < 1 || count > 360) {
      return _error('Installments must be a number from 1 to 360');
    }

    final List<EntryItemDraft> items;
    var discount = 0.0;
    if (_isIncome) {
      final value = _parse(_value.text);
      if (value == null) return _error('Enter the value');
      if (_incomeType == null) return _error('Select the $_typeLabel');
      items = [EntryItemDraft(typeId: _incomeType!.id, amount: value)];
    } else {
      if (_lines.isEmpty) return _error('Select the $_typeLabel');
      final amounts = [for (final l in _lines) _parse(l.amount.text)];
      if (amounts.contains(null)) {
        return _error('Enter a value for each ${_typeLabel.toLowerCase()}');
      }
      items = [
        for (final (i, l) in _lines.indexed)
          EntryItemDraft(typeId: l.type.id, amount: amounts[i]!),
      ];
      discount = _parse(_discount.text) ?? 0;
      if (discount < 0 || discount > _linesTotal) {
        return _error('The discount can\'t be more than the total');
      }
    }

    final draft = EntryDraft(
      vehicleId: vehicleId,
      kind: _kind,
      date: _date,
      items: items,
      odometer: odometer,
      title: _isIncome ? null : _textOrNull(_title),
      placeId: _isIncome ? null : _place?.id,
      paymentMethodId: _isIncome ? null : _paymentMethod?.id,
      reasonId: _kind == EntryKind.expense ? _reason?.id : null,
      driver: _textOrNull(_driver),
      discount: discount,
      notes: _textOrNull(_notes),
      installments: count,
      interval: _interval,
    );
    await _db.saveEntry(draft, id: widget.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${_module.label} saved')));
    _close();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/history');
    }
  }

  Future<void> _confirmDelete() async {
    final count = _loaded?.draft.installments ?? 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${_module.label.toLowerCase()}?'),
        content: Text(
          count > 1
              ? 'All $count installments will be deleted.'
              : 'This record will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _db.deleteEntry(widget.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${_module.label} deleted')));
    _close();
  }

  // ---- UI -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehiclesProvider);
    final current = ref.watch(currentVehicleProvider).value;

    if (_loading || !vehicles.hasValue) return _plainPage(_spinner);
    if (_notFound) return _plainPage(const Text('Record not found'));
    final list = vehicles.value ?? const <Vehicle>[];
    if (list.isEmpty) return _noVehicle();

    final vehicle =
        list.where((v) => v.id == _vehicleId).firstOrNull ??
        current ??
        list.first;
    final fmt = ref.watch(formattersProvider);
    final lastOdo = ref.watch(lastOdometerProvider(vehicle.id)).value;

    return ModuleFormScaffold(
      module: _module,
      title: widget.id == null ? null : 'Edit ${_module.label.toLowerCase()}',
      onSave: () => _save(vehicle.id),
      actions: [
        if (widget.id != null)
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete),
            onPressed: _confirmDelete,
          ),
      ],
      children: [
        if ((_loaded?.draft.installments ?? 1) > 1) _installmentNote(),
        FieldRow(
          icon: Icons.directions_car,
          child: PickerField(
            label: 'Vehicle',
            value: vehicle.name,
            onTap: () => _pickVehicle(list),
          ),
        ),
        _dateTimeRow(fmt),
        FieldRow(
          icon: Icons.speed,
          helper: lastOdo == null
              ? null
              : 'Last odometer: ${fmt.distance(lastOdo, vehicle.distanceUnit)}',
          child: _numberField(
            _odometer,
            'Odometer (${Formatters.distanceUnitLabel(vehicle.distanceUnit)})',
          ),
        ),
        if (_isIncome) ..._incomeFields(fmt) else ..._costFields(fmt),
        FieldRow(
          icon: Icons.badge,
          child: TextField(
            controller: _driver,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Driver'),
          ),
        ),
        if (!_isIncome) ...[
          FieldRow(
            icon: Icons.paid,
            child: PickerField(
              label: 'Payment method',
              value: _paymentMethod?.name,
              onTap: () async {
                final p = await _pickOne(
                  CatalogKind.paymentMethod,
                  'Payment methods',
                  _paymentMethod,
                );
                if (mounted) setState(() => _paymentMethod = p);
              },
            ),
          ),
          // Drivvo's service form has no Reason field.
          if (_kind == EntryKind.expense)
            FieldRow(
              icon: Icons.work,
              child: PickerField(
                label: 'Reason',
                value: _reason?.name,
                onTap: () async {
                  final r = await _pickOne(
                    CatalogKind.reason,
                    'Reasons',
                    _reason,
                  );
                  if (mounted) setState(() => _reason = r);
                },
              ),
            ),
        ],
        _addButton(
          'Attach file',
          null, // TODO(attachments): enable once file storage exists.
        ),
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

  /// Expense / service: title, type lines + total, discount, installments,
  /// place.
  List<Widget> _costFields(Formatters fmt) => [
    FieldRow(
      icon: Icons.title,
      child: TextField(
        controller: _title,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Title'),
      ),
    ),
    if (_lines.isEmpty)
      FieldRow(
        icon: _module.icon,
        child: PickerField(label: _typeLabel, value: null, onTap: _pickTypes),
      )
    else ...[
      for (final (i, line) in _lines.indexed)
        FieldRow(
          key: ObjectKey(line),
          icon: i == 0 ? _module.icon : null,
          child: TextField(
            controller: line.amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: line.type.name,
              suffixIcon: IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => _removeLine(line),
              ),
            ),
          ),
        ),
      _addButton(_typeLabel, _pickTypes),
      FieldRow(
        icon: Icons.attach_money,
        child: InputDecorator(
          decoration: const InputDecoration(labelText: 'Total cost'),
          child: Text(
            fmt.money(_total),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ],
    FieldRow(
      icon: Icons.local_offer,
      child: Row(
        children: [
          Expanded(child: _numberField(_discount, 'Discount', rebuild: true)),
          const SizedBox(width: 16),
          Expanded(child: _installmentsField()),
        ],
      ),
    ),
    ..._intervalRow(fmt),
    FieldRow(
      icon: Icons.place,
      child: PickerField(
        label: 'Place',
        value: _place?.name,
        onTap: () async {
          final p = await _pickOne(CatalogKind.place, 'Places', _place);
          if (mounted) setState(() => _place = p);
        },
      ),
    ),
  ];

  /// Income: value + installments, then the (single) type of income.
  List<Widget> _incomeFields(Formatters fmt) => [
    FieldRow(
      icon: Icons.attach_money,
      child: Row(
        children: [
          Expanded(child: _numberField(_value, 'Value', rebuild: true)),
          const SizedBox(width: 16),
          Expanded(child: _installmentsField()),
        ],
      ),
    ),
    ..._intervalRow(fmt),
    FieldRow(
      icon: _module.icon,
      child: PickerField(
        label: _typeLabel,
        value: _incomeType?.name,
        onTap: () async {
          final t = await _pickOne(_typeCatalog, _typesTitle, _incomeType);
          if (mounted) setState(() => _incomeType = t);
        },
      ),
    ),
  ];

  Widget _installmentsField() => TextField(
    controller: _installments,
    keyboardType: TextInputType.number,
    onChanged: (_) => setState(() {}),
    decoration: const InputDecoration(labelText: 'Installments'),
  );

  /// Interval choice + "3 × PKR500" preview, only shown for N > 1.
  List<Widget> _intervalRow(Formatters fmt) {
    final n = _installmentCount;
    if (n <= 1) return const [];
    final first = splitAmount(_total, n).first;
    return [
      FieldRow(
        icon: Icons.date_range,
        helper: '$n × ${fmt.money(first)}',
        child: SegmentedButton<InstallmentInterval>(
          showSelectedIcon: false,
          segments: [
            for (final i in InstallmentInterval.values)
              ButtonSegment(value: i, label: Text(i.label)),
          ],
          selected: {_interval},
          onSelectionChanged: (s) => setState(() => _interval = s.first),
        ),
      ),
    ];
  }

  Widget _dateTimeRow(Formatters fmt) => FieldRow(
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
            value: fmt.time(_date),
            onTap: _pickTime,
          ),
        ),
      ],
    ),
  );

  /// Numeric text field; [rebuild] refreshes the live total while typing.
  Widget _numberField(
    TextEditingController c,
    String label, {
    bool rebuild = false,
  }) => TextField(
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: rebuild ? (_) => setState(() {}) : null,
    decoration: InputDecoration(labelText: label),
  );

  /// Drivvo-style "+ Something" text button aligned with the fields.
  Widget _addButton(String label, VoidCallback? onPressed) => Padding(
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

  Widget _installmentNote() {
    final loaded = _loaded!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 0, 8),
      child: Text(
        'Installment ${loaded.openedInstallmentNo} of '
        '${loaded.draft.installments} — changes apply to every installment.',
        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
      ),
    );
  }

  static const _spinner = CircularProgressIndicator();

  /// Module-colored page with just a centered body (loading / errors).
  Widget _plainPage(Widget body) => Scaffold(
    appBar: AppBar(backgroundColor: _module.color, title: Text(_module.label)),
    body: Center(child: body),
  );

  Widget _noVehicle() => _plainPage(
    Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_car, size: 56, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          Text(
            'Add a vehicle first to log a ${_module.label.toLowerCase()}.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _module.color),
            onPressed: () => context.push('/vehicles/new'),
            icon: const Icon(Icons.add),
            label: const Text('ADD VEHICLE'),
          ),
        ],
      ),
    ),
  );
}
