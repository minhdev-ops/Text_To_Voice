import 'dart:math' as math;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show immutable;
import 'package:image/image.dart' as img;

import 'image_geometry.dart';
import 'luminance.dart';

/// Tuning for [detectDocumentQuad]. The defaults are the values the Phase 2
/// fixtures were measured against, not guesses — see
/// `test/domain/imaging/quad_detector_test.dart`.
@immutable
class QuadDetectionOptions {
  const QuadDetectionOptions({
    this.workingMaxDimension = 480,
    this.edgeMarginRatio = 0.01,
    this.minAreaRatio = 0.12,
    this.minSupportRun = 3,
    this.residualToleranceRatio = 0.02,
    this.maxOutlierSigma = 2.5,
    this.minSeparability = 0.6,
    this.edgeStepSampleRatio = 0.02,
    this.minEdgeStep = 24,
  });

  /// Detection runs on a downscaled copy. A 12 MP capture would otherwise cost
  /// seconds of scanning for a result whose precision is ~1/480 of the frame,
  /// which is finer than a user can drag a handle.
  final int workingMaxDimension;

  /// Ignore this fraction of the frame at each border. Camera vignetting and a
  /// rounded bezel both put a dark ring inside the sensor area, and treating it
  /// as the page edge produces a bogus inset quad.
  final double edgeMarginRatio;

  /// A detected quad covering less of the frame than this is reported as "not
  /// found" rather than offered, because the honest next step is a manual crop.
  final double minAreaRatio;

  /// How many consecutive document pixels a scanline must find before it
  /// believes it hit the page. Single-pixel noise routinely survives Otsu.
  final int minSupportRun;

  /// Minimum Otsu separability (the between-class share of total variance)
  /// before a threshold is trusted at all.
  ///
  /// Without this gate a page the same brightness as its desk does not fail — it
  /// "succeeds" brilliantly. Half of every border row is then classified as
  /// page, so each scanline finds support three pixels in, all four fitted edges
  /// land on the frame margin, the residuals are near zero, and the detector
  /// reports a full-frame quad with **high confidence**. Nothing downstream can
  /// tell that from a real detection. η is the measurement that distinguishes
  /// "two classes" from "one blurry class", and 0.6 is comfortably below the
  /// 0.95+ a genuine page-on-desk capture scores.
  final double minSeparability;

  /// Distance, as a fraction of the frame diagonal, at which luminance is
  /// sampled on each side of a fitted edge.
  final double edgeStepSampleRatio;

  /// Minimum mean luminance **difference** across every fitted edge, in 0..255
  /// levels.
  ///
  /// Separability alone cannot reject a page that matches its desk. Otsu's η is
  /// a property of the histogram's shape, and a *single* uniform distribution
  /// already scores η ≈ 0.75 when cut down the middle, so heavy noise on a flat
  /// scene sails past any η gate.
  ///
  /// What separates a page edge from noise is a luminance step **across the
  /// edge**, measured with signed means so the noise cancels. A real dark-desk
  /// capture steps by ~188 levels; the same-brightness capture steps by 6.
  final double minEdgeStep;

  /// Perpendicular distance, as a fraction of the frame diagonal, that counts
  /// as "on the line" when scoring inliers.
  final double residualToleranceRatio;

  /// Outlier rejection threshold in robust standard deviations.
  final double maxOutlierSigma;
}

/// What the detector concluded.
///
/// A `null` [quad] is a normal, reportable outcome — "nothing here looks like a
/// page" — not an error. [notFoundReason] carries the honest Vietnamese
/// sentence the UI shows instead of silently guessing a full-frame crop.
@immutable
class QuadDetection {
  const QuadDetection({
    required this.quad,
    required this.confidence,
    required this.frameWidth,
    required this.frameHeight,
    this.inlierCount = 0,
    this.notFoundReason,
    this.separability,
  });

  /// Corners in **source-image** coordinates, or `null` when nothing plausible
  /// was found.
  final ImageQuad? quad;

