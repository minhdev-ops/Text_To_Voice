import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/responsive.dart' show useSideRail;
import '../../core/theme/tokens.dart' show Layout, Spacing;
import '../../presentation/library/library_screen.dart';
import '../../presentation/models/models_screen.dart';
import '../../presentation/read_aloud/read_aloud_screen.dart';
import '../../presentation/settings/settings_screen.dart';

/// The four top-level destinations (≤ 5, per DESIGN.md cognitive-load rule).
///
/// On wide screens the destinations render as a left rail so the reading area
/// keeps horizontal room; on narrow screens they collapse to a bottom bar.
/// Labels are always visible — icon-only navigation fails screen readers and
/// first-time users alike.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goBranch(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      // Tapping the already-active tab returns to that tab's root, which is
      // the platform convention and the cheapest way back to the top.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = useSideRail(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(
        children: [
          if (wide) _Rail(navigationShell: navigationShell, onTap: _goBranch),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) => _goBranch(context, index),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              backgroundColor: scheme.surface,
              surfaceTintColor: Colors.transparent,
              indicatorColor: scheme.primary,
              elevation: 0,
              destinations: const <NavigationDestination>[
                NavigationDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder),
                  label: LibraryScreen.navLabel,
                ),
                NavigationDestination(
                  icon: Icon(Icons.record_voice_over_outlined),
                  selectedIcon: Icon(Icons.record_voice_over),
                  label: ReadAloudScreen.navLabel,
                ),
                NavigationDestination(
                  icon: Icon(Icons.memory_outlined),
                  selectedIcon: Icon(Icons.memory),
                  label: ModelsScreen.navLabel,
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: SettingsScreen.navLabel,
                ),
              ],
            ),
    );
  }
}

/// Left navigation rail for wide screens.
///
/// Fixed width so the rail never steals from the reading measure; labels are
/// always shown so the rail is scannable without hovering.
class _Rail extends StatelessWidget {
  const _Rail({
    required this.navigationShell,
    required this.onTap,
  });

  final StatefulNavigationShell navigationShell;
  final void Function(BuildContext, int) onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return SizedBox(
      width: Layout.readerMaxWidth / 3 + Spacing.s24,
      child: NavigationRail(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => onTap(context, index),
        labelType: NavigationRailLabelType.all,
        backgroundColor: scheme.surface,
        selectedIconTheme: IconThemeData(color: scheme.primary, size: 24),
        unselectedIconTheme:
            IconThemeData(color: scheme.onSurfaceVariant, size: 24),
        selectedLabelTextStyle: text.labelMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle:
            text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
        elevation: null,
        destinations: <NavigationRailDestination>[
          NavigationRailDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: Text(LibraryScreen.navLabel),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.record_voice_over_outlined),
            selectedIcon: Icon(Icons.record_voice_over),
            label: Text(ReadAloudScreen.navLabel),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.memory_outlined),
            selectedIcon: Icon(Icons.memory),
            label: Text(ModelsScreen.navLabel),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: Text(SettingsScreen.navLabel),
          ),
        ],
      ),
    );
  }
}
