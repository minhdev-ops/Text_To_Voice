import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:text_to_voice/ai/tts/vieneu_onnx_tts_engine.dart';
import 'package:text_to_voice/ai/tts/vieneu_phonemizer.dart';
import 'package:text_to_voice/ai/tts/vieneu_pipeline.dart';
import 'package:text_to_voice/ai/tts/vieneu_synthesis_worker.dart';
import 'package:text_to_voice/ai/tts/vieneu_voices.dart';
import 'package:text_to_voice/core/result/result.dart';
import 'package:text_to_voice/domain/models/tts.dart' show TtsOptions;

/// The engine is the composition point: phonemize, resolve a voice, synthesize,
/// write a WAV. Each of those can fail, and the *kind* of failure is what the UI
/// acts on, so every branch is checked here rather than discovered on a phone.
class _FakePhonemizer implements VieNeuPhonemizer {
  _FakePhonemizer({this.output = 'hˈom nˈaj', this.throwOnPhonemize = false});

  final String output;
  final bool throwOnPhonemize;
  int calls = 0;
  bool closed = false;

  @override
  bool get isAvailable => true;

  @override
  String phonemize(String text, {bool puncNorm = true}) {
    calls++;
    if (throwOnPhonemize) throw StateError('dictionary exploded');
    return output;
  }

  @override
  void close() => closed = true;
}

class _FakeSynthesizer implements VieNeuSynthesizer {
  _FakeSynthesizer({
    this.failure,
    this.sampleCount = 48000,
  });

  final AppFailure? failure;
  final int sampleCount;
  int calls = 0;
  VieNeuSynthesisJob? lastJob;
  Duration? lastTimeout;
  bool disposed = false;

  @override
  Future<Result<SynthesisOutput>> synthesize(
    VieNeuSynthesisJob job, {
    Duration? timeout,
  }) async {
    calls++;
    lastJob = job;
    lastTimeout = timeout;
    final failure = this.failure;
    if (failure != null) {
      return Result<SynthesisOutput>.failure(failure);
    }
    return Result<SynthesisOutput>.success(SynthesisOutput(
      samples: Float32List.fromList(
        List<double>.generate(sampleCount, (i) => i.isEven ? 0.25 : -0.25),
      ),
      sampleRate: 48000,
      frames: 12,
      maxFrames: 100,
    ));
  }

  @override
  Future<void> dispose() async => disposed = true;
}

VieNeuVoiceCatalog catalog() => VieNeuVoiceCatalog(
      defaultVoiceId: 'Giọng A',
      voices: <VieNeuVoice>[
        VieNeuVoice(
          id: 'Giọng A',
          label: 'Giọng A',
          gender: 'female',
          region: 'Bắc',
          style: 'tu_nhien',
          speakerEmbedding: Float32List(3)..[0] = 0.1,
          refCodes: Int32List.fromList(<int>[1, 2, 3, 4]),
          refFrames: 2,
          codebookCount: 2,
        ),
      ],
    );

