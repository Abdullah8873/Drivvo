/// Transfer codes (More → Transfer): 8 characters from an alphabet without
/// look-alikes (no 0/O, 1/I/L), shown as `K7QM-3XPD`. The server generates
/// them (`create_transfer`); this file formats what the user sees and
/// cleans up what they type. Pure Dart, unit-tested.
library;

import 'dart:math';

abstract final class TransferCode {
  /// 31 characters: A–Z without I, L, O, plus 2–9 (no 0, 1). Must match
  /// `create_transfer` in the sharing migration.
  static const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  static const length = 8;

  /// How long a code stays valid.
  static const validity = Duration(days: 7);

  /// `K7QM3XPD` → `K7QM-3XPD` (anything else is returned unchanged).
  static String format(String code) => code.length == length
      ? '${code.substring(0, 4)}-${code.substring(4)}'
      : code;

  /// What the user typed → the stored form: upper case, with dashes,
  /// spaces and other separators removed.
  static String normalize(String input) =>
      input.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

  /// Whether [code] (normalized) has the right shape.
  static bool isValid(String code) =>
      code.length == length && code.split('').every(alphabet.contains);

  /// A random code (the in-memory test server's `create_transfer`).
  static String generate([Random? random]) {
    final r = random ?? Random.secure();
    return [
      for (var i = 0; i < length; i++) alphabet[r.nextInt(alphabet.length)],
    ].join();
  }
}
