import 'package:flutter_test/flutter_test.dart';

import 'package:text_to_voice/domain/models/document_block.dart';
import 'package:text_to_voice/domain/models/document_image.dart';
import 'package:text_to_voice/domain/models/reading.dart';
import 'package:text_to_voice/presentation/read_aloud/reading_view.dart';

/// Where a scanned page's image belongs in the reading flow.
///
/// Images used to be stored and never shown; the placement rule is what makes
/// them part of the document instead of an attachment, so it is worth pinning
/// exactly — including the cases where the honest answer is "at the end".
void main() {
  const documentId = 'doc-1';

  Sentence sentence(int index, int paragraph) => Sentence(
        index: index,
        text: 'câu $index',
        blockId: 'read-aloud',
        paragraph: paragraph,
      );

  DocumentBlock block(int order, {int? page}) => DocumentBlock(
        id: 'b$order',
        documentId: documentId,
        type: BlockType.paragraph,
        content: 'nội dung $order',
        order: order,
        pageId: page == null ? null : '$documentId-p$page',
        position: page == null ? null : BlockPosition(pageNumber: page),
      );

  DocumentImage image(String id, {int? page}) => DocumentImage(
        id: id,
        documentId: documentId,
        sourceType: ImageSourceType.camera,
        filePath: '/tmp/$id.png',
        format: 'png',
        pageNumber: page,
      );

  List<ReadingImageSlot> slots({
    required List<Sentence> sentences,
    required List<DocumentBlock> blocks,
    required List<DocumentImage> images,
  }) =>
      readingImageSlots(
        sentences: sentences,
        blocks: blocks,
        images: images,
        documentId: documentId,
      );

  test('no images means no slots', () {
    expect(
      slots(
        sentences: <Sentence>[sentence(0, 0)],
        blocks: <DocumentBlock>[block(0, page: 1)],
        images: const <DocumentImage>[],
      ),
      isEmpty,
    );
  });

  test('a two-page document puts each image after its own page', () {
    // Page 1 contributes two paragraphs, page 2 one: the image of page 1 must
    // sit after paragraph 1 (not 0), and page 2's after paragraph 2.
    final result = slots(
      sentences: <Sentence>[
        sentence(0, 0),
        sentence(1, 1),
        sentence(2, 2),
      ],
      blocks: <DocumentBlock>[
        block(0, page: 1),
        block(1, page: 1),
        block(2, page: 2),
      ],
      images: <DocumentImage>[
        image('img-0', page: 1),
        image('img-1', page: 2),
      ],
    );

    expect(result, hasLength(2));
    expect(result[0].image.id, 'img-0');
    expect(result[0].afterParagraph, 1);
    expect(result[1].image.id, 'img-1');
    expect(result[1].afterParagraph, 2);
  });

  test('the page id is read when the block carries no position', () {
    // `position` is often absent on a page whose text came from a parser; the
    // repository still derives `page_id` from it, so the id is the fallback.
    final result = slots(
      sentences: <Sentence>[sentence(0, 0), sentence(1, 1)],
      blocks: <DocumentBlock>[block(0, page: 1), block(1, page: 2)],
      images: <DocumentImage>[image('img-1', page: 2)],
    );

    expect(result.single.afterParagraph, 1);
  });

  test('an image from a page with no text goes to the end', () {
    // A scanned page whose OCR produced nothing: the picture still belongs to
    // the document, and the end is the only position that is not a guess.
    final result = slots(
      sentences: <Sentence>[sentence(0, 0)],
      blocks: <DocumentBlock>[block(0, page: 1)],
      images: <DocumentImage>[
        image('img-0', page: 1),
        image('img-2', page: 3),
      ],
    );

    expect(result, hasLength(2));
    expect(result[0].afterParagraph, 0);
    expect(result[1].afterParagraph, 0);
  });

  test('text edited after capture puts every image at the end', () {
    // Three paragraphs of speech but two blocks: the two structures disagree,
    // and no image position derived from them could be trusted.
    final result = slots(
      sentences: <Sentence>[
        sentence(0, 0),
        sentence(1, 1),
        sentence(2, 2),
      ],
      blocks: <DocumentBlock>[block(0, page: 1), block(1, page: 2)],
      images: <DocumentImage>[image('img-0', page: 1)],
    );

    expect(result.single.afterParagraph, 2);
  });

  test('an image with no page number goes to the end', () {
    final result = slots(
      sentences: <Sentence>[sentence(0, 0)],
      blocks: <DocumentBlock>[block(0, page: 1)],
      images: <DocumentImage>[image('img-x')],
    );

    expect(result.single.afterParagraph, 0);
  });

  test('page ids only parse for this document', () {
    expect(pageNumberOf('doc-1-p7', 'doc-1'), 7);
    expect(pageNumberOf('doc-1-p7', 'doc-2'), isNull);
    expect(pageNumberOf('doc-1-b7', 'doc-1'), isNull);
    expect(pageNumberOf(null, 'doc-1'), isNull);
  });
}
