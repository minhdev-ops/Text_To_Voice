import 'dart:io';

import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:text_to_voice/data/database/app_database.dart' show AppDatabase;
import 'package:text_to_voice/data/repository/document_repository.dart';
import 'package:text_to_voice/domain/models/document.dart';
import 'package:text_to_voice/domain/models/document_block.dart';
import 'package:text_to_voice/domain/models/document_image.dart';
import 'package:text_to_voice/domain/models/reading.dart';
import 'package:text_to_voice/domain/models/tts.dart';

void main() {
  group('DocumentRepository', () {
    late AppDatabase database;
    late DocumentRepository repository;
    late Directory tempDir;

    setUpAll(() async {
      // Initialize path_provider for testing
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('test_db_');
      final dbFile = File(p.join(tempDir.path, 'test.db'));
      database = AppDatabase(NativeDatabase(dbFile));
      repository = DocumentRepository(database);
    });

    tearDown(() async {
      await database.close();
      await tempDir.delete(recursive: true);
    });

    test('create and retrieve document', () async {
      const id = 'test-doc-1';
      const name = 'Test Document';

      await repository.createDocument(
        id: id,
        name: name,
        source: DocumentSource.typedText,
        mimeType: 'text/plain',
        fileSize: 100,
        extractedText: 'Test content',
      );

      final doc = await repository.getDocumentWithData(id);
      expect(doc, isNotNull);
      expect(doc!.document.id, equals(id));
      expect(doc.document.name, equals(name));
      expect(doc.document.source, equals(DocumentSource.typedText));
      expect(doc.document.extractedText, equals('Test content'));
      expect(doc.document.hasText, isTrue);
    });

    test('a created document is ready to read, not stuck in the queue', () async {
      // Regression: `createDocument` hard-coded `queued`, so every imported file
      // showed "Đang xử lý" forever and refused to open.
      await repository.createDocument(
        id: 'ready-1',
        name: 'Imported',
        source: DocumentSource.textFile,
        mimeType: 'text/plain',
        fileSize: 12,
        extractedText: 'Xin chào.',
      );

      final doc = await repository.getDocumentById('ready-1');
      expect(doc!.status, equals(DocumentStatus.ready));
      expect(doc.isProcessing, isFalse);
    });

    test('a queued document can still be created explicitly', () async {
      await repository.createDocument(
        id: 'queued-1',
        name: 'Enqueued',
        source: DocumentSource.image,
        mimeType: 'image/png',
        fileSize: 10,
        status: DocumentStatus.queued,
      );

      final doc = await repository.getDocumentById('queued-1');
      expect(doc!.status, equals(DocumentStatus.queued));
    });

    test('update document status', () async {
      const id = 'test-doc-2';

      await repository.createDocument(
        id: id,
        name: 'Test',
        source: DocumentSource.pdf,
        mimeType: 'application/pdf',
        fileSize: 200,
      );

      await repository.updateStatus(id, DocumentStatus.extracting);
      var doc = await repository.getDocumentWithData(id);
      expect(doc!.document.status, equals(DocumentStatus.extracting));

      await repository.updateStatus(id, DocumentStatus.ready);
      doc = await repository.getDocumentWithData(id);
      expect(doc!.document.status, equals(DocumentStatus.ready));
    });

    test('toggle favorite', () async {
      const id = 'test-doc-3';

      await repository.createDocument(
        id: id,
        name: 'Test',
        source: DocumentSource.image,
        mimeType: 'image/png',
        fileSize: 300,
      );

      var doc = await repository.getDocumentWithData(id);
      expect(doc!.document.isFavorite, isFalse);

      await repository.toggleFavorite(id, true);
      doc = await repository.getDocumentWithData(id);
      expect(doc!.document.isFavorite, isTrue);

      await repository.toggleFavorite(id, false);
      doc = await repository.getDocumentWithData(id);
      expect(doc!.document.isFavorite, isFalse);
    });

    test('rename document', () async {
      const id = 'test-doc-4';

      await repository.createDocument(
        id: id,
        name: 'Original Name',
        source: DocumentSource.textFile,
        mimeType: 'text/plain',
        fileSize: 50,
      );

      await repository.renameDocument(id, 'New Name');
      final doc = await repository.getDocumentWithData(id);
      expect(doc!.document.name, equals('New Name'));
    });

    test('set category', () async {
      const id = 'test-doc-5';

      await repository.createDocument(
        id: id,
        name: 'Test',
        source: DocumentSource.camera,
        mimeType: 'image/jpeg',
        fileSize: 400,
      );

      await repository.setCategory(id, 'Work');
      var doc = await repository.getDocumentWithData(id);
      expect(doc!.document.category, equals('Work'));

      await repository.setCategory(id, null);
      doc = await repository.getDocumentWithData(id);
      expect(doc!.document.category, isNull);
    });

    test('delete document', () async {
      const id = 'test-doc-6';

      await repository.createDocument(
        id: id,
        name: 'To Delete',
        source: DocumentSource.epub,
        mimeType: 'application/epub+zip',
        fileSize: 500,
      );

      await repository.deleteDocument(id);
      final doc = await repository.getDocumentWithData(id);
      expect(doc, isNull);
    });

    test('reading position persistence', () async {
      const id = 'test-doc-7';

      await repository.createDocument(
        id: id,
        name: 'Test',
        source: DocumentSource.markdown,
        mimeType: 'text/markdown',
        fileSize: 600,
        extractedText: 'Content',
      );

      final position = ReadingPosition(
        documentId: id,
        pageNumber: 1,
        blockId: 'block-1',
        sentenceIndex: 5,
        positionMs: 12000,
        updatedAt: DateTime.now(),
      );

      await repository.saveReadingPosition(position);
      final saved = await repository.getReadingPosition(id);

      expect(saved, isNotNull);
      expect(saved!.documentId, equals(id));
      expect(saved.pageNumber, equals(1));
      expect(saved.blockId, equals('block-1'));
      expect(saved.sentenceIndex, equals(5));
      expect(saved.positionMs, equals(12000));
    });

    test('settings persistence', () async {
      await repository.setSetting('test_key', 'test_value');
      final value = await repository.getSetting('test_key');
      expect(value, equals('test_value'));

      await repository.deleteSetting('test_key');
      final deleted = await repository.getSetting('test_key');
      expect(deleted, isNull);
    });

    test('document with blocks and images', () async {
      const id = 'test-doc-8';

      final blocks = [
        DocumentBlock(
          id: 'block-1',
          documentId: id,
          type: BlockType.title,
          level: 1,
          content: 'Test Title',
          order: 0,
        ),
        DocumentBlock(
          id: 'block-2',
          documentId: id,
          type: BlockType.paragraph,
          content: 'Test paragraph content.',
          order: 1,
        ),
      ];

      final images = [
        DocumentImage(
          id: 'img-1',
          documentId: id,
          sourceType: ImageSourceType.embedded,
          filePath: '/fake/path/image1.png',
          format: 'png',
          width: 800,
          height: 600,
          fileSize: 50000,
          createdAt: DateTime.now(),
        ),
      ];

      await repository.createDocument(
        id: id,
        name: 'With Blocks',
        source: DocumentSource.pdf,
        mimeType: 'application/pdf',
        fileSize: 1000,
        blocks: blocks,
        images: images,
      );

      final doc = await repository.getDocumentWithData(id);
      expect(doc, isNotNull);
      expect(doc!.blocks.length, equals(2));
      expect(doc.images.length, equals(1));
      expect(doc.blocks[0].type, equals(BlockType.title));
      expect(doc.blocks[1].type, equals(BlockType.paragraph));
      expect(doc.images[0].format, equals('png'));
    });

    test('get documents with filters', () async {
      await repository.createDocument(
        id: 'filter-1',
        name: 'Doc A',
        source: DocumentSource.pdf,
        mimeType: 'application/pdf',
        fileSize: 100,
        category: 'Work',
      );

      await repository.createDocument(
        id: 'filter-2',
        name: 'Doc B',
        source: DocumentSource.image,
        mimeType: 'image/png',
        fileSize: 200,
        category: 'Personal',
      );

      await repository.createDocument(
        id: 'filter-3',
        name: 'Doc C',
        source: DocumentSource.camera,
        mimeType: 'image/jpeg',
        fileSize: 300,
        category: 'Work',
      );

      await repository.toggleFavorite('filter-1', true);
      await repository.updateStatus('filter-2', DocumentStatus.failed);

      // Filter by category
      final workDocs = await repository.getDocuments(category: 'Work');
      expect(workDocs.length, equals(2));

      // Filter by favorite
      final favDocs = await repository.getDocuments(isFavorite: true);
      expect(favDocs.length, equals(1));

      // Filter by status
      final failedDocs = await repository.getDocuments(status: DocumentStatus.failed);
      expect(failedDocs.length, equals(1));

      // Filter by source
      final pdfDocs = await repository.getDocuments(source: DocumentSource.pdf);
      expect(pdfDocs.length, equals(1));
    });

    test('document count and storage usage', () async {
      await repository.createDocument(
        id: 'count-1',
        name: 'Doc 1',
        source: DocumentSource.typedText,
        mimeType: 'text/plain',
        fileSize: 100,
      );

      await repository.createDocument(
        id: 'count-2',
        name: 'Doc 2',
        source: DocumentSource.typedText,
        mimeType: 'text/plain',
        fileSize: 200,
      );

      final count = await repository.getDocumentCount();
      expect(count, greaterThanOrEqualTo(2));

      final usage = await repository.getStorageUsage();
      expect(usage, greaterThanOrEqualTo(300));
    });
  });
}