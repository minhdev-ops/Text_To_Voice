import 'dart:typed_data' show Uint8List;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:text_to_voice/domain/models/document.dart'
    show Document, DocumentSource;
import 'package:text_to_voice/domain/models/document_block.dart'
    show BlockType;
import 'package:text_to_voice/domain/models/structured_block.dart'
    show StructuredBlock;
import 'package:text_to_voice/presentation/library/kept_documents.dart';
import 'package:text_to_voice/presentation/settings/memory_settings.dart';

/// A fixed low-memory mode, so a test does not need a database.
///
/// Overriding the provider is what keeps [LowMemoryMode.build] from scheduling its
/// one restore read — the override never runs the real `build`.
class _FixedLowMemoryMode extends LowMemoryMode {
  _FixedLowMemoryMode(this.value);

  final bool value;

  @override
  bool build() => value;
}

void main() {
  final document = Document(
    id: 'doc-1',
    name: 'Bản chụp',
    source: DocumentSource.camera,
    mimeType: 'text/plain',
    fileSize: 10,
    extractedText: 'Xin chào',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  final blocks = <StructuredBlock>[
    StructuredBlock(order: 0, type: BlockType.paragraph, content: 'a'),
    StructuredBlock(order: 1, type: BlockType.paragraph, content: 'b'),
  ];

  final images = <Uint8List>[
    Uint8List.fromList(List<int>.filled(4096, 7)),
    Uint8List.fromList(List<int>.filled(8192, 9)),
  ];

  group('low-memory mode drops retained page bytes', () {
    test('off: the page images are kept, because nothing claims otherwise', () {
      final container = ProviderContainer(
        overrides: [lowMemoryModeProvider.overrideWith(() => _FixedLowMemoryMode(false))],
      );
      addTearDown(container.dispose);

      final id = container
          .read(keptDocumentsProvider.notifier)
          .add(KeptDocument(document: document, blocks: blocks, pageImages: images));

      final kept = container.read(keptDocumentsProvider.notifier).byId(id)!;
      expect(kept.pageImages, hasLength(2));
      expect(kept.pageCount, 2);
    });

    test('on: the page images are released, the page count is not', () {
      final container = ProviderContainer(
        overrides: [lowMemoryModeProvider.overrideWith(() => _FixedLowMemoryMode(true))],
      );
      addTearDown(container.dispose);

      final id = container
          .read(keptDocumentsProvider.notifier)
          .add(KeptDocument(document: document, blocks: blocks, pageImages: images));

      final kept = container.read(keptDocumentsProvider.notifier).byId(id)!;
      // The megabytes are gone...
      expect(kept.pageImages, isEmpty);
      // ...but the document still knows it was two pages, so the library label
      // does not silently become "1 page" and under-report the capture.
      expect(kept.pageCount, 2);
      // Text and structure are untouched: low-memory mode is not "save less".
      expect(kept.blocks, hasLength(2));
      expect(kept.document.extractedText, 'Xin chào');
    });

    test('on: a document that had no images is stored as-is', () {
      final container = ProviderContainer(
        overrides: [lowMemoryModeProvider.overrideWith(() => _FixedLowMemoryMode(true))],
      );
      addTearDown(container.dispose);

      final id = container.read(keptDocumentsProvider.notifier).add(
            KeptDocument(document: document, blocks: blocks, pageCount: 7),
          );

      final kept = container.read(keptDocumentsProvider.notifier).byId(id)!;
      expect(kept.pageImages, isEmpty);
      expect(kept.pageCount, 7);
    });
  });

  group('KeptDocument.pageCount', () {
    test('defaults to the image count, and to 1 when there are none', () {
      expect(
        KeptDocument(document: document, blocks: blocks, pageImages: images)
            .pageCount,
        2,
      );
      expect(KeptDocument(document: document, blocks: blocks).pageCount, 1);
    });

    test('an explicit count survives having no images', () {
      // The whole reason pageCount is a field rather than a getter over
      // `pageImages.length`: these two must be allowed to disagree.
      final kept = KeptDocument(
        document: document,
        blocks: blocks,
        pageCount: 12,
      );
      expect(kept.pageCount, 12);
      expect(kept.pageImages, isEmpty);
    });
  });
}
