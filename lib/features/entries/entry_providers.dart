import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/providers.dart';
import 'entry_queries.dart';

export 'entry_queries.dart' show EntryLine, EntryWithItems;

/// Which entries to list: one vehicle, optionally only one kind.
/// A record, so two filters with the same values are equal (Riverpod reuses
/// the same provider instance for them — like a React Query key).
typedef EntryFilter = ({String vehicleId, EntryKind? kind});

/// Live expenses/services/incomes of a vehicle, newest first.
///
/// `ref.watch(entriesProvider((vehicleId: id, kind: EntryKind.service)))`
final entriesProvider = StreamProvider.autoDispose
    .family<List<EntryWithItems>, EntryFilter>(
      (ref, filter) => ref
          .watch(databaseProvider)
          .watchEntries(filter.vehicleId, kind: filter.kind),
    );

/// One live entry by id (null once deleted) — for detail views.
final entryProvider = StreamProvider.autoDispose
    .family<EntryWithItems?, String>(
      (ref, id) => ref.watch(databaseProvider).watchEntry(id),
    );
