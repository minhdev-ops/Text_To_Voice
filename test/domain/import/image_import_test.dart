import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:text_to_voice/core/result/result.dart';
import 'package:text_to_voice/core/storage/app_storage.dart';
import 'package:text_to_voice/domain/engines/progress.dart' show JobStage;
import 'package:text_to_voice/domain/import/document_importer.dart';
import 'package:text_to_voice/domain/import/import_service.dart';
import 'package:text_to_voice/domain/import/image_extractor.dart';
import 'package:text_to_voice/domain/models/document.dart';
import 'package:text_to_voice/domain/models/extraction.dart' show ExtractionResult;
import 'package:text_to_voice/domain/models/imported_file.dart' show ImportedFile;
import 'package:text_to_voice/domain/models/ocr.dart' show OcrLine;
import 'package:text_to_voice/domain/ocr/ocr_structurer.dart';

import '../../support/fake_ocr_engine.dart';
import '../../support/fake_platform_file.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

/// A 1×1 PNG. Only the magic number matters here: validation reads bytes and OCR
/// is faked, so the pixels are never decoded.
final Uint8List onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  late Directory tempDir;
  late File pngFile;
  late FakeOcrEngine ocr;

  DocumentImporter importerWithOcr() => DocumentImporter(
        importService: ImportService(ocr: ocr, structurer: OcrStructurer()),
      );

  Future<Result<ImportDocumentResult>> importPng() => importerWithOcr()
      .importFile(
        platformFile: FakePlatformFile(
          'trang.png',
          pngFile.readAsBytesSync(),
          localPath: pngFile.path,
        ),
      );

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('ocr_import_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    await AppStorage().initialize();
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    pngFile = File('${tempDir.path}/trang.png');
    await pngFile.writeAsBytes(onePixelPng);
    ocr = FakeOcrEngine(
      lines: <OcrLine>[
        FakeOcrEngine.line('Tiêu đề trang', top: 0.05, height: 0.04),
        FakeOcrEngine.line('Nội dung chữ trong ảnh.', top: 0.2),
      ],
    );
  });

  group('importing an image', () {
    test('runs OCR and returns readable text', () async {
      final result = await importPng();

      expect(result, isA<Success<ImportDocumentResult>>());
      final imported = (result as Success<ImportDocumentResult>).value;
      expect(imported.source, equals(DocumentSource.image));
      expect(imported.hasText, isTrue);
      expect(imported.extractedText, contains('Nội dung chữ trong ảnh.'));
      expect(imported.blocks, isNotEmpty);
      expect(ocr.callCount, 1);
    });

    test('an imported image is one page that came from OCR', () async {
      final imported = (await importPng() as Success<ImportDocumentResult>).value;

      expect(imported.pageCount, 1);
      expect(imported.ocrEngineId, 'fake-ocr');
    });

    test('reading order is gapless so the reader and speech agree', () async {
      final imported = (await importPng() as Success<ImportDocumentResult>).value;

      expect(
        imported.blocks.map((b) => b.order),
        equals(List<int>.generate(imported.blocks.length, (i) => i)),
      );
    });

    test('an image with no text says so, and does not claim a parse failure',
        () async {
      ocr.lines = <OcrLine>[];

      final result = await importPng();

      expect(result, isA<Failure<ImportDocumentResult>>());
      final failure = (result as Failure<ImportDocumentResult>).failure;
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, contains('Không tìm thấy chữ trong ảnh'));
    });

    test('a failed recognition reports the engine failure, not a generic one',
        () async {
      ocr.failure = const ProcessingFailure(message: 'Bộ nhận dạng bị lỗi.');

      final result = await importPng();

      expect(result, isA<Failure<ImportDocumentResult>>());
      expect(
        (result as Failure<ImportDocumentResult>).failure.message,
        'Bộ nhận dạng bị lỗi.',
      );
    });

    test('an engine that is not ready says the model is missing', () async {
      ocr.ready = false;

      final result = await importPng();

      expect(result, isA<Failure<ImportDocumentResult>>());
      expect(
        (result as Failure<ImportDocumentResult>).failure,
        isA<ModelUnavailableFailure>(),
      );
    });

    test('without an OCR engine the failure names what is missing', () async {
      // The bare default: no engine wired, which is what a caller that forgets
      // to inject one gets.
      final result = await const DocumentImporter().importFile(
        platformFile: FakePlatformFile(
          'trang.png',
          onePixelPng,
          localPath: pngFile.path,
        ),
      );

      expect(result, isA<Failure<ImportDocumentResult>>());
      final failure = (result as Failure<ImportDocumentResult>).failure;
      expect(failure, isA<ModelUnavailableFailure>());
      expect(failure.message, contains('bộ nhận dạng chữ'));
    });

    test('progress reaches the caller and ends at 1', () async {
      final reports = <(double, String)>[];

      await importerWithOcr().importFile(
        platformFile: FakePlatformFile(
          'trang.png',
          pngFile.readAsBytesSync(),
          localPath: pngFile.path,
        ),
        onProgress: (value, stage) => reports.add((value, stage)),
      );

      expect(reports, isNotEmpty);
      expect(reports.last.$1, 1);
      expect(reports.last.$2, JobStage.done);
    });
  });

  group('confidence', () {
    test('a clean recognition is not flagged for review', () async {
      ocr.lines = <OcrLine>[
        FakeOcrEngine.line('Dòng chắc chắn.', top: 0.1, confidence: 0.95),
      ];

      final imported = (await importPng() as Success<ImportDocumentResult>).value;

      expect(imported.lowConfidenceCount, 0);
      expect(imported.needsReview, isFalse);
    });

    test('an unsure recognition is counted, not hidden', () async {
      // The measured case from a real device run: every line came back under
      // 50% and the app presented the result as a normal document.
      ocr.lines = <OcrLine>[
        FakeOcrEngine.line('Chss:B Sfot:40C', top: 0.1, confidence: 0.46),
        FakeOcrEngine.line('Hel.0 bar', top: 0.2, confidence: 0.44),
      ];

      final imported = (await importPng() as Success<ImportDocumentResult>).value;

      expect(imported.lowConfidenceCount, 2);
      expect(imported.needsReview, isTrue);
    });

    test('a line the engine scored 85% is not flagged', () async {
      ocr.lines = <OcrLine>[
        FakeOcrEngine.line('Chắc chắn vừa đủ', top: 0.1, confidence: 0.85),
      ];

      final imported = (await importPng() as Success<ImportDocumentResult>).value;

      expect(imported.lowConfidenceCount, 0);
    });

    test('a parsed text file is never flagged — it has no confidence',
        () async {
      final result = await const DocumentImporter().importFile(
        platformFile: FakePlatformFile(
          'banan.txt',
          Uint8List.fromList('Nội dung rõ ràng.'.codeUnits),
          localPath: '${Directory.systemTemp.path}/banan.txt',
        ),
      );

      final imported = (result as Success<ImportDocumentResult>).value;
      expect(imported.lowConfidenceCount, 0);
      expect(imported.needsReview, isFalse);
    });
  });

  group('ImageExtractor', () {
    ImageExtractor extractor() =>
        ImageExtractor(ocr: ocr, structurer: OcrStructurer());

    ImportedFile imported() => ImportedFile(
          name: 'trang.png',
          path: pngFile.path,
          mimeType: 'image/png',
          size: pngFile.lengthSync(),
          headBytes: onePixelPng,
        );

    test('rejects an image outright when the engine is not ready', () async {
      ocr.ready = false;

      final result = await extractor().extract(imported());

      expect(result, isA<Failure>());
      expect((result as Failure).failure, isA<ModelUnavailableFailure>());
    });

    test('reports the page as OCR-derived, not as a text layer', () async {
      final result = await extractor().extract(imported());

      final extraction = (result as Success<ExtractionResult>).value;
      expect(extraction.pages, hasLength(1));
      expect(extraction.pages.single.hasTextLayer, isFalse);
      expect(extraction.pages.single.blockCount, extraction.blocks.length);
    });

    test('the engine is handed the imported file itself, not a copy',
        () async {
      await extractor().extract(imported());

      expect(ocr.received, hasLength(1));
      expect(ocr.received.single.path, pngFile.path);
    });
  });
}
