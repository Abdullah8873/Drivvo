import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/db/persist_writes_interceptor.dart';

/// Records every `runCustom` that reaches the real executor, and whether it
/// ran inside a transaction. Sits *below* the interceptor under test.
class _StatementLog extends QueryInterceptor {
  final entries = <(String, bool)>[];

  List<String> get outsideTransactions => [
    for (final (sql, inTx) in entries)
      if (!inTx) sql,
  ];

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    entries.add((statement, executor is TransactionExecutor));
    return super.runCustom(executor, statement, args);
  }
}

/// `PersistWritesInterceptor`: on the web, drift writes to IndexedDB only
/// after a plain statement outside a transaction, so the interceptor issues
/// one after each top-level commit and each `… RETURNING` write.
void main() {
  late _StatementLog log;
  late AppDatabase db;

  setUp(() async {
    log = _StatementLog();
    db = AppDatabase(
      NativeDatabase.memory()
          .interceptWith(log)
          .interceptWith(PersistWritesInterceptor()),
    );
    await db.customStatement('CREATE TABLE t (x INTEGER)'); // opens + migrates
    log.entries.clear();
  });

  tearDown(() => db.close());

  test('a top-level transaction is followed by one SELECT 1', () async {
    await db.transaction(() async {
      await db.customStatement('INSERT INTO t VALUES (1)');
      await db.transaction(() async {
        await db.customStatement('INSERT INTO t VALUES (2)');
      });
    });

    // The nested transaction adds no flush of its own.
    expect(log.outsideTransactions, ['SELECT 1']);
    expect(log.entries.last, ('SELECT 1', false));
  });

  test('INSERT … RETURNING is followed by SELECT 1', () async {
    final rows = await db
        .customSelect('INSERT INTO t VALUES (7) RETURNING x')
        .get();

    expect(rows.single.read<int>('x'), 7);
    expect(log.outsideTransactions, ['SELECT 1']);
  });

  test('plain reads and RETURNING inside a transaction add nothing', () async {
    await db.customSelect('SELECT * FROM t').get();
    expect(log.entries, isEmpty);

    await db.transaction(() async {
      await db.customSelect('INSERT INTO t VALUES (8) RETURNING x').get();
    });
    // Only the commit's flush.
    expect(log.outsideTransactions, ['SELECT 1']);
  });

  test('a failed transaction rethrows and does not flush', () async {
    await expectLater(
      db.transaction(() async => throw StateError('boom')),
      throwsStateError,
    );
    expect(log.outsideTransactions, isEmpty);
  });
}
