import 'package:flutter/material.dart';

import '../../core/calc/achievements.dart';
import '../../core/theme/app_theme.dart';

/// Visual look of one achievement badge — everything `core/calc/achievements`
/// doesn't know about (icon, shape, the small number Drivvo prints on some
/// badges). Keyed by [Achievement.id] in [badgeSpecFor].
class BadgeSpec {
  const BadgeSpec({
    required this.color,
    this.icon,
    this.number,
    this.hexagon = false,
  });

  /// Badge color when earned (locked badges are always grey).
  final Color color;

  /// Main icon, or null for the plain "VIP"-style number badges.
  final IconData? icon;

  /// Small number shown with the icon (or the whole content, when [icon] is
  /// null) — the achievement's threshold ("1", "25", "15"…).
  final String? number;

  /// Hexagon shape (row 5, "full tanks") vs the round scalloped shape used
  /// by every other row.
  final bool hexagon;
}

const _rowOneColor = AppTheme.primary;
const _yearsColor = Color(0xFFFF9800); // matches RecordModule.refueling
const _refuelColor = Color(0xFFC2185B); // matches RecordModule.reading (pink)
const _fullTankColor = Color(0xFF00897B);

/// Badge look for each of the 20 achievement ids, row by row (see
/// `docs/SPEC.md` "Verified hands-on in Drivvo").
final Map<String, BadgeSpec> _specs = {
  'first_record': const BadgeSpec(icon: Icons.check, color: _rowOneColor),
  'stations_10': const BadgeSpec(
    icon: Icons.local_gas_station,
    color: _rowOneColor,
  ),
  'same_station_15': const BadgeSpec(number: '15', color: _rowOneColor),
  'same_station_50': const BadgeSpec(number: '50', color: _rowOneColor),
  for (final n in [1, 2, 3, 4])
    'years_$n': BadgeSpec(icon: Icons.cake, number: '$n', color: _yearsColor),
  for (final n in [1, 25, 50, 75, 100, 250, 500, 1000])
    'refuels_$n': BadgeSpec(
      icon: Icons.water_drop,
      number: '$n',
      color: _refuelColor,
    ),
  for (final n in [15, 45, 90, 150])
    'full_tanks_$n': BadgeSpec(
      number: '$n',
      hexagon: true,
      color: _fullTankColor,
    ),
};

/// Looks up [id]'s badge look, falling back to a plain teal circle for any
/// id the map doesn't recognise (defensive — every real id is covered).
BadgeSpec badgeSpecFor(String id) =>
    _specs[id] ??
    const BadgeSpec(icon: Icons.emoji_events, color: _rowOneColor);

/// One badge: a scalloped (or hexagon, row 5) shape holding the icon and/or
/// number, colored when earned and greyed out when locked.
class AchievementBadge extends StatelessWidget {
  const AchievementBadge({
    super.key,
    required this.achievement,
    required this.size,
    this.onTap,
  });

  final Achievement achievement;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final spec = badgeSpecFor(achievement.id);
    final locked = !achievement.earned;
    final color = locked
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.18)
        : spec.color;
    final fg = locked
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)
        : Colors.white;
    final shape = spec.hexagon
        ? const StarBorder.polygon(sides: 6)
        : const StarBorder(points: 16, innerRadiusRatio: 0.9);

    return InkWell(
      key: Key('badge-${achievement.id}'),
      customBorder: shape,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: ShapeDecoration(color: color, shape: shape),
        child: Center(child: _content(spec, fg)),
      ),
    );
  }

  Widget _content(BadgeSpec spec, Color fg) {
    if (spec.icon != null && spec.number != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(spec.icon, color: fg, size: size * 0.34),
          Text(
            spec.number!,
            style: TextStyle(
              color: fg,
              fontSize: size * 0.2,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }
    if (spec.icon != null) {
      return Icon(spec.icon, color: fg, size: size * 0.4);
    }
    return Text(
      spec.number ?? '',
      style: TextStyle(
        color: fg,
        fontSize: size * 0.26,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
