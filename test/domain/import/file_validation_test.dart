import 'dart:convert' show utf8;
import 'dart:typed_data' show Uint8List;

import 'package:flutter_test/flutter_test.dart';
import 'package:text_to_voice/core/result/result.dart';
import 'package:text_to_voice/domain/import/file_validation.dart';
import 'package:text_to_voice/domain/models/imported_file.dart' show ImportedFile;

/// Builds the 30-byte ZIP local file header for a **stored** (uncompressed)
/// entry, followed by its name and data — exactly the layout EPUB requires for
/// the first `mimetype` entry.
Uint8List _storedEntry(String name, String data) {
  final nameBytes = utf8.encode(name);
  final dataBytes = utf8.encode(data);
  final header = Uint8List(30);
  header[0] = 0x50; // P
  header[1] = 0x4B; // K
  header[2] = 0x03;
  header[3] = 0x04;
  final size = dataBytes.length;
  header[18] = size & 0xFF;
  header[19] = (size >> 8) & 0xFF;
  header[20] = (size >> 16) & 0xFF;
  header[21] = (size >> 24) & 0xFF;
  header[26] = nameBytes.length & 0xFF;
  header[27] = (nameBytes.length >> 8) & 0xFF;
  return Uint8List.fromList([...header, ...nameBytes, ...dataBytes]);
}

void main() {
  group('ImportValidator epub sniffing', () {
    test('accepts a real EPUB (stored mimetype entry first)', () {
      final head = _storedEntry('mimetype', 'application/epub+zip');
      expect(ImportValidator.sniff(head), isNotNull);

      final file = ImportedFile(
        name: 'book.epub',
        path: '/tmp/book.epub',
        mimeType: 'application/epub+zip',
        size: head.length,
        headBytes: head,
      );
      final result = ImportValidator.validate(file);
      expect(result, isA<Success<ValidatedFile>>());
      expect(result.valueOrNull!.kind, FileKind.epub);
    });

    test('rejects a plain zip renamed to .epub', () {
      final head = _storedEntry('other.txt', 'hello');
      final file = ImportedFile(
        name: 'fake.epub',
        path: '/tmp/fake.epub',
        mimeType: 'application/epub+zip',
        size: head.length,
        headBytes: head,
      );
      final result = ImportValidator.validate(file);
      expect(result, isA<Failure<ValidatedFile>>());
    });

    test('still rejects a binary masquerading as .txt', () {
      final head = Uint8List.fromList(List<int>.filled(64, 0x00));
      final file = ImportedFile(
        name: 'x.txt',
        path: '/tmp/x.txt',
        mimeType: 'text/plain',
        size: head.length,
        headBytes: head,
      );
      expect(ImportValidator.validate(file), isA<Failure<ValidatedFile>>());
    });
  });
}