  /// 0..1. Combines how many scanlines agreed with the fitted edges and how
  /// tightly they agreed.
  final double confidence;

  final int frameWidth;
  final int frameHeight;
  final int inlierCount;

  /// Vietnamese, user-facing, and specific about what was wrong.
  final String? notFoundReason;

  /// Otsu's η for this capture, when a threshold was computed at all.
  ///
  /// Surfaced rather than kept internal because "the app says it can't find the
  /// page" and "the app can't find the page because paper and desk are 6/255
  /// apart" are different support conversations, and only the number tells them
  /// apart.
  final double? separability;

  bool get found => quad != null;

  /// The quad to use when the user does nothing: detected, else the whole
  /// frame. Explicit so a caller cannot mistake the fallback for a detection.
  ImageQuad get effectiveQuad =>
      quad ?? ImageQuad.fullFrame(frameWidth, frameHeight);

  @override
  String toString() => found
      ? 'QuadDetection($quad, confidence ${confidence.toStringAsFixed(2)})'
      : 'QuadDetection(none: $notFoundReason)';
}

/// Finds the page inside a photograph.
///
/// The approach is deliberately classical rather than a neural segmenter: it is
/// deterministic, needs no model download, costs tens of milliseconds on a
/// mid-range phone, and — most importantly — is *inspectable*. When it fails it
/// can say why.
///
///  1. Downscale and convert to luminance.
///  2. Otsu threshold; decide which class is the page by looking at the frame's
///     border ring (the background is whatever owns the border).
///  3. Walk scanlines inward from each side to the first supported run of page
///     pixels, yielding four boundary point clouds.
///  4. Robust total-least-squares fit per side — no slope-intercept form, because
///     page edges are routinely near-vertical.
///  5. Intersect adjacent lines for the corners; reject non-convex, out-of-frame
///     or too-small results.
QuadDetection detectDocumentQuad(
  img.Image source, {
  QuadDetectionOptions options = const QuadDetectionOptions(),
}) {
  final width = source.width;
  final height = source.height;
  if (width < 16 || height < 16) {
    return QuadDetection(
      quad: null,
      confidence: 0,
      frameWidth: width,
      frameHeight: height,
      notFoundReason: 'Ảnh quá nhỏ để dò viền.',
    );
  }

  final plane = buildLuminancePlane(
    source,
    maxDimension: options.workingMaxDimension,
  );
  final workWidth = plane.width;
  final workHeight = plane.height;

  final otsu = _otsu(plane.pixels);
  if (otsu.separability < options.minSeparability) {
    return QuadDetection(
      quad: null,
      confidence: otsu.separability.clamp(0.0, 1.0).toDouble(),
      frameWidth: width,
      frameHeight: height,
      separability: otsu.separability,
      notFoundReason: 'Nền và trang gần như cùng độ sáng '
          '(tách được ${(otsu.separability * 100).round()}%), '
          'nên không xác định được viền. Kéo góc bằng tay.',
    );
  }

  final threshold = otsu.threshold;
  final pageIsBright = _pageIsBright(plane, threshold, options);

  final marginX = math.max(1, (workWidth * options.edgeMarginRatio).round());
  final marginY = math.max(1, (workHeight * options.edgeMarginRatio).round());
  final horizontalSamples = workWidth - 2 * marginX;
  final verticalSamples = workHeight - 2 * marginY;
  if (horizontalSamples < 4 || verticalSamples < 4) {
    return QuadDetection(
      quad: null,
      confidence: 0,
      frameWidth: width,
      frameHeight: height,
      notFoundReason: 'Khung ảnh quá nhỏ để dò viền.',
    );
  }

  final left = <ImagePoint>[];
  final right = <ImagePoint>[];
  final top = <ImagePoint>[];
  final bottom = <ImagePoint>[];

  int? edge(int offset, int step, int samples) => _scanEdge(
        plane.pixels,
        offset,
        step,
        samples,
        threshold,
        pageIsBright,
        options.minSupportRun,
      );

  for (var y = marginY; y < workHeight - marginY; y++) {
    final rowStart = y * workWidth;
    final l = edge(rowStart + marginX, 1, horizontalSamples);
    if (l != null) left.add(ImagePoint((marginX + l).toDouble(), y.toDouble()));

    final r = edge(rowStart + workWidth - 1 - marginX, -1, horizontalSamples);
    if (r != null) {
      right.add(
          ImagePoint((workWidth - 1 - marginX - r).toDouble(), y.toDouble()));
    }
  }

  for (var x = marginX; x < workWidth - marginX; x++) {
    final t = edge(marginY * workWidth + x, workWidth, verticalSamples);
    if (t != null) top.add(ImagePoint(x.toDouble(), (marginY + t).toDouble()));

    final b = edge((workHeight - 1 - marginY) * workWidth + x, -workWidth,
        verticalSamples);
    if (b != null) {
      bottom.add(
          ImagePoint(x.toDouble(), (workHeight - 1 - marginY - b).toDouble()));
    }
  }

  final tolerance = options.residualToleranceRatio *
      math.sqrt((workWidth * workWidth + workHeight * workHeight).toDouble());

  final leftFit = _robustFit(left, tolerance, options.maxOutlierSigma);
  final rightFit = _robustFit(right, tolerance, options.maxOutlierSigma);
  final topFit = _robustFit(top, tolerance, options.maxOutlierSigma);
  final bottomFit = _robustFit(bottom, tolerance, options.maxOutlierSigma);

  final missing = <String>[
    if (!leftFit.ok) 'trái',
    if (!rightFit.ok) 'phải',
    if (!topFit.ok) 'trên',
    if (!bottomFit.ok) 'dưới',
  ];
  if (missing.isNotEmpty) {
    return QuadDetection(
      quad: null,
      confidence: 0,
      frameWidth: width,
      frameHeight: height,
      notFoundReason: 'Không đủ điểm tựa để dựng cạnh ${missing.join(', ')}.',
    );
  }

  final topLine = topFit.line!;
  final bottomLine = bottomFit.line!;
  final leftLine = leftFit.line!;
  final rightLine = rightFit.line!;

  final tl = topLine.intersect(leftLine);
  final tr = topLine.intersect(rightLine);
  final br = bottomLine.intersect(rightLine);
  final bl = bottomLine.intersect(leftLine);
  if (tl == null || tr == null || br == null || bl == null) {
    return QuadDetection(
      quad: null,
      confidence: 0,
      frameWidth: width,
      frameHeight: height,
      notFoundReason: 'Hai cạnh gần như song song nên không xác định được góc.',
    );
  }

  final scaleUp = width / workWidth;
  var quad = ImageQuad(
    topLeft: tl * scaleUp,
    topRight: tr * scaleUp,
    bottomRight: br * scaleUp,
    bottomLeft: bl * scaleUp,
  );

  if (quad.corners
      .any((p) => !p.x.isFinite || !p.y.isFinite)) {
    return QuadDetection(
      quad: null,
      confidence: 0,
      frameWidth: width,
      frameHeight: height,
      notFoundReason: 'Góc dò được nằm ngoài ảnh.',
    );
  }

  final slackX = width * 0.03;
  final slackY = height * 0.03;
  final outOfFrame = quad.corners.any((p) =>
      p.x < -slackX ||
      p.y < -slackY ||
      p.x > width + slackX ||
      p.y > height + slackY);
  if (outOfFrame) {
    return QuadDetection(
      quad: null,
      confidence: 0,
      frameWidth: width,
      frameHeight: height,
      notFoundReason: 'Viền dò được vượt ra ngoài khung ảnh.',
    );
  }

  quad = quad.clampedTo(width.toDouble(), height.toDouble());

  if (!quad.isConvex || quad.fillRatio < 0.7) {
    return QuadDetection(
      quad: null,
      confidence: 0,
      frameWidth: width,
      frameHeight: height,
      notFoundReason:
          'Viền dò được bị gấp khúc — có thể nền trùng màu giấy.',
    );
  }

  final areaRatio = quad.area / (width * height);
  if (areaRatio < options.minAreaRatio) {
    return QuadDetection(
      quad: null,
      confidence: 0,
      frameWidth: width,
      frameHeight: height,
      notFoundReason: 'Vùng dò được chỉ chiếm ${(areaRatio * 100).round()}% '
          'khung ảnh, quá nhỏ để coi là cả trang.',
    );
  }

  // A page that fills the frame has no interior edge to step across, so this
  // gate rejects it and `effectiveQuad` falls back to the whole frame — which is
  // the same crop, reached honestly. There is deliberately **no** special case
  // that reports "found" here: the detector cannot tell "the page fills the
  // frame" from "there is no page", and claiming a detection it did not make is
  // how a review pane ends up telling a user to crop a page that is already
  // cropped.
  final sampleDistance = math.max(
    2.5,
    options.edgeStepSampleRatio *
        math.sqrt((workWidth * workWidth + workHeight * workHeight).toDouble()),
  );
  final steps = <double>[
    _edgeStep(plane, topLine, tl, tr, sampleDistance),
    _edgeStep(plane, leftLine, tl, bl, sampleDistance),
    _edgeStep(plane, rightLine, tr, br, sampleDistance),
    _edgeStep(plane, bottomLine, bl, br, sampleDistance),
  ];
  final weakest = steps.reduce(math.min);
  if (weakest < options.minEdgeStep) {
    return QuadDetection(
      quad: null,
      confidence: (weakest / options.minEdgeStep).clamp(0.0, 1.0).toDouble(),
      frameWidth: width,
      frameHeight: height,
      separability: otsu.separability,
      notFoundReason: 'Viền dò được không có bước sáng rõ '
          '(lệch ${weakest.round()}/255) — khả năng cao nền trùng màu giấy. '
          'Kéo góc bằng tay.',
    );
  }

  final fits = <_SideFit>[leftFit, rightFit, topFit, bottomFit];
  final inliers = fits.fold<int>(0, (sum, f) => sum + f.inliers.length);
  final samples = fits.fold<int>(0, (sum, f) => sum + f.sampleCount);
  final agreement = samples == 0 ? 0.0 : inliers / samples;
  final meanResidual =
      fits.fold<double>(0, (sum, f) => sum + f.meanResidual) / fits.length;
  final tightness = math.exp(-meanResidual / math.max(tolerance, 1e-6));
  final confidence =
      (agreement * 0.6 + tightness * 0.4).clamp(0.0, 1.0).toDouble();

  return QuadDetection(
    quad: quad,
    confidence: confidence,
    frameWidth: width,
    frameHeight: height,
    inlierCount: inliers,
    separability: otsu.separability,
  );
}

