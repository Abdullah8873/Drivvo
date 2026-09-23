import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// New random record id (UUID v4). Public because drift's generated code
/// calls it for the `id` column default.
String newId() => _uuid.v4();

/// Columns shared by every synced table (like a Prisma base model).
/// - `id` is a client-generated UUID so records can be created offline.
/// - `updatedAt` / `deletedAt` drive the future Supabase sync (soft deletes).
mixin SyncColumns on Table {
  TextColumn get id => text().clientDefault(newId)();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// Vehicles
// ---------------------------------------------------------------------------

/// Stored as text in `Vehicles.type`.
enum VehicleType {
  car,
  motorcycle,
  truck,
  bus,
  boat,
  tractor,
  airplane,
  generator,
  other,
}

/// Energy source of a tank. Decides the volume unit (L/gal, kg/m³, kWh).
enum FuelKind { liquid, gas, electric }

/// How the vehicle's usage is measured.
enum DistanceUnit { km, mi, hours }

class Vehicles extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get type => textEnum<VehicleType>()();
  TextColumn get manufacturer => text().nullable()();
  TextColumn get model => text().nullable()();
  TextColumn get plate => text().nullable()();
  IntColumn get year => integer().nullable()();

  /// 1 or 2 (e.g. flex/bi-fuel vehicles with a gas tank + a CNG tank).
  IntColumn get tankCount => integer().withDefault(const Constant(1))();
  TextColumn get tank1Kind =>
      textEnum<FuelKind>().withDefault(Constant(FuelKind.liquid.name))();
  RealColumn get tank1Capacity => real().nullable()();
  TextColumn get tank2Kind => textEnum<FuelKind>().nullable()();
  RealColumn get tank2Capacity => real().nullable()();

  TextColumn get distanceUnit =>
      textEnum<DistanceUnit>().withDefault(Constant(DistanceUnit.km.name))();
  TextColumn get vin => text().nullable()();
  TextColumn get registrationId => text().nullable()();
  RealColumn get purchasePrice => real().nullable()();
  RealColumn get salePrice => real().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  TextColumn get notes => text().nullable()();
}

// ---------------------------------------------------------------------------
// Catalogs (fuels, types, stations, places, reasons, payment methods)
// ---------------------------------------------------------------------------

/// Every user-editable pick list lives in one table, discriminated by kind.
enum CatalogKind {
  fuel,
  serviceType,
  expenseType,
  incomeType,
  reason,
  paymentMethod,
  gasStation,
  place,
}

class CatalogItems extends Table with SyncColumns {
  TextColumn get kind => textEnum<CatalogKind>()();
  TextColumn get name => text()();

  /// Only for fuels: which tank kind this fuel belongs to.
  TextColumn get fuelKind => textEnum<FuelKind>().nullable()();

  /// Only for gas stations / places.
  TextColumn get address => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
}

// ---------------------------------------------------------------------------
// Records
// ---------------------------------------------------------------------------

