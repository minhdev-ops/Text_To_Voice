import 'dart:async';

import 'package:text_to_voice/domain/engines/audio_output.dart';

/// A [AudioOutput] with no sound, driven by the test.
///
/// The tests advance playback explicitly via [complete] instead of waiting on a
/// real decoder, which is what makes "playback continues after a failed
/// sentence" a deterministic assertion rather than a timing race.
class FakeAudioOutput implements AudioOutput {
  final List<String> played = <String>[];
  final List<double> speeds = <double>[];
  final List<double> volumes = <double>[];

  int pauseCalls = 0;
  int stopCalls = 0;
  bool disposed = false;

  final StreamController<Duration> _position =
      StreamController<Duration>.broadcast();
  final StreamController<void> _completed = StreamController<void>.broadcast();

  bool get isPlaying => played.isNotEmpty && _playing;
  bool _playing = false;

  /// Path of the file currently loaded, or `null`.
  String? get currentPath => played.isEmpty ? null : played.last;

  @override
  Future<void> play(String path, {double volume = 1.0}) async {
    played.add(path);
    volumes.add(volume);
    _playing = true;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    _playing = false;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _playing = false;
  }

  @override
  Future<void> setSpeed(double speed) async => speeds.add(speed);

  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Stream<void> get completed => _completed.stream;

  /// Signals that the current sentence reached its end, as the player would.
  void complete() => _completed.add(null);

  /// Emits a position inside the current sentence.
  void emitPosition(Duration position) => _position.add(position);

  @override
  Future<void> dispose() async {
    disposed = true;
    await _position.close();
    await _completed.close();
  }
}