// ---------------------------------------------------------------------------
// Internals
// ---------------------------------------------------------------------------

/// The chosen threshold plus Otsu's own measure of how real the split is.
class _Otsu {
  const _Otsu(this.threshold, this.separability);

  final int threshold;

  /// η = between-class variance / total variance, in 0..1. High means the
  /// histogram really does have two modes; low means a single blurred blob was
  /// cut in half.
  final double separability;
}

/// Otsu's method: the threshold maximizing between-class variance, plus the
/// separability that says whether the result means anything.
///
/// A fixed threshold ("brighter than 128 is paper") fails on the two captures
/// this app actually gets — a phone in a dim room, and a page under a desk lamp
/// with a shadow across one corner.
_Otsu _otsu(Uint8List pixels) {
  final histogram = List<int>.filled(256, 0);
  for (final value in pixels) {
    histogram[value]++;
  }

  final total = pixels.length;
  var sum = 0.0;
  for (var i = 0; i < 256; i++) {
    sum += i * histogram[i];
  }
  if (total == 0) return const _Otsu(127, 0);

  final globalMean = sum / total;
  var totalVariance = 0.0;
  for (var i = 0; i < 256; i++) {
    if (histogram[i] == 0) continue;
    final delta = i - globalMean;
    totalVariance += histogram[i] * delta * delta;
  }
  totalVariance /= total;
  if (totalVariance <= 0) return const _Otsu(127, 0);

  var sumBackground = 0.0;
  var weightBackground = 0;
  var best = 0.0;
  var threshold = 127;

  for (var t = 0; t < 256; t++) {
    weightBackground += histogram[t];
    if (weightBackground == 0) continue;
    final weightForeground = total - weightBackground;
    if (weightForeground == 0) break;

    sumBackground += t * histogram[t];
    final meanBackground = sumBackground / weightBackground;
    final meanForeground = (sum - sumBackground) / weightForeground;
    final delta = meanBackground - meanForeground;
    final between = weightBackground * weightForeground * delta * delta;
    if (between > best) {
      best = between;
      threshold = t;
    }
  }

  // between-class variance is `best / total²`, so η is that over the total
  // variance. Getting this ratio wrong by a factor of `total` (≈300 000) would
  // make every capture look perfectly separable and silently disable the gate.
  final separability =
      (best / (total * total) / totalVariance).clamp(0.0, 1.0);
  return _Otsu(threshold, separability.toDouble());
}

