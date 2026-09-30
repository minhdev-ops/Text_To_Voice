import 'dart:io' show Directory, File, Platform;

import 'package:flutter/services.dart' show PlatformException;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../core/logging/app_log.dart';
import '../../core/result/result.dart';
import '../../domain/engines/ocr_engine.dart';
import '../../domain/engines/progress.dart' show JobStage, ProgressCallback;
import '../../domain/models/document_block.dart' show BlockPosition;
import '../../domain/models/document_image.dart' show ImageInput;
import '../../domain/models/ocr.dart' show OcrLine, OcrResult;

/// Google ML Kit Text Recognition v2, Latin script, behind the [OcrEngine] port.
///
/// This is the **only** file in the project that imports
/// `google_mlkit_text_recognition`. Everything else talks to `OcrEngine`, so
/// replacing this with an ONNX OCR model later — which is what the privacy story
/// eventually wants, see [dataHandlingNote] — is a new class plus a provider
/// override, not a change to the import flow.
///
/// **Offline, verified:** the plugin depends on
/// `com.google.mlkit:text-recognition`, the *bundled* artifact. Google documents
/// the bundled variants as statically linked at build time (no Play Services
/// download); the unbundled ones are the `text-recognition-<script>` variants,
/// and this app never uses them. Vietnamese is Latin script, so Latin is the only
/// model needed.
///
/// **Build requirements:** the plugin declares `compileSdk 36` and `minSdk 21`;
/// the app gets 36/24 from `flutter.compileSdkVersion` / `flutter.minSdkVersion`.
class MlKitOcrEngine implements OcrEngine {
  MlKitOcrEngine({this.script = TextRecognitionScript.latin});

  final TextRecognitionScript script;

  TextRecognizer? _recognizer;

  @override
  String get id => 'mlkit-text-recognition-v2-latin';

  @override
  String get displayName => 'ML Kit Text Recognition (Latin)';

  /// The honest sentence, including the part that is not flattering.
  ///
  /// Verified against Google's own disclosure page
  /// (`developers.google.com/ml-kit/android-data-disclosure`): the SDK uploads
  /// device and app information, a per-installation identifier, latency metrics,
  /// the input/output **size**, feature version, event types and error codes, for
  /// diagnostics and usage analytics. It does **not** upload the image or the
  /// recognized text.
  ///
  /// So the app may say "ảnh và chữ không rời khỏi máy", and must not say "chỉ có
  /// tải model mới cần mạng", because that would be false. This string is what
  /// the About screen renders (NFR-02).
  @override
  String get dataHandlingNote =>
      'Ảnh và chữ nhận dạng không rời khỏi máy. Thư viện ML Kit của Google có '
      'gửi số liệu kỹ thuật về Google để chẩn đoán: phiên bản hệ điều hành, thời '
      'gian xử lý, kích thước ảnh vào/ra, mã lỗi, kèm một mã nhận diện theo từng '
      'lần cài đặt. Không kèm nội dung tài liệu.';

  /// The bundled Latin model ships inside the APK, so there is nothing to install
  /// and no `Install` action to offer.
  @override
  bool get isReady => true;

  @override
  Future<Result<OcrResult>> recognize(
    ImageInput image, {
    ProgressCallback? onProgress,
  }) async {
    final started = DateTime.now();
    onProgress?.call(0, JobStage.runningOcr);

    File? temporary;
    try {
      final path = await _resolvePath(image, onTemporaryFile: (file) => temporary = file);
      if (path == null) {
        return const Failure(ValidationFailure(
          message: 'Ảnh rỗng, không có gì để nhận dạng.',
        ));
      }
      if (!File(path).existsSync()) {
        return const Failure(NotFoundFailure(
          message: 'Không tìm thấy ảnh để nhận dạng. Có thể tệp đã bị xoá.',
        ));
      }

      final recognizer = _recognizer ??= TextRecognizer(script: script);
      final recognized = await recognizer.processImage(InputImage.fromFilePath(path));
      final lines = _toLines(recognized, image);

      AppLog.debug('ocr.mlkit', data: <String, Object?>{
        'engine': id,
        'lines': lines.length,
        'elapsedMs': DateTime.now().difference(started).inMilliseconds,
        // Counts only. The text itself is never logged (AppLog.textDigest exists
        // precisely so this rule is easy to follow).
        'chars': lines.fold<int>(0, (sum, line) => sum + line.text.length),
      });

      onProgress?.call(1, JobStage.runningOcr);

      return Success(OcrResult(
        lines: lines,
        language: _dominantLanguage(recognized),
        engineId: id,
        elapsed: DateTime.now().difference(started),
      ));
    } on PlatformException catch (error) {
      // The plugin's whole failure surface is one exception type, so passing its
      // message through is more useful than inventing a reason for it.
      return Failure(ProcessingFailure(
        message: 'Nhận dạng chữ trong ảnh thất bại.',
        detail: '${error.code}: ${error.message}',
        cause: error,
      ));
    } catch (error) {
      return Failure(ProcessingFailure(
        message: 'Nhận dạng chữ trong ảnh thất bại.',
        detail: error.toString(),
        cause: error,
      ));
    } finally {
      // The temp file is this call's own mess; the app-private copy is the
      // caller's (SRS §38).
      if (temporary != null) {
        try {
          await temporary!.delete();
        } catch (_) {
          // A temp file we could not delete is not worth failing a successful
          // OCR run over; the OS cleans the directory.
        }
      }
    }
  }

