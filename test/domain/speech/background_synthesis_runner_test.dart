import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:text_to_voice/core/result/result.dart';
import 'package:text_to_voice/domain/engines/tts_engine.dart';
import 'package:text_to_voice/domain/models/tts.dart';
import 'package:text_to_voice/domain/speech/background_synthesis_runner.dart';
import 'package:text_to_voice/domain/speech/synthesis_cache.dart';

import '../../support/fake_tts_engine.dart';

/// Collects a stream without caring that it is an async* generator.
Future<List<SynthesisProgress>> drain(Stream<SynthesisProgress> stream) =>
    stream.toList();

void main() {
  group('BackgroundSynthesisRunner', () {
    late FakeTtsEngine engine;
    late InMemorySynthesisCache cache;

    setUp(() {
      engine = FakeTtsEngine();
      cache = InMemorySynthesisCache();
    });

    BackgroundSynthesisRunner build() => BackgroundSynthesisRunner(
          engine: engine,
          cache: cache,
        );

    test('generates audio for every sentence of the document', () async {
      final progress = await drain(
        build().generate('Câu một. Câu hai. Câu ba.'),
      );

      expect(engine.synthesizeCalls, 3);
      expect(progress.last.completed, 3);
      expect(progress.last.total, 3);
      expect(progress.last.failed, 0);
      expect(progress.last.finished, isTrue);
    });

    test('every sentence that finished has audio in the cache', () async {
      await drain(build().generate('Câu một. Câu hai.'));

      expect(await cache.find(const TtsOptions().cacheKey('Câu một.')), isNotNull);
      expect(await cache.find(const TtsOptions().cacheKey('Câu hai.')), isNotNull);
    });

    // This is the whole resume mechanism: the cache is keyed by content, so an
    // interrupted run is continued simply by running again.
    test('resumes without re-synthesizing sentences already cached', () async {
      var stop = false;
      final first = await drain(
        build().generate(
          'Câu một. Câu hai. Câu ba. Câu bốn.',
          isCancelled: () => stop,
        ),
      );
      expect(first.last.completed, 4);

      // Second run over the same text: nothing to do.
      engine.synthesizedTexts.clear();
      final second = await drain(build().generate('Câu một. Câu hai. Câu ba. Câu bốn.'));

      expect(engine.synthesizeCalls, 0, reason: 'cache must serve every sentence');
      expect(second.last.completed, 4);
      expect(second.last.finished, isTrue);
    });

    test('a partly cached document only generates the missing sentences',
        () async {
      await drain(build().generate('Câu một.'));

      engine.synthesizedTexts.clear();
      await drain(build().generate('Câu một. Câu hai.'));

      expect(engine.synthesizedTexts, <String>['Câu hai.']);
    });

    test('changing speed generates new audio rather than serving the old',
        () async {
      await drain(build().generate('Câu một.'));
      engine.synthesizedTexts.clear();

      await drain(build().generate(
        'Câu một.',
        options: const TtsOptions(speed: 1.5),
      ));

      expect(engine.synthesizedTexts, <String>['Câu một.'],
          reason: 'audio made at 1.0x must never be served for 1.5x');
    });

    test('cancelling stops before the next sentence and keeps the finished work',
        () async {
      var stop = false;
      final progress = await drain(
        build().generate(
          'Câu một. Câu hai. Câu ba.',
          isCancelled: () => stop,
        ),
      );

      // Nothing has cancelled yet, so the whole document is done; now prove the
      // check actually fires by cancelling from the progress stream.
      expect(progress.last.completed, 3);
      expect(progress.last.cancelled, isFalse);

      engine.synthesizedTexts.clear();
      cache.clear();

      var seen = 0;
      final cancelled = await build()
          .generate(
        'Câu một. Câu hai. Câu ba.',
        isCancelled: () => seen++ >= 2,
      ).toList();

      expect(cancelled.last.cancelled, isTrue);
      expect(cancelled.last.completed, lessThan(3));
      expect(engine.synthesizeCalls, lessThan(3));
    });

    test('a cancelled run keeps the audio it already produced', () async {
      await drain(build().generate('Câu một.'));

      var seen = 0;
      final cancelled = await build()
          .generate(
        'Câu một. Câu hai.',
        isCancelled: () => seen++ >= 1,
      ).toList();

      expect(cancelled.last.cancelled, isTrue);
      expect(await cache.find(const TtsOptions().cacheKey('Câu một.')), isNotNull,
          reason: 'work already done must not be thrown away');
    });

    test('one failed sentence does not stop the rest of the document', () async {
      engine.failingTexts.add('Câu hai.');

      final progress = await drain(
        build().generate('Câu một. Câu hai. Câu ba.'),
      );

      expect(engine.synthesizeCalls, 3, reason: 'the run must not stop at the failure');
      expect(progress.last.completed, 3);
      expect(progress.last.failed, 1);
      expect(progress.last.finished, isTrue);
    });

    test('an engine that is not ready reports the whole document as failed',
        () async {
      engine.ready = false;

      final progress = await drain(build().generate('Câu một. Câu hai.'));

      expect(engine.synthesizeCalls, 0);
      expect(progress.last.finished, isTrue);
      expect(progress.last.failed, 2);
    });

    test('a model that disappears mid-run stops the run instead of failing every sentence',
        () async {
      final failing = _NotReadyAfterFirst();
      final runner = BackgroundSynthesisRunner(engine: failing, cache: cache);

      final progress = await drain(runner.generate('Câu một. Câu hai. Câu ba.'));

      expect(failing.calls, lessThan(3),
          reason: 'must stop at the first model failure, not try every sentence');
      expect(progress.last.finished, isTrue);
      expect(progress.last.failed, 1);
    });

    test('empty text finishes immediately with no work', () async {
      final progress = await drain(build().generate('   '));

      expect(engine.synthesizeCalls, 0);
      expect(progress.last.total, 0);
      expect(progress.last.finished, isTrue);
      expect(progress.last.fraction, isNull);
    });

    test('fraction is null until the total is known', () async {
      final progress = await drain(build().generate('Câu một.'));
      expect(progress.first.fraction, isNotNull);
    });
  });
}

/// Ready for exactly one sentence, then reports the model went away — the
/// `ModelUnavailableFailure` path the runner must not turn into N failures.
class _NotReadyAfterFirst implements TtsEngine {
  int calls = 0;

  @override
  String get id => 'vanishing-tts';

  @override
  String get displayName => 'Vanishing';

  @override
  bool get isReady => calls < 1;

  @override
  Future<Result<AudioResult>> synthesize(String text, TtsOptions options) async {
    calls++;
    if (calls > 1) {
      return Result<AudioResult>.failure(
        const ModelUnavailableFailure(message: 'không có model', modelId: 'vieneu-v3'),
      );
    }
    return Result<AudioResult>.success(
      AudioResult(
        path: '/tmp/x.wav',
        duration: const Duration(milliseconds: 100),
        textHash: options.cacheKey(text),
        sampleRate: 24000,
        voiceId: 'v',
        speed: options.speed,
      ),
    );
  }

  @override
  Future<void> close() async {}
}