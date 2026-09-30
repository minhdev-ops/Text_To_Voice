import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;
import 'package:image/image.dart' as img;

import 'image_geometry.dart';
import 'luminance.dart';

/// One toggleable step of the scan pipeline (FR-04 / §40 Flow 2).
///
/// Every step is individually switchable and the whole pipeline can be turned
/// off with one action ("Bản gốc"), because enhancement that cannot be undone is
/// destructive editing — and a user who cannot get the original back will
/// assume the app threw their photo away.
enum EnhancementStep {
  perspectiveCorrect(
    'Chỉnh phối cảnh',
    'Kéo bốn góc về hình chữ nhật.',
  ),
  grayscale(
    'Xám',
    'Bỏ màu để chữ tách khỏi nền.',
  ),
  denoise(
    'Khử nhiễu',
    'Làm mượt hạt nhiễu trong ảnh thiếu sáng.',
  ),
  contrast(
    'Tăng tương phản',
    'Trải dải sáng tối cho chữ đen hơn, giấy trắng hơn.',
  ),
  deskew(
    'Xoay thẳng trang',
    'Bù độ nghiêng của tờ giấy.',
  );

  const EnhancementStep(this.label, this.note);

  /// Vietnamese label for the toggle row.
  final String label;

  /// One plain sentence explaining what the step does. No adjectives that
  /// oversell ("thần kỳ", "vượt trội") — DESIGN.md voice rules.
  final String note;

  /// Denoise is the one step that trades detail for smoothness, so it is off by
  /// default: on a clean capture it softens diacritics, which is precisely the
  /// text this app must not lose.
  bool get isOnByDefault => this != EnhancementStep.denoise;
}

/// Which steps to run, in which combination.
///
/// A set rather than five booleans so `toggle` cannot produce an inconsistent
/// state, and so the fixed execution order lives in one place
/// ([EnhancementPipeline.order]) instead of in the order flags happen to be
/// checked.
@immutable
class EnhancementPlan {
  const EnhancementPlan(this.steps);

  final Set<EnhancementStep> steps;

  /// The escape hatch: nothing runs, the user sees their own photo.
  static const EnhancementPlan original = EnhancementPlan(<EnhancementStep>{});

  /// What a fresh scan starts with. Denoise excluded on purpose (see
  /// [EnhancementStep.isOnByDefault]).
  static const EnhancementPlan ocrDefault = EnhancementPlan(<EnhancementStep>{
    EnhancementStep.perspectiveCorrect,
    EnhancementStep.grayscale,
    EnhancementStep.contrast,
    EnhancementStep.deskew,
  });

  static final EnhancementPlan everything =
      EnhancementPlan(EnhancementStep.values.toSet());

  bool isEnabled(EnhancementStep step) => steps.contains(step);

  EnhancementPlan toggle(EnhancementStep step, [bool? enabled]) {
    final next = Set<EnhancementStep>.from(steps);
    if (enabled ?? !next.contains(step)) {
      next.add(step);
    } else {
      next.remove(step);
    }
    return EnhancementPlan(next);
  }

  bool get isEmpty => steps.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EnhancementPlan && other.steps.length == steps.length && other.steps.containsAll(steps));

  @override
  int get hashCode => Object.hashAllUnordered(steps);

  @override
  String toString() => 'EnhancementPlan(${steps.map((s) => s.name).join(', ')})';
}

/// What the pipeline actually did, in the user's terms.
///
/// Deliberately not "N steps applied": a step that had nothing to do (the page
/// was already straight) is reported as skipped with the reason, so a user who
/// toggles deskew and sees no change is told why rather than left wondering.
@immutable
class EnhancementReport {
  const EnhancementReport({
    required this.applied,
    required this.notes,
    required this.width,
    required this.height,
    this.skewDegrees,
    this.cropped = false,
  });

  final List<EnhancementStep> applied;

  /// Vietnamese, one per thing worth saying.
  final List<String> notes;

  final int width;
  final int height;

  /// Measured page tilt in degrees, when it could be measured at all.
  final double? skewDegrees;

  /// `true` when perspective correction actually changed the framing.
  final bool cropped;

