// The cost of CPU-only synthesis is now visible to the user, and these are the
// three things that make it visible. Each test pins a fact the UI depends on,
// so a future change that quietly removes the honesty fails here rather than in
// a support report.

import 'package:flutter_test/flutter_test.dart';

import 'package:text_to_voice/domain/models/reading.dart';
import 'package:text_to_voice/domain/models/tts.dart';
import 'package:text_to_voice/domain/speech/read_aloud_session.dart';
import 'package:text_to_voice/domain/speech/sentence_synthesis_queue.dart';
import 'package:text_to_voice/domain/speech/synthesis_cache.dart';

import '../../support/fake_audio_output.dart';
import '../../support/fake_tts_engine.dart';

void main() {
  const text = 'Câu một. Câu hai. Câu ba.';

  late FakeTtsEngine engine;
  late SentenceSynthesisQueue queue;
  late ReadAloudSession session;
  late FakeAudioOutput output;

  setUp(() {
    engine = FakeTtsEngine(millisecondsPerCharacter: 20);
    output = FakeAudioOutput();
    queue = SentenceSynthesisQueue(
      engine: engine,
      cache: InMemorySynthesisCache(),
      lookAhead: 1,
    );
    session = ReadAloudSession(queue: queue, output: output);
  });

  tearDown(() async {
    await session.dispose();
  });

  group('a sentence records what it cost to make', () {
    test('the measured time is kept on the sentence', () async {
      engine.latency = const Duration(milliseconds: 120);
      await queue.load(text, options: const TtsOptions());
      await queue.audioAt(0);

      final sentence = queue.sentences.first;
      expect(sentence.status, SentenceStatus.ready);
      expect(sentence.synthesisMs, isNotNull);
      expect(sentence.synthesisMs, greaterThanOrEqualTo(120));
      // Distinct from the audio's own length, which is what makes the wait
      // visible at all.
      expect(sentence.durationMs, isNot(sentence.synthesisMs));
    });

    test('a cache hit claims no synthesis cost', () async {
      // Seed a shared cache, then measure a second pass that only reads from it.
      final cache = InMemorySynthesisCache();
      final first = SentenceSynthesisQueue(
        engine: engine,
        cache: cache,
        lookAhead: 0,
      );
      await first.load(text, options: const TtsOptions());
      await first.audioAt(0);
      await first.dispose();
      expect(engine.synthesizeCalls, 1);

      // A fresh queue over the same cache and the same sentence: the engine is
      // not called again, so there is no cost to report.
      final second = SentenceSynthesisQueue(
        engine: engine,
        cache: cache,
        lookAhead: 0,
      );
      await second.load(text, options: const TtsOptions());
      await second.audioAt(0);

      expect(engine.synthesizeCalls, 1, reason: 'the engine ran once in total');
      expect(second.sentences.first.status, SentenceStatus.ready);
      expect(
        second.sentences.first.synthesisMs,
        isNull,
        reason: 'audio from the cache was not synthesized, so it cost nothing',
      );
      await second.dispose();
    });
  });

  group('the wait estimate', () {
    test('is null when nothing has been synthesized', () {
      // A session that has not been asked for audio has measured nothing, and
      // must say so rather than implying a wait of zero.
      expect(session.state.synthesisMs, isNull);
    });

    test('reports the slowest sentence, not the average', () async {
      // Sentence 0 is made slowly, sentence 1 quickly. A user waiting is
      // governed by the slow one, and an average would understate it.
      engine.latency = const Duration(milliseconds: 400);
      await queue.load(text, options: const TtsOptions());
      await queue.audioAt(0);

      engine.latency = Duration.zero;
      await queue.audioAt(1);

      final measured = session.state.synthesisMs;
      expect(measured, isNotNull);
      expect(measured!, greaterThanOrEqualTo(400));
    });
  });

  group('a speed change knows what it would cost', () {
    test('counts the sentences after the current one', () async {
      await session.read(text);
      // On sentence 1 of 3, so two are behind.
      expect(session.state.sentencesAfterCurrent, 2);
    });

    test('counts nothing when the last sentence is playing', () async {
      await session.read(text);
      await session.seekToSentence(2);
      expect(session.state.sentencesAfterCurrent, 0);
    });

    test('drops the measurements for the audio a speed change discards',
        () async {
      engine.latency = const Duration(milliseconds: 200);
      await queue.load(text, options: const TtsOptions());
      await queue.audioAt(0);
      await queue.audioAt(1);
      expect(session.state.synthesisMs, isNotNull);

      await session.setSpeed(1.5);
      // The queue publishes synchronously but the session rebuilds its state from
      // a broadcast stream, so the new sentences arrive on a later turn.
      await _settle();

      final sentences = session.state.sentences;
      // FR-10 keeps the sentence being spoken, so its audio — and the cost of
      // making that audio — legitimately survives.
      expect(sentences[0].synthesisMs, isNotNull);
      // Everything after it was thrown away, so quoting a cost for it would be a
      // lie about what the next wait will be.
      expect(sentences[1].synthesisMs, isNull);
      expect(sentences[2].synthesisMs, isNull);
    });
  });
}

/// Lets queued broadcast events reach the session before the state is read.
Future<void> _settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
