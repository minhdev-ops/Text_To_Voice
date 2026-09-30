import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show immutable;
import 'package:image/image.dart' as img;

import '../../core/isolate/isolate_runner.dart';
import '../../core/result/result.dart';
import 'enhancement.dart';
import 'image_geometry.dart';
import 'image_normalizer.dart';
import 'quad_detector.dart';

/// One scan job: raw capture bytes in, corrected page bytes out.
@immutable
class ScanRequest {
  const ScanRequest({
    required this.bytes,
    this.plan = EnhancementPlan.ocrDefault,
    this.quad,
    this.detectQuad = true,
    this.previewMaxDimension = 900,
    this.detectionOptions = const QuadDetectionOptions(),
  });

  /// JPEG/PNG/WebP bytes exactly as captured or picked.
  final Uint8List bytes;

  final EnhancementPlan plan;

  /// A user-dragged outline. When set, detection is skipped — a person who
  /// placed the corners by hand has answered the question already.
  ///
  /// Coordinates are expressed in the **normalized** image space reported by
  /// [ScanOutcome.processedWidth] / [ScanOutcome.processedHeight], which is the
  /// space the review pane draws and hit-tests in.
  final ImageQuad? quad;

  final bool detectQuad;

  /// Ceiling for the on-screen preview. Never fed to OCR.
  final int previewMaxDimension;

  final QuadDetectionOptions detectionOptions;

  @override
  String toString() =>
      'ScanRequest(${bytes.length} bytes, quad ${quad != null}, '
      'plan ${plan.steps.length})';
}

/// The result of one scan, in a form that can cross an isolate boundary.
///
/// Only `Uint8List`s and primitives: no `img.Image`, because a decoded bitmap is
/// tens of megabytes and copying one back from the worker would undo the reason
/// for using a worker (NFR-04).
@immutable
class ScanOutcome {
  const ScanOutcome({
    required this.enhancedBytes,
    required this.previewBytes,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.processedWidth,
    required this.processedHeight,
    required this.report,
    this.detection,
  });

  /// Corrected, enhanced page as PNG — the artifact OCR consumes and the one
  /// kept with the document.
  final Uint8List enhancedBytes;

  /// Small JPEG for the review pane. Derived, never stored.
  final Uint8List previewBytes;

  /// Dimensions of the capture as decoded (after EXIF rotation).
  final int sourceWidth;
  final int sourceHeight;

  /// Dimensions of the image [enhancedBytes] holds.
  final int processedWidth;
  final int processedHeight;

  final EnhancementReport report;

  /// `null` when the caller supplied its own quad or asked for no detection.
  final QuadDetection? detection;

  /// Scale from the normalized space back to the capture, for drawing a detected
  /// outline over the untouched original.
  double get normalizedScale =>
      processedWidth == 0 ? 1 : sourceWidth / processedWidth;

  @override
  String toString() => 'ScanOutcome($processedWidth×$processedHeight, '
      '${enhancedBytes.length} bytes)';
}

/// Runs the scan pipeline off the UI thread.
///
/// Every step here is CPU-bound pixel work — decode, resample, Otsu, four
/// least-squares fits, up to two rotations — so the whole thing runs through
/// `runOnBackgroundIsolate` (NFR-03). The isolate returns bytes, never bitmaps.
class DocumentScanner {
  const DocumentScanner();

  /// Decodes, detects, enhances and encodes in one pass.
  Future<Result<ScanOutcome>> scan(ScanRequest request) async {
    try {
      final outcome = await runOnBackgroundIsolate(
        _scanTask,
        request,
        debugLabel: 'vietdoc.scan',
      );
      if (outcome == null) {
        return const Failure(ValidationFailure(
          message: 'Không đọc được ảnh này. Ảnh có thể bị hỏng hoặc không '
              'đúng định dạng.',
        ));
      }
      return Success(outcome);
    } on IsolateTaskError catch (error) {
      return Failure(ProcessingFailure(
        message: 'Xử lý ảnh thất bại.',
        detail: error.message,
        cause: error,
      ));
    } on IsolateCancelledError {
      return const Failure(CancelledFailure());
    }
  }

  /// Detection only — the first half of the review-pane flow, so the outline can
  /// be drawn before the user decides anything.
  Future<Result<ScanOutcome>> detect(ScanRequest request) => scan(
        ScanRequest(
          bytes: request.bytes,
          // Skipping the enhancement pass keeps the first paint fast; the user
          // is looking at their own photo until they accept the crop.
          plan: EnhancementPlan.original,
          detectQuad: request.detectQuad,
          previewMaxDimension: request.previewMaxDimension,
          detectionOptions: request.detectionOptions,
        ),
      );
}

/// Top-level so the closure handed to `Isolate.run` captures only `request`.
ScanOutcome? _scanTask(ScanRequest request) {
  final decoded = decodeDocumentImage(request.bytes);
  if (decoded == null) return null;

  final normalized = normalizeForOcr(decoded.image);
  final normalizedFrame = ImageQuad.fullFrame(normalized.width, normalized.height);

  QuadDetection? detection;
  var quad = request.quad;

  if (quad == null && request.detectQuad) {
    detection = detectDocumentQuad(normalized, options: request.detectionOptions);
    if (detection.found) quad = detection.quad;
  }

  final enhanced = EnhancementPipeline.apply(
    normalized,
    plan: request.plan,
    // Fall back to the whole normalized frame only when perspective correction
    // is on *and* the user asked for no detection: an unrectified but otherwise
    // enhanced page is still useful, and the report says the step was skipped.
    quad: quad ?? normalizedFrame,
  );

  final preview = makePreview(
    enhanced.image,
    maxDimension: request.previewMaxDimension,
  );

  return ScanOutcome(
    enhancedBytes: encodePng(enhanced.image),
    previewBytes: encodeJpeg(preview),
    sourceWidth: decoded.width,
    sourceHeight: decoded.height,
    processedWidth: enhanced.image.width,
    processedHeight: enhanced.image.height,
    report: enhanced.report,
    detection: detection,
  );
}

/// Convenience for tests and for callers that already hold a decoded image:
/// runs the same pipeline synchronously.
ScanOutcome? scanSynchronously(ScanRequest request) => _scanTask(request);

/// Rewrites a quad from the image space it was measured in into another one.
///
/// Needed because detection runs on the normalized image while the review pane
/// draws on the capture preview, and a hand-dragged corner has to survive a
/// change of scale without drifting.
ImageQuad? rescaleQuad(
  ImageQuad? quad, {
  required int fromWidth,
  required int fromHeight,
  required int toWidth,
  required int toHeight,
}) {
  if (quad == null || fromWidth == 0 || fromHeight == 0) return null;
  final sx = toWidth / fromWidth;
  final sy = toHeight / fromHeight;
  return ImageQuad(
    topLeft: ImagePoint(quad.topLeft.x * sx, quad.topLeft.y * sy),
    topRight: ImagePoint(quad.topRight.x * sx, quad.topRight.y * sy),
    bottomRight: ImagePoint(quad.bottomRight.x * sx, quad.bottomRight.y * sy),
    bottomLeft: ImagePoint(quad.bottomLeft.x * sx, quad.bottomLeft.y * sy),
  );
}

/// Decodes [bytes] and reports its size without running any pipeline step.
///
/// Used to reject a capture before spending a worker on it, and to size the
/// preview before the user has decided anything (SRS §38 size cap).
img.Image? decodeOnly(Uint8List bytes) => decodeDocumentImage(bytes)?.image;
