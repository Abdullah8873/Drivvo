import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/providers.dart';
import '../../core/theme/record_module.dart';
import 'history_queries.dart';

/// Live timeline of one vehicle (≈ a `useQuery(['timeline', vehicleId])`
/// that refetches whenever the database changes).
final timelineProvider = StreamProvider.autoDispose
    .family<List<TimelineRecord>, String>(
      (ref, vehicleId) => ref.watch(databaseProvider).watchTimeline(vehicleId),
    );

/// Which vehicle a record belongs to — the detail screen only gets
/// `module` + `id` from the URL.
final recordVehicleIdProvider = FutureProvider.autoDispose
    .family<String?, (RecordModule, String)>(
      (ref, key) => ref.watch(databaseProvider).recordVehicleId(key.$1, key.$2),
    );

/// A single vehicle row (tank capacity, distance unit…).
final vehicleByIdProvider = StreamProvider.autoDispose.family<Vehicle?, String>(
  (ref, id) => ref.watch(databaseProvider).watchVehicle(id),
);
