import 'dart:async' show Timer, unawaited;
import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../../core/theme/app_theme.dart';
import '../../core/theme/semantic_colors.dart';
import '../../core/theme/tokens.dart';
import '../../domain/models/document_block.dart';
import '../../domain/models/document_image.dart';
import '../../domain/models/reading.dart';
import 'image_viewer_screen.dart';

/// An image shown inline at its position in the reading flow.
///
/// `afterParagraph` places the picture where the document put it — after the
/// paragraphs that were read from its page — instead of in a separate gallery
/// that loses the reading order.
class ReadingImageSlot {
  const ReadingImageSlot({
    required this.image,
    required this.afterParagraph,
    this.caption,
  });

  final DocumentImage image;

  /// The paragraph index after which the image appears. `-1` puts it first.
  final int afterParagraph;

  /// Alt text or OCR caption, shown under the picture when there is one.
  final String? caption;
}

/// Places each page image after the last paragraph read from its page.
///
/// One paragraph per text block: the extracted text joins block contents with
/// blank lines and the sentence splitter keeps those boundaries, so paragraph
/// *i* is block *i*. An image from page *p* therefore follows the last
/// paragraph whose block was on page *p*.
///
/// When the two structures disagree — text edited after capture, a parser that
/// produced no blocks, a page whose text never arrived — every image goes to the
/// end rather than to a guessed position between the wrong paragraphs. Showing
/// a picture one paragraph early is a lie about the document; showing it at the
/// end is merely a compromise.
List<ReadingImageSlot> readingImageSlots({
  required List<Sentence> sentences,
  required List<DocumentBlock> blocks,
  required List<DocumentImage> images,
  required String documentId,
}) {
  if (images.isEmpty) return const <ReadingImageSlot>[];

  final lastParagraph =
      sentences.isEmpty ? -1 : sentences.last.paragraph;
  // The `page_id` is the link the repository actually stores and joins on, so it
  // is read first; the block's own `position.pageNumber` is only the fallback for
  // a block rewritten without one. (Preferring the position was how a page number
  // derived badly at read time ended up sending every image to the end.)
  final paragraphPages = <int?>[
    for (final block in blocks)
      pageNumberOf(block.pageId, documentId) ?? block.position?.pageNumber,
  ];

  if (paragraphPages.length != lastParagraph + 1) {
    return <ReadingImageSlot>[
      for (final image in images)
        ReadingImageSlot(image: image, afterParagraph: lastParagraph),
    ];
  }

  return <ReadingImageSlot>[
    for (final image in images)
      ReadingImageSlot(
        image: image,
        afterParagraph:
            _lastParagraphOfPage(paragraphPages, image.pageNumber) ??
                lastParagraph,
      ),
  ];
}

/// The last paragraph read from [page], or `null` when the document has none.
int? _lastParagraphOfPage(List<int?> paragraphPages, int? page) {
  for (var i = paragraphPages.length - 1; i >= 0; i--) {
    if (paragraphPages[i] == page) return i;
  }
  return null;
}

/// `3` from the page id the repository derives for page 3 of [documentId]
/// (`<documentId>-p3`).
int? pageNumberOf(String? pageId, String documentId) {
  if (pageId == null) return null;
  final prefix = '$documentId-p';
  if (!pageId.startsWith(prefix)) return null;
  return int.tryParse(pageId.substring(prefix.length));
}

/// The reading surface as **one continuous document**, not a stack of sentence
/// boxes.
///
/// The sentences of a paragraph flow together as prose — the way the document
/// was written — while every sentence keeps its own tap target and the
/// Listening Spine marks the one being spoken. An image the document contains
/// is rendered at its reading order between the paragraphs around it, and the
/// view follows the Spine with a gentle scroll so the words being spoken are
/// always on screen.
///
/// Virtualized: a `ListView` over *paragraphs*, so a five-hundred-paragraph
/// document builds only the screens near the viewport.
class ReadingView extends StatefulWidget {
  const ReadingView({
    super.key,
    required this.sentences,
    required this.currentIndex,
    this.images = const <ReadingImageSlot>[],
    required this.onSentenceTap,
  });

  final List<Sentence> sentences;
  final int currentIndex;
  final List<ReadingImageSlot> images;
  final ValueChanged<int> onSentenceTap;

  @override
  State<ReadingView> createState() => _ReadingViewState();
}

/// One item of the reading list: a paragraph of flowing sentences, or a
/// document image between them.
sealed class _ReadingItem {
  const _ReadingItem();
}

class _ParagraphItem extends _ReadingItem {
  const _ParagraphItem({required this.paragraph, required this.sentenceIndices});

