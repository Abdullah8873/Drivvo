import 'package:drift/drift.dart';

/// Makes sure every write reaches IndexedDB on the web.
///
/// drift's web backend (sqlite3 WASM over IndexedDB, drift 2.35) keeps the
/// database in memory and writes it to IndexedDB only after a
/// `runCustom`/`runInsert`/`runUpdate`/`runDelete`/`runBatched` that runs
/// *outside* a transaction. Two kinds of writes never trigger that:
/// - a transaction's `COMMIT` (it runs while drift still counts the
///   transaction as open), and
/// - `INSERT/UPDATE/DELETE … RETURNING` (`insertReturning`), which drift
///   runs as a select.
/// Those changes then live only in memory until some later plain write, and
/// a reload or closed tab loses them (found in QA, 2026-09-26).
///
/// This interceptor — think Express middleware around every query — runs a
/// no-op `SELECT 1` through `runCustom` right after each of those, outside
/// any transaction, which makes drift write everything pending to IndexedDB.
/// Only installed on the web; native platforms write straight to the file.
class PersistWritesInterceptor extends QueryInterceptor {
  /// The executor each transaction was started from, to tell a top-level
  /// transaction (parent is the database) from a nested one.
  final _parents = Expando<QueryExecutor>();

  static final _write = RegExp(
    r'^\s*(INSERT|UPDATE|DELETE|REPLACE)\b',
    caseSensitive: false,
  );

  Future<void> _persist(QueryExecutor executor) =>
      executor.runCustom('SELECT 1', const []);

  @override
  TransactionExecutor beginTransaction(QueryExecutor parent) {
    final transaction = parent.beginTransaction();
    _parents[transaction] = parent;
    return transaction;
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    await inner.send();
    final parent = _parents[inner];
    if (parent != null && parent is! TransactionExecutor) {
      await _persist(parent);
    }
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final rows = await executor.runSelect(statement, args);
    if (executor is! TransactionExecutor && _write.hasMatch(statement)) {
      await _persist(executor);
    }
    return rows;
  }
}
