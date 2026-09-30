import 'package:flutter_test/flutter_test.dart';

import 'package:text_to_voice/domain/models/document.dart';
import 'package:text_to_voice/domain/models/document_block.dart';
import 'package:text_to_voice/domain/models/extraction.dart';
import 'package:text_to_voice/domain/models/ocr.dart';
import 'package:text_to_voice/domain/models/reading.dart';
import 'package:text_to_voice/domain/models/structured_block.dart';
import 'package:text_to_voice/domain/models/tts.dart';

Document _doc() => Document(
      id: 'doc-1',
      name: 'Áp phích',
      source: DocumentSource.pdf,
      mimeType: 'application/pdf',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
      status: DocumentStatus.ready,
      extractedText: 'Xin chào Việt Nam',
      filePath: '/data/doc-1/document.pdf',
    );

void main() {
  group('Document', () {
    test('has value equality', () {
      expect(_doc(), _doc());
      expect(_doc().hashCode, _doc().hashCode);
      expect(_doc(), isNot(_doc().copyWith(name: 'Khác')));
    });

    test('copyWith can clear a nullable field to null', () {
      final cleared = _doc().copyWith(extractedText: null, filePath: null);
      expect(cleared.extractedText, isNull);
      expect(cleared.filePath, isNull);
      // Fields that were not named survive.
      expect(cleared.name, 'Áp phích');
      expect(cleared.id, 'doc-1');
    });

    test('copyWith without a name leaves it untouched', () {
      expect(_doc().copyWith(status: DocumentStatus.ready).name, 'Áp phích');
    });

    test('hasText and isProcessing reflect the status honestly', () {
      expect(_doc().hasText, isTrue);
      expect(
        _doc().copyWith(extractedText: '   ').hasText,
        isFalse,
        reason: 'whitespace-only is not text',
      );
      expect(_doc().isProcessing, isFalse);
      expect(_doc().copyWith(status: DocumentStatus.ocr).isProcessing, isTrue);
      expect(
        _doc().copyWith(status: DocumentStatus.ready).isProcessing,
        isFalse,
      );
    });
  });

  group('DocumentBlock', () {
    test('low confidence and read-aloud skipping are derived, not stored', () {
      final footnote = DocumentBlock(
        id: 'b1',
        documentId: 'doc-1',
        type: BlockType.footnote,
        content: '1 Xem thêm.',
        order: 0,
        confidence: 0.72,
      );
      expect(footnote.isLowConfidence, isTrue);
      expect(footnote.isSkippedInReadAloud, isTrue);

      final heading = DocumentBlock(
        id: 'b2',
        documentId: 'doc-1',
        type: BlockType.heading,
        level: 2,
        content: 'Phương pháp',
        order: 1,
        confidence: 0.99,
      );
      expect(heading.isHeading, isTrue);
      expect(heading.isLowConfidence, isFalse);
      expect(heading.isSkippedInReadAloud, isFalse);
    });
  });

  group('ExtractionResult', () {
    ExtractionResult makeResult() => ExtractionResult(
          blocks: const <StructuredBlock>[
            StructuredBlock(
                type: BlockType.title, content: 'Tài liệu', order: 0),
            StructuredBlock(
                type: BlockType.paragraph, content: 'Đoạn một.', order: 1),
            StructuredBlock(
                type: BlockType.heading,
                level: 1,
                content: 'Mục 1',
                order: 2),
          ],
          pages: const <ExtractedPage>[
            ExtractedPage(pageNumber: 1, hasTextLayer: true, blockCount: 3),
            ExtractedPage(pageNumber: 2, hasTextLayer: false),
            ExtractedPage(pageNumber: 3, hasTextLayer: false),
          ],
        );

    test('text and outline are derived from blocks', () {
      final r = makeResult();
      expect(r.text, 'Tài liệu\n\nĐoạn một.\n\nMục 1');
      expect(r.outline.map((b) => b.content), ['Tài liệu', 'Mục 1']);
    });

    test('page summary reports the honest per-page split', () {
      expect(makeResult().pageSummary, '1 trang có text · 2 trang chạy OCR');
      expect(makeResult().textPageCount, 1);
      expect(makeResult().ocrPageCount, 2);
    });

    test('empty extraction produces empty text, not "null"', () {
      const empty = ExtractionResult(blocks: []);
      expect(empty.isEmpty, isTrue);
      expect(empty.text, '');
      expect(empty.pageSummary, '');
    });
  });

  group('OcrResult', () {
    test('text is derived from lines so the two cannot disagree', () {
      final r = OcrResult(lines: const <OcrLine>[
        OcrLine(text: 'Xin chào', confidence: 0.98),
        OcrLine(text: 'Việt Nam', confidence: 0.61),
      ]);
      expect(r.text, 'Xin chào\nViệt Nam');
      expect(r.isEmpty, isFalse);
      expect(r.lowConfidenceLines, hasLength(1));
      expect(r.averageConfidence, closeTo(0.795, 0.001));
    });

    test('empty result is detected', () {
      expect(const OcrResult(lines: []).isEmpty, isTrue);
    });
  });

  group('TtsOptions', () {
    test('speed presets match FR-10 exactly', () {
      expect(TtsOptions.speedPresets, [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]);
    });

    test('speed and volume are clamped', () {
      const o = TtsOptions();
      expect(o.copyWith(speed: 99).speed, 2.0);
      expect(o.copyWith(speed: 0.1).speed, 0.5);
      expect(o.copyWith(volume: 5).volume, 1.0);
      expect(o.copyWith(volume: -1).volume, 0.0);
    });

    test('cache key changes with speed so stale audio is never reused', () {
      const a = TtsOptions(speed: 1.0);
      const b = TtsOptions(speed: 1.5);
      expect(a.cacheKey('xin chào'), isNot(b.cacheKey('xin chào')));
      expect(a.cacheKey('xin chào'), a.cacheKey('xin chào'));
    });
  });

  group('Sentence', () {
    test('status transitions produce a new instance', () {
      const s = Sentence(index: 0, text: 'Một.', blockId: 'b1');
      final playing = s.copyWith(status: SentenceStatus.playing);

      expect(playing.status, SentenceStatus.playing);
      expect(s.status, SentenceStatus.idle, reason: 'original must be untouched');
      expect(identical(s, playing), isFalse);
    });

    test('a failed sentence keeps its real cause', () {
      const s = Sentence(index: 0, text: 'Hai.', blockId: 'b1');
      final failed = s.copyWith(
        status: SentenceStatus.failed,
        failureMessage: 'Model chưa được cài đặt.',
      );
      expect(failed.failureMessage, 'Model chưa được cài đặt.');
      expect(failed.hasAudio, isFalse);
    });
  });

  group('ReadingPosition', () {
    test('resume point survives a round trip', () {
      final p = ReadingPosition(
        documentId: 'doc-1',
        pageNumber: 17,
        blockId: 'b4',
        sentenceIndex: 3,
        positionMs: 1240,
        updatedAt: fixed,
      );
      expect(p.copyWith(positionMs: 0).positionMs, 0);
      expect(p.copyWith(positionMs: 0).sentenceIndex, 3);
      expect(
        ReadingPosition.initial('doc-1', fixed).sentenceIndex,
        0,
      );
    });
  });
}

// `DateTime` has no const constructor, so this is `final`.
final DateTime fixed = DateTime.utc(2026, 1, 1);
