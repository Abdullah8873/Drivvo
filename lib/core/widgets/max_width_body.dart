import 'package:flutter/material.dart';

/// Caps a scrollable body's width and centers it on wide windows (tablets,
/// desktop, landscape phones) so forms/settings-style lists/detail screens
/// don't stretch fields edge to edge — while the caller's `AppBar` stays
/// full width (this only wraps `Scaffold.body`, not the whole `Scaffold`).
///
/// Below 600 dp (phones, portrait) [child] gets the full width, unchanged
/// from before this widget existed — the 360×640 layout Drivvo was matched
/// against stays exactly as hand-QA'd.
///
/// Like a web layout's `max-width: 640px; margin: 0 auto` on the page's
/// main column, applied only past a tablet breakpoint.
class MaxWidthBody extends StatelessWidget {
  const MaxWidthBody({super.key, required this.child, this.maxWidth = 640});

  final Widget child;

  /// Cap for the body's width once the window is >= 600 dp wide. Forms and
  /// settings-style screens use the default 640; History/Reports' denser
  /// lists pass a wider ~840 so rows don't feel cramped.
  final double maxWidth;

  /// Windows narrower than this render [child] at full width, unchanged —
  /// matches Material's tablet breakpoint.
  static const _breakpoint = 600.0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < _breakpoint) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
