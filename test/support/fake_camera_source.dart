import 'dart:typed_data' show Uint8List;

import 'package:flutter/widgets.dart' show Key, SizedBox, Widget;
import 'package:text_to_voice/core/result/result.dart';
import 'package:text_to_voice/presentation/capture/camera_source.dart';

/// A camera the test drives, so the capture flow's permission, capture and
/// error paths can be exercised on a machine with no camera.
///
/// Mirrors the fakes used elsewhere in the project (`FakeTtsEngine`,
/// `FakeOcrEngine`, `FakeAudioOutput`): every answer can be scripted, every call
/// is counted, and the recorded arguments are asserted on. Without the last part a
/// test can only show that a frame came back, not that the resolution the user
/// picked is the one that was asked for.
class FakeCameraSource implements CameraSource {
  FakeCameraSource({
    this.supported = true,
    List<CameraInfo>? cameras,
    List<Uint8List>? frames,
  })  : cameras = cameras ??
            const <CameraInfo>[
              CameraInfo(id: 'back-0', facing: CameraFacing.back),
            ],
        frames = frames ?? <Uint8List>[];

  bool supported;
  List<CameraInfo> cameras;

  /// Frames handed back by [capture], in order. When it runs out, the last one
  /// repeats — a multi-page test should not have to pre-build N identical shots.
  List<Uint8List> frames;

  AppFailure? discoverFailure;
  AppFailure? openFailure;
  AppFailure? captureFailure;

  int discoverCount = 0;
  int openCount = 0;
  int captureCount = 0;
  bool closed = false;
  bool opened = false;

  String? lastCameraId;
  CaptureResolution? lastResolution;

  @override
  bool get isSupported => supported;

  @override
  Future<Result<List<CameraInfo>>> discover() async {
    discoverCount++;
    final failure = discoverFailure;
    if (failure != null) return Failure<List<CameraInfo>>(failure);
    return Success<List<CameraInfo>>(cameras);
  }

  @override
  Future<Result<void>> open(
    CameraInfo info, {
    required CaptureResolution resolution,
  }) async {
    openCount++;
    lastCameraId = info.id;
    lastResolution = resolution;
    final failure = openFailure;
    if (failure != null) return Failure<void>(failure);
    opened = true;
    return const Success<void>(null);
  }

  @override
  Widget buildPreview() =>
      const SizedBox(key: previewKey, width: 8, height: 8);

  @override
  Future<Result<CapturedFrame>> capture() async {
    captureCount++;
    final failure = captureFailure;
    if (failure != null) return Failure<CapturedFrame>(failure);
    if (frames.isEmpty) {
      return const Failure<CapturedFrame>(ProcessingFailure(
        message: 'FakeCameraSource has no frames queued.',
      ));
    }
    final index = (captureCount - 1).clamp(0, frames.length - 1);
    return Success<CapturedFrame>(CapturedFrame(bytes: frames[index]));
  }

  @override
  Future<void> close() async {
    closed = true;
    opened = false;
  }

  /// A preview key a widget test can find.
  static const Key previewKey = Key('fake-camera-preview');
}
