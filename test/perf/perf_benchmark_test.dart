// Benchmarks print their timings — that is their whole output.
// ignore_for_file: avoid_print
@Tags(['perf'])
@Timeout(Duration(minutes: 30))
library;

import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/calc/achievements.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/providers.dart' show loadSettings;
import 'package:motolog/core/sync/in_memory_remote_store.dart';
import 'package:motolog/core/sync/sync_engine.dart';
import 'package:motolog/core/theme/record_module.dart';
import 'package:motolog/features/history/history_calc.dart';
import 'package:motolog/features/history/history_providers.dart';
import 'package:motolog/features/history/history_queries.dart';
import 'package:motolog/features/refueling/refueling_providers.dart';
import 'package:motolog/features/reminders/reminder_queries.dart';
import 'package:motolog/features/reports/general_report.dart';
import 'package:motolog/features/reports/module_reports.dart';
import 'package:motolog/features/reports/refueling_report.dart';
import 'package:motolog/features/reports/report_period.dart';
import 'package:motolog/features/reports/report_scope.dart';

import '../sync_test_utils.dart';
import 'big_dataset.dart';

/// Performance benchmark over a big dataset (3 vehicles × ~5,000 records,
/// see `big_dataset.dart`). Excluded from the default `flutter test` run by
/// the `perf` tag (`dart_test.yaml`); run it with:
///
/// ```
/// flutter test --run-skipped -t perf test/perf -r expanded > perf.txt
/// ```
///
/// Every line starting with `PERF |` is one measurement: the median and
/// the fastest of several runs, in milliseconds.
void main() {
  late Directory dir;
  late AppDatabase db;
  late BigDataset data;
  late String vid;
  final now = DateTime(2026, 9, 20, 12);
  final lines = <String>[];

  AppDatabase open(QueryExecutor e) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    return AppDatabase(DatabaseConnection(e, closeStreamsSynchronously: true));
  }

  void report(String label, List<int> micros) {
    final sorted = [...micros]..sort();
    String ms(int us) => (us / 1000).toStringAsFixed(1).padLeft(9);
    final line =
        'PERF | ${label.padRight(52)} | median ${ms(sorted[sorted.length ~/ 2])}'
        ' ms | min ${ms(sorted.first)} ms | runs ${sorted.length}';
    lines.add(line);
    print(line);
  }

  /// Runs [body] once to warm up, then [runs] more times, and reports.
  Future<T> measure<T>(
    String label,
    Future<T> Function() body, {
    int runs = 5,
    bool warmUp = true,
  }) async {
    var result = warmUp ? await body() : null;
    final times = <int>[];
    for (var i = 0; i < runs; i++) {
      final sw = Stopwatch()..start();
      result = await body();
      times.add(sw.elapsedMicroseconds);
    }
    report(label, times);
    return result as T;
  }

  T measureSync<T>(String label, T Function() body, {int runs = 7}) {
    var result = body();
    final times = <int>[];
    for (var i = 0; i < runs; i++) {
      final sw = Stopwatch()..start();
      result = body();
      times.add(sw.elapsedMicroseconds);
    }
    report(label, times);
    return result;
  }

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('motolog_perf_');
    db = open(NativeDatabase(File('${dir.path}/big.sqlite')));
    final sw = Stopwatch()..start();
    data = await seedBigDataset(db);
    // The two-tank vehicle, so tank-2 consumption is exercised too.
    vid = data.vehicleIds.last;
    final outbox = await db
        .customSelect('SELECT COUNT(*) AS n FROM sync_outbox')
        .getSingle();
    print(
      'Seeded ${data.vehicleIds.length} vehicles × '
      '${const BigDatasetSpec().recordsPerVehicle} records '
      '(${outbox.read<int>('n')} rows queued for sync) in '
      '${sw.elapsedMilliseconds} ms',
    );
  });

  tearDownAll(() async {
    await db.close();
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
    print('\n===== PERF SUMMARY =====\n${lines.join('\n')}');
  });

  test('startup', () async {
    await measure('startup: fresh install (open + create + seed)', () async {
      final fresh = open(NativeDatabase.memory());
      await loadSettings(fresh);
      await fresh.close();
    }, warmUp: false);
    await measure(
      'startup: reopen big DB (open + settings + vehicles)',
      () async {
        final again = open(NativeDatabase(File('${dir.path}/big.sqlite')));
        await loadSettings(again);
        await again.watchVehicles().first;
        await again.close();
      },
    );
  });

  test('history', () async {
    final timeline = await measure(
      'history: loadTimeline (1 vehicle, all rows)',
      () => db.loadTimeline(vid),
    );
    print('  timeline rows: ${timeline.length}');
    await measure(
      'history: watchTimeline first emission',
      () => db.watchTimeline(vid).first,
    );
    measureSync('history: groupByMonth', () => groupByMonth(timeline));

    final refuels = await measure(
      'history: watchRefuelings (consumption input)',
      () => db.watchRefuelings(vid).first,
    );
    final samples = await measure(
      'history: watchRefuelSamples (consumption input)',
      () => db.watchRefuelSamples(vid).first,
    );
    expect(
      samples[1]!.length,
      refuels.map((d) => d.toSample(tank: 1)).nonNulls.length,
    );
    final stats = measureSync(
      'history: ConsumptionStats.compute (tank 1)',
      () => ConsumptionStats.compute(samples[1]!),
    );
    final consumption = HistoryConsumption(
      tank1: stats,
      tank2: ConsumptionStats.empty,
    );
    measureSync('history: tanksOf for every row (full scroll)', () {
      var n = 0;
      for (final r in timeline) {
        n += consumption.tanksOf(r).length;
      }
      return n;
    });
    final months = groupByMonth(timeline);
    measureSync('history: month cards (spent/distance/efficiency)', () {
      var s = 0.0;
      for (final m in months) {
        s += m.spent + (m.distance ?? 0);
        s += m.efficiencyFrom(stats.cycles) ?? 0;
        s += m.costByModule.length;
      }
      return s;
    });
  });

  test('reminders inputs', () async {
    await measure(
      'reminders: watchOdometerHistory',
      () => db.watchOdometerHistory(vid).first,
    );
    await measure(
      'reminders: watchLastLoggedByType',
      () => db.watchLastLoggedByType(vid).first,
    );
    await measure(
      'reminders: watchRefuelPoints',
      () => db.watchRefuelPoints(vid).first,
    );
    await measure(
      'shared: watchLastOdometer',
      () => db.watchLastOdometer(vid).first,
    );
  });

  test('reports', () async {
    final vehicle = (await db.watchVehicle(vid).first)!;
    final timeline = await db.loadTimeline(vid);
    final refuels = await db.watchRefuelings(vid).first;
    final tank1 = ConsumptionStats.compute(
      refuels.map((d) => d.toSample(tank: 1)).nonNulls,
    );
    final tank2 = ConsumptionStats.compute(
      refuels.map((d) => d.toSample(tank: 2)).nonNulls,
    );

    for (final (name, period) in [
      ('all time', const ReportPeriod(ReportPeriodKind.allTime)),
      ('1 year', const ReportPeriod(ReportPeriodKind.lastYear)),
    ]) {
      ReportScope scope() => ReportScope(
        vehicle: vehicle,
        period: period,
        range: period.rangeAt(now),
        timeline: [
          for (final r in timeline)
            if (r.module != RecordModule.checklist) r,
        ],
        now: now,
      );
      final s = measureSync('reports[$name]: scope (filter + span)', () {
        final s = scope();
        s.span;
        return s;
      });
      measureSync(
        'reports[$name]: general',
        () => buildGeneralReport(
          timeline: s.timeline,
          range: s.range,
          days: s.days,
        ),
      );
      measureSync(
        'reports[$name]: refueling (tab prep + build)',
        () => _refuelingReport(s, tank1, tank2),
      );
      for (final module in [
        RecordModule.expense,
        RecordModule.service,
        RecordModule.income,
      ]) {
        measureSync(
          'reports[$name]: ${module.name}',
          () => buildModuleMoneyReport(
            records: s.recordsOf({module}),
            timeline: s.timeline,
            range: s.range,
            days: s.days,
          ),
        );
      }
      measureSync(
        'reports[$name]: route',
        () => buildRouteReport(
          records: s.recordsOf({RecordModule.route}),
          days: s.days,
        ),
      );
      measureSync(
        'reports[$name]: reading',
        () => buildReadingReport(
          timeline: s.timeline,
          range: s.range,
          days: s.days,
        ),
      );
    }
    measureSync(
      'achievements: compute',
      () => Achievements.compute([
        for (final r in timeline)
          AchievementRecord(
            date: r.date,
            isRefueling: r.module == RecordModule.refueling,
            gasStation: r.module == RecordModule.refueling ? r.place : null,
            fullTank: r.refueling?.fullTank ?? false,
          ),
      ], now),
    );
  });

  test('writes and the v5 index migration', () async {
    var odo = 900000.0;
    Future<void> saveOne() => db.saveRefueling(
      RefuelingDraft(
        vehicleId: vid,
        date: DateTime(2026, 9, 19),
        odometer: odo += 10,
        lines: [
          FuelLineDraft(
            fuelId: 'seed:fuel:petrol',
            pricePerUnit: 300,
            total: 3000,
            volume: 10,
          ),
        ],
      ),
    );
    Future<List<String>> indexNames() async => [
      for (final r
          in await db
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type = 'index' "
                "AND name LIKE 'idx_%'",
              )
              .get())
        r.read<String>('name'),
    ];

    await measure(
      'write: saveRefueling (file DB, v5 indexes)',
      saveOne,
      runs: 30,
    );
    final names = await indexNames();
    for (final n in names) {
      await db.customStatement('DROP INDEX $n');
    }
    await measure(
      'write: saveRefueling (file DB, no indexes = v4)',
      saveOne,
      runs: 30,
    );
    await measure(
      'migration v4 -> v5: create ${names.length} indexes (big DB)',
      db.createIndexes,
      runs: 1,
      warmUp: false,
    );
    expect(await indexNames(), hasLength(names.length));
  });

  test('sync', () async {
    // Every run starts from "never synced, everything queued".
    Future<void> reset() async {
      await db.customStatement(
        "DELETE FROM settings_entries WHERE key = '${SyncEngine.stateKey}'",
      );
      await db.customStatement('DELETE FROM sync_outbox');
      for (final t in AppDatabase.syncedTableNames) {
        await db.customStatement(
          "INSERT INTO sync_outbox (target_table, row_id) SELECT '$t', id FROM $t",
        );
      }
    }

    for (final latency in const [Duration.zero, Duration(milliseconds: 100)]) {
      final tag = '${latency.inMilliseconds} ms/call';
      final runs = latency == Duration.zero ? 3 : 1;
      late InMemoryRemoteStore cloud;
      late RecordingRemoteStore remote;
      final pushTimes = <int>[];
      for (var i = 0; i < runs; i++) {
        await reset();
        cloud = InMemoryRemoteStore();
        remote = RecordingRemoteStore(cloud, latency: latency);
        final sw = Stopwatch()..start();
        final r = await SyncEngine(db, remote).sync('u1');
        pushTimes.add(sw.elapsedMicroseconds);
        if (i == 0) {
          print(
            '  push [$tag]: $r, ${remote.events.length ~/ 2} calls, '
            'max ${remote.maxInFlight} in flight, fake server '
            '${remote.innerTime.elapsedMilliseconds} ms',
          );
        }
      }
      report('sync[$tag]: push whole outbox (first sync)', pushTimes);

      final pullTimes = <int>[];
      for (var i = 0; i < runs; i++) {
        final empty = open(NativeDatabase.memory());
        remote = RecordingRemoteStore(cloud, latency: latency);
        final sw = Stopwatch()..start();
        final r = await SyncEngine(empty, remote).sync('u1');
        pullTimes.add(sw.elapsedMicroseconds);
        if (i == 0) {
          print(
            '  pull [$tag]: $r, ${remote.events.length ~/ 2} calls, '
            'max ${remote.maxInFlight} in flight, fake server '
            '${remote.innerTime.elapsedMilliseconds} ms',
          );
        }
        await empty.close();
      }
      report('sync[$tag]: full pull into empty DB', pullTimes);
    }
  });
}

