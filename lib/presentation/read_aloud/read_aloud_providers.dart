import 'dart:async';
import 'dart:io' show Directory;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/tts/model_missing_tts_engine.dart';
import '../../ai/tts/vieneu_onnx_tts_engine.dart';
import '../../core/audio/just_audio_output.dart';
import '../../core/storage/export_directory.dart';
import '../../data/providers.dart';
import '../../data/speech/persistent_synthesis_cache.dart';
import '../../domain/engines/audio_output.dart';
import '../../domain/engines/tts_engine.dart';
import '../../domain/export/document_export_service.dart';
import '../../domain/speech/read_aloud_session.dart';
import '../../domain/speech/sentence_synthesis_queue.dart';
import '../../domain/speech/synthesis_cache.dart';
import '../models/model_providers.dart';

/// The TTS engine the app reads with.
///
/// Watches install state, so the answer is the real on-device engine once a
/// verified model exists and [ModelMissingTtsEngine] before that — which is what
/// keeps the read-aloud button disabled and routes the user to Models instead of
/// spinning on a model that is not there (FR-20 → FR-09).
///
/// Swapping happens **without an app restart**: installing or deleting a model
/// flips [modelReadyProvider], this provider rebuilds, and the sentence queue is
/// rebuilt with the new engine because it watches this one.
///
/// `isReady` is read during `build`, so it must not touch the file system — the
/// engine reports readiness from install state and only pays the load on the
/// first sentence.
final ttsEngineProvider = Provider<TtsEngine>((ref) {
  final ready = ref.watch(modelReadyProvider);
  if (!ready) {
    return const ModelMissingTtsEngine(modelId: 'vieneu-v3-turbo');
  }
  final directories = ref.watch(modelDirectoriesProvider);
  final engine = VieNeuOnnxTtsEngine(
    collaborators: VieNeuCollaborators(
      modelDirectory: directories.model,
      codecDirectory: directories.codec,
      phonemizerDirectories: <String>[directories.phonemizer],
      audioDirectory: directories.audio,
    ),
  );
  // The worker isolate holds four loaded graphs; disposing with the provider is
  // what stops it outliving the model that was deleted underneath it.
  ref.onDispose(engine.close);
  return engine;
});

/// Synthesis cache backed by the `tts_audio` table (SRS §32).
final synthesisCacheProvider = Provider<SynthesisCache>((ref) {
  final repo = ref.watch(documentRepositoryProvider);
  return PersistentSynthesisCache(repo);
});

/// The sentence queue: normalize → split → synthesize one sentence at a time.
final sentenceQueueProvider = Provider<SentenceSynthesisQueue>((ref) {
  final queue = SentenceSynthesisQueue(
    engine: ref.watch(ttsEngineProvider),
    cache: ref.watch(synthesisCacheProvider),
    // Two sentences of look-ahead: enough that the next sentence is usually
    // ready, small enough to stay kind to a low-end phone (NFR-04/NFR-05).
    lookAhead: 2,
  );
  ref.onDispose(queue.dispose);
  return queue;
});

/// The player. Created with the provider, but the plugin is only touched when
/// something is actually played, so nothing in the app reaches the platform
/// until there is audio to hear.
final audioOutputProvider = Provider<AudioOutput>((ref) {
  final output = JustAudioOutput();
  ref.onDispose(output.dispose);
  return output;
});

/// Sentence-addressable playback over the queue.
final readAloudSessionProvider = Provider<ReadAloudSession>((ref) {
  final session = ReadAloudSession(
    queue: ref.watch(sentenceQueueProvider),
    output: ref.watch(audioOutputProvider),
  );
  ref.onDispose(session.dispose);
  return session;
});

/// Writes the export artifacts (FR-14 / FR-15).
final exportServiceProvider = Provider<DocumentExportService>(
  (ref) => const DocumentExportService(),
);

/// Where exports land. A `Provider<Future<Directory>>` rather than a
/// `FutureProvider` so a test can hand it a temporary directory with a plain
/// `overrideWithValue` — and so nothing touches `path_provider` until an export
/// is actually requested.
final exportDirectoryProvider = Provider<Future<Directory>>(
  (ref) => appExportDirectory(),
);

/// One `Notifier` over the session's one immutable state value.
///
/// The widget layer never mutates state itself: it calls an intent method and
/// re-renders from the value the session publishes, so the transport bar, the
/// ruler and the Listening Spine cannot drift out of agreement.
class ReadAloudController extends Notifier<ReadAloudState> {
  // Not `final`: `build` re-runs whenever the session chain rebuilds (the
  // documents directory resolving, the model audit finishing, an engine swap
  // after install), and a `late final` field can only take one assignment —
  // the second `build` would throw `LateInitializationError` and poison the
  // provider for every future read of the screen.
  late ReadAloudSession _session;
  StreamSubscription<ReadAloudState>? _subscription;

  @override
  ReadAloudState build() {
    final session = ref.watch(readAloudSessionProvider);
    _session = session;
    // The previous session is disposed with its provider; dropping its
    // subscription here keeps a stale stream from writing state after the swap.
    _subscription?.cancel();
    _subscription = session.states.listen((state) => this.state = state);
    ref.onDispose(() => _subscription?.cancel());
    return session.state;
  }

  Future<void> read(String text) => _session.read(text);

  Future<void> play() => _session.play();

  Future<void> pause() => _session.pause();

  Future<void> toggle() => _session.toggle();

  Future<void> next() => _session.next();

  Future<void> previous() => _session.previous();

  Future<void> seekToSentence(int index) => _session.seekToSentence(index);

  Future<void> setSpeed(double speed) => _session.setSpeed(speed);

  Future<void> retryFailed() => _session.retryFailed();

  void dismissFailure() => _session.dismissFailure();

  /// Stops playback and empties the reading surface, which is how the user gets
  /// back to editing the text (FR-08: text edits are blocked while reading so
  /// audio and text cannot desync).
  Future<void> editText() => _session.read('');
}

final readAloudControllerProvider =
    NotifierProvider<ReadAloudController, ReadAloudState>(
  ReadAloudController.new,
);
