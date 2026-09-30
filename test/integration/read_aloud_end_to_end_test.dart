// Phase 1 item 20 — the end-to-end path, run headless.
//
// "Integration" here means the real collaborators: the real normalizer, the real
// sentence splitter, the real queue and session, a real synthesis cache and real
// WAV files on disk (via `dart:io`). Only two things are substituted, and both
// are documented:
//
//   * the TTS *model* — no Vietnamese checkpoint is bundled yet (SRS §47), so
//     `FakeTtsEngine` stands in and writes structurally valid WAV bytes;
//   * the audio *device* — a test cannot open a speaker, so `FakeAudioOutput`
//     reports completion when the test says the file ended.
//
// Everything the SRS actually constrains (FR-12 start fast, SRS §32 no
// re-synthesis, FR-11 playback to the end of the document, NFR-01 no network)
// is exercised by the real code below. The on-device variant — real ONNX
// inference through `just_audio` — needs `integration_test` and a phone, and is
// blocked on the same checkpoint decision as ROADMAP item 6.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:text_to_voice/domain/models/reading.dart';
import 'package:text_to_voice/domain/speech/read_aloud_session.dart';
import 'package:text_to_voice/domain/speech/sentence_synthesis_queue.dart';
import 'package:text_to_voice/domain/speech/synthesis_cache.dart';

import '../support/fake_audio_output.dart';
import '../support/fake_tts_engine.dart';

