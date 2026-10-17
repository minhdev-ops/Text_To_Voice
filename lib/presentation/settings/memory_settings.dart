import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

/// Low-memory mode, as one synchronous value (NFR-04 / NFR-05).
///
/// **This used to be a dead switch.** The Settings tile wrote `low_memory_mode`
/// into the `settings` table and nothing ever read it back, so a user who turned
/// it on to save memory on a cheap phone saw no change at all — the tile made a
/// promise the app did not keep. The setting is now a real provider that the
/// memory-hungry paths read.
///
/// **Why this is a `Notifier<bool>` and not a `FutureProvider<bool>`.** The
/// consumers are synchronous: `KeptDocuments.add` and `CaptureController.keep`
/// have to decide whether to retain page bytes *while they are building the
/// value*, and a callback cannot await a database read without either becoming
/// `async` (changing the capture flow's shape) or rendering a frame of the
/// memory-heavy version first. The persisted value is therefore read once, off
/// the build path, and mirrored into this value; the database stays the single
/// write path via [set].
///
/// Default is `false`, which is exactly the behaviour that shipped before, so a
/// cold start that has not finished restoring the setting behaves as it always
/// did rather than as an empty library.
class LowMemoryMode extends Notifier<bool> {
  @override
  bool build() {
    // Not awaited: `build` is synchronous, and nothing may wait on the database
    // to learn a preference. Guarded so a re-entry cannot double-read.
    unawaited(_restore());
    return false;
  }

  var _restored = false;

  Future<void> _restore() async {
    if (_restored) return;
    _restored = true;
    String? stored;
    try {
      stored =
          await ref.read(documentRepositoryProvider).getSetting(_settingKey);
    } catch (_) {
      // Reading a preference must never be able to break the flows that consult
      // it. An unavailable database (a test container with no database, a store
      // that has not finished opening) leaves the mode off, which is exactly the
      // behaviour that shipped before this setting did anything.
      return;
    }
    // The provider can be disposed while the read is in flight (a test tearing
    // the container down), and writing state then throws.
    if (!ref.mounted) return;
    if (stored == null) return;
    state = stored == 'true';
  }

  /// Turns the mode on or off and persists it, so the next launch agrees.
  Future<void> set(bool value) async {
    state = value;
    await ref
        .read(documentRepositoryProvider)
        .setSetting(_settingKey, value.toString());
  }

  static const String _settingKey = 'low_memory_mode';
}

final lowMemoryModeProvider =
    NotifierProvider<LowMemoryMode, bool>(LowMemoryMode.new);
