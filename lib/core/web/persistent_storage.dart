import 'package:flutter/foundation.dart' show kIsWeb;

import 'persistent_storage_stub.dart'
    if (dart.library.js_interop) 'persistent_storage_web.dart'
    as impl;

/// Asks the browser to keep this site's storage (the IndexedDB copy of the
/// drift database) even under disk pressure — `navigator.storage.persist()`.
/// Without it the browser may silently evict "best-effort" storage, which
/// for an offline-first app means losing every record.
///
/// Fire-and-forget: never awaited, never blocks start-up, and any error
/// (API missing, permission denied) is ignored — the app works the same,
/// only without the eviction guarantee. No-op off the web; the conditional
/// import (like a bundler's `browser` field in package.json) keeps
/// `package:web` out of native builds.
void requestPersistentStorage() {
  if (!kIsWeb) return;
  impl.requestPersistentStorage();
}