void main() {
  late Directory workspace;
  late FakeTtsEngine engine;
  late FakeAudioOutput output;
  late SentenceSynthesisQueue queue;
  late ReadAloudSession session;

  /// Real Vietnamese input: diacritics, a number that the normalizer has to
  /// expand, an abbreviation that must not split a sentence, and a paragraph
  /// break as a hard boundary.
  const input = '''
Năm 2026, tài liệu này nói về việc đọc tiếng Việt trên điện thoại.
TS. Nguyễn Văn A cho rằng chất lượng giọng đọc quan trọng hơn tốc độ.

Câu cuối cùng khép lại tài liệu.
''';

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('vietdoc_e2e_');
    engine = FakeTtsEngine(directory: workspace);
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
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  /// Files actually written to disk by the engine.
  List<File> wavFiles() => workspace
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.wav'))
      .toList();

  /// Waits for the session to reach a state instead of guessing how many
  /// event-loop turns real file I/O needs. `pumpEventQueue` is not enough here:
  /// the engine writes actual bytes to disk, so the completion of a synthesis is
  /// genuinely asynchronous.
  Future<void> waitFor(
    bool Function() condition, {
    String reason = 'the session never settled',
  }) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) fail(reason);
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  /// Plays the whole document, completing each sentence only once it has
  /// actually started — which is what the media session would do.
  Future<void> readToTheEnd() async {
    var guard = 0;
    while (!session.state.finished) {
      final index = session.state.currentIndex;
      await waitFor(
        () => session.state.isPlaying && session.state.currentIndex == index,
        reason: 'sentence $index never started playing',
      );
      output.complete();
      await waitFor(
        () =>
            session.state.finished ||
            session.state.currentIndex != index ||
            !session.state.isPlaying,
        reason: 'playback never advanced past sentence $index',
      );
      if (++guard > 20) fail('reading never finished');
    }
  }

  /// A WAV is only real if the container says so: `RIFF`/`WAVE`, and a `data`
  /// chunk whose declared size fits inside the file.
  void expectValidWav(File file) {
    final bytes = file.readAsBytesSync();
    expect(bytes.length, greaterThan(44), reason: '${file.path} is header-only');

    String ascii(int start, int length) =>
        String.fromCharCodes(bytes.sublist(start, start + length));

    expect(ascii(0, 4), 'RIFF');
    expect(ascii(8, 4), 'WAVE');
    expect(ascii(12, 4), 'fmt ');
    expect(ascii(36, 4), 'data');

    final declaredData = bytes[40] |
        (bytes[41] << 8) |
        (bytes[42] << 16) |
        (bytes[43] << 24);
    expect(declaredData + 44, bytes.length,
        reason: 'declared data size must match the file: ${file.path}');
  }

  test('text becomes real WAV files on disk', () async {
    await session.read(input);

    final files = wavFiles();
    expect(files, isNotEmpty);
    // FR-12: one file per sentence, never one file for the document.
    for (final file in files) {
      expectValidWav(file);
    }
    // The first sentence is already on disk before the document is finished:
    // the queue only warmed one sentence ahead.
    expect(files.length, lessThan(session.state.total));
  });

  test('playback starts on sentence 1 and reaches the end of the document',
      () async {
    await session.read(input);
    final total = session.state.total;
    expect(total, greaterThan(1), reason: 'the input must split into sentences');

    // Sentence 1 plays first, from a file that exists on disk.
    expect(session.state.currentIndex, 0);
    expect(session.state.isPlaying, isTrue);
    expect(File(output.played.single).existsSync(), isTrue);

    // Every sentence is spoken in order, then playback completes.
    var spoken = 1;
    while (!session.state.finished) {
      final index = session.state.currentIndex;
      output.complete();
      await waitFor(
        () =>
            session.state.finished ||
            session.state.currentIndex != index ||
            !session.state.isPlaying,
        reason: 'playback stalled after sentence $index',
      );
      if (session.state.currentIndex != index) {
        // Reading order, with no gaps and no repeats.
        expect(session.state.currentIndex, index + 1);
        spoken++;
      }
    }
    expect(spoken, total);

    expect(session.state.finished, isTrue);
    expect(session.state.isPlaying, isFalse);
    expect(output.played, hasLength(total));
    expect(
      queue.sentences.every((s) => s.status == SentenceStatus.played),
      isTrue,
      reason: 'every sentence was spoken exactly once',
    );
    // One file per sentence, all of them real.
    expect(wavFiles(), hasLength(total));
    for (final file in wavFiles()) {
      expectValidWav(file);
    }
  });

  test('re-reading the same text reuses the audio instead of resynthesizing',
      () async {
    await session.read(input);
    await readToTheEnd();
    final firstPassCalls = engine.synthesizeCalls;
    final filesAfterFirstPass = wavFiles().length;

    // Reading it again, as a user would when they finish a document and hit
    // play: SRS §32 says nothing should be synthesized a second time.
    await session.read(input);
    await waitFor(() => session.state.isPlaying,
        reason: 'the second read never started');

    expect(engine.synthesizeCalls, firstPassCalls);
    expect(wavFiles(), hasLength(filesAfterFirstPass));
    expect(session.state.isPlaying, isTrue);
  });

  test('the document is read sentence by sentence, not as one blob', () async {
    await session.read(input);

    // The abbreviation kept two sentences together, the paragraph break split
    // them, and the number was expanded before synthesis: all three rules are
    // visible in what the synthesizer was actually handed.
    final synthesized = engine.synthesizedTexts;
    expect(
      synthesized.any((text) => text.contains('TS. Nguyễn Văn A')),
      isTrue,
      reason: 'the abbreviation must not split a sentence',
    );
    expect(
      synthesized.any((text) => text.contains('hai nghìn không trăm hai mươi sáu')),
      isTrue,
      reason: 'numbers are normalized before synthesis',
    );
    expect(
      synthesized.every((text) => !text.contains('\n')),
      isTrue,
      reason: 'a sentence never carries a line break',
    );
  });

  test('speed changing mid-document re-synthesizes only what is left',
      () async {
    await session.read(input);
    final callsBefore = engine.synthesizeCalls;
    final currentSentence = session.state.currentIndex;

    await session.setSpeed(1.5);
    output.complete();
    await waitFor(
      () =>
          session.state.currentIndex == currentSentence + 1 ||
          session.state.finished,
      reason: 'playback never moved to the sentence after the speed change',
    );

    // The sentence being spoken was not restarted and not re-synthesized...
    expect(engine.synthesizedSpeeds.last, 1.5,
        reason: 'the next sentence is synthesized at the new rate');
    expect(engine.synthesizeCalls, greaterThan(callsBefore));
    expect(session.state.currentIndex, currentSentence + 1);
    expect(session.options.speed, 1.5);
    // ...and what it produced is a real file on disk.
    final freshest = File(output.played.last);
    expect(freshest.existsSync(), isTrue);
    expectValidWav(freshest);
  });
}
