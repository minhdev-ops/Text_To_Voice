import 'package:collection/collection.dart' show DeepCollectionEquality;
import 'package:flutter/foundation.dart' show immutable;

/// SRS §30 `block_type`. The exhaustive set the structure extractor emits.
enum BlockType {
  title,
  heading,
  paragraph,
  image,
  table,
  list,
  footnote,
  unknown,
}

/// Where a block sits on its page, normalized to 0..1 of the page box.
///
/// Normalized rather than pixel coordinates so the same value renders correctly
/// at any DPI, and so an OCR region can be outlined over the image at any zoom.
@immutable
class BlockPosition {
  const BlockPosition({
    this.pageNumber,
    this.left,
    this.top,
    this.width,
    this.height,
  });

  final int? pageNumber;
  final double? left;
  final double? top;
  final double? width;
  final double? height;

  bool get isComplete =>
      left != null && top != null && width != null && height != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BlockPosition &&
          other.pageNumber == pageNumber &&
          other.left == left &&
          other.top == top &&
          other.width == width &&
          other.height == height);

  @override
  int get hashCode => Object.hash(pageNumber, left, top, width, height);
}

/// One structural unit of a document — SRS §30 `document_blocks`.
///
/// Reading order lives in [order] rather than in list position, because a
/// mixed PDF (text-layer page 1, scanned page 9) is assembled from two
/// different extractors and only an explicit order keeps read-aloud sane.
@immutable
class DocumentBlock {
  const DocumentBlock({
    required this.id,
    required this.documentId,
    required this.type,
    required this.content,
    required this.order,
    this.pageId,
    this.level = 0,
    this.position,
    this.confidence,
    this.createdAt,
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final String documentId;
  final String? pageId;

  final BlockType type;

  /// Heading depth: 1..3 for [BlockType.heading] and [BlockType.title],
  /// 0 for everything else.
  final int level;

  /// Plain text. Images and tables store their caption/alt text here.
  final String content;

  /// Reading order across the whole document, 0-based, gapless.
  final int order;

  final BlockPosition? position;

  /// OCR confidence in 0..1. Null for text extracted from a real text layer,
  /// where there is no uncertainty to report.
  final double? confidence;

  final DateTime? createdAt;

  final Map<String, Object?> metadata;

  bool get isHeading =>
      type == BlockType.title || type == BlockType.heading;

  /// `true` when OCR was not confident enough to trust silently. Rendered with
  /// the `warning` hairline, never a filled block (DESIGN.md → OcrReviewPane).
  bool get isLowConfidence => confidence != null && confidence! < 0.85;

  /// Footnotes, running headers and page furniture are visible in the reader
  /// but skipped during read-aloud (FR-07).
  bool get isSkippedInReadAloud =>
      type == BlockType.footnote ||
      metadata['skip_in_read_aloud'] == true;

  static const Object _unset = Object();

  DocumentBlock copyWith({
    BlockType? type,
    int? level,
    String? content,
    int? order,
    Object? pageId = _unset,
    Object? position = _unset,
    Object? confidence = _unset,
    Map<String, Object?>? metadata,
  }) =>
      DocumentBlock(
        id: id,
        documentId: documentId,
        pageId: identical(pageId, _unset) ? this.pageId : pageId as String?,
        type: type ?? this.type,
        level: level ?? this.level,
        content: content ?? this.content,
        order: order ?? this.order,
        position:
            identical(position, _unset) ? this.position : position as BlockPosition?,
        confidence:
            identical(confidence, _unset) ? this.confidence : confidence as double?,
        createdAt: createdAt,
        metadata: metadata ?? this.metadata,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentBlock &&
          other.id == id &&
          other.documentId == documentId &&
          other.pageId == pageId &&
          other.type == type &&
          other.level == level &&
          other.content == content &&
          other.order == order &&
          other.position == position &&
          other.confidence == confidence &&
          other.createdAt == createdAt &&
          const DeepCollectionEquality().equals(other.metadata, metadata));

  @override
  int get hashCode => Object.hash(
        id,
        documentId,
        pageId,
        type,
        level,
        content,
        order,
        position,
        confidence,
        createdAt,
        const DeepCollectionEquality().hash(metadata),
      );

  @override
  String toString() => 'DocumentBlock($order, $type, ${content.length} chars)';
}
