import 'dart:math' as math;
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'remote_file_store.dart';

/// [RemoteFileStore] backed by Supabase Storage (bucket
/// [RemoteFileStore.bucket]). The bucket is private: its policies scope every
/// call to the signed-in user's `<userId>/` folder.
class SupabaseRemoteFileStore implements RemoteFileStore {
  SupabaseRemoteFileStore(this._client);

  final SupabaseClient _client;

  StorageFileApi get _bucket => _client.storage.from(RemoteFileStore.bucket);

  /// Storage's list/remove calls take at most this many items.
  static const _page = 1000;

  @override
  Future<void> upload(
    String path,
    Uint8List bytes, {
    required String mimeType,
  }) async {
    await _bucket.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mimeType, upsert: true),
    );
  }

  @override
  Future<Uint8List> download(String path) => _bucket.download(path);

  @override
  Future<void> remove(List<String> paths) async {
    for (var i = 0; i < paths.length; i += _page) {
      await _bucket.remove(paths.sublist(i, math.min(i + _page, paths.length)));
    }
  }

  @override
  Future<void> removeAllForUser(String userId) async {
    // Objects are `<userId>/<attachmentId>/<fileName>`: listing `<userId>`
    // returns one "folder" per attachment (no id), listing a folder returns
    // its files. Storage has no recursive delete.
    final paths = <String>[];
    for (final folder in await _listAll(userId)) {
      final prefix = '$userId/${folder.name}';
      if (folder.id != null) {
        paths.add(prefix); // a stray file right under the user folder
        continue;
      }
      for (final file in await _listAll(prefix)) {
        if (file.id != null) paths.add('$prefix/${file.name}');
      }
    }
    await remove(paths);
  }

  Future<List<FileObject>> _listAll(String path) async {
    final all = <FileObject>[];
    for (var offset = 0; ; offset += _page) {
      final page = await _bucket.list(
        path: path,
        searchOptions: SearchOptions(limit: _page, offset: offset),
      );
      all.addAll(page);
      if (page.length < _page) return all;
    }
  }
}
