import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web build of `requestPersistentStorage` (see persistent_storage.dart).
void requestPersistentStorage() {
  try {
    web.window.navigator.storage.persist().toDart.then(
      (_) {},
      onError: (Object _) {},
    );
  } catch (_) {
    // Older browsers without the Storage API — nothing to do.
  }
}
