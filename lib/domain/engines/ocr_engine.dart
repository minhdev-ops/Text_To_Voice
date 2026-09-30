import '../../core/result/result.dart';
import '../models/document_image.dart' show ImageInput;
import '../models/ocr.dart' show OcrResult;
import 'progress.dart' show ProgressCallback;

/// Optical character recognition — SRS §26.
///
/// Abstract so the OCR model can be exchanged (ML Kit ↔ Tesseract ↔ an ONNX
/// model) without touching the import, reader or TTS paths. Whatever the
/// implementation, it must recognize **Vietnamese and English**, preserve
/// Unicode and Vietnamese diacritics, handle multi-line and multi-paragraph
/// text, and return per-line confidence (FR-04).
abstract interface class OcrEngine {
  String get id;

  String get displayName;

  /// One plain Vietnamese sentence stating what this engine does with the
  /// user's data.
  ///
  /// Part of the port rather than a screen's concern because the answer differs
  /// per implementation and the product's privacy claim has to be literally
  /// true (NFR-02, DESIGN.md → Voice). An engine that uploads nothing says so;
  /// an engine that reports diagnostics to a third party says *that*, in the
  /// same sentence, and the About screen renders whatever it returns.
  String get dataHandlingNote;

  /// `true` once the recognition model is installed locally.
  bool get isReady;

  /// Runs recognition on one image.
  ///
  /// Implementations must work with the network off and must not keep the
  /// decoded bitmap alive after returning (NFR-04).
  Future<Result<OcrResult>> recognize(
    ImageInput image, {
    ProgressCallback? onProgress,
  });

  Future<void> close();
}
