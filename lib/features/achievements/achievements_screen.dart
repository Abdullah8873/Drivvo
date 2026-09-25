import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calc/achievements.dart';
import '../../core/providers.dart';
import 'achievement_badge.dart';
import 'achievements_providers.dart';

/// More → "Achievements": a 4-column grid of the current vehicle's 20
/// badges (see `docs/SPEC.md`) — colored when earned, grey when locked.
/// Tapping one opens a dialog with the badge, its text and the date earned.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleAsync = ref.watch(currentVehicleProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Achievements')),
      body: vehicleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (vehicle) => vehicle == null
            ? const Center(child: Text('No vehicle yet'))
            : _Grid(vehicleId: vehicle.id),
      ),
    );
  }
}

class _Grid extends ConsumerWidget {
  const _Grid({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievementsAsync = ref.watch(achievementsProvider(vehicleId));
    return achievementsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (achievements) => GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 4,
        mainAxisSpacing: 16,
        crossAxisSpacing: 8,
        childAspectRatio: 0.8,
        children: [
          for (final a in achievements)
            _GridItem(
              achievement: a,
              onTap: () => _showDialog(context, ref, a),
            ),
        ],
      ),
    );
  }

  void _showDialog(BuildContext context, WidgetRef ref, Achievement a) {
    final fmt = ref.read(formattersProvider);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AchievementBadge(achievement: a, size: 88),
            const SizedBox(height: 16),
            Text(a.text, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              a.earned ? fmt.date(a.earnedDate!) : 'Not achieved',
              style: TextStyle(
                color: a.earned
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _GridItem extends StatelessWidget {
  const _GridItem({required this.achievement, required this.onTap});

  final Achievement achievement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AchievementBadge(
          key: Key('badge-${achievement.id}'),
          achievement: achievement,
          size: 64,
          onTap: onTap,
        ),
      ],
    );
  }
}
