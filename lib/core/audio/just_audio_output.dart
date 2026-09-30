import 'dart:async';

import 'package:just_audio/just_audio.dart' as ja;

import '../../core/logging/app_log.dart';
import '../../domain/engines/audio_output.dart';

/// [AudioOutput] backed by `just_audio` (verified on pub.dev as 0.10.6,
/// ryanheise.com — Android, actively maintained).
///
/// This is the only file in the app that knows a player plugin exists, which is
/// the point of the port: every rule that matters (which sentence plays next,
/// what happens when one fails, when a speed change takes effect) is in
/// `ReadAloudSession` and is tested without a device.
///
/// Every platform call is timed and logged (`audio.stage`): a phone that goes
/// silent used to leave no trace of *which* call never returned, because
/// `unawaited` futures and unlistened error streams swallow failures whole.
/// [watchdogAfter] only reports a stage that is taking too long — it never
/// aborts it, so the instrumentation cannot change the behavior it measures.
///
/// Background playback with a media notification (FR-11) needs `audio_service`
/// around this; that is Phase 6 work (ROADMAP "background playback hardening"),
/// and [AudioOutput] does not have to change for it.
class JustAudioOutput implements AudioOutput {
  JustAudioOutput({
    ja.AudioPlayer? player,
    this.watchdogAfter = const Duration(seconds: 5),
  }) : _player = player ?? ja.AudioPlayer() {
    _completedSubscription = _player.processingStateStream.listen((state) {
      AppLog.info('audio.state', data: <String, Object?>{'state': state.name});
      // `completed` fires once per file; `setFilePath` resets the state for the
      // next sentence, which is exactly the sentence queue's model.
      if (state == ja.ProcessingState.completed) _completed.add(null);
    });
    // Player-side failures arrive on their own stream, not as thrown errors —
    // without this listener they disappear without a trace.
    _errorSubscription = _player.errorStream.listen((event) {
      AppLog.error('audio.player.error', data: <String, Object?>{
        'code': event.code,
        'message': event.message,
      });
    });
  }

  /// How long a stage may run before [play] logs `audio.stage.slow` for it.
  final Duration watchdogAfter;

  final ja.AudioPlayer _player;
  late final StreamSubscription<ja.ProcessingState> _completedSubscription;
  late final StreamSubscription<ja.PlayerException> _errorSubscription;

  final StreamController<void> _completed = StreamController<void>.broadcast();

  @override
  Stream<Duration> get position => _player.positionStream;

  @override
  Stream<void> get completed => _completed.stream;

  @override
  Future<void> play(String path, {double volume = 1.0}) async {
    AppLog.info('audio.play.begin', data: <String, Object?>{
      'file': path.split('/').last,
      'volume': volume,
    });
    AppLog.info('audio.state.check', data: <String, Object?>{
      'when': 'begin',
      'playing': _player.playing,
      'state': _player.processingState.name,
    });
    await _stage('setFilePath', _player.setFilePath(path));
    await _stage('setVolume', _player.setVolume(volume));
    AppLog.info('audio.state.check', data: <String, Object?>{
      'when': 'prePlay',
      'playing': _player.playing,
      'state': _player.processingState.name,
    });
    // Not awaited: `play()` only completes when playback finishes, and callers
    // are waiting for it to *start*. Its failure would otherwise vanish with
    // the unawaited future — exactly the silence this log closes.
    final started = _player.play();
    AppLog.info('audio.play.dispatched');
    unawaited(started.then(
      (_) => AppLog.info('audio.play.started'),
      onError: (Object error, StackTrace stack) => AppLog.error(
        'audio.play.failed',
        error: error,
        stackTrace: stack,
      ),
    ));
  }

  /// Times [call], warning once at [watchdogAfter] if it is still pending —
  /// and logging `audio.stage` with the elapsed time when it does return.
  /// A stage that never returns therefore leaves exactly one line: the warning.
  Future<T> _stage<T>(String name, Future<T> call) async {
    final stopwatch = Stopwatch()..start();
    final timer = Timer(watchdogAfter, () {
      AppLog.warning('audio.stage.slow', data: <String, Object?>{
        'stage': name,
        'ms': stopwatch.elapsedMilliseconds,
      });
    });
    try {
      return await call;
    } finally {
      timer.cancel();
      AppLog.info('audio.stage', data: <String, Object?>{
        'stage': name,
        'ms': stopwatch.elapsedMilliseconds,
      });
    }
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> dispose() async {
    await _completedSubscription.cancel();
    await _errorSubscription.cancel();
    await _completed.close();
    await _player.dispose();
  }
}
