import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/capture/camera_capture_screen.dart';
import '../../presentation/capture/scan_review_screen.dart';
import '../../presentation/library/history_favorites_screen.dart';
import '../../presentation/library/library_screen.dart';
import '../../presentation/models/models_screen.dart';
import '../../presentation/read_aloud/read_aloud_screen.dart';
import '../../presentation/settings/settings_screen.dart';
import 'app_shell.dart';

/// Top-level route paths. Screens own their own `location` constants; these
/// exist so shell code and tests can build paths without importing screens.
abstract final class RoutePaths {
  static const String library = LibraryScreen.location;
  static const String readAloud = ReadAloudScreen.location;
  static const String models = ModelsScreen.location;
  static const String settings = SettingsScreen.location;
  static const String history = ReadingHistoryScreen.location;
  static const String favorites = FavoritesScreen.location;

  /// Pushed routes — deliberately not tabs (DESIGN.md: no fifth tab).
  static const String capture = CameraCaptureScreen.location;
  static const String scanReview = ScanReviewScreen.location;

  /// The four shell destinations, in bottom-bar order.
  static const List<String> all = <String>[
    library,
    readAloud,
    models,
    settings,
  ];

  /// Everything reachable, including pushed routes. Tests walk this list.
  static const List<String> everyRoute = <String>[
    ...all,
    capture,
    scanReview,
    history,
    favorites,
  ];
}

/// Builds the app's declarative router.
///
/// A factory, not a global, so every test gets a fresh router — a shared
/// `GoRouter` leaks its branch stack between tests.
///
/// Four branches in a [StatefulShellRoute.indexedStack] (SRS §44 / DESIGN.md:
/// Library · Read aloud · Models · Settings), so each tab keeps its own scroll
/// position and back stack when you switch.
GoRouter createAppRouter() => GoRouter(
      initialLocation: RoutePaths.library,
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          redirect: (context, state) => RoutePaths.library,
        ),
        // Pushed over the shell on purpose: a camera session keeps running if
        // the user checks something in another tab, and `Back` from review must
        // return to the still-open camera rather than to the tab it started from.
        GoRoute(
          path: RoutePaths.capture,
          builder: (context, state) => const CameraCaptureScreen(),
          routes: <RouteBase>[
            GoRoute(
              path: 'review',
              builder: (context, state) => const ScanReviewScreen(),
            ),
          ],
        ),
        // History and Favorites — pushed routes accessible from Library
        GoRoute(
          path: RoutePaths.history,
          builder: (context, state) => const ReadingHistoryScreen(),
        ),
        GoRoute(
          path: RoutePaths.favorites,
          builder: (context, state) => const FavoritesScreen(),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: RoutePaths.library,
                  builder: (context, state) => const LibraryScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  // A branch's default location may not carry path parameters
                  // (go_router asserts this), and callers pass the document as
                  // a query parameter (`?documentId=...`) anyway.
                  path: RoutePaths.readAloud,
                  builder: (context, state) => const ReadAloudScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: RoutePaths.models,
                  builder: (context, state) => const ModelsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: RoutePaths.settings,
                  builder: (context, state) => const SettingsScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => RouteNotFoundScreen(
        attempted: state.uri.path,
      ),
    );

/// Unknown route. States what was requested and offers one way back rather
/// than a generic "Something went wrong".
class RouteNotFoundScreen extends StatelessWidget {
  const RouteNotFoundScreen({super.key, required this.attempted});

  final String attempted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Không tìm thấy trang')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Đường dẫn "$attempted" không tồn tại.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go(RoutePaths.library),
              child: const Text('Về Thư viện'),
            ),
          ],
        ),
      ),
    );
  }
}
