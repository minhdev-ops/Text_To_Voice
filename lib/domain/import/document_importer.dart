import 'dart:io' show File;
import 'dart:typed_data' show Uint8List;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show immutable;

import '../../core/result/result.dart';
import '../../core/storage/app_storage.dart';
import '../engines/ocr_engine.dart';
import '../engines/progress.dart' show ProgressCallback;
import '../models/document.dart' show DocumentSource;
import '../models/extraction.dart' show ExtractionResult;
import '../models/imported_file.dart' show ImportedFile, SupportedFiles;
import '../models/structured_block.dart' show StructuredBlock;
import 'file_validation.dart' show ImportValidator, ValidatedFile, FileKind;
import 'import_service.dart' show ImportService;

/// Result of a document import operation.
@immutable
class ImportDocumentResult {
  const ImportDocumentResult({
    required this.documentId,
    required this.name,
    required this.source,
    required this.extractedText,
    required this.blocks,
    required this.pagesCount,
    required this.hasText,
    required this.fileSize,
    this.pageCount = 0,
    this.ocrEngineId,
    this.lowConfidenceCount = 0,
  });

  final String documentId;
  final String name;

  /// What kind of file this came from — the persistence layer stores it as
  /// `documents.source` (the caller must not guess it from block types).
  final DocumentSource source;
  final String extractedText;
  final List<StructuredBlock> blocks;
  final int pagesCount;
  final bool hasText;
  final int fileSize;

  /// Distinct from [pagesCount]: the number of pages that came from a text
  /// layer. For an imported image this is 1, because one image is one page.
  final int pageCount;

  /// Which recognizer produced the text, for an image or a scanned PDF. Null
  /// when a parser did, so a bad OCR run can be attributed later (NFR-02: the
  /// name only, never the text).
  final String? ocrEngineId;

  /// How many blocks the recognizer was not confident about.
  ///
  /// Carried on the result so the import can be **labelled** as uncertain
  /// instead of silently presented as clean text. A page that came back as
  /// "Chss:B Sfot:40C" at 38% confidence is not a document, it is a guess, and
  /// the person who has to read it is the only one who can tell.
  final int lowConfidenceCount;

  /// `true` when OCR was unsure enough that the user should look at the result.
  bool get needsReview => lowConfidenceCount > 0;
}

/// Service for importing documents from files.
///
/// Handles the full flow: file picking → validation → extraction → database persistence.
/// Can be used from any screen (Library, Capture, etc.).
class DocumentImporter {
  const DocumentImporter({this.importService = const ImportService()});

  /// The extraction pipeline. Injectable so the caller can supply one with OCR
  /// wired in — without it, images and scanned PDFs have no reader at all, and
  /// the default here would quietly fail exactly the formats a phone camera
  /// produces.
  final ImportService importService;

  /// The recognizer this importer reads with, for attribution on the result.
  OcrEngine? get ocr => importService.ocr;

