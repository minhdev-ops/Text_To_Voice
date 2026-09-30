import 'dart:io';
import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:text_to_voice/core/theme/app_theme.dart';
import 'package:text_to_voice/domain/export/document_export_service.dart';
import 'package:text_to_voice/domain/export/text_exporter.dart';
import 'package:text_to_voice/domain/models/reading.dart';
import 'package:text_to_voice/domain/speech/sentence_synthesis_queue.dart';
import 'package:text_to_voice/domain/speech/synthesis_cache.dart';
import 'package:text_to_voice/presentation/read_aloud/read_aloud_providers.dart';
import 'package:text_to_voice/presentation/read_aloud/read_aloud_screen.dart';

import '../../support/fake_audio_output.dart';
import '../../support/fake_tts_engine.dart';

/// Records what the UI asked for and returns a canned outcome.
///
/// The widget test's subject is the *surface*: which artifacts it offers, what it
/// says about MP3, and what it hands to the exporter. Writing real files belongs
/// to `test/domain/export/document_export_service_test.dart`, which does it on a
/// real disk — a `testWidgets` zone cannot complete real file I/O, and a test
/// that pretends otherwise is the kind of green that hides bugs.
class _RecordingExportService extends DocumentExportService {
  _RecordingExportService({required this.outcome});

  final ExportOutcome outcome;

  List<TextExportFormat>? requestedFormats;
  bool? requestedAudio;
  int? sentenceCount;
  DateTime? requestedAt;

  @override
  Future<ExportOutcome> export({
    required String text,
    required List<Sentence> sentences,
    required Directory directory,
    required List<TextExportFormat> formats,
    bool includeAudio = false,
    String? title,
    DateTime? now,
    Future<Uint8List> Function(String path)? readFile,
  }) async {
    requestedFormats = formats;
    requestedAudio = includeAudio;
    sentenceCount = sentences.length;
    requestedAt = now;
    return outcome;
  }
}