  /// Short honest summary for the instrument strip.
  String get summary {
    if (applied.isEmpty) return 'Bản gốc, không chỉnh gì.';
    return 'Đã áp dụng ${applied.map((s) => s.label.toLowerCase()).join(', ')}.';
  }

  @override
  String toString() => 'EnhancementReport(${applied.length} steps, $width×$height)';
}

/// The corrected page plus the report.
@immutable
class EnhancedImage {
  const EnhancedImage({required this.image, required this.report});

  final img.Image image;
  final EnhancementReport report;
}

/// The scan pipeline over the `image` package.
///
/// Order is fixed and reasoned, not arbitrary:
///
///  1. **perspective** — every later step should look at the page, not the desk
///     around it. Measuring skew on the desk would find the desk's lines.
///  2. **grayscale** — denoise and contrast are per-luminance operations and
///     colour channels only add work.
///  3. **denoise** — before contrast, so the contrast stretch amplifies strokes
///     rather than amplified noise.
///  4. **contrast** — the linear stretch.
///  5. **deskew** — last, because it resamples every pixel; doing it earlier
///     would make the other steps resample the resample.
abstract final class EnhancementPipeline {
  /// Steps in execution order.
  static const List<EnhancementStep> order = <EnhancementStep>[
    EnhancementStep.perspectiveCorrect,
    EnhancementStep.grayscale,
    EnhancementStep.denoise,
    EnhancementStep.contrast,
    EnhancementStep.deskew,
  ];

  /// Runs [plan] over [source].
  ///
  /// [quad] is the detected (or user-dragged) page outline. When it is `null`
  /// the perspective step is reported as skipped rather than guessed at.
  static EnhancedImage apply(
    img.Image source, {
    required EnhancementPlan plan,
    ImageQuad? quad,
    double minSkewDegrees = 0.2,
  }) {
    var current = source;
    final applied = <EnhancementStep>[];
    final notes = <String>[];
    var cropped = false;
    double? skew;

    for (final step in order) {
      if (!plan.isEnabled(step)) continue;

      switch (step) {
        case EnhancementStep.perspectiveCorrect:
          if (quad == null) {
            notes.add('Bỏ qua chỉnh phối cảnh: chưa xác định được viền trang.');
            continue;
          }
          final result = rectify(current, quad);
          if (result == null) {
            notes.add('Bỏ qua chỉnh phối cảnh: viền trang không hợp lệ.');
            continue;
          }
          cropped = !(quad.isAxisAligned &&
              quad.width >= current.width * 0.995 &&
              quad.height >= current.height * 0.995);
          current = result;
          applied.add(step);

        case EnhancementStep.grayscale:
          if (current.numChannels == 1) {
            notes.add('Ảnh đã là ảnh xám.');
            continue;
          }
          // `img.grayscale` only equalizes R/G/B — it keeps three channels, so
          // the "already grey" early exit below would never fire and every
          // later step would still pay for three. Collapsing to one channel is
          // the part that actually saves the memory and the time.
          current = img.grayscale(current).convert(numChannels: 1);
          applied.add(step);

        case EnhancementStep.denoise:
          current = img.gaussianBlur(current, radius: 1);
          applied.add(step);

        case EnhancementStep.contrast:
          final before = _luminanceSpread(current);
          current = img.normalize(current, min: 0, max: 255);
          final after = _luminanceSpread(current);
          if (after - before < 0.02) {
            notes.add('Tương phản đã tốt sẵn, không cần tăng.');
          }
          applied.add(step);

        case EnhancementStep.deskew:
          final estimate = estimateSkew(current);
          skew = estimate.degrees;
          if (estimate.degrees == null) {
            notes.add('Không đo được độ nghiêng: trang không có dòng chữ rõ.');
            continue;
          }
          if (estimate.degrees!.abs() < minSkewDegrees) {
            notes.add('Trang đã thẳng, không cần xoay.');
            continue;
          }
          current = img.copyRotate(
            current,
            angle: estimate.degrees!,
            interpolation: img.Interpolation.linear,
          );
          applied.add(step);
      }
    }

    return EnhancedImage(
      image: current,
      report: EnhancementReport(
        applied: applied,
        notes: notes,
        width: current.width,
        height: current.height,
        skewDegrees: skew,
        cropped: cropped,
      ),
    );
  }

