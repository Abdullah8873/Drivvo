import '../../core/calc/units.dart';
import '../../core/db/tables.dart';
import '../../core/format/formatters.dart';

/// Formats an efficiency from the consumption engine (distance per volume in
/// the vehicle's native units) the way the user asked for in Settings,
/// e.g. "42.765 km/L", "2.338 L/100km", "23.5 mpg US". Returns null when
/// there's nothing to show.
///
/// - Liquid fuels use the Settings efficiency format (12 options).
/// - CNG/LPG and electric have no such formats: "km/kg", "km/kWh".
/// - Hour-meter vehicles show consumption per hour: "1.250 L/h".
String? efficiencyText(
  Formatters fmt,
  DistanceUnit distanceUnit,
  double? nativeEfficiency, {
  FuelKind kind = FuelKind.liquid,
  int decimals = 3,
}) {
  if (nativeEfficiency == null || nativeEfficiency <= 0) return null;
  final volumeLabel = fmt.volumeUnitLabel(kind);

  if (distanceUnit == DistanceUnit.hours) {
    return '${(1 / nativeEfficiency).toStringAsFixed(decimals)} $volumeLabel/h';
  }
  if (kind != FuelKind.liquid) {
    final d = Formatters.distanceUnitLabel(distanceUnit);
    return '${nativeEfficiency.toStringAsFixed(decimals)} $d/$volumeLabel';
  }
  final format = fmt.settings.efficiencyFormat;
  final value = convertEfficiency(
    nativeEfficiency,
    distanceUnit,
    fmt.settings.volumeUnit,
    format,
  );
  return value == null
      ? null
      : '${value.toStringAsFixed(decimals)} ${format.label}';
}
