import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/calc/fuel_math.dart';

void main() {
  group('FuelMath.solve', () {
    test('computes total from price and volume', () {
      final r = FuelMath.solve(
        edited: [FuelField.price, FuelField.volume],
        price: 293.03,
        volume: 5.017,
      );
      expect(r!.field, FuelField.total);
      expect(r.value, closeTo(1470.13, 0.01));
    });

    test('computes volume from total and price', () {
      final r = FuelMath.solve(
        edited: [FuelField.total, FuelField.price],
        total: 1470,
        price: 293.03,
      );
      expect(r!.field, FuelField.volume);
      expect(r.value, closeTo(5.0166, 0.0001));
    });

    test('computes price from total and volume', () {
      final r = FuelMath.solve(
        edited: [FuelField.volume, FuelField.total],
        total: 2438,
        volume: 7.231,
      );
      expect(r!.field, FuelField.price);
      expect(r.value, closeTo(337.16, 0.01));
    });

    test(
      'returns null with fewer than two edited fields or division by zero',
      () {
        expect(FuelMath.solve(edited: [FuelField.price], price: 1), isNull);
        expect(
          FuelMath.solve(
            edited: [FuelField.total, FuelField.volume],
            total: 10,
            volume: 0,
          ),
          isNull,
        );
      },
    );
  });

  group('FuelMath.touch', () {
    test('keeps the two most recent distinct fields, newest last', () {
      var e = FuelMath.touch([], FuelField.price);
      e = FuelMath.touch(e, FuelField.volume);
      e = FuelMath.touch(e, FuelField.price);
      expect(e, [FuelField.volume, FuelField.price]);
      e = FuelMath.touch(e, FuelField.total);
      expect(e, [FuelField.price, FuelField.total]);
    });
  });
}
