import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:text_to_voice/domain/imaging/image_geometry.dart';

void main() {
  group('ImagePoint', () {
    test('measures distance and lerps', () {
      const a = ImagePoint(0, 0);
      const b = ImagePoint(3, 4);
      expect(a.distanceTo(b), closeTo(5, 1e-9));
      expect(a.lerpTo(b, 0.5), const ImagePoint(1.5, 2));
    });
  });

  group('ImageQuad', () {
    test('computes the shoelace area of a rectangle', () {
      final quad = ImageQuad.fullFrame(10, 20);
      expect(quad.area, 200);
      expect(quad.width, 10);
      expect(quad.height, 20);
      expect(quad.fillRatio, closeTo(1, 1e-9));
    });

    test('a rectangle is convex, a bow-tie is not', () {
      expect(ImageQuad.fullFrame(100, 100).isConvex, isTrue);

      const bowTie = ImageQuad(
        topLeft: ImagePoint(0, 0),
        topRight: ImagePoint(100, 0),
        bottomRight: ImagePoint(0, 100),
        bottomLeft: ImagePoint(100, 100),
      );
      expect(bowTie.isConvex, isFalse);
      expect(bowTie.fillRatio, lessThan(0.6));
    });

    test('a sliver is degenerate rather than a page', () {
      const sliver = ImageQuad(
        topLeft: ImagePoint(0, 0),
        topRight: ImagePoint(4, 0),
        bottomRight: ImagePoint(4, 4),
        bottomLeft: ImagePoint(0, 4),
      );
      expect(sliver.isDegenerate, isTrue);
    });

    test('clamping pulls corners back inside the frame', () {
      const quad = ImageQuad(
        topLeft: ImagePoint(-5, -9),
        topRight: ImagePoint(200, -1),
        bottomRight: ImagePoint(200, 200),
        bottomLeft: ImagePoint(-3, 200),
      );
      final clamped = quad.clampedTo(100, 100);
      for (final corner in clamped.corners) {
        // Continuous coordinates: the frame is [0, width], not [0, width-1].
        expect(corner.x, inInclusiveRange(0, 100));
        expect(corner.y, inInclusiveRange(0, 100));
      }
    });

    test('a full-frame quad survives clamping unchanged', () {
      final quad = ImageQuad.fullFrame(200, 400);
      expect(quad.clampedTo(200, 400), quad);
    });

    test('normalizing order re-anchors on the top-left and repairs winding', () {
      const rotated = ImageQuad(
        topLeft: ImagePoint(100, 100),
        topRight: ImagePoint(100, 0),
        bottomRight: ImagePoint(0, 0),
        bottomLeft: ImagePoint(0, 100),
      );
      expect(rotated.hasCanonicalWinding, isFalse);

      final normalized = rotated.normalizedOrder();
      expect(normalized.topLeft, const ImagePoint(0, 0));
      expect(normalized.topRight, const ImagePoint(100, 0));
      expect(normalized.bottomRight, const ImagePoint(100, 100));
      expect(normalized.bottomLeft, const ImagePoint(0, 100));
      expect(normalized.hasCanonicalWinding, isTrue);
      expect(normalized.area, rotated.area);
    });

    test('normalizing an already-canonical quad changes nothing', () {
      final quad = ImageQuad.fullFrame(100, 100);
      expect(quad.normalizedOrder(), quad);
    });

    test('a tilted page reports the aspect ratio of the page, not the frame', () {
      const portraitOnItsSide = ImageQuad(
        topLeft: ImagePoint(0, 0),
        topRight: ImagePoint(40, 0),
        bottomRight: ImagePoint(40, 80),
        bottomLeft: ImagePoint(0, 80),
      );
      expect(portraitOnItsSide.aspectRatio, closeTo(0.5, 1e-9));
    });

    test('an inset frame is axis aligned and a tilted quad is not', () {
      expect(ImageQuad.insetFrame(100, 100, 5).isAxisAligned, isTrue);
      expect(ImageQuad.fullFrame(100, 100).isAxisAligned, isTrue);

      const tilted = ImageQuad(
        topLeft: ImagePoint(0, 4),
        topRight: ImagePoint(100, 0),
        bottomRight: ImagePoint(100, 96),
        bottomLeft: ImagePoint(0, 100),
      );
      expect(tilted.isAxisAligned, isFalse);
    });
  });

  group('FittedLine', () {
    test('fits a horizontal line and measures distance to it', () {
      final line = FittedLine.fit(const <ImagePoint>[
        ImagePoint(0, 5),
        ImagePoint(10, 5),
        ImagePoint(20, 5),
        ImagePoint(30, 5),
      ]);
      expect(line, isNotNull);
      expect(line!.distanceTo(const ImagePoint(15, 5)), closeTo(0, 1e-9));
      expect(line.distanceTo(const ImagePoint(15, 9)), closeTo(4, 1e-9));
      expect(line.angleDegrees, closeTo(0, 1e-6));
    });

    test('fits a near-vertical line without blowing up', () {
      final line = FittedLine.fit(const <ImagePoint>[
        ImagePoint(3, 0),
        ImagePoint(3.1, 100),
        ImagePoint(2.9, 200),
        ImagePoint(3, 300),
      ]);
      expect(line, isNotNull);
      expect(line!.distanceTo(const ImagePoint(3, 150)), lessThan(0.05));
      expect(line.angleDegrees.abs(), greaterThan(89));
    });

    test('fits a diagonal at 45°', () {
      final line = FittedLine.fit(const <ImagePoint>[
        ImagePoint(0, 0),
        ImagePoint(10, 10),
        ImagePoint(20, 20),
      ]);
      expect(line!.angleDegrees, closeTo(45, 1e-6));
    });

    test('refuses a line through fewer than two points', () {
      expect(FittedLine.fit(const <ImagePoint>[]), isNull);
      expect(FittedLine.fit(const <ImagePoint>[ImagePoint(1, 1)]), isNull);
      expect(
        FittedLine.fit(const <ImagePoint>[ImagePoint(1, 1), ImagePoint(1, 1)]),
        isNull,
      );
    });

    test('intersects two perpendicular lines and refuses parallels', () {
      final vertical = FittedLine.fit(const <ImagePoint>[
        ImagePoint(1, 0),
        ImagePoint(1, 10),
      ])!;
      final horizontal = FittedLine.fit(const <ImagePoint>[
        ImagePoint(0, 2),
        ImagePoint(10, 2),
      ])!;
      final crossing = vertical.intersect(horizontal)!;
      expect(crossing.x, closeTo(1, 1e-6));
      expect(crossing.y, closeTo(2, 1e-6));

      final alsoVertical = FittedLine.fit(const <ImagePoint>[
        ImagePoint(5, 0),
        ImagePoint(5, 10),
      ])!;
      expect(vertical.intersect(alsoVertical), isNull);
    });

    test('angle folding keeps a line within [-90, 90)', () {
      final steep = FittedLine.fit(const <ImagePoint>[
        ImagePoint(0, 0),
        ImagePoint(1, 50),
      ])!;
      expect(steep.angleDegrees, greaterThan(-90));
      expect(steep.angleDegrees, lessThan(90));
      expect(
        steep.angleDegrees,
        closeTo(math.atan2(50, 1) * 180 / math.pi, 1e-6),
      );
    });
  });
}
