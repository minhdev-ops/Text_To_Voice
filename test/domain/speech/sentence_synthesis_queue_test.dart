import 'package:flutter_test/flutter_test.dart';

import 'package:text_to_voice/core/result/result.dart';
import 'package:text_to_voice/domain/models/reading.dart';
import 'package:text_to_voice/domain/models/tts.dart';
import 'package:text_to_voice/domain/speech/sentence_synthesis_queue.dart';
import 'package:text_to_voice/domain/speech/synthesis_cache.dart';

import '../../support/fake_tts_engine.dart';

void main() {
  late FakeTtsEngine engine;
  late InMemorySynthesisCache cache;
  late SentenceSynthesisQueue queue;

  const text = 'Câu một. Câu hai. Câu ba. Câu bốn. Câu năm.';

  SentenceSynthesisQueue buildQueue({int lookAhead = 2}) =>
      SentenceSynthesisQueue(
        engine: engine,
        cache: cache,
        lookAhead: lookAhead,
      );

  setUp(() {
    engine = FakeTtsEngine();
    cache = InMemorySynthesisCache();
    queue = buildQueue();
  });

  tearDown(() => queue.dispose());

  group('load', () {
    test('normalizes then splits, in that order (SRS §12)', () async {
      final sentences = await queue.load(
        'Năm 2026 có 50% tài liệu. Câu hai.',
        options: const TtsOptions(),
      );

      expect(sentences, hasLength(2));
      // The normalizer ran first: the digits are already words, and the
      // splitter therefore sees "phần trăm" rather than "50%".
      expect(sentences.first.text, 'Năm hai nghìn không trăm hai mươi sáu có năm mươi phần trăm tài liệu.');
      expect(sentences.last.text, 'Câu hai.');
      expect(sentences.map((s) => s.index), <int>[0, 1]);
    });

    test('every sentence starts idle', () async {
      final sentences =
          await queue.load(text, options: const TtsOptions());

      expect(sentences, isNotEmpty);
      expect(
        sentences.every((s) => s.status == SentenceStatus.idle),
        isTrue,
      );
    });

    test('empty text produces no sentences', () async {
      expect(await queue.load('   ', options: const TtsOptions()), isEmpty);
    });

    test('loading again replaces the previous text', () async {
      await queue.load('Một. Hai. Ba.', options: const TtsOptions());
      final replaced = await queue.load('Chỉ một câu.', options: const TtsOptions());

      expect(replaced, hasLength(1));
      expect(queue.length, 1);
    });
  });

  group('FR-12 — audio starts before the document is synthesized', () {
    test('only the look-ahead window is synthesized for the first sentence',
        () async {
      await queue.load(text, options: const TtsOptions());
      expect(queue.length, 5);

      final result = await queue.audioAt(0);

      expect(result, isA<Success<AudioResult>>());
      // 1 requested + 2 look-ahead, not all 5 sentences.
      expect(engine.synthesizeCalls, 3);
      expect(queue.sentences[0].status, SentenceStatus.ready);
    });

    test('look-ahead is bounded by the end of the document', () async {
      await queue.load('Một. Hai.', options: const TtsOptions());

      await queue.audioAt(0);

      expect(engine.synthesizeCalls, 2);
    });

    test('a look-ahead of zero synthesizes only what is asked for', () async {
      final lean = buildQueue(lookAhead: 0);
      addTearDown(lean.dispose);
      await lean.load(text, options: const TtsOptions());

      await lean.audioAt(0);

      expect(engine.synthesizeCalls, 1);
    });

    test('repeated requests for the same sentence reuse the work', () async {
      await queue.load(text, options: const TtsOptions());

      final first = queue.audioAt(0);
      final second = queue.audioAt(0);
      await Future.wait(<Future<Result<AudioResult>>>[first, second]);

      expect(engine.synthesizeCalls, 3);
    });
  });

  group('SRS §32 — the cache', () {
    test('re-reading the same text does not re-synthesize', () async {
      const options = TtsOptions();
      await queue.load(text, options: options);
      await queue.audioAt(0);
      final firstPass = engine.synthesizeCalls;

      // A second, independent queue over the same cache: the app being reopened.
      final reopened = buildQueue();
      addTearDown(reopened.dispose);
      await reopened.load(text, options: options);
      final result = await reopened.audioAt(0);

      expect(engine.synthesizeCalls, firstPass);
      expect(result.valueOrNull?.cacheHit, isTrue);
      expect(reopened.sentences[0].status, SentenceStatus.ready);
    });

    test('a different speed is a different cache entry (FR-10)', () async {
      await queue.load(text, options: const TtsOptions());
      await queue.audioAt(0);

      final faster = buildQueue();
      addTearDown(faster.dispose);
      await faster.load(text, options: const TtsOptions(speed: 1.5));
      await faster.audioAt(0);

      // Not served from the 1.0x entry: the waveform differs.
      expect(engine.synthesizeCalls, 6);
    });

    test('the cache is bounded', () async {
      final bounded = InMemorySynthesisCache(maxEntries: 2);
      final small = SentenceSynthesisQueue(
        engine: engine,
        cache: bounded,
        lookAhead: 0,
      );
      addTearDown(small.dispose);
      await small.load(text, options: const TtsOptions());

      for (var i = 0; i < 5; i++) {
        await small.audioAt(i);
      }

      expect(bounded.length, 2);
    });
  });

  group('failure isolation', () {
    test('one failed sentence leaves the others usable', () async {
      engine.failingTexts.add('Câu hai.');
      await queue.load(text, options: const TtsOptions());

      final first = await queue.audioAt(0);
      final second = await queue.audioAt(1);
      final third = await queue.audioAt(2);

      expect(first.isSuccess, isTrue);
      expect(second, isA<Failure<AudioResult>>());
      expect(second.failureOrNull?.message, 'Không tổng hợp được câu này.');
      expect(third.isSuccess, isTrue);
      expect(queue.sentences[1].status, SentenceStatus.failed);
      expect(queue.sentences[1].failureMessage, isNotNull);
      expect(queue.sentences[2].status, SentenceStatus.ready);
    });

    test('a missing model is reported as such, not as a synthesis error',
        () async {
      engine.ready = false;
      await queue.load(text, options: const TtsOptions());

      final result = await queue.audioAt(0);

      expect(result.failureOrNull, isA<ModelUnavailableFailure>());
    });

    test('retry clears the failure and synthesizes again', () async {
      engine.failingTexts.add('Câu một.');
      await queue.load(text, options: const TtsOptions());
      await queue.audioAt(0);
      expect(queue.sentences[0].status, SentenceStatus.failed);

      engine.failingTexts.clear();
      queue.retry(0);
      final retried = await queue.audioAt(0);

      expect(retried.isSuccess, isTrue);
      expect(queue.sentences[0].status, SentenceStatus.ready);
    });
  });

  group('speed and voice changes (FR-10)', () {
    test('invalidating from an index resets everything after it', () async {
      final wide = buildQueue(lookAhead: 4);
      addTearDown(wide.dispose);
      await wide.load(text, options: const TtsOptions());

      // Let the whole window settle first: the warm-up runs in the background,
      // so "kept" would otherwise be indistinguishable from "still in flight".
      for (var i = 0; i < 5; i++) {
        await wide.audioAt(i);
      }
      expect(wide.sentences[4].status, SentenceStatus.ready);

      wide.invalidateFrom(2, options: const TtsOptions(speed: 1.5));

      expect(wide.sentences[0].status, SentenceStatus.ready, reason: 'kept');
      expect(wide.sentences[1].status, SentenceStatus.ready, reason: 'kept');
      expect(wide.sentences[2].status, SentenceStatus.idle);
      expect(wide.sentences[4].status, SentenceStatus.idle);
      expect(wide.sentences[3].audioPath, isNull);
    });

    test('invalidated sentences are synthesized at the new speed', () async {
      await queue.load(text, options: const TtsOptions());
      await queue.audioAt(0);
      final before = engine.synthesizeCalls;

      queue.invalidateFrom(1, options: const TtsOptions(speed: 1.5));
      await queue.audioAt(1);

      expect(engine.synthesizeCalls, greaterThan(before));
      // The look-ahead warmed sentence 1 onward, all at the new options.
      expect(queue.sentences[1].status, SentenceStatus.ready);
      expect(queue.sentences[1].durationMs, isNotNull);
    });
  });

  group('cancellation', () {
    test('in-flight work from the previous text is discarded', () async {
      engine.latency = const Duration(milliseconds: 30);
      await queue.load('Câu cũ một. Câu cũ hai.', options: const TtsOptions());

      final stale = queue.audioAt(0);
      // The user pastes new text before the old one finishes.
      final fresh = await queue.load('Câu mới.', options: const TtsOptions());

      final staleResult = await stale;
      final freshResult = await queue.audioAt(0);

      expect(staleResult.failureOrNull, isA<CancelledFailure>());
      expect(freshResult.isSuccess, isTrue);
      expect(fresh, hasLength(1));
      expect(queue.sentences, hasLength(1));
      expect(queue.sentences[0].text, 'Câu mới.');
    });

    test('status changes are published to listeners', () async {
      await queue.load(text, options: const TtsOptions());
      final seen = <SentenceStatus>[];
      final subscription = queue.changes.listen(
        (sentences) => seen.add(sentences[0].status),
      );

      await queue.audioAt(0);
      await Future<void>.delayed(Duration.zero);

      expect(seen, contains(SentenceStatus.synthesizing));
      expect(seen.last, SentenceStatus.ready);
      await subscription.cancel();
    });
  });

  group('playback marking', () {
    test('at most one sentence is playing at a time', () async {
      await queue.load(text, options: const TtsOptions());
      await queue.audioAt(0);

      queue.markPlaying(0);
      queue.markPlaying(1);

      expect(queue.sentences[0].status, SentenceStatus.played);
      expect(queue.sentences[1].status, SentenceStatus.playing);
    });

    test('audioFor reports what is ready without synthesizing', () async {
      await queue.load(text, options: const TtsOptions());
      expect(queue.audioFor(0), isNull);

      await queue.audioAt(0);

      expect(queue.audioFor(0)?.path, isNotEmpty);
      expect(engine.synthesizeCalls, 3, reason: 'no extra synthesis');
    });
  });

  test('an out-of-range sentence is a typed failure, not a crash', () async {
    await queue.load(text, options: const TtsOptions());

    final result = await queue.audioAt(99);

    expect(result.failureOrNull, isA<NotFoundFailure>());
  });
}
