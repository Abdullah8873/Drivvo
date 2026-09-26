import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/features/vehicles/vehicle_brands.dart';

bool _sortedIgnoreCase(List<String> items) {
  for (var i = 1; i < items.length; i++) {
    if (items[i - 1].toLowerCase().compareTo(items[i].toLowerCase()) > 0) {
      return false;
    }
  }
  return true;
}

void main() {
  test('brand lists are sorted A-Z and non-empty', () {
    expect(carBrands, isNotEmpty);
    expect(motorcycleBrands, isNotEmpty);
    expect(truckBusBrands, isNotEmpty);
    expect(_sortedIgnoreCase(carBrands), isTrue);
    expect(_sortedIgnoreCase(motorcycleBrands), isTrue);
    expect(_sortedIgnoreCase(truckBusBrands), isTrue);
  });

  test('brandsFor picks the list matching the vehicle type', () {
    expect(brandsFor(VehicleType.car), carBrands);
    expect(brandsFor(VehicleType.motorcycle), motorcycleBrands);
    expect(brandsFor(VehicleType.truck), truckBusBrands);
    expect(brandsFor(VehicleType.bus), truckBusBrands);
  });

  test('other vehicle types fall back to cars + motorcycles, sorted', () {
    final fallback = brandsFor(VehicleType.tractor);
    expect(fallback, isNotEmpty);
    expect(_sortedIgnoreCase(fallback), isTrue);
    expect(fallback, containsAll(['Suzuki', 'Honda', 'Toyota']));
  });

  test('brandAvatarColor is deterministic', () {
    expect(brandAvatarColor('Toyota'), brandAvatarColor('Toyota'));
    expect(brandAvatarColor('toyota'), brandAvatarColor('Toyota'));
  });
}
