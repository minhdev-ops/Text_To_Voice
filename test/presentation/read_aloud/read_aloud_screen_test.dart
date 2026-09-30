import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:text_to_voice/core/theme/app_theme.dart';
import 'package:text_to_voice/domain/models/reading.dart';
import 'package:text_to_voice/domain/speech/sentence_synthesis_queue.dart';
import 'package:text_to_voice/domain/speech/synthesis_cache.dart';
import 'package:text_to_voice/presentation/read_aloud/read_aloud_providers.dart';
import 'package:text_to_voice/presentation/read_aloud/read_aloud_screen.dart';
import 'package:text_to_voice/presentation/read_aloud/sentence_block.dart';
import 'package:text_to_voice/presentation/read_aloud/sentence_ruler.dart';
import 'package:text_to_voice/presentation/read_aloud/transport_bar.dart';

import '../../support/fake_audio_output.dart';
import '../../support/fake_tts_engine.dart';

void main() {
  late FakeTtsEngine engine;
  late FakeAudioOutput output;
  late SentenceSynthesisQueue queue;

  const text = 'Câu một. Câu hai. Câu ba.';

  setUp(() {
    engine = FakeTtsEngine(millisecondsPerCharacter: 20);
    output = FakeAudioOutput();
    queue = SentenceSynthesisQueue(
      engine: engine,
      cache: InMemorySynthesisCache(),
      lookAhead: 1,
    );
    _clockNow = DateTime(2026);
  });

  /// Mounts the screen. [missingModel] leaves the real default engine in place,
  /// which is the app's own "no checkpoint bundled yet" state.
  Future<void> pumpScreen(
    WidgetTester tester, {
    bool missingModel = false,
  }) async {
    engine.ready = !missingModel;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (!missingModel) ttsEngineProvider.overrideWithValue(engine),
          sentenceQueueProvider.overrideWithValue(queue),
          audioOutputProvider.overrideWithValue(output),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ReadAloudScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> typeText(WidgetTester tester, String value) async {
    await tester.enterText(find.byType(TextField), value);
    await tester.pumpAndSettle();
  }

  /// Labels of the rows currently built in the open sheet.
  List<String> sheetTitles(WidgetTester tester) => tester
      .widgetList<ListTile>(find.byType(ListTile))
      .map((tile) => (tile.title! as Text).data!)
      .toList();

  /// The primary button, named exactly — the app bar carries the same words as
  /// a title, which a bare `find.text` would confuse.
  Future<void> tapRead(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Đọc thành tiếng'));
    await tester.pumpAndSettle();
  }

  group('composer', () {
    testWidgets('starts empty, with nothing to read', (tester) async {
      await pumpScreen(tester);

      expect(find.text('Chưa có văn bản để đọc.'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Đọc thành tiếng'),
      );
      expect(button.onPressed, isNull, reason: 'disabled without text');
    });

    testWidgets('counts the sentences it would read', (tester) async {
      await pumpScreen(tester);
      await typeText(tester, text);

      expect(find.text('Sẽ đọc 3 câu, theo từng câu một.'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Đọc thành tiếng'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('a sentence count is a count, never an invented time',
        (tester) async {
      await pumpScreen(tester);
      await typeText(tester, 'Chỉ một câu thôi.');

      expect(find.text('Sẽ đọc 1 câu, theo từng câu một.'), findsOneWidget);
    });

    testWidgets('with text but no engine the primary action stays disabled',
        (tester) async {
      await pumpScreen(tester, missingModel: true);
      await typeText(tester, text);

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Đọc thành tiếng'),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('model not installed', () {
    testWidgets('says so, and offers the next action instead of a dead button',
        (tester) async {
      await pumpScreen(tester, missingModel: true);

      expect(find.text('Chưa có model đọc tiếng Việt'), findsOneWidget);
      expect(find.text('Mở Models'), findsOneWidget);
      // Privacy copy stays literally true at the step that needs the network.
      expect(
        find.text('Cần mạng để tải model. Tài liệu của bạn vẫn không rời khỏi máy.'),
        findsOneWidget,
      );
    });
  });

  group('reading', () {
    testWidgets('shows one block per sentence with the spine on the current one',
        (tester) async {
      await pumpScreen(tester);
      await typeText(tester, text);
      await tapRead(tester);

      expect(find.byType(SentenceBlock), findsNWidgets(3));
      final blocks = tester.widgetList<SentenceBlock>(find.byType(SentenceBlock));
      expect(blocks.where((b) => b.isCurrent), hasLength(1));
      expect(blocks.first.isCurrent, isTrue);
      // The reading surface replaces the composer, and the transport is there.
      expect(find.byType(TransportBar), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('while the first sentence is prepared, the transport says so',
        (tester) async {
      // The state under test is "synthesizing, no audio yet", so the engine's
      // future has to stay pending across the pumps below. `latency` is the lever
      // that does that: it is the only thing in `FakeTtsEngine` that actually
      // suspends `synthesize`. `millisecondsPerCharacter` only makes the returned
      // audio *longer* — the future still resolves in a microtask, the sentence
      // is `ready` and then `playing` before any assertion runs, and the test
      // passes or fails on scheduling luck rather than on behaviour.
      //
      // The 400 ms/character is not decoration: the transport's clock is only
      // meaningful once a sentence is longer than a second, and the default 20
      // would make even a finished document read "0:00 / 0:00" — which is honest
      // for a 160 ms clip and useless as a check that a real clock appeared.
      engine = FakeTtsEngine(
        latency: const Duration(milliseconds: 500),
        millisecondsPerCharacter: 400,
      );
      queue = SentenceSynthesisQueue(
        engine: engine,
        cache: InMemorySynthesisCache(),
        lookAhead: 1,
      );
      await pumpScreen(tester);
      await typeText(tester, text);

      await tester.tap(find.widgetWithText(FilledButton, 'Đọc thành tiếng'));
      await tester.pump();
      await tester.pump();

      expect(queue.sentences.first.status, SentenceStatus.synthesizing);
      expect(find.text('Đang xử lý…'), findsOneWidget);
      // A "0:00 / 0:00" while nothing can play yet reads as a broken clock.
      expect(find.text('0:00 / 0:00'), findsNothing);

      // Released deliberately, so the claim above is about a transition rather
      // than a state the screen could get stuck in. `latency` is dropped first:
      // a future already parked on a 500 ms timer would resolve into a *second*
      // synthesis, and the timing would depend on which one won.
      engine.latency = Duration.zero;
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(queue.sentences.first.status, isNot(SentenceStatus.synthesizing));
      expect(find.text('Đang xử lý…'), findsNothing);
      // A real clock, not the placeholder that was refused above.
      expect(find.text('0:00 / 0:00'), findsNothing);
      expect(find.textContaining('/ 0:0'), findsOneWidget);
    });

    testWidgets('the ruler and the transport agree with the state',
        (tester) async {
      await pumpScreen(tester);
      await typeText(tester, text);
      await tapRead(tester);

      expect(find.byType(SentenceRuler), findsOneWidget);
      expect(find.text('Câu 1/3'), findsOneWidget);

      output.complete();
      await tester.pumpAndSettle();

      expect(find.text('Câu 2/3'), findsOneWidget);
      final blocks = tester.widgetList<SentenceBlock>(find.byType(SentenceBlock));
      expect(blocks.elementAt(1).isCurrent, isTrue);
      expect(queue.sentences.first.status, SentenceStatus.played);
    });

    testWidgets('tapping a sentence reads from that sentence', (tester) async {
      await pumpScreen(tester);
      await typeText(tester, text);
      await tapRead(tester);

      await tester.tap(find.text('Câu ba.'));
      await tester.pumpAndSettle();

      expect(find.text('Câu 3/3'), findsOneWidget);
      expect(queue.sentences[2].status, SentenceStatus.playing);
    });

    testWidgets('play/pause keeps its position instead of restarting',
        (tester) async {
      await pumpScreen(tester);
      await typeText(tester, text);
      await tapRead(tester);
      output.complete();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.pause_outlined));
      await tester.pumpAndSettle();
      expect(output.pauseCalls, 1);

      await tester.tap(find.byIcon(Icons.play_arrow_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Câu 2/3'), findsOneWidget);
    });

    testWidgets('a failed sentence is reported and can be retried',
        (tester) async {
      engine.failingTexts.add('Câu hai.');
      await pumpScreen(tester);
      await typeText(tester, text);
      await tapRead(tester);

      output.complete();
      await tester.pumpAndSettle();

      // Reading continued to sentence 3, and the banner still names sentence 2.
      expect(find.text('Câu 3/3'), findsOneWidget);
      expect(
        find.textContaining('Câu 2: Không tổng hợp được câu này.'),
        findsOneWidget,
      );

      engine.failingTexts.clear();
      await tester.tap(find.text('Đọc lại câu này').first);
      await tester.pumpAndSettle();

      expect(find.text('Câu 2/3'), findsOneWidget);
    });
  });

  group('FR-10 — speed', () {
    testWidgets('the sheet offers exactly the six presets and applies one',
        (tester) async {
      await pumpScreen(tester);
      await typeText(tester, text);

      await tester.tap(find.text('1.0×').first);
      await tester.pumpAndSettle();

      // The sheet scrolls on a short screen, so walk it to the end and collect
      // every row: the point is that the choices are exactly the six presets,
      // not that six rows happen to fit in the viewport.
      final seen = <String>{...sheetTitles(tester)};
      await tester.drag(find.byType(ListView).last, const Offset(0, -200));
      await tester.pumpAndSettle();
      seen.addAll(sheetTitles(tester));

      expect(
        seen,
        <String>{'0.5×', '0.75×', '1.0×', '1.25×', '1.5×', '2.0×'},
      );

      await tester.tap(find.text('2.0×'));
      await tester.pumpAndSettle();

      expect(find.text('2.0×'), findsWidgets);
    });

    testWidgets('a speed change mid-read keeps the current sentence',
        (tester) async {
      await pumpScreen(tester);
      await typeText(tester, text);
      await tapRead(tester);

      await tester.tap(find.text('1.0×').first);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).last, const Offset(0, -200));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2.0×'));
      await tester.pumpAndSettle();

      expect(find.text('Câu 1/3'), findsOneWidget);
      expect(find.text('2.0×'), findsWidgets);
      expect(queue.sentences[2].status, SentenceStatus.idle,
          reason: 'later sentences are re-synthesized at the new speed');
    });

    testWidgets('on a slow device a speed change asks before discarding audio',
        (tester) async {
      // The fake above makes audio in a microtask, so the confirm never appears
      // in the tests above — which is right, but it also means the path that
      // every real user on this hardware takes would be the untested one. The
      // latency here stands in for the ~15 s a sentence actually costs on a
      // Galaxy A75, which is the whole reason the question is being asked.
      engine = FakeTtsEngine(
        latency: const Duration(milliseconds: 4000),
        millisecondsPerCharacter: 400,
      );
      queue = SentenceSynthesisQueue(
        engine: engine,
        cache: InMemorySynthesisCache(),
        lookAhead: 1,
        clock: _slowClock,
      );

      await pumpScreen(tester);
      await typeText(tester, text);
      await tapRead(tester);
      // Let the first sentence finish so a real measurement exists.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.tap(find.text('1.0×').first);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).last, const Offset(0, -200));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2.0×'));
      await tester.pumpAndSettle();

      expect(find.text('Đổi tốc độ?'), findsOneWidget);
      // A cost in seconds is quoted, so the interruption is explaining itself.
      // The exact figure is not asserted: two sentences are synthesized
      // concurrently, and how the clock reads interleave between them is a
      // scheduling detail, not a promise this test should make on the app's
      // behalf. `synthesis_cost_test` pins the number itself.
      expect(find.textContaining('giây'), findsWidgets);

      await tester.tap(find.text('Huỷ'));
      await tester.pumpAndSettle();

      // Declining leaves everything exactly as it was: no speed change, and the
      // prepared audio is still there.
      expect(find.text('Đổi tốc độ?'), findsNothing);
      expect(queue.sentences[1].status, SentenceStatus.ready,
          reason: 'cancelling must not discard audio that was already paid for');
    });

    testWidgets('confirming a speed change on a slow device proceeds',
        (tester) async {
      engine = FakeTtsEngine(
        latency: const Duration(milliseconds: 4000),
        millisecondsPerCharacter: 400,
      );
      queue = SentenceSynthesisQueue(
        engine: engine,
        cache: InMemorySynthesisCache(),
        lookAhead: 1,
        clock: _slowClock,
      );

      await pumpScreen(tester);
      await typeText(tester, text);
      await tapRead(tester);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.tap(find.text('1.0×').first);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).last, const Offset(0, -200));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2.0×'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đổi').last);
      await tester.pumpAndSettle();

      expect(find.text('Đổi tốc độ?'), findsNothing);
      expect(find.text('2.0×'), findsWidgets);
      expect(queue.sentences[2].status, SentenceStatus.idle);
    });
  });
}

/// A clock that advances a fixed amount on every read, so a synthesis looks
/// like it took the four seconds a real one costs on this hardware.
///
/// It is deliberately dumb: a "smart" clock that inspected the engine would be
/// testing the stub instead of the queue.
DateTime _slowClock() {
  final previous = _clockNow;
  _clockNow = previous.add(const Duration(seconds: 4));
  return previous;
}

var _clockNow = DateTime(2026);
