import 'dart:typed_data' show Uint8List;

import 'package:flutter/widgets.dart' show Widget;
import 'package:flutter/foundation.dart' show immutable;

import '../../core/result/result.dart';

/// Which physical camera to use (FR-03).
enum CameraFacing { back, front }

/// A camera the device reports.
@immutable
class CameraInfo {
  const CameraInfo({
    required this.id,
    required this.facing,
    this.sensorOrientation = 90,
  });

  /// Platform identifier — opaque, only ever passed back to the source.
  final String id;

  final CameraFacing facing;

  /// Degrees the sensor is rotated from the display's natural orientation.
  /// Needed to explain a sideways preview rather than guess at it.
  final int sensorOrientation;

  /// Vietnamese label for the lens switcher.
  String get label => facing == CameraFacing.front ? 'Trước' : 'Sau';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CameraInfo &&
          other.id == id &&
          other.facing == facing &&
          other.sensorOrientation == sensorOrientation);

  @override
  int get hashCode => Object.hash(id, facing, sensorOrientation);

  @override
  String toString() => 'CameraInfo($id, ${facing.name})';
}

/// How large a capture to ask for.
///
/// The app's own enum rather than the plugin's `ResolutionPreset`: the OCR
/// pipeline cares about "enough pixels for diacritics, not so many that a page
/// takes a second to decode", and that is a product decision, not a plugin one.
enum CaptureResolution { standard, high, maximum }

/// One frame, already in memory.
///
/// [width] and [height] are the **decoded** dimensions when the source knows
/// them. They are optional because a source that hands back encoded bytes may not
/// have decoded them, and inventing them here would corrupt the normalized OCR
/// coordinates downstream.
@immutable
class CapturedFrame {
  const CapturedFrame({
    required this.bytes,
    this.width,
    this.height,
    this.mimeType = 'image/jpeg',
  });

  final Uint8List bytes;
  final int? width;
  final int? height;
  final String mimeType;

  @override
  String toString() =>
      'CapturedFrame(${bytes.length} bytes, ${width ?? "?"}×${height ?? "?"})';
}

/// The camera, as the app uses it.
///
/// The port lives in `presentation/` rather than `domain/` on purpose: it hands
/// back a `Widget` for the live preview, and a domain interface that returns
/// widgets would drag Flutter into the layer that is meant to be testable without
/// it. Recognition and parsing have no such need, which is why those ports *are*
/// in `domain/engines/`.
///
/// Everything that can fail — no camera, no permission, camera busy — comes back as
/// a typed [AppFailure] instead of an exception, so the capture screen can render
/// the honest state the UX spec asks for (`Open settings` plus a `Choose file`
/// fallback) rather than a generic error.
abstract interface class CameraSource {
  /// `false` on a platform with no camera at all (desktop, web build). The
  /// capture screen then offers file import as the only path instead of showing a
  /// dead preview.
  bool get isSupported;

  Future<Result<List<CameraInfo>>> discover();

  Future<Result<void>> open(CameraInfo info, {required CaptureResolution resolution});

  /// The live preview. Only valid between [open] and [close].
  Widget buildPreview();

  Future<Result<CapturedFrame>> capture();

  Future<void> close();
}
