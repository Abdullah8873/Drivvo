import 'tables.dart';

/// Default catalog entries created for a new account (same defaults Drivvo
/// ships with). Users can add, rename or delete them from the More tab.
class SeedData {
  SeedData._();

  /// Every seeded catalog, as `(kind, names)` pairs.
  static const catalogs = <(CatalogKind, List<String>)>[
    (CatalogKind.fuel, fuels),
    (CatalogKind.serviceType, serviceTypes),
    (CatalogKind.expenseType, expenseTypes),
    (CatalogKind.incomeType, incomeTypes),
    (CatalogKind.reason, reasons),
    (CatalogKind.paymentMethod, paymentMethods),
  ];

  /// Deterministic id of a seeded catalog item, e.g. `seed:fuel:petrol` or
  /// `seed:serviceType:oil-change`.
  ///
  /// Why not a random UUID: seeding must be idempotent (an interrupted first
  /// launch runs it again) and every device must seed the *same* rows, so
  /// cloud sync doesn't end up with one "Petrol" per device.
  static String idFor(CatalogKind kind, String name) =>
      'seed:${kind.name}:${slug(name)}';

  /// Default checklist templates ("Forms"), as `(name, item labels)`.
  static const checklistForms = <(String, List<String>)>[
    (
      'Pre-trip inspection',
      [
        'Tires',
        'Lights',
        'Brakes',
        'Engine oil level',
        'Coolant level',
        'Windshield & wipers',
        'Horn',
        'Mirrors',
        'Documents',
      ],
    ),
  ];

  /// Deterministic id of a seeded checklist template, e.g.
  /// `seed:checklistForm:pre-trip-inspection` (same reasoning as [idFor]).
  static String formIdFor(String name) => 'seed:checklistForm:${slug(name)}';

  /// Deterministic id of one item of a seeded template.
  static String formItemIdFor(String form, String label) =>
      'seed:checklistFormItem:${slug(form)}:${slug(label)}';

  /// Lower-case, dash-separated form of [name] (`Gas Midgrade` ->
  /// `gas-midgrade`).
  static String slug(String name) => name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  /// Tank kind a seeded fuel belongs to.
  static FuelKind fuelKindOf(String fuel) => switch (fuel) {
    'CNG' || 'LPG' => FuelKind.gas,
    'Electric' => FuelKind.electric,
    _ => FuelKind.liquid,
  };

  static const fuels = [
    'CNG',
    'Diesel',
    'Electric',
    'Ethanol',
    'Gas Midgrade',
    'Gas Premium',
    'Gasoline',
    'High Octane',
    'LPG',
    'Petrol',
  ];

  static const serviceTypes = [
    'Air Conditioning',
    'Air Filter',
    'Battery',
    'Belts',
    'Brake Fluid',
    'Brake Pad',
    'Car Wash',
    'Clutch Plates',
    'Fuel Filter',
    'Inspection',
    'Labor Cost',
    'Lights',
    'New Tires',
    'Oil Change',
    'Oil Filter',
    'Plug',
    'Suspension',
    'Tire Pressure',
    'Tire Rotation',
    'Wheel Alignment',
    'Wheel Balancing',
  ];

  static const expenseTypes = [
    'Financing',
    'Fine',
    'Insurance',
    'Parking',
    'Payment',
    'Registration',
    'Reimbursement',
    'Tax',
    'Tolls',
  ];

  static const incomeTypes = [
    'Freight',
    'Refund',
    'Ride',
    'Transport application',
    'Vehicle sale',
  ];

  static const reasons = ['Trip', 'Work'];

  static const paymentMethods = [
    'Credit card',
    'Debit card',
    'Money',
    'Online',
  ];
}