void main() {
  late Directory workspace;
  late Directory exports;
  late FakeTtsEngine engine;
  late FakeAudioOutput output;
  late SentenceSynthesisQueue queue;
  late _RecordingExportService service;

  const text = 'Câu một. Câu hai. Câu ba.';

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('vietdoc_export_screen_');
    exports = Directory('${workspace.path}/exports');
    // No directory: the engine keeps audio in memory, so synthesis completes
    // inside the test zone and the sheet sees a finished document.
    engine = FakeTtsEngine(millisecondsPerCharacter: 20);
    output = FakeAudioOutput();
    queue = SentenceSynthesisQueue(
      engine: engine,
      cache: InMemorySynthesisCache(),
      lookAhead: 1,
    );
    service = _RecordingExportService(
      outcome: ExportOutcome(
        directory: exports.path,
        written: const <ExportedArtifact>[
          ExportedArtifact(path: 'a.txt', bytes: 10, label: 'Văn bản (.txt)'),
          ExportedArtifact(path: 'a.md', bytes: 20, label: 'Markdown (.md)'),
          ExportedArtifact(path: 'a.json', bytes: 30, label: 'JSON (.json)'),
          ExportedArtifact(path: 'a.wav', bytes: 40, label: 'Audio (.wav)'),
        ],
      ),
    );
  });

  tearDown(() {
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ttsEngineProvider.overrideWithValue(engine),
          sentenceQueueProvider.overrideWithValue(queue),
          audioOutputProvider.overrideWithValue(output),
          exportDirectoryProvider.overrideWithValue(Future<Directory>.value(exports)),
          exportServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ReadAloudScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> startReading(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Đọc thành tiếng'));
    await tester.pumpAndSettle();
  }

  Future<void> openExportSheet(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Xuất tài liệu'));
    await tester.pumpAndSettle();
  }

  /// Scrolls the sheet's confirm button into view and taps it: the sheet is
  /// taller than the test viewport, and an off-screen tap hits nothing.
  Future<void> confirmExport(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Xuất'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xuất'));
    await tester.pumpAndSettle();
  }

  testWidgets('is not offered before there is anything to export',
      (tester) async {
    await pumpScreen(tester);

    expect(find.byTooltip('Xuất tài liệu'), findsNothing);
    expect(find.byTooltip('Sửa văn bản'), findsNothing);
  });

  testWidgets('offers the three text formats and WAV', (tester) async {
    await pumpScreen(tester);
    await startReading(tester);
    await openExportSheet(tester);

    expect(find.text('Văn bản (.txt)'), findsOneWidget);
    expect(find.text('Markdown (.md)'), findsOneWidget);
    expect(find.text('JSON (.json)'), findsOneWidget);
    expect(find.text('Audio (.wav)'), findsOneWidget);
  });

  testWidgets('says why MP3 is not among the choices', (tester) async {
    await pumpScreen(tester);
    await startReading(tester);
    await openExportSheet(tester);

    // FR-15: mp3 only when an encoder exists — so its absence is explained
    // rather than silent.
    expect(find.textContaining('Chưa có bộ mã hoá MP3'), findsOneWidget);
    expect(find.textContaining('MP3 (.mp3)'), findsNothing);
  });

  testWidgets('estimates the audio size from measured durations',
      (tester) async {
    await pumpScreen(tester);
    await startReading(tester);
    await openExportSheet(tester);

    // A real number derived from the durations the engine reported, plus the
    // total duration the file will contain.
    expect(find.textContaining('≈ '), findsOneWidget);
    expect(find.textContaining('MB'), findsOneWidget);
    expect(find.textContaining('đã tạo'), findsOneWidget);
  });

  testWidgets('the audio row is unavailable while nothing has been synthesized',
      (tester) async {
    await pumpScreen(tester);
    await startReading(tester);

    // Replace the reading with a fresh, unsynthesized document.
    await queue.load(text, options: queue.options);
    await tester.pumpAndSettle();
    await openExportSheet(tester);

    expect(find.text('Chưa có câu nào được tạo audio.'), findsOneWidget);
    final audioTile = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Audio (.wav)'),
    );
    expect(audioTile.onChanged, isNull, reason: 'nothing to write yet');
  });

  testWidgets('hands the chosen artifacts to the exporter and reports the path',
      (tester) async {
    await pumpScreen(tester);
    await startReading(tester);
    await openExportSheet(tester);

    await tester.tap(find.text('Markdown (.md)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JSON (.json)'));
    await tester.pumpAndSettle();
    await confirmExport(tester);

    // txt is the default, and the order is the format order, not tap order.
    expect(service.requestedFormats, <TextExportFormat>[
      TextExportFormat.txt,
      TextExportFormat.md,
      TextExportFormat.json,
    ]);
    expect(service.requestedAudio, isTrue);
    expect(service.sentenceCount, 3);
    expect(service.requestedAt, isNotNull);
    // The confirmation names where the files went: the user has to find them.
    expect(find.textContaining(exports.path), findsOneWidget);
    expect(find.textContaining('Đã xuất 4 tệp'), findsOneWidget);
  });

  testWidgets('a partial export states what failed', (tester) async {
    service = _RecordingExportService(
      outcome: ExportOutcome(
        directory: exports.path,
        written: const <ExportedArtifact>[
          ExportedArtifact(path: 'a.txt', bytes: 10, label: 'Văn bản (.txt)'),
        ],
        failed: const <FailedArtifact>[
          FailedArtifact(
            label: 'Audio (.wav)',
            message: 'Còn 1 câu chưa có audio. Đọc hết tài liệu rồi xuất lại.',
          ),
        ],
      ),
    );

    await pumpScreen(tester);
    await startReading(tester);
    await openExportSheet(tester);
    await confirmExport(tester);

    expect(find.textContaining('Đã xuất 1/2 tệp'), findsOneWidget);
    expect(find.textContaining('chưa có audio'), findsOneWidget);
  });

  testWidgets('exporting text alone does not require any audio', (tester) async {
    await pumpScreen(tester);
    await startReading(tester);
    await openExportSheet(tester);

    await tester.tap(find.text('Audio (.wav)'));
    await tester.pumpAndSettle();
    await confirmExport(tester);

    expect(service.requestedAudio, isFalse);
    expect(service.requestedFormats, <TextExportFormat>[TextExportFormat.txt]);
  });
}