/// Which side of the threshold is the page?
///
/// The page is whatever the frame's border ring is *not*. A page that fills the
/// frame leaves an ambiguous ring; in that case both readings describe the same
/// crop, so the bright reading is used.
bool _pageIsBright(
  LuminancePlane plane,
  int threshold,
  QuadDetectionOptions options,
) {
  final marginX = math.max(1, (plane.width * options.edgeMarginRatio).round());
  final marginY = math.max(1, (plane.height * options.edgeMarginRatio).round());

  var brightOnBorder = 0;
  var borderPixels = 0;
  void sample(int x, int y) {
    borderPixels++;
    if (plane.at(x, y) > threshold) brightOnBorder++;
  }

  for (var x = 0; x < plane.width; x++) {
    for (var dy = 0; dy < marginY; dy++) {
      sample(x, dy);
      sample(x, plane.height - 1 - dy);
    }
  }
  for (var y = 0; y < plane.height; y++) {
    for (var dx = 0; dx < marginX; dx++) {
      sample(dx, y);
      sample(plane.width - 1 - dx, y);
    }
  }

  final brightRatio = borderPixels == 0 ? 1.0 : brightOnBorder / borderPixels;
  // Border mostly bright → background bright → page dark.
  return brightRatio < 0.5;
}

/// Walks from a starting index in [step] increments and returns the *relative*
/// index of the first run of [runLength] page pixels.
///
/// The run requirement is what separates the page edge from a speck of dust or a
/// single hot pixel, both of which Otsu routinely classifies as page.
int? _scanEdge(
  Uint8List pixels,
  int offset,
  int step,
  int samples,
  int threshold,
  bool pageIsBright,
  int runLength,
) {
  for (var i = 0; i < samples; i++) {
    if (!_isPage(pixels[offset + i * step], threshold, pageIsBright)) continue;
    var run = 1;
    while (run < runLength && i + run < samples) {
      if (!_isPage(pixels[offset + (i + run) * step], threshold, pageIsBright)) {
        break;
      }
      run++;
    }
    if (run >= runLength) return i;
  }
  return null;
}

