import 'package:collection/collection.dart' show DeepCollectionEquality;
import 'package:flutter/foundation.dart' show immutable;

/// Processing state of a document. Drives every `StatusChip` in the app, so the
/// words are chosen once here and reused (DESIGN.md → Voice).
enum DocumentStatus {
  /// Accepted but not started; sits in the queue and survives process death.
  queued,

  /// Parser/OCR running on a background isolate.
  extracting,

  /// OCR pass running (separate so the UI can say "Running OCR" rather than a
  /// generic "Processing").
  ocr,

  /// Structured text is available; readable and speakable.
  ready,

  /// Failed. [Document.failureMessage] carries the real cause.
  failed,
}

/// Where the content came from. Keeps `source_type` (SRS §31) honest — an image
/// scanned with the camera is not the same provenance as an embedded PDF image.
enum DocumentSource {
  typedText,
  camera,
  image,
  pdf,
  textFile,
  markdown,
  epub,
}

/// Sort options for the library (FR-01, FR-18).
enum DocumentSortBy {
  name,
  createdAt,
  updatedAt,
  fileSize,
  lastOpenedAt,
}

/// A stored document — SRS §30 `documents`.
///
/// Immutable with value equality: every state transition assigns a **new**
/// instance so Riverpod's value-based listeners diff correctly. No field is
/// ever mutated in place.
@immutable
class Document {
  const Document({
    required this.id,
    required this.name,
    required this.source,
    required this.mimeType,
    required this.createdAt,
    required this.updatedAt,
    this.originalFileName,
    this.fileSize = 0,
    this.filePath,
    this.status = DocumentStatus.queued,
    this.extractedText,
    this.isFavorite = false,
    this.category,
    this.lastOpenedAt,
    this.failureMessage,
    this.metadata = const <String, Object?>{},
  });

  /// Stable identifier (also the folder name under app-private storage).
  final String id;

  /// User-editable display name.
  final String name;

  final DocumentSource source;

  /// MIME type **verified against the file bytes**, not taken from the
  /// extension (SRS §38).
  final String mimeType;

  /// Original name as supplied by the picker, before any rename.
  final String? originalFileName;

  final int fileSize;

  /// Path inside app-private storage. Never a network location.
  final String? filePath;

  final DocumentStatus status;

  /// Full extracted text. The structured view lives in `document_blocks`;
  /// this is the flat projection used for search and export.
  final String? extractedText;

  final bool isFavorite;

  /// Free-form grouping (FR-01 "phân loại tài liệu").
  final String? category;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Set when the user actually opened it — drives "Recent" and history
  /// ordering rather than guessing from [updatedAt].
  final DateTime? lastOpenedAt;

  /// Real cause when [status] is [DocumentStatus.failed]. User-facing text.
  final String? failureMessage;

  final Map<String, Object?> metadata;

  static const Object _unset = Object();

  Document copyWith({
    String? name,
    DocumentSource? source,
    String? mimeType,
    int? fileSize,
    DocumentStatus? status,
    bool? isFavorite,
    DateTime? updatedAt,
    Map<String, Object?>? metadata,
    Object? originalFileName = _unset,
    Object? filePath = _unset,
    Object? extractedText = _unset,
    Object? category = _unset,
    Object? lastOpenedAt = _unset,
    Object? failureMessage = _unset,
  }) {
    return Document(
      id: id,
      name: name ?? this.name,
      source: source ?? this.source,
      mimeType: mimeType ?? this.mimeType,
      originalFileName: identical(originalFileName, _unset)
          ? this.originalFileName
          : originalFileName as String?,
      fileSize: fileSize ?? this.fileSize,
      filePath: identical(filePath, _unset) ? this.filePath : filePath as String?,
      status: status ?? this.status,
      extractedText: identical(extractedText, _unset)
          ? this.extractedText
          : extractedText as String?,
      isFavorite: isFavorite ?? this.isFavorite,
      category: identical(category, _unset) ? this.category : category as String?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastOpenedAt: identical(lastOpenedAt, _unset)
          ? this.lastOpenedAt
          : lastOpenedAt as DateTime?,
      failureMessage: identical(failureMessage, _unset)
          ? this.failureMessage
          : failureMessage as String?,
      metadata: metadata ?? this.metadata,
    );
  }

  /// `true` when there is text the reader and the TTS engine can consume.
  bool get hasText => extractedText != null && extractedText!.trim().isNotEmpty;

  /// How many blocks OCR was not confident about, or 0 when the text came from a
  /// parser or the document was not produced by OCR at all.
  ///
  /// Read from metadata rather than recounted from the blocks so the library can
  /// show it without loading every block of every document — and so the number
  /// on the row is the number the import actually decided on, not one recomputed
  /// by a second rule.
  int get lowConfidenceCount {
    final value = metadata['ocr_low_confidence_blocks'];
    return value is int ? value : 0;
  }

  /// `true` when OCR was unsure enough that the user should check the result
  /// before trusting it.
  bool get needsOcrReview => lowConfidenceCount > 0;

  bool get isProcessing =>
      status == DocumentStatus.queued ||
      status == DocumentStatus.extracting ||
      status == DocumentStatus.ocr;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Document &&
          other.id == id &&
          other.name == name &&
          other.source == source &&
          other.mimeType == mimeType &&
          other.originalFileName == originalFileName &&
          other.fileSize == fileSize &&
          other.filePath == filePath &&
          other.status == status &&
          other.extractedText == extractedText &&
          other.isFavorite == isFavorite &&
          other.category == category &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt &&
          other.lastOpenedAt == lastOpenedAt &&
          other.failureMessage == failureMessage &&
          const DeepCollectionEquality().equals(other.metadata, metadata));

  @override
  int get hashCode => Object.hash(
        id,
        name,
        source,
        mimeType,
        originalFileName,
        fileSize,
        filePath,
        status,
        extractedText,
        isFavorite,
        category,
        createdAt,
        updatedAt,
        lastOpenedAt,
        failureMessage,
        const DeepCollectionEquality().hash(metadata),
      );

  @override
  String toString() => 'Document($id, $name, $status)';
}
