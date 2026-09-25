import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cloud/auth_state.dart';
import '../../core/providers.dart';
import '../../core/theme/record_module.dart';
import 'attachment_queries.dart';

/// Live attachment usage (all vehicles).
final storageUsageProvider = StreamProvider<StorageUsage>(
  (ref) => ref.watch(databaseProvider).watchStorageUsage(),
);

/// More → Storage: how much space attachments take, in total and per
/// module (colored bars proportional to each module's share), plus how many
/// files still wait for upload when signed in.
class StorageScreen extends ConsumerWidget {
  const StorageScreen({super.key});

  /// Every module that can carry attachments, in the order listed.
  static const _modules = [
    RecordModule.refueling,
    RecordModule.expense,
    RecordModule.service,
    RecordModule.income,
    RecordModule.route,
    RecordModule.reading,
    RecordModule.checklist,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(storageUsageProvider);
    final signedIn = ref.watch(authUserIdProvider).value != null;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Storage')),
      body: usage.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (u) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.attach_file, size: 36, color: muted),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatBytes(u.bytes),
                            key: const Key('storage-total-size'),
                            style: theme.textTheme.headlineSmall,
                          ),
                          Text(
                            '${u.count} ${u.count == 1 ? 'file' : 'files'}',
                            key: const Key('storage-total-count'),
                            style: TextStyle(color: muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (signedIn && u.notUploaded > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 18, color: muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${u.notUploaded} '
                        '${u.notUploaded == 1 ? 'file' : 'files'} '
                        'not uploaded yet',
                        style: TextStyle(color: muted),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            if (u.count == 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'No attachments yet. Attach photos or PDFs from any '
                  'record form.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted),
                ),
              ),
            for (final module in _modules)
              if (u.byModule.where((m) => m.module == module).firstOrNull ??
                      ModuleStorage(module: module, count: 0, bytes: 0)
                  case final m)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: m.module.color,
                        child: Icon(
                          m.module.icon,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(m.module.label)),
                                Text(
                                  '${m.count} · ${formatBytes(m.bytes)}',
                                  key: Key('storage-${m.module.name}'),
                                  style: TextStyle(color: muted),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: u.bytes == 0 ? 0 : m.bytes / u.bytes,
                                minHeight: 6,
                                color: m.module.color,
                                backgroundColor: m.module.color.withValues(
                                  alpha: 0.15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