/// What `RefuelingReportTab` does before calling `buildRefuelingReport`.
RefuelingReport _refuelingReport(
  ReportScope scope,
  ConsumptionStats tank1Stats,
  ConsumptionStats tank2Stats,
) {
  final fuelByRefueling = <String, List<ReportFuelLine>>{
    for (final r in scope.timeline)
      if (r.module == RecordModule.refueling)
        r.id: [
          for (final f in r.fuels)
            ReportFuelLine(
              fuelName: f.name,
              kind: f.kind,
              tank: f.tank,
              volume: f.volume,
              total: f.total,
            ),
        ],
  };
  final entries = [
    for (final r in scope.timeline)
      if (r.module == RecordModule.refueling)
        RefuelingEntry(
          id: r.id,
          date: r.date,
          fullTank: r.refueling?.fullTank ?? true,
          totalCost: r.amount,
          gasStation: r.place,
          lines: fuelByRefueling[r.id] ?? const [],
        ),
  ];
  final cycles = <RefuelingCycle>[
    for (final c in tank1Stats.cycles) ?tagCycle(c, 1, fuelByRefueling),
    for (final c in tank2Stats.cycles) ?tagCycle(c, 2, fuelByRefueling),
  ];
  return buildRefuelingReport(
    entries: entries,
    cycles: cycles,
    primaryResults: tank1Stats.results,
    range: scope.range,
    days: scope.days,
    distance: periodDistance(scope.timeline, scope.range),
    primaryTankCapacity: scope.vehicle.tank1Capacity,
  );
}
