import 'dart:typed_data';

import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:text_to_voice/core/theme/app_theme.dart';
import 'package:text_to_voice/data/database/app_database.dart';
import 'package:text_to_voice/data/providers.dart' show documentRepositoryProvider;
import 'package:text_to_voice/data/repository/document_repository.dart';
import 'package:text_to_voice/domain/models/reading.dart';
import 'package:text_to_voice/domain/speech/sentence_synthesis_queue.dart';
import 'package:text_to_voice/domain/speech/synthesis_cache.dart';
import 'package:text_to_voice/ai/tts/vieneu_voices.dart';
import 'package:text_to_voice/presentation/read_aloud/read_aloud_providers.dart';
import 'package:text_to_voice/presentation/read_aloud/read_aloud_screen.dart';
import 'package:text_to_voice/presentation/read_aloud/reading_view.dart';
import 'package:text_to_voice/presentation/read_aloud/sentence_ruler.dart';
import 'package:text_to_voice/presentation/read_aloud/transport_bar.dart';

import '../../support/fake_audio_output.dart';
import '../../support/fake_tts_engine.dart';

/// Two voices, small enough to build inline: the sheet needs names to show and
/// ids to resolve, not 192-d embeddings.
VieNeuVoiceCatalog _testCatalog() => VieNeuVoiceCatalog(
      voices: <VieNeuVoice>[
        _voice('Miên'),
        _voice('Bách'),
      ],
      defaultVoiceId: 'Miên',
    );

VieNeuVoice _voice(String id) => VieNeuVoice(
      id: id,
      label: id,
      speakerEmbedding: Float32List(0),
      refCodes: Int32List(0),
      refFrames: 0,
      codebookCount: 1,
    );

