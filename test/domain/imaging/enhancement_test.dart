import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:text_to_voice/domain/imaging/enhancement.dart';
import 'package:text_to_voice/domain/imaging/image_geometry.dart';

import '../../support/image_fixtures.dart';

double _spread(img.Image image) {
  var low = 255;
  var high = 0;
  for (final pixel in image) {
    final luma = pixel.r.round();
    if (luma < low) low = luma;
    if (luma > high) high = luma;
  }
  return (high - low) / 255;
}

void main() {
  group('EnhancementPlan', () {
    test('the default plan leaves denoise off', () {
      expect(
        EnhancementPlan.ocrDefault.isEnabled(EnhancementStep.denoise),
        isFalse,
      );
      expect(
        EnhancementPlan.ocrDefault.isEnabled(EnhancementStep.perspectiveCorrect),
        isTrue,
      );
    });

    test('the original plan runs nothing', () {
      expect(EnhancementPlan.original.isEmpty, isTrue);
      expect(EnhancementPlan.everything.steps.length,
          EnhancementStep.values.length);
    });

    test('toggling is explicit in both directions', () {
      final on = EnhancementPlan.original.toggle(EnhancementStep.grayscale);
      expect(on.isEnabled(EnhancementStep.grayscale), isTrue);
      final off = on.toggle(EnhancementStep.grayscale, false);
      expect(off.isEnabled(EnhancementStep.grayscale), isFalse);
      // Toggling back off restores the original plan exactly.
      expect(off, EnhancementPlan.original);
    });

    test('equality ignores the order steps were added in', () {
      final a = EnhancementPlan(<EnhancementStep>{
        EnhancementStep.grayscale,
        EnhancementStep.contrast,
      });
      final b = EnhancementPlan(<EnhancementStep>{
        EnhancementStep.contrast,
        EnhancementStep.grayscale,
      });
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('EnhancementPipeline.rectify', () {
    test('an axis-aligned quad is a crop, not a resample', () {
      final source = syntheticCapture(width: 400, height: 600, pageInset: 0.1);
      const quad = ImageQuad(
        topLeft: ImagePoint(40, 60),
        topRight: ImagePoint(240, 60),
        bottomRight: ImagePoint(240, 360),
        bottomLeft: ImagePoint(40, 360),
      );

      final cropped = EnhancementPipeline.rectify(source, quad)!;
      expect(cropped.width, 200);
      expect(cropped.height, 300);
      // Interior pixel: the page is 228, the desk 40.
      expect(cropped.getPixel(100, 150).r.round(), 228);
    });

    test('a tilted quad is warped to the size of its own edges', () {
      final source = syntheticCapture(width: 600, height: 600, pageInset: 0.1);
      const quad = ImageQuad(
        topLeft: ImagePoint(60, 80),
        topRight: ImagePoint(540, 60),
        bottomRight: ImagePoint(520, 540),
        bottomLeft: ImagePoint(80, 520),
      );

      final warped = EnhancementPipeline.rectify(source, quad)!;
      // Width from the longer horizontal edge, height from the longer vertical.
      expect(warped.width, greaterThan(440));
      expect(warped.height, greaterThan(440));
      // The middle of the warped page is still paper.
      expect(
        warped.getPixel(warped.width ~/ 2, warped.height ~/ 2).r.round(),
        greaterThan(180),
      );
    });

    test('a degenerate quad is refused rather than warped', () {
      final source = syntheticCapture(width: 200, height: 200);
      const sliver = ImageQuad(
        topLeft: ImagePoint(10, 10),
        topRight: ImagePoint(14, 10),
        bottomRight: ImagePoint(14, 14),
        bottomLeft: ImagePoint(10, 14),
      );
      expect(EnhancementPipeline.rectify(source, sliver), isNull);
    });

    test('corners outside the frame are clamped before sampling', () {
      final source = syntheticCapture(width: 200, height: 200);
      const overshoot = ImageQuad(
        topLeft: ImagePoint(-30, -30),
        topRight: ImagePoint(230, -30),
        bottomRight: ImagePoint(230, 230),
        bottomLeft: ImagePoint(-30, 230),
      );
      final cropped = EnhancementPipeline.rectify(source, overshoot);
      expect(cropped, isNotNull);
      expect(cropped!.width, lessThanOrEqualTo(200));
      expect(cropped.height, lessThanOrEqualTo(200));
    });
  });

  group('EnhancementPipeline.apply', () {
    test('the original plan returns the same pixels and says so', () {
      final source = syntheticCapture(width: 200, height: 300);
      final result = EnhancementPipeline.apply(
        source,
        plan: EnhancementPlan.original,
      );
      expect(result.image.width, source.width);
      expect(result.report.applied, isEmpty);
      expect(result.report.summary, contains('Bản gốc'));
      expect(result.report.notes, isEmpty);
    });

    test('grayscale really drops to one channel', () {
      final source = syntheticCapture(width: 120, height: 120);
      final result = EnhancementPipeline.apply(
        source,
        plan: const EnhancementPlan(<EnhancementStep>{
          EnhancementStep.grayscale,
        }),
      );
      expect(result.image.numChannels, 1);
      expect(result.report.applied, <EnhancementStep>[
        EnhancementStep.grayscale,
      ]);
    });

    test('contrast stretches a washed-out capture', () {
      // 120/140 is a 20-level spread — a phone photo in flat office light.
      final flat = syntheticCapture(
        width: 300,
        height: 400,
        backgroundLuma: 120,
        pageLuma: 140,
      );
      final before = _spread(flat);

      final result = EnhancementPipeline.apply(
        flat,
        plan: const EnhancementPlan(<EnhancementStep>{
          EnhancementStep.contrast,
        }),
      );
      expect(_spread(result.image), greaterThan(before));
      expect(_spread(result.image), greaterThan(0.9));
    });

    test('a step that has nothing to do is reported, not silently skipped', () {
      final source = syntheticCapture(width: 300, height: 400);
      final result = EnhancementPipeline.apply(
        source,
        plan: const EnhancementPlan(<EnhancementStep>{
          EnhancementStep.perspectiveCorrect,
        }),
        // No quad at all: the review pane has not decided the crop yet.
        quad: null,
      );
      expect(result.report.applied, isEmpty);
      expect(result.report.notes.single, contains('chưa xác định được viền'));
    });

    test('steps run in the documented order regardless of plan order', () {
      final source = syntheticCapture(width: 300, height: 400, pageInset: 0.1);
      final quad = ImageQuad.insetFrame(300, 400, 30);
      final result = EnhancementPipeline.apply(
        source,
        plan: EnhancementPlan(<EnhancementStep>{
          EnhancementStep.grayscale,
          EnhancementStep.perspectiveCorrect,
        }),
        quad: quad,
      );
      expect(result.report.applied, <EnhancementStep>[
        EnhancementStep.perspectiveCorrect,
        EnhancementStep.grayscale,
      ]);
      expect(result.report.cropped, isTrue);
    });

    test('an axis-aligned full-frame quad reports no crop', () {
      final source = syntheticCapture(width: 200, height: 200, pageInset: 0);
      final result = EnhancementPipeline.apply(
        source,
        plan: const EnhancementPlan(<EnhancementStep>{
          EnhancementStep.perspectiveCorrect,
        }),
        quad: ImageQuad.fullFrame(200, 200),
      );
      expect(result.report.cropped, isFalse);
      expect(result.image.width, 200);
    });
  });

  group('estimateSkew', () {
    test('a square page of horizontal lines reports no tilt to correct', () {
      final straight = syntheticCapture(
        width: 700,
        height: 900,
        pageInset: 0.1,
        textLines: 18,
      );
      final estimate = estimateSkew(straight);
      expect(estimate.isMeasurable, isTrue);
      expect(estimate.degrees!.abs(), lessThan(0.5));
      expect(estimate.confidence, greaterThan(0.05));
    });

    test('a page photographed at an angle measures its tilt', () {
      final skewed = syntheticCapture(
        width: 700,
        height: 900,
        pageInset: 0.12,
        textLines: 18,
        rotationDegrees: 4,
      );
      final estimate = estimateSkew(skewed);
      expect(estimate.isMeasurable, isTrue, reason: 'no text lines found');
      expect(estimate.degrees!.abs(), inInclusiveRange(3.0, 5.5));
    });

    test('deskewing removes the tilt it measured', () {
      final skewed = syntheticCapture(
        width: 700,
        height: 900,
        pageInset: 0.12,
        textLines: 18,
        rotationDegrees: 4,
      );
      final before = estimateSkew(skewed).degrees!.abs();

      final result = EnhancementPipeline.apply(
        skewed,
        plan: const EnhancementPlan(<EnhancementStep>{
          EnhancementStep.deskew,
        }),
      );
      expect(result.report.applied, contains(EnhancementStep.deskew));

      final after = estimateSkew(result.image);
      // A straightened page either measures ~0° or has no measurable text rows
      // left to score (the second is a pass: there is nothing to correct).
      expect(after.degrees?.abs() ?? 0, lessThan(before));
      expect(after.degrees?.abs() ?? 0, lessThan(1.5));
    });

    test('a blank page has no tilt worth correcting and says so', () {
      final blank = syntheticCapture(width: 600, height: 800, pageInset: 0.1);
      final estimate = estimateSkew(blank);
      // A blank sheet still has one horizontal feature — its own paper edge —
      // so "measurable" is legitimate here. What must never happen is a
      // correction being applied to a page that is already square.
      expect(estimate.degrees?.abs() ?? 0, lessThan(0.5));

      final result = EnhancementPipeline.apply(
        blank,
        plan: const EnhancementPlan(<EnhancementStep>{
          EnhancementStep.deskew,
        }),
      );
      expect(result.report.applied, isEmpty);
      // And the reason is stated rather than the step vanishing.
      expect(result.report.notes, hasLength(1));
      expect(
        result.report.notes.single,
        anyOf(
          contains('Không đo được độ nghiêng'),
          contains('Trang đã thẳng'),
        ),
      );
    });

    test('a tiny image is not measured', () {
      final estimate = estimateSkew(img.Image(width: 16, height: 16));
      expect(estimate.isMeasurable, isFalse);
    });
  });
}
