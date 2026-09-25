import 'package:motolog/core/sync/remote_store.dart';

/// One [RecordingRemoteStore] call, as it started (`>`) or finished (`<`).
typedef RemoteEvent = ({String op, String table, bool start});

/// Wraps a [RemoteStore] to log every call's start and end (and how many
/// calls were in flight at once), optionally adding a fixed [latency] per
/// call to model the network — like a proxy in front of a REST API that
/// records traffic.
class RecordingRemoteStore implements RemoteStore {
  RecordingRemoteStore(this.inner, {this.latency = Duration.zero});

  final RemoteStore inner;
  final Duration latency;

  /// Every call start/end in the order they happened.
  final events = <RemoteEvent>[];

  int _inFlight = 0;

  /// Most calls that were in flight at the same time.
  int maxInFlight = 0;

  /// Time spent inside [inner] (the fake server's own work, without the
  /// simulated [latency]), summed over every call.
  final innerTime = Stopwatch();

  Future<T> _record<T>(
    String op,
    String table,
    Future<T> Function() call,
  ) async {
    events.add((op: op, table: table, start: true));
    _inFlight++;
    if (_inFlight > maxInFlight) maxInFlight = _inFlight;
    try {
      if (latency > Duration.zero) await Future<void>.delayed(latency);
      // The in-memory fake completes synchronously inside `call()`, so the
      // stopwatch only covers its own work even with calls in parallel.
      innerTime.start();
      final future = call();
      innerTime.stop();
      return await future;
    } finally {
      _inFlight--;
      events.add((op: op, table: table, start: false));
    }
  }

  @override
  Future<void> push(String table, String ownerId, List<RemoteRow> rows) =>
      _record('push', table, () => inner.push(table, ownerId, rows));

  @override
  Future<List<RemoteRow>> pull(
    String table,
    String ownerId, {
    RemoteCursor? after,
    int limit = RemoteStore.maxPullPage,
  }) => _record(
    'pull',
    table,
    () => inner.pull(table, ownerId, after: after, limit: limit),
  );

  /// Index of the first start / last end of [op] calls on [table] in
  /// [events] (-1 when there was none).
  int firstStart(String op, String table) =>
      events.indexWhere((e) => e.op == op && e.table == table && e.start);

  int lastEnd(String op, String table) =>
      events.lastIndexWhere((e) => e.op == op && e.table == table && !e.start);
}