bool _isPage(int luma, int threshold, bool pageIsBright) =>
    pageIsBright ? luma > threshold : luma <= threshold;

/// One side's fitted line plus how well the point cloud supported it.
class _SideFit {
  const _SideFit({
    required this.line,
    required this.inliers,
    required this.sampleCount,
    required this.meanResidual,
  });

  final FittedLine? line;
  final List<ImagePoint> inliers;
  final int sampleCount;
  final double meanResidual;

  bool get ok => line != null && inliers.length >= 2;

  static _SideFit failed(List<ImagePoint> points) => _SideFit(
        line: null,
        inliers: points,
        sampleCount: points.length,
        meanResidual: 0,
      );
}

/// Total-least-squares fit with one round of MAD-based outlier rejection.
///
/// One round is deliberate: a *shadow* across the page is not a geometric
/// outlier, and iterating to convergence would keep re-fitting toward its edge.
_SideFit _robustFit(
  List<ImagePoint> points,
  double tolerance,
  double maxOutlierSigma,
) {
  if (points.length < 3) return _SideFit.failed(points);

  final initial = FittedLine.fit(points);
  if (initial == null) return _SideFit.failed(points);

  final residuals = points.map(initial.distanceTo).toList(growable: false);
  final sorted = List<double>.from(residuals)..sort();
  final median = _percentile(sorted, 0.5);
  final deviations = residuals
      .map((r) => (r - median).abs())
      .toList(growable: false)
    ..sort();
  final mad = _percentile(deviations, 0.5);
  final sigma = math.max(mad * 1.4826, 1e-3);
  final cutoff = math.max(median + maxOutlierSigma * sigma, tolerance);

  final inliers = <ImagePoint>[];
  for (var i = 0; i < points.length; i++) {
    if (residuals[i] <= cutoff) inliers.add(points[i]);
  }
  if (inliers.length < 2) return _SideFit.failed(points);

  final refined = FittedLine.fit(inliers);
  if (refined == null) return _SideFit.failed(points);

  var sum = 0.0;
  var count = 0;
  for (final point in inliers) {
    final residual = refined.distanceTo(point);
    if (residual <= cutoff) {
      sum += residual;
      count++;
    }
  }
  return _SideFit(
    line: refined,
    inliers: inliers,
    sampleCount: points.length,
    meanResidual: count == 0 ? 0 : sum / count,
  );
}

