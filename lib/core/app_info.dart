/// App-wide constants the owner fills in once contact/share details exist —
/// kept in one file so About/Contact/Share app don't hardcode them inline.
abstract final class AppInfo {
  /// Address "Email us" sends feedback to. Empty hides that option.
  static const contactEmail = '';

  /// Public link shared alongside "Share app"/"Send feedback" text. Empty
  /// omits it (no store listing yet).
  static const shareUrl = '';

  static const appName = 'MotoLog';
}
