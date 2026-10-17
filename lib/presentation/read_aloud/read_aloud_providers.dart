import 'dart:async';
import 'dart:io' show Directory;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/tts/model_missing_tts_engine.dart';
import '../../ai/tts/vieneu_onnx_tts_engine.dart';
import '../../ai/tts/vieneu_voices.dart';
import '../../core/audio/desktop_audio_output.dart';
import '../../core/audio/just_audio_output.dart';
import '../../core/share/share_target.dart';
import '../../core/platform/synthesis_platform.dart';
import '../../core/storage/export_directory.dart';
import '../../data/providers.dart';
import '../../data/speech/persistent_synthesis_cache.dart';
import '../../domain/engines/audio_output.dart';
import '../../domain/engines/tts_engine.dart';
import '../../domain/export/document_export_service.dart';
import '../../domain/models/tts.dart' show TtsOptions;
import '../../domain/speech/background_synthesis_runner.dart';
import '../../domain/speech/read_aloud_session.dart';
import '../../domain/speech/sentence_synthesis_queue.dart';
import '../../domain/speech/synthesis_cache.dart';
import '../models/model_providers.dart';
import 'background_synthesis_controller.dart';

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
  final variant = ref.watch(activeModelVariantProvider);
  if (!ready) {
    return ModelMissingTtsEngine(modelId: variant.modelId);
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
  // `just_audio` has no linux/windows native implementation, so desktop plays
  // WAV through the OS player; mobile and macos keep `just_audio`.
  final output = switch (defaultTargetPlatform) {
    TargetPlatform.linux => DesktopAudioOutput(),
    TargetPlatform.windows => DesktopAudioOutput(),
    _ => JustAudioOutput(),
  };
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

/// The Android foreground-service bridge. Plain [SynthesisPlatform] rather than
/// a provider collaborator so a test can inject a fake without a container.
final synthesisPlatformProvider = Provider<SynthesisPlatform>(
  (ref) => SynthesisPlatform(),
);

/// Generating a whole document's audio in advance, so reading it later does not
/// wait for synthesis and "Export Audio" (FR-15) has something to export.
final backgroundSynthesisRunnerProvider = Provider<BackgroundSynthesisRunner>(
  (ref) => BackgroundSynthesisRunner(
    engine: ref.watch(ttsEngineProvider),
    cache: ref.watch(synthesisCacheProvider),
  ),
);

final backgroundSynthesisProvider =
    NotifierProvider<BackgroundSynthesisController, BackgroundSynthesisState>(
  BackgroundSynthesisController.new,
);

/// The voice catalog shipped inside the app (Apache-2.0, 180 KB).
///
/// Read straight from the asset rather than from the engine's own copy: the
/// sheet needs ids and labels before any model is installed, and `rootBundle`
/// caches the string, so this costs one parse for the whole app lifetime.
final voiceCatalogProvider = FutureProvider<VieNeuVoiceCatalog>((ref) async {
  // Same asset the engine reads (`VieNeuCollaborators.voicesAssetPath`); a
  // literal here rather than a second constant so the two cannot drift apart
  // silently — the pubspec bundles exactly this path.
  const voicesAssetPath = 'assets/voices/voices_v3_turbo.json';
  final result = await VieNeuVoiceCatalog.fromAsset(voicesAssetPath);
  return result.valueOrNull ??
      const VieNeuVoiceCatalog(voices: <VieNeuVoice>[], defaultVoiceId: '');
});

/// Where a document's own reading preferences live in the `settings` table.
///
/// One JSON blob per document (voice, speed, volume) so reopening a document
/// restores the voice it was being read with — and the composer keeps its own
/// last-used options under the same scheme, keyed [composerDocumentId].
String ttsOptionsSettingKey(String documentId) => 'tts_options:$documentId';

/// The `settings` key holding the composer draft, so typed text survives
/// leaving the screen, backgrounding the app, or killing the process.
const String composerDraftSettingKey = 'composer_draft';

/// The document id the composer's own preferences are stored under.
const String composerDocumentId = 'composer';

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

/// Hands exported files to another app (FR-16).
///
/// Behind the [ShareTarget] port so the export sheet and the read-aloud screen
/// can be widget-tested without a platform channel, and so "nothing accepted the
/// share" arrives as a failure the UI can speak rather than a silent no-op.
final shareTargetProvider = Provider<ShareTarget>(
  (ref) => const PluginShareTarget(),
);

/// The slowest sentence synthesis this device has actually measured, persisted.
///
/// Measured on this device, on this model, at this speed — which is the only
/// reason it is worth showing at all. A figure carried over from a different
/// device or a different checkpoint would be a guess wearing a measurement's
/// clothes.
class SynthesisPriors extends Notifier<int?> {
  static const String settingKey = 'slowest_synthesis_ms';

  @override
  int? build() {
    unawaited(_restore());
    return null;
  }

  var _restored = false;

  Future<void> _restore() async {
    if (_restored) return;
    _restored = true;
    String? stored;
    try {
      stored = await ref
          .read(documentRepositoryProvider)
          .getSetting(settingKey);
    } catch (_) {
      // A preference that cannot be read is a missing preference, not a failure
      // of the thing being read.
      return;
    }
    if (!ref.mounted) return;
    state = int.tryParse(stored ?? '');
  }

  /// Records a new measurement, keeping the slowest.
  ///
  /// Slowest, not latest: the number that decides whether someone thinks the app
  /// is stuck is the longest wait, and averaging would quietly understate it.
  Future<void> record(int milliseconds) async {
    if (milliseconds <= 0) return;
    if (state != null && milliseconds <= state!) return;
    state = milliseconds;
    try {
      await ref
          .read(documentRepositoryProvider)
          .setSetting(settingKey, '$milliseconds');
    } catch (_) {
      // Losing the prior only costs the next first-sentence estimate.
    }
  }
}

final synthesisPriorsProvider =
    NotifierProvider<SynthesisPriors, int?>(SynthesisPriors.new);

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
    _subscription = session.states.listen(_publish);
    ref.onDispose(() => _subscription?.cancel());
    return session.state;
  }

  /// Publishes a session state, and banks this session's slowest measurement.
  ///
  /// Banking happens here rather than in a `ref.listen` on this provider: a
  /// provider cannot depend on itself, and watching [synthesisPriorsProvider]
  /// from `build` would rebuild the controller the moment a measurement landed —
  /// discarding the published reading position. [SynthesisPriors] is read, not
  /// watched, for the same reason.
  void _publish(ReadAloudState state) {
    final measured = state.synthesisMs;
    if (measured != null) {
      unawaited(ref.read(synthesisPriorsProvider.notifier).record(measured));
    }
    this.state = state;
  }

  Future<void> read(String text, {int startIndex = 0}) =>
      _session.read(text, startIndex: startIndex);

  Future<void> play() => _session.play();

  Future<void> pause() => _session.pause();

  Future<void> toggle() => _session.toggle();

  Future<void> next() => _session.next();

  Future<void> previous() => _session.previous();

  Future<void> seekToSentence(int index) => _session.seekToSentence(index);

  Future<void> setSpeed(double speed) => _session.setSpeed(speed);

  /// Voice and volume join speed behind one intent: the options sheet edits a
  /// whole set, and the session applies it atomically from the next sentence.
  Future<void> setVoice(String? voiceId) => _session.setVoice(voiceId);

  Future<void> setOptions(TtsOptions options) => _session.setOptions(options);

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
