/// Manufacturer suggestions for the vehicle form's "Manufacturer" picker,
/// grouped by [VehicleType] and sorted A–Z. The field still stores plain
/// text (`vehicles.manufacturer`), so these lists are suggestions only — a
/// vehicle saved with a name that isn't here (typed via the picker's "+")
/// keeps showing correctly; see [brandsFor].
///
/// No real logos/artwork are used anywhere for these — see [brandAvatarColor]
/// — only a colored initial, to avoid trademarked material in the app.
library;

import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';

/// Cars, including the makes most common in the Pakistani market plus the
/// main global brands.
const carBrands = <String>[
  'Audi',
  'Bentley',
  'BMW',
  'Buick',
  'BYD',
  'Cadillac',
  'Changan',
  'Chery',
  'Chevrolet',
  'Chrysler',
  'Citroën',
  'Daewoo',
  'Daihatsu',
  'DFSK',
  'Dodge',
  'FAW',
  'Fiat',
  'Ford',
  'Geely',
  'Genesis',
  'GMC',
  'Great Wall',
  'Haval',
  'Honda',
  'Hyundai',
  'Infiniti',
  'Isuzu',
  'JAC',
  'Jaguar',
  'Jeep',
  'Kia',
  'Land Rover',
  'Lexus',
  'Lincoln',
  'Maserati',
  'Mazda',
  'Mercedes-Benz',
  'MG',
  'Mini',
  'Mitsubishi',
  'Nissan',
  'Opel',
  'Peugeot',
  'Porsche',
  'Prince',
  'Proton',
  'Renault',
  'Rolls-Royce',
  'Saab',
  'Seat',
  'Skoda',
  'Smart',
  'SsangYong',
  'Subaru',
  'Suzuki',
  'Tata',
  'Tesla',
  'Toyota',
  'Volkswagen',
  'Volvo',
];

/// Motorcycles/scooters common in Pakistan plus the main global brands.
const motorcycleBrands = <String>[
  'Aprilia',
  'Bajaj',
  'Benelli',
  'BMW Motorrad',
  'Crown',
  'Ducati',
  'Evee',
  'Harley-Davidson',
  'Hero',
  'Hi-Speed',
  'Honda',
  'Jolta',
  'Kawasaki',
  'KTM',
  'Lifan',
  'Metro',
  'Road Prince',
  'Royal Enfield',
  'Sazgar',
  'Super Power',
  'Suzuki',
  'Triumph',
  'TVS',
  'Unique',
  'United',
  'Vespa',
  'Yamaha',
  'Zongshen',
];

/// Trucks and buses.
const truckBusBrands = <String>[
  'Foton',
  'Hino',
  'Isuzu',
  'JAC',
  'MAN',
  'Master',
  'Mercedes-Benz',
  'Scania',
  'Shacman',
  'Volvo',
];

/// The brand list matching [type] (already sorted A–Z); other vehicle types
/// (boat, tractor, airplane, generator, other) don't have a well-known brand
/// set here, so they fall back to cars + motorcycles combined.
List<String> brandsFor(VehicleType type) {
  switch (type) {
    case VehicleType.car:
      return carBrands;
    case VehicleType.motorcycle:
      return motorcycleBrands;
    case VehicleType.truck:
    case VehicleType.bus:
      return truckBusBrands;
    case VehicleType.boat:
    case VehicleType.tractor:
    case VehicleType.airplane:
    case VehicleType.generator:
    case VehicleType.other:
      return _carsAndMotorcycles;
  }
}

final _carsAndMotorcycles = ({...carBrands, ...motorcycleBrands}.toList()
  ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())));

/// A palette cycled by a hash of the brand name so the same name always maps
/// to the same color (e.g. across the picker and the saved list) without
/// hard-coding a color per brand.
const _avatarPalette = <Color>[
  Color(0xFFE57373),
  Color(0xFF64B5F6),
  Color(0xFF81C784),
  Color(0xFFFFB74D),
  Color(0xFFBA68C8),
  Color(0xFF4DB6AC),
  Color(0xFFF06292),
  Color(0xFF9575CD),
  Color(0xFFAED581),
  Color(0xFF4FC3F7),
  Color(0xFFFF8A65),
  Color(0xFF90A4AE),
];

/// Deterministic color for a brand's avatar circle, derived from the name so
/// it never changes for a given brand and needs no per-brand table.
Color brandAvatarColor(String name) {
  if (name.isEmpty) return _avatarPalette.first;
  return _avatarPalette[name.toLowerCase().hashCode.abs() %
      _avatarPalette.length];
}

/// Small circular avatar showing a brand's initial on a deterministic color
/// (never a real logo — brand artwork is trademarked, see project rules).
class BrandAvatar extends StatelessWidget {
  const BrandAvatar({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final color = brandAvatarColor(name);
    return CircleAvatar(
      backgroundColor: color,
      child: Text(letter, style: const TextStyle(color: Colors.white)),
    );
  }
}
