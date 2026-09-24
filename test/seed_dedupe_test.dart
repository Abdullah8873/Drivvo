import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/db/seed_data.dart';

import 'helpers.dart';

/// Number of rows the default seed creates.
final _seedCount = SeedData.catalogs.fold<int>(
  0,
  (sum, c) => sum + c.$2.length,
);

/// `CREATE` statements of the current schema, captured from a fresh database
/// so tests can rebuild an "old" database by hand (v1 has the same tables).
late List<String> _schema;

/// Opens a database whose underlying SQLite file was first prepared by
/// running [statements] (e.g. the schema, legacy rows, `PRAGMA user_version`).
AppDatabase _openPrepared(List<String> statements) {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(
        setup: (raw) {
          for (final sql in statements) {
            raw.execute(sql);
          }
        },
      ),
      closeStreamsSynchronously: true,
    ),
  );
}

Future<List<CatalogItem>> _live(AppDatabase db) =>
    (db.select(db.catalogItems)..where((c) => c.deletedAt.isNull())).get();

/// Asserts there's at most one live catalog item per (kind, name).
void _expectNoDuplicates(List<CatalogItem> items) {
  final keys = items
      .map((c) => '${c.kind.name}|${c.name.trim().toLowerCase()}')
      .toList();
  expect(keys.toSet(), hasLength(keys.length));
}

const _t0 = '2026-01-01T10:00:00.000Z';
const _t1 = '2026-01-01T10:00:05.000Z';

String _catalog(
  String id,
  CatalogKind kind,
  String name, {
  String created = _t0,
  String? deleted,
}) =>
    'INSERT INTO catalog_items (id, created_at, updated_at, deleted_at, kind, '
    "name) VALUES ('$id', '$created', '$created', "
    "${deleted == null ? 'NULL' : "'$deleted'"}, '${kind.name}', '$name')";

