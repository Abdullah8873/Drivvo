import 'package:flutter/material.dart';

/// Liquid volume unit.
enum VolumeUnit { liter, gallonUs, gallonImp }

/// Gas (CNG/LPG) unit.
enum GasUnit { kg, cubicMeter }

/// How fuel efficiency is displayed (Drivvo's 12 options).
enum EfficiencyFormat {
  kmPerLiter('km/L'),
  kmPerGallonUs('km/gal US'),
  kmPerGallonImp('km/gal Imp'),
  litersPer100Km('L/100km'),
  gallonsUsPer100Km('gal US/100km'),
  gallonsImpPer100Km('gal Imp/100km'),
  milesPerLiter('mi/L'),
  mpgUs('mpg US'),
  mpgImp('mpg Imp'),
  litersPer100Mi('L/100mi'),
  gallonsUsPer100Mi('gal US/100mi'),
  gallonsImpPer100Mi('gal Imp/100mi');

  const EfficiencyFormat(this.label);
  final String label;
}

/// Whether a refuel cycle's efficiency is shown on the refuel that starts
/// the cycle or the one that ends it.
enum EconomyPosition { cycleStart, cycleEnd }

/// All user preferences (More → Settings). Immutable; update with copyWith.
/// Persisted as JSON in the `settings_entries` table.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.light,
    this.languageCode = 'en',
    this.datePattern = 'yyyy-MM-dd',
    this.currencyCode = 'PKR',
    this.showDecimals = true,
    this.threeDecimalVolumes = true,
    this.volumeUnit = VolumeUnit.liter,
    this.gasUnit = GasUnit.kg,
    this.efficiencyFormat = EfficiencyFormat.kmPerLiter,
    this.economyPosition = EconomyPosition.cycleStart,
    this.reminderDistanceAhead = 500,
    this.reminderDaysAhead = 30,
    this.notificationHour = 10,
    this.notificationMinute = 30,
    this.refuelingNotifications = true,
    this.tirePressureNotifications = true,
    this.gasStationNotifications = true,
    this.vibrate = true,
    this.selectedVehicleId,
  });

  final ThemeMode themeMode;
  final String languageCode;

  /// intl DateFormat pattern, e.g. 'yyyy-MM-dd', 'dd/MM/yyyy'.
  final String datePattern;

  /// ISO 4217 code, e.g. 'PKR', 'USD'.
  final String currencyCode;
  final bool showDecimals;
  final bool threeDecimalVolumes;
  final VolumeUnit volumeUnit;
  final GasUnit gasUnit;
  final EfficiencyFormat efficiencyFormat;
  final EconomyPosition economyPosition;

  /// Warn this many distance units before a distance reminder is due.
  final int reminderDistanceAhead;

  /// Warn this many days before a date reminder is due.
  final int reminderDaysAhead;
  final int notificationHour;
  final int notificationMinute;
  final bool refuelingNotifications;
  final bool tirePressureNotifications;
  final bool gasStationNotifications;
  final bool vibrate;

  /// Vehicle shown in the main tabs (null = first vehicle).
  final String? selectedVehicleId;

  static const datePatterns = [
    'yyyy-MM-dd',
    'dd/MM/yyyy',
    'MM/dd/yyyy',
    'dd.MM.yyyy',
    'dd-MM-yyyy',
  ];

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? languageCode,
    String? datePattern,
    String? currencyCode,
    bool? showDecimals,
    bool? threeDecimalVolumes,
    VolumeUnit? volumeUnit,
    GasUnit? gasUnit,
    EfficiencyFormat? efficiencyFormat,
    EconomyPosition? economyPosition,
    int? reminderDistanceAhead,
    int? reminderDaysAhead,
    int? notificationHour,
    int? notificationMinute,
    bool? refuelingNotifications,
    bool? tirePressureNotifications,
    bool? gasStationNotifications,
    bool? vibrate,
    String? selectedVehicleId,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      languageCode: languageCode ?? this.languageCode,
      datePattern: datePattern ?? this.datePattern,
      currencyCode: currencyCode ?? this.currencyCode,
      showDecimals: showDecimals ?? this.showDecimals,
      threeDecimalVolumes: threeDecimalVolumes ?? this.threeDecimalVolumes,
      volumeUnit: volumeUnit ?? this.volumeUnit,
      gasUnit: gasUnit ?? this.gasUnit,
      efficiencyFormat: efficiencyFormat ?? this.efficiencyFormat,
      economyPosition: economyPosition ?? this.economyPosition,
      reminderDistanceAhead:
          reminderDistanceAhead ?? this.reminderDistanceAhead,
      reminderDaysAhead: reminderDaysAhead ?? this.reminderDaysAhead,
      notificationHour: notificationHour ?? this.notificationHour,
      notificationMinute: notificationMinute ?? this.notificationMinute,
      refuelingNotifications:
          refuelingNotifications ?? this.refuelingNotifications,
      tirePressureNotifications:
          tirePressureNotifications ?? this.tirePressureNotifications,
      gasStationNotifications:
          gasStationNotifications ?? this.gasStationNotifications,
      vibrate: vibrate ?? this.vibrate,
      selectedVehicleId: selectedVehicleId ?? this.selectedVehicleId,
    );
  }

  Map<String, Object?> toJson() => {
    'themeMode': themeMode.name,
    'languageCode': languageCode,
    'datePattern': datePattern,
    'currencyCode': currencyCode,
    'showDecimals': showDecimals,
    'threeDecimalVolumes': threeDecimalVolumes,
    'volumeUnit': volumeUnit.name,
    'gasUnit': gasUnit.name,
    'efficiencyFormat': efficiencyFormat.name,
    'economyPosition': economyPosition.name,
    'reminderDistanceAhead': reminderDistanceAhead,
    'reminderDaysAhead': reminderDaysAhead,
    'notificationHour': notificationHour,
    'notificationMinute': notificationMinute,
    'refuelingNotifications': refuelingNotifications,
    'tirePressureNotifications': tirePressureNotifications,
    'gasStationNotifications': gasStationNotifications,
    'vibrate': vibrate,
    'selectedVehicleId': selectedVehicleId,
  };

  /// Unknown or missing keys fall back to defaults, so adding settings later
  /// never breaks existing installs.
  factory AppSettings.fromJson(Map<String, Object?> j) {
    const d = AppSettings();
    T pick<T extends Enum>(List<T> values, Object? v, T fallback) =>
        values.where((e) => e.name == v).firstOrNull ?? fallback;
    return AppSettings(
      themeMode: pick(ThemeMode.values, j['themeMode'], d.themeMode),
      languageCode: j['languageCode'] as String? ?? d.languageCode,
      datePattern: j['datePattern'] as String? ?? d.datePattern,
      currencyCode: j['currencyCode'] as String? ?? d.currencyCode,
      showDecimals: j['showDecimals'] as bool? ?? d.showDecimals,
      threeDecimalVolumes:
          j['threeDecimalVolumes'] as bool? ?? d.threeDecimalVolumes,
      volumeUnit: pick(VolumeUnit.values, j['volumeUnit'], d.volumeUnit),
      gasUnit: pick(GasUnit.values, j['gasUnit'], d.gasUnit),
      efficiencyFormat: pick(
        EfficiencyFormat.values,
        j['efficiencyFormat'],
        d.efficiencyFormat,
      ),
      economyPosition: pick(
        EconomyPosition.values,
        j['economyPosition'],
        d.economyPosition,
      ),
      reminderDistanceAhead:
          j['reminderDistanceAhead'] as int? ?? d.reminderDistanceAhead,
      reminderDaysAhead: j['reminderDaysAhead'] as int? ?? d.reminderDaysAhead,
      notificationHour: j['notificationHour'] as int? ?? d.notificationHour,
      notificationMinute:
          j['notificationMinute'] as int? ?? d.notificationMinute,
      refuelingNotifications:
          j['refuelingNotifications'] as bool? ?? d.refuelingNotifications,
      tirePressureNotifications:
          j['tirePressureNotifications'] as bool? ??
          d.tirePressureNotifications,
      gasStationNotifications:
          j['gasStationNotifications'] as bool? ?? d.gasStationNotifications,
      vibrate: j['vibrate'] as bool? ?? d.vibrate,
      selectedVehicleId: j['selectedVehicleId'] as String?,
    );
  }
}
