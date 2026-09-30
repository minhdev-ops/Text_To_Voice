import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show immutable;

/// SRS §31 `source_type`.
enum ImageSourceType {
  /// Pulled out of a PDF container by FR-06.
  embedded,

  /// A rendered-and-OCR'd page.
  ocrPage,

  /// Taken with the camera (FR-03).
  camera,

  /// Picked from the gallery (FR-02).
  imported,
}

/// An image belonging to a document — SRS §31 `document_images`.
@immutable
class DocumentImage {
  const DocumentImage({
    required this.id,
    required this.documentId,
    required this.sourceType,
    required this.filePath,
    required this.format,
    this.pageId,
    this.pageNumber,
    this.width = 0,
    this.height = 0,
    this.fileSize = 0,
    this.createdAt,
  });

  final String id;
  final String documentId;
  final String? pageId;

  /// 1-based page the image came from. Null for a standalone camera capture
  /// that has no page concept yet.
  final int? pageNumber;

  final ImageSourceType sourceType;

  /// Path inside app-private storage.
  final String filePath;

  final int width;
  final int height;

  /// Lowercase without the dot: `png`, `jpg`, `webp`.
  final String format;

  final int fileSize;

  final DateTime? createdAt;

  double get aspectRatio =>
      (height == 0) ? 1 : (width / height).clamp(0.01, 100.0);

  static const Object _unset = Object();

  DocumentImage copyWith({
    int? width,
    int? height,
    int? fileSize,
    Object? pageNumber = _unset,
    Object? createdAt = _unset,
  }) =>
      DocumentImage(
        id: id,
        documentId: documentId,
        pageId: pageId,
        pageNumber:
            identical(pageNumber, _unset) ? this.pageNumber : pageNumber as int?,
        sourceType: sourceType,
        filePath: filePath,
        width: width ?? this.width,
        height: height ?? this.height,
        format: format,
        fileSize: fileSize ?? this.fileSize,
        createdAt:
            identical(createdAt, _unset) ? this.createdAt : createdAt as DateTime?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentImage &&
          other.id == id &&
          other.documentId == documentId &&
          other.pageId == pageId &&
          other.pageNumber == pageNumber &&
          other.sourceType == sourceType &&
          other.filePath == filePath &&
          other.width == width &&
          other.height == height &&
          other.format == format &&
          other.fileSize == fileSize &&
          other.createdAt == createdAt);

  @override
  int get hashCode => Object.hash(id, documentId, pageId, pageNumber,
      sourceType, filePath, width, height, format, fileSize, createdAt);

  @override
  String toString() => 'DocumentImage($id, $sourceType, ${width}x$height)';
}

/// Input to an [OcrEngine].
///
/// Exactly one of [path] or [bytes] is set. Path is preferred: passing a file
/// path lets the native side memory-map the image instead of copying a full
/// bitmap across the isolate boundary (NFR-04).
@immutable
class ImageInput {
  const ImageInput.file(this.path, {this.mimeType = 'image/*'})
      : bytes = null,
        width = null,
        height = null;

  const ImageInput.bytes(this.bytes, {this.mimeType = 'image/png'})
      : path = null,
        width = null,
        height = null;

  final String? path;
  final Uint8List? bytes;
  final String mimeType;

  /// Optional pre-known dimensions, used to size the OCR canvas without a
  /// full decode.
  final int? width;
  final int? height;

  bool get isFromFile => path != null;

  /// Validates the "exactly one source" contract at construction time rather
  /// than letting an empty input reach the engine.
  void validate() {
    final hasSource = (path != null) != (bytes != null);
    assert(hasSource, 'ImageInput must have exactly one of path or bytes');
    if (!hasSource) {
      throw ArgumentError('ImageInput must have exactly one of path or bytes');
    }
  }
}
