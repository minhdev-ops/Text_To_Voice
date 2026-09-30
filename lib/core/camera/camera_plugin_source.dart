import 'package:camera/camera.dart' as cam;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/widgets.dart' show SizedBox, Widget;

import '../../presentation/capture/camera_source.dart';
import '../logging/app_log.dart';
import '../result/result.dart';

/// The real camera, and the **only** file in the project that imports
/// `package:camera`.
///
/// Everything else talks to [CameraSource], which is what lets the capture screen,
/// its permission flow and its error states be tested on a machine with no
/// camera — see `test/support/fake_camera_source.dart`.
class CameraPluginSource implements CameraSource {
  CameraPluginSource();

  cam.CameraController? _controller;
  bool _opened = false;

  /// Cameras are enumerated once per process: `availableCameras()` is a channel
  /// round-trip, and calling it on every screen entry adds a visible stall before
  /// the preview appears.
  static List<cam.CameraDescription>? _cached;

  /// The platforms the `camera` plugin actually implements. On Linux, Windows or
  /// web the honest answer is "no camera here", so the capture screen offers file
  /// import instead of a dead preview.
  ///
  /// Asked through `defaultTargetPlatform` rather than `Platform.isAndroid` so it
  /// is also correct inside a widget test, where `dart:io` reports the host OS.
  @override
  bool get isSupported =>
      !kIsWeb &&
      const <TargetPlatform>{
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      }.contains(defaultTargetPlatform);

  @override
  Future<Result<List<CameraInfo>>> discover() async {
    if (!isSupported) {
      return const Failure(UnsupportedFormatFailure(
        message: 'Thiết bị này không có camera.',
        extension: '',
      ));
    }
    try {
      final cameras = _cached ??= await cam.availableCameras();
      if (cameras.isEmpty) {
        return Failure(PermissionFailure(
          message: 'Không tìm thấy camera nào trên máy.',
          permission: 'camera',
        ));
      }
      return Success(List<CameraInfo>.unmodifiable(cameras.map(_toInfo)));
    } on cam.CameraException catch (error) {
      return Failure(_mapError(error));
    } catch (error) {
      return Failure(UnexpectedFailure(
        message: 'Không mở được camera.',
        detail: error.toString(),
        cause: error,
      ));
    }
  }

  @override
  Future<Result<void>> open(
    CameraInfo info, {
    required CaptureResolution resolution,
  }) async {
    await close();
    try {
      final cameras = _cached ??= await cam.availableCameras();
      final description = cameras.firstWhere(
        (camera) => camera.name == info.id,
        orElse: () => cameras.first,
      );

      final controller = cam.CameraController(
        description,
        _preset(resolution),
        // Audio is never needed and asking for it is one more permission prompt
        // for a feature that does not exist.
        enableAudio: false,
      );
      await controller.initialize();
      _controller = controller;
      _opened = true;
      AppLog.debug('camera.open', data: {'camera': info.id});
      return const Success(null);
    } on cam.CameraException catch (error) {
      return Failure(_mapError(error));
    } catch (error) {
      return Failure(UnexpectedFailure(
        message: 'Không mở được camera.',
        detail: error.toString(),
        cause: error,
      ));
    }
  }

  @override
  Widget buildPreview() {
    final controller = _controller;
    if (controller == null || !_opened) {
      // The caller must not reach here (the screen shows file import instead),
      // but a blank box beats a crash.
      return const SizedBox.shrink();
    }
    return cam.CameraPreview(controller);
  }

  @override
  Future<Result<CapturedFrame>> capture() async {
    final controller = _controller;
    if (controller == null || !_opened) {
      return const Failure(ProcessingFailure(
        message: 'Camera chưa sẵn sàng.',
        retryable: true,
      ));
    }
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      return Success(CapturedFrame(bytes: bytes, mimeType: 'image/jpeg'));
    } on cam.CameraException catch (error) {
      return Failure(_mapError(error));
    } catch (error) {
      return Failure(ProcessingFailure(
        message: 'Chụp ảnh thất bại.',
        detail: error.toString(),
        cause: error,
      ));
    }
  }

  @override
  Future<void> close() async {
    final controller = _controller;
    _controller = null;
    _opened = false;
    try {
      await controller?.dispose();
    } catch (error) {
      AppLog.warning('camera.close', data: {'error': error.toString()});
    }
  }

  static CameraInfo _toInfo(cam.CameraDescription description) => CameraInfo(
        id: description.name,
        facing: description.lensDirection == cam.CameraLensDirection.front
            ? CameraFacing.front
            : CameraFacing.back,
        sensorOrientation: description.sensorOrientation,
      );

  static cam.ResolutionPreset _preset(CaptureResolution resolution) =>
      switch (resolution) {
        CaptureResolution.standard => cam.ResolutionPreset.medium,
        CaptureResolution.high => cam.ResolutionPreset.high,
        CaptureResolution.maximum => cam.ResolutionPreset.max,
      };

  /// Maps the plugin's error codes to the app's typed failures.
  ///
  /// `CameraAccessDenied` is the one that matters: it is the difference between
  /// "ask again" and "you must open Settings", and the UX spec requires those two
  /// to be different screens.
  static AppFailure _mapError(cam.CameraException error) {
    final denied = error.code == 'CameraAccessDenied' ||
        error.code == 'CameraAccessDeniedWithoutPrompt' ||
        error.code == 'CameraAccessRestricted';
    if (denied) {
      return PermissionFailure(
        message: 'VietDoc AI cần quyền dùng camera để chụp tài liệu. '
            'Bạn có thể cấp lại trong phần Cài đặt của máy, hoặc chọn ảnh có '
            'sẵn.',
        permission: 'camera',
        cause: error,
      );
    }
    return ProcessingFailure(
      message: 'Camera gặp lỗi.',
      detail: '${error.code}: ${error.description ?? ""}',
      cause: error,
    );
  }
}
