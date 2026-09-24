// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $VehiclesTable extends Vehicles with TableInfo<$VehiclesTable, Vehicle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VehiclesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newId,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<VehicleType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<VehicleType>($VehiclesTable.$convertertype);
  static const VerificationMeta _manufacturerMeta = const VerificationMeta(
    'manufacturer',
  );
  @override
  late final GeneratedColumn<String> manufacturer = GeneratedColumn<String>(
    'manufacturer',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plateMeta = const VerificationMeta('plate');
  @override
  late final GeneratedColumn<String> plate = GeneratedColumn<String>(
    'plate',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tankCountMeta = const VerificationMeta(
    'tankCount',
  );
  @override
  late final GeneratedColumn<int> tankCount = GeneratedColumn<int>(
    'tank_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  late final GeneratedColumnWithTypeConverter<FuelKind, String> tank1Kind =
      GeneratedColumn<String>(
        'tank1_kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(FuelKind.liquid.name),
      ).withConverter<FuelKind>($VehiclesTable.$convertertank1Kind);
  static const VerificationMeta _tank1CapacityMeta = const VerificationMeta(
    'tank1Capacity',
  );
  @override
  late final GeneratedColumn<double> tank1Capacity = GeneratedColumn<double>(
    'tank1_capacity',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<FuelKind?, String> tank2Kind =
      GeneratedColumn<String>(
        'tank2_kind',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<FuelKind?>($VehiclesTable.$convertertank2Kindn);
  static const VerificationMeta _tank2CapacityMeta = const VerificationMeta(
    'tank2Capacity',
  );
  @override
  late final GeneratedColumn<double> tank2Capacity = GeneratedColumn<double>(
    'tank2_capacity',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DistanceUnit, String>
  distanceUnit = GeneratedColumn<String>(
    'distance_unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(DistanceUnit.km.name),
  ).withConverter<DistanceUnit>($VehiclesTable.$converterdistanceUnit);
  static const VerificationMeta _vinMeta = const VerificationMeta('vin');
  @override
  late final GeneratedColumn<String> vin = GeneratedColumn<String>(
    'vin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _registrationIdMeta = const VerificationMeta(
    'registrationId',
  );
  @override
  late final GeneratedColumn<String> registrationId = GeneratedColumn<String>(
    'registration_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _purchasePriceMeta = const VerificationMeta(
    'purchasePrice',
  );
  @override
  late final GeneratedColumn<double> purchasePrice = GeneratedColumn<double>(
    'purchase_price',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _salePriceMeta = const VerificationMeta(
    'salePrice',
  );
  @override
  late final GeneratedColumn<double> salePrice = GeneratedColumn<double>(
    'sale_price',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    name,
    type,
    manufacturer,
    model,
    plate,
    year,
    tankCount,
    tank1Kind,
    tank1Capacity,
    tank2Kind,
    tank2Capacity,
    distanceUnit,
    vin,
    registrationId,
    purchasePrice,
    salePrice,
    active,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vehicles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Vehicle> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('manufacturer')) {
      context.handle(
        _manufacturerMeta,
        manufacturer.isAcceptableOrUnknown(
          data['manufacturer']!,
          _manufacturerMeta,
        ),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('plate')) {
      context.handle(
        _plateMeta,
        plate.isAcceptableOrUnknown(data['plate']!, _plateMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('tank_count')) {
      context.handle(
        _tankCountMeta,
        tankCount.isAcceptableOrUnknown(data['tank_count']!, _tankCountMeta),
      );
    }
    if (data.containsKey('tank1_capacity')) {
      context.handle(
        _tank1CapacityMeta,
        tank1Capacity.isAcceptableOrUnknown(
          data['tank1_capacity']!,
          _tank1CapacityMeta,
        ),
      );
    }
    if (data.containsKey('tank2_capacity')) {
      context.handle(
        _tank2CapacityMeta,
        tank2Capacity.isAcceptableOrUnknown(
          data['tank2_capacity']!,
          _tank2CapacityMeta,
        ),
      );
    }
    if (data.containsKey('vin')) {
      context.handle(
        _vinMeta,
        vin.isAcceptableOrUnknown(data['vin']!, _vinMeta),
      );
    }
    if (data.containsKey('registration_id')) {
      context.handle(
        _registrationIdMeta,
        registrationId.isAcceptableOrUnknown(
          data['registration_id']!,
          _registrationIdMeta,
        ),
      );
    }
    if (data.containsKey('purchase_price')) {
      context.handle(
        _purchasePriceMeta,
        purchasePrice.isAcceptableOrUnknown(
          data['purchase_price']!,
          _purchasePriceMeta,
        ),
      );
    }
    if (data.containsKey('sale_price')) {
      context.handle(
        _salePriceMeta,
        salePrice.isAcceptableOrUnknown(data['sale_price']!, _salePriceMeta),
      );
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Vehicle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Vehicle(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: $VehiclesTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      manufacturer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manufacturer'],
      ),
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      ),
      plate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plate'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      tankCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tank_count'],
      )!,
      tank1Kind: $VehiclesTable.$convertertank1Kind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}tank1_kind'],
        )!,
      ),
      tank1Capacity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}tank1_capacity'],
      ),
      tank2Kind: $VehiclesTable.$convertertank2Kindn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}tank2_kind'],
        ),
      ),
      tank2Capacity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}tank2_capacity'],
      ),
      distanceUnit: $VehiclesTable.$converterdistanceUnit.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}distance_unit'],
        )!,
      ),
      vin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vin'],
      ),
      registrationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}registration_id'],
      ),
      purchasePrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}purchase_price'],
      ),
      salePrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sale_price'],
      ),
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $VehiclesTable createAlias(String alias) {
    return $VehiclesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<VehicleType, String, String> $convertertype =
      const EnumNameConverter<VehicleType>(VehicleType.values);
  static JsonTypeConverter2<FuelKind, String, String> $convertertank1Kind =
      const EnumNameConverter<FuelKind>(FuelKind.values);
  static JsonTypeConverter2<FuelKind, String, String> $convertertank2Kind =
      const EnumNameConverter<FuelKind>(FuelKind.values);
  static JsonTypeConverter2<FuelKind?, String?, String?> $convertertank2Kindn =
      JsonTypeConverter2.asNullable($convertertank2Kind);
  static JsonTypeConverter2<DistanceUnit, String, String>
  $converterdistanceUnit = const EnumNameConverter<DistanceUnit>(
    DistanceUnit.values,
  );
}

