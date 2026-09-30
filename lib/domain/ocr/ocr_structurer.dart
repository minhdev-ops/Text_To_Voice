import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;

import '../models/document_block.dart' show BlockPosition, BlockType;
import '../models/ocr.dart' show OcrLine;
import '../models/structured_block.dart' show StructuredBlock;

/// Tuning for [OcrStructurer]. Every ratio here was chosen against the synthetic
/// page layouts in `test/domain/ocr/ocr_structurer_test.dart`; they are
/// heuristics, and the class says so rather than pretending to be typography.
@immutable
class OcrStructureOptions {
  const OcrStructureOptions({
    this.paragraphGapRatio = 1.35,
    this.indentRatio = 1.5,
    this.heightChangeRatio = 0.22,
    this.titleHeightRatio = 1.5,
    this.headingHeightRatio = 1.18,
    this.headingMaxChars = 90,
    this.smallTextRatio = 0.82,
    this.footnoteZoneTop = 0.85,
    this.furnitureZoneRatio = 0.055,
    this.maxFurnitureChars = 60,
    this.columnGutterRatio = 0.05,
    this.columnMinShareRatio = 0.22,
    this.columnMinExtentRatio = 0.32,
    this.tableColumnGapChars = 3,
    this.tableMinColumns = 3,
    this.maxHeaderLevel = 3,
  });

  /// Vertical gap, as a multiple of the median line height, that starts a new
  /// paragraph.
  final double paragraphGapRatio;

  /// Horizontal offset, as a multiple of the median line height, that counts as
  /// an indent.
  final double indentRatio;

  /// Relative line-height change that starts a new block.
  final double heightChangeRatio;

  /// Line height, relative to the page median, at which the first block is
  /// called a [BlockType.title].
  final double titleHeightRatio;

  /// Line height, relative to the page median, at which a block is called a
  /// [BlockType.heading].
  final double headingHeightRatio;

  /// A heading longer than this is prose that happens to be set large.
  final int headingMaxChars;

  /// Line height below which text is "small print".
  final double smallTextRatio;

  /// Normalized distance from the top of the page past which small print is a
  /// footnote.
  final double footnoteZoneTop;

  /// Top/bottom band of the page treated as running-header territory.
  final double furnitureZoneRatio;

  /// Furniture is short by nature; a long line near the margin is body text.
  final int maxFurnitureChars;

  /// Minimum width of an all-blank vertical band, as a fraction of page width,
  /// to call it a column gutter.
  final double columnGutterRatio;

  /// Each side of a gutter must hold at least this share of the page's lines.
  final double columnMinShareRatio;

  /// Each column must span at least this share of the page height.
  final double columnMinExtentRatio;

  /// Spaces in a row that separate table cells.
  final int tableColumnGapChars;

  /// Cells per row before a run of lines counts as a table.
  final int tableMinColumns;

  final int maxHeaderLevel;
}

/// One block together with the recognized lines it was built from.
///
/// The two travel together because the review pane needs both: the block is what
/// the reader shows, the lines are what the finger taps and what the accent
/// rectangle on the image is drawn from.
@immutable
class StructuredSection {
  const StructuredSection({required this.block, required this.lines});

  final StructuredBlock block;
  final List<OcrLine> lines;

  /// True when any line in this section was recognized with low confidence —
  /// what the `warning` hairline and the "N dòng cần kiểm tra" banner count.
  bool get hasLowConfidenceLine => lines.any((line) => line.isLowConfidence);

  @override
  String toString() => 'StructuredSection(${block.type}, ${lines.length} lines)';
}

/// Turns the raw lines an [OcrEngine] returns into document structure.
///
/// The engine's job is to say what it saw and how sure it was; guessing which
/// line is a heading is a different problem with different failure modes, and
/// keeping them apart means a structurer fix never risks the recognition path.
///
/// Coordinates are **normalized to 0..1 of the page**, which is `BlockPosition`'s
/// contract. The structurer therefore never needs the pixel size of the capture,
/// and the same thresholds work for a 1080p camera frame and a scanned page.
class OcrStructurer {
  OcrStructurer({this.options = const OcrStructureOptions()});

