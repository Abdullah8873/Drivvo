import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/sharing/invitation_banner.dart';
import '../../features/sharing/sharing_widgets.dart';
import '../calc/access_profile.dart';
import '../sharing/active_account.dart';
import '../theme/app_theme.dart';
import '../theme/record_module.dart';
import 'motion.dart';
import 'speed_dial_menu.dart';

/// Layout wrapping the four main tabs: the active tab's page on top and the
/// bottom bar (History · Reports · [+] · Reminders · More) below it.
/// Similar to a React Router layout route with an `<Outlet />`.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with TickerProviderStateMixin {
  bool _menuOpen = false;

  /// Speed dial open (1) / closed (0); the menu stays mounted while it
  /// animates closed.
  late final _menu = AnimationController(vsync: this, duration: Motion.short);

  /// Soft fade-in of the page when switching main tabs.
  late final _tabFade = AnimationController(
    vsync: this,
    duration: Motion.short,
    value: 1,
  );

  @override
  void didUpdateWidget(MainShell old) {
    super.didUpdateWidget(old);
    if (old.navigationShell.currentIndex !=
            widget.navigationShell.currentIndex &&
        !Motion.disabled(context)) {
      _tabFade.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _menu.dispose();
    _tabFade.dispose();
    super.dispose();
  }

  void _setMenu(bool open) {
    if (open == _menuOpen) return;
    setState(() => _menuOpen = open);
    _menu.duration = Motion.of(context, Motion.short);
    open ? _menu.forward() : _menu.reverse();
  }

  void _toggleMenu() => _setMenu(!_menuOpen);

  void _openForm(RecordModule module) {
    _setMenu(false);
    context.push('/add/${module.name}');
  }

  void _goTab(int index) {
    _setMenu(false);
    widget.navigationShell.goBranch(
      index,
      // Tapping the active tab again pops back to its first page.
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(currentAccessProvider);
    final modules = [
      for (final m in RecordModule.speedDialOrder)
        if (access.can(areaOfModule(m), AccessAction.register)) m,
    ];
    return Scaffold(
      body: Column(
        children: [
          Expanded(child: _body(context, modules)),
          // Pending invitation to someone's account (sharing).
          const InvitationBanner(),
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

  Widget _body(BuildContext context, List<RecordModule> modules) {
    return Stack(
      children: [
        FadeTransition(
          opacity: CurvedAnimation(parent: _tabFade, curve: Curves.easeOut),
          child: widget.navigationShell,
        ),
        AnimatedBuilder(
          animation: _menu,
          builder: (context, _) {
            if (_menu.isDismissed) return const SizedBox.shrink();
            final t = Motion.curve.transform(_menu.value);
            // While closing, taps go through to the page.
            return IgnorePointer(
              ignoring: !_menuOpen,
              child: Stack(
                children: [
                  // Dimmed backdrop; tap to close.
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _toggleMenu,
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.3 * t),
                      ),
                    ),
                  ),
                  // Bounded to the space between the status bar and the FAB,
                  // so on short screens the menu scrolls instead of pushing
                  // its top items off-screen and unreachable. Grows out of
                  // the + button.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: MediaQuery.paddingOf(context).top + 8,
                    bottom: 12,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Opacity(
                        opacity: t,
                        child: Transform.scale(
                          scale: 0.85 + 0.15 * t,
                          alignment: Alignment.bottomCenter,
                          child: Transform.translate(
                            offset: Offset(0, 16 * (1 - t)),
                            child: SpeedDialMenu(
                              onSelected: _openForm,
                              modules: modules,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
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
                    // + turns into × with a quarter spin.
                    child: AnimatedSwitcher(
                      duration: Motion.of(context, Motion.short),
                      transitionBuilder: (child, animation) =>
                          RotationTransition(
                            turns: Tween(
                              begin: 0.75,
                              end: 1.0,
                            ).animate(animation),
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          ),
                      child: Icon(
                        menuOpen ? Icons.close : Icons.add,
                        key: ValueKey(menuOpen),
                        size: 28,
                      ),
                    ),
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
    final color = selected
        ? AppTheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
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
            // FittedBox shrinks the label instead of wrapping it to a second
            // line ("Reminders" -> "Reminder / s") on narrow phones.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