class Vehicle extends DataClass implements Insertable<Vehicle> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String name;
  final VehicleType type;
  final String? manufacturer;
  final String? model;
  final String? plate;
  final int? year;

  /// 1 or 2 (e.g. flex/bi-fuel vehicles with a gas tank + a CNG tank).
  final int tankCount;
  final FuelKind tank1Kind;
  final double? tank1Capacity;
  final FuelKind? tank2Kind;
  final double? tank2Capacity;
  final DistanceUnit distanceUnit;
  final String? vin;
  final String? registrationId;
  final double? purchasePrice;
  final double? salePrice;
  final bool active;
  final String? notes;
  const Vehicle({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.name,
    required this.type,
    this.manufacturer,
    this.model,
    this.plate,
    this.year,
    required this.tankCount,
    required this.tank1Kind,
    this.tank1Capacity,
    this.tank2Kind,
    this.tank2Capacity,
    required this.distanceUnit,
    this.vin,
    this.registrationId,
    this.purchasePrice,
    this.salePrice,
    required this.active,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['name'] = Variable<String>(name);
    {
      map['type'] = Variable<String>($VehiclesTable.$convertertype.toSql(type));
    }
    if (!nullToAbsent || manufacturer != null) {
      map['manufacturer'] = Variable<String>(manufacturer);
    }
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    if (!nullToAbsent || plate != null) {
      map['plate'] = Variable<String>(plate);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    map['tank_count'] = Variable<int>(tankCount);
    {
      map['tank1_kind'] = Variable<String>(
        $VehiclesTable.$convertertank1Kind.toSql(tank1Kind),
      );
    }
    if (!nullToAbsent || tank1Capacity != null) {
      map['tank1_capacity'] = Variable<double>(tank1Capacity);
    }
    if (!nullToAbsent || tank2Kind != null) {
      map['tank2_kind'] = Variable<String>(
        $VehiclesTable.$convertertank2Kindn.toSql(tank2Kind),
      );
    }
    if (!nullToAbsent || tank2Capacity != null) {
      map['tank2_capacity'] = Variable<double>(tank2Capacity);
    }
    {
      map['distance_unit'] = Variable<String>(
        $VehiclesTable.$converterdistanceUnit.toSql(distanceUnit),
      );
    }
    if (!nullToAbsent || vin != null) {
      map['vin'] = Variable<String>(vin);
    }
    if (!nullToAbsent || registrationId != null) {
      map['registration_id'] = Variable<String>(registrationId);
    }
    if (!nullToAbsent || purchasePrice != null) {
      map['purchase_price'] = Variable<double>(purchasePrice);
    }
    if (!nullToAbsent || salePrice != null) {
      map['sale_price'] = Variable<double>(salePrice);
    }
    map['active'] = Variable<bool>(active);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  VehiclesCompanion toCompanion(bool nullToAbsent) {
    return VehiclesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      name: Value(name),
      type: Value(type),
      manufacturer: manufacturer == null && nullToAbsent
          ? const Value.absent()
          : Value(manufacturer),
      model: model == null && nullToAbsent
          ? const Value.absent()
          : Value(model),
      plate: plate == null && nullToAbsent
          ? const Value.absent()
          : Value(plate),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      tankCount: Value(tankCount),
      tank1Kind: Value(tank1Kind),
      tank1Capacity: tank1Capacity == null && nullToAbsent
          ? const Value.absent()
          : Value(tank1Capacity),
      tank2Kind: tank2Kind == null && nullToAbsent
          ? const Value.absent()
          : Value(tank2Kind),
      tank2Capacity: tank2Capacity == null && nullToAbsent
          ? const Value.absent()
          : Value(tank2Capacity),
      distanceUnit: Value(distanceUnit),
      vin: vin == null && nullToAbsent ? const Value.absent() : Value(vin),
      registrationId: registrationId == null && nullToAbsent
          ? const Value.absent()
          : Value(registrationId),
      purchasePrice: purchasePrice == null && nullToAbsent
          ? const Value.absent()
          : Value(purchasePrice),
      salePrice: salePrice == null && nullToAbsent
          ? const Value.absent()
          : Value(salePrice),
      active: Value(active),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory Vehicle.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Vehicle(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      name: serializer.fromJson<String>(json['name']),
      type: $VehiclesTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      manufacturer: serializer.fromJson<String?>(json['manufacturer']),
      model: serializer.fromJson<String?>(json['model']),
      plate: serializer.fromJson<String?>(json['plate']),
      year: serializer.fromJson<int?>(json['year']),
      tankCount: serializer.fromJson<int>(json['tankCount']),
      tank1Kind: $VehiclesTable.$convertertank1Kind.fromJson(
        serializer.fromJson<String>(json['tank1Kind']),
      ),
      tank1Capacity: serializer.fromJson<double?>(json['tank1Capacity']),
      tank2Kind: $VehiclesTable.$convertertank2Kindn.fromJson(
        serializer.fromJson<String?>(json['tank2Kind']),
      ),
      tank2Capacity: serializer.fromJson<double?>(json['tank2Capacity']),
      distanceUnit: $VehiclesTable.$converterdistanceUnit.fromJson(
        serializer.fromJson<String>(json['distanceUnit']),
      ),
      vin: serializer.fromJson<String?>(json['vin']),
      registrationId: serializer.fromJson<String?>(json['registrationId']),
      purchasePrice: serializer.fromJson<double?>(json['purchasePrice']),
      salePrice: serializer.fromJson<double?>(json['salePrice']),
      active: serializer.fromJson<bool>(json['active']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(
        $VehiclesTable.$convertertype.toJson(type),
      ),
      'manufacturer': serializer.toJson<String?>(manufacturer),
      'model': serializer.toJson<String?>(model),
      'plate': serializer.toJson<String?>(plate),
      'year': serializer.toJson<int?>(year),
      'tankCount': serializer.toJson<int>(tankCount),
      'tank1Kind': serializer.toJson<String>(
        $VehiclesTable.$convertertank1Kind.toJson(tank1Kind),
      ),
      'tank1Capacity': serializer.toJson<double?>(tank1Capacity),
      'tank2Kind': serializer.toJson<String?>(
        $VehiclesTable.$convertertank2Kindn.toJson(tank2Kind),
      ),
      'tank2Capacity': serializer.toJson<double?>(tank2Capacity),
      'distanceUnit': serializer.toJson<String>(
        $VehiclesTable.$converterdistanceUnit.toJson(distanceUnit),
      ),
      'vin': serializer.toJson<String?>(vin),
      'registrationId': serializer.toJson<String?>(registrationId),
      'purchasePrice': serializer.toJson<double?>(purchasePrice),
      'salePrice': serializer.toJson<double?>(salePrice),
      'active': serializer.toJson<bool>(active),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  Vehicle copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? name,
    VehicleType? type,
    Value<String?> manufacturer = const Value.absent(),
    Value<String?> model = const Value.absent(),
    Value<String?> plate = const Value.absent(),
    Value<int?> year = const Value.absent(),
    int? tankCount,
    FuelKind? tank1Kind,
    Value<double?> tank1Capacity = const Value.absent(),
    Value<FuelKind?> tank2Kind = const Value.absent(),
    Value<double?> tank2Capacity = const Value.absent(),
    DistanceUnit? distanceUnit,
    Value<String?> vin = const Value.absent(),
    Value<String?> registrationId = const Value.absent(),
    Value<double?> purchasePrice = const Value.absent(),
    Value<double?> salePrice = const Value.absent(),
    bool? active,
    Value<String?> notes = const Value.absent(),
  }) => Vehicle(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    name: name ?? this.name,
    type: type ?? this.type,
    manufacturer: manufacturer.present ? manufacturer.value : this.manufacturer,
    model: model.present ? model.value : this.model,
    plate: plate.present ? plate.value : this.plate,
    year: year.present ? year.value : this.year,
    tankCount: tankCount ?? this.tankCount,
    tank1Kind: tank1Kind ?? this.tank1Kind,
    tank1Capacity: tank1Capacity.present
        ? tank1Capacity.value
        : this.tank1Capacity,
    tank2Kind: tank2Kind.present ? tank2Kind.value : this.tank2Kind,
    tank2Capacity: tank2Capacity.present
        ? tank2Capacity.value
        : this.tank2Capacity,
    distanceUnit: distanceUnit ?? this.distanceUnit,
    vin: vin.present ? vin.value : this.vin,
    registrationId: registrationId.present
        ? registrationId.value
        : this.registrationId,
    purchasePrice: purchasePrice.present
        ? purchasePrice.value
        : this.purchasePrice,
    salePrice: salePrice.present ? salePrice.value : this.salePrice,
    active: active ?? this.active,
    notes: notes.present ? notes.value : this.notes,
  );
  Vehicle copyWithCompanion(VehiclesCompanion data) {
    return Vehicle(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      manufacturer: data.manufacturer.present
          ? data.manufacturer.value
          : this.manufacturer,
      model: data.model.present ? data.model.value : this.model,
      plate: data.plate.present ? data.plate.value : this.plate,
      year: data.year.present ? data.year.value : this.year,
      tankCount: data.tankCount.present ? data.tankCount.value : this.tankCount,
      tank1Kind: data.tank1Kind.present ? data.tank1Kind.value : this.tank1Kind,
      tank1Capacity: data.tank1Capacity.present
          ? data.tank1Capacity.value
          : this.tank1Capacity,
      tank2Kind: data.tank2Kind.present ? data.tank2Kind.value : this.tank2Kind,
      tank2Capacity: data.tank2Capacity.present
          ? data.tank2Capacity.value
          : this.tank2Capacity,
      distanceUnit: data.distanceUnit.present
          ? data.distanceUnit.value
          : this.distanceUnit,
      vin: data.vin.present ? data.vin.value : this.vin,
      registrationId: data.registrationId.present
          ? data.registrationId.value
          : this.registrationId,
      purchasePrice: data.purchasePrice.present
          ? data.purchasePrice.value
          : this.purchasePrice,
      salePrice: data.salePrice.present ? data.salePrice.value : this.salePrice,
      active: data.active.present ? data.active.value : this.active,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Vehicle(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('manufacturer: $manufacturer, ')
          ..write('model: $model, ')
          ..write('plate: $plate, ')
          ..write('year: $year, ')
          ..write('tankCount: $tankCount, ')
          ..write('tank1Kind: $tank1Kind, ')
          ..write('tank1Capacity: $tank1Capacity, ')
          ..write('tank2Kind: $tank2Kind, ')
          ..write('tank2Capacity: $tank2Capacity, ')
          ..write('distanceUnit: $distanceUnit, ')
          ..write('vin: $vin, ')
          ..write('registrationId: $registrationId, ')
          ..write('purchasePrice: $purchasePrice, ')
          ..write('salePrice: $salePrice, ')
          ..write('active: $active, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    createdAt,
    updatedAt,
    deletedAt,
    name,
    type,
    manufacturer,
    model,
    plate,
    year,
    tankCount,
    tank1Kind,
    tank1Capacity,
    tank2Kind,
    tank2Capacity,
    distanceUnit,
    vin,
    registrationId,
    purchasePrice,
    salePrice,
    active,
    notes,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Vehicle &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.name == this.name &&
          other.type == this.type &&
          other.manufacturer == this.manufacturer &&
          other.model == this.model &&
          other.plate == this.plate &&
          other.year == this.year &&
          other.tankCount == this.tankCount &&
          other.tank1Kind == this.tank1Kind &&
          other.tank1Capacity == this.tank1Capacity &&
          other.tank2Kind == this.tank2Kind &&
          other.tank2Capacity == this.tank2Capacity &&
          other.distanceUnit == this.distanceUnit &&
          other.vin == this.vin &&
          other.registrationId == this.registrationId &&
          other.purchasePrice == this.purchasePrice &&
          other.salePrice == this.salePrice &&
          other.active == this.active &&
          other.notes == this.notes);
}

class VehiclesCompanion extends UpdateCompanion<Vehicle> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> name;
  final Value<VehicleType> type;
  final Value<String?> manufacturer;
  final Value<String?> model;
  final Value<String?> plate;
  final Value<int?> year;
  final Value<int> tankCount;
  final Value<FuelKind> tank1Kind;
  final Value<double?> tank1Capacity;
  final Value<FuelKind?> tank2Kind;
  final Value<double?> tank2Capacity;
  final Value<DistanceUnit> distanceUnit;
  final Value<String?> vin;
  final Value<String?> registrationId;
  final Value<double?> purchasePrice;
  final Value<double?> salePrice;
  final Value<bool> active;
  final Value<String?> notes;
  final Value<int> rowid;
  const VehiclesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.manufacturer = const Value.absent(),
    this.model = const Value.absent(),
    this.plate = const Value.absent(),
    this.year = const Value.absent(),
    this.tankCount = const Value.absent(),
    this.tank1Kind = const Value.absent(),
    this.tank1Capacity = const Value.absent(),
    this.tank2Kind = const Value.absent(),
    this.tank2Capacity = const Value.absent(),
    this.distanceUnit = const Value.absent(),
    this.vin = const Value.absent(),
    this.registrationId = const Value.absent(),
    this.purchasePrice = const Value.absent(),
    this.salePrice = const Value.absent(),
    this.active = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VehiclesCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String name,
    required VehicleType type,
    this.manufacturer = const Value.absent(),
    this.model = const Value.absent(),
    this.plate = const Value.absent(),
    this.year = const Value.absent(),
    this.tankCount = const Value.absent(),
    this.tank1Kind = const Value.absent(),
    this.tank1Capacity = const Value.absent(),
    this.tank2Kind = const Value.absent(),
    this.tank2Capacity = const Value.absent(),
    this.distanceUnit = const Value.absent(),
    this.vin = const Value.absent(),
    this.registrationId = const Value.absent(),
    this.purchasePrice = const Value.absent(),
    this.salePrice = const Value.absent(),
    this.active = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : name = Value(name),
       type = Value(type);
  static Insertable<Vehicle> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? manufacturer,
    Expression<String>? model,
    Expression<String>? plate,
    Expression<int>? year,
    Expression<int>? tankCount,
    Expression<String>? tank1Kind,
    Expression<double>? tank1Capacity,
    Expression<String>? tank2Kind,
    Expression<double>? tank2Capacity,
    Expression<String>? distanceUnit,
    Expression<String>? vin,
    Expression<String>? registrationId,
    Expression<double>? purchasePrice,
    Expression<double>? salePrice,
    Expression<bool>? active,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (manufacturer != null) 'manufacturer': manufacturer,
      if (model != null) 'model': model,
      if (plate != null) 'plate': plate,
      if (year != null) 'year': year,
      if (tankCount != null) 'tank_count': tankCount,
      if (tank1Kind != null) 'tank1_kind': tank1Kind,
      if (tank1Capacity != null) 'tank1_capacity': tank1Capacity,
      if (tank2Kind != null) 'tank2_kind': tank2Kind,
      if (tank2Capacity != null) 'tank2_capacity': tank2Capacity,
      if (distanceUnit != null) 'distance_unit': distanceUnit,
      if (vin != null) 'vin': vin,
      if (registrationId != null) 'registration_id': registrationId,
      if (purchasePrice != null) 'purchase_price': purchasePrice,
      if (salePrice != null) 'sale_price': salePrice,
      if (active != null) 'active': active,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VehiclesCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? name,
    Value<VehicleType>? type,
    Value<String?>? manufacturer,
    Value<String?>? model,
    Value<String?>? plate,
    Value<int?>? year,
    Value<int>? tankCount,
    Value<FuelKind>? tank1Kind,
    Value<double?>? tank1Capacity,
    Value<FuelKind?>? tank2Kind,
    Value<double?>? tank2Capacity,
    Value<DistanceUnit>? distanceUnit,
    Value<String?>? vin,
    Value<String?>? registrationId,
    Value<double?>? purchasePrice,
    Value<double?>? salePrice,
    Value<bool>? active,
    Value<String?>? notes,
    Value<int>? rowid,
  }) {
    return VehiclesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      name: name ?? this.name,
      type: type ?? this.type,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      plate: plate ?? this.plate,
      year: year ?? this.year,
      tankCount: tankCount ?? this.tankCount,
      tank1Kind: tank1Kind ?? this.tank1Kind,
      tank1Capacity: tank1Capacity ?? this.tank1Capacity,
      tank2Kind: tank2Kind ?? this.tank2Kind,
      tank2Capacity: tank2Capacity ?? this.tank2Capacity,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      vin: vin ?? this.vin,
      registrationId: registrationId ?? this.registrationId,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      salePrice: salePrice ?? this.salePrice,
      active: active ?? this.active,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $VehiclesTable.$convertertype.toSql(type.value),
      );
    }
    if (manufacturer.present) {
      map['manufacturer'] = Variable<String>(manufacturer.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (plate.present) {
      map['plate'] = Variable<String>(plate.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (tankCount.present) {
      map['tank_count'] = Variable<int>(tankCount.value);
    }
    if (tank1Kind.present) {
      map['tank1_kind'] = Variable<String>(
        $VehiclesTable.$convertertank1Kind.toSql(tank1Kind.value),
      );
    }
    if (tank1Capacity.present) {
      map['tank1_capacity'] = Variable<double>(tank1Capacity.value);
    }
    if (tank2Kind.present) {
      map['tank2_kind'] = Variable<String>(
        $VehiclesTable.$convertertank2Kindn.toSql(tank2Kind.value),
      );
    }
    if (tank2Capacity.present) {
      map['tank2_capacity'] = Variable<double>(tank2Capacity.value);
    }
    if (distanceUnit.present) {
      map['distance_unit'] = Variable<String>(
        $VehiclesTable.$converterdistanceUnit.toSql(distanceUnit.value),
      );
    }
    if (vin.present) {
      map['vin'] = Variable<String>(vin.value);
    }
    if (registrationId.present) {
      map['registration_id'] = Variable<String>(registrationId.value);
    }
    if (purchasePrice.present) {
      map['purchase_price'] = Variable<double>(purchasePrice.value);
    }
    if (salePrice.present) {
      map['sale_price'] = Variable<double>(salePrice.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VehiclesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('manufacturer: $manufacturer, ')
          ..write('model: $model, ')
          ..write('plate: $plate, ')
          ..write('year: $year, ')
          ..write('tankCount: $tankCount, ')
          ..write('tank1Kind: $tank1Kind, ')
          ..write('tank1Capacity: $tank1Capacity, ')
          ..write('tank2Kind: $tank2Kind, ')
          ..write('tank2Capacity: $tank2Capacity, ')
          ..write('distanceUnit: $distanceUnit, ')
          ..write('vin: $vin, ')
          ..write('registrationId: $registrationId, ')
          ..write('purchasePrice: $purchasePrice, ')
          ..write('salePrice: $salePrice, ')
          ..write('active: $active, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatalogItemsTable extends CatalogItems
    with TableInfo<$CatalogItemsTable, CatalogItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatalogItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newId,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CatalogKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CatalogKind>($CatalogItemsTable.$converterkind);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<FuelKind?, String> fuelKind =
      GeneratedColumn<String>(
        'fuel_kind',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<FuelKind?>($CatalogItemsTable.$converterfuelKindn);
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    kind,
    name,
    fuelKind,
    address,
    latitude,
    longitude,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catalog_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatalogItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CatalogItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      kind: $CatalogItemsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      fuelKind: $CatalogItemsTable.$converterfuelKindn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}fuel_kind'],
        ),
      ),
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
    );
  }

  @override
  $CatalogItemsTable createAlias(String alias) {
    return $CatalogItemsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CatalogKind, String, String> $converterkind =
      const EnumNameConverter<CatalogKind>(CatalogKind.values);
  static JsonTypeConverter2<FuelKind, String, String> $converterfuelKind =
      const EnumNameConverter<FuelKind>(FuelKind.values);
  static JsonTypeConverter2<FuelKind?, String?, String?> $converterfuelKindn =
      JsonTypeConverter2.asNullable($converterfuelKind);
}

class CatalogItem extends DataClass implements Insertable<CatalogItem> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final CatalogKind kind;
  final String name;

  /// Only for fuels: which tank kind this fuel belongs to.
  final FuelKind? fuelKind;

  /// Only for gas stations / places.
  final String? address;
  final double? latitude;
  final double? longitude;
  const CatalogItem({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.kind,
    required this.name,
    this.fuelKind,
    this.address,
    this.latitude,
    this.longitude,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    {
      map['kind'] = Variable<String>(
        $CatalogItemsTable.$converterkind.toSql(kind),
      );
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || fuelKind != null) {
      map['fuel_kind'] = Variable<String>(
        $CatalogItemsTable.$converterfuelKindn.toSql(fuelKind),
      );
    }
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    return map;
  }

  CatalogItemsCompanion toCompanion(bool nullToAbsent) {
    return CatalogItemsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      kind: Value(kind),
      name: Value(name),
      fuelKind: fuelKind == null && nullToAbsent
          ? const Value.absent()
          : Value(fuelKind),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
    );
  }

  factory CatalogItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatalogItem(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      kind: $CatalogItemsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      name: serializer.fromJson<String>(json['name']),
      fuelKind: $CatalogItemsTable.$converterfuelKindn.fromJson(
        serializer.fromJson<String?>(json['fuelKind']),
      ),
      address: serializer.fromJson<String?>(json['address']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'kind': serializer.toJson<String>(
        $CatalogItemsTable.$converterkind.toJson(kind),
      ),
      'name': serializer.toJson<String>(name),
      'fuelKind': serializer.toJson<String?>(
        $CatalogItemsTable.$converterfuelKindn.toJson(fuelKind),
      ),
      'address': serializer.toJson<String?>(address),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
    };
  }

  CatalogItem copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    CatalogKind? kind,
    String? name,
    Value<FuelKind?> fuelKind = const Value.absent(),
    Value<String?> address = const Value.absent(),
    Value<double?> latitude = const Value.absent(),
    Value<double?> longitude = const Value.absent(),
  }) => CatalogItem(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    fuelKind: fuelKind.present ? fuelKind.value : this.fuelKind,
    address: address.present ? address.value : this.address,
    latitude: latitude.present ? latitude.value : this.latitude,
    longitude: longitude.present ? longitude.value : this.longitude,
  );
  CatalogItem copyWithCompanion(CatalogItemsCompanion data) {
    return CatalogItem(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      fuelKind: data.fuelKind.present ? data.fuelKind.value : this.fuelKind,
      address: data.address.present ? data.address.value : this.address,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatalogItem(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('fuelKind: $fuelKind, ')
          ..write('address: $address, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    kind,
    name,
    fuelKind,
    address,
    latitude,
    longitude,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogItem &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.fuelKind == this.fuelKind &&
          other.address == this.address &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude);
}

class CatalogItemsCompanion extends UpdateCompanion<CatalogItem> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<CatalogKind> kind;
  final Value<String> name;
  final Value<FuelKind?> fuelKind;
  final Value<String?> address;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<int> rowid;
  const CatalogItemsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.fuelKind = const Value.absent(),
    this.address = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatalogItemsCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required CatalogKind kind,
    required String name,
    this.fuelKind = const Value.absent(),
    this.address = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : kind = Value(kind),
       name = Value(name);
  static Insertable<CatalogItem> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<String>? fuelKind,
    Expression<String>? address,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (fuelKind != null) 'fuel_kind': fuelKind,
      if (address != null) 'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatalogItemsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<CatalogKind>? kind,
    Value<String>? name,
    Value<FuelKind?>? fuelKind,
    Value<String?>? address,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<int>? rowid,
  }) {
    return CatalogItemsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      fuelKind: fuelKind ?? this.fuelKind,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $CatalogItemsTable.$converterkind.toSql(kind.value),
      );
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (fuelKind.present) {
      map['fuel_kind'] = Variable<String>(
        $CatalogItemsTable.$converterfuelKindn.toSql(fuelKind.value),
      );
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatalogItemsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('fuelKind: $fuelKind, ')
          ..write('address: $address, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RefuelingsTable extends Refuelings
    with TableInfo<$RefuelingsTable, Refueling> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RefuelingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newId,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vehicles (id)',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _odometerMeta = const VerificationMeta(
    'odometer',
  );
  @override
  late final GeneratedColumn<double> odometer = GeneratedColumn<double>(
    'odometer',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fullTankMeta = const VerificationMeta(
    'fullTank',
  );
  @override
  late final GeneratedColumn<bool> fullTank = GeneratedColumn<bool>(
    'full_tank',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("full_tank" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _missedPreviousMeta = const VerificationMeta(
    'missedPrevious',
  );
  @override
  late final GeneratedColumn<bool> missedPrevious = GeneratedColumn<bool>(
    'missed_previous',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("missed_previous" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _gasStationIdMeta = const VerificationMeta(
    'gasStationId',
  );
  @override
  late final GeneratedColumn<String> gasStationId = GeneratedColumn<String>(
    'gas_station_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES catalog_items (id)',
    ),
  );
  static const VerificationMeta _paymentMethodIdMeta = const VerificationMeta(
    'paymentMethodId',
  );
  @override
  late final GeneratedColumn<String> paymentMethodId = GeneratedColumn<String>(
    'payment_method_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES catalog_items (id)',
    ),
  );
  static const VerificationMeta _reasonIdMeta = const VerificationMeta(
    'reasonId',
  );
  @override
  late final GeneratedColumn<String> reasonId = GeneratedColumn<String>(
    'reason_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES catalog_items (id)',
    ),
  );
  static const VerificationMeta _driverMeta = const VerificationMeta('driver');
  @override
  late final GeneratedColumn<String> driver = GeneratedColumn<String>(
    'driver',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _discountMeta = const VerificationMeta(
    'discount',
  );
  @override
  late final GeneratedColumn<double> discount = GeneratedColumn<double>(
    'discount',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalCostMeta = const VerificationMeta(
    'totalCost',
  );
  @override
  late final GeneratedColumn<double> totalCost = GeneratedColumn<double>(
    'total_cost',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    vehicleId,
    date,
    odometer,
    fullTank,
    missedPrevious,
    gasStationId,
    paymentMethodId,
    reasonId,
    driver,
    discount,
    totalCost,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'refuelings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Refueling> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('odometer')) {
      context.handle(
        _odometerMeta,
        odometer.isAcceptableOrUnknown(data['odometer']!, _odometerMeta),
      );
    } else if (isInserting) {
      context.missing(_odometerMeta);
    }
    if (data.containsKey('full_tank')) {
      context.handle(
        _fullTankMeta,
        fullTank.isAcceptableOrUnknown(data['full_tank']!, _fullTankMeta),
      );
    }
    if (data.containsKey('missed_previous')) {
      context.handle(
        _missedPreviousMeta,
        missedPrevious.isAcceptableOrUnknown(
          data['missed_previous']!,
          _missedPreviousMeta,
        ),
      );
    }
    if (data.containsKey('gas_station_id')) {
      context.handle(
        _gasStationIdMeta,
        gasStationId.isAcceptableOrUnknown(
          data['gas_station_id']!,
          _gasStationIdMeta,
        ),
      );
    }
    if (data.containsKey('payment_method_id')) {
      context.handle(
        _paymentMethodIdMeta,
        paymentMethodId.isAcceptableOrUnknown(
          data['payment_method_id']!,
          _paymentMethodIdMeta,
        ),
      );
    }
    if (data.containsKey('reason_id')) {
      context.handle(
        _reasonIdMeta,
        reasonId.isAcceptableOrUnknown(data['reason_id']!, _reasonIdMeta),
      );
    }
    if (data.containsKey('driver')) {
      context.handle(
        _driverMeta,
        driver.isAcceptableOrUnknown(data['driver']!, _driverMeta),
      );
    }
    if (data.containsKey('discount')) {
      context.handle(
        _discountMeta,
        discount.isAcceptableOrUnknown(data['discount']!, _discountMeta),
      );
    }
    if (data.containsKey('total_cost')) {
      context.handle(
        _totalCostMeta,
        totalCost.isAcceptableOrUnknown(data['total_cost']!, _totalCostMeta),
      );
    } else if (isInserting) {
      context.missing(_totalCostMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Refueling map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Refueling(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      odometer: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}odometer'],
      )!,
      fullTank: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}full_tank'],
      )!,
      missedPrevious: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}missed_previous'],
      )!,
      gasStationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gas_station_id'],
      ),
      paymentMethodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_method_id'],
      ),
      reasonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason_id'],
      ),
      driver: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}driver'],
      ),
      discount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}discount'],
      ),
      totalCost: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_cost'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $RefuelingsTable createAlias(String alias) {
    return $RefuelingsTable(attachedDatabase, alias);
  }
}