  final OcrStructureOptions options;

  /// Page furniture is only furniture if it *repeats*.
  ///
  /// A single short line in the top margin is a title. The same line at the top
  /// of pages 2–5 is a running header, and skipping it in read-aloud is correct
  /// only for the second case. So the structurer keeps one instance per document
  /// and remembers what it has seen, instead of hard-coding "anything in the
  /// margin is skipped" — which would delete the title of every one-page
  /// document.
  final Map<String, int> _furnitureSeen = <String, int>{};
  int _pagesSeen = 0;

  /// Forgets what it learned about running headers. Call when a new document
  /// starts: carrying a previous document's headers into the next one would
  /// skip the *new* document's real first line.
  void reset() {
    _furnitureSeen.clear();
    _pagesSeen = 0;
  }

  /// Structures one page of recognized lines.
  ///
  /// [startOrder] lets a multi-page job keep `order` gapless across pages.
  List<StructuredBlock> structure(
    List<OcrLine> lines, {
    int? pageNumber,
    int startOrder = 0,
  }) =>
      sections(lines, pageNumber: pageNumber, startOrder: startOrder)
          .map((section) => section.block)
          .toList(growable: false);

  /// The same pass, keeping each block's source lines.
  ///
  /// The review pane needs both halves: the block to render as a paragraph, and
  /// the individual lines to hit-test and outline on the image. Deriving the
  /// line-to-block link afterwards would mean matching text back to lines, which
  /// breaks the moment two lines read alike.
  List<StructuredSection> sections(
    List<OcrLine> lines, {
    int? pageNumber,
    int startOrder = 0,
  }) {
    final usable = <_OcrLine>[];
    for (final line in lines) {
      final text = line.text.trim();
      if (text.isEmpty) continue;
      usable.add(_OcrLine(text: text, source: line, pageNumber: pageNumber));
    }
    if (usable.isEmpty) return const <StructuredSection>[];

    _pagesSeen++;

    // Without geometry there is no honest way to group: guessing paragraph
    // breaks from punctuation alone would invent structure. One block, and the
    // caller can still read and speak it.
    if (usable.every((line) => !line.hasPosition)) {
      return <StructuredSection>[
        StructuredSection(
          block: StructuredBlock(
            type: BlockType.paragraph,
            content: usable.map((line) => line.text).join('\n'),
            order: startOrder,
            confidence: _minConfidence(usable),
            metadata: const <String, Object?>{'structure': 'no_geometry'},
          ),
          lines: usable.map((line) => line.source).toList(growable: false),
        ),
      ];
    }

    final medianHeight = _medianHeight(usable);
    final ordered = _inReadingOrder(usable, medianHeight);
    final runs = _groupIntoRuns(ordered, medianHeight);

    final sections = <StructuredSection>[];
    var order = startOrder;
    for (final run in runs) {
      sections.add(StructuredSection(
        block: _classify(run, medianHeight, order),
        lines: run.map((line) => line.source).toList(growable: false),
      ));
      order++;
    }

    return _markFurnitureAcrossPages(sections);
  }

  // -- reading order ---------------------------------------------------------

