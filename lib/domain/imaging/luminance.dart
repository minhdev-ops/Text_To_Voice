import 'dart:typed_data' show Uint8List;

import 'package:image/image.dart' as img;

/// A flat, single-channel luminance buffer.
///
/// `img.Image.getPixel` returns a fresh `Pixel` object on every call. The
/// detector alone would make several million of those per capture, and the skew
/// estimator samples the image along a tilted line for every candidate angle —
/// tens of millions. Reading the image once into a `Uint8List` turns every later
/// access into an array index, which is the difference between a scan that feels
/// instant and one that drops frames (NFR-05).
class LuminancePlane {
  const LuminancePlane(this.width, this.height, this.pixels);

  final int width;
  final int height;
  final Uint8List pixels;

  int at(int x, int y) => pixels[y * width + x];

  bool contains(int x, int y) => x >= 0 && y >= 0 && x < width && y < height;

  int get longestEdge => width > height ? width : height;
}

/// Builds a luminance plane, downscaling so the longest edge is at most
/// [maxDimension].
///
/// Downscaling uses [img.Interpolation.average] because these consumers are all
/// looking for *edges* — averaging preserves them, whereas nearest-neighbour
/// keeps single-pixel speckle that reads as an edge to a threshold-based
/// detector.
LuminancePlane buildLuminancePlane(
  img.Image source, {
  int maxDimension = 480,
}) {
  var working = source;
  final longest = source.width > source.height ? source.width : source.height;
  if (longest > maxDimension) {
    final scale = maxDimension / longest;
    working = img.copyResize(
      working,
      width: (source.width * scale).round().clamp(4, 1 << 16),
      height: (source.height * scale).round().clamp(4, 1 << 16),
      interpolation: img.Interpolation.average,
    );
  }

  final width = working.width;
  final height = working.height;
  final pixels = Uint8List(width * height);
  var index = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final pixel = working.getPixel(x, y);
      // Rec. 601 luma, the weights every OCR pipeline uses.
      final luma = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b).round();
      pixels[index++] = luma.clamp(0, 255);
    }
  }
  return LuminancePlane(width, height, pixels);
}
