import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/app_database.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/record_module.dart';
import 'export_models.dart';
import 'export_service.dart';

/// History app bar's ⬇ action → this screen: pick what to export (vehicle
/// scope, period, record types, format) and share the resulting file —
/// like a settings form whose submit produces a downloadable file instead
/// of saving to the database.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  bool _allVehicles = false;
  ExportPeriod? _period; // null = All time
  final Set<RecordModule> _modules = {...exportableModules};
  ExportFormat _format = ExportFormat.csv;
  bool _exporting = false;

  static final _dateFmt = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehiclesProvider).value ?? const [];
    final currentVehicle = ref.watch(currentVehicleProvider).value;

    final canExport =
        !_exporting && _modules.isNotEmpty && vehicles.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Export')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const _SectionLabel('Vehicle'),
          RadioGroup<bool>(
            groupValue: _allVehicles,
            onChanged: (v) => setState(() => _allVehicles = v ?? false),
            child: Column(
              children: [
                RadioListTile<bool>(
                  value: false,
                  contentPadding: EdgeInsets.zero,
                  title: Text(currentVehicle?.name ?? 'Current vehicle'),
                ),
                RadioListTile<bool>(
                  value: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('All vehicles'),
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          const _SectionLabel('Period'),
          RadioGroup<bool>(
            groupValue: _period != null,
            onChanged: (custom) async {
              if (custom != true) {
                setState(() => _period = null);
                return;
              }
              final picked = await _pickRange(context);
              if (picked != null) setState(() => _period = picked);
            },
            child: Column(
              children: [
                RadioListTile<bool>(
                  value: false,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('All time'),
                ),
                RadioListTile<bool>(
                  value: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _period == null
                        ? 'Custom range'
                        : '${_dateFmt.format(_period!.from)} – '
                              '${_dateFmt.format(_period!.to)}',
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          const _SectionLabel('Record types'),
          for (final module in exportableModules)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _modules.contains(module),
              title: Text(module.label),
              secondary: Icon(module.icon, color: module.color),
              onChanged: (checked) => setState(() {
                checked == true
                    ? _modules.add(module)
                    : _modules.remove(module);
              }),
            ),
          const Divider(height: 24),
          const _SectionLabel('Format'),
          RadioGroup<ExportFormat>(
            groupValue: _format,
            onChanged: (v) => setState(() => _format = v ?? _format),
            child: Column(
              children: [
                for (final format in ExportFormat.values)
                  RadioListTile<ExportFormat>(
                    value: format,
                    contentPadding: EdgeInsets.zero,
                    title: Text(format.label),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
            onPressed: canExport ? () => _export(vehicles, currentVehicle) : null,
            child: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Text('EXPORT', style: TextStyle(letterSpacing: 1)),
          ),
        ],
      ),
    );
  }

  Future<ExportPeriod?> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 15),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _period == null
          ? null
          : DateTimeRange(start: _period!.from, end: _period!.to),
    );
    if (range == null) return null;
    return ExportPeriod(from: range.start, to: range.end);
  }

  Future<void> _export(List<Vehicle> vehicles, Vehicle? currentVehicle) async {
    final vehicleIds = _allVehicles
        ? [for (final v in vehicles) v.id]
        : [if (currentVehicle != null) currentVehicle.id];
    if (vehicleIds.isEmpty) return;

    final options = ExportOptions(
      vehicleIds: vehicleIds,
      vehicleLabel: _allVehicles
          ? 'All vehicles'
          : (currentVehicle?.name ?? 'Vehicle'),
      period: _period,
      modules: _modules,
      format: _format,
    );

    setState(() => _exporting = true);
    try {
      final db = ref.read(databaseProvider);
      final currencyCode = ref.read(settingsProvider).currencyCode;
      await ref
          .read(exportServiceProvider)
          .export(db, options, currencyCode);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