  /// Sorts lines into reading order, handling a two-column page.
  ///
  /// Column detection is the one thing that cannot be skipped: a two-column page
  /// sorted purely top-to-bottom interleaves the columns, and read-aloud then
  /// produces alternating half-sentences. It is capped at two columns and
  /// verified two ways (both sides must hold a real share of the lines *and*
  /// span most of the page height) because a false positive here scrambles a
  /// perfectly ordinary single-column page.
  List<_OcrLine> _inReadingOrder(List<_OcrLine> lines, double medianHeight) {
    final positioned = lines.where((line) => line.hasPosition).toList();
    final unpositioned =
        lines.where((line) => !line.hasPosition).toList(growable: false);

    if (positioned.length < 4) {
      return <_OcrLine>[...positioned..sort(_byTopLeft), ...unpositioned];
    }

    final left = positioned.map((l) => l.left!).reduce(math.min);
    final right = positioned.map((l) => l.right!).reduce(math.max);
    final width = right - left;
    if (width <= 0) return <_OcrLine>[...positioned..sort(_byTopLeft), ...unpositioned];

    final gutter = _findGutter(positioned, left, width);
    if (gutter == null) {
      return <_OcrLine>[...positioned..sort(_byTopLeft), ...unpositioned];
    }

    final (gutterStart, gutterEnd) = gutter;
    final leftColumn = <_OcrLine>[];
    final rightColumn = <_OcrLine>[];
    for (final line in positioned) {
      final center = (line.left! + line.right!) / 2;
      if (center < (gutterStart + gutterEnd) / 2) {
        leftColumn.add(line);
      } else {
        rightColumn.add(line);
      }
    }

    final top = positioned.map((l) => l.top!).reduce(math.min);
    final bottom = positioned.map((l) => l.bottom!).reduce(math.max);
    final extent = bottom - top;

    final balanced = leftColumn.length >=
            (positioned.length * options.columnMinShareRatio).ceil() &&
        rightColumn.length >=
            (positioned.length * options.columnMinShareRatio).ceil();
    final bothSpan =
        _extentRatio(leftColumn, top, extent) >=
                options.columnMinExtentRatio &&
            _extentRatio(rightColumn, top, extent) >=
                options.columnMinExtentRatio;

    // Two independent checks, because a single blank band inside one column of
    // ordinary prose (a short line, a centred heading) satisfies the gutter test
    // on its own and would scramble a perfectly normal page.
    if (!balanced || !bothSpan) {
      return <_OcrLine>[...positioned..sort(_byTopLeft), ...unpositioned];
    }

    leftColumn.sort(_byTopLeft);
    rightColumn.sort(_byTopLeft);
    return <_OcrLine>[...leftColumn, ...rightColumn, ...unpositioned];
  }

  double _extentRatio(List<_OcrLine> lines, double pageTop, double pageExtent) {
    if (lines.isEmpty || pageExtent <= 0) return 0;
    final top = lines.map((l) => l.top!).reduce(math.min);
    final bottom = lines.map((l) => l.bottom!).reduce(math.max);
    return (bottom - top) / pageExtent;
  }

  /// The widest all-blank vertical band, when it looks like a real gutter.
  ///
  /// Returns `null` when no band is wide enough, or when the band is so close to
  /// one edge that it is really the page margin rather than a gutter.
  (double, double)? _findGutter(List<_OcrLine> lines, double pageLeft, double width) {
    const steps = 240;
    final covered = List<bool>.filled(steps, false);
    for (final line in lines) {
      final a = (((line.left! - pageLeft) / width) * steps).floor().clamp(0, steps - 1);
      final b = (((line.right! - pageLeft) / width) * steps).ceil().clamp(0, steps - 1);
      for (var i = a; i <= b; i++) {
        covered[i] = true;
      }
    }

    final minGapSteps = (options.columnGutterRatio * steps).ceil();
    var bestStart = -1;
    var bestLength = 0;
    var currentStart = -1;

    for (var i = 0; i <= steps; i++) {
      final blank = i < steps && !covered[i];
      if (blank && currentStart < 0) currentStart = i;
      if (!blank && currentStart >= 0) {
        final length = i - currentStart;
        if (length > bestLength) {
          bestLength = length;
          bestStart = currentStart;
        }
        currentStart = -1;
      }
    }

    if (bestStart < 0 || bestLength < minGapSteps) return null;
    final startFraction = bestStart / steps;
    final endFraction = (bestStart + bestLength) / steps;
    // A band hugging either edge is the page margin, not a gutter.
    if (startFraction < 0.05 || endFraction > 0.95) return null;

    return (
      pageLeft + startFraction * width,
      pageLeft + endFraction * width,
    );
  }