  final int paragraph;
  final List<int> sentenceIndices;
}

class _ImageItem extends _ReadingItem {
  const _ImageItem(this.slot);

  final ReadingImageSlot slot;
}

class _ReadingViewState extends State<ReadingView> {
  static const Duration _autoScroll = Duration(milliseconds: 250);

  /// How long the view leaves the reader alone after they scroll by hand. A
  /// gentle follow that fights the finger is worse than no follow at all.
  static const Duration _handsOffAfterUserScroll = Duration(seconds: 8);

  final ScrollController _scroll = ScrollController();
  DateTime _lastUserScroll = DateTime.fromMillisecondsSinceEpoch(0);
  int _followedParagraph = -1;
  Timer? _followDebounce;

  /// One key per paragraph item, so the view can bring the paragraph being
  /// spoken into view. Created once per item list, not per build.
  Map<int, GlobalKey> _paragraphKeys = <int, GlobalKey>{};
  List<_ReadingItem> _items = const <_ReadingItem>[];

  @override
  void initState() {
    super.initState();
    _rebuildItems();
  }

  @override
  void didUpdateWidget(ReadingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.sentences, widget.sentences) ||
        oldWidget.images.length != widget.images.length) {
      _rebuildItems();
    }
  }

  @override
  void dispose() {
    _followDebounce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _rebuildItems() {
    final paragraphs = <int, List<int>>{};
    for (final sentence in widget.sentences) {
      (paragraphs[sentence.paragraph] ??= <int>[]).add(sentence.index);
    }

    final images = <int, List<ReadingImageSlot>>{};
    for (final slot in widget.images) {
      (images[slot.afterParagraph] ??= <ReadingImageSlot>[]).add(slot);
    }

    final items = <_ReadingItem>[];
    final keys = <int, GlobalKey>{};
    var paragraph = -1;
    // Paragraphs are gapless in the sentence model, but a defensive loop keeps
    // an out-of-order `paragraph` value from hiding every later paragraph.
    for (final entry in paragraphs.entries) {
      paragraph = entry.key;
      final paragraphItem = items.length;
      items.add(_ParagraphItem(
        paragraph: paragraph,
        sentenceIndices: entry.value,
      ));
      keys[paragraphItem] = GlobalKey();
      final after = images[paragraph];
      if (after != null) {
        for (final slot in after) {
          items.add(_ImageItem(slot));
        }
      }
    }
    // Images parked after a paragraph the document never produced (a text-less
    // scanned page) still get shown, at the end where they honestly belong.
    final orphan = images.values
        .expand((slots) => slots)
        .where((slot) => !paragraphs.containsKey(slot.afterParagraph));
    for (final slot in orphan) {
      items.add(_ImageItem(slot));
    }

    setState(() {
      _items = items;
      _paragraphKeys = keys;
      _followedParagraph = -1;
    });
  }

  /// The paragraph the Spine is on right now.
  int get _currentParagraph {
    if (widget.currentIndex < 0 ||
        widget.currentIndex >= widget.sentences.length) {
      return -1;
    }
    return widget.sentences[widget.currentIndex].paragraph;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Follow the Spine, debounced to the next frame so a burst of status
    // changes does not queue a burst of scrolls.
    final paragraph = _currentParagraph;
    if (paragraph != _followedParagraph) {
      _followedParagraph = paragraph;
      _followDebounce?.cancel();
      _followDebounce = Timer(Duration.zero, () => _bringIntoView(paragraph));
    }

    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        // Only a drag is the user's hand; programmatic and overscroll
        // notifications would reset the hands-off window on every follow.
        if (notification.direction == ScrollDirection.forward ||
            notification.direction == ScrollDirection.reverse) {
          _lastUserScroll = DateTime.now();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(vertical: Spacing.s16),
        // Pre-render a couple of screens so the follow scroll never lands on a
        // paragraph that is still being built.
        cacheExtent: 600,
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return switch (item) {
            _ParagraphItem() => _buildParagraph(
                context,
                theme,
                item,
                _paragraphKeys[index],
              ),
            _ImageItem() => _buildImage(theme, item.slot),
          };
        },
      ),
    );
  }

  Widget _buildParagraph(
    BuildContext context,
    ThemeData theme,
    _ParagraphItem item,
    Key? key,
  ) {
    final spans = <Widget>[];
    for (var i = 0; i < item.sentenceIndices.length; i++) {
      if (i > 0) {
        // The space that joins two sentences back into one line of prose.
        spans.add(Text(' ', style: theme.reading.copyWith(
          fontSize: TypeScale.bodyLarge,
        )));
      }
      spans.add(_SentenceSpan(
        key: ValueKey('sentence-${item.sentenceIndices[i]}'),
        sentence: widget.sentences[item.sentenceIndices[i]],
        isCurrent: item.sentenceIndices[i] == widget.currentIndex,
        onTap: () => widget.onSentenceTap(item.sentenceIndices[i]),
      ));
    }

    return Padding(
      key: key,
      padding: const EdgeInsets.only(
        left: Spacing.gutter,
        right: Spacing.gutter,
        bottom: Spacing.s12,
      ),
      child: Wrap(
        children: spans,
      ),
    );
  }

  Widget _buildImage(ThemeData theme, ReadingImageSlot slot) {
    final semantic = theme.semanticColors;
    final width = MediaQuery.sizeOf(context).width;
    final readerWidth = width < Layout.readerMaxWidth ? width : Layout.readerMaxWidth.toDouble();
    final devicePixels = (readerWidth * MediaQuery.devicePixelRatioOf(context)).round();

    final file = File(slot.image.filePath);
    final caption = slot.caption?.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.gutter,
        0,
        Spacing.gutter,
        Spacing.s16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          GestureDetector(
            onTap: () => unawaited(ImageViewerScreen.show(
              context,
              filePath: slot.image.filePath,
              heroTag: slot.image.id,
            )),
            child: ClipRRect(
              borderRadius: RadiusTokens.mdBorder,
              child: Image.file(
                file,
                width: double.infinity,
                fit: BoxFit.fitWidth,
                // Decode at display size, not camera size: a 12 MP page decoded
                // full for a thumbnail row is the exact memory spike NFR-05
                // forbids.
                cacheWidth: devicePixels,
                errorBuilder: (context, error, stack) => Container(
                  height: 120,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: RadiusTokens.mdBorder,
                  ),
                  child: Text(
                    'Không hiện được ảnh này.',
                    style: theme.utility.copyWith(color: semantic.danger),
                  ),
                ),
              ),
            ),
          ),
          if (caption != null && caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.s8),
              child: Text(caption, style: theme.utility),
            ),
        ],
      ),
    );
  }

  /// Brings the paragraph being spoken into view — unless the reader scrolled
  /// by hand moments ago, in which case their finger wins.
  void _bringIntoView(int paragraph) {
    if (paragraph < 0) return;
    if (DateTime.now().difference(_lastUserScroll) < _handsOffAfterUserScroll) {
      return;
    }
    final itemIndex = _items.indexWhere(
      (item) => item is _ParagraphItem && item.paragraph == paragraph,
    );
    if (itemIndex < 0) return;
    final key = _paragraphKeys[itemIndex];
    final context = key?.currentContext;
    if (context == null) return;

    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    Scrollable.ensureVisible(
      context,
      // A quarter from the top: the paragraph being read sits high on screen
      // with the following text visible under it.
      alignment: 0.25,
      duration: reduceMotion ? Duration.zero : _autoScroll,
      curve: reduceMotion ? Curves.linear : Curves.easeOutCubic,
    );
  }
}

