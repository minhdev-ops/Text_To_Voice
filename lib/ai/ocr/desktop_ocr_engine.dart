import '../../core/result/result.dart';
import '../../domain/engines/ocr_engine.dart';
import '../../domain/engines/progress.dart' show ProgressCallback;
import '../../domain/models/document_image.dart' show ImageInput;
import '../../domain/models/ocr.dart' show OcrResult;

class DesktopOcrEngine implements OcrEngine {
  const DesktopOcrEngine();

  @override
  String get id => 'ocr-desktop-unavailable';

  @override
  String get displayName => 'Nhận dạng chữ (máy tính)';

  @override
  String get dataHandlingNote =>
      'Không nhận dạng chữ trên máy tính: không có engine OCR gốc cho '
      'Linux, Windows và macOS, nên không ảnh được gửi đi và không văn bản '
      'được trích xuất từ ảnh.';

  @override
  bool get isReady => false;

  @override
  Future<Result<OcrResult>> recognize(
    ImageInput image, {
    ProgressCallback? onProgress,
  }) async {
    return const Failure(ModelUnavailableFailure(
      message: 'Chưa có bộ nhận dạng chữ trên máy tính.',
      modelId: 'ocr',
    ));
  }

  @override
  Future<void> close() async {}
}
