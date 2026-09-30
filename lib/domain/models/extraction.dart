import 'package:collection/collection.dart' show DeepCollectionEquality;
import 'package:flutter/foundation.dart' show immutable;

import 'structured_block.dart' show StructuredBlock;
import 'document_image.dart' show DocumentImage;

/// Per-page facts discovered while parsing — SRS §41 mixed-PDF branch.
@immutable
class ExtractedPage {
  const ExtractedPage({
    required this.pageNumber,
    this.width = 0,
    this.height = 0,
    required this.hasTextLayer,
    this.renderedImagePath,
    this.blockCount = 0,
  });

  final int pageNumber;
  final int width;
  final int height;

  /// `true` → parser path, `false` → render + OCR. Decided **per page**, not
  /// per document, so a PDF with a text-layer cover and scanned appendices
  /// routes each page correctly.
  final bool hasTextLayer;

  /// Present only for rendered pages; released after OCR (NFR-04).
  final String? renderedImagePath;

  final int blockCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExtractedPage &&
          other.pageNumber == pageNumber &&
          other.width == width &&
          other.height == height &&
          other.hasTextLayer == hasTextLayer &&
          other.renderedImagePath == renderedImagePath &&
          other.blockCount == blockCount);

  @override
  int get hashCode => Object.hash(
      pageNumber, width, height, hasTextLayer, renderedImagePath, blockCount);

  @override
  String toString() =>
      'ExtractedPage($pageNumber, textLayer=$hasTextLayer)';
}

/// Output of one `DocumentExtractor.extract` call — SRS §28.
///
/// Text, structure, images and pages all come back together because FR-16
/// "Extract All" needs exactly this package, and because reading it twice from
/// disk would be both slower and a second source of truth.
@immutable
class ExtractionResult {
  const ExtractionResult({
    required this.blocks,
    this.pages = const <ExtractedPage>[],
    this.images = const <DocumentImage>[],
    this.title,
    this.detectedLanguage,
    this.elapsed,
  });

  /// Structural units in **reading order** (gapless `order` values).
  final List<StructuredBlock> blocks;

  final List<ExtractedPage> pages;
  final List<DocumentImage> images;

  final String? title;
  final String? detectedLanguage;
  final Duration? elapsed;

  /// Full text, derived from [blocks] in reading order. Never stored twice.
  String get text => blocks.isEmpty
      ? ''
      : blocks.map((block) => block.content).join('\n\n');

  bool get isEmpty => text.trim().isEmpty;

  /// Document outline for FR-07 — also derived, so the outline and the reader
  /// can never drift apart.
  List<StructuredBlock> get outline =>
      blocks.where((b) => b.isHeading).toList(growable: false);

  int get textPageCount => pages.where((p) => p.hasTextLayer).length;
  int get ocrPageCount => pages.where((p) => !p.hasTextLayer).length;

  /// The honest per-page report the UI shows, e.g.
  /// `12 trang có text · 3 trang chạy OCR`.
  String get pageSummary {
    if (pages.isEmpty) return '';
    final text = textPageCount;
    final ocr = ocrPageCount;
    final parts = <String>[
      if (text > 0) '$text trang có text',
      if (ocr > 0) '$ocr trang chạy OCR',
    ];
    return parts.join(' · ');
  }

  ExtractionResult copyWith({
    List<StructuredBlock>? blocks,
    List<ExtractedPage>? pages,
    List<DocumentImage>? images,
    Object? title = _unset,
    Object? detectedLanguage = _unset,
  }) =>
      ExtractionResult(
        blocks: blocks ?? this.blocks,
        pages: pages ?? this.pages,
        images: images ?? this.images,
        title: identical(title, _unset) ? this.title : title as String?,
        detectedLanguage: identical(detectedLanguage, _unset)
            ? this.detectedLanguage
            : detectedLanguage as String?,
        elapsed: elapsed,
      );

  static const Object _unset = Object();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExtractionResult &&
          const DeepCollectionEquality().equals(other.blocks, blocks) &&
          const DeepCollectionEquality().equals(other.pages, pages) &&
          const DeepCollectionEquality().equals(other.images, images) &&
          other.title == title &&
          other.detectedLanguage == detectedLanguage &&
          other.elapsed == elapsed);

  @override
  int get hashCode => Object.hash(
        const DeepCollectionEquality().hash(blocks),
        const DeepCollectionEquality().hash(pages),
        const DeepCollectionEquality().hash(images),
        title,
        detectedLanguage,
        elapsed,
      );

  @override
  String toString() =>
      'ExtractionResult(${blocks.length} blocks, ${pages.length} pages, '
      '${images.length} images)';
}
