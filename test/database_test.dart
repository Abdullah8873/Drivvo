import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/providers.dart';
import 'package:motolog/core/settings/app_settings.dart';

import 'helpers.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  test('seeds default catalogs', () async {
    final fuels = await db.watchCatalog(CatalogKind.fuel).first;
    expect(fuels.map((f) => f.name), contains('Petrol'));
    expect(fuels.firstWhere((f) => f.name == 'CNG').fuelKind, FuelKind.gas);
    final payment = await db.watchCatalog(CatalogKind.paymentMethod).first;
    expect(payment, hasLength(4));
  });

  test('last odometer is the max across record tables', () async {
    final vid = await addTestVehicle(db);
    expect(await db.watchLastOdometer(vid).first, isNull);
    await db
        .into(db.readings)
        .insert(
          ReadingsCompanion.insert(
            vehicleId: vid,
            date: DateTime(2026, 9, 1),
            odometer: 56935,
          ),
        );
    await db
        .into(db.entries)
        .insert(
          EntriesCompanion.insert(
            vehicleId: vid,
            kind: EntryKind.service,
            date: DateTime(2026, 7, 29),
            totalCost: 9100,
            odometer: const Value(56403),
          ),
        );
    expect(await db.watchLastOdometer(vid).first, 56935);
  });

  test('settings round-trip through the database', () async {
    expect(await loadSettings(db), isA<AppSettings>());
    final s = const AppSettings().copyWith(currencyCode: 'USD');
    final restored = AppSettings.fromJson(s.toJson());
    expect(restored.currencyCode, 'USD');
    expect(restored.efficiencyFormat, EfficiencyFormat.kmPerLiter);
  });
}
