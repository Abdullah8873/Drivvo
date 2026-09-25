import '../db/tables.dart' show ChecklistStatus;

/// How many lines of a checklist run got each result.
class ChecklistCounts {
  const ChecklistCounts({
    this.ok = 0,
    this.problem = 0,
    this.na = 0,
    this.unchecked = 0,
  });

  /// Counts the statuses of a run's lines (null = not checked).
  factory ChecklistCounts.of(Iterable<ChecklistStatus?> statuses) {
    var ok = 0, problem = 0, na = 0, unchecked = 0;
    for (final s in statuses) {
      switch (s) {
        case ChecklistStatus.ok:
          ok++;
        case ChecklistStatus.problem:
          problem++;
        case ChecklistStatus.na:
          na++;
        case null:
          unchecked++;
      }
    }
    return ChecklistCounts(
      ok: ok,
      problem: problem,
      na: na,
      unchecked: unchecked,
    );
  }

  final int ok;
  final int problem;
  final int na;
  final int unchecked;

  int get total => ok + problem + na + unchecked;

  /// "8 OK · 1 problem" — zero counts are left out, except that a run with
  /// nothing checked says "Not checked".
  String get summary {
    final parts = [
      if (ok > 0) '$ok OK',
      if (problem > 0) '$problem ${problem == 1 ? 'problem' : 'problems'}',
      if (na > 0) '$na N/A',
    ];
    return parts.isEmpty ? 'Not checked' : parts.join(' · ');
  }
}
