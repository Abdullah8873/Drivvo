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

/// The clock reports resolve periods against. Tests override it to pin
/// "today" (`reportNowProvider.overrideWithValue(() => DateTime(2026, 9, 24))`).
final reportNowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

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