void main() {
  late FakeTtsEngine engine;
  late FakeAudioOutput output;
  late SentenceSynthesisQueue queue;
  late DocumentRepository repo;
  late AppDatabase db;

  const text = 'Câu một. Câu hai. Câu ba.';

  setUp(() {
    engine = FakeTtsEngine(millisecondsPerCharacter: 20);
    output = FakeAudioOutput();
    queue = SentenceSynthesisQueue(
      engine: engine,
      cache: InMemorySynthesisCache(),
      lookAhead: 1,
      // Zero: a sentence the fake engine fails on must fail *now*, not after
      // the real 2 s/4 s/8 s backoff the app uses in production.
      retryBaseDelay: Duration.zero,
    );
    db = AppDatabase(NativeDatabase.memory());
    repo = DocumentRepository(db);
    _clockNow = DateTime(2026);
  });

  tearDown(() async => db.close());

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
          documentRepositoryProvider.overrideWithValue(repo),
          voiceCatalogProvider.overrideWith((ref) async => _testCatalog()),
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

      expect(find.textContaining('Sẽ đọc 3 câu'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Đọc thành tiếng'),
      );
      expect(button.onPressed, isNotNull);
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

    testWidgets('the draft is saved for the next visit', (tester) async {
      await pumpScreen(tester);
      await tester.enterText(find.byType(TextField), 'Bản nháp quan trọng.');
      await tester.pumpAndSettle();
      // Past the 800 ms debounce, so the write has actually run.
      await tester.pump(const Duration(milliseconds: 900));

      expect(
        await repo.getSetting(composerDraftSettingKey),
        'Bản nháp quan trọng.',
      );
    });

    testWidgets('the draft comes back on a fresh start', (tester) async {
      // Type into one mount...
      await pumpScreen(tester);
      await tester.enterText(find.byType(TextField), 'Bản nháp còn nguyên.');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 900));

      // ...then remount the screen: the app was closed and opened again.
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Bản nháp còn nguyên.');
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
    testWidgets('shows the document as continuous prose, spine on the current one',
        (tester) async {
      await pumpScreen(tester);
      await typeText(tester, text);
      await tapRead(tester);

      // Every sentence is on the surface as text — one flowing document, not
      // three stacked boxes.
      expect(find.byType(ReadingView), findsOneWidget);
      expect(find.text('Câu một.'), findsOneWidget);
      expect(find.text('Câu hai.'), findsOneWidget);
      expect(find.text('Câu ba.'), findsOneWidget);
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
        retryBaseDelay: Duration.zero,
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

  group('FR-10 — voice and speed', () {
    /// Opens the options sheet from the app bar and walks the speed chips.
    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.text('1.0×').first);
      await tester.pumpAndSettle();
    }

    /// Selects a speed preset, scrolling it into view first — the sheet is
    /// taller than a phone screen and the chips sit below the voice list.
    Future<void> pickSpeed(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    Future<void> confirmSheet(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Xong'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xong'));
      await tester.pumpAndSettle();
    }

    Set<String> speedChips(WidgetTester tester) => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((data) => RegExp(r'^[0-9]+(\.[0-9]+)?×$').hasMatch(data))
        .toSet();

    testWidgets('the sheet offers the voices and the six speed presets',
        (tester) async {
      await pumpScreen(tester);
      await typeText(tester, text);
      await openSheet(tester);

      expect(find.text('Giọng đọc & tốc độ'), findsOneWidget);
      // The voice catalog is visible before any model is installed: the sheet
      // reads the shipped asset, not the engine. Both may also appear on the
      // transport bar behind the sheet, hence `findsWidgets`.
      expect(find.text('Miên'), findsWidgets);
      expect(find.text('Bách'), findsWidgets);
      expect(
        speedChips(tester),
        containsAll(<String>['0.5×', '0.75×', '1.0×', '1.25×', '1.5×', '2.0×']),
      );

      await pickSpeed(tester, '2.0×');
      await confirmSheet(tester);

      expect(find.text('2.0×'), findsWidgets);
    });

    testWidgets('a voice choice applies from the options sheet', (tester) async {
      await pumpScreen(tester);
      await typeText(tester, text);
      // Reading first, because the voice is named on the *transport bar* —
      // which only exists once there is something being read.
      await tapRead(tester);
      await openSheet(tester);

      await tester.tap(find.text('Bách'));
      await tester.pumpAndSettle();
      await confirmSheet(tester);

      expect(queue.options.voiceId, 'Bách');
      // The transport bar names the voice now in force.
      expect(find.text('Bách'), findsWidgets);
    });

    testWidgets('the app bar and transport bar name and change the voice',
        (tester) async {
      await pumpScreen(tester);
      await typeText(tester, text);
      await tapRead(tester);

      // The voice that is in force (the catalog default) is named in the app
      // bar alongside the speed, so it is visible without opening the sheet.
      expect(find.text('Miên'), findsWidgets);

      // The transport bar's voice label is now a real tap target: tapping it
      // opens the same voice sheet, whose list is every voice the model ships
      // with — i.e. any of the many voices can be chosen from here.
      await tester.tap(find.text('Miên').last);
      await tester.pumpAndSettle();

      expect(find.text('Giọng đọc & tốc độ'), findsOneWidget);
      expect(find.text('Bách'), findsOneWidget);

      await tester.tap(find.text('Bách'));
      await tester.pumpAndSettle();
      await confirmSheet(tester);

      // After the change, the new voice is reflected everywhere it is named.
      expect(find.text('Bách'), findsWidgets);
    });

    testWidgets('a speed change mid-read keeps the current sentence',
        (tester) async {
      await pumpScreen(tester);
      await typeText(tester, text);
      await tapRead(tester);

      await openSheet(tester);
      await pickSpeed(tester, '2.0×');
      await confirmSheet(tester);

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

      await openSheet(tester);
      await pickSpeed(tester, '2.0×');
      await confirmSheet(tester);

      expect(find.text('Đổi giọng đọc?'), findsOneWidget);
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
      expect(find.text('Đổi giọng đọc?'), findsNothing);
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

      await openSheet(tester);
      await pickSpeed(tester, '2.0×');
      await confirmSheet(tester);
      await tester.tap(find.text('Đổi').last);
      await tester.pumpAndSettle();

      expect(find.text('Đổi giọng đọc?'), findsNothing);
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
