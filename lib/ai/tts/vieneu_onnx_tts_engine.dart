import 'dart:io' show Directory, File;
import 'dart:typed_data';

import '../../core/audio/pcm_wav.dart';
import '../../core/logging/app_log.dart';
import '../../core/result/result.dart';
import '../../domain/engines/tts_engine.dart';
import '../../domain/models/tts.dart' show AudioResult, TtsOptions;
import 'vieneu_frames.dart';
import 'vieneu_phonemizer.dart';
import 'vieneu_pipeline.dart' show SynthesisOutput;
import 'vieneu_synthesis_worker.dart';
import 'vieneu_voices.dart';

/// Where the expensive collaborators come from.
///
/// A seam, not a convenience. Resolving the real one loads 165 MB of int8
/// weights, opens a 63 MB g2p dictionary and spawns an isolate; without this,
/// every test of the read-aloud path would be a model test. Tests inject
/// [phonemizer], [synthesizer] and [voices]; production leaves them null and the
/// engine resolves them lazily, on the first sentence, off the UI thread.
class VieNeuCollaborators {
  const VieNeuCollaborators({
    required this.modelDirectory,
    required this.codecDirectory,
    required this.phonemizerDirectories,
    required this.audioDirectory,
    this.voicesAssetPath = 'assets/voices/voices_v3_turbo.json',
    this.phonemizer,
    this.synthesizer,
    this.voices,
  });

  /// `<app documents>/models/vieneu-v3-turbo-int8`.
  final String modelDirectory;

  /// `<app documents>/models/codec-nano`.
  final String codecDirectory;

  /// Where to look for `sea_g2p.bin` and the native g2p library, in order.
  final List<String> phonemizerDirectories;

  /// Where synthesized WAV files are written (`audio/_synthesis`).
  final String audioDirectory;

  /// Bundled voice catalog. Small (180 KB) and shipped with the app rather than
  /// downloaded, so the voice list is readable before any model exists.
  final String voicesAssetPath;

  final VieNeuPhonemizer? phonemizer;
  final VieNeuSynthesizer? synthesizer;
  final VieNeuVoiceCatalog? voices;
}

/// The real on-device Vietnamese TTS engine (FR-09, FR-12).
///
/// One sentence in, one WAV out, entirely local: phonemize with sea-g2p, run the
/// four ONNX graphs in a worker isolate (`vieneu_synthesis_worker.dart`), write
/// 16-bit PCM at 48 kHz. No GPU, no server, no network — after the model is
/// installed, this path cannot reach the internet even by accident (NFR-01).
///
/// **Readiness is install state, not I/O.** [isReady] reflects whether the model
/// is installed and whether a load has already failed; it never touches the file
/// system, because the read-aloud button reads it during `build`. The first
/// sentence pays the load, and a load failure flips [isReady] to false so the
/// button disables itself and routes to Models instead of retrying forever.
///
/// **Failure is typed, never silent.** A missing model is
/// [ModelUnavailableFailure] (offers `Install`), a graph that loads but cannot
/// run is [CorruptModelFailure] (offers `Re-download`, FR-20), and a genuinely
/// bad sentence is [ProcessingFailure] — which the sentence queue skips so the
/// rest of the document still plays.
class VieNeuOnnxTtsEngine implements TtsEngine {
  VieNeuOnnxTtsEngine({
    required this.collaborators,
    bool installed = true,
  }) : _installed = installed;

  final VieNeuCollaborators collaborators;

  bool _installed;
  bool _loadFailed = false;
  bool _disposed = false;

  VieNeuPhonemizer? _phonemizer;
  VieNeuVoiceCatalog? _voices;
  VieNeuSynthesizer? _synthesizer;
  Future<Result<VieNeuSynthesizer>>? _synthesizerInFlight;

  @override
  String get id => 'vieneu-onnx-v3-turbo';

  @override
  String get displayName => 'VieNeu-TTS v3 Turbo (ONNX, CPU)';

  @override
  bool get isReady => _installed && !_loadFailed && !_disposed;

  /// Tells the engine that the model was deleted underneath it.
  ///
  /// Called by the install-state watcher, so a delete in the Models tab takes
  /// effect without an app restart (FR-20).
  void setInstalled(bool installed) {
    _installed = installed;
    if (!installed) {
      _loadFailed = false;
    }
  }

