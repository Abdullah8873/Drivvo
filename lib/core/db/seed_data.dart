/// Default catalog entries created for a new account (same defaults Drivvo
/// ships with). Users can add, rename or delete them from the More tab.
class SeedData {
  SeedData._();

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
