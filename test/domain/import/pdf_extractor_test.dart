import 'package:flutter_test/flutter_test.dart';

import 'package:text_to_voice/domain/import/pdf_extractor.dart';
import 'package:text_to_voice/domain/import/index.dart';
import 'package:text_to_voice/domain/models/imported_file.dart';
import 'package:text_to_voice/domain/models/extraction.dart';
import 'package:text_to_voice/domain/engines/progress.dart' show JobStage;
import 'package:text_to_voice/core/result/result.dart';

void main() {
  group('PdfExtractor', () {
    late PdfExtractor extractor;

    setUp(() {
      extractor = const PdfExtractor();
    });

    test('has correct ID and supported extensions', () {
      expect(extractor.id, 'pdf');
      expect(extractor.supportedExtensions, equals({'pdf'}));
    });

    test('rejects null file', () async {
      final result = await extractor.extract(
        ImportedFile(
          name: 'test.pdf',
          path: '/fake/path/test.pdf',
          mimeType: 'application/pdf',
          size: 100,
        ),
      );
      
      expect(result, isA<Failure<ExtractionResult>>());
      // Should fail because the file doesn't actually exist
      // In a real test with a mock file system, we'd test successful extraction
    });
  });
}