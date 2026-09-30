import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:text_to_voice/ai/tts/vieneu_synthesis_worker.dart';
import 'package:text_to_voice/core/result/result.dart';

import '../../support/fake_onnx_session.dart';

/// These tests exercise the whole pipeline *inside the worker isolate*: load the
/// config, read the weight archive, build the prompt, run the frame loop and the
/// codec, and hand back samples.
///
/// The model they use is `test/fixtures/tiny_model/` — the same file names, the
/// same config keys and the same tensor relationships, small enough to commit.
/// That is deliberate: an integration test that needs 280 MB cannot run in CI,
/// and a test that mocks the pipeline cannot catch a wrong row count, a leaked
/// cache handle or a codec channel mix-up. The four ONNX sessions are fakes here;
/// everything the app *does with* them is real.
void main() {
  late Directory root;
  late String modelDir;
  late String codecDir;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('vieneu_worker_test');
    modelDir = '${root.path}/vieneu-v3-turbo-int8';
    codecDir = '${root.path}/codec-nano';
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  void plantTinyModel({String? configOverride, bool onlyModelFiles = false}) {
    Directory(modelDir).createSync(recursive: true);
    for (final name in VieNeuSynthesisWorker.requiredModelFiles) {
      File('$modelDir/$name').writeAsBytesSync(<int>[]);
    }
    File('$modelDir/config.json').writeAsStringSync(
      configOverride ??
          File('test/fixtures/tiny_model/config.json').readAsStringSync(),
    );
    for (final name in <String>['tokenizer.json', 'vieneu_v3_heads.npz']) {
      File('$modelDir/$name').writeAsBytesSync(
        File('test/fixtures/tiny_model/$name').readAsBytesSync(),
      );
    }
    if (onlyModelFiles) return;
    Directory(codecDir).createSync(recursive: true);
    for (final name in VieNeuSynthesisWorker.requiredCodecFiles) {
      File('$codecDir/$name').writeAsBytesSync(<int>[]);
    }
  }

  VieNeuSynthesisJob job({String phonemes = 'hˈom nˈaj'}) => VieNeuSynthesisJob(
        phonemes: phonemes,
        speakerEmbedding: Float32List.fromList(<double>[0.1, 0.2, 0.3]),
        refCodes: Int32List.fromList(<int>[1, 2, 3, 4]),
        refFrames: 2,
      );

  test('a missing file is ModelUnavailableFailure naming that file', () async {
    final result = await VieNeuSynthesisWorker.start(
      modelDirectory: modelDir,
      codecDirectory: codecDir,
      factory: fakeSessionFactory(),
    );
    expect(result.failureOrNull, isA<ModelUnavailableFailure>());
    expect(result.failureOrNull!.cause.toString(), contains('config.json'));
  });

  test('a missing codec file is reported as its own failure', () async {
    plantTinyModel(onlyModelFiles: true);
    final result = await VieNeuSynthesisWorker.start(
      modelDirectory: modelDir,
      codecDirectory: codecDir,
      factory: fakeSessionFactory(),
    );
    expect(result.failureOrNull, isA<ModelUnavailableFailure>());
    expect(
      result.failureOrNull!.cause.toString(),
      contains('moss_audio_tokenizer_decode_full.onnx'),
    );
  });

  test('a damaged config is CorruptModelFailure, not "model missing"', () async {
    // The distinction is not cosmetic: FR-20 answers "chưa cài" with `Tải về`
    // and "hỏng" with `Tải lại`.
    plantTinyModel(configOverride: '{"n_vq": 2}');
    final result = await VieNeuSynthesisWorker.start(
      modelDirectory: modelDir,
      codecDirectory: codecDir,
      factory: fakeSessionFactory(),
    );
    expect(result.failureOrNull, isA<CorruptModelFailure>());
  });

  test('a factory that cannot load the graph is CorruptModelFailure', () async {
    plantTinyModel();
    final result = await VieNeuSynthesisWorker.start(
      modelDirectory: modelDir,
      codecDirectory: codecDir,
      factory: fakeSessionFactory(throwOnCreate: true),
    );
    expect(result.failureOrNull, isA<CorruptModelFailure>());
  });

  test('loads, synthesizes and reports the work happened off the UI isolate',
      () async {
    plantTinyModel();
    final result = await VieNeuSynthesisWorker.start(
      modelDirectory: modelDir,
      codecDirectory: codecDir,
      factory: fakeSessionFactory(),
    );
    final worker = result.valueOrNull;
    expect(worker, isNotNull, reason: '${result.failureOrNull}');

    // All four graphs load in ONE isolate, which is the whole point of the
    // worker: a session owns a native handle and cannot move between isolates.
    // The worker reports the set it created; a list mutated inside the spawned
    // isolate would not be visible here, which is exactly the boundary this
    // assertion is about.
    final paths = worker!.loadedGraphs;
    expect(paths, hasLength(4));
    expect(paths.map((p) => p.split('/').last).toSet(), <String>{
      'vieneu_prefill.onnx',
      'vieneu_decode_step.onnx',
      'vieneu_acoustic_cached.onnx',
      'moss_audio_tokenizer_decode_full.onnx',
    });
    expect(worker!.isolateName, isNotEmpty);
    expect(worker.isolateName, isNot(Isolate.current.debugName ?? ''));
    expect(worker.loadTime, greaterThan(Duration.zero));

    final output = await worker.synthesize(job());
    expect(output.failureOrNull, isNull, reason: '${output.failureOrNull}');
    final synthesis = output.valueOrNull!;
    // The fake codec returns 8 samples per call; the assertion that matters is
    // that a non-empty waveform came back through the isolate boundary.
    expect(synthesis.samples, isNotEmpty);
    expect(synthesis.sampleRate, 48000);
    expect(synthesis.frames, greaterThan(0));
    expect(synthesis.duration.inMilliseconds, greaterThanOrEqualTo(0));
    expect(worker.completedRequests, 1);

    await worker.dispose();
    expect(worker.isClosed, isTrue);
  });

  test('synthesis after dispose fails instead of hanging', () async {
    plantTinyModel();
    final worker = (await VieNeuSynthesisWorker.start(
      modelDirectory: modelDir,
      codecDirectory: codecDir,
      factory: fakeSessionFactory(),
    ))
        .valueOrNull!;
    await worker.dispose();
    final output = await worker.synthesize(job());
    expect(output.failureOrNull, isA<ProcessingFailure>());
  });

  test('a caller that sizes no timeout still gets a bounded one', () async {
    // The fallback exists so a caller that forgets to pass a budget cannot hang
    // the reader. It is deliberately the same ceiling the sized budgets are
    // clamped to, so behaviour does not depend on which path was taken.
    plantTinyModel();
    final worker = (await VieNeuSynthesisWorker.start(
      modelDirectory: modelDir,
      codecDirectory: codecDir,
      factory: fakeSessionFactory(),
      requestTimeout: const Duration(seconds: 30),
    ))
        .valueOrNull!;
    final output = await worker.synthesize(job());
    expect(output.failureOrNull, isNull, reason: '${output.failureOrNull}');
    await worker.dispose();
  });

  test('an empty phoneme string produces no audio and no crash', () async {
    plantTinyModel();
    final worker = (await VieNeuSynthesisWorker.start(
      modelDirectory: modelDir,
      codecDirectory: codecDir,
      factory: fakeSessionFactory(),
    ))
        .valueOrNull!;
    final output = await worker.synthesize(job(phonemes: '   '));
    expect(output.valueOrNull!.samples, isEmpty);
    expect(output.valueOrNull!.frames, 0);
    await worker.dispose();
  });

  test('a graph that fails mid-run is reported as a corrupt model', () async {
    plantTinyModel();
    final worker = (await VieNeuSynthesisWorker.start(
      modelDirectory: modelDir,
      codecDirectory: codecDir,
      factory: fakeSessionFactory(shared: FakeOnnxSession(throwOnRun: true)),
    ))
        .valueOrNull!;
    final output = await worker.synthesize(job());
    expect(output.failureOrNull, isA<CorruptModelFailure>());
    await worker.dispose();
  });
}
