/// Pure math for the Flex calculator (More → "Flex calculator") — no Flutter
/// imports, so it's unit-testable in isolation. See `docs/SPEC.md` "Verified
/// hands-on in Drivvo" for the exact behaviour this mirrors.
library;

/// Which fuel the calculator recommends.
enum FlexFuel { ethanol, gasoline }

/// Result of [FlexMath.calculate].
class FlexResult {
  const FlexResult({
    required this.ethanolToGasRatio,
    required this.recommendation,
  });

  /// Ethanol price ÷ gas price, as a percentage (e.g. `67.9` for 190/280).
  final double ethanolToGasRatio;

  final FlexFuel recommendation;
}

/// Flex-fuel (ethanol vs gasoline) break-even math: a flex engine burns more
/// ethanol per km than gasoline, so ethanol is only worth it when it's
/// cheap enough relative to gas — cheaper than the car's "autonomy
/// difference" (how much less distance a liter of ethanol covers).
class FlexMath {
  FlexMath._();

  /// Ethanol is worth using when its price is less than [autonomyPercent] of
  /// the gas price (e.g. ethanol at 65% of the gas price beats a car that
  /// only loses 30% autonomy on ethanol, i.e. a 70% autonomy difference).
  /// Equal ratio recommends gasoline (verified hands-on: 190/280 = 67.9% <
  /// 70% → ethanol).
  static FlexResult calculate({
    required double gasPrice,
    required double ethanolPrice,
    required double autonomyPercent,
  }) {
    final ratio = ethanolPrice / gasPrice * 100;
    return FlexResult(
      ethanolToGasRatio: ratio,
      recommendation: ratio < autonomyPercent
          ? FlexFuel.ethanol
          : FlexFuel.gasoline,
    );
  }
}
