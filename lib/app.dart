import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/settings/theme_mode_provider.dart';

/// Root widget: wires the locked themes to the four-branch router.
///
/// The router lives in state rather than in a top-level global so it is created
/// once per app and disposed with it — a global `GoRouter` would keep its
/// branch stack alive across tests.
class VietDocApp extends ConsumerStatefulWidget {
  const VietDocApp({super.key});

  @override
  ConsumerState<VietDocApp> createState() => _VietDocAppState();
}

class _VietDocAppState extends ConsumerState<VietDocApp> {
  late final GoRouter _router = createAppRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'VietDoc AI',
      debugShowCheckedModeBanner: false,
      // Literal palettes — see AppTheme for why fromSeed is banned here.
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}