  static int _byTopLeft(_OcrLine a, _OcrLine b) {
    final byTop = a.top!.compareTo(b.top!);
    if (byTop != 0) return byTop;
    return a.left!.compareTo(b.left!);
  }

  // -- paragraph grouping ----------------------------------------------------

  List<List<_OcrLine>> _groupIntoRuns(List<_OcrLine> lines, double medianHeight) {
    final runs = <List<_OcrLine>>[];
    var current = <_OcrLine>[];
    double? currentHeight;

    for (final line in lines) {
      if (current.isEmpty) {
        current = <_OcrLine>[line];
        currentHeight = line.height;
        continue;
      }

      final previous = current.last;
      final gap = (line.top ?? 0) - (previous.bottom ?? 0);
      final heightChange = currentHeight == null || currentHeight == 0
          ? 0.0
          : ((line.height ?? 0) - currentHeight).abs() / currentHeight;
      final indent = (line.left ?? 0) - (previous.left ?? 0);
      final previousEndedShort = _endsShortOfMargin(previous, lines);

      final newParagraph = gap > medianHeight * options.paragraphGapRatio ||
          heightChange > options.heightChangeRatio ||
          (indent > medianHeight * options.indentRatio && previousEndedShort);

      if (newParagraph) {
        runs.add(current);
        current = <_OcrLine>[line];
        currentHeight = line.height;
      } else {
        current.add(line);
      }
    }
    if (current.isNotEmpty) runs.add(current);
    return runs.expand(_splitTableRows).toList(growable: false);
  }

  /// Pulls a table out of the paragraph it was grouped into.
  ///
  /// A table caption sits one line-height above the header row, so the paragraph
  /// grouper — correctly — puts them in the same run. The run as a whole then
  /// fails "every line has three cells", which is how a single caption line used
  /// to swallow an entire table into one paragraph. Splitting here keeps both
  /// facts instead of dropping one: the caption stays prose, the rows become a
  /// table.
  List<List<_OcrLine>> _splitTableRows(List<_OcrLine> run) {
    if (run.length < 2) return <List<_OcrLine>>[run];

    final flags = run
        .map((line) => _cellCount(line.text) >= options.tableMinColumns)
        .toList(growable: false);
    if (!flags.contains(true)) return <List<_OcrLine>>[run];

    final segments = <({bool isRow, List<_OcrLine> lines})>[];
    var start = 0;
    for (var i = 1; i <= run.length; i++) {
      if (i == run.length || flags[i] != flags[start]) {
        segments.add((isRow: flags[start], lines: run.sublist(start, i)));
        start = i;
      }
    }

    final merged = <List<_OcrLine>>[];
    for (final segment in segments) {
      // One wide-spaced line alone is a line of text that happens to have gaps,
      // not a table. Merging it back keeps the structurer from claiming a table
      // it cannot support.
      if (segment.isRow && segment.lines.length < 2 && merged.isNotEmpty) {
        merged.last.addAll(segment.lines);
      } else {
        merged.add(segment.lines);
      }
    }
    return merged;
  }

  /// A line that stops well before the right margin is the last line of a
  /// paragraph — the strongest prose signal available without word wrapping.
  bool _endsShortOfMargin(_OcrLine line, List<_OcrLine> all) {
    if (!line.hasPosition) return false;
    final rightEdge = all
        .where((l) => l.hasPosition)
        .map((l) => l.right!)
        .reduce(math.max);
    final leftEdge = all
        .where((l) => l.hasPosition)
        .map((l) => l.left!)
        .reduce(math.min);
    final width = rightEdge - leftEdge;
    if (width <= 0) return false;
    // 12% short of the margin: enough that justification cannot explain it.
    return (rightEdge - line.right!) > width * 0.12;
  }

