import 'dart:async';
import 'dart:io' show Platform, Process, ProcessSignal, ProcessException;

import '../../core/logging/app_log.dart';
import '../../domain/engines/audio_output.dart';

/// Desktop audio output backed by the OS WAV player.
///
/// `just_audio` has no linux/windows native implementation
/// (`MethodChannelJustAudio.init()` throws `UnimplementedError`), so desktop
/// plays WAV files with the system player:
///
/// * linux — `paplay`, falling back to `aplay`
/// * macos — `afplay` (kept here for symmetry; `just_audio` also works on macos)
/// * windows — PowerShell `System.Media.SoundPlayer.PlaySync()`
///
/// True pause is not available from these players: pausing stops playback and
/// the next play restarts the sentence from its start. That matches how
/// [ReadAloudSession] already treats pause/play (position resets per sentence),
/// so the reader surface stays consistent. Speed is applied by re-synthesizing
/// at the requested speed rather than by changing the playback rate.
class DesktopAudioOutput implements AudioOutput {
  DesktopAudioOutput();

  Process? _process;
  int _playGeneration = 0;
  DateTime? _playStartedAt;
  Duration _positionAtPause = Duration.zero;
  bool _playing = false;

  final StreamController<void> _completedController =
      StreamController<void>.broadcast();
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  Timer? _positionTimer;

  /// The player command for the current platform.
  List<String> _playerCommand(String path) => switch (Platform.operatingSystem) {
        'linux' => <String>['paplay', path],
        'macos' => <String>['afplay', path],
        'windows' => <String>[
            'powershell.exe',
            '-NoProfile',
            '-Command',
            '(New-Object System.Media.SoundPlayer(\'$path\')).PlaySync()',
          ],
        _ => <String>['aplay', path],
      };

  @override
  Stream<Duration> get position => _positionController.stream;

  @override
  Stream<void> get completed => _completedController.stream;

  Duration _nowPosition() {
    if (!_playing || _playStartedAt == null) return _positionAtPause;
    return _positionAtPause + DateTime.now().difference(_playStartedAt!);
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!_playing) return;
      _positionController.add(_nowPosition());
    });
    _positionController.add(_nowPosition());
  }

  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  void _onCompleted(int generation) {
    if (generation != _playGeneration) return;
    _playing = false;
    _playStartedAt = null;
    _process = null;
    _stopPositionTimer();
    _completedController.add(null);
  }

  @override
  Future<void> play(String path, {double volume = 1.0}) async {
    await stop();
    _playGeneration++;
    final generation = _playGeneration;

    Process process;
    try {
      final command = _playerCommand(path);
      process = await Process.start(command.first, command.sublist(1));
    } on ProcessException catch (error) {
      AppLog.warning('audio.desktop.startFailed',
          data: <String, Object?>{
            'command': _playerCommand(path).join(' '),
            'error': '$error',
          });
      return;
    }

    _process = process;
    _playing = true;
    _playStartedAt = DateTime.now();
    _positionAtPause = Duration.zero;
    _startPositionTimer();
    process.exitCode.then((_) => _onCompleted(generation));
  }

  @override
  Future<void> pause() async {
    if (!_playing) return;
    _positionAtPause = _nowPosition();
    await stop();
  }

  @override
  Future<void> stop() async {
    _playing = false;
    _playStartedAt = null;
    _stopPositionTimer();
    final process = _process;
    _process = null;
    if (process != null) {
      try {
        process.kill(ProcessSignal.sigterm);
      } catch (_) {}
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    // Desktop system players do not expose playback rate. Speed is applied by
    // re-synthesizing at the requested speed (ReadAloudSession.setOptions
    // invalidates and re-synthesizes from the next sentence).
  }

  @override
  Future<void> setVolume(double volume) async {
    // Desktop system players are not volume-controlled from this output.
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _completedController.close();
    await _positionController.close();
  }
}
