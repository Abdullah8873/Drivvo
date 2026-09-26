import 'dart:async';

/// Re-runs [load] whenever [changes] fires, and emits each result — but
/// never runs two loads at once and never queues more than one: changes
/// that arrive while a load is running collapse into ONE reload after it.
///
/// `changes.asyncMap(load)` would instead queue a full reload per change
/// event; a sync pull commits one transaction per page, so a screen
/// watching an expensive query (the History timeline) would then redo it
/// dozens of times in a row after the sync. Think "debounce", but without
/// a timer: the running load is the window.
///
/// Like drift's own watch streams, the result can be listened to more than
/// once; every listener gets its own subscription to [changes].
Stream<T> reloadOnChange<T>(
  Stream<Object?> changes,
  Future<T> Function() load,
) {
  return Stream<T>.multi((out) {
    var running = false;
    var dirty = false;

    Future<void> run() async {
      running = true;
      do {
        dirty = false;
        try {
          final value = await load();
          if (!out.isClosed) out.add(value);
        } catch (e, s) {
          if (!out.isClosed) out.addError(e, s);
        }
      } while (dirty && !out.isClosed);
      running = false;
    }

    final sub = changes.listen(
      (_) {
        if (running) {
          dirty = true;
        } else {
          unawaited(run());
        }
      },
      onError: out.addError,
      onDone: out.close,
    );
    out
      ..onPause = sub.pause
      ..onResume = sub.resume
      ..onCancel = sub.cancel;
  });
}
