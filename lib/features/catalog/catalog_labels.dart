import 'package:flutter/material.dart';

import '../../core/db/tables.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/record_module.dart';

/// Display names and icons for each catalog, as shown in Drivvo's More menu.
extension CatalogKindLabels on CatalogKind {
  /// Screen title (plural): "Gas stations".
  String get title => switch (this) {
    CatalogKind.fuel => 'Fuel',
    CatalogKind.gasStation => 'Gas stations',
    CatalogKind.place => 'Places',
    CatalogKind.serviceType => 'Types of service',
    CatalogKind.expenseType => 'Types of expense',
    CatalogKind.incomeType => 'Types of income',
    CatalogKind.reason => 'Reasons',
    CatalogKind.paymentMethod => 'Payment methods',
  };

  /// Form title (singular): "Gas station".
  String get singular => switch (this) {
    CatalogKind.fuel => 'Fuel',
    CatalogKind.gasStation => 'Gas station',
    CatalogKind.place => 'Place',
    CatalogKind.serviceType => 'Type of service',
    CatalogKind.expenseType => 'Type of expense',
    CatalogKind.incomeType => 'Type of income',
    CatalogKind.reason => 'Reason',
    CatalogKind.paymentMethod => 'Payment method',
  };

  IconData get icon => switch (this) {
    CatalogKind.fuel => Icons.local_gas_station,
    CatalogKind.gasStation => Icons.ev_station,
    CatalogKind.place => Icons.place,
    CatalogKind.serviceType => Icons.build,
    CatalogKind.expenseType => Icons.receipt_long,
    CatalogKind.incomeType => Icons.trending_up,
    CatalogKind.reason => Icons.work,
    CatalogKind.paymentMethod => Icons.payments,
  };

  /// Gas stations and places also store an address.
  bool get hasAddress =>
      this == CatalogKind.gasStation || this == CatalogKind.place;

  /// Marker/pin color on the My places map — gas stations share the
  /// refueling module's orange (they're where you refuel), other located
  /// kinds (places) use the general teal.
  Color get markerColor => this == CatalogKind.gasStation
      ? RecordModule.refueling.color
      : AppTheme.primary;
}

extension FuelKindLabels on FuelKind {
  String get label => switch (this) {
    FuelKind.liquid => 'Liquids',
    FuelKind.gas => 'Gas',
    FuelKind.electric => 'Electric',
  };
}
