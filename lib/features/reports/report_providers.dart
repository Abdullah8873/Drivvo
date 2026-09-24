import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../history/history_providers.dart';
import 'report_period.dart';
import 'report_scope.dart';

/// Reports state (≈ a small global store shared by every report tab).
///
/// ```dart
/// final scope = ref.watch(reportScopeProvider);    // AsyncValue<ReportScope?>
/// ref.read(reportPeriodProvider.notifier).select(p); // change the filter
/// ```

/// Bumps when "today" may have changed: at the next midnight and whenever
/// the app comes back to the foreground (a phone app can sit in the
/// background for days). Nothing reads its value — watching it just makes
/// [reportNowProvider] (and every report built on it) re-evaluate, the way
/// a `useEffect` with a timer + `visibilitychange` listener would re-render
/// a web page.
class ReportDayTicker extends Notifier<int> {
  Timer? _midnight;

  @override
  int build() {
    _scheduleMidnight();
    final lifecycle = AppLifecycleListener(onResume: _tick);
    ref.onDispose(() {
      _midnight?.cancel();
      lifecycle.dispose();
    });
    return 0;
  }

  void _tick() {
    _scheduleMidnight();
    state++;
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1);
    // +1s so the new day has surely started when we re-read the clock.
    _midnight = Timer(next.difference(now) + const Duration(seconds: 1), _tick);
  }
}

final reportDayTickerProvider = NotifierProvider<ReportDayTicker, int>(
  ReportDayTicker.new,
);

/// The clock reports resolve periods against. Re-evaluates daily and on
/// app resume (see [ReportDayTicker]), so an app left open overnight moves
/// "Current month" / "Last month" etc. to the new day. Tests override it
/// to pin "today"
/// (`reportNowProvider.overrideWithValue(() => DateTime(2026, 9, 24))`),
/// which also skips the ticker (no timers in tests).
final reportNowProvider = Provider<DateTime Function()>((ref) {
  ref.watch(reportDayTickerProvider);
  // A fresh closure each time, so dependents see a new value and rebuild
  // (the `DateTime.now` tear-off would compare equal and notify no one).
  return () => DateTime.now();
});

/// Holds the period picked in the Filter screen. Not auto-disposed, so the
/// choice survives switching tabs (and leaving the Reports tab).
class ReportPeriodNotifier extends Notifier<ReportPeriod> {
  @override
  ReportPeriod build() => ReportPeriod.defaultPeriod;

  /// APPLY FILTER.
  void select(ReportPeriod period) => state = period;

  /// CLEAR FILTERS.
  void clear() => state = ReportPeriod.defaultPeriod;
}

/// The selected period, shared by every report tab.
final reportPeriodProvider =
    NotifierProvider<ReportPeriodNotifier, ReportPeriod>(
      ReportPeriodNotifier.new,
    );

/// The selected period resolved to a `[from, to)` range for today.
final reportRangeProvider = Provider<ReportRange>(
  (ref) =>
      ref.watch(reportPeriodProvider).rangeAt(ref.watch(reportNowProvider)()),
);

/// The current vehicle's records filtered by the selected period — the one
/// input every report tab starts from. `AsyncData(null)` = no vehicle yet.
/// Live: re-emits when records change (it's built on History's timeline).
final reportScopeProvider = Provider.autoDispose<AsyncValue<ReportScope?>>((
  ref,
) {
  final vehicleAsync = ref.watch(currentVehicleProvider);
  if (vehicleAsync.hasError) {
    return AsyncError(
      vehicleAsync.error!,
      vehicleAsync.stackTrace ?? StackTrace.current,
    );
  }
  if (!vehicleAsync.hasValue) return const AsyncLoading();
  final vehicle = vehicleAsync.value;
  if (vehicle == null) return const AsyncData(null);

  final period = ref.watch(reportPeriodProvider);
  final now = ref.watch(reportNowProvider)();
  return ref
      .watch(timelineProvider(vehicle.id))
      .whenData(
        (timeline) => ReportScope(
          vehicle: vehicle,
          period: period,
          range: period.rangeAt(now),
          timeline: timeline,
          now: now,
        ),
      );
});
