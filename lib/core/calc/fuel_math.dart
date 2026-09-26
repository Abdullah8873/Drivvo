/// The three linked refueling values: total = price × volume.
enum FuelField { price, total, volume }

/// Pure helper for the "enter any two, the third is calculated" behaviour of
/// the refueling form. Kept free of Flutter so it's trivially unit-testable.
class FuelMath {
  FuelMath._();

  /// Computes the field that is NOT in [edited] (the two most recently edited
  /// fields) from the other two. Returns null when inputs are missing/invalid.
  static ({FuelField field, double value})? solve({
    required List<FuelField> edited,
    double? price,
    double? total,
    double? volume,
  }) {
    if (edited.length < 2) return null;
    final target = FuelField.values.firstWhere((f) => !edited.contains(f));
    switch (target) {
      case FuelField.total:
        if (price == null || volume == null) return null;
        return (field: target, value: price * volume);
      case FuelField.price:
        if (total == null || volume == null || volume == 0) return null;
        return (field: target, value: total / volume);
      case FuelField.volume:
        if (total == null || price == null || price == 0) return null;
        return (field: target, value: total / price);
    }
  }

  /// Keeps the last two distinct fields the user typed in, newest last.
  static List<FuelField> touch(List<FuelField> edited, FuelField field) {
    final next = [...edited.where((f) => f != field), field];
    return next.length > 2 ? next.sublist(next.length - 2) : next;
  }
}
