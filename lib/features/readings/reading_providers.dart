import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/providers.dart';
import 'reading_math.dart';
import 'reading_queries.dart';

/// Riverpod providers for readings — used by History and Reports.

/// Non-deleted readings of a vehicle, newest first.
final readingsProvider = StreamProvider.family<List<Reading>, String>(
  (ref, vehicleId) => ref.watch(databaseProvider).watchReadings(vehicleId),
);

/// One reading by id (null when missing or deleted).
final readingProvider = StreamProvider.family<Reading?, String>(
  (ref, id) => ref.watch(databaseProvider).watchReading(id),
);

/// Report filter: a vehicle plus an optional `[from, to)` date range.
typedef ReadingPeriod = ({String vehicleId, DateTime? from, DateTime? to});

/// Reading report numbers (distance, daily average, days between readings).
final readingStatsProvider =
    Provider.family<AsyncValue<ReadingStats>, ReadingPeriod>((ref, p) {
      return ref.watch(readingsProvider(p.vehicleId)).whenData((list) {
        final inPeriod = list.where(
          (r) =>
              (p.from == null || !r.date.isBefore(p.from!)) &&
              (p.to == null || r.date.isBefore(p.to!)),
        );
        return ReadingMath.stats(inPeriod.map((r) => r.point));
      });
    });
