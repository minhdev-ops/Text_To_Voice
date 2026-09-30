import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/semantic_colors.dart';
import '../../core/theme/tokens.dart';
import '../../domain/models/document_block.dart' show BlockType;
import '../../domain/models/ocr.dart' show OcrLine;
import '../../domain/ocr/ocr_structurer.dart' show StructuredSection;
import 'capture_providers.dart' show CapturedPage;

/// Which line the user is pointing at, across the whole page.
///
/// A pair rather than a flat index because a line only means something inside its
/// block: the outline needs the line's own box, and the block it belongs to is
/// what the reader will store.
@immutable
class ReviewSelection {
  const ReviewSelection({required this.section, required this.line});

  final int section;
  final int line;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewSelection &&
          other.section == section &&
          other.line == line);

  @override
  int get hashCode => Object.hash(section, line);

  @override
  String toString() => 'ReviewSelection($section.$line)';
}

/// The OCR review surface (DESIGN.md → `OcrReviewPane`, UX spec §4).
///
/// Two-pane at `expanded` (image | text) and stacked with a draggable divider
/// below that, because a split view on a phone gives neither side a readable
/// width.
///
/// Deliberately a fully parameterized presentational widget: the screen above it
/// owns selection, edit mode and the image/text split, so this can be pumped in a
/// test with an exact state instead of being driven there through taps that only
/// approximate the state under test.
class OcrReviewPane extends StatelessWidget {
  const OcrReviewPane({
    super.key,
    required this.page,
    required this.selectedLine,
    required this.editing,
    required this.showOriginal,
    required this.imageFraction,
    required this.onLineSelected,
    required this.onImageFractionChanged,
    required this.onTextChanged,
  });

  final CapturedPage page;

  /// `null` when nothing is selected — the outline is simply absent, which is a
  /// valid state and not an error.
  final ReviewSelection? selectedLine;

  /// `true` while the user is correcting the text. Editing is an explicit mode so
  /// a stray tap on a line locates it on the image instead of moving a cursor.
  final bool editing;

  /// `true` to show the untouched capture instead of the processed page.
  final bool showOriginal;

  /// Height share of the image pane in the stacked layout, clamped internally.
  final double imageFraction;

  final ValueChanged<ReviewSelection> onLineSelected;
  final ValueChanged<double> onImageFractionChanged;
  final ValueChanged<String> onTextChanged;