/// One sentence of flowing prose: its own tap target, no box unless it is the
/// one being spoken.
class _SentenceSpan extends StatelessWidget {
  const _SentenceSpan({
    super.key,
    required this.sentence,
    required this.isCurrent,
    required this.onTap,
  });

  final Sentence sentence;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semanticColors;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final motion = reduceMotion ? Duration.zero : Motion.base;

    final status = sentence.status;
    final isFailed = status == SentenceStatus.failed;
    final isPlayed = status == SentenceStatus.played;

    final style = theme.reading.copyWith(
      fontSize: TypeScale.bodyLarge,
      color: isPlayed && !isCurrent
          ? theme.colorScheme.onSurfaceVariant
          : theme.colorScheme.onSurface,
      // A failed sentence keeps its place in the prose and says so with a
      // warning underline — a filled box here would shout.
      decoration: isFailed ? TextDecoration.underline : null,
      decorationColor: isFailed ? semantic.danger : null,
      decorationStyle: isFailed ? TextDecorationStyle.dashed : null,
    );

    return Semantics(
      label: sentence.display,
      hint: 'Nhấn để đọc từ câu này',
      selected: isCurrent,
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: motion,
          curve: Motion.standard,
          decoration: BoxDecoration(
            // The Listening Spine, inline: the accent wash sits behind the
            // words instead of in a left margin. The padding is unconditional
            // so highlighting never shifts the text sideways.
            color: isCurrent ? semantic.accentWash : Colors.transparent,
            borderRadius: const BorderRadius.all(Radius.circular(3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          child: Text(sentence.display, style: style),
        ),
      ),
    );
  }
}
