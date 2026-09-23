import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/tables.dart';
import '../../core/format/formatters.dart';
import '../../core/providers.dart';
import 'history_providers.dart';
import 'history_queries.dart';
import 'widgets/timeline_widgets.dart';

/// True when [query] appears in any searchable text of [r]: title, fuel /
/// type names, station/place, notes, driver, route fields or the amount
/// (raw "1470.13" or formatted "PKR1,470.13").
bool recordMatches(TimelineRecord r, String query, Formatters fmt) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final route = r.route;
  final haystack = <String?>[
    r.title,
    r.module.label,
    for (final f in r.fuels) f.name,
    for (final i in r.items) ...[i.name, i.amount.toString()],
    r.place,
    r.paymentMethod,
    r.reason,
    r.notes,
    r.driver,
    r.entry?.title,
    route?.origin,
    route?.destination,
    route?.contractor,
    route?.cargoType,
    if (r.amount != 0) ...[
      r.amount.toStringAsFixed(2),
      r.amount.toString(),
      fmt.money(r.amount),
    ],
  ].whereType<String>().join('\n').toLowerCase();
  return haystack.contains(q);
}

/// Full-screen search over the current vehicle's timeline (pushed from the
/// History app bar's 🔍 button).
class HistorySearchScreen extends ConsumerStatefulWidget {
  const HistorySearchScreen({
    super.key,
    required this.vehicleId,
    required this.distanceUnit,
  });

  final String vehicleId;
  final DistanceUnit distanceUnit;

  @override
  ConsumerState<HistorySearchScreen> createState() =>
      _HistorySearchScreenState();
}

class _HistorySearchScreenState extends ConsumerState<HistorySearchScreen> {
  String _query = '';
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    final fmt = ref.watch(formattersProvider);
    final timeline = ref.watch(timelineProvider(widget.vehicleId));

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          key: const Key('history-search-field'),
          autofocus: true,
          cursorColor: Colors.white,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search records',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      body: timeline.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (records) {
          final hits = records
              .where((r) => recordMatches(r, _query, fmt))
              .toList();
          if (hits.isEmpty) {
            return Center(
              child: Text(
                'No records found',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            );
          }
          return ListView.builder(
            itemCount: hits.length,
            itemBuilder: (context, i) => TimelineRow(
              record: hits[i],
              timeline: records,
              distanceUnit: widget.distanceUnit,
              expanded: _expandedId == hits[i].id,
              onTap: () => setState(
                () =>
                    _expandedId = _expandedId == hits[i].id ? null : hits[i].id,
              ),
            ),
          );
        },
      ),
    );
  }
}
