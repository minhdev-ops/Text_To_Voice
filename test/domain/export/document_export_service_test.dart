import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:text_to_voice/domain/export/document_export_service.dart';
import 'package:text_to_voice/domain/export/text_exporter.dart';
import 'package:text_to_voice/domain/models/reading.dart';

import '../../support/fake_tts_engine.dart';

void main() {
  const service = DocumentExportService();

  late Directory workspace;
  late Directory out;

  const text = 'Xin chào Việt Nam. Đây là tài liệu thử.\n\nĐoạn thứ hai.';

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('vietdoc_export_');
    out = Directory('${workspace.path}/exports');
  });

  tearDown(() {
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  /// A sentence whose audio really exists on disk.
  Sentence withAudio(int index, String path, {int milliseconds = 500}) => Sentence(
        index: index,
        text: 'Câu số $index.',
        blockId: 'read-aloud',
        audioPath: path,
        durationMs: milliseconds,
      );

  Future<String> writeWav(String name, {int sampleCount = 24000}) async {
    final file = File('${workspace.path}/$name');
    await file.writeAsBytes(buildWav(sampleCount: sampleCount, sampleRate: 24000));
    return file.path;
  }

  group('text artifacts', () {
    test('writes each requested format and reports what it wrote', () async {
      final outcome = await service.export(
        text: text,
        sentences: const <Sentence>[],
        directory: out,
        formats: TextExportFormat.values,
        title: 'Tài liệu thử',
        now: DateTime.utc(2026, 9, 28),
      );

      expect(outcome.isComplete, isTrue);
      expect(outcome.written, hasLength(3));
      expect(outcome.failed, isEmpty);
      expect(outcome.totalBytes, greaterThan(0));

      expect(File('${out.path}/tài-liệu-thử.txt').existsSync(), isTrue);
      expect(File('${out.path}/tài-liệu-thử.md').existsSync(), isTrue);
      expect(File('${out.path}/tài-liệu-thử.json').existsSync(), isTrue);
      expect(outcome.summary, contains('Đã xuất 3 tệp'));
    });

    test('the txt export is the document the user typed', () async {
      await service.export(
        text: text,
        sentences: const <Sentence>[],
        directory: out,
        formats: const <TextExportFormat>[TextExportFormat.txt],
        title: 'Tài liệu thử',
      );

      expect(
        File('${out.path}/tài-liệu-thử.txt').readAsStringSync(),
        '$text\n',
      );
    });

    test('creates the destination directory when it does not exist', () async {
      expect(out.existsSync(), isFalse);

      final outcome = await service.export(
        text: text,
        sentences: const <Sentence>[],
        directory: out,
        formats: const <TextExportFormat>[TextExportFormat.txt],
      );

      expect(outcome.isComplete, isTrue);
      expect(out.existsSync(), isTrue);
    });

    test('no formats and no audio writes nothing, and says so', () async {
      final outcome = await service.export(
        text: text,
        sentences: const <Sentence>[],
        directory: out,
        formats: const <TextExportFormat>[],
      );

      expect(outcome.written, isEmpty);
      expect(outcome.failed, isEmpty);
      expect(outcome.isComplete, isFalse);
    });
  });

  group('audio artifact', () {
    test('joins the sentences into one WAV in reading order', () async {
      final first = await writeWav('a.wav', sampleCount: 24000); // 1s
      final second = await writeWav('b.wav', sampleCount: 12000); // 0.5s

      final outcome = await service.export(
        text: text,
        sentences: <Sentence>[
          withAudio(0, first, milliseconds: 1000),
          withAudio(1, second, milliseconds: 500),
        ],
        directory: out,
        formats: const <TextExportFormat>[TextExportFormat.txt],
        includeAudio: true,
        title: 'Tài liệu thử',
      );

      expect(outcome.isComplete, isTrue, reason: outcome.summary);
      final merged = File('${out.path}/tài-liệu-thử.wav');
      expect(merged.existsSync(), isTrue);

      final bytes = merged.readAsBytesSync();
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      final dataSize =
          bytes[40] | (bytes[41] << 8) | (bytes[42] << 16) | (bytes[43] << 24);
      expect(dataSize, 24000 * 2 + 12000 * 2);
      expect(bytes.length, 44 + dataSize);
      // Text and audio landed together.
      expect(outcome.written.map((a) => a.label), contains('Audio (.wav)'));
    });

    test('a sentence with no audio yet fails only the audio artifact', () async {
      final first = await writeWav('a.wav');

      final outcome = await service.export(
        text: text,
        sentences: <Sentence>[
          withAudio(0, first),
          const Sentence(index: 1, text: 'Câu số 1.', blockId: 'read-aloud'),
        ],
        directory: out,
        formats: const <TextExportFormat>[TextExportFormat.txt],
        includeAudio: true,
        title: 'Tài liệu thử',
      );

      // The text export is untouched, and the audio failure names its cause.
      expect(outcome.written, hasLength(1));
      expect(outcome.failed, hasLength(1));
      expect(outcome.isComplete, isFalse);
      expect(outcome.failed.single.label, 'Audio (.wav)');
      expect(outcome.failed.single.message, contains('1 câu chưa có audio'));
      expect(outcome.summary, 'Đã xuất 1/2 tệp; 1 tệp lỗi.');
      expect(File('${out.path}/tài-liệu-thử.txt').existsSync(), isTrue);
      expect(File('${out.path}/tài-liệu-thử.wav').existsSync(), isFalse,
          reason: 'a half document is not written as if it were whole');
    });

    test('an unreadable audio file is reported with its path', () async {
      final outcome = await service.export(
        text: text,
        sentences: <Sentence>[
          withAudio(0, '${workspace.path}/missing.wav'),
        ],
        directory: out,
        formats: const <TextExportFormat>[],
        includeAudio: true,
        title: 'Tài liệu thử',
      );

      expect(outcome.written, isEmpty);
      expect(outcome.isTotalFailure, isTrue);
      expect(outcome.failed.single.message, contains('câu 1'));
    });

    test('audio is refused when nothing has been synthesized', () async {
      final outcome = await service.export(
        text: text,
        sentences: const <Sentence>[],
        directory: out,
        formats: const <TextExportFormat>[],
        includeAudio: true,
      );

      expect(outcome.failed.single.message, contains('Chưa có câu nào'));
    });

    test('measuredDuration sums only durations that were really measured',
        () async {
      final duration = DocumentExportService.measuredDuration(<Sentence>[
        withAudio(0, 'x', milliseconds: 1500),
        const Sentence(index: 1, text: 'chưa có', blockId: 'read-aloud'),
        withAudio(2, 'y', milliseconds: 500),
      ]);

      expect(duration, const Duration(seconds: 2));
    });
  });

  group('an unusable destination', () {
    test('is reported once, with the real cause', () async {
      // A file where the directory should be: `create()` must fail.
      final blocked = File('${workspace.path}/blocked');
      await blocked.writeAsString('not a directory');

      final outcome = await service.export(
        text: text,
        sentences: const <Sentence>[],
        directory: Directory(blocked.path),
        formats: TextExportFormat.values,
        includeAudio: true,
      );

      expect(outcome.written, isEmpty);
      expect(outcome.failed, hasLength(1));
      expect(outcome.failed.single.label, 'Thư mục xuất');
      expect(outcome.summary, 'Không xuất được tệp nào.');
      expect(outcome.failed.single.message, contains(blocked.path));
    });
  });

  group('injected file reader', () {
    test('lets the merge path be tested without a disk', () async {
      final bytes = buildWav(sampleCount: 4800, sampleRate: 24000);

      final outcome = await service.export(
        text: text,
        sentences: <Sentence>[withAudio(0, 'memory://one.wav')],
        directory: out,
        formats: const <TextExportFormat>[],
        includeAudio: true,
        title: 'Tài liệu thử',
        readFile: (path) async => Uint8List.fromList(bytes),
      );

      expect(outcome.isComplete, isTrue, reason: outcome.summary);
      expect(File('${out.path}/tài-liệu-thử.wav').lengthSync(), 44 + 4800 * 2);
    });
  });
}
