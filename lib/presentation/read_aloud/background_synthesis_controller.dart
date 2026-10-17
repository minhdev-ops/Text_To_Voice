import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/app_log.dart';
import '../../core/platform/synthesis_platform.dart';
import '../../domain/models/tts.dart' show TtsOptions;
import '../../domain/speech/background_synthesis_runner.dart';
import 'read_aloud_providers.dart' show backgroundSynthesisRunnerProvider, synthesisPlatformProvider;

/// What the UI needs to know about a background generation run.
class BackgroundSynthesisState {
  const BackgroundSynthesisState({
    this.running = false,
    this.documentId,
    this.progress = const SynthesisProgress(completed: 0, total: 0),
    this.message,
  });

  final bool running;

  /// Which document is being generated, so a second request can refuse instead of
  /// silently generating the wrong one.
  final String? documentId;

  final SynthesisProgress progress;

  /// Set when the run stopped for a reason worth showing — a missing model, or a
  /// failure count the reader should know about.
  final String? message;

  bool get cancelled => progress.cancelled;

  BackgroundSynthesisState copyWith({
    bool? running,
    String? documentId,
    SynthesisProgress? progress,
    String? message,
  }) {
    return BackgroundSynthesisState(
      running: running ?? this.running,
      documentId: documentId ?? this.documentId,
      progress: progress ?? this.progress,
      message: message,
    );
  }
}

/// Drives [BackgroundSynthesisRunner] and keeps the notification in step with it.
///
/// **One run at a time.** The ONNX decoder is single-threaded CPU work (NFR-04),
/// so a second concurrent run would not be faster — it would halve the speed of
/// the one the reader is waiting on. A request for a different document while one
/// is running is refused, not queued.
///
/// **Stopping keeps the work.** Stopping sets a flag the runner checks between
/// sentences; it does not kill anything mid-sentence, because a truncated WAV in
/// the cache is worse than a missing one — the cache would serve it forever.
class BackgroundSynthesisController
    extends Notifier<BackgroundSynthesisState> {
  late final SynthesisPlatform _platform;

  /// Set by [stop]; read by the runner between sentences.
  bool _stopRequested = false;

  /// Mirrors `state.running` without reading [state].
  ///
  /// The notification's Stop button can be delivered while [build] is still
  /// running, and reading a Notifier's `state` before it is initialized throws
  /// rather than returning a default. A private flag makes the stop path safe
  /// from the very first moment, when the platform is told to listen.
  bool _running = false;

  StreamSubscription<SynthesisProgress>? _subscription;

  @override
  BackgroundSynthesisState build() {
    // Deliberately **not** `watch(backgroundSynthesisRunnerProvider)` here. The
    // runner pulls the persistent cache, which pulls the database, and the engine,
    // which boots the ONNX worker isolate — so watching it in `build` would make
    // every read-aloud screen open the database and load four graphs even when
    // the reader never asks for pre-generation. The runner is resolved in [start]
    // instead, where the work is actually wanted.
    _platform = ref.watch(synthesisPlatformProvider);

    ref.onDispose(() => _subscription?.cancel());
    // The notification's Stop button can fire at any moment, including between
    // runs, so the listener is installed for the controller's whole life rather
    // than at the start of each run.
    _platform.onStopRequested = stop;
    return const BackgroundSynthesisState();
  }

  /// Starts generating audio for [rawText].
  ///
  /// [options] must be the reader's own voice/speed: the runner caches under
  /// `options.cacheKey(...)`, and a run with the defaults would write keys the
  /// reader never queries.
  ///
  /// Returns false without doing anything when a run is already going.
  Future<bool> start({
    required String documentId,
    required String rawText,
    TtsOptions options = const TtsOptions(),
  }) async {
    if (_running) {
      AppLog.info('synthesis.busy', data: <String, Object?>{'requested': documentId});
      return false;
    }

    _stopRequested = false;
    _running = true;
    _platform.ensureStopListener();
    // Asked for **before** the first notification is posted: from API 33 the
    // service's notification is hidden without it, and a run that generates
    // audio invisibly — with no way to see or stop it — is the failure mode the
    // foreground service exists to prevent.
    unawaited(_platform.requestNotifications());

    state = BackgroundSynthesisState(
      running: true,
      documentId: documentId,
      progress: const SynthesisProgress(completed: 0, total: 0),
    );

    // The notification appears immediately so a long first sentence is not a
    // silent wait the user cannot explain.
    await _platform.start(done: 0, total: 0);

    // Resolved here rather than in `build` — see the note there.
    final stream = ref.read(backgroundSynthesisRunnerProvider).generate(
      rawText,
      options: options,
      isCancelled: () => _stopRequested,
    );

    await _subscription?.cancel();
    _subscription = stream.listen(_onProgress, onError: _onError, onDone: _onDone);

    return true;
  }

  /// Asks the current run to stop after the sentence in flight.
  void stop() {
    if (!_running) return;
    AppLog.info('synthesis.stopRequested', data: <String, Object?>{
      'document': state.documentId,
      'completed': state.progress.completed,
    });
    _stopRequested = true;
  }

  void _onProgress(SynthesisProgress progress) {
    // Read the previous percentage **before** publishing the new state, or
    // "did this move?" compares the new value against itself and the
    // notification never advances.
    final previous = _percentOf(state.progress);

    _running = !progress.finished;
    state = state.copyWith(running: _running, progress: progress);

    // Repainting the notification on every sentence would be a system call per
    // sentence for a bar that moves one percent; only meaningful moves are sent.
    final percent = _percentOf(progress);
    if (progress.finished || percent != previous) {
      unawaited(_platform.progress(
        done: progress.completed,
        total: progress.total,
      ));
    }
  }

  /// `null` when the total is not known yet — a progress bar must not claim 0%.
  static int? _percentOf(SynthesisProgress progress) =>
      progress.total == 0 ? null : progress.completed * 100 ~/ progress.total;

  void _onError(Object error, StackTrace stack) {
    AppLog.error('synthesis.runFailed', error: error, stackTrace: stack);
    _running = false;
    state = state.copyWith(
      running: false,
      message: 'Không tạo được audio: $error',
    );
    unawaited(_platform.finished());
  }

  void _onDone() {
    final progress = state.progress;
    final failed = progress.failed;
    _running = false;
    state = state.copyWith(
      running: false,
      // A stopped run is worth saying so: without a message the banner
      // disappears entirely and the stop looks like it was never registered.
      message: progress.cancelled
          ? 'Đã dừng — ${progress.completed}/${progress.total} câu đã tạo.'
          : failed == 0
              ? null
              : 'Đã tạo xong, $failed câu bị lỗi và sẽ thử lại lần sau.',
    );
    unawaited(_platform.finished());
  }
}