  @override
  Future<void> close() async {
    final recognizer = _recognizer;
    _recognizer = null;
    await recognizer?.close();
  }

  /// ML Kit's byte-input path wants **raw** pixel buffers (`nv21` / `bgra8888`),
  /// not the PNG or JPEG bytes this app holds. Handing it encoded bytes would
  /// produce scrambled text rather than an error — the worst possible failure.
  ///
  /// So a byte input is staged to a temporary file and recognized from the path,
  /// which is also the port's preferred form: a path lets the native side decode
  /// once, off the Dart heap (NFR-04).
  Future<String?> _resolvePath(
    ImageInput image, {
    required void Function(File) onTemporaryFile,
  }) async {
    if (image.isFromFile) return image.path;

    final bytes = image.bytes;
    if (bytes == null || bytes.isEmpty) return null;

    final directory = Directory.systemTemp;
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      'vietdoc-ocr-${DateTime.now().microsecondsSinceEpoch}.img',
    );
    await file.writeAsBytes(bytes, flush: true);
    onTemporaryFile(file);
    return file.path;
  }

  /// Flattens ML Kit's block/line tree into [OcrLine]s, normalizing the bounding
  /// boxes to 0..1 of the page.
  ///
  /// Normalization happens at this boundary so nothing downstream has to know the
  /// pixel size of a capture, and one set of structurer thresholds stays valid at
  /// every resolution.
  List<OcrLine> _toLines(RecognizedText recognized, ImageInput image) {
    final size = _pageSize(recognized, image);
    final lines = <OcrLine>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isEmpty) continue;
        lines.add(OcrLine(
          text: text,
          confidence: line.confidence,
          position: size == null
              ? null
              : BlockPosition(
                  left: line.boundingBox.left / size.$1,
                  top: line.boundingBox.top / size.$2,
                  width: line.boundingBox.width / size.$1,
                  height: line.boundingBox.height / size.$2,
                ),
        ));
      }
    }
    return lines;
  }

  /// Page size for normalization: the caller's number when it has one, otherwise
  /// the union of ML Kit's own boxes.
  ///
  /// The union is an approximation and it is the right one here —
  /// `BlockPosition` only has to be proportional, and the structurer compares
  /// positions with each other, never against an absolute pixel value.
  (double, double)? _pageSize(RecognizedText recognized, ImageInput image) {
    if (image.width != null && image.height != null) {
      return (image.width!.toDouble(), image.height!.toDouble());
    }
    var maxRight = 0.0;
    var maxBottom = 0.0;
    for (final block in recognized.blocks) {
      final box = block.boundingBox;
      if (box.right > maxRight) maxRight = box.right;
      if (box.bottom > maxBottom) maxBottom = box.bottom;
    }
    if (maxRight <= 0 || maxBottom <= 0) return null;
    return (maxRight, maxBottom);
  }

  /// `vi-VN` when ML Kit reports Vietnamese anywhere on the page.
  ///
  /// It returns a *set* per block, and on a Vietnamese page it routinely lists
  /// both `vi` and `en` because Latin script is ambiguous. Counting would be
  /// fake precision; for a Vietnamese-first app the honest rule is: if
  /// Vietnamese was seen at all, this is a Vietnamese document.
  String? _dominantLanguage(RecognizedText recognized) {
    final languages = <String>{};
    for (final block in recognized.blocks) {
      languages.addAll(block.recognizedLanguages);
    }
    if (languages.isEmpty) return null;
    if (languages.contains('vi')) return 'vi-VN';
    return languages.first;
  }
}
