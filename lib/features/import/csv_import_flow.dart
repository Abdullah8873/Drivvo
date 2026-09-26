import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/providers.dart';
import 'csv_import.dart';
import 'csv_import_service.dart';

const _service = CsvImportService();

/// Export screen → "Import CSV": pick a MotoLog CSV (or the .zip of
/// several) → preview what would be added → import → SnackBar. Works with
/// bytes only, so the same flow runs on the web (like reading a
/// `<input type="file">` with `FileReader`).
Future<void> runCsvImport(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final picked = await FilePicker.pickFile(
    dialogTitle: 'Select a MotoLog CSV or ZIP export',
    type: FileType.custom,
    allowedExtensions: ['csv', 'zip'],
  );
  if (picked == null || !context.mounted) return;

  final db = ref.read(databaseProvider);
  final currentVehicleId = ref.read(currentVehicleProvider).value?.id;
  final Uint8List bytes;
  try {
    bytes = await picked.readAsBytes();
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Could not read file: $e')));
    return;
  }
  if (!context.mounted) return;

  final batch = await showDialog<CsvImportBatch>(
    context: context,
    builder: (_) => CsvImportPreviewDialog(
      db: db,
      bytes: bytes,
      fileName: picked.name,
      currentVehicleId: currentVehicleId,
    ),
  );
  if (batch == null) return;

  try {
    final result = await _service.run(
      db,
      batch,
      currentVehicleId: currentVehicleId,
    );
    messenger.showSnackBar(SnackBar(content: Text(result.message)));
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Import failed, nothing was saved: $e')),
    );
  }
}

/// The preview step: what the picked file would add, what is skipped and
/// why. Pops with the batch to import, or null on cancel. When the file is
/// a lone Expense/Service/Income table the user picks which it is here.
class CsvImportPreviewDialog extends StatefulWidget {
  const CsvImportPreviewDialog({
    super.key,
    required this.db,
    required this.bytes,
    required this.fileName,
    required this.currentVehicleId,
  });

  final AppDatabase db;
  final List<int> bytes;
  final String fileName;
  final String? currentVehicleId;

  @override
  State<CsvImportPreviewDialog> createState() => _CsvImportPreviewDialogState();
}

class _CsvImportPreviewDialogState extends State<CsvImportPreviewDialog> {
  static const _maxIssuesShown = 50;

  EntryKind? _entryKind;
  bool _askEntryKind = false;
  CsvImportPreview? _preview;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final batch = parseImportFile(
        widget.bytes,
        fileName: widget.fileName,
        entryKind: _entryKind,
      );
      if (batch.needsEntryKind) _askEntryKind = true;
      final preview = await _service.preview(
        widget.db,
        batch,
        currentVehicleId: widget.currentVehicleId,
      );
      if (mounted) setState(() => _preview = preview);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final theme = Theme.of(context);
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);

    Widget content;
    if (_error != null) {
      content = Text('Could not read the file: $_error');
    } else if (preview == null) {
      content = const SizedBox(
        height: 64,
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      final issues = preview.issues;
      content = SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.fileName, style: muted),
            if (_askEntryKind) ...[
              const SizedBox(height: 12),
              const Text('These rows are:'),
              const SizedBox(height: 4),
              SegmentedButton<EntryKind>(
                segments: const [
                  ButtonSegment(
                    value: EntryKind.expense,
                    label: Text('Expense'),
                  ),
                  ButtonSegment(
                    value: EntryKind.service,
                    label: Text('Service'),
                  ),
                  ButtonSegment(value: EntryKind.income, label: Text('Income')),
                ],
                selected: {_entryKind ?? preview.batch.entryKindUsed},
                showSelectedIcon: false,
                onSelectionChanged: (s) {
                  setState(() {
                    _entryKind = s.single;
                    _preview = null;
                  });
                  _load();
                },
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Adds ${preview.countsLabel}.',
              style: theme.textTheme.titleSmall,
            ),
            if (preview.duplicateCount > 0)
              _line(
                '${preview.duplicateCount} already on this device — '
                'skipped as duplicates.',
              ),
            for (final note in preview.vehicleNotes) _line(note),
            if (preview.newCatalogItems.isNotEmpty)
              _line(
                'New catalog items: ${preview.newCatalogItems.join(', ')}.',
              ),
            for (final notice in preview.batch.notices) _line(notice),
            if (issues.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '${issues.length} problem${issues.length == 1 ? '' : 's'} — '
                'these rows are left out:',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              for (final issue in issues.take(_maxIssuesShown))
                _line(issue.toString()),
              if (issues.length > _maxIssuesShown)
                _line('…and ${issues.length - _maxIssuesShown} more.'),
            ],
          ],
        ),
      );
    }

    return AlertDialog(
      title: const Text('Import CSV'),
      content: SizedBox(width: 480, child: content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: preview != null && preview.newCount > 0
              ? () => Navigator.pop(context, preview.batch)
              : null,
          child: const Text('IMPORT'),
        ),
      ],
    );
  }

  Widget _line(String text) =>
      Padding(padding: const EdgeInsets.only(top: 6), child: Text(text));
}
