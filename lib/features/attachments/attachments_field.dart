import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/providers.dart';
import '../../core/sync/remote_file_store.dart';
import 'attachment_picker.dart';
import 'attachment_queries.dart';
import 'attachment_viewer_screen.dart';

/// A form's attachment state: what the record already has plus the files
/// added/removed since the form opened. Nothing touches the database until
/// the form's SAVE calls [save] (inside the record's own transaction), so
/// backing out of the form discards the changes — like a controlled
/// `<input type="file" multiple>` whose files are only POSTed on submit.
class AttachmentsController extends ChangeNotifier {
  AttachmentsController(this.parentTable);

  /// `attachments.parent_table` of the form's records (e.g. `readings`).
  final String parentTable;

  List<Attachment> _existing = const [];
  final _removed = <String>{};
  final _added = <PendingAttachment>[];

  /// Current list: saved files not removed, then newly added ones.
  List<AttachmentItem> get items => [
    for (final a in _existing)
      if (!_removed.contains(a.id)) AttachmentItem.saved(a),
    for (final p in _added) AttachmentItem.pending(p),
  ];

  /// True when there is something to save (drives "Discard changes?").
  bool get isDirty => _removed.isNotEmpty || _added.isNotEmpty;

  /// Edit mode: shows the record's saved attachments.
  Future<void> load(AppDatabase db, String parentId) async {
    _existing = await db.getAttachments(parentTable, parentId);
    notifyListeners();
  }

  void add(PendingAttachment file) {
    _added.add(file);
    notifyListeners();
  }

  void remove(AttachmentItem item) {
    if (item.saved case final a?) {
      _removed.add(a.id);
    } else {
      _added.remove(item.pending);
    }
    notifyListeners();
  }

  /// Writes the pending changes for the saved record [parentId]. Call it
  /// inside the same `db.transaction` as the record itself.
  Future<void> save(
    AppDatabase db, {
    required String parentId,
    required String? vehicleId,
  }) => db.applyAttachmentChanges(
    parentTable: parentTable,
    parentId: parentId,
    vehicleId: vehicleId,
    added: _added,
    removedIds: _removed,
  );
}

enum _Source { camera, gallery, pdf }

/// "+ Attach file" plus the list of attached files (thumbnail or PDF icon,
/// name, size, ✕). Tapping a row opens [AttachmentViewerScreen]. Used by
/// every record form.
class AttachmentsField extends ConsumerWidget {
  const AttachmentsField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final AttachmentsController controller;

  /// Called after every add/remove (forms mark themselves dirty).
  final VoidCallback onChanged;

  Future<void> _attach(BuildContext context, WidgetRef ref) async {
    final picker = ref.read(attachmentPickerProvider);
    final source = await showModalBottomSheet<_Source>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (picker.canTakePhoto)
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take photo'),
                onTap: () => Navigator.pop(ctx, _Source.camera),
              ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Choose image'),
              onTap: () => Navigator.pop(ctx, _Source.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Choose file (PDF)'),
              onTap: () => Navigator.pop(ctx, _Source.pdf),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    PendingAttachment? file;
    try {
      file = await switch (source) {
        _Source.camera => picker.takePhoto(),
        _Source.gallery => picker.pickImage(),
        _Source.pdf => picker.pickPdf(),
      };
    } catch (_) {
      if (context.mounted) _snack(context, "Couldn't open the file.");
      return;
    }
    if (file == null || !context.mounted) return;
    if (file.bytes.length > RemoteFileStore.maxBytes) {
      _snack(context, 'Files larger than 10 MB can\'t be attached.');
      return;
    }
    controller.add(file);
    onChanged();
  }

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in controller.items)
            AttachmentRow(
              item: item,
              onRemove: () {
                controller.remove(item);
                onChanged();
              },
            ),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('attach-file'),
                onPressed: () => _attach(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Attach file'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One attached file: thumbnail (images) or file icon, name, size and an
/// optional ✕. Tap opens the viewer.
class AttachmentRow extends StatelessWidget {
  const AttachmentRow({
    super.key,
    required this.item,
    this.onRemove,
    this.indent = 48,
  });

  final AttachmentItem item;
  final VoidCallback? onRemove;

  /// Left inset (48 lines rows up with the form fields next to their icons).
  final double indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: AttachmentThumbnail(item: item),
        title: Text(
          item.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(formatBytes(item.sizeBytes)),
        trailing: onRemove == null
            ? null
            : IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.close),
                onPressed: onRemove,
              ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AttachmentViewerScreen(item: item),
          ),
        ),
      ),
    );
  }
}

/// 40×40 preview: the image itself when its bytes are on this device,
/// otherwise an icon (never downloads — that happens in the viewer).
class AttachmentThumbnail extends ConsumerStatefulWidget {
  const AttachmentThumbnail({super.key, required this.item});

  final AttachmentItem item;

  @override
  ConsumerState<AttachmentThumbnail> createState() =>
      _AttachmentThumbnailState();
}

class _AttachmentThumbnailState extends ConsumerState<AttachmentThumbnail> {
  Future<Uint8List?>? _bytes;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (!item.isImage) return;
    _bytes = item.pending != null
        ? Future.value(item.pending!.bytes)
        : ref.read(databaseProvider).localAttachmentBytes(item.saved!.id);
  }

  @override
  Widget build(BuildContext context) {
    final icon = SizedBox(
      width: 40,
      height: 40,
      child: Icon(
        widget.item.isImage ? Icons.image : Icons.picture_as_pdf,
        color: widget.item.isImage ? Colors.grey.shade600 : Colors.red.shade400,
      ),
    );
    if (_bytes == null) return icon;
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snap) {
        final data = snap.data;
        if (data == null) return icon;
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.memory(
            data,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            cacheWidth: 120,
            errorBuilder: (_, _, _) => icon,
          ),
        );
      },
    );
  }
}

/// Read-only attachment list of a saved record (record detail screen).
class RecordAttachmentsList extends ConsumerWidget {
  const RecordAttachmentsList({
    super.key,
    required this.parentTable,
    required this.parentId,
  });

  final String parentTable;
  final String parentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list =
        ref.watch(recordAttachmentsProvider((parentTable, parentId))).value ??
        const <Attachment>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final a in list)
          AttachmentRow(item: AttachmentItem.saved(a), indent: 0),
      ],
    );
  }
}

/// Live attachments of one record, keyed by `(parentTable, parentId)`.
final recordAttachmentsProvider = StreamProvider.autoDispose
    .family<List<Attachment>, (String, String)>(
      (ref, key) =>
          ref.watch(databaseProvider).watchAttachments(key.$1, key.$2),
    );
