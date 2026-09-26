import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Shared animation timings and small animated building blocks — the app's
/// "motion tokens", like CSS custom properties for `transition-duration`.
///
/// Every animation goes through [Motion.of] (or checks
/// [Motion.disabled]), so the OS "remove animations" accessibility setting
/// (`MediaQuery.disableAnimations`, ≈ `prefers-reduced-motion`) turns all
/// of them off.
abstract final class Motion {
  /// Small UI changes: tab fade, FAB icon, speed dial. Kept short: Drivvo
  /// shows these instantly (compared in BlueStacks), so ours only soften.
  static const short = Duration(milliseconds: 150);

  /// Screens and cards entering.
  static const medium = Duration(milliseconds: 250);

  /// Standard "decelerate into place" curve.
  static const curve = Curves.easeOutCubic;

  /// True when the user asked the OS to reduce motion.
  static bool disabled(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration], or zero when animations are disabled.
  static Duration of(BuildContext context, Duration duration) =>
      disabled(context) ? Duration.zero : duration;
}

/// Screen transition used for every pushed route on Android, web and
/// desktop: the new screen slides in a little from the right while fading
/// in, and the screen below drifts slightly left — like a CSS
/// `transform: translateX(…)` + `opacity` transition. iOS keeps its native
/// Cupertino transition (with the edge swipe-back gesture).
class SlideFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const SlideFadePageTransitionsBuilder();

  @override
  Duration get transitionDuration => Motion.medium;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (Motion.disabled(context)) return child;
    final incoming = CurvedAnimation(
      parent: animation,
      curve: Motion.curve,
      reverseCurve: Curves.easeInCubic,
    );
    final outgoing = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Motion.curve,
      reverseCurve: Curves.easeInCubic,
    );
    return SlideTransition(
      position: Tween(
        begin: Offset.zero,
        end: const Offset(-0.08, 0),
      ).animate(outgoing),
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0.2, 0),
          end: Offset.zero,
        ).animate(incoming),
        child: FadeTransition(opacity: incoming, child: child),
      ),
    );
  }
}

/// The app's page transitions per platform (see
/// [SlideFadePageTransitionsBuilder]).
const appPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: SlideFadePageTransitionsBuilder(),
    TargetPlatform.fuchsia: SlideFadePageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: SlideFadePageTransitionsBuilder(),
    TargetPlatform.linux: SlideFadePageTransitionsBuilder(),
  },
);

/// Fades [child] in while sliding it up a few pixels, once, when it first
/// appears — used for report cards and charts. [index] staggers a list's
/// items (each starts a little after the previous one, capped so long
/// lists don't wait). Later rebuilds (new data) don't replay it.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  static const _stagger = Duration(milliseconds: 40);
  static const _maxStaggered = 5;
  static const _distance = 12.0;

  @override
  Widget build(BuildContext context) {
    if (Motion.disabled(context)) return child;
    final delay = _stagger * index.clamp(0, _maxStaggered);
    final total = Motion.medium + delay;
    final start = delay.inMicroseconds / total.inMicroseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(start, 1, curve: Motion.curve),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, _distance * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
