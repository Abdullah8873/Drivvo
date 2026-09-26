import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cloud/auth_state.dart';
import '../../core/files/file_sharer.dart';
import '../../core/providers.dart';
import '../../core/sync/sync_controller.dart';
import 'attachment_loader.dart';
import 'attachment_queries.dart';

/// Full-screen view of one attachment (our own design — Drivvo's viewer is
/// behind its paywall): images can be pinch-zoomed; PDFs and other files
/// get a "Share / open" button that hands them to the system (on the web:
/// a download). Saved files missing on this device are downloaded from
/// cloud storage on demand.
class AttachmentViewerScreen extends ConsumerStatefulWidget {
  const AttachmentViewerScreen({super.key, required this.item});

  final AttachmentItem item;

  @override
  ConsumerState<AttachmentViewerScreen> createState() =>
      _AttachmentViewerScreenState();
}

class _AttachmentViewerScreenState
    extends ConsumerState<AttachmentViewerScreen> {
  late Future<Uint8List> _bytes = _load();

  Future<Uint8List> _load() async {
    final item = widget.item;
    if (item.pending case final p?) return p.bytes;
    return loadAttachmentBytes(
      ref.read(databaseProvider),
      item.saved!,
      files: ref.read(remoteFileStoreProvider),
      signedIn: ref.read(authUserIdProvider).value != null,
    );
  }

  Future<void> _share(Uint8List bytes) => ref
      .read(fileSharerProvider)
      .shareBytes(
        filename: widget.item.fileName,
        bytes: bytes,
        mimeType: widget.item.mimeType,
      );

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snap) {
        final bytes = snap.data;
        return Scaffold(
          backgroundColor: item.isImage ? Colors.black : null,
          appBar: AppBar(
            backgroundColor: item.isImage ? Colors.black : null,
            foregroundColor: item.isImage ? Colors.white : null,
            title: Text(item.fileName, overflow: TextOverflow.ellipsis),
            actions: [
              if (bytes != null)
                IconButton(
                  tooltip: 'Share / open',
                  icon: const Icon(Icons.share),
                  onPressed: () => _share(bytes),
                ),
            ],
          ),
          body: switch (snap) {
            AsyncSnapshot(hasError: true, :final error) => _Message(
              icon: Icons.cloud_off,
              text: error is AttachmentUnavailable
                  ? error.message
                  : 'This file could not be opened.',
              onRetry: () => setState(() => _bytes = _load()),
            ),
            AsyncSnapshot(:final data?) when item.isImage => InteractiveViewer(
              maxScale: 6,
              child: Center(
                child: Image.memory(
                  data,
                  key: const Key('attachment-image'),
                  errorBuilder: (_, _, _) => const _Message(
                    icon: Icons.broken_image,
                    text: 'This image could not be displayed.',
                  ),
                ),
              ),
            ),
            AsyncSnapshot(:final data?) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.mimeType == 'application/pdf'
                          ? Icons.picture_as_pdf
                          : Icons.insert_drive_file,
                      size: 96,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(item.fileName, textAlign: TextAlign.center),
                    Text(
                      formatBytes(data.length),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _share(data),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('SHARE / OPEN'),
                    ),
                  ],
                ),
              ),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: const Text('TRY AGAIN')),
            ],
          ],
        ),
      ),
    );
  }
}