  /// Maps the quad to a rectangle, or `null` when the quad cannot produce one.
  ///
  /// The destination size comes from the quad's *own* edge lengths, so a page
  /// photographed from the side keeps its real aspect ratio instead of being
  /// squashed into the frame's.
  static img.Image? rectify(img.Image source, ImageQuad quad) {
    if (quad.isDegenerate) return null;

    final width =
        math.max(quad.topLeft.distanceTo(quad.topRight), quad.bottomLeft.distanceTo(quad.bottomRight));
    final height =
        math.max(quad.topLeft.distanceTo(quad.bottomLeft), quad.topRight.distanceTo(quad.bottomRight));
    final outWidth = width.round().clamp(16, 1 << 16);
    final outHeight = height.round().clamp(16, 1 << 16);

    final clamped = quad.clampedTo(
      source.width.toDouble(),
      source.height.toDouble(),
    );

    // An axis-aligned quad is a plain crop; running it through the bilinear
    // rectify would resample every pixel for no geometric gain.
    if (clamped.isAxisAligned) {
      final left = clamped.corners.map((p) => p.x).reduce(math.min).round();
      final top = clamped.corners.map((p) => p.y).reduce(math.min).round();
      final right = clamped.corners.map((p) => p.x).reduce(math.max).round();
      final bottom = clamped.corners.map((p) => p.y).reduce(math.max).round();
      final w = (right - left).clamp(16, 1 << 16);
      final h = (bottom - top).clamp(16, 1 << 16);
      return img.copyCrop(source, x: left, y: top, width: w, height: h);
    }

    return img.copyRectify(
      source,
      topLeft: img.Point(clamped.topLeft.x, clamped.topLeft.y),
      topRight: img.Point(clamped.topRight.x, clamped.topRight.y),
      bottomLeft: img.Point(clamped.bottomLeft.x, clamped.bottomLeft.y),
      bottomRight: img.Point(clamped.bottomRight.x, clamped.bottomRight.y),
      interpolation: img.Interpolation.linear,
      toImage: img.Image(width: outWidth, height: outHeight),
    );
  }

  static double _luminanceSpread(img.Image image) {
    final histogram = List<int>.filled(256, 0);
    var total = 0;
    for (final frame in image.frames) {
      for (final pixel in frame) {
        histogram[pixel.r.round().clamp(0, 255)]++;
        total++;
      }
    }
    if (total == 0) return 0;
    var low = 0;
    var high = 255;
    var seen = 0;
    for (var i = 0; i < 256; i++) {
      seen += histogram[i];
      if (seen >= total * 0.02) {
        low = i;
        break;
      }
    }
    seen = 0;
    for (var i = 255; i >= 0; i--) {
      seen += histogram[i];
      if (seen >= total * 0.02) {
        high = i;
        break;
      }
    }
    return (high - low) / 255;
  }
}

/// A skew measurement, or the reason there isn't one.
@immutable
class SkewEstimate {
  const SkewEstimate({required this.degrees, required this.confidence});

  /// Degrees to rotate the image by to straighten it. `null` when the page has
  /// no measurable text lines (blank page, a photo of a wall, heavy blur).
  final double? degrees;

  /// 0..1. How much better the best angle scored than a typical angle.
  final double confidence;

  bool get isMeasurable => degrees != null;

  @override
  String toString() => degrees == null
      ? 'SkewEstimate(none, confidence ${confidence.toStringAsFixed(2)})'
      : 'SkewEstimate(${degrees!.toStringAsFixed(2)}°, '
          'confidence ${confidence.toStringAsFixed(2)})';
}