  /// The processed page is what the normalized line boxes refer to, so the
  /// outline is only drawn over it.
  ///
  /// The original capture has a different frame (the page may have been cropped
  /// and warped out of it), and drawing the same rectangle over it would point at
  /// the wrong pixels — a confidently wrong outline is worse than none.
  bool get _canOutline => !showOriginal && page.scan != null;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= Layout.mediumMax + 1;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: _buildImagePane(context)),
              const VerticalDivider(width: 1),
              Expanded(child: _buildTextPane(context)),
            ],
          );
        }
        return _buildStacked(context, constraints);
      },
    );
  }

  Widget _buildStacked(BuildContext context, BoxConstraints constraints) {
    final fraction = imageFraction.clamp(0.2, 0.7);
    final imageHeight = math.max(160.0, constraints.maxHeight * fraction);

    return Column(
      children: <Widget>[
        SizedBox(height: imageHeight, child: _buildImagePane(context)),
        _DragDivider(
          onDelta: (delta) {
            if (constraints.maxHeight <= 0) return;
            onImageFractionChanged(
              (fraction + delta / constraints.maxHeight).clamp(0.2, 0.7),
            );
          },
        ),
        Expanded(child: _buildTextPane(context)),
      ],
    );
  }

  Widget _buildImagePane(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semanticColors;
    final bytes = showOriginal || page.scan == null
        ? page.originalBytes
        : page.scan!.previewBytes;

    return Container(
      color: theme.colorScheme.surfaceContainerLowest,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.memory(
            bytes,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            // A capture that will not decode is a real possibility (a truncated
            // JPEG), and a broken-image box would hide the honest text below it.
            errorBuilder: (context, error, stackTrace) => Center(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.s16),
                child: Text(
                  'Không hiển thị được ảnh này.',
                  style: theme.utility.copyWith(color: semantic.danger),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          // Only painted when there is a resolved box to paint: a rectangle for
          // a line the engine gave no geometry for would be invented, and an
          // empty painter in the tree hides that from both the test and review.
          if (_canOutline && _selectedLineBox != null)
            Positioned.fill(
              child: CustomPaint(
                painter: _SelectionOutlinePainter(
                  position: _selectedLineBox,
                  color: theme.colorScheme.primary,
                  imageAspect: _processedAspect,
                ),
              ),
            ),
          if (showOriginal)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                color: theme.colorScheme.surface,
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.s16,
                  vertical: Spacing.s8,
                ),
                child: Text(
                  'Đang xem ảnh gốc. Vị trí dòng chỉ hiển thị trên bản đã xử lý.',
                  style: theme.utility
                      .copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Aspect ratio of the processed page, so the outline can be mapped through the
  /// same `BoxFit.contain` letterboxing the image uses. Without it the stroke
  /// drifts away from the line by exactly the letterbox margin — which looks
  /// almost right, and is the kind of almost that costs an hour of debugging.
  double? get _processedAspect {
    final scan = page.scan;
    if (scan == null || scan.processedHeight == 0) return null;
    return scan.processedWidth / scan.processedHeight;
  }

  /// The selected line's normalized box, or `null` when there is nothing to
  /// outline (no selection, or a line the engine gave no geometry for).
  _NormalizedBox? get _selectedLineBox {
    final selection = selectedLine;
    if (selection == null) return null;
    if (selection.section >= page.sections.length) return null;
    final lines = page.sections[selection.section].lines;
    if (selection.line >= lines.length) return null;
    return _NormalizedBox.from(lines[selection.line]);
  }

  Widget _buildTextPane(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semanticColors;

    if (editing) {
      return _EditableTextPane(
        text: page.text ?? '',
        onChanged: onTextChanged,
      );
    }

    if (page.sections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.s24),
          child: Text(
            page.textPending
                ? 'Ảnh đã được lưu nhưng chưa nhận dạng được chữ. '
                    'Bạn có thể quét lại hoặc tự nhập nội dung.'
                : 'Không tìm thấy chữ nào trong ảnh này.',
            style: theme.utility.copyWith(color: semantic.textSubtle),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: Spacing.s8),
      itemCount: page.sections.length,
      separatorBuilder: (context, index) => const SizedBox(height: Spacing.s8),
      itemBuilder: (context, sectionIndex) {
        final section = page.sections[sectionIndex];
        return _SectionView(
          section: section,
          sectionIndex: sectionIndex,
          selectedLine: selectedLine,
          onLineSelected: onLineSelected,
        );
      },
    );
  }
}

/// One structured block, rendered as its recognized lines.
///
/// Lines rather than the joined block text, because tapping has to resolve to a
/// single source region: a block is often a whole paragraph, and outlining a
/// paragraph when the user pointed at one line is useless.
class _SectionView extends StatelessWidget {
  const _SectionView({
    required this.section,
    required this.sectionIndex,
    required this.selectedLine,
    required this.onLineSelected,
  });

  final StructuredSection section;
  final int sectionIndex;
  final ReviewSelection? selectedLine;
  final ValueChanged<ReviewSelection> onLineSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semanticColors;
    final block = section.block;
    final isHeading = block.isHeading;
    final isTableOrList =
        block.type == BlockType.table || block.type == BlockType.list;

    final style = isHeading
        ? (block.type == BlockType.title
            ? theme.textTheme.headlineSmall
            : theme.textTheme.titleMedium)
        : theme.reading;

    return Container(
      decoration: BoxDecoration(
        // Footnotes and running headers are visible but marked as skipped in
        // read-aloud, so the distinction is visible in review too — otherwise a
        // skipped line looks like a bug when playback passes over it.
        border: block.isSkippedInReadAloud
            ? Border(
                left: BorderSide(color: semantic.border, width: 2),
              )
            : null,
      ),
      padding: EdgeInsets.only(left: block.isSkippedInReadAloud ? Spacing.s12 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (block.isSkippedInReadAloud)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.s4),
              child: Text(
                block.type == BlockType.footnote
                    ? 'Chú thích — không đọc thành tiếng'
                    : 'Đầu trang — không đọc thành tiếng',
                style: theme.utility.copyWith(color: semantic.textSubtle),
              ),
            ),
          for (var lineIndex = 0;
              lineIndex < section.lines.length;
              lineIndex++)
            _LineRow(
              line: section.lines[lineIndex],
              selected: selectedLine ==
                  ReviewSelection(section: sectionIndex, line: lineIndex),
              style: isTableOrList
                  ? theme.utility.copyWith(fontSize: TypeScale.bodyLarge)
                  : style,
              onTap: () => onLineSelected(
                ReviewSelection(section: sectionIndex, line: lineIndex),
              ),
            ),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.line,
    required this.selected,
    required this.style,
    required this.onTap,
  });

  final OcrLine line;
  final bool selected;
  final TextStyle? style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semanticColors;

    return Semantics(
      button: true,
      label: line.text,
      hint: 'Nhấn để xem vị trí dòng trên ảnh',
      selected: selected,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.s8,
            vertical: Spacing.s4,
          ),
          decoration: BoxDecoration(
            color: selected ? semantic.accentWash : null,
            border: Border(
              bottom: BorderSide(
                // Low confidence is a `warning` hairline, never a filled block
                // (DESIGN.md bans coloured blocks for state): the reviewer needs
                // to see the text they are judging.
                color: line.isLowConfidence
                    ? semantic.warning
                    : Colors.transparent,
              ),
            ),
          ),
          child: Text(line.text, style: style),
        ),
      ),
    );
  }
}