  /// Opens the system file picker and returns the chosen file, or `null` when the
  /// user backed out.
  ///
  /// Cancelling returns `null` rather than a failure: it is not an error and the
  /// UI must not announce it (see `CancelledFailure`).
  Future<PlatformFile?> pick() async {
    // Sorted so the picker's filter is in a stable, predictable order; the set
    // it comes from has no order of its own.
    final extensions = SupportedFiles.extensions.toList()..sort();
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      dialogTitle: 'Chọn tài liệu',
    );
    if (result.isEmpty) return null;
    return result.first;
  }

  /// Opens the system file picker and imports the selected document.
  ///
  /// Returns an [ImportDocumentResult] on success, or a [Failure] if the user
  /// cancels, the file is invalid, or extraction fails.
  Future<Result<ImportDocumentResult>> pickAndImport({
    required ProgressCallback? onProgress,
  }) async {
    try {
      final platformFile = await pick();
      if (platformFile == null) {
        return const Failure<ImportDocumentResult>(CancelledFailure(
          message: 'Người dùng đã hủy chọn tệp.',
        ));
      }

      return await importFile(
        platformFile: platformFile,
        onProgress: onProgress,
      );
    } catch (error) {
      return Failure<ImportDocumentResult>(ProcessingFailure(
        message: 'Lỗi khi nhập tài liệu.',
        detail: error.toString(),
        cause: error,
      ));
    }
  }

  /// Imports a document from a [PlatformFile].
  ///
  /// This method handles validation, extraction, and conversion to a document.
  /// The caller is responsible for persisting the document to the database.
  Future<Result<ImportDocumentResult>> importFile({
    required PlatformFile platformFile,
    ProgressCallback? onProgress,
  }) async {
    try {
      // Read file bytes
      final Uint8List fileBytes = await platformFile.readAsBytes();
      final headBytes = fileBytes.length > 512
          ? fileBytes.sublist(0, 512)
          : fileBytes;

      // Determine MIME type from extension
      final mimeType = _mimeTypeFromExtension(platformFile.extension);
      final size = await platformFile.length() ?? fileBytes.length;

      // A provider may hand back a URI that is not a local path (a cloud
      // document, a web blob). The extractors read through
      // `readImportedBytes`, which needs a real file, so the bytes are
      // materialized into app-private storage rather than asserted non-null.
      final path = await _materializePath(platformFile, fileBytes);
      if (path == null) {
        return const Failure<ImportDocumentResult>(StorageFailure(
          message: 'Không mở được tệp đã chọn. Thử chọn tệp khác hoặc tải tệp '
              'về máy trước.',
        ));
      }

      // Create ImportedFile for validation
      final importedFile = ImportedFile(
        name: platformFile.name,
        path: path,
        mimeType: mimeType,
        size: size,
        headBytes: headBytes,
      );

      // Validate the file to determine its actual type
      final validationResult = ImportValidator.validate(importedFile);
      if (validationResult case Failure<ValidatedFile>(:final failure)) {
        return Failure<ImportDocumentResult>(failure);
      }

      final ValidatedFile validated = validationResult.valueOrNull!;

      // Extract content using the injected pipeline
      final extractResult = await importService.importFile(
        importedFile,
        onProgress: onProgress,
      );

      if (extractResult case Failure<ExtractionResult>(:final failure)) {
        return Failure<ImportDocumentResult>(failure);
      }

      final ExtractionResult extraction = extractResult.valueOrNull!;

      if (extraction.isEmpty) {
        return const Failure<ImportDocumentResult>(ValidationFailure(
          message: 'Tệp này không có nội dung văn bản để đọc.',
        ));
      }

      // Determine document source from file kind
      final source = _sourceFromFileKind(validated.kind);

      // Generate a document ID
      final documentId = _generateDocumentId();

      return Success(ImportDocumentResult(
        documentId: documentId,
        name: _documentNameFromFile(platformFile.name, extraction.title),
        source: source,
        extractedText: extraction.text,
        blocks: extraction.blocks,
        pagesCount: extraction.pages.length,
        hasText: extraction.text.trim().isNotEmpty,
        fileSize: size,
        pageCount: extraction.pages.length,
        ocrEngineId: _ocrEngineId(validated.kind, extraction),
        lowConfidenceCount: _lowConfidenceCount(extraction),
      ));
    } catch (error) {
      return Failure<ImportDocumentResult>(ProcessingFailure(
        message: 'Không thể xử lý tệp này.',
        detail: error.toString(),
        cause: error,
      ));
    }
  }

  /// The recognizer that produced this extraction, or `null` when a parser did.
  ///
  /// Only reported for formats that *can* go through OCR and actually did: a
  /// text-layer PDF was parsed, so attributing it to an OCR engine would send
  /// whoever debugs a bad extraction to the wrong place.
  String? _ocrEngineId(FileKind kind, ExtractionResult extraction) {
    final canUseOcr = kind == FileKind.pdf || _isImage(kind);
    if (!canUseOcr || ocr == null) return null;
    if (extraction.pages.isEmpty) return null;
    if (extraction.pages.any((page) => page.hasTextLayer)) return null;
    return ocr!.id;
  }

  /// Blocks the recognizer was unsure of, by the same 0.85 rule the camera
  /// review pane uses.
  ///
  /// Counted only for OCR-derived extractions: a parsed text file has no
  /// confidence at all, and reporting "0 lines need checking" for a plain `.txt`
  /// would be a meaningless number dressed up as a measurement.
  static int _lowConfidenceCount(ExtractionResult extraction) => extraction
      .blocks
      .where((block) =>
          block.confidence != null && block.confidence! < _confidenceThreshold)
      .length;

  /// Below this the recognizer's own line confidence is not trustworthy.
  ///
  /// One constant for both the count and the UI that shows it: two numbers would
  /// eventually disagree, and then the warning would appear on lines the review
  /// pane considers fine.
  static const double _confidenceThreshold = 0.85;

  static bool _isImage(FileKind kind) =>
      kind == FileKind.imageJpeg ||
      kind == FileKind.imagePng ||
      kind == FileKind.imageWebp;

  /// A local path the extractors can read, or `null` when the bytes could not be
  /// written anywhere.
  ///
  /// Native mobile pickers already hand back a real path, so this is a no-op
  /// there; it exists for providers that return a non-`file` URI, where the
  /// `!` that used to be here was a crash rather than a fallback.
  Future<String?> _materializePath(PlatformFile file, Uint8List bytes) async {
    final existing = file.path;
    if (existing != null && File(existing).existsSync()) return existing;

    try {
      final tempPath = appStorage.tempFilePath('import', _extensionOrBin(file));
      await File(tempPath).writeAsBytes(bytes, flush: true);
      return tempPath;
    } catch (_) {
      return null;
    }
  }

  String _extensionOrBin(PlatformFile file) =>
      file.extension == null || file.extension!.isEmpty
          ? 'bin'
          : file.extension!.toLowerCase();

  /// Converts a [FileKind] to a [DocumentSource].
  DocumentSource _sourceFromFileKind(FileKind kind) {
    switch (kind) {
      case FileKind.pdf:
        return DocumentSource.pdf;
      case FileKind.text:
        return DocumentSource.textFile;
      case FileKind.markdown:
        return DocumentSource.markdown;
      case FileKind.epub:
        return DocumentSource.epub;
      case FileKind.imageJpeg:
      case FileKind.imagePng:
      case FileKind.imageWebp:
        return DocumentSource.image;
    }
  }

  /// Determines MIME type from file extension.
  String _mimeTypeFromExtension(String? extension) {
    if (extension == null) return 'application/octet-stream';
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'md':
        return 'text/markdown';
      case 'epub':
        return 'application/epub+zip';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  /// Generates a document name from the file name and optional extracted title.
  String _documentNameFromFile(String fileName, String? extractedTitle) {
    // Use extracted title if available and meaningful
    if (extractedTitle != null && extractedTitle.trim().isNotEmpty) {
      final cleanTitle = extractedTitle.trim();
      if (cleanTitle.length <= 100) return cleanTitle;
    }
    // Otherwise use file name without extension
    final nameWithoutExt = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    return nameWithoutExt.length > 100
        ? nameWithoutExt.substring(0, 100)
        : nameWithoutExt;
  }

  /// Generates a unique document ID.
  String _generateDocumentId() {
    return 'doc-${DateTime.now().microsecondsSinceEpoch}';
  }
}