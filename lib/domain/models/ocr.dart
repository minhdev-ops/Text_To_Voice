import 'package:collection/collection.dart' show DeepCollectionEquality;
import 'package:flutter/foundation.dart' show immutable;

import 'document_block.dart' show BlockPosition;

/// One recognized line. Line-level rather than block-level because layout
/// grouping happens afterwards in the structure step — OCR's job is to say what
/// it saw and how sure it was, not to guess paragraphs.
@immutable
class OcrLine {
  const OcrLine({
    required this.text,
    this.confidence,
    this.position,
    this.pageNumber,
  });

  final String text;

  /// 0..1, when the engine reports one.
  final double? confidence;

  final BlockPosition? position;
  final int? pageNumber;

  bool get isLowConfidence => confidence != null && confidence! < 0.85;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OcrLine &&
          other.text == text &&
          other.confidence == confidence &&
          other.position == position &&
          other.pageNumber == pageNumber);

  @override
  int get hashCode => Object.hash(text, confidence, position, pageNumber);

  @override
  String toString() => 'OcrLine(${confidence ?? "-"}, "$text")';
}

/// Result of one `OcrEngine.recognize` call — SRS §26.
@immutable
class OcrResult {
  const OcrResult({
    required this.lines,
    this.language,
    this.engineId,
    this.pageNumber,
    this.elapsed,
  });

  final List<OcrLine> lines;

  /// Recognized BCP-47 tag, e.g. `vi-VN`.
  final String? language;

  /// Which engine produced this. Logged with the document so a bad OCR run can
  /// be attributed later.
  final String? engineId;

  final int? pageNumber;
  final Duration? elapsed;

  /// Flat text. Derived from [lines] — never stored separately, so the two can
  /// never disagree (derive, don't store).
  String get text =>
      lines.isEmpty ? '' : lines.map((line) => line.text).join('\n');

  bool get isEmpty => text.trim().isEmpty;

  double? get averageConfidence {
    final scored = lines.where((l) => l.confidence != null).toList();
    if (scored.isEmpty) return null;
    return scored.fold<double>(0, (sum, l) => sum + l.confidence!) /
        scored.length;
  }

  List<OcrLine> get lowConfidenceLines =>
      lines.where((l) => l.isLowConfidence).toList(growable: false);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OcrResult &&
          const DeepCollectionEquality()
              .equals(other.lines, lines) &&
          other.language == language &&
          other.engineId == engineId &&
          other.pageNumber == pageNumber &&
          other.elapsed == elapsed);

  @override
  int get hashCode => Object.hash(
        const DeepCollectionEquality().hash(lines),
        language,
        engineId,
        pageNumber,
        elapsed,
      );

  @override
  String toString() =>
      'OcrResult(${lines.length} lines, engine $engineId)';
}
