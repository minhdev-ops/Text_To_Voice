import 'dart:typed_data' show Uint8List;

import 'package:image/image.dart' as img;

/// Synthetic captures for the imaging tests.
///
/// Deliberately generated rather than checked in as binary fixtures: a
/// committed JPEG is opaque in review, cannot be varied (skew 0° vs 4°, text or
/// no text), and its pixel values can drift when someone re-saves it. These
/// builders are readable and every parameter that matters for a test is visible
/// at the call site.
///
/// What they cannot cover is real OCR: no synthetic image tells us whether a
/// real engine reads Vietnamese diacritics correctly. That check needs a device
/// with the ML Kit model — see `document/ROADMAP.md`, Phase 2 acceptance.

/// A page on a desk: dark surround, bright sheet, optional text bars.
///
/// At default settings the page occupies ~84% of the frame and the surround is
/// 40/255 — roughly what a phone camera produces over a dark table.
img.Image syntheticCapture({
  int width = 900,
  int height = 1200,
  int backgroundLuma = 40,
  int pageLuma = 228,
  double pageInset = 0.08,
  int textLines = 0,
  int textLuma = 28,
  double rotationDegrees = 0,
  int noiseAmplitude = 0,
  int noiseSeed = 7,
}) {
  final image = img.Image(width: width, height: height);
  img.fill(
    image,
    color: img.ColorRgb8(backgroundLuma, backgroundLuma, backgroundLuma),
  );

  final insetX = (width * pageInset).round();
  final insetY = (height * pageInset).round();
  final pageLeft = insetX;
  final pageTop = insetY;
  final pageRight = width - insetX;
  final pageBottom = height - insetY;

  img.fillRect(
    image,
    x1: pageLeft,
    y1: pageTop,
    x2: pageRight,
    y2: pageBottom,
    color: img.ColorRgb8(pageLuma, pageLuma, pageLuma),
  );

  if (textLines > 0) {
    final pageWidth = pageRight - pageLeft;
    final pageHeight = pageBottom - pageTop;
    final margin = (pageWidth * 0.08).round();
    final lineHeight = (pageHeight * 0.010).round().clamp(2, 24);
    final lineGap = ((pageHeight * 0.88) / textLines).round();
    for (var i = 0; i < textLines; i++) {
      final y = pageTop + (pageHeight * 0.06).round() + i * lineGap;
      if (y + lineHeight >= pageBottom) break;
      // Ragged right edge, like real prose; a perfectly uniform block would let
      // a skew estimator cheat off the page edge instead of the text.
      final ragged = pageWidth - margin * 2 - ((i * 37) % (pageWidth ~/ 6));
      img.fillRect(
        image,
        x1: pageLeft + margin,
        y1: y,
        x2: pageLeft + margin + ragged.clamp(8, pageWidth - margin * 2),
        y2: y + lineHeight,
        color: img.ColorRgb8(textLuma, textLuma, textLuma),
      );
    }
  }

  if (noiseAmplitude > 0) {
    var state = noiseSeed;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        state = (state * 1103515245 + 12345) & 0x7fffffff;
        // High bits, not low: an LCG's low bits are strongly periodic, and
        // `state % 91` produced a visible lattice that the detector could latch
        // onto as a fake page edge. Real noise has to actually be noise.
        final delta =
            ((state >> 16) % (noiseAmplitude * 2 + 1)) - noiseAmplitude;
        final pixel = image.getPixel(x, y);
        image.setPixelRgb(
          x,
          y,
          (pixel.r + delta).clamp(0, 255),
          (pixel.g + delta).clamp(0, 255),
          (pixel.b + delta).clamp(0, 255),
        );
      }
    }
  }

  if (rotationDegrees == 0) return image;
  return img.copyRotate(
    image,
    angle: rotationDegrees,
    interpolation: img.Interpolation.cubic,
  );
}

/// A page whose paper and desk are the *same* brightness once noise is counted,
/// so no single threshold separates them.
///
/// This is the case that has to fail honestly rather than return a fake quad.
/// Two pure tones 8/255 apart would not be a hard case at all — Otsu splits a
/// clean bimodal histogram perfectly. The distributions have to overlap, which
/// is what a page on an identically-lit surface actually looks like.
img.Image lowContrastCapture({int width = 800, int height = 1000}) =>
    syntheticCapture(
      width: width,
      height: height,
      backgroundLuma: 150,
      pageLuma: 156,
      pageInset: 0.1,
      noiseAmplitude: 45,
    );

/// A uniformly bright frame — a photo of a wall, or a page filling the sensor.
img.Image flatCapture({int width = 640, int height = 640, int luma = 210}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(luma, luma, luma));
  return image;
}

/// Counts the pixels brighter than [threshold], as an independent reference for
/// what the page's area should be.
///
/// Self-calibrating on purpose: a hard-coded pixel count in the test would break
/// the moment a fixture size changed, and would not notice if the detector and
/// the fixture drifted apart together.
int brightPixelCount(img.Image image, {int threshold = 150}) {
  var count = 0;
  for (final pixel in image) {
    if (pixel.r > threshold) count++;
  }
  return count;
}

Uint8List pngBytes(img.Image image) => img.encodePng(image);

Uint8List jpegBytes(img.Image image, {int quality = 90}) =>
    img.encodeJpg(image, quality: quality);

/// A JPEG that claims an EXIF orientation of 6 ("rotate 90° CW").
///
/// The `image` package writes the orientation tag through to the encoded file,
/// which is what lets the normalizer's bake path be tested without a camera.
Uint8List jpegWithOrientation(img.Image image, int orientation) {
  image.exif.imageIfd.orientation = orientation;
  return img.encodeJpg(image, quality: 95);
}