/// The correction surface.
///
/// A `StatefulWidget` purely because the `TextEditingController` has to outlive a
/// single build. Building one inline in `build()` looks identical on screen and
/// is broken: every keystroke rebuilds, the field is handed a brand-new controller
/// seeded with the *old* text, and the caret jumps to the end of the document.
class _EditableTextPane extends StatefulWidget {
  const _EditableTextPane({required this.text, required this.onChanged});

  final String text;
  final ValueChanged<String> onChanged;

  @override
  State<_EditableTextPane> createState() => _EditableTextPaneState();
}

class _EditableTextPaneState extends State<_EditableTextPane> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.text);

  @override
  void didUpdateWidget(_EditableTextPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only when the text changed *outside* the field — a re-scan replacing the
    // extracted text. Adopting it unconditionally would fight the user's typing.
    if (widget.text != oldWidget.text && widget.text != _controller.text) {
      _controller.text = widget.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(Spacing.s16),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        maxLines: null,
        expands: true,
        keyboardType: TextInputType.multiline,
        textAlignVertical: TextAlignVertical.top,
        style: theme.reading,
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Chưa có chữ nào. Bạn có thể tự nhập nội dung.',
        ),
      ),
    );
  }
}

/// The draggable rule between the image and the text in the stacked layout.
class _DragDivider extends StatelessWidget {
  const _DragDivider({required this.onDelta});

  final ValueChanged<double> onDelta;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).semanticColors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) => onDelta(details.delta.dy),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeRow,
        child: SizedBox(
          height: Spacing.s24,
          child: Center(
            child: Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: Spacing.s24),
              color: semantic.border,
            ),
          ),
        ),
      ),
    );
  }
}

/// A normalized (0..1) rectangle, which is what `BlockPosition` holds.
class _NormalizedBox {
  const _NormalizedBox(this.left, this.top, this.width, this.height);

  final double left;
  final double top;
  final double width;
  final double height;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _NormalizedBox &&
          other.left == left &&
          other.top == top &&
          other.width == width &&
          other.height == height);

  @override
  int get hashCode => Object.hash(left, top, width, height);

  static _NormalizedBox? from(OcrLine line) {
    final position = line.position;
    if (position == null || !position.isComplete) return null;
    return _NormalizedBox(
      position.left!,
      position.top!,
      position.width!,
      position.height!,
    );
  }
}

/// Draws the 2px accent stroke around the selected line's source region.
///
/// An outline, not an opaque highlight: the reviewer has to be able to read the
/// pixels underneath to decide whether the text is right (UX spec §4).
class _SelectionOutlinePainter extends CustomPainter {
  const _SelectionOutlinePainter({
    required this.position,
    required this.color,
    required this.imageAspect,
  });

  final _NormalizedBox? position;
  final Color color;

  /// Aspect ratio (width / height) of the image being displayed, or `null` when
  /// it is unknown — in which case the painted rect assumes the image fills the
  /// box exactly.
  final double? imageAspect;

  @override
  void paint(Canvas canvas, Size size) {
    final box = position;
    if (box == null || size.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;

    final aspect = imageAspect;
    if (aspect == null || aspect <= 0) {
      canvas.drawRect(
        Rect.fromLTWH(
          box.left * size.width,
          box.top * size.height,
          box.width * size.width,
          box.height * size.height,
        ),
        paint,
      );
      return;
    }

    // Same letterboxing `BoxFit.contain` applies: the drawn rectangle has to sit
    // on the image, not on the widget.
    final viewAspect = size.width / size.height;
    final double scale;
    final double dx;
    final double dy;
    if (aspect > viewAspect) {
      scale = size.width;
      dx = 0;
      dy = (size.height - size.width / aspect) / 2;
    } else {
      scale = size.height;
      dx = (size.width - size.height * aspect) / 2;
      dy = 0;
    }

    canvas.drawRect(
      Rect.fromLTWH(
        dx + box.left * scale,
        dy + box.top * scale,
        box.width * scale,
        box.height * scale,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SelectionOutlinePainter oldDelegate) =>
      oldDelegate.position != position ||
      oldDelegate.color != color ||
      oldDelegate.imageAspect != imageAspect;
}
