import '../db/tables.dart' show DistanceUnit;
import '../settings/app_settings.dart' show EfficiencyFormat, VolumeUnit;

/// Unit conversions and fuel-efficiency formatting (Drivvo's 12 formats).
///
/// Everything here is plain math — no widgets — so it's easy to unit-test.
class Units {
  Units._();

  static const kmPerMile = 1.609344;
  static const litersPerGallonUs = 3.785411784;
  static const litersPerGallonImp = 4.54609;

  static double kmToMi(double km) => km / kmPerMile;
  static double miToKm(double mi) => mi * kmPerMile;

  /// Liters in one [unit] (1, 3.785…, 4.546…).
  static double litersPer(VolumeUnit unit) => switch (unit) {
    VolumeUnit.liter => 1,
    VolumeUnit.gallonUs => litersPerGallonUs,
    VolumeUnit.gallonImp => litersPerGallonImp,
  };

  /// Converts a liquid volume between units, e.g. 10 L → 2.64 gal US.
  static double convertVolume(double value, VolumeUnit from, VolumeUnit to) =>
      value * litersPer(from) / litersPer(to);

  /// Distance in km. [DistanceUnit.hours] can't be converted and is returned
  /// unchanged (hour-meter vehicles such as generators or boats).
  static double toKm(double value, DistanceUnit unit) =>
      unit == DistanceUnit.mi ? miToKm(value) : value;
}

/// Fuel efficiency for [distance] travelled on [volume], shown in [format].
///
/// - [distance] is in the vehicle's [distanceUnit] (km or mi).
/// - [volume] is in the liquid [volumeUnit] the user logs refuels in.
///
/// Handles both "distance per volume" formats (km/L, mpg…) and the inverse
/// "volume per 100 distance" ones (L/100km…). Returns null when the result
/// would be meaningless (no distance or no volume).
///
/// Example: `formatEfficiency(100, 10, DistanceUnit.km, VolumeUnit.liter,
/// EfficiencyFormat.mpgUs)` → 23.52.
double? formatEfficiency(
  double distance,
  double volume,
  DistanceUnit distanceUnit,
  VolumeUnit volumeUnit,
  EfficiencyFormat format,
) {
  if (distance <= 0 || volume <= 0) return null;
  final km = Units.toKm(distance, distanceUnit);
  final liters = volume * Units.litersPer(volumeUnit);

  // Target distance/volume units of the format, and whether it's inverted.
  final (toMiles, targetVolume, inverse) = switch (format) {
    EfficiencyFormat.kmPerLiter => (false, VolumeUnit.liter, false),
    EfficiencyFormat.kmPerGallonUs => (false, VolumeUnit.gallonUs, false),
    EfficiencyFormat.kmPerGallonImp => (false, VolumeUnit.gallonImp, false),
    EfficiencyFormat.litersPer100Km => (false, VolumeUnit.liter, true),
    EfficiencyFormat.gallonsUsPer100Km => (false, VolumeUnit.gallonUs, true),
    EfficiencyFormat.gallonsImpPer100Km => (false, VolumeUnit.gallonImp, true),
    EfficiencyFormat.milesPerLiter => (true, VolumeUnit.liter, false),
    EfficiencyFormat.mpgUs => (true, VolumeUnit.gallonUs, false),
    EfficiencyFormat.mpgImp => (true, VolumeUnit.gallonImp, false),
    EfficiencyFormat.litersPer100Mi => (true, VolumeUnit.liter, true),
    EfficiencyFormat.gallonsUsPer100Mi => (true, VolumeUnit.gallonUs, true),
    EfficiencyFormat.gallonsImpPer100Mi => (true, VolumeUnit.gallonImp, true),
  };
  // Hour meters have no km/mi equivalent, so keep the raw hours.
  final d = distanceUnit == DistanceUnit.hours
      ? distance
      : (toMiles ? Units.kmToMi(km) : km);
  final v = liters / Units.litersPer(targetVolume);
  return inverse ? v / d * 100 : d / v;
}

/// Converts an efficiency already expressed as "distance per volume" in the
/// vehicle's native units (what the consumption engine outputs) to [format].
double? convertEfficiency(
  double? nativeEfficiency,
  DistanceUnit distanceUnit,
  VolumeUnit volumeUnit,
  EfficiencyFormat format,
) {
  if (nativeEfficiency == null) return null;
  return formatEfficiency(
    nativeEfficiency,
    1,
    distanceUnit,
    volumeUnit,
    format,
  );
}

/// True for formats where a LOWER number is better (L/100km and friends).
bool isInverseFormat(EfficiencyFormat format) => switch (format) {
  EfficiencyFormat.litersPer100Km ||
  EfficiencyFormat.gallonsUsPer100Km ||
  EfficiencyFormat.gallonsImpPer100Km ||
  EfficiencyFormat.litersPer100Mi ||
  EfficiencyFormat.gallonsUsPer100Mi ||
  EfficiencyFormat.gallonsImpPer100Mi => true,
  _ => false,
};