/// Mean luminance difference across one fitted edge, sampled between the two
/// corners that bound it.
///
/// Signed means rather than a per-pixel absolute difference: a signed mean is
/// what makes the measurement survive heavy sensor noise, because noise averages
/// to zero on both sides. An absolute-difference measure would report a large
/// "edge" on a uniformly noisy blank frame, which is the exact failure this
/// gate exists to prevent.
///
/// Sampling is confined to the segment **between the corners**, not the whole
/// infinite line: outside the page's extent both sides are desk, and including
/// those samples would average the real step toward zero.
double _edgeStep(
  LuminancePlane plane,
  FittedLine line,
  ImagePoint from,
  ImagePoint to,
  double sampleDistance,
) {
  const segments = 24;
  var nearSum = 0.0;
  var farSum = 0.0;
  var samples = 0;

  for (var i = 1; i < segments; i++) {
    // Skip the last 10% at each end so a slightly-off corner does not drag the
    // samples off the page.
    final t = 0.1 + 0.8 * (i / segments);
    final onEdge = ImagePoint(
      from.x + (to.x - from.x) * t,
      from.y + (to.y - from.y) * t,
    );
    final near = ImagePoint(
      onEdge.x + line.a * sampleDistance,
      onEdge.y + line.b * sampleDistance,
    );
    final far = ImagePoint(
      onEdge.x - line.a * sampleDistance,
      onEdge.y - line.b * sampleDistance,
    );
    if (!_inPlane(plane, near) || !_inPlane(plane, far)) continue;
    nearSum += plane.at(near.x.round(), near.y.round());
    farSum += plane.at(far.x.round(), far.y.round());
    samples++;
  }

  if (samples == 0) return 0;
  return (nearSum - farSum).abs() / samples;
}

bool _inPlane(LuminancePlane plane, ImagePoint p) =>
    p.x >= 0 && p.y >= 0 && p.x < plane.width && p.y < plane.height;

double _percentile(List<double> sorted, double fraction) {
  if (sorted.isEmpty) return 0;
  final index = ((sorted.length - 1) * fraction).round();
  return sorted[index];
}
