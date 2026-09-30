import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show immutable;
import 'package:image/image.dart' as img;

/// Facts about a decoded capture, kept because the review pane has to state what
/// actually came in — "4032×3024 · JPEG · còn nguyên" reads very differently
/// from "1600×1200 · PNG · đã nén lại", and a user debugging a blurry scan needs
/// to know which one they got.
@immutable
class DecodedImage {
  const DecodedImage({
    required this.image,
    required this.originalWidth,
    required this.originalHeight,
    required this.originalBytes,
    this.bakedExifHere = false,
  });

  final img.Image image;

  /// Dimensions as decoded — i.e. **after** any EXIF rotation, because that is
  /// what `image`'s decoders hand back.
  final int originalWidth;
  final int originalHeight;

  /// Size of the source bytes on disk.
  final int originalBytes;

  /// `true` only when this function had to bake the orientation itself.
  ///
  /// Verified in `package:image` 4.10.1: `getImageFromJpeg` applies the EXIF
  /// orientation while decoding and then **clears the tag**, so for every JPEG
  /// this flag is false and the pixels are already upright. It exists for the
  /// decoders that leave the tag in place (and for a future `image` release that
  /// changes behaviour): without it, a capture could be rotated twice — once by
  /// the decoder, once here — and land back on its side.
  final bool bakedExifHere;

  int get width => image.width;
  int get height => image.height;
}

/// The size band OCR wants.
///
/// Below ~1000 px on the long edge, Vietnamese diacritics collapse into their
/// base letters (`ế` → `e`), which is exactly the failure this app cannot have.
/// Above ~2600 px the extra pixels buy no accuracy and cost seconds per page on
/// a low-end phone (NFR-05).
abstract final class OcrSizeTarget {
  static const int minLongEdge = 1000;
  static const int maxLongEdge = 2600;
}

/// Decodes [bytes] and applies the EXIF orientation.
///
/// Returns `null` for anything the `image` package cannot identify, so the
/// caller reports a typed [ValidationFailure] instead of crashing on a corrupt
/// capture — SRS §38 requires validating by content, and a file that will not
/// decode is content that failed validation.
DecodedImage? decodeDocumentImage(Uint8List bytes) {
  // `img.decodeImage` sniffs the container; there is no extension to trust here.
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    return null;
  }
  if (decoded == null) return null;

  final originalWidth = decoded.width;
  final originalHeight = decoded.height;

  // Safety net for a decoder that leaves the EXIF tag in place. For JPEG the
  // tag is already gone by now (the decoder baked it and cleared it), so this
  // is a no-op there — which is the point: baking twice would put a portrait
  // capture back on its side and nothing else in the pipeline would notice.
  final orientation = decoded.exif.imageIfd.orientation;
  final shouldBake = orientation != null && orientation != 1;
  final upright = shouldBake ? img.bakeOrientation(decoded) : decoded;

  return DecodedImage(
    image: upright,
    originalWidth: originalWidth,
    originalHeight: originalHeight,
    originalBytes: bytes.length,
    bakedExifHere: shouldBake,
  );
}

/// Scales [source] into [OcrSizeTarget], preserving the aspect ratio.
///
/// Returns the same instance when it is already in band — copying an image that
/// needs nothing wastes 30 MB on a 12 MP capture.
img.Image normalizeForOcr(
  img.Image source, {
  int minLongEdge = OcrSizeTarget.minLongEdge,
  int maxLongEdge = OcrSizeTarget.maxLongEdge,
}) {
  final longEdge = source.width > source.height ? source.width : source.height;
  if (longEdge == 0) return source;

  final target = longEdge.clamp(minLongEdge, maxLongEdge);
  if (target == longEdge) return source;

  final scale = target / longEdge;
  // Resampling *up* uses linear interpolation: a small crop has no detail to
  // lose, and averaging would only soften the strokes OCR needs.
  return img.copyResize(
    source,
    width: (source.width * scale).round().clamp(1, 1 << 16),
    height: (source.height * scale).round().clamp(1, 1 << 16),
    interpolation: scale < 1 ? img.Interpolation.average : img.Interpolation.linear,
  );
}

/// Downscales for on-screen preview only. Never fed to OCR.
///
/// The review pane shows the enhanced page next to the text, and handing a
/// 2600 px bitmap to a 400 dp pane would decode it three times over for no
/// visible gain — and hold it in memory while the reader is open (NFR-04).
img.Image makePreview(
  img.Image source, {
  int maxDimension = 900,
}) {
  final longEdge = source.width > source.height ? source.width : source.height;
  if (longEdge <= maxDimension) return source;
  final scale = maxDimension / longEdge;
  return img.copyResize(
    source,
    width: (source.width * scale).round().clamp(1, 1 << 16),
    height: (source.height * scale).round().clamp(1, 1 << 16),
    interpolation: img.Interpolation.average,
  );
}

Uint8List encodePng(img.Image image) => img.encodePng(image, level: 6);

Uint8List encodeJpeg(img.Image image, {int quality = 82}) =>
    img.encodeJpg(image, quality: quality);