void main() {
  setUpAll(() async {
    final db = testDatabase();
    final rows = await db
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT "
          "LIKE 'sqlite_%' ORDER BY type DESC",
        )
        .get();
    _schema = [for (final r in rows) r.read<String>('sql')];
    await db.close();
  });

  group('seeding', () {
    late AppDatabase db;
    setUp(() => db = testDatabase());
    tearDown(() => db.close());

    test('a fresh database is seeded exactly once, with seed ids', () async {
      final items = await _live(db);
      expect(items, hasLength(_seedCount));
      _expectNoDuplicates(items);
      expect(items.every((c) => c.id.startsWith('seed:')), isTrue);
      final petrol = items.singleWhere((c) => c.name == 'Petrol');
      expect(petrol.id, 'seed:fuel:petrol');
      expect(
        items.singleWhere((c) => c.name == 'Oil Change').id,
        'seed:serviceType:oil-change',
      );
    });

    test('running the seed again adds nothing', () async {
      await db.seedCatalogs();
      await db.seedCatalogs();
      final items = await _live(db);
      expect(items, hasLength(_seedCount));
      _expectNoDuplicates(items);
    });

    test('re-seeding does not resurrect a deleted default', () async {
      await (db.update(db.catalogItems)
            ..where((c) => c.id.equals('seed:fuel:petrol')))
          .write(CatalogItemsCompanion(deletedAt: Value(DateTime.now())));
      await db.seedCatalogs();
      final fuels = await db.watchCatalog(CatalogKind.fuel).first;
      expect(fuels.map((f) => f.name), isNot(contains('Petrol')));
    });
  });

  test('an interrupted first launch self-heals without duplicates', () async {
    // Tables exist and part of the seed ran, but the schema version was never
    // recorded (user_version 0), so drift runs onCreate again.
    final db = _openPrepared([
      ..._schema,
      _catalog('seed:fuel:petrol', CatalogKind.fuel, 'Petrol'),
      _catalog('seed:fuel:diesel', CatalogKind.fuel, 'Diesel'),
    ]);
    addTearDown(db.close);
    final items = await _live(db);
    expect(items, hasLength(_seedCount));
    _expectNoDuplicates(items);
  });

  group('v1 -> v2 migration', () {
    late AppDatabase db;

    setUp(() {
      // A v1 database seeded twice with random ids ("a-" first, "b-" five
      // seconds later), plus user items and records that point at the
      // second (duplicate) copy.
      String a(CatalogKind k, String n) => 'a-${SeedData.idFor(k, n)}';
      String b(CatalogKind k, String n) => 'b-${SeedData.idFor(k, n)}';
      final petrolB = b(CatalogKind.fuel, 'Petrol');
      final moneyB = b(CatalogKind.paymentMethod, 'Money');
      final workB = b(CatalogKind.reason, 'Work');
      final tripB = b(CatalogKind.reason, 'Trip');
      final oilB = b(CatalogKind.serviceType, 'Oil Change');
      db = _openPrepared([
        ..._schema,
        for (final (kind, names) in SeedData.catalogs)
          for (final name in names) ...[
            _catalog(a(kind, name), kind, name),
            _catalog(b(kind, name), kind, name, created: _t1),
          ],
        // User items with distinct names: must be left alone.
        _catalog('u-shell', CatalogKind.gasStation, 'Shell'),
        _catalog('u-garage', CatalogKind.place, 'Home Garage'),
        _catalog('u-wax', CatalogKind.serviceType, 'Wax'),
        // An already-deleted duplicate stays as it was.
        _catalog('u-old', CatalogKind.fuel, 'Petrol', deleted: _t1),
        "INSERT INTO vehicles (id, created_at, updated_at, name, type) "
            "VALUES ('v1', '$_t0', '$_t0', 'Honda', 'motorcycle')",
        'INSERT INTO refuelings (id, created_at, updated_at, vehicle_id, '
            'date, odometer, gas_station_id, payment_method_id, reason_id, '
            "total_cost) VALUES ('r1', '$_t0', '$_t0', 'v1', '$_t0', 100, "
            "'u-shell', '$moneyB', '$workB', 50)",
        'INSERT INTO refueling_fuels (id, created_at, updated_at, '
            'refueling_id, fuel_id, price_per_unit, total, volume) VALUES '
            "('rf1', '$_t0', '$_t0', 'r1', '$petrolB', 5, 50, 10)",
        'INSERT INTO entries (id, created_at, updated_at, vehicle_id, kind, '
            'date, place_id, payment_method_id, reason_id, total_cost) VALUES '
            "('e1', '$_t0', '$_t0', 'v1', 'service', '$_t0', 'u-garage', "
            "'$moneyB', '$tripB', 30)",
        'INSERT INTO entry_items (id, created_at, updated_at, entry_id, '
            "type_id, amount) VALUES ('ei1', '$_t0', '$_t0', 'e1', '$oilB', 20)",
        'INSERT INTO entry_items (id, created_at, updated_at, entry_id, '
            "type_id, amount) VALUES ('ei2', '$_t0', '$_t0', 'e1', 'u-wax', 10)",
        'INSERT INTO routes (id, created_at, updated_at, vehicle_id, '
            'start_date, start_odometer, reason_id) VALUES '
            "('ro1', '$_t0', '$_t0', 'v1', '$_t0', 100, '$tripB')",
        'INSERT INTO reminders (id, created_at, updated_at, vehicle_id, '
            "target, type_id) VALUES ('re1', '$_t0', '$_t0', 'v1', "
            "'service', '$oilB')",
        'PRAGMA user_version = 1',
      ]);
    });
    tearDown(() => db.close());

    test('keeps one live row per name and soft-deletes the rest', () async {
      final items = await _live(db);
      _expectNoDuplicates(items);
      expect(items, hasLength(_seedCount + 3));
      // The oldest copy wins; the seed isn't re-run on top of v1 data.
      expect(
        items.where((c) => c.id.startsWith('a-seed:')),
        hasLength(_seedCount),
      );
      final all = await db.select(db.catalogItems).get();
      final dup = all.singleWhere(
        (c) => c.id == 'b-${SeedData.idFor(CatalogKind.fuel, 'Petrol')}',
      );
      expect(dup.deletedAt, isNotNull);
      expect(dup.updatedAt.isAfter(DateTime.parse(_t1)), isTrue);
      final old = all.singleWhere((c) => c.id == 'u-old');
      expect(old.deletedAt, DateTime.parse(_t1));
    });

    test('user items with distinct names are untouched', () async {
      final items = await _live(db);
      for (final id in ['u-shell', 'u-garage', 'u-wax']) {
        final item = items.singleWhere((c) => c.id == id);
        expect(item.updatedAt, DateTime.parse(_t0));
      }
    });

    test('every record points at the kept rows', () async {
      String keep(CatalogKind k, String n) => 'a-${SeedData.idFor(k, n)}';
      final r = await db.select(db.refuelings).getSingle();
      expect(r.gasStationId, 'u-shell');
      expect(r.paymentMethodId, keep(CatalogKind.paymentMethod, 'Money'));
      expect(r.reasonId, keep(CatalogKind.reason, 'Work'));
      final rf = await db.select(db.refuelingFuels).getSingle();
      expect(rf.fuelId, keep(CatalogKind.fuel, 'Petrol'));
      final e = await db.select(db.entries).getSingle();
      expect(e.placeId, 'u-garage');
      expect(e.paymentMethodId, keep(CatalogKind.paymentMethod, 'Money'));
      expect(e.reasonId, keep(CatalogKind.reason, 'Trip'));
      final types = {
        for (final i in await db.select(db.entryItems).get()) i.id: i.typeId,
      };
      expect(types, {
        'ei1': keep(CatalogKind.serviceType, 'Oil Change'),
        'ei2': 'u-wax',
      });
      final ro = await db.select(db.routes).getSingle();
      expect(ro.reasonId, keep(CatalogKind.reason, 'Trip'));
      final re = await db.select(db.reminders).getSingle();
      expect(re.typeId, keep(CatalogKind.serviceType, 'Oil Change'));

      // No record references a deleted catalog item.
      final dangling = await db.customSelect('''
        SELECT COUNT(*) AS n FROM catalog_items c WHERE c.deleted_at IS NOT NULL
          AND (c.id IN (SELECT fuel_id FROM refueling_fuels)
            OR c.id IN (SELECT type_id FROM entry_items)
            OR c.id IN (SELECT type_id FROM reminders)
            OR c.id IN (SELECT reason_id FROM routes WHERE reason_id IS NOT NULL)
            OR c.id IN (SELECT payment_method_id FROM entries
                        WHERE payment_method_id IS NOT NULL)
            OR c.id IN (SELECT reason_id FROM refuelings
                        WHERE reason_id IS NOT NULL))
      ''').getSingle();
      expect(dangling.read<int>('n'), 0);
    });

    test('a seed-id row is preferred over an older random-id row', () async {
      await db.close();
      db = _openPrepared([
        ..._schema,
        _catalog('x-old', CatalogKind.fuel, 'Petrol'),
        _catalog('seed:fuel:petrol', CatalogKind.fuel, 'petrol ', created: _t1),
        "INSERT INTO settings_entries (key, value) VALUES "
            "('${AppDatabase.seedMarkerKey}', '1')",
        'PRAGMA user_version = 1',
      ]);
      final items = await _live(db);
      expect(items.map((c) => c.id), ['seed:fuel:petrol']);
    });
  });
}