class Refuelings extends Table with SyncColumns {
  TextColumn get vehicleId => text().references(Vehicles, #id)();
  DateTimeColumn get date => dateTime()();
  RealColumn get odometer => real()();
  BoolColumn get fullTank => boolean().withDefault(const Constant(true))();
  BoolColumn get missedPrevious =>
      boolean().withDefault(const Constant(false))();
  TextColumn get gasStationId =>
      text().nullable().references(CatalogItems, #id)();
  TextColumn get paymentMethodId =>
      text().nullable().references(CatalogItems, #id)();
  TextColumn get reasonId => text().nullable().references(CatalogItems, #id)();
  TextColumn get driver => text().nullable()();
  RealColumn get discount => real().nullable()();

  /// Sum of all fuel lines minus discount (denormalized for fast lists).
  RealColumn get totalCost => real()();
  TextColumn get notes => text().nullable()();
}

/// One fuel inside a refueling (a refueling can hold several, e.g. + AdBlue).
class RefuelingFuels extends Table with SyncColumns {
  TextColumn get refuelingId => text().references(Refuelings, #id)();
  TextColumn get fuelId => text().references(CatalogItems, #id)();
  RealColumn get pricePerUnit => real()();
  RealColumn get total => real()();
  RealColumn get volume => real()();

  /// Which tank (1 or 2) this fuel went into.
  IntColumn get tank => integer().withDefault(const Constant(1))();
}

/// Expenses, services and incomes share one shape (Drivvo's forms are
/// nearly identical), discriminated by kind.
enum EntryKind { expense, service, income }

class Entries extends Table with SyncColumns {
  TextColumn get vehicleId => text().references(Vehicles, #id)();
  TextColumn get kind => textEnum<EntryKind>()();
  DateTimeColumn get date => dateTime()();
  RealColumn get odometer => real().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get placeId => text().nullable().references(CatalogItems, #id)();
  TextColumn get paymentMethodId =>
      text().nullable().references(CatalogItems, #id)();
  TextColumn get reasonId => text().nullable().references(CatalogItems, #id)();
  TextColumn get driver => text().nullable()();
  RealColumn get discount => real().nullable()();

  /// Sum of items minus discount (for installments: this installment's share).
  RealColumn get totalCost => real()();

  /// Installments: the first row is the parent; rows 2..n point to it.
  TextColumn get parentId => text().nullable()();
  IntColumn get installmentNo => integer().withDefault(const Constant(1))();
  IntColumn get installmentCount => integer().withDefault(const Constant(1))();
  TextColumn get notes => text().nullable()();
}

/// A typed line inside an entry (e.g. "Oil Change — 1200").
class EntryItems extends Table with SyncColumns {
  TextColumn get entryId => text().references(Entries, #id)();
  TextColumn get typeId => text().references(CatalogItems, #id)();
  RealColumn get amount => real()();
}

enum RouteMode { trip, freight }

class Routes extends Table with SyncColumns {
  TextColumn get vehicleId => text().references(Vehicles, #id)();
  TextColumn get mode =>
      textEnum<RouteMode>().withDefault(Constant(RouteMode.trip.name))();
  TextColumn get origin => text().nullable()();
  DateTimeColumn get startDate => dateTime()();
  RealColumn get startOdometer => real()();
  TextColumn get destination => text().nullable()();

  /// Null while the route is still open (finish later).
  DateTimeColumn get endDate => dateTime().nullable()();
  RealColumn get endOdometer => real().nullable()();

  /// Trip mode: optional value per distance unit, and the computed total.
  RealColumn get valuePerDistance => real().nullable()();
  RealColumn get total => real().nullable()();

  // Freight mode.
  TextColumn get cargoType => text().nullable()();
  TextColumn get contractor => text().nullable()();
  TextColumn get cargoUnit => text().nullable()();
  RealColumn get cargoAmount => real().nullable()();
  RealColumn get cargoWeight => real().nullable()();
  RealColumn get cargoVolume => real().nullable()();
  RealColumn get freightValue => real().nullable()();
  IntColumn get installments => integer().withDefault(const Constant(1))();

  TextColumn get driver => text().nullable()();
  TextColumn get reasonId => text().nullable().references(CatalogItems, #id)();
  TextColumn get notes => text().nullable()();
}

/// Quick odometer update.
class Readings extends Table with SyncColumns {
  TextColumn get vehicleId => text().references(Vehicles, #id)();
  DateTimeColumn get date => dateTime()();
  RealColumn get odometer => real()();
  TextColumn get driver => text().nullable()();
  TextColumn get notes => text().nullable()();
}

enum ReminderTarget { expense, service }

enum PeriodUnit { day, month, year }

class Reminders extends Table with SyncColumns {
  TextColumn get vehicleId => text().references(Vehicles, #id)();
  TextColumn get target => textEnum<ReminderTarget>()();
  TextColumn get typeId => text().references(CatalogItems, #id)();

  /// false = "just one time", true = "repeat every".
  BoolColumn get repeat => boolean().withDefault(const Constant(false))();

  /// Distance trigger. One-time: [dueOdometer]. Repeat: every [everyDistance].
  BoolColumn get byDistance => boolean().withDefault(const Constant(true))();
  RealColumn get dueOdometer => real().nullable()();
  RealColumn get everyDistance => real().nullable()();

  /// Date trigger. One-time: [dueDate]. Repeat: every [everyAmount] [everyUnit].
  BoolColumn get byDate => boolean().withDefault(const Constant(false))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  IntColumn get everyAmount => integer().nullable()();
  TextColumn get everyUnit => textEnum<PeriodUnit>().nullable()();

  /// Baseline for repeating reminders; updated when the linked
  /// service/expense is logged (auto-reschedule).
  RealColumn get lastDoneOdometer => real().nullable()();
  DateTimeColumn get lastDoneDate => dateTime().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  TextColumn get notes => text().nullable()();
}

// ---------------------------------------------------------------------------
// App settings (local only, key/value like localStorage)
// ---------------------------------------------------------------------------

class SettingsEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
