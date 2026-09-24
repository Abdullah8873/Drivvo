import 'dart:typed_data';

/// The cloud side of attachments: a file bucket (Supabase Storage) — an
/// interface next to [RemoteStore] so the sync engine and the attachment
/// viewer can be tested against [InMemoryRemoteFileStore] and run for real
/// against [SupabaseRemoteFileStore]. Think of it as an S3 client.
///
/// Objects live in the private bucket [bucket] at
/// `<userId>/<attachmentId>/<fileName>` (see [pathFor]); the bucket's
/// policies (`supabase/migrations/20260925000001_attachments_checklists.sql`)
/// only let a user touch objects under their own `<userId>/` folder.
abstract interface class RemoteFileStore {
  /// Name of the Storage bucket.
  static const bucket = 'attachments';

  /// Largest file the app accepts (and the bucket's `file_size_limit`).
  static const maxBytes = 10 * 1024 * 1024;

  /// Object key of an attachment. The file name is reduced to characters
  /// every storage backend accepts in a key; the original name stays in the
  /// `attachments.file_name` column.
  static String pathFor(String userId, String attachmentId, String fileName) {
    var safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    if (safe.isEmpty || safe == '.' || safe == '..') safe = 'file';
    return '$userId/$attachmentId/$safe';
  }

  /// Stores [bytes] at [path] (overwrites). Throws on failure.
  Future<void> upload(String path, Uint8List bytes, {required String mimeType});

  /// The object at [path]. Throws when it is missing or on failure.
  Future<Uint8List> download(String path);

  /// Removes the objects at [paths] (missing ones are ignored).
  Future<void> remove(List<String> paths);

  /// Removes every object under `<userId>/` — used before deleting the
  /// account, because Supabase blocks deleting `storage.objects` rows from
  /// SQL (the files would otherwise be orphaned in the bucket).
  Future<void> removeAllForUser(String userId);
}

/// A fake Storage bucket in memory — the test double for
/// [RemoteFileStore] (like `InMemoryRemoteStore` for rows).
class InMemoryRemoteFileStore implements RemoteFileStore {
  /// path → bytes.
  final objects = <String, Uint8List>{};

  /// path → MIME type given on upload.
  final mimeTypes = <String, String>{};

  /// Throw from these to simulate a network/server error for that call.
  void Function(String path)? beforeUpload;
  void Function(String path)? beforeDownload;
  void Function(List<String> paths)? beforeRemove;

  int uploads = 0;
  int downloads = 0;

  /// Every path passed to [remove], in order.
  final removed = <String>[];

  /// Users passed to [removeAllForUser].
  final removedUsers = <String>[];

  @override
  Future<void> upload(
    String path,
    Uint8List bytes, {
    required String mimeType,
  }) async {
    beforeUpload?.call(path);
    if (bytes.length > RemoteFileStore.maxBytes) {
      throw StateError('Payload too large');
    }
    uploads++;
    objects[path] = Uint8List.fromList(bytes);
    mimeTypes[path] = mimeType;
  }

  @override
  Future<Uint8List> download(String path) async {
    beforeDownload?.call(path);
    downloads++;
    final bytes = objects[path];
    if (bytes == null) throw StateError('Object not found: $path');
    return Uint8List.fromList(bytes);
  }

  @override
  Future<void> remove(List<String> paths) async {
    beforeRemove?.call(paths);
    removed.addAll(paths);
    for (final p in paths) {
      objects.remove(p);
      mimeTypes.remove(p);
    }
  }

  @override
  Future<void> removeAllForUser(String userId) async {
    removedUsers.add(userId);
    final mine = objects.keys.where((k) => k.startsWith('$userId/')).toList();
    await remove(mine);
  }
}