  // -- classification --------------------------------------------------------

  StructuredBlock _classify(
    List<_OcrLine> run,
    double medianHeight,
    int order,
  ) {
    final text = run.map((line) => line.text).join(' ');
    final height = _medianHeight(run);
    final ratio = medianHeight == 0 ? 1.0 : height / medianHeight;
    final top = run.first.top;
    final bottom = run.last.bottom;
    final confidence = _minConfidence(run);
    final position = _spanOf(run);

    if (_isTableRun(run)) {
      return StructuredBlock(
        type: BlockType.table,
        content: run.map(_tableRow).join('\n'),
        order: order,
        position: position,
        confidence: confidence,
        metadata: const <String, Object?>{'structure': 'ocr_table_best_effort'},
      );
    }

    // Footnote **before** list, deliberately. Real footnotes are numbered
    // ("1. Ghi chú…"), so the list-marker test matches them every time, and a
    // numbered footnote read aloud as a bullet is exactly the bug this ordering
    // prevents. Small type in the bottom zone is the stronger signal.
    final isSmall = ratio <= options.smallTextRatio;
    final inFootnoteZone = top != null && top >= options.footnoteZoneTop;
    if (isSmall && inFootnoteZone) {
      return StructuredBlock(
        type: BlockType.footnote,
        content: text,
        order: order,
        position: position,
        confidence: confidence,
        metadata: const <String, Object?>{'skip_in_read_aloud': true},
      );
    }

    if (run.every(_startsWithListMarker)) {
      return StructuredBlock(
        type: BlockType.list,
        content: run
            .map((line) => _stripListMarker(line.text))
            .map((item) => '• $item')
            .join('\n'),
        order: order,
        position: position,
        confidence: confidence,
      );
    }

    final short = text.length <= options.headingMaxChars;
    if (short && ratio >= options.titleHeightRatio && order == 0) {
      return StructuredBlock(
        type: BlockType.title,
        content: text,
        order: order,
        level: 1,
        position: position,
        confidence: confidence,
      );
    }
    if (short && ratio >= options.headingHeightRatio) {
      return StructuredBlock(
        type: BlockType.heading,
        content: text,
        order: order,
        level: _headingLevel(ratio),
        position: position,
        confidence: confidence,
      );
    }

    return StructuredBlock(
      type: BlockType.paragraph,
      content: text,
      order: order,
      position: position,
      confidence: confidence,
      metadata: bottom != null && bottom <= options.furnitureZoneRatio
          ? const <String, Object?>{'margin': 'top'}
          : top != null && top >= 1 - options.furnitureZoneRatio
              ? const <String, Object?>{'margin': 'bottom'}
              : const <String, Object?>{},
    );
  }

  int _headingLevel(double ratio) {
    if (ratio >= options.titleHeightRatio) return 1;
    // 1.18–1.5 is a wide band; split the difference so a document with two
    // heading sizes does not collapse both into level 2.
    if (ratio >= (options.headingHeightRatio + options.titleHeightRatio) / 2) {
      return 2;
    }
    return options.maxHeaderLevel;
  }

  bool _isTableRun(List<_OcrLine> run) {
    if (run.length < 2) return false;
    return run.every((line) => _cellCount(line.text) >= options.tableMinColumns);
  }

  int _cellCount(String text) {
    final pattern = RegExp('\\s{${options.tableColumnGapChars},}');
    return pattern.allMatches(text).length + 1;
  }

  String _tableRow(_OcrLine line) {
    final pattern = RegExp('\\s{${options.tableColumnGapChars},}');
    return line.text
        .split(pattern)
        .map((cell) => cell.trim())
        .where((cell) => cell.isNotEmpty)
        .join(' | ');
  }