/// Measures page tilt by scoring how strongly the text lines line up.
///
/// The score is the variance of the row-sum profile: with the baselines
/// horizontal each row is either mostly ink or mostly paper, so the profile is
/// spiky and its variance is high; at the wrong angle ink bleeds across rows and
/// the profile flattens.
///
/// The profile for a candidate angle is sampled along **tilted rows of the
/// original image** rather than by rotating a copy. That matters: `copyRotate`
/// grows the canvas and pads the new corners, so a rotated-and-cropped copy is
/// not the same amount of image at every angle, and on a page with no text at
/// all that asymmetry made the score rise monotonically toward the edge of the
/// search range — a blank page measured 7° of tilt. Sampling in place makes every
/// candidate an apples-to-apples measurement of the same pixels.
SkewEstimate estimateSkew(
  img.Image source, {
  double maxDegrees = 6,
  double coarseStep = 1,
  double fineStep = 0.25,
  int workingMaxDimension = 420,
  double minScoreGain = 0.02,
}) {
  if (source.width < 32 || source.height < 32) {
    return const SkewEstimate(degrees: null, confidence: 0);
  }

  final plane = buildLuminancePlane(source, maxDimension: workingMaxDimension);

  var bestDegrees = 0.0;
  var bestScore = -1.0;
  final coarseScores = <double>[];
  for (var a = -maxDegrees; a <= maxDegrees + 1e-9; a += coarseStep) {
    final score = _profileVariance(plane, a);
    coarseScores.add(score);
    if (score > bestScore) {
      bestScore = score;
      bestDegrees = a;
    }
  }

  var refinedDegrees = bestDegrees;
  var refinedScore = bestScore;
  for (var a = bestDegrees - coarseStep;
      a <= bestDegrees + coarseStep + 1e-9;
      a += fineStep) {
    final score = _profileVariance(plane, a);
    if (score > refinedScore) {
      refinedScore = score;
      refinedDegrees = a;
    }
  }

  if (refinedScore <= 0) {
    return const SkewEstimate(degrees: null, confidence: 0);
  }

  final sorted = List<double>.from(coarseScores)..sort();
  final median = sorted[sorted.length ~/ 2];
  final gain = (refinedScore - median) / refinedScore;
  if (gain < minScoreGain) {
    return SkewEstimate(degrees: null, confidence: gain.clamp(0.0, 1.0));
  }

  return SkewEstimate(
    degrees: _rotationToCorrect(plane, refinedDegrees),
    confidence: gain.clamp(0.0, 1.0).toDouble(),
  );
}

/// Converts the angle that best aligns the rows into the rotation that
/// straightens the image.
///
/// The sign was **measured, not reasoned about** — it is the one thing in this
/// file that is easy to get backwards and impossible to notice. Applying
/// `copyRotate(angle: A)` to a page and re-measuring returned exactly `A`, so the
/// alignment angle and the applied rotation share a convention, and undoing a
/// rotation means negating it. `test/domain/imaging/enhancement_test.dart`
/// rotates a page by a known angle, applies what this returns, and asserts the
/// residual tilt shrank; a wrong sign doubles the tilt and fails there.
double _rotationToCorrect(LuminancePlane plane, double bestDegrees) {
  assert(plane.width > 0);
  return -bestDegrees;
}

/// Variance of the row-mean profile when rows are sampled at [angleDegrees].
///
/// Rows whose samples would fall outside the image are dropped entirely rather
/// than clamped: a clamped sample would repeat the border pixel and add a
/// constant that varies with the angle, which is the same class of bias the
/// rotate-a-copy approach suffered from.
double _profileVariance(LuminancePlane plane, double angleDegrees) {
  final slope = math.tan(angleDegrees * math.pi / 180);
  final centerX = plane.width / 2;
  final maxShift = (slope.abs() * centerX).ceil() + 1;
  if (plane.height <= 2 * maxShift + 4) return 0;

  var sum = 0.0;
  var count = 0;
  final profile = <double>[];

  for (var y = maxShift; y < plane.height - maxShift; y++) {
    var rowSum = 0.0;
    for (var x = 0; x < plane.width; x++) {
      final sampleY = (y + slope * (x - centerX)).round();
      rowSum += plane.at(x, sampleY);
    }
    final rowMean = rowSum / plane.width;
    profile.add(rowMean);
    sum += rowMean;
    count++;
  }

  if (count < 8) return 0;
  final mean = sum / count;

  var variance = 0.0;
  for (final value in profile) {
    final delta = value - mean;
    variance += delta * delta;
  }
  return variance / count;
}
