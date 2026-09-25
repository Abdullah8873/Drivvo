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
//
// Indexes (schema v5, `@TableIndex`, named `idx_<table>_…`): every record
// table is read "one vehicle, by date" (History, Reports, reminders), so
// each gets `(vehicle_id, date)`; child tables get their parent id (the
// joins and cascades); `attachments` gets its polymorphic parent key and
// `sync_outbox` its push order. Without them every such query was a full
// table scan — like a Postgres table with no index on its foreign keys.
// Existing installs get them in `AppDatabase.migration` (v4 -> v5).

@TableIndex(name: 'idx_refuelings_vehicle_date', columns: {#vehicleId, #date})
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

  /// Sharing (schema v6): the Supabase user who created the record, for
  /// the "own records" profile scope. The server stamps it on the first
  /// upload and never changes it; null = not uploaded yet (so created on
  /// this device) or created before sharing existed (= the account owner).
  TextColumn get createdBy => text().nullable()();
}

/// One fuel inside a refueling (a refueling can hold several, e.g. + AdBlue).
@TableIndex(name: 'idx_refueling_fuels_refueling', columns: {#refuelingId})
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

@TableIndex(name: 'idx_entries_vehicle_date', columns: {#vehicleId, #date})
@TableIndex(name: 'idx_entries_parent', columns: {#parentId})
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

  /// Sharing (v6): who created it — see [Refuelings.createdBy].
  TextColumn get createdBy => text().nullable()();
}

/// A typed line inside an entry (e.g. "Oil Change — 1200").
@TableIndex(name: 'idx_entry_items_entry', columns: {#entryId})
class EntryItems extends Table with SyncColumns {
  TextColumn get entryId => text().references(Entries, #id)();
  TextColumn get typeId => text().references(CatalogItems, #id)();
  RealColumn get amount => real()();

  /// Service items only (v7): the replaced part's number or brand, e.g.
  /// "Bosch WS10130" — free text, shown next to the type in the picker,
  /// record detail and exports.
  TextColumn get partNumber => text().nullable()();
}

enum RouteMode { trip, freight }

@TableIndex(name: 'idx_routes_vehicle_start', columns: {#vehicleId, #startDate})
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

  /// Sharing (v6): who created it — see [Refuelings.createdBy].
  TextColumn get createdBy => text().nullable()();
}

/// Quick odometer update.
@TableIndex(name: 'idx_readings_vehicle_date', columns: {#vehicleId, #date})
class Readings extends Table with SyncColumns {
  TextColumn get vehicleId => text().references(Vehicles, #id)();
  DateTimeColumn get date => dateTime()();
  RealColumn get odometer => real()();
  TextColumn get driver => text().nullable()();
  TextColumn get notes => text().nullable()();

  /// Sharing (v6): who created it — see [Refuelings.createdBy].
  TextColumn get createdBy => text().nullable()();
}

enum ReminderTarget { expense, service }

enum PeriodUnit { day, month, year }

@TableIndex(name: 'idx_reminders_vehicle', columns: {#vehicleId})
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

  /// Sharing (v6): who created it — see [Refuelings.createdBy].
  TextColumn get createdBy => text().nullable()();
}

// ---------------------------------------------------------------------------
// Checklists (templates = "Forms", plus one filled-in record per run)
// ---------------------------------------------------------------------------

/// A checklist template — what Drivvo calls a "Form" (e.g. "Pre-trip
/// inspection"). Its items live in [ChecklistFormItems].
class ChecklistForms extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get notes => text().nullable()();
}

/// One line of a template, in [position] order.
@TableIndex(name: 'idx_checklist_form_items_form', columns: {#formId})
class ChecklistFormItems extends Table with SyncColumns {
  TextColumn get formId => text().references(ChecklistForms, #id)();
  IntColumn get position => integer()();
  TextColumn get label => text()();
}

/// A filled-in checklist (one inspection run of one vehicle).
///
/// [formId] is only a hint (the template may be deleted later) and [title]
/// is a copy of the template's name at the time, so the record still reads
/// the same after the template is renamed or removed.
@TableIndex(name: 'idx_checklists_vehicle_date', columns: {#vehicleId, #date})
class Checklists extends Table with SyncColumns {
  TextColumn get vehicleId => text().references(Vehicles, #id)();
  DateTimeColumn get date => dateTime()();

  /// Optional, like an expense's odometer. Never used for consumption.
  RealColumn get odometer => real().nullable()();
  TextColumn get formId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get driver => text().nullable()();
  TextColumn get notes => text().nullable()();

  /// Sharing (v6): who created it — see [Refuelings.createdBy].
  TextColumn get createdBy => text().nullable()();
}

/// Result of one checklist line: `ok`, `problem` or `na` (null = not
/// checked yet).
enum ChecklistStatus { ok, problem, na }

/// One answered line of a [Checklists] run. [label] is copied from the
/// template item so later template edits never change past records.
@TableIndex(name: 'idx_checklist_answers_checklist', columns: {#checklistId})
class ChecklistAnswers extends Table with SyncColumns {
  TextColumn get checklistId => text().references(Checklists, #id)();
  IntColumn get position => integer()();
  TextColumn get label => text()();
  TextColumn get status => textEnum<ChecklistStatus>().nullable()();
  TextColumn get note => text().nullable()();
}

// ---------------------------------------------------------------------------
// Attachments (photos / PDFs on any record)
// ---------------------------------------------------------------------------

/// Metadata of a file attached to a record — synced like any other row.
///
/// The record is referenced loosely by ([parentTable], [parentId]) (one
/// attachments table for every module, like a polymorphic relation), so
/// there is no SQL foreign key to the parent. The bytes live in
/// [AttachmentFiles] on this device and, once uploaded, in the Supabase
/// Storage bucket `attachments` at [storagePath]
/// (`<userId>/<attachmentId>/<fileName>`).
@TableIndex(name: 'idx_attachments_parent', columns: {#parentTable, #parentId})
class Attachments extends Table with SyncColumns {
  TextColumn get vehicleId => text().nullable().references(Vehicles, #id)();

  /// SQL name of the parent's table: `refuelings`, `entries`, `routes`,
  /// `readings` or `checklists`.
  TextColumn get parentTable => text()();
  TextColumn get parentId => text()();
  TextColumn get fileName => text()();
  TextColumn get mimeType => text()();
  IntColumn get sizeBytes => integer()();

  /// Set once the file is in cloud storage; null = local only.
  TextColumn get storagePath => text().nullable()();

  /// Sharing (v6): who created it — see [Refuelings.createdBy].
  TextColumn get createdBy => text().nullable()();
}

/// The on-device copy of an attachment's bytes (LOCAL ONLY, never synced).
///
/// A BLOB in SQLite rather than a file on disk, so it works the same on
/// the web (drift's wasm SQLite) and on native, with no filesystem code.
/// Deliberately no `ON DELETE CASCADE`: backup restore rewrites attachment
/// rows with `INSERT OR REPLACE`, which would wipe the bytes.
class AttachmentFiles extends Table {
  TextColumn get attachmentId => text().references(Attachments, #id)();
  BlobColumn get bytes => blob()();

  @override
  Set<Column<Object>> get primaryKey => {attachmentId};
}

// ---------------------------------------------------------------------------
// Sharing (schema v6): custom access profiles and account members
// ---------------------------------------------------------------------------
//
// Synced like every other table, inside the account they belong to (the
// owner's). See docs/SHARING.md and `lib/core/calc/access_profile.dart`.

/// A custom access profile (More → Profiles). The three built-in profiles
/// live in code (`BuiltInProfile`), never in this table. Rows are
/// `AccessProfileRow`s (the pure `AccessProfile` model lives in
/// `core/calc/access_profile.dart`).
@DataClassName('AccessProfileRow')
class AccessProfiles extends Table with SyncColumns {
  TextColumn get name => text()();

  /// `AccessProfile.permissionsToJson()` as JSON text.
  TextColumn get permissions => text()();
}

/// Where an invitation stands. `pending` until the invited user accepts it
/// (server RPC `accept_invitation`), `declined` when they say no,
/// `removed` when the owner/a manager removes them (or they leave).
enum MemberStatus { pending, active, declined, removed }

/// A user invited into this account (More → Users).
///
/// [memberId] and [status] `active` are only ever set by the server when
/// the invited user accepts (a trigger ignores clients that try).
class AccountMembers extends Table with SyncColumns {
  /// The address the invitation was sent to (matched case-insensitively
  /// against the invited user's verified sign-in email).
  TextColumn get email => text()();

  /// Supabase user id, once accepted.
  TextColumn get memberId => text().nullable()();

  /// Display name copied from the member's account on accept.
  TextColumn get memberName => text().nullable()();

  /// A `BuiltInProfile` id or an [AccessProfiles] id.
  TextColumn get profileId => text()();
  TextColumn get status => textEnum<MemberStatus>().withDefault(
    Constant(MemberStatus.pending.name),
  )();

  /// Assigned vehicle ids (JSON array text) — used when the profile's
  /// vehicle scope is "assigned".
  TextColumn get vehicleIds => text().withDefault(const Constant('[]'))();
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

// ---------------------------------------------------------------------------
// Cloud sync bookkeeping (local only, never synced itself)
// ---------------------------------------------------------------------------

/// The sync "outbox": one row per synced record that changed locally and
/// hasn't been uploaded yet — like a queue of dirty rows.
///
/// It is filled by SQLite triggers (see `AppDatabase.createSyncTriggers`),
/// not by feature code, so every insert/update of a synced table is caught
/// automatically, even ones made in the same millisecond as the previous
/// upload or with a device clock that jumped backwards (a timestamp cursor
/// would miss both). The sync engine uploads the queued rows and then
/// deletes exactly the queue entries it read (by [seq]); an edit made while
/// the upload was in flight re-queues the row with a newer [seq], so it is
/// never lost.
@TableIndex(name: 'idx_sync_outbox_table_seq', columns: {#targetTable, #seq})
class SyncOutbox extends Table {
  /// Monotonic queue position (SQLite `AUTOINCREMENT` never reuses values).
  IntColumn get seq => integer().autoIncrement()();

  /// SQL name of the changed table, e.g. `refuelings`.
  TextColumn get targetTable => text()();

  /// `id` of the changed row.
  TextColumn get rowId => text()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {targetTable, rowId},
  ];
}