class Refueling extends DataClass implements Insertable<Refueling> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String vehicleId;
  final DateTime date;
  final double odometer;
  final bool fullTank;
  final bool missedPrevious;
  final String? gasStationId;
  final String? paymentMethodId;
  final String? reasonId;
  final String? driver;
  final double? discount;

  /// Sum of all fuel lines minus discount (denormalized for fast lists).
  final double totalCost;
  final String? notes;
  const Refueling({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.vehicleId,
    required this.date,
    required this.odometer,
    required this.fullTank,
    required this.missedPrevious,
    this.gasStationId,
    this.paymentMethodId,
    this.reasonId,
    this.driver,
    this.discount,
    required this.totalCost,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['vehicle_id'] = Variable<String>(vehicleId);
    map['date'] = Variable<DateTime>(date);
    map['odometer'] = Variable<double>(odometer);
    map['full_tank'] = Variable<bool>(fullTank);
    map['missed_previous'] = Variable<bool>(missedPrevious);
    if (!nullToAbsent || gasStationId != null) {
      map['gas_station_id'] = Variable<String>(gasStationId);
    }
    if (!nullToAbsent || paymentMethodId != null) {
      map['payment_method_id'] = Variable<String>(paymentMethodId);
    }
    if (!nullToAbsent || reasonId != null) {
      map['reason_id'] = Variable<String>(reasonId);
    }
    if (!nullToAbsent || driver != null) {
      map['driver'] = Variable<String>(driver);
    }
    if (!nullToAbsent || discount != null) {
      map['discount'] = Variable<double>(discount);
    }
    map['total_cost'] = Variable<double>(totalCost);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  RefuelingsCompanion toCompanion(bool nullToAbsent) {
    return RefuelingsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      vehicleId: Value(vehicleId),
      date: Value(date),
      odometer: Value(odometer),
      fullTank: Value(fullTank),
      missedPrevious: Value(missedPrevious),
      gasStationId: gasStationId == null && nullToAbsent
          ? const Value.absent()
          : Value(gasStationId),
      paymentMethodId: paymentMethodId == null && nullToAbsent
          ? const Value.absent()
          : Value(paymentMethodId),
      reasonId: reasonId == null && nullToAbsent
          ? const Value.absent()
          : Value(reasonId),
      driver: driver == null && nullToAbsent
          ? const Value.absent()
          : Value(driver),
      discount: discount == null && nullToAbsent
          ? const Value.absent()
          : Value(discount),
      totalCost: Value(totalCost),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory Refueling.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Refueling(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      vehicleId: serializer.fromJson<String>(json['vehicleId']),
      date: serializer.fromJson<DateTime>(json['date']),
      odometer: serializer.fromJson<double>(json['odometer']),
      fullTank: serializer.fromJson<bool>(json['fullTank']),
      missedPrevious: serializer.fromJson<bool>(json['missedPrevious']),
      gasStationId: serializer.fromJson<String?>(json['gasStationId']),
      paymentMethodId: serializer.fromJson<String?>(json['paymentMethodId']),
      reasonId: serializer.fromJson<String?>(json['reasonId']),
      driver: serializer.fromJson<String?>(json['driver']),
      discount: serializer.fromJson<double?>(json['discount']),
      totalCost: serializer.fromJson<double>(json['totalCost']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'vehicleId': serializer.toJson<String>(vehicleId),
      'date': serializer.toJson<DateTime>(date),
      'odometer': serializer.toJson<double>(odometer),
      'fullTank': serializer.toJson<bool>(fullTank),
      'missedPrevious': serializer.toJson<bool>(missedPrevious),
      'gasStationId': serializer.toJson<String?>(gasStationId),
      'paymentMethodId': serializer.toJson<String?>(paymentMethodId),
      'reasonId': serializer.toJson<String?>(reasonId),
      'driver': serializer.toJson<String?>(driver),
      'discount': serializer.toJson<double?>(discount),
      'totalCost': serializer.toJson<double>(totalCost),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  Refueling copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? vehicleId,
    DateTime? date,
    double? odometer,
    bool? fullTank,
    bool? missedPrevious,
    Value<String?> gasStationId = const Value.absent(),
    Value<String?> paymentMethodId = const Value.absent(),
    Value<String?> reasonId = const Value.absent(),
    Value<String?> driver = const Value.absent(),
    Value<double?> discount = const Value.absent(),
    double? totalCost,
    Value<String?> notes = const Value.absent(),
  }) => Refueling(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    vehicleId: vehicleId ?? this.vehicleId,
    date: date ?? this.date,
    odometer: odometer ?? this.odometer,
    fullTank: fullTank ?? this.fullTank,
    missedPrevious: missedPrevious ?? this.missedPrevious,
    gasStationId: gasStationId.present ? gasStationId.value : this.gasStationId,
    paymentMethodId: paymentMethodId.present
        ? paymentMethodId.value
        : this.paymentMethodId,
    reasonId: reasonId.present ? reasonId.value : this.reasonId,
    driver: driver.present ? driver.value : this.driver,
    discount: discount.present ? discount.value : this.discount,
    totalCost: totalCost ?? this.totalCost,
    notes: notes.present ? notes.value : this.notes,
  );
  Refueling copyWithCompanion(RefuelingsCompanion data) {
    return Refueling(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      date: data.date.present ? data.date.value : this.date,
      odometer: data.odometer.present ? data.odometer.value : this.odometer,
      fullTank: data.fullTank.present ? data.fullTank.value : this.fullTank,
      missedPrevious: data.missedPrevious.present
          ? data.missedPrevious.value
          : this.missedPrevious,
      gasStationId: data.gasStationId.present
          ? data.gasStationId.value
          : this.gasStationId,
      paymentMethodId: data.paymentMethodId.present
          ? data.paymentMethodId.value
          : this.paymentMethodId,
      reasonId: data.reasonId.present ? data.reasonId.value : this.reasonId,
      driver: data.driver.present ? data.driver.value : this.driver,
      discount: data.discount.present ? data.discount.value : this.discount,
      totalCost: data.totalCost.present ? data.totalCost.value : this.totalCost,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Refueling(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('date: $date, ')
          ..write('odometer: $odometer, ')
          ..write('fullTank: $fullTank, ')
          ..write('missedPrevious: $missedPrevious, ')
          ..write('gasStationId: $gasStationId, ')
          ..write('paymentMethodId: $paymentMethodId, ')
          ..write('reasonId: $reasonId, ')
          ..write('driver: $driver, ')
          ..write('discount: $discount, ')
          ..write('totalCost: $totalCost, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    vehicleId,
    date,
    odometer,
    fullTank,
    missedPrevious,
    gasStationId,
    paymentMethodId,
    reasonId,
    driver,
    discount,
    totalCost,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Refueling &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.vehicleId == this.vehicleId &&
          other.date == this.date &&
          other.odometer == this.odometer &&
          other.fullTank == this.fullTank &&
          other.missedPrevious == this.missedPrevious &&
          other.gasStationId == this.gasStationId &&
          other.paymentMethodId == this.paymentMethodId &&
          other.reasonId == this.reasonId &&
          other.driver == this.driver &&
          other.discount == this.discount &&
          other.totalCost == this.totalCost &&
          other.notes == this.notes);
}

class RefuelingsCompanion extends UpdateCompanion<Refueling> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> vehicleId;
  final Value<DateTime> date;
  final Value<double> odometer;
  final Value<bool> fullTank;
  final Value<bool> missedPrevious;
  final Value<String?> gasStationId;
  final Value<String?> paymentMethodId;
  final Value<String?> reasonId;
  final Value<String?> driver;
  final Value<double?> discount;
  final Value<double> totalCost;
  final Value<String?> notes;
  final Value<int> rowid;
  const RefuelingsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.date = const Value.absent(),
    this.odometer = const Value.absent(),
    this.fullTank = const Value.absent(),
    this.missedPrevious = const Value.absent(),
    this.gasStationId = const Value.absent(),
    this.paymentMethodId = const Value.absent(),
    this.reasonId = const Value.absent(),
    this.driver = const Value.absent(),
    this.discount = const Value.absent(),
    this.totalCost = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RefuelingsCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String vehicleId,
    required DateTime date,
    required double odometer,
    this.fullTank = const Value.absent(),
    this.missedPrevious = const Value.absent(),
    this.gasStationId = const Value.absent(),
    this.paymentMethodId = const Value.absent(),
    this.reasonId = const Value.absent(),
    this.driver = const Value.absent(),
    this.discount = const Value.absent(),
    required double totalCost,
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : vehicleId = Value(vehicleId),
       date = Value(date),
       odometer = Value(odometer),
       totalCost = Value(totalCost);
  static Insertable<Refueling> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? vehicleId,
    Expression<DateTime>? date,
    Expression<double>? odometer,
    Expression<bool>? fullTank,
    Expression<bool>? missedPrevious,
    Expression<String>? gasStationId,
    Expression<String>? paymentMethodId,
    Expression<String>? reasonId,
    Expression<String>? driver,
    Expression<double>? discount,
    Expression<double>? totalCost,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (date != null) 'date': date,
      if (odometer != null) 'odometer': odometer,
      if (fullTank != null) 'full_tank': fullTank,
      if (missedPrevious != null) 'missed_previous': missedPrevious,
      if (gasStationId != null) 'gas_station_id': gasStationId,
      if (paymentMethodId != null) 'payment_method_id': paymentMethodId,
      if (reasonId != null) 'reason_id': reasonId,
      if (driver != null) 'driver': driver,
      if (discount != null) 'discount': discount,
      if (totalCost != null) 'total_cost': totalCost,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RefuelingsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? vehicleId,
    Value<DateTime>? date,
    Value<double>? odometer,
    Value<bool>? fullTank,
    Value<bool>? missedPrevious,
    Value<String?>? gasStationId,
    Value<String?>? paymentMethodId,
    Value<String?>? reasonId,
    Value<String?>? driver,
    Value<double?>? discount,
    Value<double>? totalCost,
    Value<String?>? notes,
    Value<int>? rowid,
  }) {
    return RefuelingsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      vehicleId: vehicleId ?? this.vehicleId,
      date: date ?? this.date,
      odometer: odometer ?? this.odometer,
      fullTank: fullTank ?? this.fullTank,
      missedPrevious: missedPrevious ?? this.missedPrevious,
      gasStationId: gasStationId ?? this.gasStationId,
      paymentMethodId: paymentMethodId ?? this.paymentMethodId,
      reasonId: reasonId ?? this.reasonId,
      driver: driver ?? this.driver,
      discount: discount ?? this.discount,
      totalCost: totalCost ?? this.totalCost,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (odometer.present) {
      map['odometer'] = Variable<double>(odometer.value);
    }
    if (fullTank.present) {
      map['full_tank'] = Variable<bool>(fullTank.value);
    }
    if (missedPrevious.present) {
      map['missed_previous'] = Variable<bool>(missedPrevious.value);
    }
    if (gasStationId.present) {
      map['gas_station_id'] = Variable<String>(gasStationId.value);
    }
    if (paymentMethodId.present) {
      map['payment_method_id'] = Variable<String>(paymentMethodId.value);
    }
    if (reasonId.present) {
      map['reason_id'] = Variable<String>(reasonId.value);
    }
    if (driver.present) {
      map['driver'] = Variable<String>(driver.value);
    }
    if (discount.present) {
      map['discount'] = Variable<double>(discount.value);
    }
    if (totalCost.present) {
      map['total_cost'] = Variable<double>(totalCost.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RefuelingsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('date: $date, ')
          ..write('odometer: $odometer, ')
          ..write('fullTank: $fullTank, ')
          ..write('missedPrevious: $missedPrevious, ')
          ..write('gasStationId: $gasStationId, ')
          ..write('paymentMethodId: $paymentMethodId, ')
          ..write('reasonId: $reasonId, ')
          ..write('driver: $driver, ')
          ..write('discount: $discount, ')
          ..write('totalCost: $totalCost, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RefuelingFuelsTable extends RefuelingFuels
    with TableInfo<$RefuelingFuelsTable, RefuelingFuel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RefuelingFuelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newId,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _refuelingIdMeta = const VerificationMeta(
    'refuelingId',
  );
  @override
  late final GeneratedColumn<String> refuelingId = GeneratedColumn<String>(
    'refueling_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES refuelings (id)',
    ),
  );
  static const VerificationMeta _fuelIdMeta = const VerificationMeta('fuelId');
  @override
  late final GeneratedColumn<String> fuelId = GeneratedColumn<String>(
    'fuel_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES catalog_items (id)',
    ),
  );
  static const VerificationMeta _pricePerUnitMeta = const VerificationMeta(
    'pricePerUnit',
  );
  @override
  late final GeneratedColumn<double> pricePerUnit = GeneratedColumn<double>(
    'price_per_unit',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<double> total = GeneratedColumn<double>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _volumeMeta = const VerificationMeta('volume');
  @override
  late final GeneratedColumn<double> volume = GeneratedColumn<double>(
    'volume',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tankMeta = const VerificationMeta('tank');
  @override
  late final GeneratedColumn<int> tank = GeneratedColumn<int>(
    'tank',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    refuelingId,
    fuelId,
    pricePerUnit,
    total,
    volume,
    tank,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'refueling_fuels';
  @override
  VerificationContext validateIntegrity(
    Insertable<RefuelingFuel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('refueling_id')) {
      context.handle(
        _refuelingIdMeta,
        refuelingId.isAcceptableOrUnknown(
          data['refueling_id']!,
          _refuelingIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_refuelingIdMeta);
    }
    if (data.containsKey('fuel_id')) {
      context.handle(
        _fuelIdMeta,
        fuelId.isAcceptableOrUnknown(data['fuel_id']!, _fuelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_fuelIdMeta);
    }
    if (data.containsKey('price_per_unit')) {
      context.handle(
        _pricePerUnitMeta,
        pricePerUnit.isAcceptableOrUnknown(
          data['price_per_unit']!,
          _pricePerUnitMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pricePerUnitMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    if (data.containsKey('volume')) {
      context.handle(
        _volumeMeta,
        volume.isAcceptableOrUnknown(data['volume']!, _volumeMeta),
      );
    } else if (isInserting) {
      context.missing(_volumeMeta);
    }
    if (data.containsKey('tank')) {
      context.handle(
        _tankMeta,
        tank.isAcceptableOrUnknown(data['tank']!, _tankMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RefuelingFuel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RefuelingFuel(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      refuelingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}refueling_id'],
      )!,
      fuelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fuel_id'],
      )!,
      pricePerUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}price_per_unit'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total'],
      )!,
      volume: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}volume'],
      )!,
      tank: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tank'],
      )!,
    );
  }

  @override
  $RefuelingFuelsTable createAlias(String alias) {
    return $RefuelingFuelsTable(attachedDatabase, alias);
  }
}

class RefuelingFuel extends DataClass implements Insertable<RefuelingFuel> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String refuelingId;
  final String fuelId;
  final double pricePerUnit;
  final double total;
  final double volume;

  /// Which tank (1 or 2) this fuel went into.
  final int tank;
  const RefuelingFuel({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.refuelingId,
    required this.fuelId,
    required this.pricePerUnit,
    required this.total,
    required this.volume,
    required this.tank,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['refueling_id'] = Variable<String>(refuelingId);
    map['fuel_id'] = Variable<String>(fuelId);
    map['price_per_unit'] = Variable<double>(pricePerUnit);
    map['total'] = Variable<double>(total);
    map['volume'] = Variable<double>(volume);
    map['tank'] = Variable<int>(tank);
    return map;
  }

  RefuelingFuelsCompanion toCompanion(bool nullToAbsent) {
    return RefuelingFuelsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      refuelingId: Value(refuelingId),
      fuelId: Value(fuelId),
      pricePerUnit: Value(pricePerUnit),
      total: Value(total),
      volume: Value(volume),
      tank: Value(tank),
    );
  }

  factory RefuelingFuel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RefuelingFuel(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      refuelingId: serializer.fromJson<String>(json['refuelingId']),
      fuelId: serializer.fromJson<String>(json['fuelId']),
      pricePerUnit: serializer.fromJson<double>(json['pricePerUnit']),
      total: serializer.fromJson<double>(json['total']),
      volume: serializer.fromJson<double>(json['volume']),
      tank: serializer.fromJson<int>(json['tank']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'refuelingId': serializer.toJson<String>(refuelingId),
      'fuelId': serializer.toJson<String>(fuelId),
      'pricePerUnit': serializer.toJson<double>(pricePerUnit),
      'total': serializer.toJson<double>(total),
      'volume': serializer.toJson<double>(volume),
      'tank': serializer.toJson<int>(tank),
    };
  }

  RefuelingFuel copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? refuelingId,
    String? fuelId,
    double? pricePerUnit,
    double? total,
    double? volume,
    int? tank,
  }) => RefuelingFuel(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    refuelingId: refuelingId ?? this.refuelingId,
    fuelId: fuelId ?? this.fuelId,
    pricePerUnit: pricePerUnit ?? this.pricePerUnit,
    total: total ?? this.total,
    volume: volume ?? this.volume,
    tank: tank ?? this.tank,
  );
  RefuelingFuel copyWithCompanion(RefuelingFuelsCompanion data) {
    return RefuelingFuel(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      refuelingId: data.refuelingId.present
          ? data.refuelingId.value
          : this.refuelingId,
      fuelId: data.fuelId.present ? data.fuelId.value : this.fuelId,
      pricePerUnit: data.pricePerUnit.present
          ? data.pricePerUnit.value
          : this.pricePerUnit,
      total: data.total.present ? data.total.value : this.total,
      volume: data.volume.present ? data.volume.value : this.volume,
      tank: data.tank.present ? data.tank.value : this.tank,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RefuelingFuel(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('refuelingId: $refuelingId, ')
          ..write('fuelId: $fuelId, ')
          ..write('pricePerUnit: $pricePerUnit, ')
          ..write('total: $total, ')
          ..write('volume: $volume, ')
          ..write('tank: $tank')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    refuelingId,
    fuelId,
    pricePerUnit,
    total,
    volume,
    tank,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RefuelingFuel &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.refuelingId == this.refuelingId &&
          other.fuelId == this.fuelId &&
          other.pricePerUnit == this.pricePerUnit &&
          other.total == this.total &&
          other.volume == this.volume &&
          other.tank == this.tank);
}

class RefuelingFuelsCompanion extends UpdateCompanion<RefuelingFuel> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> refuelingId;
  final Value<String> fuelId;
  final Value<double> pricePerUnit;
  final Value<double> total;
  final Value<double> volume;
  final Value<int> tank;
  final Value<int> rowid;
  const RefuelingFuelsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.refuelingId = const Value.absent(),
    this.fuelId = const Value.absent(),
    this.pricePerUnit = const Value.absent(),
    this.total = const Value.absent(),
    this.volume = const Value.absent(),
    this.tank = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RefuelingFuelsCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String refuelingId,
    required String fuelId,
    required double pricePerUnit,
    required double total,
    required double volume,
    this.tank = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : refuelingId = Value(refuelingId),
       fuelId = Value(fuelId),
       pricePerUnit = Value(pricePerUnit),
       total = Value(total),
       volume = Value(volume);
  static Insertable<RefuelingFuel> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? refuelingId,
    Expression<String>? fuelId,
    Expression<double>? pricePerUnit,
    Expression<double>? total,
    Expression<double>? volume,
    Expression<int>? tank,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (refuelingId != null) 'refueling_id': refuelingId,
      if (fuelId != null) 'fuel_id': fuelId,
      if (pricePerUnit != null) 'price_per_unit': pricePerUnit,
      if (total != null) 'total': total,
      if (volume != null) 'volume': volume,
      if (tank != null) 'tank': tank,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RefuelingFuelsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? refuelingId,
    Value<String>? fuelId,
    Value<double>? pricePerUnit,
    Value<double>? total,
    Value<double>? volume,
    Value<int>? tank,
    Value<int>? rowid,
  }) {
    return RefuelingFuelsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      refuelingId: refuelingId ?? this.refuelingId,
      fuelId: fuelId ?? this.fuelId,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      total: total ?? this.total,
      volume: volume ?? this.volume,
      tank: tank ?? this.tank,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (refuelingId.present) {
      map['refueling_id'] = Variable<String>(refuelingId.value);
    }
    if (fuelId.present) {
      map['fuel_id'] = Variable<String>(fuelId.value);
    }
    if (pricePerUnit.present) {
      map['price_per_unit'] = Variable<double>(pricePerUnit.value);
    }
    if (total.present) {
      map['total'] = Variable<double>(total.value);
    }
    if (volume.present) {
      map['volume'] = Variable<double>(volume.value);
    }
    if (tank.present) {
      map['tank'] = Variable<int>(tank.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RefuelingFuelsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('refuelingId: $refuelingId, ')
          ..write('fuelId: $fuelId, ')
          ..write('pricePerUnit: $pricePerUnit, ')
          ..write('total: $total, ')
          ..write('volume: $volume, ')
          ..write('tank: $tank, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EntriesTable extends Entries with TableInfo<$EntriesTable, Entry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newId,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vehicles (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<EntryKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<EntryKind>($EntriesTable.$converterkind);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _odometerMeta = const VerificationMeta(
    'odometer',
  );
  @override
  late final GeneratedColumn<double> odometer = GeneratedColumn<double>(
    'odometer',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _placeIdMeta = const VerificationMeta(
    'placeId',
  );
  @override
  late final GeneratedColumn<String> placeId = GeneratedColumn<String>(
    'place_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES catalog_items (id)',
    ),
  );
  static const VerificationMeta _paymentMethodIdMeta = const VerificationMeta(
    'paymentMethodId',
  );
  @override
  late final GeneratedColumn<String> paymentMethodId = GeneratedColumn<String>(
    'payment_method_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES catalog_items (id)',
    ),
  );
  static const VerificationMeta _reasonIdMeta = const VerificationMeta(
    'reasonId',
  );
  @override
  late final GeneratedColumn<String> reasonId = GeneratedColumn<String>(
    'reason_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES catalog_items (id)',
    ),
  );
  static const VerificationMeta _driverMeta = const VerificationMeta('driver');
  @override
  late final GeneratedColumn<String> driver = GeneratedColumn<String>(
    'driver',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _discountMeta = const VerificationMeta(
    'discount',
  );
  @override
  late final GeneratedColumn<double> discount = GeneratedColumn<double>(
    'discount',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalCostMeta = const VerificationMeta(
    'totalCost',
  );
  @override
  late final GeneratedColumn<double> totalCost = GeneratedColumn<double>(
    'total_cost',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _installmentNoMeta = const VerificationMeta(
    'installmentNo',
  );
  @override
  late final GeneratedColumn<int> installmentNo = GeneratedColumn<int>(
    'installment_no',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _installmentCountMeta = const VerificationMeta(
    'installmentCount',
  );
  @override
  late final GeneratedColumn<int> installmentCount = GeneratedColumn<int>(
    'installment_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    vehicleId,
    kind,
    date,
    odometer,
    title,
    placeId,
    paymentMethodId,
    reasonId,
    driver,
    discount,
    totalCost,
    parentId,
    installmentNo,
    installmentCount,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<Entry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('odometer')) {
      context.handle(
        _odometerMeta,
        odometer.isAcceptableOrUnknown(data['odometer']!, _odometerMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('place_id')) {
      context.handle(
        _placeIdMeta,
        placeId.isAcceptableOrUnknown(data['place_id']!, _placeIdMeta),
      );
    }
    if (data.containsKey('payment_method_id')) {
      context.handle(
        _paymentMethodIdMeta,
        paymentMethodId.isAcceptableOrUnknown(
          data['payment_method_id']!,
          _paymentMethodIdMeta,
        ),
      );
    }
    if (data.containsKey('reason_id')) {
      context.handle(
        _reasonIdMeta,
        reasonId.isAcceptableOrUnknown(data['reason_id']!, _reasonIdMeta),
      );
    }
    if (data.containsKey('driver')) {
      context.handle(
        _driverMeta,
        driver.isAcceptableOrUnknown(data['driver']!, _driverMeta),
      );
    }
    if (data.containsKey('discount')) {
      context.handle(
        _discountMeta,
        discount.isAcceptableOrUnknown(data['discount']!, _discountMeta),
      );
    }
    if (data.containsKey('total_cost')) {
      context.handle(
        _totalCostMeta,
        totalCost.isAcceptableOrUnknown(data['total_cost']!, _totalCostMeta),
      );
    } else if (isInserting) {
      context.missing(_totalCostMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('installment_no')) {
      context.handle(
        _installmentNoMeta,
        installmentNo.isAcceptableOrUnknown(
          data['installment_no']!,
          _installmentNoMeta,
        ),
      );
    }
    if (data.containsKey('installment_count')) {
      context.handle(
        _installmentCountMeta,
        installmentCount.isAcceptableOrUnknown(
          data['installment_count']!,
          _installmentCountMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Entry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Entry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      )!,
      kind: $EntriesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      odometer: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}odometer'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      placeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}place_id'],
      ),
      paymentMethodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_method_id'],
      ),
      reasonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason_id'],
      ),
      driver: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}driver'],
      ),
      discount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}discount'],
      ),
      totalCost: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_cost'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      installmentNo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}installment_no'],
      )!,
      installmentCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}installment_count'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $EntriesTable createAlias(String alias) {
    return $EntriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<EntryKind, String, String> $converterkind =
      const EnumNameConverter<EntryKind>(EntryKind.values);
}

