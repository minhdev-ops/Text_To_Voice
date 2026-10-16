import 'dart:io';

import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:text_to_voice/data/database/app_database.dart' show AppDatabase;
import 'package:text_to_voice/data/repository/document_repository.dart';
import 'package:text_to_voice/domain/models/document.dart' show DocumentSource;
import 'package:text_to_voice/domain/models/document_block.dart'
    show BlockPosition, BlockType, DocumentBlock;

/// SRS FR-17 §20: search answers *where*, not *which documents*.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late DocumentRepository repository;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('search_test_');
    database = AppDatabase(NativeDatabase(File(p.join(tempDir.path, 't.db'))));
    repository = DocumentRepository(database);
  });

  tearDown(() async {
    await database.close();
    await tempDir.delete(recursive: true);
  });

  DocumentBlock block(
    String id,
    String content, {
    int order = 0,
    int? pageNumber,
  }) =>
      DocumentBlock(
        id: id,
        documentId: 'doc-1',
        type: BlockType.paragraph,
        content: content,
        order: order,
        position: BlockPosition(
          pageNumber: pageNumber,
          left: 0.1,
          top: 0.1,
          width: 0.8,
          height: 0.05,
        ),
        createdAt: DateTime(2026),
      );

  group('search reports a location', () {
    test('finds a term and names the page it was on', () async {
      await repository.createDocument(
        id: 'doc-1',
        name: 'Giáo trình',
        source: DocumentSource.pdf,
        mimeType: 'application/pdf',
        fileSize: 10,
        blocks: <DocumentBlock>[
          block('b0', 'Trang đầu nói về lịch sử.', pageNumber: 1),
          block('b1', 'Chương sau nói về máy học.', order: 1, pageNumber: 5),
        ],
      );

      final results = await repository.search('máy học');

      expect(results.hits, hasLength(1));
      final hit = results.hits.single;
      expect(hit.documentId, 'doc-1');
      expect(hit.documentName, 'Giáo trình');
      // The one number that makes a result findable.
      expect(hit.pageNumber, 5);
      expect(hit.match, 'máy học');
      expect(hit.excerpt, contains('máy học'));
    });

    test('the same term on two pages is two results, not one', () async {
      await repository.createDocument(
        id: 'doc-1',
        name: 'Giáo trình',
        source: DocumentSource.pdf,
        mimeType: 'application/pdf',
        fileSize: 10,
        blocks: <DocumentBlock>[
          block('b0', 'Đoạn đầu nói về học máy.', pageNumber: 2),
          block('b1', 'Đoạn sau lại nói về học máy.', order: 1, pageNumber: 9),
        ],
      );

      final results = await repository.search('học máy');

      expect(results.hits, hasLength(2));
      expect(results.documentCount, 1);
      expect(
        results.hits.map((hit) => hit.pageNumber),
        containsAll(<int>[2, 9]),
      );
    });

    test('a document with no pages reports no page rather than page 1',
        () async {
      // A typed-text document has no pages, and inventing "Page 1" would be a
      // number the app does not know.
      await repository.createDocument(
        id: 'doc-1',
        name: 'Ghi chú',
        source: DocumentSource.typedText,
        mimeType: 'text/plain',
        fileSize: 10,
        blocks: <DocumentBlock>[block('b0', 'Một dòng về bảo mật.')],
      );

      final results = await repository.search('bảo mật');

      expect(results.hits, hasLength(1));
      expect(results.hits.single.pageNumber, isNull);
    });
  });

  group('search matching', () {
    test('finds a term in the document name even with no matching body', () async {
      await repository.createDocument(
        id: 'doc-1',
        name: 'Nguyên lý cơ bản',
        source: DocumentSource.typedText,
        mimeType: 'text/plain',
        fileSize: 10,
        blocks: <DocumentBlock>[block('b0', 'Nội dung không liên quan.')],
      );

      final results = await repository.search('Nguyên lý');

      expect(results.hits, hasLength(1));
      expect(results.hits.single.matchedInTitle, isTrue);
      expect(results.hits.single.match, 'Nguyên lý');
    });

    test('a document matched in its body is not also listed as a title hit',
        () async {
      await repository.createDocument(
        id: 'doc-1',
        name: 'Kinh tế',
        source: DocumentSource.typedText,
        mimeType: 'text/plain',
        fileSize: 10,
        blocks: <DocumentBlock>[block('b0', 'Kinh tế vĩ mô rất quan trọng.')],
      );

      final results = await repository.search('Kinh tế');

      expect(results.hits, hasLength(1));
      expect(results.hits.single.matchedInTitle, isFalse);
    });

    test('a wildcard in the term is a literal, not a pattern', () async {
      // Regression-shaped: with `100%` unescaped, LIKE would read it as "100
      // followed by anything" and return unrelated rows.
      await repository.createDocument(
        id: 'doc-1',
        name: 'A',
        source: DocumentSource.typedText,
        mimeType: 'text/plain',
        fileSize: 10,
        blocks: <DocumentBlock>[block('b0', 'Tăng trưởng đạt 100% năm nay.')],
      );
      await repository.createDocument(
        id: 'doc-2',
        name: 'B',
        source: DocumentSource.typedText,
        mimeType: 'text/plain',
        fileSize: 10,
        blocks: <DocumentBlock>[block('b1', 'Không có con số nào ở đây.')],
      );

      final results = await repository.search('100%');

      expect(results.hits, hasLength(1));
      expect(results.hits.single.documentId, 'doc-1');
    });

    test('an empty term is no search at all', () async {
      await repository.createDocument(
        id: 'doc-1',
        name: 'A',
        source: DocumentSource.typedText,
        mimeType: 'text/plain',
        fileSize: 10,
        blocks: <DocumentBlock>[block('b0', 'Bất cứ điều gì.')],
      );

      expect((await repository.search('   ')).hits, isEmpty);
    });

    test('no match is an empty result, not a failure', () async {
      await repository.createDocument(
        id: 'doc-1',
        name: 'A',
        source: DocumentSource.typedText,
        mimeType: 'text/plain',
        fileSize: 10,
        blocks: <DocumentBlock>[block('b0', 'Nội dung.')],
      );

      final results = await repository.search('không-có-gì-này');
      expect(results.isEmpty, isTrue);
      expect(results.documentCount, 0);
    });
  });

  group('excerpts', () {
    test('the match is separated from its surroundings', () async {
      await repository.createDocument(
        id: 'doc-1',
        name: 'A',
        source: DocumentSource.typedText,
        mimeType: 'text/plain',
        fileSize: 10,
        blocks: <DocumentBlock>[
          block('b0', 'Trước đó có một câu dài. Sau đó từ khoá nằm ở giữa.'),
        ],
      );

      final results = await repository.search('từ khoá');
      final hit = results.hits.single;

      expect(hit.match, 'từ khoá');
      expect(hit.excerptBefore, contains('Trước đó'));
      expect(hit.excerptAfter, contains('nằm ở giữa'));
      // The three pieces reassemble into the original text: the UI renders them
      // as three spans and must not lose or duplicate a character.
      expect(hit.excerpt, 'Trước đó có một câu dài. Sau đó từ khoá nằm ở giữa.');
    });

    test('a long block is clipped around the match, not dumped whole', () async {
      final filler = 'x' * 400;
      await repository.createDocument(
        id: 'doc-1',
        name: 'A',
        source: DocumentSource.typedText,
        mimeType: 'text/plain',
        fileSize: 10,
        blocks: <DocumentBlock>[block('b0', '$filler kìa $filler')],
      );

      final hit = (await repository.search('kìa')).hits.single;

      expect(hit.excerpt.length, lessThan(200));
      expect(hit.match, 'kìa');
    });
  });
}
