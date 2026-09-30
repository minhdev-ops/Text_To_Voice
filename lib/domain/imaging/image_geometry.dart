import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;

/// A point in image coordinates: x grows right, y grows **down**, origin is the
/// top-left pixel corner. Kept separate from `dart:ui`'s `Offset` because the
/// scanner runs on a background isolate where `dart:ui` is unavailable, and
/// separate from `package:image`'s `Point` so the geometry can be tested without
/// decoding anything.
@immutable
class ImagePoint {
  const ImagePoint(this.x, this.y);

  final double x;
  final double y;

  static const ImagePoint zero = ImagePoint(0, 0);

  ImagePoint operator +(ImagePoint other) => ImagePoint(x + other.x, y + other.y);
  ImagePoint operator -(ImagePoint other) => ImagePoint(x - other.x, y - other.y);
  ImagePoint operator *(double factor) => ImagePoint(x * factor, y * factor);

  double distanceTo(ImagePoint other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  ImagePoint lerpTo(ImagePoint other, double t) =>
      ImagePoint(x + (other.x - x) * t, y + (other.y - y) * t);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImagePoint && other.x == x && other.y == y);

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';
}

/// The four corners of a detected document, in **clockwise** order starting at
/// the top-left *as the user sees it*.
///
/// Corners are ordered by meaning, not by coordinate magnitude, so a page
/// photographed upside-down still reports `topLeft` as the corner that will
/// become the top-left of the corrected image. That is what lets the crop UI
/// offer a single `Xoay 180°` action instead of four unlabelled handles.
@immutable
class ImageQuad {
  const ImageQuad({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  /// The whole frame — the "no crop" answer, and the fallback when detection
  /// finds nothing. Never a silent substitution: callers are told which one they
  /// got (`QuadDetection.quad == null`).
  factory ImageQuad.fullFrame(int width, int height) => ImageQuad(
        topLeft: const ImagePoint(0, 0),
        topRight: ImagePoint(width.toDouble(), 0),
        bottomRight: ImagePoint(width.toDouble(), height.toDouble()),
        bottomLeft: ImagePoint(0, height.toDouble()),
      );

  /// An inset axis-aligned rectangle, used to trim the outermost pixels of a
  /// frame (phone cameras often include a sliver of the frame's own vignette).
  factory ImageQuad.insetFrame(int width, int height, double inset) => ImageQuad(
        topLeft: ImagePoint(inset, inset),
        topRight: ImagePoint(width - inset, inset),
        bottomRight: ImagePoint(width - inset, height - inset),
        bottomLeft: ImagePoint(inset, height - inset),
      );

  final ImagePoint topLeft;
  final ImagePoint topRight;
  final ImagePoint bottomRight;
  final ImagePoint bottomLeft;

  /// Clockwise from [topLeft].
  List<ImagePoint> get corners =>
      <ImagePoint>[topLeft, topRight, bottomRight, bottomLeft];

  /// Twice the signed shoelace sum. Positive means the corners wind
  /// `topLeft → topRight → bottomRight → bottomLeft` in screen coordinates
  /// (y down); negative means the winding was reversed and the warp would
  /// produce a **mirrored** page — legible-looking text that reads backwards.
  double get signedArea2 {
    var sum = 0.0;
    final points = corners;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      sum += a.x * b.y - b.x * a.y;
    }
    return sum;
  }

  /// Shoelace area, always positive.
  double get area => signedArea2.abs() / 2;

  /// `true` when the winding matches the app's convention.
  bool get hasCanonicalWinding => signedArea2 > 0;

  double get width => (topRight.distanceTo(topLeft) + bottomRight.distanceTo(bottomLeft)) / 2;
  double get height => (bottomLeft.distanceTo(topLeft) + bottomRight.distanceTo(topRight)) / 2;

  /// Pixel aspect of the detected page. A landscape capture of a portrait page
  /// reports < 1 here, which is what the review pane keys its orientation hint
  /// off — not the raw frame.
  double get aspectRatio => height == 0 ? 1 : width / height;

  /// Every cross product between adjacent edge vectors has the same sign.
  ///
  /// A self-intersecting or reflex "quad" (which a naive line intersection can
  /// produce when one of the four fitted lines is wrong) would otherwise be
  /// handed to the warp, and the warp would happily produce a folded image.
  bool get isConvex {
    final points = corners;
    var positive = 0;
    var negative = 0;
    for (var i = 0; i < 4; i++) {
      final a = points[i];
      final b = points[(i + 1) % 4];
      final c = points[(i + 2) % 4];
      final cross =
          (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
      if (cross > 0) positive++;
      if (cross < 0) negative++;
    }
    return positive == 4 || negative == 4;
  }

  /// True when the quad is too small or too thin to be a page.
  bool get isDegenerate =>
      width < 8 || height < 8 || area < 1 || !isConvex;

  bool get isAxisAligned {
    const slack = 0.75;
    return (topLeft.y - topRight.y).abs() <= slack &&
        (bottomLeft.y - bottomRight.y).abs() <= slack &&
        (topLeft.x - bottomLeft.x).abs() <= slack &&
        (topRight.x - bottomRight.x).abs() <= slack;
  }

  /// Moves every corner back inside the frame.
  ///
  /// Detection can land a pixel outside on a page that bleeds past the sensor;
  /// clamping here means the warp never samples out of bounds and the UI never
  /// draws a handle off-screen.
  ///
  /// Coordinates are **continuous**, so the frame runs from `0` to
  /// `frameWidth`, not to `frameWidth - 1`: a full-frame quad must clamp to
  /// itself. Clamping to the last *pixel index* instead silently shaved one pixel
  /// off every full-frame crop — small, invisible, and exactly the kind of
  /// off-by-one that survives to production because nothing looks wrong.
  ImageQuad clampedTo(double frameWidth, double frameHeight) {
    ImagePoint clamp(ImagePoint p) => ImagePoint(
          p.x.clamp(0.0, math.max(0.0, frameWidth)).toDouble(),
          p.y.clamp(0.0, math.max(0.0, frameHeight)).toDouble(),
        );

    return ImageQuad(
      topLeft: clamp(topLeft),
      topRight: clamp(topRight),
      bottomRight: clamp(bottomRight),
      bottomLeft: clamp(bottomLeft),
    );
  }

  ImageQuad scaled(double factor) => ImageQuad(
        topLeft: topLeft * factor,
        topRight: topRight * factor,
        bottomRight: bottomRight * factor,
        bottomLeft: bottomLeft * factor,
      );

  /// Re-anchors on the corner closest to the origin and re-establishes winding.
  ///
  /// Used after a manual corner drag, where the user can move handles past each
  /// other. Two things have to be repaired, not one: which corner is "first",
  /// and which way the polygon winds. Fixing only the first leaves a quad whose
  /// corners trace the outline backwards, and `copyRectify` mirrors it rather
  /// than folding it — a mirrored page looks like readable text until you try to
  /// read it, which is the worst possible failure mode to ship.
  ImageQuad normalizedOrder() {
    final points = corners;
    var bestIndex = 0;
    for (var i = 1; i < points.length; i++) {
      final candidate = points[i];
      final best = points[bestIndex];
      if (candidate.x + candidate.y < best.x + best.y) bestIndex = i;
    }

    final anchored = ImageQuad(
      topLeft: points[bestIndex],
      topRight: points[(bestIndex + 1) % 4],
      bottomRight: points[(bestIndex + 2) % 4],
      bottomLeft: points[(bestIndex + 3) % 4],
    );
    if (anchored.hasCanonicalWinding) return anchored;

    return ImageQuad(
      topLeft: anchored.topLeft,
      bottomLeft: anchored.topRight,
      bottomRight: anchored.bottomRight,
      topRight: anchored.bottomLeft,
    );
  }

  /// How much of the quad's bounding box the quad actually covers. A true
  /// rectangle is 1.0; a bow-tie is far lower, which makes this a cheap sanity
  /// signal alongside [isConvex].
  double get fillRatio {
    final minX = corners.map((p) => p.x).reduce(math.min);
    final maxX = corners.map((p) => p.x).reduce(math.max);
    final minY = corners.map((p) => p.y).reduce(math.min);
    final maxY = corners.map((p) => p.y).reduce(math.max);
    final box = (maxX - minX) * (maxY - minY);
    return box <= 0 ? 0 : (area / box).clamp(0.0, 1.0);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImageQuad &&
          other.topLeft == topLeft &&
          other.topRight == topRight &&
          other.bottomRight == bottomRight &&
          other.bottomLeft == bottomLeft);

  @override
  int get hashCode => Object.hash(topLeft, topRight, bottomRight, bottomLeft);

  @override
  String toString() => 'ImageQuad($topLeft, $topRight, $bottomRight, $bottomLeft)';
}

/// A straight line in normal form `a·x + b·y + c = 0` with `a² + b² = 1`.
///
/// Normal form rather than slope-intercept because document edges are
/// frequently near-vertical, where `y = m·x + b` explodes.
@immutable
class FittedLine {
  const FittedLine(this.a, this.b, this.c);

  final double a;
  final double b;
  final double c;

  /// Signed distance from [p] to this line. Sign is meaningless on its own;
  /// only magnitudes are used.
  double distanceTo(ImagePoint p) => (a * p.x + b * p.y + c).abs();

  /// Least-squares fit through [points] using total-least-squares (principal
  /// axis), which is stable for near-vertical lines and needs no pivot.
  ///
  /// Returns `null` when there are fewer than two points or every point is
  /// identical — a line through one point is not a line.
  static FittedLine? fit(List<ImagePoint> points) {
    if (points.length < 2) return null;

    var meanX = 0.0;
    var meanY = 0.0;
    for (final p in points) {
      meanX += p.x;
      meanY += p.y;
    }
    meanX /= points.length;
    meanY /= points.length;

    var sxx = 0.0;
    var syy = 0.0;
    var sxy = 0.0;
    for (final p in points) {
      final dx = p.x - meanX;
      final dy = p.y - meanY;
      sxx += dx * dx;
      syy += dy * dy;
      sxy += dx * dy;
    }
    if (sxx + syy == 0) return null;

    // Principal eigenvector of [[sxx, sxy], [sxy, syy]].
    final theta = 0.5 * math.atan2(2 * sxy, sxx - syy);
    // Direction of the line; normal is perpendicular to it.
    final nx = math.cos(theta);
    final ny = math.sin(theta);

    // Normalize so a² + b² == 1.
    final norm = math.sqrt(nx * nx + ny * ny);
    final a = -ny / norm;
    final b = nx / norm;
    final c = -(a * meanX + b * meanY);

    // Re-orient so the equation is canonical (a > 0, or a == 0 and b > 0),
    // which makes equality comparisons in tests meaningful.
    if (a < 0 || (a == 0 && b < 0)) {
      return FittedLine(-a, -b, -c);
    }
    return FittedLine(a, b, c);
  }

  /// Intersection with [other], or `null` when the two are near-parallel.
  ///
  /// A "corner" produced from two lines within a degree of each other is tens of
  /// thousands of pixels away and would drag the whole quad with it, so the
  /// caller is told instead of handed a wild number.
  ImagePoint? intersect(FittedLine other) {
    final determinant = a * other.b - other.a * b;
    if (determinant.abs() < 1e-6) return null;
    return ImagePoint(
      (b * other.c - other.b * c) / determinant,
      (other.a * c - a * other.c) / determinant,
    );
  }

  /// The angle of this line in degrees, folded into `[-90, 90)`.
  double get angleDegrees {
    final degrees = math.atan2(-a, b) * 180 / math.pi;
    var folded = degrees % 180;
    if (folded >= 90) folded -= 180;
    if (folded < -90) folded += 180;
    return folded;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FittedLine && other.a == a && other.b == b && other.c == c);

  @override
  int get hashCode => Object.hash(a, b, c);

  @override
  String toString() =>
      'FittedLine(${a.toStringAsFixed(4)}x + ${b.toStringAsFixed(4)}y + '
      '${c.toStringAsFixed(2)} = 0)';
}
