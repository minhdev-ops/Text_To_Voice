import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/library/library_screen.dart';
import '../../presentation/models/models_screen.dart';
import '../../presentation/read_aloud/read_aloud_screen.dart';
import '../../presentation/settings/settings_screen.dart';

/// The four top-level destinations (≤ 5, per DESIGN.md cognitive-load rule).
///
/// Labels are always visible — icon-only navigation fails screen readers and
/// first-time users alike.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the already-active tab returns to that tab's root, which is
      // the platform convention and the cheapest way back to the top.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _goBranch,
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