class Entry extends DataClass implements Insertable<Entry> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String vehicleId;
  final EntryKind kind;
  final DateTime date;
  final double? odometer;
  final String? title;
  final String? placeId;
  final String? paymentMethodId;
  final String? reasonId;
  final String? driver;
  final double? discount;

  /// Sum of items minus discount (for installments: this installment's share).
  final double totalCost;

  /// Installments: the first row is the parent; rows 2..n point to it.
  final String? parentId;
  final int installmentNo;
  final int installmentCount;
  final String? notes;
  const Entry({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.vehicleId,
    required this.kind,
    required this.date,
    this.odometer,
    this.title,
    this.placeId,
    this.paymentMethodId,
    this.reasonId,
    this.driver,
    this.discount,
    required this.totalCost,
    this.parentId,
    required this.installmentNo,
    required this.installmentCount,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['vehicle_id'] = Variable<String>(vehicleId);
    {
      map['kind'] = Variable<String>($EntriesTable.$converterkind.toSql(kind));
    }
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || odometer != null) {
      map['odometer'] = Variable<double>(odometer);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || placeId != null) {
      map['place_id'] = Variable<String>(placeId);
    }
    if (!nullToAbsent || paymentMethodId != null) {
      map['payment_method_id'] = Variable<String>(paymentMethodId);
    }
    if (!nullToAbsent || reasonId != null) {
      map['reason_id'] = Variable<String>(reasonId);
    }
    if (!nullToAbsent || driver != null) {
      map['driver'] = Variable<String>(driver);
    }
    if (!nullToAbsent || discount != null) {
      map['discount'] = Variable<double>(discount);
    }
    map['total_cost'] = Variable<double>(totalCost);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['installment_no'] = Variable<int>(installmentNo);
    map['installment_count'] = Variable<int>(installmentCount);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  EntriesCompanion toCompanion(bool nullToAbsent) {
    return EntriesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      vehicleId: Value(vehicleId),
      kind: Value(kind),
      date: Value(date),
      odometer: odometer == null && nullToAbsent
          ? const Value.absent()
          : Value(odometer),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      placeId: placeId == null && nullToAbsent
          ? const Value.absent()
          : Value(placeId),
      paymentMethodId: paymentMethodId == null && nullToAbsent
          ? const Value.absent()
          : Value(paymentMethodId),
      reasonId: reasonId == null && nullToAbsent
          ? const Value.absent()
          : Value(reasonId),
      driver: driver == null && nullToAbsent
          ? const Value.absent()
          : Value(driver),
      discount: discount == null && nullToAbsent
          ? const Value.absent()
          : Value(discount),
      totalCost: Value(totalCost),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      installmentNo: Value(installmentNo),
      installmentCount: Value(installmentCount),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory Entry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Entry(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      vehicleId: serializer.fromJson<String>(json['vehicleId']),
      kind: $EntriesTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      date: serializer.fromJson<DateTime>(json['date']),
      odometer: serializer.fromJson<double?>(json['odometer']),
      title: serializer.fromJson<String?>(json['title']),
      placeId: serializer.fromJson<String?>(json['placeId']),
      paymentMethodId: serializer.fromJson<String?>(json['paymentMethodId']),
      reasonId: serializer.fromJson<String?>(json['reasonId']),
      driver: serializer.fromJson<String?>(json['driver']),
      discount: serializer.fromJson<double?>(json['discount']),
      totalCost: serializer.fromJson<double>(json['totalCost']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      installmentNo: serializer.fromJson<int>(json['installmentNo']),
      installmentCount: serializer.fromJson<int>(json['installmentCount']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'vehicleId': serializer.toJson<String>(vehicleId),
      'kind': serializer.toJson<String>(
        $EntriesTable.$converterkind.toJson(kind),
      ),
      'date': serializer.toJson<DateTime>(date),
      'odometer': serializer.toJson<double?>(odometer),
      'title': serializer.toJson<String?>(title),
      'placeId': serializer.toJson<String?>(placeId),
      'paymentMethodId': serializer.toJson<String?>(paymentMethodId),
      'reasonId': serializer.toJson<String?>(reasonId),
      'driver': serializer.toJson<String?>(driver),
      'discount': serializer.toJson<double?>(discount),
      'totalCost': serializer.toJson<double>(totalCost),
      'parentId': serializer.toJson<String?>(parentId),
      'installmentNo': serializer.toJson<int>(installmentNo),
      'installmentCount': serializer.toJson<int>(installmentCount),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  Entry copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? vehicleId,
    EntryKind? kind,
    DateTime? date,
    Value<double?> odometer = const Value.absent(),
    Value<String?> title = const Value.absent(),
    Value<String?> placeId = const Value.absent(),
    Value<String?> paymentMethodId = const Value.absent(),
    Value<String?> reasonId = const Value.absent(),
    Value<String?> driver = const Value.absent(),
    Value<double?> discount = const Value.absent(),
    double? totalCost,
    Value<String?> parentId = const Value.absent(),
    int? installmentNo,
    int? installmentCount,
    Value<String?> notes = const Value.absent(),
  }) => Entry(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    vehicleId: vehicleId ?? this.vehicleId,
    kind: kind ?? this.kind,
    date: date ?? this.date,
    odometer: odometer.present ? odometer.value : this.odometer,
    title: title.present ? title.value : this.title,
    placeId: placeId.present ? placeId.value : this.placeId,
    paymentMethodId: paymentMethodId.present
        ? paymentMethodId.value
        : this.paymentMethodId,
    reasonId: reasonId.present ? reasonId.value : this.reasonId,
    driver: driver.present ? driver.value : this.driver,
    discount: discount.present ? discount.value : this.discount,
    totalCost: totalCost ?? this.totalCost,
    parentId: parentId.present ? parentId.value : this.parentId,
    installmentNo: installmentNo ?? this.installmentNo,
    installmentCount: installmentCount ?? this.installmentCount,
    notes: notes.present ? notes.value : this.notes,
  );
  Entry copyWithCompanion(EntriesCompanion data) {
    return Entry(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      kind: data.kind.present ? data.kind.value : this.kind,
      date: data.date.present ? data.date.value : this.date,
      odometer: data.odometer.present ? data.odometer.value : this.odometer,
      title: data.title.present ? data.title.value : this.title,
      placeId: data.placeId.present ? data.placeId.value : this.placeId,
      paymentMethodId: data.paymentMethodId.present
          ? data.paymentMethodId.value
          : this.paymentMethodId,
      reasonId: data.reasonId.present ? data.reasonId.value : this.reasonId,
      driver: data.driver.present ? data.driver.value : this.driver,
      discount: data.discount.present ? data.discount.value : this.discount,
      totalCost: data.totalCost.present ? data.totalCost.value : this.totalCost,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      installmentNo: data.installmentNo.present
          ? data.installmentNo.value
          : this.installmentNo,
      installmentCount: data.installmentCount.present
          ? data.installmentCount.value
          : this.installmentCount,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Entry(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('kind: $kind, ')
          ..write('date: $date, ')
          ..write('odometer: $odometer, ')
          ..write('title: $title, ')
          ..write('placeId: $placeId, ')
          ..write('paymentMethodId: $paymentMethodId, ')
          ..write('reasonId: $reasonId, ')
          ..write('driver: $driver, ')
          ..write('discount: $discount, ')
          ..write('totalCost: $totalCost, ')
          ..write('parentId: $parentId, ')
          ..write('installmentNo: $installmentNo, ')
          ..write('installmentCount: $installmentCount, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    vehicleId,
    kind,
    date,
    odometer,
    title,
    placeId,
    paymentMethodId,
    reasonId,
    driver,
    discount,
    totalCost,
    parentId,
    installmentNo,
    installmentCount,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Entry &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.vehicleId == this.vehicleId &&
          other.kind == this.kind &&
          other.date == this.date &&
          other.odometer == this.odometer &&
          other.title == this.title &&
          other.placeId == this.placeId &&
          other.paymentMethodId == this.paymentMethodId &&
          other.reasonId == this.reasonId &&
          other.driver == this.driver &&
          other.discount == this.discount &&
          other.totalCost == this.totalCost &&
          other.parentId == this.parentId &&
          other.installmentNo == this.installmentNo &&
          other.installmentCount == this.installmentCount &&
          other.notes == this.notes);
}

class EntriesCompanion extends UpdateCompanion<Entry> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> vehicleId;
  final Value<EntryKind> kind;
  final Value<DateTime> date;
  final Value<double?> odometer;
  final Value<String?> title;
  final Value<String?> placeId;
  final Value<String?> paymentMethodId;
  final Value<String?> reasonId;
  final Value<String?> driver;
  final Value<double?> discount;
  final Value<double> totalCost;
  final Value<String?> parentId;
  final Value<int> installmentNo;
  final Value<int> installmentCount;
  final Value<String?> notes;
  final Value<int> rowid;
  const EntriesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.kind = const Value.absent(),
    this.date = const Value.absent(),
    this.odometer = const Value.absent(),
    this.title = const Value.absent(),
    this.placeId = const Value.absent(),
    this.paymentMethodId = const Value.absent(),
    this.reasonId = const Value.absent(),
    this.driver = const Value.absent(),
    this.discount = const Value.absent(),
    this.totalCost = const Value.absent(),
    this.parentId = const Value.absent(),
    this.installmentNo = const Value.absent(),
    this.installmentCount = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntriesCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String vehicleId,
    required EntryKind kind,
    required DateTime date,
    this.odometer = const Value.absent(),
    this.title = const Value.absent(),
    this.placeId = const Value.absent(),
    this.paymentMethodId = const Value.absent(),
    this.reasonId = const Value.absent(),
    this.driver = const Value.absent(),
    this.discount = const Value.absent(),
    required double totalCost,
    this.parentId = const Value.absent(),
    this.installmentNo = const Value.absent(),
    this.installmentCount = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : vehicleId = Value(vehicleId),
       kind = Value(kind),
       date = Value(date),
       totalCost = Value(totalCost);
  static Insertable<Entry> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? vehicleId,
    Expression<String>? kind,
    Expression<DateTime>? date,
    Expression<double>? odometer,
    Expression<String>? title,
    Expression<String>? placeId,
    Expression<String>? paymentMethodId,
    Expression<String>? reasonId,
    Expression<String>? driver,
    Expression<double>? discount,
    Expression<double>? totalCost,
    Expression<String>? parentId,
    Expression<int>? installmentNo,
    Expression<int>? installmentCount,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (kind != null) 'kind': kind,
      if (date != null) 'date': date,
      if (odometer != null) 'odometer': odometer,
      if (title != null) 'title': title,
      if (placeId != null) 'place_id': placeId,
      if (paymentMethodId != null) 'payment_method_id': paymentMethodId,
      if (reasonId != null) 'reason_id': reasonId,
      if (driver != null) 'driver': driver,
      if (discount != null) 'discount': discount,
      if (totalCost != null) 'total_cost': totalCost,
      if (parentId != null) 'parent_id': parentId,
      if (installmentNo != null) 'installment_no': installmentNo,
      if (installmentCount != null) 'installment_count': installmentCount,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntriesCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? vehicleId,
    Value<EntryKind>? kind,
    Value<DateTime>? date,
    Value<double?>? odometer,
    Value<String?>? title,
    Value<String?>? placeId,
    Value<String?>? paymentMethodId,
    Value<String?>? reasonId,
    Value<String?>? driver,
    Value<double?>? discount,
    Value<double>? totalCost,
    Value<String?>? parentId,
    Value<int>? installmentNo,
    Value<int>? installmentCount,
    Value<String?>? notes,
    Value<int>? rowid,
  }) {
    return EntriesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      vehicleId: vehicleId ?? this.vehicleId,
      kind: kind ?? this.kind,
      date: date ?? this.date,
      odometer: odometer ?? this.odometer,
      title: title ?? this.title,
      placeId: placeId ?? this.placeId,
      paymentMethodId: paymentMethodId ?? this.paymentMethodId,
      reasonId: reasonId ?? this.reasonId,
      driver: driver ?? this.driver,
      discount: discount ?? this.discount,
      totalCost: totalCost ?? this.totalCost,
      parentId: parentId ?? this.parentId,
      installmentNo: installmentNo ?? this.installmentNo,
      installmentCount: installmentCount ?? this.installmentCount,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $EntriesTable.$converterkind.toSql(kind.value),
      );
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (odometer.present) {
      map['odometer'] = Variable<double>(odometer.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (placeId.present) {
      map['place_id'] = Variable<String>(placeId.value);
    }
    if (paymentMethodId.present) {
      map['payment_method_id'] = Variable<String>(paymentMethodId.value);
    }
    if (reasonId.present) {
      map['reason_id'] = Variable<String>(reasonId.value);
    }
    if (driver.present) {
      map['driver'] = Variable<String>(driver.value);
    }
    if (discount.present) {
      map['discount'] = Variable<double>(discount.value);
    }
    if (totalCost.present) {
      map['total_cost'] = Variable<double>(totalCost.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (installmentNo.present) {
      map['installment_no'] = Variable<int>(installmentNo.value);
    }
    if (installmentCount.present) {
      map['installment_count'] = Variable<int>(installmentCount.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntriesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('kind: $kind, ')
          ..write('date: $date, ')
          ..write('odometer: $odometer, ')
          ..write('title: $title, ')
          ..write('placeId: $placeId, ')
          ..write('paymentMethodId: $paymentMethodId, ')
          ..write('reasonId: $reasonId, ')
          ..write('driver: $driver, ')
          ..write('discount: $discount, ')
          ..write('totalCost: $totalCost, ')
          ..write('parentId: $parentId, ')
          ..write('installmentNo: $installmentNo, ')
          ..write('installmentCount: $installmentCount, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EntryItemsTable extends EntryItems
    with TableInfo<$EntryItemsTable, EntryItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntryItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newId,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES entries (id)',
    ),
  );
  static const VerificationMeta _typeIdMeta = const VerificationMeta('typeId');
  @override
  late final GeneratedColumn<String> typeId = GeneratedColumn<String>(
    'type_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES catalog_items (id)',
    ),
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    entryId,
    typeId,
    amount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entry_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntryItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('type_id')) {
      context.handle(
        _typeIdMeta,
        typeId.isAcceptableOrUnknown(data['type_id']!, _typeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_typeIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EntryItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntryItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      typeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type_id'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
    );
  }

  @override
  $EntryItemsTable createAlias(String alias) {
    return $EntryItemsTable(attachedDatabase, alias);
  }
}

class EntryItem extends DataClass implements Insertable<EntryItem> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String entryId;
  final String typeId;
  final double amount;
  const EntryItem({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.entryId,
    required this.typeId,
    required this.amount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['entry_id'] = Variable<String>(entryId);
    map['type_id'] = Variable<String>(typeId);
    map['amount'] = Variable<double>(amount);
    return map;
  }

  EntryItemsCompanion toCompanion(bool nullToAbsent) {
    return EntryItemsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      entryId: Value(entryId),
      typeId: Value(typeId),
      amount: Value(amount),
    );
  }

  factory EntryItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntryItem(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      entryId: serializer.fromJson<String>(json['entryId']),
      typeId: serializer.fromJson<String>(json['typeId']),
      amount: serializer.fromJson<double>(json['amount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'entryId': serializer.toJson<String>(entryId),
      'typeId': serializer.toJson<String>(typeId),
      'amount': serializer.toJson<double>(amount),
    };
  }

  EntryItem copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? entryId,
    String? typeId,
    double? amount,
  }) => EntryItem(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    entryId: entryId ?? this.entryId,
    typeId: typeId ?? this.typeId,
    amount: amount ?? this.amount,
  );
  EntryItem copyWithCompanion(EntryItemsCompanion data) {
    return EntryItem(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      typeId: data.typeId.present ? data.typeId.value : this.typeId,
      amount: data.amount.present ? data.amount.value : this.amount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntryItem(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('entryId: $entryId, ')
          ..write('typeId: $typeId, ')
          ..write('amount: $amount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, createdAt, updatedAt, deletedAt, entryId, typeId, amount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntryItem &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.entryId == this.entryId &&
          other.typeId == this.typeId &&
          other.amount == this.amount);
}

class EntryItemsCompanion extends UpdateCompanion<EntryItem> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> entryId;
  final Value<String> typeId;
  final Value<double> amount;
  final Value<int> rowid;
  const EntryItemsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.entryId = const Value.absent(),
    this.typeId = const Value.absent(),
    this.amount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntryItemsCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String entryId,
    required String typeId,
    required double amount,
    this.rowid = const Value.absent(),
  }) : entryId = Value(entryId),
       typeId = Value(typeId),
       amount = Value(amount);
  static Insertable<EntryItem> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? entryId,
    Expression<String>? typeId,
    Expression<double>? amount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (entryId != null) 'entry_id': entryId,
      if (typeId != null) 'type_id': typeId,
      if (amount != null) 'amount': amount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntryItemsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? entryId,
    Value<String>? typeId,
    Value<double>? amount,
    Value<int>? rowid,
  }) {
    return EntryItemsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      entryId: entryId ?? this.entryId,
      typeId: typeId ?? this.typeId,
      amount: amount ?? this.amount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (typeId.present) {
      map['type_id'] = Variable<String>(typeId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntryItemsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('entryId: $entryId, ')
          ..write('typeId: $typeId, ')
          ..write('amount: $amount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RoutesTable extends Routes with TableInfo<$RoutesTable, Route> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newId,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vehicles (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<RouteMode, String> mode =
      GeneratedColumn<String>(
        'mode',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(RouteMode.trip.name),
      ).withConverter<RouteMode>($RoutesTable.$convertermode);
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startOdometerMeta = const VerificationMeta(
    'startOdometer',
  );
  @override
  late final GeneratedColumn<double> startOdometer = GeneratedColumn<double>(
    'start_odometer',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _destinationMeta = const VerificationMeta(
    'destination',
  );
  @override
  late final GeneratedColumn<String> destination = GeneratedColumn<String>(
    'destination',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endOdometerMeta = const VerificationMeta(
    'endOdometer',
  );
  @override
  late final GeneratedColumn<double> endOdometer = GeneratedColumn<double>(
    'end_odometer',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _valuePerDistanceMeta = const VerificationMeta(
    'valuePerDistance',
  );
  @override
  late final GeneratedColumn<double> valuePerDistance = GeneratedColumn<double>(
    'value_per_distance',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<double> total = GeneratedColumn<double>(
    'total',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cargoTypeMeta = const VerificationMeta(
    'cargoType',
  );
  @override
  late final GeneratedColumn<String> cargoType = GeneratedColumn<String>(
    'cargo_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contractorMeta = const VerificationMeta(
    'contractor',
  );
  @override
  late final GeneratedColumn<String> contractor = GeneratedColumn<String>(
    'contractor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cargoUnitMeta = const VerificationMeta(
    'cargoUnit',
  );
  @override
  late final GeneratedColumn<String> cargoUnit = GeneratedColumn<String>(
    'cargo_unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cargoAmountMeta = const VerificationMeta(
    'cargoAmount',
  );
  @override
  late final GeneratedColumn<double> cargoAmount = GeneratedColumn<double>(
    'cargo_amount',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cargoWeightMeta = const VerificationMeta(
    'cargoWeight',
  );
  @override
  late final GeneratedColumn<double> cargoWeight = GeneratedColumn<double>(
    'cargo_weight',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cargoVolumeMeta = const VerificationMeta(
    'cargoVolume',
  );
  @override
  late final GeneratedColumn<double> cargoVolume = GeneratedColumn<double>(
    'cargo_volume',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _freightValueMeta = const VerificationMeta(
    'freightValue',
  );
  @override
  late final GeneratedColumn<double> freightValue = GeneratedColumn<double>(
    'freight_value',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _installmentsMeta = const VerificationMeta(
    'installments',
  );
  @override
  late final GeneratedColumn<int> installments = GeneratedColumn<int>(
    'installments',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _driverMeta = const VerificationMeta('driver');
  @override
  late final GeneratedColumn<String> driver = GeneratedColumn<String>(
    'driver',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reasonIdMeta = const VerificationMeta(
    'reasonId',
  );
  @override
  late final GeneratedColumn<String> reasonId = GeneratedColumn<String>(
    'reason_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES catalog_items (id)',
    ),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    vehicleId,
    mode,
    origin,
    startDate,
    startOdometer,
    destination,
    endDate,
    endOdometer,
    valuePerDistance,
    total,
    cargoType,
    contractor,
    cargoUnit,
    cargoAmount,
    cargoWeight,
    cargoVolume,
    freightValue,
    installments,
    driver,
    reasonId,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Route> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('start_odometer')) {
      context.handle(
        _startOdometerMeta,
        startOdometer.isAcceptableOrUnknown(
          data['start_odometer']!,
          _startOdometerMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startOdometerMeta);
    }
    if (data.containsKey('destination')) {
      context.handle(
        _destinationMeta,
        destination.isAcceptableOrUnknown(
          data['destination']!,
          _destinationMeta,
        ),
      );
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('end_odometer')) {
      context.handle(
        _endOdometerMeta,
        endOdometer.isAcceptableOrUnknown(
          data['end_odometer']!,
          _endOdometerMeta,
        ),
      );
    }
    if (data.containsKey('value_per_distance')) {
      context.handle(
        _valuePerDistanceMeta,
        valuePerDistance.isAcceptableOrUnknown(
          data['value_per_distance']!,
          _valuePerDistanceMeta,
        ),
      );
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    }
    if (data.containsKey('cargo_type')) {
      context.handle(
        _cargoTypeMeta,
        cargoType.isAcceptableOrUnknown(data['cargo_type']!, _cargoTypeMeta),
      );
    }
    if (data.containsKey('contractor')) {
      context.handle(
        _contractorMeta,
        contractor.isAcceptableOrUnknown(data['contractor']!, _contractorMeta),
      );
    }
    if (data.containsKey('cargo_unit')) {
      context.handle(
        _cargoUnitMeta,
        cargoUnit.isAcceptableOrUnknown(data['cargo_unit']!, _cargoUnitMeta),
      );
    }
    if (data.containsKey('cargo_amount')) {
      context.handle(
        _cargoAmountMeta,
        cargoAmount.isAcceptableOrUnknown(
          data['cargo_amount']!,
          _cargoAmountMeta,
        ),
      );
    }
    if (data.containsKey('cargo_weight')) {
      context.handle(
        _cargoWeightMeta,
        cargoWeight.isAcceptableOrUnknown(
          data['cargo_weight']!,
          _cargoWeightMeta,
        ),
      );
    }
    if (data.containsKey('cargo_volume')) {
      context.handle(
        _cargoVolumeMeta,
        cargoVolume.isAcceptableOrUnknown(
          data['cargo_volume']!,
          _cargoVolumeMeta,
        ),
      );
    }
    if (data.containsKey('freight_value')) {
      context.handle(
        _freightValueMeta,
        freightValue.isAcceptableOrUnknown(
          data['freight_value']!,
          _freightValueMeta,
        ),
      );
    }
    if (data.containsKey('installments')) {
      context.handle(
        _installmentsMeta,
        installments.isAcceptableOrUnknown(
          data['installments']!,
          _installmentsMeta,
        ),
      );
    }
    if (data.containsKey('driver')) {
      context.handle(
        _driverMeta,
        driver.isAcceptableOrUnknown(data['driver']!, _driverMeta),
      );
    }
    if (data.containsKey('reason_id')) {
      context.handle(
        _reasonIdMeta,
        reasonId.isAcceptableOrUnknown(data['reason_id']!, _reasonIdMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Route map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Route(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      )!,
      mode: $RoutesTable.$convertermode.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}mode'],
        )!,
      ),
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      ),
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      )!,
      startOdometer: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}start_odometer'],
      )!,
      destination: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}destination'],
      ),
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      ),
      endOdometer: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}end_odometer'],
      ),
      valuePerDistance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}value_per_distance'],
      ),
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total'],
      ),
      cargoType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cargo_type'],
      ),
      contractor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contractor'],
      ),
      cargoUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cargo_unit'],
      ),
      cargoAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cargo_amount'],
      ),
      cargoWeight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cargo_weight'],
      ),
      cargoVolume: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cargo_volume'],
      ),
      freightValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}freight_value'],
      ),
      installments: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}installments'],
      )!,
      driver: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}driver'],
      ),
      reasonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason_id'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $RoutesTable createAlias(String alias) {
    return $RoutesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<RouteMode, String, String> $convertermode =
      const EnumNameConverter<RouteMode>(RouteMode.values);
}

