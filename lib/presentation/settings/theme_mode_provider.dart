import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which theme the app renders with.
///
/// One `Notifier` over one immutable value (state-management-riverpod):
/// widgets never set this field themselves, they call [select]. Persisting the
/// choice to disk lands in Phase 5 with the rest of `settings` — until then
/// this is session-only, which is the honest scope.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void select(ThemeMode mode) {
    // Every transition assigns a fresh value so value-equality listeners diff.
    if (state == mode) return;
    state = mode;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
