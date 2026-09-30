import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:text_to_voice/domain/models/reading.dart';
import 'package:text_to_voice/domain/models/tts.dart';
import 'package:text_to_voice/domain/speech/read_aloud_session.dart';
import 'package:text_to_voice/domain/speech/sentence_synthesis_queue.dart';
import 'package:text_to_voice/domain/speech/synthesis_cache.dart';

import '../../support/fake_audio_output.dart';
import '../../support/fake_tts_engine.dart';

void main() {
  late FakeTtsEngine engine;
  late FakeAudioOutput output;
  late SentenceSynthesisQueue queue;
  late ReadAloudSession session;

  const text = 'Câu một. Câu hai. Câu ba.';

  setUp(() {
    engine = FakeTtsEngine();
    output = FakeAudioOutput();
    queue = SentenceSynthesisQueue(
      engine: engine,
      cache: InMemorySynthesisCache(),
      lookAhead: 1,
    );
    session = ReadAloudSession(queue: queue, output: output);
  });

  tearDown(() => session.dispose());

  group('FR-11 — reading a document', () {
    test('reading starts on the first sentence without waiting for the rest',
        () async {
      await session.read(text);

      expect(session.state.isPlaying, isTrue);
      expect(session.state.currentIndex, 0);
      expect(session.state.total, 3);
      expect(output.played, hasLength(1));
      // Sentence 1 + one look-ahead sentence, not all three.
      expect(engine.synthesizeCalls, 2);
      expect(queue.sentences.first.status, SentenceStatus.playing);
    });

    test('a finished sentence advances to the next one', () async {
      await session.read(text);

      output.complete();
      await pumpEventQueue();

      expect(session.state.currentIndex, 1);
      expect(session.state.isPlaying, isTrue);
      expect(queue.sentences[0].status, SentenceStatus.played);
      expect(output.played, hasLength(2));
    });

    test('the end of the document stops the transport', () async {
      await session.read(text);

      for (var i = 0; i < 3; i++) {
        output.complete();
        await pumpEventQueue();
      }

      expect(session.state.isPlaying, isFalse);
      expect(session.state.finished, isTrue);
      expect(session.state.currentIndex, 2);
      expect(output.played, hasLength(3));
    });

    test('reading empty text plays nothing and does not start', () async {
      await session.read('   ');

      expect(session.state.isEmpty, isTrue);
      expect(session.state.isPlaying, isFalse);
      expect(output.played, isEmpty);
      expect(engine.synthesizeCalls, 0);
    });

    test('starting playback announces each call it is about to await',
        () async {
      final printed = <String>[];
      await runZoned(
        () => session.read(text),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => printed.add(line),
        ),
      );

      // The device-side silence this closes: when playback stalls, the last
      // printed stage names the await it stalled in.
      final log = printed.join('\n');
      expect(log, contains('speech.play.speed'));
      expect(log, contains('speech.play.call'));
      expect(log, contains('speech.play.returned'));
    });
  });

  group('transport', () {
    test('pause then play resumes at the same sentence, not at zero', () async {
      await session.read(text);
      output.complete();
      await pumpEventQueue();
      expect(session.state.currentIndex, 1);

      await session.pause();
      expect(session.state.isPlaying, isFalse);

      await session.play();
      expect(session.state.currentIndex, 1);
      expect(session.state.isPlaying, isTrue);
    });

    test('next and previous move by sentence and clamp at the ends', () async {
      await session.read(text);

      await session.next();
      expect(session.state.currentIndex, 1);

      await session.previous();
      expect(session.state.currentIndex, 0);

      // Already at the first sentence: stays there rather than wrapping.
      await session.previous();
      expect(session.state.currentIndex, 0);

      await session.seekToSentence(99);
      expect(session.state.currentIndex, 2);
    });

    test('seeking while paused moves without starting playback', () async {
      await session.read(text);
      await session.pause();
      final playsBefore = output.played.length;

      await session.seekToSentence(2);

      expect(session.state.currentIndex, 2);
      expect(session.state.isPlaying, isFalse);
      expect(output.played.length, playsBefore);
    });

    test('tapping a sentence restarts from that sentence (FR-12)', () async {
      await session.read(text);

      await session.seekToSentence(2);

      expect(session.state.currentIndex, 2);
      expect(output.played.last, isNotEmpty);
      expect(queue.sentences[2].status, SentenceStatus.playing);
      // The one that was playing is released, so only one Spine exists.
      expect(queue.sentences[0].status, SentenceStatus.played);
    });
  });

  group('FR-10 — speed', () {
    test('a speed change does not restart the current sentence', () async {
      await session.read(text);
      final playsBefore = output.played.length;

      await session.setSpeed(1.5);

      expect(output.played.length, playsBefore, reason: 'no restart');
      expect(session.state.currentIndex, 0);
      expect(queue.sentences[0].status, SentenceStatus.playing);
      expect(output.speeds.last, 1.5);
    });

    test('it applies from the next sentence onward', () async {
      await session.read(text);
      await session.setSpeed(1.5);

      // Sentences after the current one were invalidated, so they are no longer
      // ready and will be synthesized again at the new speed.
      expect(queue.sentences[1].status, SentenceStatus.idle);
      expect(queue.sentences[2].status, SentenceStatus.idle);

      final callsAtOldSpeed = engine.synthesizeCalls;
      output.complete();
      await pumpEventQueue();

      expect(engine.synthesizeCalls, greaterThan(callsAtOldSpeed));
      expect(session.state.currentIndex, 1);
      expect(queue.sentences[1].status, SentenceStatus.playing);
    });

    test('the speed is clamped to the six allowed presets range', () async {
      await session.read(text);

      await session.setSpeed(9.0);

      expect(session.options.speed, TtsOptions.maxSpeed);
      expect(output.speeds.last, TtsOptions.maxSpeed);
    });

    test('a volume change does not invalidate synthesized sentences',
        () async {
      await session.read(text);
      final callsBefore = engine.synthesizeCalls;

      await session.setVolume(0.4);

      expect(session.options.volume, 0.4);
      expect(output.volumes.last, 0.4);
      expect(engine.synthesizeCalls, callsBefore);
      expect(queue.sentences[1].status, SentenceStatus.ready);
    });
  });

  group('a failed sentence is skipped, not fatal', () {
    test('playback continues with the following sentence', () async {
      engine.failingTexts.add('Câu hai.');
      await session.read(text);
      expect(session.state.currentIndex, 0);

      output.complete();
      await pumpEventQueue();

      // Sentence 2 failed; sentence 3 is being read instead.
      expect(session.state.failedSentenceIndex, 1);
      expect(session.state.failureMessage, 'Không tổng hợp được câu này.');
      expect(session.state.currentIndex, 2);
      expect(session.state.isPlaying, isTrue);
      expect(queue.sentences[1].status, SentenceStatus.failed);
    });

    test('the document ends honestly when every sentence fails', () async {
      engine.failingTexts.addAll(<String>['Câu một.', 'Câu hai.', 'Câu ba.']);

      await session.read(text);

      expect(session.state.isPlaying, isFalse);
      expect(session.state.finished, isTrue);
      expect(session.state.failedSentenceIndex, 2);
      expect(output.played, isEmpty);
    });

    test('retryFailed re-synthesizes and continues from that sentence',
        () async {
      engine.failingTexts.add('Câu hai.');
      await session.read(text);
      output.complete();
      await pumpEventQueue();
      expect(session.state.currentIndex, 2);

      engine.failingTexts.clear();
      await session.retryFailed();

      expect(session.state.failedSentenceIndex, isNull);
      expect(session.state.currentIndex, 1);
      expect(queue.sentences[1].status, SentenceStatus.playing);
    });
  });

  group('state reporting for the transport bar and the ruler', () {
    test('elapsed sums real durations plus the offset in the sentence',
        () async {
      await session.read(text);
      final firstDuration =
          Duration(milliseconds: queue.sentences[0].durationMs ?? 0);

      output.emitPosition(const Duration(milliseconds: 100));
      await pumpEventQueue();
      expect(
        session.state.elapsed,
        const Duration(milliseconds: 100),
      );

      output.complete();
      await pumpEventQueue();

      expect(
        session.state.elapsed,
        firstDuration,
      );
    });

    test('knownDuration grows as sentences are prepared', () async {
      await session.read(text);
      final early = session.state.knownDuration;

      await queue.audioAt(2);
      await pumpEventQueue();

      expect(session.state.knownDuration, greaterThan(early));
    });

    test('state is published as one value', () async {
      final seen = <ReadAloudState>[];
      final subscription = session.states.listen(seen.add);

      await session.read(text);
      await pumpEventQueue();

      expect(seen, isNotEmpty);
      expect(seen.last.sentences, isNotEmpty);
      expect(seen.last.isPlaying, isTrue);
      await subscription.cancel();
    });
  });

  group('ownership', () {
    // The output and the queue are created and disposed by their own
    // providers (audioOutputProvider / sentenceQueueProvider). When the
    // session chain rebuilds — engine swap after the model audit finishes —
    // the old session must not tear down collaborators the new session still
    // uses: that disposed the shared JustAudio player and every later play()
    // became a silent no-op.
    test('dispose stops playback but does not dispose the output', () async {
      await session.read(text);
      // `read()` stops first to clear anything already playing, so the count is
      // measured from here rather than assumed — the property under test is that
      // *dispose* stops, not how many times reading did.
      final beforeDispose = output.stopCalls;
      await session.dispose();

      expect(output.stopCalls, beforeDispose + 1);
      expect(output.disposed, isFalse);
    });
  });
}
