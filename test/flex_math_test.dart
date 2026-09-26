import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/calc/flex_math.dart';

void main() {
  group('FlexMath.calculate', () {
    test('recommends ethanol when it is cheap enough (verified hands-on)', () {
      final r = FlexMath.calculate(
        gasPrice: 280,
        ethanolPrice: 190,
        autonomyPercent: 70,
      );
      expect(r.ethanolToGasRatio, closeTo(67.857, 0.01));
      expect(r.recommendation, FlexFuel.ethanol);
    });

    test('recommends gasoline when ethanol is too expensive', () {
      final r = FlexMath.calculate(
        gasPrice: 280,
        ethanolPrice: 220,
        autonomyPercent: 70,
      );
      expect(r.recommendation, FlexFuel.gasoline);
    });

    test('equal ratio recommends gasoline (not strictly below)', () {
      final r = FlexMath.calculate(
        gasPrice: 200,
        ethanolPrice: 140,
        autonomyPercent: 70,
      );
      expect(r.ethanolToGasRatio, 70);
      expect(r.recommendation, FlexFuel.gasoline);
    });

    test('ratio just below autonomy still recommends ethanol', () {
      final r = FlexMath.calculate(
        gasPrice: 100,
        ethanolPrice: 69.9,
        autonomyPercent: 70,
      );
      expect(r.recommendation, FlexFuel.ethanol);
    });
  });
}
