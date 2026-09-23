import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../theme/record_module.dart';
import 'speed_dial_menu.dart';

/// Layout wrapping the four main tabs: the active tab's page on top and the
/// bottom bar (History · Reports · [+] · Reminders · More) below it.
/// Similar to a React Router layout route with an `<Outlet />`.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  bool _menuOpen = false;

  void _toggleMenu() => setState(() => _menuOpen = !_menuOpen);

  void _openForm(RecordModule module) {
    setState(() => _menuOpen = false);
    context.push('/add/${module.name}');
  }

  void _goTab(int index) {
    setState(() => _menuOpen = false);
    widget.navigationShell.goBranch(
      index,
      // Tapping the active tab again pops back to its first page.
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          widget.navigationShell,
          if (_menuOpen) ...[
            // Dimmed backdrop; tap to close.
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleMenu,
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.3)),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Center(child: SpeedDialMenu(onSelected: _openForm)),
            ),
          ],
        ],
      ),
      bottomNavigationBar: _BottomBar(
        currentIndex: widget.navigationShell.currentIndex,
        menuOpen: _menuOpen,
        onTab: _goTab,
        onFab: _toggleMenu,
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.currentIndex,
    required this.menuOpen,
    required this.onTab,
    required this.onFab,
  });

  final int currentIndex;
  final bool menuOpen;
  final ValueChanged<int> onTab;
  final VoidCallback onFab;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              _NavItem(
                Icons.format_list_bulleted,
                'History',
                0,
                currentIndex,
                onTab,
              ),
              _NavItem(Icons.show_chart, 'Reports', 1, currentIndex, onTab),
              Expanded(
                child: Center(
                  child: FloatingActionButton(
                    heroTag: 'add',
                    elevation: 2,
                    shape: const CircleBorder(),
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    onPressed: onFab,
                    child: Icon(menuOpen ? Icons.close : Icons.add, size: 28),
                  ),
                ),
              ),
              _NavItem(Icons.alarm, 'Reminders', 2, currentIndex, onTab),
              _NavItem(Icons.more_horiz, 'More', 3, currentIndex, onTab),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem(
    this.icon,
    this.label,
    this.index,
    this.currentIndex,
    this.onTap,
  );

  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final selected = index == currentIndex;
    final color = selected ? AppTheme.primary : Colors.grey.shade700;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Light pill behind the selected icon (Material 3 indicator).
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