  @override
  Future<Result<AudioResult>> synthesize(
    String text,
    TtsOptions options,
  ) async {
    if (_disposed) {
      return const Result<AudioResult>.failure(ProcessingFailure(
        message: 'Phiên đọc đã đóng. Mở lại tài liệu để đọc tiếp.',
        retryable: false,
      ));
    }
    if (!_installed) {
      return const Result<AudioResult>.failure(ModelUnavailableFailure(
        message: 'Chưa cài model đọc tiếng Việt. Mở tab Mô hình để tải về.',
        modelId: 'vieneu-v3-turbo',
      ));
    }

    // Stage timings (info → debug console via AppLog): which collaborator a
    // slow first sentence actually spent its time on — dictionary open, graph
    // load, or phonemize. Rebased after each stage, so each log is that stage.
    var stageClock = DateTime.now();
    void markStage(String name) {
      AppLog.info(name, data: <String, Object?>{
        'ms': DateTime.now().difference(stageClock).inMilliseconds,
      });
      stageClock = DateTime.now();
    }

    final phonemizer = await _resolvePhonemizer();
    if (phonemizer case Failure<VieNeuPhonemizer>(:final failure)) {
      return Result<AudioResult>.failure(failure);
    }
    markStage('tts.stage.phonemizer');

    final voices = await _resolveVoices();
    if (voices case Failure<VieNeuVoiceCatalog>(:final failure)) {
      return Result<AudioResult>.failure(failure);
    }
    final voice = voices.valueOrNull!.resolve(options.voiceId);
    if (voice == null) {
      return Result<AudioResult>.failure(ProcessingFailure(
        message: 'Không tìm thấy giọng đọc "${options.voiceId}".',
        retryable: false,
      ));
    }
    markStage('tts.stage.voices');

    final synthesizer = await _resolveSynthesizer();
    if (synthesizer case Failure<VieNeuSynthesizer>(:final failure)) {
      return Result<AudioResult>.failure(failure);
    }
    markStage('tts.stage.worker');

    final String phonemes;
    try {
      phonemes = phonemizer.valueOrNull!.phonemize(text);
    } catch (error, stack) {
      AppLog.error('tts.phonemize.failed', error: error, stackTrace: stack);
      return Result<AudioResult>.failure(ProcessingFailure(
        message: 'Không chuyển được văn bản thành ngữ âm: $error',
        detail: stack.toString(),
        cause: error,
      ));
    }
    if (phonemes.trim().isEmpty) {
      return const Result<AudioResult>.failure(ProcessingFailure(
        message: 'Câu này không có nội dung đọc được.',
        retryable: false,
      ));
    }
    markStage('tts.stage.g2p');

    final started = DateTime.now();
    // The budget comes from the phonemes, which are only known after phonemizing
    // — so it cannot live in the sentence queue, and a flat constant here is
    // what used to make every long sentence fail.
    final budget = synthesisTimeout(phonemes);
    final result = await synthesizer.valueOrNull!.synthesize(
      VieNeuSynthesisJob(
        phonemes: phonemes,
        speakerEmbedding: voice.speakerEmbedding,
        refCodes: voice.refCodes,
        refFrames: voice.refFrames,
      ),
      timeout: budget,
    );
    final output = switch (result) {
      Success<SynthesisOutput>(:final value) => value,
      Failure<SynthesisOutput>() => null,
    };
    if (output == null) {
      final failure = result.failureOrNull!;
      // A missing or broken model is not a per-sentence problem: flipping
      // readiness here is what stops the queue from re-attempting a 165 MB load
      // for every remaining sentence in the document (FR-20 → FR-09).
      if (failure is ModelUnavailableFailure || failure is CorruptModelFailure) {
        _loadFailed = true;
      }
      return Result<AudioResult>.failure(failure);
    }
    if (output.samples.isEmpty) {
      return const Result<AudioResult>.failure(ProcessingFailure(
        message: 'Model không tạo ra âm thanh cho câu này.',
      ));
    }

    AppLog.info('tts.synthesized', data: <String, Object?>{
      'ms': DateTime.now().difference(started).inMilliseconds,
      'frames': output.frames,
      'capped': output.hitFrameCap,
      'budgetMs': budget.inMilliseconds,
      'digest': text.length,
    });

    try {
      final path = await _writeWav(
        output.samples,
        output.sampleRate,
        options.cacheKey(text),
      );
      return Result<AudioResult>.success(AudioResult(
        path: path,
        // Measured from the samples, not estimated from the text.
        duration: output.duration,
        textHash: options.cacheKey(text),
        sampleRate: output.sampleRate,
        voiceId: voice.id,
        speed: options.speed,
      ));
    } catch (error, stack) {
      AppLog.error('tts.write.failed', error: error, stackTrace: stack);
      return Result<AudioResult>.failure(StorageFailure(
        message: 'Không ghi được tệp âm thanh: $error',
        detail: stack.toString(),
        cause: error,
      ));
    }
  }

