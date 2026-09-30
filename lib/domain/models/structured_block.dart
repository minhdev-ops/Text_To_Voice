import 'package:flutter/foundation.dart' show immutable;

import 'document_block.dart' show BlockPosition, BlockType, DocumentBlock;

/// A structural unit *before* it belongs to a stored document.
///
/// Extractors and the OCR structurer produce these; the storage layer assigns
/// ids and turns them into [DocumentBlock]s. The split exists because a parser
/// has no business inventing document ids or timestamps — and because Phase 3's
/// PDF reader has to assemble blocks from two different sources (a text layer and
/// OCR'd pages) before any of them can be persisted.
@immutable
class StructuredBlock {
  const StructuredBlock({
    required this.type,
    required this.content,
    required this.order,
    this.level = 0,
    this.position,
    this.confidence,
    this.metadata = const <String, Object?>{},
  });

  final BlockType type;

  /// Plain text. Images and tables carry their caption/alt text here.
  final String content;

  /// Reading order across the whole document, 0-based and gapless by the time
  /// the document is assembled.
  final int order;

  /// Heading depth 1..3 for [BlockType.heading] and [BlockType.title].
  final int level;

  /// Normalized (0..1) position within its page, when the source knew one.
  final BlockPosition? position;

  /// OCR confidence 0..1. Null for a real text layer, where there is no
  /// uncertainty to report.
  final double? confidence;

  final Map<String, Object?> metadata;

  bool get isHeading =>
      type == BlockType.title || type == BlockType.heading;

  /// Visible in the reader, skipped during read-aloud (FR-07).
  bool get isSkippedInReadAloud =>
      type == BlockType.footnote ||
      metadata['skip_in_read_aloud'] == true;

  bool get isLowConfidence => confidence != null && confidence! < 0.85;

  StructuredBlock copyWith({
    BlockType? type,
    String? content,
    int? order,
    int? level,
    BlockPosition? position,
    double? confidence,
    Map<String, Object?>? metadata,
  }) =>
      StructuredBlock(
        type: type ?? this.type,
        content: content ?? this.content,
        order: order ?? this.order,
        level: level ?? this.level,
        position: position ?? this.position,
        confidence: confidence ?? this.confidence,
        metadata: metadata ?? this.metadata,
      );

  /// Materializes this draft into a stored block.
  ///
  /// [id] and [createdAt] are supplied by the caller that owns identity, so a
  /// re-import cannot silently reuse a previous run's ids.
  DocumentBlock toDocumentBlock({
    required String id,
    required String documentId,
    String? pageId,
    DateTime? createdAt,
  }) =>
      DocumentBlock(
        id: id,
        documentId: documentId,
        pageId: pageId,
        type: type,
        level: level,
        content: content,
        order: order,
        position: position,
        confidence: confidence,
        createdAt: createdAt,
        metadata: metadata,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StructuredBlock &&
          other.type == type &&
          other.content == content &&
          other.order == order &&
          other.level == level &&
          other.position == position &&
          other.confidence == confidence &&
          other.metadata.length == metadata.length &&
          other.metadata.keys.every((key) => other.metadata[key] == metadata[key]));

  @override
  int get hashCode => Object.hash(type, content, order, level, position, confidence);

  @override
  String toString() =>
      'StructuredBlock($order, $type, ${content.length} chars)';
}
