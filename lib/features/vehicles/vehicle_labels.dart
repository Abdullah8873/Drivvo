import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';

/// Display label + icon for each vehicle type. Dart extensions add members to
/// an existing type (here a DB enum) without touching its declaration.
extension VehicleTypeUi on VehicleType {
  String get label => switch (this) {
    VehicleType.car => 'Car',
    VehicleType.motorcycle => 'Motorcycle',
    VehicleType.truck => 'Truck',
    VehicleType.bus => 'Bus',
    VehicleType.boat => 'Boat',
    VehicleType.tractor => 'Tractor',
    VehicleType.airplane => 'Airplane',
    VehicleType.generator => 'Generator',
    VehicleType.other => 'Other',
  };

  IconData get icon => switch (this) {
    VehicleType.car => Icons.directions_car,
    VehicleType.motorcycle => Icons.two_wheeler,
    VehicleType.truck => Icons.local_shipping,
    VehicleType.bus => Icons.directions_bus,
    VehicleType.boat => Icons.directions_boat,
    VehicleType.tractor => Icons.agriculture,
    VehicleType.airplane => Icons.flight,
    VehicleType.generator => Icons.power,
    VehicleType.other => Icons.commute,
  };
}

extension FuelKindUi on FuelKind {
  String get label => switch (this) {
    FuelKind.liquid => 'Liquids',
    FuelKind.gas => 'Gas',
    FuelKind.electric => 'Electric',
  };
}

extension DistanceUnitUi on DistanceUnit {
  String get label => switch (this) {
    DistanceUnit.km => 'Kilometers',
    DistanceUnit.mi => 'Miles',
    DistanceUnit.hours => 'Hours',
  };
}

/// "model · plate" line shown under a vehicle's name (missing parts omitted).
String vehicleDetails(Vehicle v) => [
  v.model,
  v.plate,
].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
