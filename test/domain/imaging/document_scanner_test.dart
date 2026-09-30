import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:text_to_voice/core/result/result.dart';
import 'package:text_to_voice/domain/imaging/document_scanner.dart';
import 'package:text_to_voice/domain/imaging/enhancement.dart';
import 'package:text_to_voice/domain/imaging/image_geometry.dart';
import 'package:text_to_voice/domain/imaging/image_normalizer.dart';

import '../../support/image_fixtures.dart';

void main() {
  group('decodeDocumentImage', () {
    test('decodes a PNG and reports its real size', () {
      final decoded = decodeDocumentImage(pngBytes(syntheticCapture(
        width: 300,
        height: 400,
      )));
      expect(decoded, isNotNull);
      expect(decoded!.width, 300);
      expect(decoded.height, 400);
      expect(decoded.originalWidth, 300);
      expect(decoded.originalBytes, greaterThan(0));
    });

    test('refuses bytes that are not an image', () {
      final garbage = Uint8List.fromList(
        List<int>.generate(256, (i) => (i * 37) % 256),
      );
      expect(decodeDocumentImage(garbage), isNull);
    });

    test('a sideways JPEG comes back upright', () {
      final source = syntheticCapture(width: 300, height: 400);
      final bytes = jpegWithOrientation(source, 6); // "rotate 90° CW"
      final decoded = decodeDocumentImage(bytes);

      expect(decoded, isNotNull);
      // Orientation 6 swaps the axes, and the decoder does it for us: a
      // 300×400 file tagged 6 decodes to 400×300, already upright.
      expect(decoded!.width, 400);
      expect(decoded.height, 300);
      // And we must not rotate it a second time.
      expect(decoded.bakedExifHere, isFalse);
    });

    test('an upright JPEG keeps its dimensions', () {
      final decoded = decodeDocumentImage(
        jpegBytes(syntheticCapture(width: 200, height: 260)),
      );
      expect(decoded!.width, 200);
      expect(decoded.height, 260);
      expect(decoded.bakedExifHere, isFalse);
    });
  });

  group('normalizeForOcr', () {
    test('scales a small capture up so diacritics survive', () {
      final small = syntheticCapture(width: 400, height: 300);
      final normalized = normalizeForOcr(small);
      expect(normalized.width, OcrSizeTarget.minLongEdge);
      expect(normalized.height, (300 * (OcrSizeTarget.minLongEdge / 400)).round());
      // Aspect ratio preserved.
      expect(normalized.width / normalized.height,
          closeTo(400 / 300, 0.01));
    });

    test('scales a 12 MP capture down to the OCR ceiling', () {
      final huge = img.Image(width: 4000, height: 3000);
      final normalized = normalizeForOcr(huge);
      expect(normalized.width, OcrSizeTarget.maxLongEdge);
      expect(normalized.height, 1950);
    });

    test('leaves an in-band image alone, without copying it', () {
      final inBand = syntheticCapture(width: 1600, height: 2000);
      expect(identical(normalizeForOcr(inBand), inBand), isTrue);
    });
  });

  group('makePreview', () {
    test('caps the long edge', () {
      final big = syntheticCapture(width: 2000, height: 3000);
      final preview = makePreview(big, maxDimension: 600);
      expect(preview.height, 600);
      expect(preview.width, 400);
    });

    test('returns the same image when it is already small enough', () {
      final small = syntheticCapture(width: 200, height: 200);
      expect(identical(makePreview(small), small), isTrue);
    });
  });

  group('DocumentScanner.scan', () {
    test('runs off the UI isolate and returns a corrected page', () async {
      final capture = syntheticCapture(
        width: 900,
        height: 1200,
        pageInset: 0.1,
        textLines: 14,
      );

      const scanner = DocumentScanner();
      final result = await scanner.scan(ScanRequest(bytes: pngBytes(capture)));

      final outcome = result.valueOrNull;
      expect(result.isSuccess, isTrue, reason: '$result');
      expect(outcome, isNotNull);
      expect(outcome!.sourceWidth, 900);
      expect(outcome.sourceHeight, 1200);
      expect(outcome.detection, isNotNull);
      expect(outcome.detection!.found, isTrue);

      // The corrected page is a real PNG that decodes to the reported size.
      final decoded = img.decodeImage(outcome.enhancedBytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, outcome.processedWidth);
      expect(decoded.height, outcome.processedHeight);

      // The preview is smaller than the page and also decodable.
      final preview = img.decodeImage(outcome.previewBytes);
      expect(preview, isNotNull);
      expect(preview!.width, lessThanOrEqualTo(900));

      expect(outcome.report.applied, isNotEmpty);
      expect(outcome.report.summary, isNotEmpty);
    });

    test('an undetectable page still returns an image, and says why', () async {
      final capture = flatCapture(width: 400, height: 400);
      const scanner = DocumentScanner();
      final result = await scanner.scan(ScanRequest(bytes: pngBytes(capture)));

      final outcome = result.valueOrNull!;
      expect(outcome.detection!.found, isFalse);
      expect(outcome.detection!.notFoundReason, isNotNull);
      // Falling back to the whole frame is a valid outcome, not a failure.
      expect(outcome.processedWidth, greaterThan(0));
      expect(outcome.processedHeight, greaterThan(0));
    });

    test('the original plan leaves the page unenhanced', () async {
      final capture = syntheticCapture(
        width: 600,
        height: 800,
        pageInset: 0.1,
      );
      const scanner = DocumentScanner();
      final result = await scanner.scan(
        ScanRequest(bytes: pngBytes(capture), plan: EnhancementPlan.original),
      );

      final outcome = result.valueOrNull!;
      expect(outcome.report.applied, isEmpty);
      expect(outcome.report.summary, contains('Bản gốc'));
    });

    test('a user-supplied quad wins over detection', () async {
      final capture = syntheticCapture(width: 800, height: 800, pageInset: 0.2);
      const scanner = DocumentScanner();
      final first = (await scanner.detect(ScanRequest(bytes: pngBytes(capture))))
          .valueOrNull!;

      // Draw a crop over the middle half of the normalized image.
      final manual = ImageQuad(
        topLeft: ImagePoint(first.processedWidth * 0.25, first.processedHeight * 0.25),
        topRight: ImagePoint(first.processedWidth * 0.75, first.processedHeight * 0.25),
        bottomRight:
            ImagePoint(first.processedWidth * 0.75, first.processedHeight * 0.75),
        bottomLeft:
            ImagePoint(first.processedWidth * 0.25, first.processedHeight * 0.75),
      );

      final result = await scanner.scan(
        ScanRequest(bytes: pngBytes(capture), quad: manual),
      );
      final outcome = result.valueOrNull!;
      expect(outcome.detection, isNull, reason: 'detection must not re-run');
      expect(outcome.report.cropped, isTrue);
      expect(outcome.processedWidth,
          closeTo(first.processedWidth * 0.5, first.processedWidth * 0.05));
    });

    test('bytes that are not an image fail with a validation message', () async {
      const scanner = DocumentScanner();
      final result = await scanner.scan(
        ScanRequest(bytes: Uint8List.fromList(List<int>.filled(512, 7))),
      );
      expect(result.isSuccess, isFalse);
      final failure = result.failureOrNull;
      expect(failure, isA<ValidationFailure>());
      expect(failure!.message, contains('Không đọc được ảnh'));
    });

    test('detect() does not run the enhancement pass', () async {
      final capture = syntheticCapture(width: 700, height: 900, pageInset: 0.1);
      const scanner = DocumentScanner();
      final outcome =
          (await scanner.detect(ScanRequest(bytes: pngBytes(capture)))).valueOrNull!;
      expect(outcome.detection!.found, isTrue);
      expect(outcome.report.applied, isEmpty);
    });
  });

  group('rescaleQuad', () {
    test('maps a quad between image spaces', () {
      final quad = ImageQuad.fullFrame(100, 200);
      final scaled = rescaleQuad(
        quad,
        fromWidth: 100,
        fromHeight: 200,
        toWidth: 400,
        toHeight: 100,
      )!;
      expect(scaled.topLeft, const ImagePoint(0, 0));
      expect(scaled.topRight, const ImagePoint(400, 0));
      expect(scaled.bottomRight, const ImagePoint(400, 100));
    });

    test('a null quad stays null and a zero-width source is refused', () {
      expect(
        rescaleQuad(null, fromWidth: 10, fromHeight: 10, toWidth: 20, toHeight: 20),
        isNull,
      );
      expect(
        rescaleQuad(
          ImageQuad.fullFrame(10, 10),
          fromWidth: 0,
          fromHeight: 10,
          toWidth: 20,
          toHeight: 20,
        ),
        isNull,
      );
    });
  });

  group('scanSynchronously', () {
    test('the same pipeline runs without an isolate for callers that have one',
        () {
      final capture = syntheticCapture(width: 500, height: 700, pageInset: 0.1);
      final outcome = scanSynchronously(ScanRequest(bytes: jpegBytes(capture)));
      expect(outcome, isNotNull);
      expect(outcome!.detection!.found, isTrue);
      expect(outcome.enhancedBytes, isNotEmpty);
    });

    test('returns null rather than guessing when the bytes are unreadable', () {
      expect(
        scanSynchronously(
          ScanRequest(bytes: Uint8List.fromList(List<int>.filled(64, 1))),
        ),
        isNull,
      );
    });
  });
}