  Future<String> _writeWav(
    Float32List samples,
    int sampleRate,
    String cacheKey,
  ) async {
    final directory = Directory(collaborators.audioDirectory);
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    final file = File('${directory.path}/${_fileName(cacheKey)}.wav');
    await file.writeAsBytes(
      pcm16WavBytes(samples, sampleRate: sampleRate),
      flush: true,
    );
    return file.path;
  }

  /// A cache key is a sentence — far too long and not safe as a name. The FNV-1a
  /// digest keeps the file stable for the same (voice, speed, text) triple, which
  /// is what the SRS §32 cache needs.
  static String _fileName(String cacheKey) {
    var hash = 0x811C9DC5;
    for (final unit in cacheKey.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return 'vieneu_${hash.toRadixString(16).padLeft(8, '0')}';
  }

  Future<Result<VieNeuPhonemizer>> _resolvePhonemizer() async {
    final injected = collaborators.phonemizer;
    if (injected != null) {
      // Held like one the engine resolved itself, so `close()` releases it
      // through the same path instead of leaving an injected one open.
      _phonemizer = injected;
      return Result<VieNeuPhonemizer>.success(injected);
    }
    final existing = _phonemizer;
    if (existing != null && existing.isAvailable) {
      return Result<VieNeuPhonemizer>.success(existing);
    }
    final result = SeaG2pPhonemizer.open(
      searchDirectories: collaborators.phonemizerDirectories,
    );
    if (result case Success<SeaG2pPhonemizer>(:final value)) {
      _phonemizer = value;
    } else {
      // The g2p library is not going to appear mid-session; reporting not-ready
      // is the honest state and stops the queue from retrying every sentence.
      _loadFailed = true;
    }
    return result;
  }

  Future<Result<VieNeuVoiceCatalog>> _resolveVoices() async {
    final injected = collaborators.voices;
    if (injected != null) {
      return Result<VieNeuVoiceCatalog>.success(injected);
    }
    final existing = _voices;
    if (existing != null) return Result<VieNeuVoiceCatalog>.success(existing);
    final result =
        await VieNeuVoiceCatalog.fromAsset(collaborators.voicesAssetPath);
    if (result case Success<VieNeuVoiceCatalog>(:final value)) {
      _voices = value;
    }
    return result;
  }

  Future<Result<VieNeuSynthesizer>> _resolveSynthesizer() {
    final injected = collaborators.synthesizer;
    if (injected != null) {
      // Held like one the engine started itself, so `close()` disposes it too.
      _synthesizer = injected;
      return Future<Result<VieNeuSynthesizer>>.value(
        Result<VieNeuSynthesizer>.success(injected),
      );
    }
    final existing = _synthesizer;
    if (existing != null) return Future.value(Result.success(existing));

    // One load at a time: the sentence queue starts a look-ahead synthesis
    // immediately, and two concurrent loads would create two workers holding the
    // weights twice over (NFR-04).
    final inFlight = _synthesizerInFlight;
    if (inFlight != null) return inFlight;

    final future = _startSynthesizer();
    _synthesizerInFlight = future;
    return future;
  }

  Future<Result<VieNeuSynthesizer>> _startSynthesizer() async {
    final result = await VieNeuSynthesisWorker.start(
      modelDirectory: collaborators.modelDirectory,
      codecDirectory: collaborators.codecDirectory,
    );
    switch (result) {
      case Success<VieNeuSynthesisWorker>(:final value):
        _synthesizer = value;
        _synthesizerInFlight = null;
        return Result<VieNeuSynthesizer>.success(value);
      case Failure<VieNeuSynthesisWorker>(:final failure):
        _synthesizerInFlight = null;
        // A missing or broken checkpoint is not a per-sentence problem. Flipping
        // readiness keeps the banner up and the Models route open instead of
        // re-attempting a 165 MB load for every sentence in the document.
        _loadFailed = true;
        return Result<VieNeuSynthesizer>.failure(failure);
    }
  }

  @override
  Future<void> close() async {
    if (_disposed) return;
    _disposed = true;
    await _synthesizer?.dispose();
    _synthesizer = null;
    _phonemizer?.close();
    _phonemizer = null;
  }
}
