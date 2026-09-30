import '../../core/logging/app_log.dart';
import '../../core/result/result.dart';
import '../engines/document_extractor.dart';
import '../engines/ocr_engine.dart';
import '../engines/progress.dart' show JobStage, ProgressCallback;
import '../imaging/document_scanner.dart';
import '../imaging/enhancement.dart';
import '../models/document_image.dart' show ImageInput;
import '../models/extraction.dart' show ExtractionResult, ExtractedPage;
import '../models/imported_file.dart' show ImportedFile;
import '../ocr/ocr_structurer.dart';
import 'file_bytes.dart' show readImportedBytes;

/// Image → text, via the OCR engine and the structurer (FR-02, FR-04).
///
/// The image itself is not the deliverable — the words in it are. So this runs
/// the same steps the camera path runs ([DocumentScanner] then [OcrEngine] then
/// [OcrStructurer]) rather than a second, slightly different pipeline: an import
/// and a capture of the same page must produce the same blocks, or the reader and
/// read-aloud behave differently depending on where the page came from.
///
/// Skipping the scanner is what made imported images read badly. A photo off a
/// phone camera is off-axis, dimly lit and shot at an angle; the recognizer is
/// tuned for flat black-on-white. Normalizing, straightening and stretching the
/// contrast first is the difference between ~40% confidence and text you can read
/// — measured on a real import from the device, where every line came back under
/// 50% and the recognizer was guessing.
///
/// Every collaborator is injected, so this class is testable without ML Kit and
/// the whole file can be replaced when an on-device OCR model arrives.
class ImageExtractor implements DocumentExtractor {
  const ImageExtractor({
    required this.ocr,
    required this.structurer,
    this.scanner,
  });

  final OcrEngine ocr;
  final OcrStructurer structurer;

  /// Prepares the page for recognition. Optional so a caller without one still
  /// gets an attempt on the original rather than a hard failure.
  final DocumentScanner? scanner;

  @override
  String get id => 'image-ocr';

  @override
  Set<String> get supportedExtensions =>
      const <String>{'jpg', 'jpeg', 'png', 'webp'};

  @override
  Future<Result<ExtractionResult>> extract(
    ImportedFile file, {
    ProgressCallback? onProgress,
  }) async {
    onProgress?.call(0, JobStage.extracting);

    if (!ocr.isReady) {
      return const Failure(ModelUnavailableFailure(
        message: 'Chưa có bộ nhận dạng chữ trên máy.',
        modelId: 'ocr',
      ));
    }

    final input = await _prepare(file, onProgress);
    if (input == null) {
      return const Failure(ModelUnavailableFailure(
        message: 'Chưa có bộ nhận dạng chữ trên máy.',
        modelId: 'ocr',
      ));
    }

    // Reset first: running-header memory belongs to one document, and an
    // extractor instance can outlive a previous import.
    structurer.reset();

    final recognized = await ocr.recognize(
      input,
      onProgress: (progress, stage) {
        // Preparation owns the first slice, recognition the rest.
        onProgress?.call(_preparedFraction + progress * (1 - _preparedFraction), stage);
      },
    );

    switch (recognized) {
      case Failure(:final failure):
        return Failure<ExtractionResult>(failure);
      case Success(:final value):
        if (value.isEmpty) {
          // Empty is not an engine failure — the engine ran fine and found
          // nothing. Saying so is more useful than "không đọc được".
          return const Failure(ValidationFailure(
            message: 'Không tìm thấy chữ trong ảnh này. Chụp rõ hơn, '
                'vuông góc hơn hoặc chọn ảnh khác.',
          ));
        }

        onProgress?.call(_preparedFraction + (1 - _preparedFraction) * 0.8, JobStage.extracting);
        final blocks = structurer.structure(value.lines, pageNumber: 1);
        onProgress?.call(1, JobStage.done);

        return Success(ExtractionResult(
          blocks: blocks,
          // An imported image is one page that came from OCR, not from a parser.
          pages: <ExtractedPage>[
            ExtractedPage(
              pageNumber: 1,
              hasTextLayer: false,
              blockCount: blocks.length,
            ),
          ],
          detectedLanguage: value.language,
          elapsed: value.elapsed,
        ));
    }
  }

  /// The share of the bar given to image preparation.
  static const double _preparedFraction = 0.25;

  /// The image the recognizer should see, or `null` when the file cannot be
  /// read at all.
  ///
  /// A preparation failure is **not** fatal: the enhanced page is an
  /// improvement, not a precondition, and refusing to even try the original would
  /// turn "the photo was crooked" into "the app cannot read this file".
  Future<ImageInput?> _prepare(
    ImportedFile file,
    ProgressCallback? onProgress,
  ) async {
    final scanner = this.scanner;
    if (scanner == null) {
      return ImageInput.file(file.path, mimeType: file.mimeType);
    }

    final read = readImportedBytes(file);
    final bytes = read.valueOrNull;
    if (bytes == null) {
      // No bytes at all: the file is genuinely unreadable, unlike a failed
      // enhancement, so this one is reported instead of papered over.
      AppLog.warning('import.image.unreadable',
          data: <String, Object?>{'detail': read.failureOrNull?.message});
      return null;
    }

    onProgress?.call(0, JobStage.extracting);
    final scan = await scanner.scan(
      ScanRequest(bytes: bytes, plan: EnhancementPlan.ocrDefault),
    );

    switch (scan) {
      case Success(:final value):
        return ImageInput.bytes(value.enhancedBytes, mimeType: 'image/png');
      case Failure(:final failure):
        AppLog.warning('import.image.enhance_failed',
            data: <String, Object?>{'detail': failure.message});
        return ImageInput.file(file.path, mimeType: file.mimeType);
    }
  }
}
