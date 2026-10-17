import 'dart:async' show unawaited;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

/// Which theme the app renders with.
///
/// One `Notifier` over one immutable value (state-management-riverpod):
/// widgets never set this field themselves, they call [select].
///
/// **The choice is persisted.** It used to be session-only, so picking "Tối"
/// and reopening the app put the user back on "Theo hệ thống" — the switch
/// looked like it silently reverted. `ThemeMode.system` is the default for a
/// cold start that has not finished restoring the stored value, which is the
/// behaviour the app shipped with before the tile did anything.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const String settingKey = 'theme_mode';

  @override
  ThemeMode build() {
    // Not awaited: `build` is synchronous and no frame may wait on the database
    // to learn a preference. Guarded so a rebuild cannot double-read.
    unawaited(_restore());
    return ThemeMode.system;
  }

  var _restored = false;

  Future<void> _restore() async {
    if (_restored) return;
    _restored = true;
    String? stored;
    try {
      stored = await ref.read(documentRepositoryProvider).getSetting(settingKey);
    } catch (_) {
      // A preference that cannot be read is a missing preference — never a
      // reason for the app to fail to render.
      return;
    }
    if (!ref.mounted || stored == null) return;
    // An unknown stored value (a name from a future version, a corrupt row) is
    // not a reason to fail: it falls back to the default the app started with.
    state = ThemeMode.values.asNameMap()[stored] ?? ThemeMode.system;
  }

  /// Selects a mode and persists it, so the next launch agrees.
  void select(ThemeMode mode) {
    // Every transition assigns a fresh value so value-equality listeners diff.
    if (state == mode) return;
    state = mode;
    unawaited(
      ref.read(documentRepositoryProvider).setSetting(settingKey, mode.name),
    );
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
