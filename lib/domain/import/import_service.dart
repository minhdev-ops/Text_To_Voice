import '../../core/result/result.dart';
import '../engines/document_extractor.dart';
import '../engines/ocr_engine.dart';
import '../engines/progress.dart' show JobStage, ProgressCallback;
import '../imaging/document_scanner.dart';
import '../models/extraction.dart' show ExtractionResult;
import '../models/imported_file.dart' show ImportedFile;
import '../ocr/ocr_structurer.dart';
import './file_validation.dart' show ImportValidator, ValidatedFile, FileKind;
import './epub_extractor.dart' show EpubExtractor;
import './image_extractor.dart' show ImageExtractor;
import './pdf_extractor.dart' show PdfExtractor;
import './text_extractor.dart' show MarkdownExtractor, TextExtractor;

/// Imports a file by validating it and extracting its content using the
/// appropriate format-specific extractor.
///
/// This service wires together:
/// 1. File validation (checking actual content, not just extension)
/// 2. Extractor selection (based on validated file type)
/// 3. Content extraction (using the selected extractor)
/// 4. Progress reporting
class ImportService {
  const ImportService({this.ocr, this.structurer, this.scanner});

  /// Needed only for images and scanned PDFs. Left null by the default
  /// constructor, and an image imported without it fails with a message naming
  /// the missing piece rather than "unsupported format" — the format *is*
  /// supported, nothing was wired to read it.
  final OcrEngine? ocr;

  final OcrStructurer? structurer;

  /// Prepares a page for recognition. Shared with the camera flow so an imported
  /// photo is straightened and contrast-stretched the same way a captured one is
  /// — an import that skipped this is the difference between readable text and a
  /// recognizer guessing at 40% confidence.
  final DocumentScanner? scanner;

  /// Imports [file] by validating its content and extracting with the
  /// appropriate extractor for its actual format.
  ///
  /// Returns an [ExtractionResult] containing the structured blocks and
  /// per-page information, or a failure if validation or extraction fails.
  ///
  /// The extractor is chosen based on the file's actual content type,
  /// not its extension or claimed MIME type (SRS §38).
  Future<Result<ExtractionResult>> importFile(
    ImportedFile file, {
    ProgressCallback? onProgress,
  }) async {
    // Step 1: Validate the file to determine its actual type
    onProgress?.call(0, JobStage.analyzing);
    final validationResult = ImportValidator.validate(file);
    if (validationResult case Failure<ValidatedFile>(:final failure)) {
      return Result<ExtractionResult>.failure(failure);
    }
    final ValidatedFile validated = validationResult.valueOrNull!;

    // Step 2: Select the appropriate extractor based on validated type
    final DocumentExtractor? extractor = _selectExtractor(validated);
    if (extractor == null) {
      // An image with no OCR engine wired is a different problem from a format
      // nobody can read, and it needs a different fix, so it is said plainly.
      if (!_needsOcr(validated.kind)) {
        return Result<ExtractionResult>.failure(
          ValidationFailure(
            message: 'Không thể trích xuất tệp "${validated.extension}" vì '
                'định dạng này chưa được hỗ trợ.',
          ),
        );
      }
      return const Result<ExtractionResult>.failure(
        ModelUnavailableFailure(
          message: 'Ảnh cần bộ nhận dạng chữ, nhưng bộ này chưa được bật.',
          modelId: 'ocr',
        ),
      );
    }

    // Step 3: Extract content using the selected extractor
    onProgress?.call(0, JobStage.extracting);
    try {
      final result = await extractor.extract(
        file,
        onProgress: (progress, stage) {
          // Map extractor progress to overall import progress
          // Validation: 0%, Extraction: 0-100% mapped to 0-100% of remaining
          final overallProgress = 0.5 + progress * 0.5;
          onProgress?.call(overallProgress, stage);
        },
      );
      
      // Step 4: Report completion
      onProgress?.call(1, JobStage.done);
      return result;
    } catch (error) {
      return Result<ExtractionResult>.failure(
        ProcessingFailure(
          message: 'Không thể trích xuất nội dung từ tệp này.',
          detail: error.toString(),
          cause: error,
        ),
      );
    }
  }

  /// `true` when a format is readable only through OCR.
  static bool _needsOcr(FileKind kind) => switch (kind) {
        FileKind.imageJpeg ||
        FileKind.imagePng ||
        FileKind.imageWebp =>
          true,
        FileKind.pdf || FileKind.text || FileKind.markdown || FileKind.epub =>
          false,
      };

  /// Selects the appropriate extractor for a validated file type.
  DocumentExtractor? _selectExtractor(ValidatedFile validated) {
    switch (validated.kind) {
      case FileKind.pdf:
        return PdfExtractor(ocr: ocr, structurer: structurer, scanner: scanner);
      case FileKind.text:
        return const TextExtractor();
      case FileKind.markdown:
        return const MarkdownExtractor();
      case FileKind.epub:
        return const EpubExtractor();
      case FileKind.imageJpeg:
      case FileKind.imagePng:
      case FileKind.imageWebp:
        final engine = ocr;
        final structures = structurer;
        if (engine == null || structures == null) return null;
        return ImageExtractor(
          ocr: engine,
          structurer: structures,
          scanner: scanner,
        );
    }
  }
}