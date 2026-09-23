import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/calc/units.dart';
import 'package:motolog/core/db/tables.dart';
import 'package:motolog/core/settings/app_settings.dart';

void main() {
  group('Units', () {
    test('distance conversions', () {
      expect(Units.miToKm(1), closeTo(1.609344, 1e-9));
      expect(Units.kmToMi(160.9344), closeTo(100, 1e-9));
      expect(Units.toKm(10, DistanceUnit.mi), closeTo(16.09344, 1e-9));
      expect(Units.toKm(10, DistanceUnit.km), 10);
      expect(Units.toKm(10, DistanceUnit.hours), 10);
    });

    test('volume conversions', () {
      expect(
        Units.convertVolume(10, VolumeUnit.liter, VolumeUnit.gallonUs),
        closeTo(2.64172, 1e-5),
      );
      expect(
        Units.convertVolume(1, VolumeUnit.gallonImp, VolumeUnit.liter),
        closeTo(4.54609, 1e-9),
      );
      expect(
        Units.convertVolume(1, VolumeUnit.gallonImp, VolumeUnit.gallonUs),
        closeTo(1.20095, 1e-5),
      );
    });
  });

  group('formatEfficiency: 100 km on 10 L (10 km/L) in every format', () {
    const expected = {
      EfficiencyFormat.kmPerLiter: 10.0,
      EfficiencyFormat.kmPerGallonUs: 37.85412,
      EfficiencyFormat.kmPerGallonImp: 45.4609,
      EfficiencyFormat.litersPer100Km: 10.0,
      EfficiencyFormat.gallonsUsPer100Km: 2.64172,
      EfficiencyFormat.gallonsImpPer100Km: 2.19969,
      EfficiencyFormat.milesPerLiter: 6.21371,
      EfficiencyFormat.mpgUs: 23.52146,
      EfficiencyFormat.mpgImp: 28.24809,
      EfficiencyFormat.litersPer100Mi: 16.09344,
      EfficiencyFormat.gallonsUsPer100Mi: 4.25144,
      EfficiencyFormat.gallonsImpPer100Mi: 3.54006,
    };
    for (final MapEntry(key: format, value: value) in expected.entries) {
      test(format.label, () {
        expect(
          formatEfficiency(100, 10, DistanceUnit.km, VolumeUnit.liter, format),
          closeTo(value, 1e-4),
        );
      });
    }
  });

  group('formatEfficiency with non-metric inputs', () {
    test('30 mi on 1 gal US = 30 mpg US = 7.84 L/100km', () {
      expect(
        formatEfficiency(
          30,
          1,
          DistanceUnit.mi,
          VolumeUnit.gallonUs,
          EfficiencyFormat.mpgUs,
        ),
        closeTo(30, 1e-9),
      );
      expect(
        formatEfficiency(
          30,
          1,
          DistanceUnit.mi,
          VolumeUnit.gallonUs,
          EfficiencyFormat.litersPer100Km,
        ),
        closeTo(7.8405, 1e-4),
      );
    });

    test('invalid inputs return null', () {
      expect(
        formatEfficiency(
          0,
          5,
          DistanceUnit.km,
          VolumeUnit.liter,
          EfficiencyFormat.litersPer100Km,
        ),
        isNull,
      );
      expect(
        formatEfficiency(
          100,
          0,
          DistanceUnit.km,
          VolumeUnit.liter,
          EfficiencyFormat.kmPerLiter,
        ),
        isNull,
      );
    });

    test('convertEfficiency converts a native km/L value', () {
      expect(
        convertEfficiency(
          42.765,
          DistanceUnit.km,
          VolumeUnit.liter,
          EfficiencyFormat.litersPer100Km,
        ),
        closeTo(2.3384, 1e-4),
      );
      expect(
        convertEfficiency(
          null,
          DistanceUnit.km,
          VolumeUnit.liter,
          EfficiencyFormat.mpgUs,
        ),
        isNull,
      );
    });

    test('isInverseFormat', () {
      expect(isInverseFormat(EfficiencyFormat.litersPer100Km), isTrue);
      expect(isInverseFormat(EfficiencyFormat.mpgUs), isFalse);
    });
  });
}
