import '../../core/result/result.dart';
import '../models/extraction.dart' show ExtractionResult;
import '../models/imported_file.dart' show ImportedFile;
import 'progress.dart' show ProgressCallback;

/// Turns a picked file into structured content — SRS §28.
///
/// One implementation per format (`PdfExtractor`, `TextExtractor`,
/// `MarkdownExtractor`, `EpubExtractor`, `ImageExtractor`). The import flow
/// picks by [supportedExtensions], so adding a format means adding one class
/// and registering it — no change to the import, reader or TTS paths.
abstract interface class DocumentExtractor {
  String get id;

  /// Lowercase extensions without dots, e.g. `{'pdf'}`.
  Set<String> get supportedExtensions;

  /// Extracts text, structure, embedded images and per-page facts in one pass.
  ///
  /// Contract for every implementation:
  ///
  /// * **Page-at-a-time.** Never load the whole document into memory (NFR-04).
  /// * **Per-page OCR decision.** Report each page's `hasTextLayer` honestly
  ///   rather than assuming the whole file is one or the other (FR-05).
  /// * **Reading order preserved** in `blocks.order`.
  /// * **Progress reported** for any document longer than a trivial one.
  /// * **Failure is typed** — an encrypted file returns
  ///   [EncryptedDocumentFailure], not a generic parse error, so the UI can
  ///   prompt for the password.
  Future<Result<ExtractionResult>> extract(
    ImportedFile file, {
    ProgressCallback? onProgress,
  });
}