void main() {
  late Directory audioDir;

  setUp(() async {
    audioDir = await Directory.systemTemp.createTemp('vieneu_audio');
  });

  tearDown(() async {
    if (await audioDir.exists()) await audioDir.delete(recursive: true);
  });

  VieNeuOnnxTtsEngine engine({
    _FakePhonemizer? phonemizer,
    _FakeSynthesizer? synthesizer,
    bool installed = true,
  }) =>
      VieNeuOnnxTtsEngine(
        installed: installed,
        collaborators: VieNeuCollaborators(
          modelDirectory: '/nonexistent/model',
          codecDirectory: '/nonexistent/codec',
          phonemizerDirectories: const <String>['/nonexistent/g2p'],
          audioDirectory: audioDir.path,
          phonemizer: phonemizer ?? _FakePhonemizer(),
          synthesizer: synthesizer ?? _FakeSynthesizer(),
          voices: catalog(),
        ),
      );

  test('a healthy sentence produces a real WAV with a measured duration',
      () async {
    final synthesizer = _FakeSynthesizer(sampleCount: 48000);
    final ttsEngine = engine(synthesizer: synthesizer);

    expect(ttsEngine.isReady, isTrue);
    final result = await ttsEngine.synthesize('Hôm nay', const TtsOptions());
    final audio = result.valueOrNull;
    expect(audio, isNotNull, reason: '${result.failureOrNull}');
    expect(audio!.sampleRate, 48000);
    // 48000 samples at 48 kHz is exactly one second — measured, not estimated.
    expect(audio.duration, const Duration(seconds: 1));
    expect(audio.voiceId, 'Giọng A');

    final file = File(audio.path);
    expect(file.existsSync(), isTrue);
    final bytes = file.readAsBytesSync();
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
    // 16-bit mono: 44-byte header + 2 bytes per sample.
    expect(bytes.length, 44 + 48000 * 2);

    // The job carried the voice's real data, not a placeholder.
    expect(synthesizer.lastJob!.speakerEmbedding.length, 3);
    expect(synthesizer.lastJob!.refFrames, 2);
    expect(synthesizer.lastJob!.phonemes, 'hˈom nˈaj');
  });

  test('the worker is given a timeout sized to the sentence, never a constant',
      () async {
    // The engine is the only place that knows the phonemes, so it is the only
    // place a per-sentence budget can be computed. A `null` here would put the
    // worker's fallback ceiling in charge, which is what used to make every long
    // sentence fail.
    final synthesizer = _FakeSynthesizer();
    final ttsEngine = engine(synthesizer: synthesizer);

    await ttsEngine.synthesize('Hôm nay', const TtsOptions());
    expect(synthesizer.lastTimeout, isNotNull);
    expect(
      synthesizer.lastTimeout!,
      greaterThanOrEqualTo(const Duration(minutes: 1)),
    );
  });

  test('a long sentence is given a longer budget than a short one', () async {
    final synthesizer = _FakeSynthesizer();
    final ttsEngine = engine(
      phonemizer: _FakePhonemizer(
        output: 'va nɤˈɔːk ɗuːɔc tɕɨˈeŋ khǔɤc naː ɡiːaː phẩ́m '
            'aːn choː ɓə́t tʰɨˈə̌ɓ sɨ naː pʰaːy',
      ),
      synthesizer: synthesizer,
    );
    await ttsEngine.synthesize('Câu dài', const TtsOptions());
    final longBudget = synthesizer.lastTimeout!;

    final shortSynthesizer = _FakeSynthesizer();
    final shortEngine = engine(synthesizer: shortSynthesizer);
    await shortEngine.synthesize('Hôm nay', const TtsOptions());

    expect(longBudget, greaterThan(shortSynthesizer.lastTimeout!));
  });

  test('the cache key makes the same sentence reuse the same file name', () async {
    final ttsEngine = engine();
    final first = (await ttsEngine.synthesize('Hôm nay', const TtsOptions())).valueOrNull!;
    final second = (await ttsEngine.synthesize('Hôm nay', const TtsOptions())).valueOrNull!;
    expect(second.path, first.path);

    final other = (await ttsEngine.synthesize('Mai sau', const TtsOptions())).valueOrNull!;
    expect(other.path, isNot(first.path));
  });

  test('not installed is ModelUnavailableFailure and never touches the model',
      () async {
    final phonemizer = _FakePhonemizer();
    final ttsEngine = engine(phonemizer: phonemizer, installed: false);
    expect(ttsEngine.isReady, isFalse);

    final result = await ttsEngine.synthesize('Hôm nay', const TtsOptions());
    expect(result.failureOrNull, isA<ModelUnavailableFailure>());
    expect(phonemizer.calls, 0);
  });

  test('the installed flag can be flipped without rebuilding the engine', () {
    final ttsEngine = engine(installed: false);
    expect(ttsEngine.isReady, isFalse);
    ttsEngine.setInstalled(true);
    expect(ttsEngine.isReady, isTrue);
  });

  test('a phonemizer failure is a ProcessingFailure, not a missing model',
      () async {
    final ttsEngine = engine(phonemizer: _FakePhonemizer(throwOnPhonemize: true));
    final result = await ttsEngine.synthesize('Hôm nay', const TtsOptions());
    expect(result.failureOrNull, isA<ProcessingFailure>());
    expect(result.failureOrNull!.message, contains('ngữ âm'));
  });

  test('empty phonemes fail rather than writing a silent file', () async {
    final ttsEngine = engine(phonemizer: _FakePhonemizer(output: '   '));
    final result = await ttsEngine.synthesize('...', const TtsOptions());
    expect(result.failureOrNull, isA<ProcessingFailure>());
  });

  test('a corrupt model failure stops the engine from retrying forever',
      () async {
    final synthesizer = _FakeSynthesizer(
      failure: const CorruptModelFailure(
        message: 'Model đọc tiếng Việt không chạy được. Tải lại model.',
      ),
    );
    final ttsEngine = engine(synthesizer: synthesizer);
    final result = await ttsEngine.synthesize('Hôm nay', const TtsOptions());
    expect(result.failureOrNull, isA<CorruptModelFailure>());
    // The banner stays up and Models stays reachable instead of every remaining
    // sentence re-attempting the load.
    expect(ttsEngine.isReady, isFalse);
  });

  test('an unknown voice id falls back to the catalog default', () async {
    final synthesizer = _FakeSynthesizer();
    final ttsEngine = engine(synthesizer: synthesizer);
    final result = await ttsEngine.synthesize(
      'Hôm nay',
      const TtsOptions(voiceId: 'Không tồn tại'),
    );
    expect(result.valueOrNull!.voiceId, 'Giọng A');
  });

  test('a synthesis failure is passed through unchanged', () async {
    final ttsEngine = engine(
      synthesizer: _FakeSynthesizer(
        failure: const ProcessingFailure(message: 'Câu này bị bỏ qua.'),
      ),
    );
    final result = await ttsEngine.synthesize('Hôm nay', const TtsOptions());
    expect(result.failureOrNull!.message, 'Câu này bị bỏ qua.');
    // A per-sentence failure must NOT disable the engine.
    expect(ttsEngine.isReady, isTrue);
  });

  test('close disposes the synthesizer and closes the phonemizer', () async {
    final phonemizer = _FakePhonemizer();
    final synthesizer = _FakeSynthesizer();
    final ttsEngine = engine(phonemizer: phonemizer, synthesizer: synthesizer);
    await ttsEngine.synthesize('Hôm nay', const TtsOptions());
    await ttsEngine.close();
    expect(synthesizer.disposed, isTrue);
    expect(phonemizer.closed, isTrue);
    expect(ttsEngine.isReady, isFalse);

    final after = await ttsEngine.synthesize('Hôm nay', const TtsOptions());
    expect(after.failureOrNull, isA<ProcessingFailure>());
  });

  test('writes 16-bit PCM that survives the round trip', () async {
    final ttsEngine = engine(synthesizer: _FakeSynthesizer(sampleCount: 8));
    final audio = (await ttsEngine.synthesize('Hôm nay', const TtsOptions())).valueOrNull!;
    final bytes = File(audio.path).readAsBytesSync();
    final view = ByteData.sublistView(bytes);
    // First sample: declared sample rate 48000, and 0.25 * 32767 rounds to 8192.
    expect(view.getUint32(24, Endian.little), 48000);
    expect(view.getUint16(22, Endian.little), 1);
    expect(view.getInt16(44, Endian.little), 8192);
  });
}