  static final RegExp _listMarker = RegExp(
    r'^\s*(?:[-–—•*·]|\(?\d{1,3}[.)]|[a-z][.)]|[IVXLC]{1,4}[.)])\s+',
    caseSensitive: false,
  );

  bool _startsWithListMarker(_OcrLine line) =>
      _listMarker.hasMatch(line.text);

  String _stripListMarker(String text) =>
      text.replaceFirst(_listMarker, '').trim();

  // -- running headers and footers -------------------------------------------

  /// Marks a margin line as furniture only once it has appeared on more than one
  /// page. The first occurrence is kept as ordinary content.
  List<StructuredSection> _markFurnitureAcrossPages(
    List<StructuredSection> sections,
  ) {
    final result = <StructuredSection>[];
    for (final section in sections) {
      final block = section.block;
      final margin = block.metadata['margin'];
      if (margin == null || block.content.length > options.maxFurnitureChars) {
        result.add(section);
        continue;
      }
      final key = '$margin:${_normalizeForRepeat(block.content)}';
      final seen = (_furnitureSeen[key] ?? 0) + 1;
      _furnitureSeen[key] = seen;

      if (seen > 1 && _pagesSeen > 1) {
        result.add(StructuredSection(
          block: block.copyWith(metadata: <String, Object?>{
            ...block.metadata,
            'page_furniture': true,
            'skip_in_read_aloud': true,
          }),
          lines: section.lines,
        ));
      } else {
        result.add(section);
      }
    }
    return result;
  }

  /// Digits are stripped before comparing: "Trang 2" and "Trang 3" are the same
  /// running footer, and treating them as different is exactly the bug that
  /// leaves page numbers being read aloud.
  String _normalizeForRepeat(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'\d+'), '#').replaceAll(RegExp(r'\s+'), ' ').trim();

  // -- helpers ---------------------------------------------------------------

  double _medianHeight(List<_OcrLine> lines) {
    final heights = lines
        .where((line) => line.height != null && line.height! > 0)
        .map((line) => line.height!)
        .toList()
      ..sort();
    if (heights.isEmpty) return 0;
    return heights[heights.length ~/ 2];
  }

  double? _minConfidence(List<_OcrLine> lines) {
    final scored = lines
        .map((line) => line.source.confidence)
        .whereType<double>()
        .toList();
    if (scored.isEmpty) return null;
    // The **minimum**, not the mean: one misread line in a paragraph is what a
    // person needs to check, and averaging it against nine clean lines hides it.
    return scored.reduce(math.min);
  }

  BlockPosition? _spanOf(List<_OcrLine> run) {
    final positioned = run.where((line) => line.hasPosition).toList();
    if (positioned.isEmpty) return null;
    final left = positioned.map((l) => l.left!).reduce(math.min);
    final right = positioned.map((l) => l.right!).reduce(math.max);
    final top = positioned.map((l) => l.top!).reduce(math.min);
    final bottom = positioned.map((l) => l.bottom!).reduce(math.max);
    return BlockPosition(
      pageNumber: run.first.pageNumber,
      left: left,
      top: top,
      width: right - left,
      height: bottom - top,
    );
  }
}

/// One recognized line plus its normalized geometry, so the algorithms above do
/// not each have to re-derive `right`/`bottom` from nullable fields.
class _OcrLine {
  _OcrLine({required this.text, required this.source, this.pageNumber});

  final String text;
  final OcrLine source;
  final int? pageNumber;

  BlockPosition? get _box => source.position;

  bool get hasPosition => _box != null && _box!.isComplete;

  double? get left => _box?.left;
  double? get top => _box?.top;
  double? get right =>
      _box == null || _box!.left == null || _box!.width == null
          ? null
          : _box!.left! + _box!.width!;
  double? get bottom =>
      _box == null || _box!.top == null || _box!.height == null
          ? null
          : _box!.top! + _box!.height!;

  double? get height => _box?.height;
}
