import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/backup/backup_format.dart';
import '../../core/backup/backup_service.dart';
import '../../core/files/file_sharer.dart';
import '../../core/providers.dart';
import '../../core/sharing/active_account.dart';
import '../../core/theme/app_theme.dart';

/// Settings → "Backup & restore": one-tap local backup file (share/save
/// anywhere) and restore-from-file, so a lost phone or a botched migration
/// can never lose data — the offline safety net for the app's data, next to
/// the (separate) Export screen.
class BackupRestoreSection extends ConsumerStatefulWidget {
  const BackupRestoreSection({super.key});

  @override
  ConsumerState<BackupRestoreSection> createState() =>
      _BackupRestoreSectionState();
}

class _BackupRestoreSectionState extends ConsumerState<BackupRestoreSection> {
  static const _service = BackupService();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(72, 16, 16, 4),
          child: Text(
            'BACKUP & RESTORE',
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
        ListTile(
          leading: Icon(
            Icons.save_alt,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          title: const Text('Create backup file'),
          subtitle: const Text(
            'Save every vehicle and record to a file you can keep anywhere',
          ),
          enabled: !_busy,
          onTap: _createBackup,
        ),
        // Restoring would overwrite (and upload into) someone else's
        // account: only in the user's own data.
        if (ref.watch(currentAccessProvider).isOwner)
          ListTile(
            leading: Icon(
              Icons.settings_backup_restore,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            title: const Text('Restore from backup'),
            subtitle: const Text(
              'Replace all data on this device with a backup file',
            ),
            enabled: !_busy,
            onTap: _restoreBackup,
          ),
      ],
    );
  }

  Future<void> _createBackup() async {
    setState(() => _busy = true);
    try {
      final db = ref.read(databaseProvider);
      final bytes = await _service.createBackupBytes(db);
      final sharer = ref.read(fileSharerProvider);
      await sharer.shareBytes(
        filename: _service.backupFilename(),
        bytes: bytes,
        mimeType: 'application/json',
      );
    } catch (e) {
      _showMessage('Could not create the backup: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup() async {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Select a MotoLog backup file',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (picked == null) return;

    setState(() => _busy = true);
    try {
      final bytes = await picked.readAsBytes();
      final db = ref.read(databaseProvider);
      final Map<String, dynamic> json;
      try {
        json = _service.parseAndValidate(bytes, db.schemaVersion);
      } on BackupFormatException catch (e) {
        _showMessage(e.message);
        return;
      }

      final summary = _service.summarize(json);
      if (!mounted) return;
      final confirmed = await _confirmRestore(context, summary);
      if (confirmed != true) return;

      await _service.restore(db, json);
      // The restore writes `settings_entries` directly (outside
      // `SettingsNotifier.update`), so the cached provider state needs an
      // explicit reload to pick up the restored settings.
      await ref.read(settingsProvider.notifier).reload();
      _showMessage('Backup restored.');
    } catch (e) {
      _showMessage('Could not restore the backup: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirmRestore(BuildContext context, BackupSummary summary) {
    final date = DateFormat('dd MMM yyyy, HH:mm').format(summary.exportedAt);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore backup?'),
        content: Text(
          'This replaces all MotoLog data on this device with the backup '
          'from $date (${summary.vehicleCount} vehicles, '
          '${summary.recordCount} records). Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('RESTORE'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
