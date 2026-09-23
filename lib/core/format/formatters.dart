import 'package:intl/intl.dart';

import '../db/tables.dart';
import '../settings/app_settings.dart';

/// Display formatting driven by [AppSettings] — use these everywhere instead
/// of calling toStringAsFixed/DateFormat directly, so a settings change
/// (currency, date format, decimals, units) updates the whole app.
///
/// Get it in widgets with `ref.watch(formattersProvider)`.
class Formatters {
  Formatters(this.settings)
    : _money = NumberFormat.currency(
        name: settings.currencyCode,
        symbol: settings.currencyCode,
        decimalDigits: settings.showDecimals ? 2 : 0,
      ),
      _date = DateFormat(settings.datePattern);

  final AppSettings settings;
  final NumberFormat _money;
  final DateFormat _date;

  /// "PKR1,470" / "PKR1,470.00".
  String money(num value) => _money.format(value);

  /// "PKR293.030/L" — unit prices always keep 3 decimals like Drivvo.
  String unitPrice(num value, String unitSuffix) =>
      '${NumberFormat.currency(name: settings.currencyCode, symbol: settings.currencyCode, decimalDigits: 3).format(value)}/$unitSuffix';

  String date(DateTime d) => _date.format(d);

  /// "17 sep" style used on history rows.
  String shortDate(DateTime d) => DateFormat('dd MMM').format(d).toLowerCase();

  String time(DateTime d) => DateFormat('HH:mm').format(d);

  /// "5.017 L" / "5.02 L".
  String volume(num value, {FuelKind kind = FuelKind.liquid}) {
    final digits = settings.threeDecimalVolumes ? 3 : 2;
    return '${value.toStringAsFixed(digits)} ${volumeUnitLabel(kind)}';
  }

  String volumeUnitLabel([FuelKind kind = FuelKind.liquid]) => switch (kind) {
    FuelKind.electric => 'kWh',
    FuelKind.gas => settings.gasUnit == GasUnit.kg ? 'kg' : 'm³',
    FuelKind.liquid => switch (settings.volumeUnit) {
      VolumeUnit.liter => 'L',
      VolumeUnit.gallonUs || VolumeUnit.gallonImp => 'gal',
    },
  };

  /// "56935 km".
  String distance(num value, DistanceUnit unit) =>
      '${NumberFormat('#,##0', 'en').format(value).replaceAll(',', '')} ${distanceUnitLabel(unit)}';

  static String distanceUnitLabel(DistanceUnit unit) => switch (unit) {
    DistanceUnit.km => 'km',
    DistanceUnit.mi => 'mi',
    DistanceUnit.hours => 'h',
  };

  /// Plain number with fixed decimals ("39.344").
  String number(num value, {int decimals = 3}) =>
      value.toStringAsFixed(decimals);
}
