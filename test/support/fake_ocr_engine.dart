import 'dart:async';

import 'package:text_to_voice/core/result/result.dart';
import 'package:text_to_voice/domain/engines/ocr_engine.dart';
import 'package:text_to_voice/domain/engines/progress.dart';
import 'package:text_to_voice/domain/models/document_block.dart' show BlockPosition;
import 'package:text_to_voice/domain/models/document_image.dart' show ImageInput;
import 'package:text_to_voice/domain/models/ocr.dart';

/// An [OcrEngine] whose answers the test decides.
///
/// Mirrors `FakeTtsEngine`'s shape on purpose: per-input scripted failures, a
/// settable latency, and a record of every call, so a test can assert on *what
/// was asked* as well as what came back. That is the only way to prove the
/// pipeline handed OCR the enhanced image rather than the original.
class FakeOcrEngine implements OcrEngine {
  FakeOcrEngine({this.lines = const <OcrLine>[], this.language = 'vi-VN'});

  /// Lines returned for every call, unless [linesByPath] has a specific answer.
  List<OcrLine> lines;

  /// Per-file answers, keyed by `ImageInput.path`.
  final Map<String, List<OcrLine>> linesByPath = <String, List<OcrLine>>{};

  /// Inputs for which `recognize` should fail instead of answering.
  final Set<String> failingPaths = <String>{};

  /// A failure to return for every call, when set.
  AppFailure? failure;

  String language;
  String engineId = 'fake-ocr';
  Duration latency = Duration.zero;
  bool ready = true;

  int callCount = 0;

  /// Every input handed to [recognize], in order.
  final List<ImageInput> received = <ImageInput>[];

  /// Progress reports, so a test can prove the UI was told *something* while a
  /// slow recognition was running instead of showing a frozen screen.
  final List<double> progressCalls = <double>[];

  bool closed = false;

  @override
  String get id => engineId;

  @override
  String get displayName => 'Fake OCR';

  @override
  String get dataHandlingNote => 'Không gửi gì đi đâu (bản giả lập cho test).';

  @override
  bool get isReady => ready;

  @override
  Future<Result<OcrResult>> recognize(
    ImageInput image, {
    ProgressCallback? onProgress,
  }) async {
    callCount++;
    received.add(image);
    onProgress?.call(0, JobStage.runningOcr);
    progressCalls.add(0);

    if (latency > Duration.zero) await Future<void>.delayed(latency);

    final path = image.path ?? '';
    if (failure != null) return Failure<OcrResult>(failure!);
    if (failingPaths.contains(path)) {
      return const Failure(ProcessingFailure(
        message: 'Nhận dạng chữ trong ảnh thất bại.',
      ));
    }

    onProgress?.call(1, JobStage.runningOcr);
    progressCalls.add(1);

    return Success(OcrResult(
      lines: linesByPath[path] ?? lines,
      language: language,
      engineId: engineId,
    ));
  }

  @override
  Future<void> close() async {
    closed = true;
  }

  /// Convenience for building positioned lines, since a line without a position
  /// cannot exercise any of the structuring logic.
  static OcrLine line(
    String text, {
    double top = 0,
    double left = 0,
    double width = 1,
    double height = 0.02,
    double? confidence,
    int? pageNumber,
  }) =>
      OcrLine(
        text: text,
        confidence: confidence,
        pageNumber: pageNumber,
        position: BlockPosition(
          pageNumber: pageNumber,
          left: left,
          top: top,
          width: width,
          height: height,
        ),
      );
}