class Route extends DataClass implements Insertable<Route> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String vehicleId;
  final RouteMode mode;
  final String? origin;
  final DateTime startDate;
  final double startOdometer;
  final String? destination;

  /// Null while the route is still open (finish later).
  final DateTime? endDate;
  final double? endOdometer;

  /// Trip mode: optional value per distance unit, and the computed total.
  final double? valuePerDistance;
  final double? total;
  final String? cargoType;
  final String? contractor;
  final String? cargoUnit;
  final double? cargoAmount;
  final double? cargoWeight;
  final double? cargoVolume;
  final double? freightValue;
  final int installments;
  final String? driver;
  final String? reasonId;
  final String? notes;
  const Route({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.vehicleId,
    required this.mode,
    this.origin,
    required this.startDate,
    required this.startOdometer,
    this.destination,
    this.endDate,
    this.endOdometer,
    this.valuePerDistance,
    this.total,
    this.cargoType,
    this.contractor,
    this.cargoUnit,
    this.cargoAmount,
    this.cargoWeight,
    this.cargoVolume,
    this.freightValue,
    required this.installments,
    this.driver,
    this.reasonId,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['vehicle_id'] = Variable<String>(vehicleId);
    {
      map['mode'] = Variable<String>($RoutesTable.$convertermode.toSql(mode));
    }
    if (!nullToAbsent || origin != null) {
      map['origin'] = Variable<String>(origin);
    }
    map['start_date'] = Variable<DateTime>(startDate);
    map['start_odometer'] = Variable<double>(startOdometer);
    if (!nullToAbsent || destination != null) {
      map['destination'] = Variable<String>(destination);
    }
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<DateTime>(endDate);
    }
    if (!nullToAbsent || endOdometer != null) {
      map['end_odometer'] = Variable<double>(endOdometer);
    }
    if (!nullToAbsent || valuePerDistance != null) {
      map['value_per_distance'] = Variable<double>(valuePerDistance);
    }
    if (!nullToAbsent || total != null) {
      map['total'] = Variable<double>(total);
    }
    if (!nullToAbsent || cargoType != null) {
      map['cargo_type'] = Variable<String>(cargoType);
    }
    if (!nullToAbsent || contractor != null) {
      map['contractor'] = Variable<String>(contractor);
    }
    if (!nullToAbsent || cargoUnit != null) {
      map['cargo_unit'] = Variable<String>(cargoUnit);
    }
    if (!nullToAbsent || cargoAmount != null) {
      map['cargo_amount'] = Variable<double>(cargoAmount);
    }
    if (!nullToAbsent || cargoWeight != null) {
      map['cargo_weight'] = Variable<double>(cargoWeight);
    }
    if (!nullToAbsent || cargoVolume != null) {
      map['cargo_volume'] = Variable<double>(cargoVolume);
    }
    if (!nullToAbsent || freightValue != null) {
      map['freight_value'] = Variable<double>(freightValue);
    }
    map['installments'] = Variable<int>(installments);
    if (!nullToAbsent || driver != null) {
      map['driver'] = Variable<String>(driver);
    }
    if (!nullToAbsent || reasonId != null) {
      map['reason_id'] = Variable<String>(reasonId);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  RoutesCompanion toCompanion(bool nullToAbsent) {
    return RoutesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      vehicleId: Value(vehicleId),
      mode: Value(mode),
      origin: origin == null && nullToAbsent
          ? const Value.absent()
          : Value(origin),
      startDate: Value(startDate),
      startOdometer: Value(startOdometer),
      destination: destination == null && nullToAbsent
          ? const Value.absent()
          : Value(destination),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      endOdometer: endOdometer == null && nullToAbsent
          ? const Value.absent()
          : Value(endOdometer),
      valuePerDistance: valuePerDistance == null && nullToAbsent
          ? const Value.absent()
          : Value(valuePerDistance),
      total: total == null && nullToAbsent
          ? const Value.absent()
          : Value(total),
      cargoType: cargoType == null && nullToAbsent
          ? const Value.absent()
          : Value(cargoType),
      contractor: contractor == null && nullToAbsent
          ? const Value.absent()
          : Value(contractor),
      cargoUnit: cargoUnit == null && nullToAbsent
          ? const Value.absent()
          : Value(cargoUnit),
      cargoAmount: cargoAmount == null && nullToAbsent
          ? const Value.absent()
          : Value(cargoAmount),
      cargoWeight: cargoWeight == null && nullToAbsent
          ? const Value.absent()
          : Value(cargoWeight),
      cargoVolume: cargoVolume == null && nullToAbsent
          ? const Value.absent()
          : Value(cargoVolume),
      freightValue: freightValue == null && nullToAbsent
          ? const Value.absent()
          : Value(freightValue),
      installments: Value(installments),
      driver: driver == null && nullToAbsent
          ? const Value.absent()
          : Value(driver),
      reasonId: reasonId == null && nullToAbsent
          ? const Value.absent()
          : Value(reasonId),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory Route.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Route(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      vehicleId: serializer.fromJson<String>(json['vehicleId']),
      mode: $RoutesTable.$convertermode.fromJson(
        serializer.fromJson<String>(json['mode']),
      ),
      origin: serializer.fromJson<String?>(json['origin']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      startOdometer: serializer.fromJson<double>(json['startOdometer']),
      destination: serializer.fromJson<String?>(json['destination']),
      endDate: serializer.fromJson<DateTime?>(json['endDate']),
      endOdometer: serializer.fromJson<double?>(json['endOdometer']),
      valuePerDistance: serializer.fromJson<double?>(json['valuePerDistance']),
      total: serializer.fromJson<double?>(json['total']),
      cargoType: serializer.fromJson<String?>(json['cargoType']),
      contractor: serializer.fromJson<String?>(json['contractor']),
      cargoUnit: serializer.fromJson<String?>(json['cargoUnit']),
      cargoAmount: serializer.fromJson<double?>(json['cargoAmount']),
      cargoWeight: serializer.fromJson<double?>(json['cargoWeight']),
      cargoVolume: serializer.fromJson<double?>(json['cargoVolume']),
      freightValue: serializer.fromJson<double?>(json['freightValue']),
      installments: serializer.fromJson<int>(json['installments']),
      driver: serializer.fromJson<String?>(json['driver']),
      reasonId: serializer.fromJson<String?>(json['reasonId']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'vehicleId': serializer.toJson<String>(vehicleId),
      'mode': serializer.toJson<String>(
        $RoutesTable.$convertermode.toJson(mode),
      ),
      'origin': serializer.toJson<String?>(origin),
      'startDate': serializer.toJson<DateTime>(startDate),
      'startOdometer': serializer.toJson<double>(startOdometer),
      'destination': serializer.toJson<String?>(destination),
      'endDate': serializer.toJson<DateTime?>(endDate),
      'endOdometer': serializer.toJson<double?>(endOdometer),
      'valuePerDistance': serializer.toJson<double?>(valuePerDistance),
      'total': serializer.toJson<double?>(total),
      'cargoType': serializer.toJson<String?>(cargoType),
      'contractor': serializer.toJson<String?>(contractor),
      'cargoUnit': serializer.toJson<String?>(cargoUnit),
      'cargoAmount': serializer.toJson<double?>(cargoAmount),
      'cargoWeight': serializer.toJson<double?>(cargoWeight),
      'cargoVolume': serializer.toJson<double?>(cargoVolume),
      'freightValue': serializer.toJson<double?>(freightValue),
      'installments': serializer.toJson<int>(installments),
      'driver': serializer.toJson<String?>(driver),
      'reasonId': serializer.toJson<String?>(reasonId),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  Route copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? vehicleId,
    RouteMode? mode,
    Value<String?> origin = const Value.absent(),
    DateTime? startDate,
    double? startOdometer,
    Value<String?> destination = const Value.absent(),
    Value<DateTime?> endDate = const Value.absent(),
    Value<double?> endOdometer = const Value.absent(),
    Value<double?> valuePerDistance = const Value.absent(),
    Value<double?> total = const Value.absent(),
    Value<String?> cargoType = const Value.absent(),
    Value<String?> contractor = const Value.absent(),
    Value<String?> cargoUnit = const Value.absent(),
    Value<double?> cargoAmount = const Value.absent(),
    Value<double?> cargoWeight = const Value.absent(),
    Value<double?> cargoVolume = const Value.absent(),
    Value<double?> freightValue = const Value.absent(),
    int? installments,
    Value<String?> driver = const Value.absent(),
    Value<String?> reasonId = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => Route(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    vehicleId: vehicleId ?? this.vehicleId,
    mode: mode ?? this.mode,
    origin: origin.present ? origin.value : this.origin,
    startDate: startDate ?? this.startDate,
    startOdometer: startOdometer ?? this.startOdometer,
    destination: destination.present ? destination.value : this.destination,
    endDate: endDate.present ? endDate.value : this.endDate,
    endOdometer: endOdometer.present ? endOdometer.value : this.endOdometer,
    valuePerDistance: valuePerDistance.present
        ? valuePerDistance.value
        : this.valuePerDistance,
    total: total.present ? total.value : this.total,
    cargoType: cargoType.present ? cargoType.value : this.cargoType,
    contractor: contractor.present ? contractor.value : this.contractor,
    cargoUnit: cargoUnit.present ? cargoUnit.value : this.cargoUnit,
    cargoAmount: cargoAmount.present ? cargoAmount.value : this.cargoAmount,
    cargoWeight: cargoWeight.present ? cargoWeight.value : this.cargoWeight,
    cargoVolume: cargoVolume.present ? cargoVolume.value : this.cargoVolume,
    freightValue: freightValue.present ? freightValue.value : this.freightValue,
    installments: installments ?? this.installments,
    driver: driver.present ? driver.value : this.driver,
    reasonId: reasonId.present ? reasonId.value : this.reasonId,
    notes: notes.present ? notes.value : this.notes,
  );
  Route copyWithCompanion(RoutesCompanion data) {
    return Route(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      mode: data.mode.present ? data.mode.value : this.mode,
      origin: data.origin.present ? data.origin.value : this.origin,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      startOdometer: data.startOdometer.present
          ? data.startOdometer.value
          : this.startOdometer,
      destination: data.destination.present
          ? data.destination.value
          : this.destination,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      endOdometer: data.endOdometer.present
          ? data.endOdometer.value
          : this.endOdometer,
      valuePerDistance: data.valuePerDistance.present
          ? data.valuePerDistance.value
          : this.valuePerDistance,
      total: data.total.present ? data.total.value : this.total,
      cargoType: data.cargoType.present ? data.cargoType.value : this.cargoType,
      contractor: data.contractor.present
          ? data.contractor.value
          : this.contractor,
      cargoUnit: data.cargoUnit.present ? data.cargoUnit.value : this.cargoUnit,
      cargoAmount: data.cargoAmount.present
          ? data.cargoAmount.value
          : this.cargoAmount,
      cargoWeight: data.cargoWeight.present
          ? data.cargoWeight.value
          : this.cargoWeight,
      cargoVolume: data.cargoVolume.present
          ? data.cargoVolume.value
          : this.cargoVolume,
      freightValue: data.freightValue.present
          ? data.freightValue.value
          : this.freightValue,
      installments: data.installments.present
          ? data.installments.value
          : this.installments,
      driver: data.driver.present ? data.driver.value : this.driver,
      reasonId: data.reasonId.present ? data.reasonId.value : this.reasonId,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Route(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('mode: $mode, ')
          ..write('origin: $origin, ')
          ..write('startDate: $startDate, ')
          ..write('startOdometer: $startOdometer, ')
          ..write('destination: $destination, ')
          ..write('endDate: $endDate, ')
          ..write('endOdometer: $endOdometer, ')
          ..write('valuePerDistance: $valuePerDistance, ')
          ..write('total: $total, ')
          ..write('cargoType: $cargoType, ')
          ..write('contractor: $contractor, ')
          ..write('cargoUnit: $cargoUnit, ')
          ..write('cargoAmount: $cargoAmount, ')
          ..write('cargoWeight: $cargoWeight, ')
          ..write('cargoVolume: $cargoVolume, ')
          ..write('freightValue: $freightValue, ')
          ..write('installments: $installments, ')
          ..write('driver: $driver, ')
          ..write('reasonId: $reasonId, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    createdAt,
    updatedAt,
    deletedAt,
    vehicleId,
    mode,
    origin,
    startDate,
    startOdometer,
    destination,
    endDate,
    endOdometer,
    valuePerDistance,
    total,
    cargoType,
    contractor,
    cargoUnit,
    cargoAmount,
    cargoWeight,
    cargoVolume,
    freightValue,
    installments,
    driver,
    reasonId,
    notes,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Route &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.vehicleId == this.vehicleId &&
          other.mode == this.mode &&
          other.origin == this.origin &&
          other.startDate == this.startDate &&
          other.startOdometer == this.startOdometer &&
          other.destination == this.destination &&
          other.endDate == this.endDate &&
          other.endOdometer == this.endOdometer &&
          other.valuePerDistance == this.valuePerDistance &&
          other.total == this.total &&
          other.cargoType == this.cargoType &&
          other.contractor == this.contractor &&
          other.cargoUnit == this.cargoUnit &&
          other.cargoAmount == this.cargoAmount &&
          other.cargoWeight == this.cargoWeight &&
          other.cargoVolume == this.cargoVolume &&
          other.freightValue == this.freightValue &&
          other.installments == this.installments &&
          other.driver == this.driver &&
          other.reasonId == this.reasonId &&
          other.notes == this.notes);
}

class RoutesCompanion extends UpdateCompanion<Route> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> vehicleId;
  final Value<RouteMode> mode;
  final Value<String?> origin;
  final Value<DateTime> startDate;
  final Value<double> startOdometer;
  final Value<String?> destination;
  final Value<DateTime?> endDate;
  final Value<double?> endOdometer;
  final Value<double?> valuePerDistance;
  final Value<double?> total;
  final Value<String?> cargoType;
  final Value<String?> contractor;
  final Value<String?> cargoUnit;
  final Value<double?> cargoAmount;
  final Value<double?> cargoWeight;
  final Value<double?> cargoVolume;
  final Value<double?> freightValue;
  final Value<int> installments;
  final Value<String?> driver;
  final Value<String?> reasonId;
  final Value<String?> notes;
  final Value<int> rowid;
  const RoutesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.mode = const Value.absent(),
    this.origin = const Value.absent(),
    this.startDate = const Value.absent(),
    this.startOdometer = const Value.absent(),
    this.destination = const Value.absent(),
    this.endDate = const Value.absent(),
    this.endOdometer = const Value.absent(),
    this.valuePerDistance = const Value.absent(),
    this.total = const Value.absent(),
    this.cargoType = const Value.absent(),
    this.contractor = const Value.absent(),
    this.cargoUnit = const Value.absent(),
    this.cargoAmount = const Value.absent(),
    this.cargoWeight = const Value.absent(),
    this.cargoVolume = const Value.absent(),
    this.freightValue = const Value.absent(),
    this.installments = const Value.absent(),
    this.driver = const Value.absent(),
    this.reasonId = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RoutesCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String vehicleId,
    this.mode = const Value.absent(),
    this.origin = const Value.absent(),
    required DateTime startDate,
    required double startOdometer,
    this.destination = const Value.absent(),
    this.endDate = const Value.absent(),
    this.endOdometer = const Value.absent(),
    this.valuePerDistance = const Value.absent(),
    this.total = const Value.absent(),
    this.cargoType = const Value.absent(),
    this.contractor = const Value.absent(),
    this.cargoUnit = const Value.absent(),
    this.cargoAmount = const Value.absent(),
    this.cargoWeight = const Value.absent(),
    this.cargoVolume = const Value.absent(),
    this.freightValue = const Value.absent(),
    this.installments = const Value.absent(),
    this.driver = const Value.absent(),
    this.reasonId = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : vehicleId = Value(vehicleId),
       startDate = Value(startDate),
       startOdometer = Value(startOdometer);
  static Insertable<Route> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? vehicleId,
    Expression<String>? mode,
    Expression<String>? origin,
    Expression<DateTime>? startDate,
    Expression<double>? startOdometer,
    Expression<String>? destination,
    Expression<DateTime>? endDate,
    Expression<double>? endOdometer,
    Expression<double>? valuePerDistance,
    Expression<double>? total,
    Expression<String>? cargoType,
    Expression<String>? contractor,
    Expression<String>? cargoUnit,
    Expression<double>? cargoAmount,
    Expression<double>? cargoWeight,
    Expression<double>? cargoVolume,
    Expression<double>? freightValue,
    Expression<int>? installments,
    Expression<String>? driver,
    Expression<String>? reasonId,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (mode != null) 'mode': mode,
      if (origin != null) 'origin': origin,
      if (startDate != null) 'start_date': startDate,
      if (startOdometer != null) 'start_odometer': startOdometer,
      if (destination != null) 'destination': destination,
      if (endDate != null) 'end_date': endDate,
      if (endOdometer != null) 'end_odometer': endOdometer,
      if (valuePerDistance != null) 'value_per_distance': valuePerDistance,
      if (total != null) 'total': total,
      if (cargoType != null) 'cargo_type': cargoType,
      if (contractor != null) 'contractor': contractor,
      if (cargoUnit != null) 'cargo_unit': cargoUnit,
      if (cargoAmount != null) 'cargo_amount': cargoAmount,
      if (cargoWeight != null) 'cargo_weight': cargoWeight,
      if (cargoVolume != null) 'cargo_volume': cargoVolume,
      if (freightValue != null) 'freight_value': freightValue,
      if (installments != null) 'installments': installments,
      if (driver != null) 'driver': driver,
      if (reasonId != null) 'reason_id': reasonId,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RoutesCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? vehicleId,
    Value<RouteMode>? mode,
    Value<String?>? origin,
    Value<DateTime>? startDate,
    Value<double>? startOdometer,
    Value<String?>? destination,
    Value<DateTime?>? endDate,
    Value<double?>? endOdometer,
    Value<double?>? valuePerDistance,
    Value<double?>? total,
    Value<String?>? cargoType,
    Value<String?>? contractor,
    Value<String?>? cargoUnit,
    Value<double?>? cargoAmount,
    Value<double?>? cargoWeight,
    Value<double?>? cargoVolume,
    Value<double?>? freightValue,
    Value<int>? installments,
    Value<String?>? driver,
    Value<String?>? reasonId,
    Value<String?>? notes,
    Value<int>? rowid,
  }) {
    return RoutesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      vehicleId: vehicleId ?? this.vehicleId,
      mode: mode ?? this.mode,
      origin: origin ?? this.origin,
      startDate: startDate ?? this.startDate,
      startOdometer: startOdometer ?? this.startOdometer,
      destination: destination ?? this.destination,
      endDate: endDate ?? this.endDate,
      endOdometer: endOdometer ?? this.endOdometer,
      valuePerDistance: valuePerDistance ?? this.valuePerDistance,
      total: total ?? this.total,
      cargoType: cargoType ?? this.cargoType,
      contractor: contractor ?? this.contractor,
      cargoUnit: cargoUnit ?? this.cargoUnit,
      cargoAmount: cargoAmount ?? this.cargoAmount,
      cargoWeight: cargoWeight ?? this.cargoWeight,
      cargoVolume: cargoVolume ?? this.cargoVolume,
      freightValue: freightValue ?? this.freightValue,
      installments: installments ?? this.installments,
      driver: driver ?? this.driver,
      reasonId: reasonId ?? this.reasonId,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(
        $RoutesTable.$convertermode.toSql(mode.value),
      );
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (startOdometer.present) {
      map['start_odometer'] = Variable<double>(startOdometer.value);
    }
    if (destination.present) {
      map['destination'] = Variable<String>(destination.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (endOdometer.present) {
      map['end_odometer'] = Variable<double>(endOdometer.value);
    }
    if (valuePerDistance.present) {
      map['value_per_distance'] = Variable<double>(valuePerDistance.value);
    }
    if (total.present) {
      map['total'] = Variable<double>(total.value);
    }
    if (cargoType.present) {
      map['cargo_type'] = Variable<String>(cargoType.value);
    }
    if (contractor.present) {
      map['contractor'] = Variable<String>(contractor.value);
    }
    if (cargoUnit.present) {
      map['cargo_unit'] = Variable<String>(cargoUnit.value);
    }
    if (cargoAmount.present) {
      map['cargo_amount'] = Variable<double>(cargoAmount.value);
    }
    if (cargoWeight.present) {
      map['cargo_weight'] = Variable<double>(cargoWeight.value);
    }
    if (cargoVolume.present) {
      map['cargo_volume'] = Variable<double>(cargoVolume.value);
    }
    if (freightValue.present) {
      map['freight_value'] = Variable<double>(freightValue.value);
    }
    if (installments.present) {
      map['installments'] = Variable<int>(installments.value);
    }
    if (driver.present) {
      map['driver'] = Variable<String>(driver.value);
    }
    if (reasonId.present) {
      map['reason_id'] = Variable<String>(reasonId.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('mode: $mode, ')
          ..write('origin: $origin, ')
          ..write('startDate: $startDate, ')
          ..write('startOdometer: $startOdometer, ')
          ..write('destination: $destination, ')
          ..write('endDate: $endDate, ')
          ..write('endOdometer: $endOdometer, ')
          ..write('valuePerDistance: $valuePerDistance, ')
          ..write('total: $total, ')
          ..write('cargoType: $cargoType, ')
          ..write('contractor: $contractor, ')
          ..write('cargoUnit: $cargoUnit, ')
          ..write('cargoAmount: $cargoAmount, ')
          ..write('cargoWeight: $cargoWeight, ')
          ..write('cargoVolume: $cargoVolume, ')
          ..write('freightValue: $freightValue, ')
          ..write('installments: $installments, ')
          ..write('driver: $driver, ')
          ..write('reasonId: $reasonId, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadingsTable extends Readings with TableInfo<$ReadingsTable, Reading> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newId,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vehicles (id)',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _odometerMeta = const VerificationMeta(
    'odometer',
  );
  @override
  late final GeneratedColumn<double> odometer = GeneratedColumn<double>(
    'odometer',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _driverMeta = const VerificationMeta('driver');
  @override
  late final GeneratedColumn<String> driver = GeneratedColumn<String>(
    'driver',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    vehicleId,
    date,
    odometer,
    driver,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'readings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Reading> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('odometer')) {
      context.handle(
        _odometerMeta,
        odometer.isAcceptableOrUnknown(data['odometer']!, _odometerMeta),
      );
    } else if (isInserting) {
      context.missing(_odometerMeta);
    }
    if (data.containsKey('driver')) {
      context.handle(
        _driverMeta,
        driver.isAcceptableOrUnknown(data['driver']!, _driverMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Reading map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Reading(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      odometer: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}odometer'],
      )!,
      driver: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}driver'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $ReadingsTable createAlias(String alias) {
    return $ReadingsTable(attachedDatabase, alias);
  }
}

class Reading extends DataClass implements Insertable<Reading> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String vehicleId;
  final DateTime date;
  final double odometer;
  final String? driver;
  final String? notes;
  const Reading({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.vehicleId,
    required this.date,
    required this.odometer,
    this.driver,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['vehicle_id'] = Variable<String>(vehicleId);
    map['date'] = Variable<DateTime>(date);
    map['odometer'] = Variable<double>(odometer);
    if (!nullToAbsent || driver != null) {
      map['driver'] = Variable<String>(driver);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  ReadingsCompanion toCompanion(bool nullToAbsent) {
    return ReadingsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      vehicleId: Value(vehicleId),
      date: Value(date),
      odometer: Value(odometer),
      driver: driver == null && nullToAbsent
          ? const Value.absent()
          : Value(driver),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory Reading.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Reading(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      vehicleId: serializer.fromJson<String>(json['vehicleId']),
      date: serializer.fromJson<DateTime>(json['date']),
      odometer: serializer.fromJson<double>(json['odometer']),
      driver: serializer.fromJson<String?>(json['driver']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'vehicleId': serializer.toJson<String>(vehicleId),
      'date': serializer.toJson<DateTime>(date),
      'odometer': serializer.toJson<double>(odometer),
      'driver': serializer.toJson<String?>(driver),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  Reading copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? vehicleId,
    DateTime? date,
    double? odometer,
    Value<String?> driver = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => Reading(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    vehicleId: vehicleId ?? this.vehicleId,
    date: date ?? this.date,
    odometer: odometer ?? this.odometer,
    driver: driver.present ? driver.value : this.driver,
    notes: notes.present ? notes.value : this.notes,
  );
  Reading copyWithCompanion(ReadingsCompanion data) {
    return Reading(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      date: data.date.present ? data.date.value : this.date,
      odometer: data.odometer.present ? data.odometer.value : this.odometer,
      driver: data.driver.present ? data.driver.value : this.driver,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Reading(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('date: $date, ')
          ..write('odometer: $odometer, ')
          ..write('driver: $driver, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    vehicleId,
    date,
    odometer,
    driver,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reading &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.vehicleId == this.vehicleId &&
          other.date == this.date &&
          other.odometer == this.odometer &&
          other.driver == this.driver &&
          other.notes == this.notes);
}

class ReadingsCompanion extends UpdateCompanion<Reading> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> vehicleId;
  final Value<DateTime> date;
  final Value<double> odometer;
  final Value<String?> driver;
  final Value<String?> notes;
  final Value<int> rowid;
  const ReadingsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.date = const Value.absent(),
    this.odometer = const Value.absent(),
    this.driver = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadingsCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String vehicleId,
    required DateTime date,
    required double odometer,
    this.driver = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : vehicleId = Value(vehicleId),
       date = Value(date),
       odometer = Value(odometer);
  static Insertable<Reading> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? vehicleId,
    Expression<DateTime>? date,
    Expression<double>? odometer,
    Expression<String>? driver,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (date != null) 'date': date,
      if (odometer != null) 'odometer': odometer,
      if (driver != null) 'driver': driver,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadingsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? vehicleId,
    Value<DateTime>? date,
    Value<double>? odometer,
    Value<String?>? driver,
    Value<String?>? notes,
    Value<int>? rowid,
  }) {
    return ReadingsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      vehicleId: vehicleId ?? this.vehicleId,
      date: date ?? this.date,
      odometer: odometer ?? this.odometer,
      driver: driver ?? this.driver,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (odometer.present) {
      map['odometer'] = Variable<double>(odometer.value);
    }
    if (driver.present) {
      map['driver'] = Variable<String>(driver.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('date: $date, ')
          ..write('odometer: $odometer, ')
          ..write('driver: $driver, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RemindersTable extends Reminders
    with TableInfo<$RemindersTable, Reminder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newId,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vehicles (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<ReminderTarget, String> target =
      GeneratedColumn<String>(
        'target',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ReminderTarget>($RemindersTable.$convertertarget);
  static const VerificationMeta _typeIdMeta = const VerificationMeta('typeId');
  @override
  late final GeneratedColumn<String> typeId = GeneratedColumn<String>(
    'type_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES catalog_items (id)',
    ),
  );
  static const VerificationMeta _repeatMeta = const VerificationMeta('repeat');
  @override
  late final GeneratedColumn<bool> repeat = GeneratedColumn<bool>(
    'repeat',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("repeat" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _byDistanceMeta = const VerificationMeta(
    'byDistance',
  );
  @override
  late final GeneratedColumn<bool> byDistance = GeneratedColumn<bool>(
    'by_distance',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("by_distance" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _dueOdometerMeta = const VerificationMeta(
    'dueOdometer',
  );
  @override
  late final GeneratedColumn<double> dueOdometer = GeneratedColumn<double>(
    'due_odometer',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _everyDistanceMeta = const VerificationMeta(
    'everyDistance',
  );
  @override
  late final GeneratedColumn<double> everyDistance = GeneratedColumn<double>(
    'every_distance',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _byDateMeta = const VerificationMeta('byDate');
  @override
  late final GeneratedColumn<bool> byDate = GeneratedColumn<bool>(
    'by_date',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("by_date" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _everyAmountMeta = const VerificationMeta(
    'everyAmount',
  );
  @override
  late final GeneratedColumn<int> everyAmount = GeneratedColumn<int>(
    'every_amount',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<PeriodUnit?, String> everyUnit =
      GeneratedColumn<String>(
        'every_unit',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<PeriodUnit?>($RemindersTable.$convertereveryUnitn);
  static const VerificationMeta _lastDoneOdometerMeta = const VerificationMeta(
    'lastDoneOdometer',
  );
  @override
  late final GeneratedColumn<double> lastDoneOdometer = GeneratedColumn<double>(
    'last_done_odometer',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastDoneDateMeta = const VerificationMeta(
    'lastDoneDate',
  );
  @override
  late final GeneratedColumn<DateTime> lastDoneDate = GeneratedColumn<DateTime>(
    'last_done_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    vehicleId,
    target,
    typeId,
    repeat,
    byDistance,
    dueOdometer,
    everyDistance,
    byDate,
    dueDate,
    everyAmount,
    everyUnit,
    lastDoneOdometer,
    lastDoneDate,
    active,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<Reminder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('type_id')) {
      context.handle(
        _typeIdMeta,
        typeId.isAcceptableOrUnknown(data['type_id']!, _typeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_typeIdMeta);
    }
    if (data.containsKey('repeat')) {
      context.handle(
        _repeatMeta,
        repeat.isAcceptableOrUnknown(data['repeat']!, _repeatMeta),
      );
    }
    if (data.containsKey('by_distance')) {
      context.handle(
        _byDistanceMeta,
        byDistance.isAcceptableOrUnknown(data['by_distance']!, _byDistanceMeta),
      );
    }
    if (data.containsKey('due_odometer')) {
      context.handle(
        _dueOdometerMeta,
        dueOdometer.isAcceptableOrUnknown(
          data['due_odometer']!,
          _dueOdometerMeta,
        ),
      );
    }
    if (data.containsKey('every_distance')) {
      context.handle(
        _everyDistanceMeta,
        everyDistance.isAcceptableOrUnknown(
          data['every_distance']!,
          _everyDistanceMeta,
        ),
      );
    }
    if (data.containsKey('by_date')) {
      context.handle(
        _byDateMeta,
        byDate.isAcceptableOrUnknown(data['by_date']!, _byDateMeta),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('every_amount')) {
      context.handle(
        _everyAmountMeta,
        everyAmount.isAcceptableOrUnknown(
          data['every_amount']!,
          _everyAmountMeta,
        ),
      );
    }
    if (data.containsKey('last_done_odometer')) {
      context.handle(
        _lastDoneOdometerMeta,
        lastDoneOdometer.isAcceptableOrUnknown(
          data['last_done_odometer']!,
          _lastDoneOdometerMeta,
        ),
      );
    }
    if (data.containsKey('last_done_date')) {
      context.handle(
        _lastDoneDateMeta,
        lastDoneDate.isAcceptableOrUnknown(
          data['last_done_date']!,
          _lastDoneDateMeta,
        ),
      );
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Reminder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Reminder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      )!,
      target: $RemindersTable.$convertertarget.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}target'],
        )!,
      ),
      typeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type_id'],
      )!,
      repeat: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}repeat'],
      )!,
      byDistance: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}by_distance'],
      )!,
      dueOdometer: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}due_odometer'],
      ),
      everyDistance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}every_distance'],
      ),
      byDate: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}by_date'],
      )!,
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      ),
      everyAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}every_amount'],
      ),
      everyUnit: $RemindersTable.$convertereveryUnitn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}every_unit'],
        ),
      ),
      lastDoneOdometer: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}last_done_odometer'],
      ),
      lastDoneDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_done_date'],
      ),
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $RemindersTable createAlias(String alias) {
    return $RemindersTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ReminderTarget, String, String> $convertertarget =
      const EnumNameConverter<ReminderTarget>(ReminderTarget.values);
  static JsonTypeConverter2<PeriodUnit, String, String> $convertereveryUnit =
      const EnumNameConverter<PeriodUnit>(PeriodUnit.values);
  static JsonTypeConverter2<PeriodUnit?, String?, String?>
  $convertereveryUnitn = JsonTypeConverter2.asNullable($convertereveryUnit);
}

class Reminder extends DataClass implements Insertable<Reminder> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String vehicleId;
  final ReminderTarget target;
  final String typeId;

  /// false = "just one time", true = "repeat every".
  final bool repeat;

  /// Distance trigger. One-time: [dueOdometer]. Repeat: every [everyDistance].
  final bool byDistance;
  final double? dueOdometer;
  final double? everyDistance;

  /// Date trigger. One-time: [dueDate]. Repeat: every [everyAmount] [everyUnit].
  final bool byDate;
  final DateTime? dueDate;
  final int? everyAmount;
  final PeriodUnit? everyUnit;

  /// Baseline for repeating reminders; updated when the linked
  /// service/expense is logged (auto-reschedule).
  final double? lastDoneOdometer;
  final DateTime? lastDoneDate;
  final bool active;
  final String? notes;
  const Reminder({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.vehicleId,
    required this.target,
    required this.typeId,
    required this.repeat,
    required this.byDistance,
    this.dueOdometer,
    this.everyDistance,
    required this.byDate,
    this.dueDate,
    this.everyAmount,
    this.everyUnit,
    this.lastDoneOdometer,
    this.lastDoneDate,
    required this.active,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['vehicle_id'] = Variable<String>(vehicleId);
    {
      map['target'] = Variable<String>(
        $RemindersTable.$convertertarget.toSql(target),
      );
    }
    map['type_id'] = Variable<String>(typeId);
    map['repeat'] = Variable<bool>(repeat);
    map['by_distance'] = Variable<bool>(byDistance);
    if (!nullToAbsent || dueOdometer != null) {
      map['due_odometer'] = Variable<double>(dueOdometer);
    }
    if (!nullToAbsent || everyDistance != null) {
      map['every_distance'] = Variable<double>(everyDistance);
    }
    map['by_date'] = Variable<bool>(byDate);
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<DateTime>(dueDate);
    }
    if (!nullToAbsent || everyAmount != null) {
      map['every_amount'] = Variable<int>(everyAmount);
    }
    if (!nullToAbsent || everyUnit != null) {
      map['every_unit'] = Variable<String>(
        $RemindersTable.$convertereveryUnitn.toSql(everyUnit),
      );
    }
    if (!nullToAbsent || lastDoneOdometer != null) {
      map['last_done_odometer'] = Variable<double>(lastDoneOdometer);
    }
    if (!nullToAbsent || lastDoneDate != null) {
      map['last_done_date'] = Variable<DateTime>(lastDoneDate);
    }
    map['active'] = Variable<bool>(active);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  RemindersCompanion toCompanion(bool nullToAbsent) {
    return RemindersCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      vehicleId: Value(vehicleId),
      target: Value(target),
      typeId: Value(typeId),
      repeat: Value(repeat),
      byDistance: Value(byDistance),
      dueOdometer: dueOdometer == null && nullToAbsent
          ? const Value.absent()
          : Value(dueOdometer),
      everyDistance: everyDistance == null && nullToAbsent
          ? const Value.absent()
          : Value(everyDistance),
      byDate: Value(byDate),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      everyAmount: everyAmount == null && nullToAbsent
          ? const Value.absent()
          : Value(everyAmount),
      everyUnit: everyUnit == null && nullToAbsent
          ? const Value.absent()
          : Value(everyUnit),
      lastDoneOdometer: lastDoneOdometer == null && nullToAbsent
          ? const Value.absent()
          : Value(lastDoneOdometer),
      lastDoneDate: lastDoneDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastDoneDate),
      active: Value(active),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory Reminder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Reminder(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      vehicleId: serializer.fromJson<String>(json['vehicleId']),
      target: $RemindersTable.$convertertarget.fromJson(
        serializer.fromJson<String>(json['target']),
      ),
      typeId: serializer.fromJson<String>(json['typeId']),
      repeat: serializer.fromJson<bool>(json['repeat']),
      byDistance: serializer.fromJson<bool>(json['byDistance']),
      dueOdometer: serializer.fromJson<double?>(json['dueOdometer']),
      everyDistance: serializer.fromJson<double?>(json['everyDistance']),
      byDate: serializer.fromJson<bool>(json['byDate']),
      dueDate: serializer.fromJson<DateTime?>(json['dueDate']),
      everyAmount: serializer.fromJson<int?>(json['everyAmount']),
      everyUnit: $RemindersTable.$convertereveryUnitn.fromJson(
        serializer.fromJson<String?>(json['everyUnit']),
      ),
      lastDoneOdometer: serializer.fromJson<double?>(json['lastDoneOdometer']),
      lastDoneDate: serializer.fromJson<DateTime?>(json['lastDoneDate']),
      active: serializer.fromJson<bool>(json['active']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'vehicleId': serializer.toJson<String>(vehicleId),
      'target': serializer.toJson<String>(
        $RemindersTable.$convertertarget.toJson(target),
      ),
      'typeId': serializer.toJson<String>(typeId),
      'repeat': serializer.toJson<bool>(repeat),
      'byDistance': serializer.toJson<bool>(byDistance),
      'dueOdometer': serializer.toJson<double?>(dueOdometer),
      'everyDistance': serializer.toJson<double?>(everyDistance),
      'byDate': serializer.toJson<bool>(byDate),
      'dueDate': serializer.toJson<DateTime?>(dueDate),
      'everyAmount': serializer.toJson<int?>(everyAmount),
      'everyUnit': serializer.toJson<String?>(
        $RemindersTable.$convertereveryUnitn.toJson(everyUnit),
      ),
      'lastDoneOdometer': serializer.toJson<double?>(lastDoneOdometer),
      'lastDoneDate': serializer.toJson<DateTime?>(lastDoneDate),
      'active': serializer.toJson<bool>(active),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  Reminder copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? vehicleId,
    ReminderTarget? target,
    String? typeId,
    bool? repeat,
    bool? byDistance,
    Value<double?> dueOdometer = const Value.absent(),
    Value<double?> everyDistance = const Value.absent(),
    bool? byDate,
    Value<DateTime?> dueDate = const Value.absent(),
    Value<int?> everyAmount = const Value.absent(),
    Value<PeriodUnit?> everyUnit = const Value.absent(),
    Value<double?> lastDoneOdometer = const Value.absent(),
    Value<DateTime?> lastDoneDate = const Value.absent(),
    bool? active,
    Value<String?> notes = const Value.absent(),
  }) => Reminder(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    vehicleId: vehicleId ?? this.vehicleId,
    target: target ?? this.target,
    typeId: typeId ?? this.typeId,
    repeat: repeat ?? this.repeat,
    byDistance: byDistance ?? this.byDistance,
    dueOdometer: dueOdometer.present ? dueOdometer.value : this.dueOdometer,
    everyDistance: everyDistance.present
        ? everyDistance.value
        : this.everyDistance,
    byDate: byDate ?? this.byDate,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    everyAmount: everyAmount.present ? everyAmount.value : this.everyAmount,
    everyUnit: everyUnit.present ? everyUnit.value : this.everyUnit,
    lastDoneOdometer: lastDoneOdometer.present
        ? lastDoneOdometer.value
        : this.lastDoneOdometer,
    lastDoneDate: lastDoneDate.present ? lastDoneDate.value : this.lastDoneDate,
    active: active ?? this.active,
    notes: notes.present ? notes.value : this.notes,
  );
  Reminder copyWithCompanion(RemindersCompanion data) {
    return Reminder(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      target: data.target.present ? data.target.value : this.target,
      typeId: data.typeId.present ? data.typeId.value : this.typeId,
      repeat: data.repeat.present ? data.repeat.value : this.repeat,
      byDistance: data.byDistance.present
          ? data.byDistance.value
          : this.byDistance,
      dueOdometer: data.dueOdometer.present
          ? data.dueOdometer.value
          : this.dueOdometer,
      everyDistance: data.everyDistance.present
          ? data.everyDistance.value
          : this.everyDistance,
      byDate: data.byDate.present ? data.byDate.value : this.byDate,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      everyAmount: data.everyAmount.present
          ? data.everyAmount.value
          : this.everyAmount,
      everyUnit: data.everyUnit.present ? data.everyUnit.value : this.everyUnit,
      lastDoneOdometer: data.lastDoneOdometer.present
          ? data.lastDoneOdometer.value
          : this.lastDoneOdometer,
      lastDoneDate: data.lastDoneDate.present
          ? data.lastDoneDate.value
          : this.lastDoneDate,
      active: data.active.present ? data.active.value : this.active,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Reminder(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('target: $target, ')
          ..write('typeId: $typeId, ')
          ..write('repeat: $repeat, ')
          ..write('byDistance: $byDistance, ')
          ..write('dueOdometer: $dueOdometer, ')
          ..write('everyDistance: $everyDistance, ')
          ..write('byDate: $byDate, ')
          ..write('dueDate: $dueDate, ')
          ..write('everyAmount: $everyAmount, ')
          ..write('everyUnit: $everyUnit, ')
          ..write('lastDoneOdometer: $lastDoneOdometer, ')
          ..write('lastDoneDate: $lastDoneDate, ')
          ..write('active: $active, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    vehicleId,
    target,
    typeId,
    repeat,
    byDistance,
    dueOdometer,
    everyDistance,
    byDate,
    dueDate,
    everyAmount,
    everyUnit,
    lastDoneOdometer,
    lastDoneDate,
    active,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reminder &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.vehicleId == this.vehicleId &&
          other.target == this.target &&
          other.typeId == this.typeId &&
          other.repeat == this.repeat &&
          other.byDistance == this.byDistance &&
          other.dueOdometer == this.dueOdometer &&
          other.everyDistance == this.everyDistance &&
          other.byDate == this.byDate &&
          other.dueDate == this.dueDate &&
          other.everyAmount == this.everyAmount &&
          other.everyUnit == this.everyUnit &&
          other.lastDoneOdometer == this.lastDoneOdometer &&
          other.lastDoneDate == this.lastDoneDate &&
          other.active == this.active &&
          other.notes == this.notes);
}

class RemindersCompanion extends UpdateCompanion<Reminder> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> vehicleId;
  final Value<ReminderTarget> target;
  final Value<String> typeId;
  final Value<bool> repeat;
  final Value<bool> byDistance;
  final Value<double?> dueOdometer;
  final Value<double?> everyDistance;
  final Value<bool> byDate;
  final Value<DateTime?> dueDate;
  final Value<int?> everyAmount;
  final Value<PeriodUnit?> everyUnit;
  final Value<double?> lastDoneOdometer;
  final Value<DateTime?> lastDoneDate;
  final Value<bool> active;
  final Value<String?> notes;
  final Value<int> rowid;
  const RemindersCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.target = const Value.absent(),
    this.typeId = const Value.absent(),
    this.repeat = const Value.absent(),
    this.byDistance = const Value.absent(),
    this.dueOdometer = const Value.absent(),
    this.everyDistance = const Value.absent(),
    this.byDate = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.everyAmount = const Value.absent(),
    this.everyUnit = const Value.absent(),
    this.lastDoneOdometer = const Value.absent(),
    this.lastDoneDate = const Value.absent(),
    this.active = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RemindersCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String vehicleId,
    required ReminderTarget target,
    required String typeId,
    this.repeat = const Value.absent(),
    this.byDistance = const Value.absent(),
    this.dueOdometer = const Value.absent(),
    this.everyDistance = const Value.absent(),
    this.byDate = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.everyAmount = const Value.absent(),
    this.everyUnit = const Value.absent(),
    this.lastDoneOdometer = const Value.absent(),
    this.lastDoneDate = const Value.absent(),
    this.active = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : vehicleId = Value(vehicleId),
       target = Value(target),
       typeId = Value(typeId);
  static Insertable<Reminder> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? vehicleId,
    Expression<String>? target,
    Expression<String>? typeId,
    Expression<bool>? repeat,
    Expression<bool>? byDistance,
    Expression<double>? dueOdometer,
    Expression<double>? everyDistance,
    Expression<bool>? byDate,
    Expression<DateTime>? dueDate,
    Expression<int>? everyAmount,
    Expression<String>? everyUnit,
    Expression<double>? lastDoneOdometer,
    Expression<DateTime>? lastDoneDate,
    Expression<bool>? active,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (target != null) 'target': target,
      if (typeId != null) 'type_id': typeId,
      if (repeat != null) 'repeat': repeat,
      if (byDistance != null) 'by_distance': byDistance,
      if (dueOdometer != null) 'due_odometer': dueOdometer,
      if (everyDistance != null) 'every_distance': everyDistance,
      if (byDate != null) 'by_date': byDate,
      if (dueDate != null) 'due_date': dueDate,
      if (everyAmount != null) 'every_amount': everyAmount,
      if (everyUnit != null) 'every_unit': everyUnit,
      if (lastDoneOdometer != null) 'last_done_odometer': lastDoneOdometer,
      if (lastDoneDate != null) 'last_done_date': lastDoneDate,
      if (active != null) 'active': active,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RemindersCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? vehicleId,
    Value<ReminderTarget>? target,
    Value<String>? typeId,
    Value<bool>? repeat,
    Value<bool>? byDistance,
    Value<double?>? dueOdometer,
    Value<double?>? everyDistance,
    Value<bool>? byDate,
    Value<DateTime?>? dueDate,
    Value<int?>? everyAmount,
    Value<PeriodUnit?>? everyUnit,
    Value<double?>? lastDoneOdometer,
    Value<DateTime?>? lastDoneDate,
    Value<bool>? active,
    Value<String?>? notes,
    Value<int>? rowid,
  }) {
    return RemindersCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      vehicleId: vehicleId ?? this.vehicleId,
      target: target ?? this.target,
      typeId: typeId ?? this.typeId,
      repeat: repeat ?? this.repeat,
      byDistance: byDistance ?? this.byDistance,
      dueOdometer: dueOdometer ?? this.dueOdometer,
      everyDistance: everyDistance ?? this.everyDistance,
      byDate: byDate ?? this.byDate,
      dueDate: dueDate ?? this.dueDate,
      everyAmount: everyAmount ?? this.everyAmount,
      everyUnit: everyUnit ?? this.everyUnit,
      lastDoneOdometer: lastDoneOdometer ?? this.lastDoneOdometer,
      lastDoneDate: lastDoneDate ?? this.lastDoneDate,
      active: active ?? this.active,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (target.present) {
      map['target'] = Variable<String>(
        $RemindersTable.$convertertarget.toSql(target.value),
      );
    }
    if (typeId.present) {
      map['type_id'] = Variable<String>(typeId.value);
    }
    if (repeat.present) {
      map['repeat'] = Variable<bool>(repeat.value);
    }
    if (byDistance.present) {
      map['by_distance'] = Variable<bool>(byDistance.value);
    }
    if (dueOdometer.present) {
      map['due_odometer'] = Variable<double>(dueOdometer.value);
    }
    if (everyDistance.present) {
      map['every_distance'] = Variable<double>(everyDistance.value);
    }
    if (byDate.present) {
      map['by_date'] = Variable<bool>(byDate.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (everyAmount.present) {
      map['every_amount'] = Variable<int>(everyAmount.value);
    }
    if (everyUnit.present) {
      map['every_unit'] = Variable<String>(
        $RemindersTable.$convertereveryUnitn.toSql(everyUnit.value),
      );
    }
    if (lastDoneOdometer.present) {
      map['last_done_odometer'] = Variable<double>(lastDoneOdometer.value);
    }
    if (lastDoneDate.present) {
      map['last_done_date'] = Variable<DateTime>(lastDoneDate.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemindersCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('target: $target, ')
          ..write('typeId: $typeId, ')
          ..write('repeat: $repeat, ')
          ..write('byDistance: $byDistance, ')
          ..write('dueOdometer: $dueOdometer, ')
          ..write('everyDistance: $everyDistance, ')
          ..write('byDate: $byDate, ')
          ..write('dueDate: $dueDate, ')
          ..write('everyAmount: $everyAmount, ')
          ..write('everyUnit: $everyUnit, ')
          ..write('lastDoneOdometer: $lastDoneOdometer, ')
          ..write('lastDoneDate: $lastDoneDate, ')
          ..write('active: $active, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsEntriesTable extends SettingsEntries
    with TableInfo<$SettingsEntriesTable, SettingsEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingsEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingsEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingsEntry(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsEntriesTable createAlias(String alias) {
    return $SettingsEntriesTable(attachedDatabase, alias);
  }
}

class SettingsEntry extends DataClass implements Insertable<SettingsEntry> {
  final String key;
  final String value;
  const SettingsEntry({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsEntriesCompanion toCompanion(bool nullToAbsent) {
    return SettingsEntriesCompanion(key: Value(key), value: Value(value));
  }

  factory SettingsEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingsEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingsEntry copyWith({String? key, String? value}) =>
      SettingsEntry(key: key ?? this.key, value: value ?? this.value);
  SettingsEntry copyWithCompanion(SettingsEntriesCompanion data) {
    return SettingsEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingsEntry(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingsEntry &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsEntriesCompanion extends UpdateCompanion<SettingsEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsEntriesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsEntriesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingsEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsEntriesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsEntriesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsEntriesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxTable extends SyncOutbox
    with TableInfo<$SyncOutboxTable, SyncOutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _targetTableMeta = const VerificationMeta(
    'targetTable',
  );
  @override
  late final GeneratedColumn<String> targetTable = GeneratedColumn<String>(
    'target_table',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<String> rowId = GeneratedColumn<String>(
    'row_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [seq, targetTable, rowId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncOutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('target_table')) {
      context.handle(
        _targetTableMeta,
        targetTable.isAcceptableOrUnknown(
          data['target_table']!,
          _targetTableMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetTableMeta);
    }
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rowIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {targetTable, rowId},
  ];
  @override
  SyncOutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOutboxData(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      targetTable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_table'],
      )!,
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_id'],
      )!,
    );
  }

  @override
  $SyncOutboxTable createAlias(String alias) {
    return $SyncOutboxTable(attachedDatabase, alias);
  }
}

class SyncOutboxData extends DataClass implements Insertable<SyncOutboxData> {
  /// Monotonic queue position (SQLite `AUTOINCREMENT` never reuses values).
  final int seq;

  /// SQL name of the changed table, e.g. `refuelings`.
  final String targetTable;

  /// `id` of the changed row.
  final String rowId;
  const SyncOutboxData({
    required this.seq,
    required this.targetTable,
    required this.rowId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['target_table'] = Variable<String>(targetTable);
    map['row_id'] = Variable<String>(rowId);
    return map;
  }

  SyncOutboxCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxCompanion(
      seq: Value(seq),
      targetTable: Value(targetTable),
      rowId: Value(rowId),
    );
  }

  factory SyncOutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOutboxData(
      seq: serializer.fromJson<int>(json['seq']),
      targetTable: serializer.fromJson<String>(json['targetTable']),
      rowId: serializer.fromJson<String>(json['rowId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'targetTable': serializer.toJson<String>(targetTable),
      'rowId': serializer.toJson<String>(rowId),
    };
  }

  SyncOutboxData copyWith({int? seq, String? targetTable, String? rowId}) =>
      SyncOutboxData(
        seq: seq ?? this.seq,
        targetTable: targetTable ?? this.targetTable,
        rowId: rowId ?? this.rowId,
      );
  SyncOutboxData copyWithCompanion(SyncOutboxCompanion data) {
    return SyncOutboxData(
      seq: data.seq.present ? data.seq.value : this.seq,
      targetTable: data.targetTable.present
          ? data.targetTable.value
          : this.targetTable,
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxData(')
          ..write('seq: $seq, ')
          ..write('targetTable: $targetTable, ')
          ..write('rowId: $rowId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(seq, targetTable, rowId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOutboxData &&
          other.seq == this.seq &&
          other.targetTable == this.targetTable &&
          other.rowId == this.rowId);
}

class SyncOutboxCompanion extends UpdateCompanion<SyncOutboxData> {
  final Value<int> seq;
  final Value<String> targetTable;
  final Value<String> rowId;
  const SyncOutboxCompanion({
    this.seq = const Value.absent(),
    this.targetTable = const Value.absent(),
    this.rowId = const Value.absent(),
  });
  SyncOutboxCompanion.insert({
    this.seq = const Value.absent(),
    required String targetTable,
    required String rowId,
  }) : targetTable = Value(targetTable),
       rowId = Value(rowId);
  static Insertable<SyncOutboxData> custom({
    Expression<int>? seq,
    Expression<String>? targetTable,
    Expression<String>? rowId,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (targetTable != null) 'target_table': targetTable,
      if (rowId != null) 'row_id': rowId,
    });
  }

  SyncOutboxCompanion copyWith({
    Value<int>? seq,
    Value<String>? targetTable,
    Value<String>? rowId,
  }) {
    return SyncOutboxCompanion(
      seq: seq ?? this.seq,
      targetTable: targetTable ?? this.targetTable,
      rowId: rowId ?? this.rowId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (targetTable.present) {
      map['target_table'] = Variable<String>(targetTable.value);
    }
    if (rowId.present) {
      map['row_id'] = Variable<String>(rowId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxCompanion(')
          ..write('seq: $seq, ')
          ..write('targetTable: $targetTable, ')
          ..write('rowId: $rowId')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  late final $VehiclesTable vehicles = $VehiclesTable(this);
  late final $CatalogItemsTable catalogItems = $CatalogItemsTable(this);
  late final $RefuelingsTable refuelings = $RefuelingsTable(this);
  late final $RefuelingFuelsTable refuelingFuels = $RefuelingFuelsTable(this);
  late final $EntriesTable entries = $EntriesTable(this);
  late final $EntryItemsTable entryItems = $EntryItemsTable(this);
  late final $RoutesTable routes = $RoutesTable(this);
  late final $ReadingsTable readings = $ReadingsTable(this);
  late final $RemindersTable reminders = $RemindersTable(this);
  late final $SettingsEntriesTable settingsEntries = $SettingsEntriesTable(
    this,
  );
  late final $SyncOutboxTable syncOutbox = $SyncOutboxTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    vehicles,
    catalogItems,
    refuelings,
    refuelingFuels,
    entries,
    entryItems,
    routes,
    readings,
    reminders,
    settingsEntries,
    syncOutbox,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}
