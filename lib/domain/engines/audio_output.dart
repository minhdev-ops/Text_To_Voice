import 'dart:async';

/// Audio playback — SRS §26/§27 seam.
///
/// The app depends on this, never on a player plugin, for the same reason
/// [TtsEngine] exists: the transport logic (next/previous sentence, speed from
/// the next sentence, skip a failed sentence) is the part that has to be
/// testable, and it is testable only when playback is not a plugin call.
///
/// Phase 1 verified `just_audio 0.10.6` (ryanheise.com, Android) for the
/// plugin-backed implementation, which also brings `audio_service` for the
/// media notification (FR-11 background playback).
abstract interface class AudioOutput {
  /// Starts [path] from the beginning, replacing whatever was playing.
  Future<void> play(String path, {double volume = 1.0});

  /// Pauses, keeping the position so [play] could resume. Phase 1 restarts the
  /// sentence instead of resuming mid-word, which is what FR-12 makes cheap.
  Future<void> pause();

  Future<void> stop();

  /// Playback rate used the next time a sentence starts. Changing this must not
  /// restart the sentence currently playing (FR-10).
  Future<void> setSpeed(double speed);

  /// Output volume, 0..1. Safe to call while a sentence is playing.
  Future<void> setVolume(double volume);

  /// Position inside the current file. A cold stream emits nothing until a
  /// sentence starts.
  Stream<Duration> get position;

  /// Fires once each time the current file reaches its end.
  Stream<void> get completed;

  Future<void> dispose();
}
