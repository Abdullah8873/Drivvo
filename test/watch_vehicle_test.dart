import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/app_database.dart';

import 'helpers.dart';

void main() {
  test('watchVehicle ignores soft-deleted vehicles', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final id = await addTestVehicle(db);
    expect((await db.watchVehicle(id).first)?.id, id);

    await (db.update(db.vehicles)..where((v) => v.id.equals(id))).write(
      VehiclesCompanion(deletedAt: Value(DateTime.now())),
    );
    expect(await db.watchVehicle(id).first, isNull);
  });
}
