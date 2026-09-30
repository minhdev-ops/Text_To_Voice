import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:text_to_voice/core/result/result.dart';
import 'package:text_to_voice/core/storage/app_storage.dart';
import 'package:text_to_voice/domain/import/document_importer.dart';
import 'package:text_to_voice/domain/models/document.dart';

import '../../support/fake_platform_file.dart';

/// Points path_provider at this test's temp directory so `AppStorage` can
/// initialize for real without touching the platform channel.
class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  late Directory tempDir;
  late File file;

  setUpAll(() async {
    // `appStorage` is a singleton `main()` normally initializes; the import path
    // reaches for its temp directory whenever a file has no local path, so it is
    // pointed at a real directory here.
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('importer_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    await AppStorage().initialize();

    file = File('${tempDir.path}/banan.txt');
    await file.writeAsString(
      'Câu một.\n\nCâu hai.',
      encoding: utf8,
    );
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  group('DocumentImporter', () {
    test('a plain text file becomes a ready, readable document', () async {
      final result = await const DocumentImporter().importFile(
        platformFile: FakePlatformFile(
          'banan.txt',
          await file.readAsBytes(),
          localPath: file.path,
        ),
      );

      expect(result, isA<Success<ImportDocumentResult>>());
      final imported = (result as Success<ImportDocumentResult>).value;
      expect(imported.source, equals(DocumentSource.textFile));
      expect(imported.hasText, isTrue);
      expect(imported.extractedText, contains('Câu một.'));
      expect(imported.blocks, isNotEmpty);
      // Reading order must be gapless for the reader and read-aloud to agree.
      expect(
        imported.blocks.map((b) => b.order),
        equals(List<int>.generate(imported.blocks.length, (i) => i)),
      );
      expect(imported.name, 'banan');
      // A plain text file was parsed, not recognized: no OCR engine is credited.
      expect(imported.ocrEngineId, isNull);
    });

    test('a file with no local path is materialized, not asserted away',
        () async {
      final result = await const DocumentImporter().importFile(
        platformFile: FakePlatformFile('banan.txt', await file.readAsBytes()),
      );

      expect(result, isA<Success<ImportDocumentResult>>());
      expect(
        (result as Success<ImportDocumentResult>).value.extractedText,
        contains('Câu hai.'),
      );
    });

    test('a binary file renamed to .txt is rejected by content, not by name',
        () async {
      final result = await const DocumentImporter().importFile(
        platformFile: FakePlatformFile(
          'khong-phai-van-ban.txt',
          Uint8List.fromList(List<int>.filled(64, 0)),
          localPath: file.path,
        ),
      );

      expect(result, isA<Failure<ImportDocumentResult>>());
      expect(
        (result as Failure<ImportDocumentResult>).failure.message,
        contains('không phải văn bản đọc được'),
      );
    });

    test('an unsupported extension never reaches an extractor', () async {
      final exe = File('${tempDir.path}/khong-chay.exe');
      await exe.writeAsBytes(<int>[0x4D, 0x5A, 0, 0, 0, 0]);

      final result = await const DocumentImporter().importFile(
        platformFile: FakePlatformFile(
          'khong-chay.exe',
          await exe.readAsBytes(),
          localPath: exe.path,
        ),
      );

      expect(result, isA<Failure<ImportDocumentResult>>());
    });
  });
}
