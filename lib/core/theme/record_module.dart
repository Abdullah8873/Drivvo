import 'package:flutter/material.dart';

/// Every kind of record the app tracks. Each module has its own color and
/// icon, used for its app bar, timeline dot, save button and chart accents
/// (same visual language as Drivvo).
enum RecordModule {
  refueling('Refueling', Color(0xFFFF9800), Icons.local_gas_station),
  expense('Expense', Color(0xFFF0532A), Icons.receipt_long),
  income('Income', Color(0xFF2E7D32), Icons.trending_up),
  service('Service', Color(0xFF795548), Icons.build),
  route('Route', Color(0xFF607D8B), Icons.alt_route),
  reading('Reading', Color(0xFFC2185B), Icons.speed),
  checklist('Checklist', Color(0xFF1E88E5), Icons.checklist),
  reminder('Reminder', Color(0xFF673AB7), Icons.alarm);

  const RecordModule(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;

  /// Order used by the "+" speed-dial menu, top to bottom.
  static const speedDialOrder = [
    reminder,
    checklist,
    reading,
    route,
    service,
    income,
    expense,
    refueling,
  ];
}
