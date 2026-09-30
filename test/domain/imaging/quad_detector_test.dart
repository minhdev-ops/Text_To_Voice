import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:text_to_voice/domain/imaging/image_geometry.dart';
import 'package:text_to_voice/domain/imaging/quad_detector.dart';

import '../../support/image_fixtures.dart';

/// Tolerance is expressed as a fraction of the frame, not in pixels: the
/// detector works on a 480-px copy, so a fixed pixel tolerance would either be
/// meaningless at one fixture size or impossible at another.
double _frameFraction(double absolute, img.Image frame) =>
    absolute / (frame.width > frame.height ? frame.width : frame.height);

void main() {
  group('detectDocumentQuad', () {
    test('finds an axis-aligned page inset in a dark frame', () {
      final capture = syntheticCapture(width: 900, height: 1200, pageInset: 0.08);
      final detection = detectDocumentQuad(capture);

      expect(detection.found, isTrue, reason: detection.notFoundReason ?? '');
      expect(detection.confidence, greaterThan(0.5));

      final quad = detection.quad!;
      // The page is inset by 8% on every side: 72 px of 900, 96 px of 1200.
      expect(quad.topLeft.x, closeTo(72, 900 * 0.03));
      expect(quad.topLeft.y, closeTo(96, 1200 * 0.03));
      expect(quad.bottomRight.x, closeTo(828, 900 * 0.03));
      expect(quad.bottomRight.y, closeTo(1104, 1200 * 0.03));
    });

    test('finds a rotated page and reports a tilted quad', () {
      final capture = syntheticCapture(
        width: 900,
        height: 1200,
        pageInset: 0.12,
        rotationDegrees: 5,
      );
      final detection = detectDocumentQuad(capture);

      expect(detection.found, isTrue, reason: detection.notFoundReason ?? '');
      final quad = detection.quad!;
      expect(quad.isAxisAligned, isFalse);
      final topEdgeTilt =
          (quad.topRight.y - quad.topLeft.y).abs();
      expect(_frameFraction(topEdgeTilt, capture), greaterThan(0.01));

      // The page is the dominant object, so the quad should cover roughly the
      // page's own area — measured from the pixels, not from the fixture's
      // nominal inset (the rotation also grows the canvas).
      final pageArea = brightPixelCount(capture).toDouble();
      expect(quad.area, closeTo(pageArea, pageArea * 0.2));
    });

    test('a page the same brightness as the desk is refused, with a reason', () {
      final capture = lowContrastCapture();
      final detection = detectDocumentQuad(capture);

      expect(detection.found, isFalse);
      expect(detection.notFoundReason, isNotNull);
      expect(detection.notFoundReason, isNotEmpty);
      // The message has to name what was wrong, not just say "failed".
      expect(detection.notFoundReason!.toLowerCase(), contains('viền'));
    });

    test('a flat frame reports that there is nothing to threshold against', () {
      final detection = detectDocumentQuad(flatCapture());
      expect(detection.found, isFalse);
      // One tone: Otsu has no between-class variance to work with at all.
      expect(detection.separability, 0);
      expect(detection.notFoundReason, contains('độ sáng'));
      expect(detection.notFoundReason, contains('Kéo góc bằng tay'));
    });

    test('a page filling the whole frame falls back to the whole frame', () {
      final capture = syntheticCapture(width: 400, height: 400, pageInset: 0);
      final detection = detectDocumentQuad(capture);
      // A page that fills the sensor is indistinguishable from a photo of a
      // blank wall, and the detector is not allowed to pretend otherwise. The
      // *effective* quad is still correct — it is the whole frame — and the
      // fallback is reached through the honest "not found" path, so the UI can
      // say "dùng toàn bộ ảnh" instead of claiming a detection.
      expect(detection.found, isFalse);
      expect(detection.quad, isNull);
      expect(detection.notFoundReason, isNotNull);
      expect(detection.effectiveQuad, ImageQuad.fullFrame(400, 400));
    });

    test('a capture below the minimum size is refused before any scan', () {
      final detection = detectDocumentQuad(img.Image(width: 8, height: 8));
      expect(detection.found, isFalse);
      expect(detection.notFoundReason, contains('quá nhỏ'));
    });

    test('noise on top of a real page does not break detection', () {
      final capture = syntheticCapture(
        width: 800,
        height: 1000,
        pageInset: 0.1,
        noiseAmplitude: 18,
      );
      final detection = detectDocumentQuad(capture);
      expect(detection.found, isTrue, reason: detection.notFoundReason ?? '');
    });

    test('a dark page on a bright desk is detected (polarity is not assumed)', () {
      // Scanned-print scenario inverted: white desk, dark document.
      final capture = syntheticCapture(
        width: 700,
        height: 900,
        backgroundLuma: 235,
        pageLuma: 60,
        pageInset: 0.15,
      );
      final detection = detectDocumentQuad(capture);
      expect(detection.found, isTrue, reason: detection.notFoundReason ?? '');
      expect(detection.quad!.topLeft.x, closeTo(105, 700 * 0.05));
    });

    test('a speckled page does not drag the fitted edge to the speckle', () {
      final capture = syntheticCapture(
        width: 800,
        height: 1000,
        pageInset: 0.1,
        noiseAmplitude: 60,
      );
      final detection = detectDocumentQuad(capture);
      if (detection.found) {
        // With 60/255 of noise, Otsu can put outliers well outside the page.
        // The robust fit is what keeps the answer near the true edge.
        expect(detection.quad!.topLeft.x, closeTo(80, 800 * 0.06));
      } else {
        expect(detection.notFoundReason, isNotNull);
      }
    });

    test('effectiveQuad falls back to the frame, and says it did', () {
      final detection = detectDocumentQuad(flatCapture(width: 300, height: 200));
      expect(detection.found, isFalse);
      expect(detection.quad, isNull);
      final fallback = detection.effectiveQuad;
      expect(fallback.area, closeTo(300 * 200, 1));
      expect(detection.frameWidth, 300);
      expect(detection.frameHeight, 200);
    });

    test('the working resolution does not change the answer', () {
      final capture = syntheticCapture(width: 1200, height: 1600, pageInset: 0.1);
      final coarse = detectDocumentQuad(
        capture,
        options: const QuadDetectionOptions(workingMaxDimension: 320),
      );
      final finer = detectDocumentQuad(
        capture,
        options: const QuadDetectionOptions(workingMaxDimension: 720),
      );
      expect(coarse.found, isTrue);
      expect(finer.found, isTrue);
      expect(
        coarse.quad!.topLeft.x,
        closeTo(finer.quad!.topLeft.x, 1200 * 0.02),
      );
      expect(
        coarse.quad!.bottomRight.y,
        closeTo(finer.quad!.bottomRight.y, 1600 * 0.02),
      );
    });
  });
}
