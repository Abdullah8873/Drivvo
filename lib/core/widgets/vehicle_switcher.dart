import 'package:flutter/material.dart';

/// The rounded chip in the top-left of the main tabs showing the current
/// vehicle ("Honda Moto · 56935 km ▾"). Purely presentational: the
/// `MainTabAppBar` decides what to show and what tapping does.
class VehicleSwitcher extends StatelessWidget {
  const VehicleSwitcher({
    super.key,
    required this.name,
    this.subtitle,
    this.icon = Icons.directions_car,
    this.onTap,
  });

  final String name;

  /// Second line; hidden when null or empty.
  final String? subtitle;

  /// Vehicle type icon in the white circle.
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.white,
                child: Icon(icon, size: 16, color: Colors.grey),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (sub != null && sub.isNotEmpty)
                      Text(
                        sub,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
