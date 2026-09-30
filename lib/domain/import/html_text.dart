import 'package:xml/xml.dart';

import '../models/document_block.dart' show BlockType;
import '../models/structured_block.dart' show StructuredBlock;

/// Turns one XHTML/HTML document into structured blocks.
///
/// Shared by the EPUB extractor and available to any future HTML input, because
/// both need the same thing: block-level structure in reading order, with the
/// inline noise (scripts, styles, navigation) gone and entities decoded.
///
/// It is a **block-level** reader on purpose. It does not attempt inline layout,
/// tables-of-contents generation or CSS — the SRS asks for text and structure that
/// feed the reader and read-aloud, and anything beyond that would be guessed.
abstract final class HtmlTextConverter {
  /// Elements whose text is never content.
  static const Set<String> _ignored = <String>{
    'script',
    'style',
    'head',
    'meta',
    'link',
    'title',
    'nav',
    'noscript',
    'svg',
    'iframe',
  };

  /// Heading tag → block level.
  static const Map<String, int> _headingLevels = <String, int>{
    'h1': 1,
    'h2': 2,
    'h3': 3,
    'h4': 4,
    'h5': 5,
    'h6': 6,
  };

  /// Converts [html] into blocks starting at [startOrder].
  ///
  /// [documentTitle] is emitted as a title block only when the document itself
  /// has no heading to introduce it — otherwise the book's `<title>` would be
  /// duplicated as a chapter heading on every chapter.
  static List<StructuredBlock> convert(
    String html, {
    int startOrder = 0,
    String? documentTitle,
  }) {
    final document = XmlDocument.parse(html);
    final blocks = <StructuredBlock>[];
    var order = startOrder;
    var sawHeading = false;

    void add(BlockType type, String text, {int level = 0, Map<String, Object?> metadata = const {}}) {
      final normalized = _collapseWhitespace(text);
      if (normalized.isEmpty) return;
      blocks.add(StructuredBlock(
        type: type,
        content: normalized,
        order: order++,
        level: level,
        metadata: metadata,
      ));
    }

    for (final element in document.descendants.whereType<XmlElement>()) {
      final tag = element.name.local.toLowerCase();
      if (_ignored.contains(tag)) continue;
      // Only leaf-ish block elements are emitted: a `<div><p>a</p><p>b</p></div>`
      // would otherwise produce the whole div as one block *and* its paragraphs.
      if (element.descendants.whereType<XmlElement>().any(_isBlockLevel)) continue;

      if (_headingLevels.containsKey(tag)) {
        sawHeading = true;
        add(BlockType.heading, _text(element), level: _headingLevels[tag]!);
        continue;
      }
      switch (tag) {
        case 'title':
          add(BlockType.title, _text(element), level: 1);
        case 'blockquote':
          add(BlockType.paragraph, _text(element),
              metadata: const <String, Object?>{'quote': true});
        case 'pre':
          add(BlockType.paragraph, _rawText(element),
              metadata: const <String, Object?>{'preformatted': true});
        case 'li':
          add(BlockType.list, '• ${_text(element)}');
        case 'img':
          final alt = element.getAttribute('alt') ?? '';
          final src = element.getAttribute('src') ?? '';
          add(BlockType.image, alt.isEmpty ? src : alt,
              metadata: <String, Object?>{'src': src, if (alt.isNotEmpty) 'alt': alt});
        case 'figcaption':
          add(BlockType.paragraph, _text(element),
              metadata: const <String, Object?>{'caption': true});
        case 'p':
        case 'div':
        case 'section':
        case 'article':
        case 'td':
        case 'dd':
        case 'dt':
          add(BlockType.paragraph, _text(element));
      }
    }

    if (!sawHeading && documentTitle != null && documentTitle.trim().isNotEmpty) {
      blocks.insert(
        0,
        StructuredBlock(
          type: BlockType.title,
          content: _collapseWhitespace(documentTitle),
          order: startOrder,
          level: 1,
        ),
      );
      // Re-number after the insert so `order` stays gapless and 0-based.
      for (var i = 0; i < blocks.length; i++) {
        blocks[i] = blocks[i].copyWith(order: startOrder + i);
      }
    }

    return blocks;
  }

  /// Plain text of [html] with block boundaries preserved as newlines. Used for
  /// the flat projection and for search.
  static String plainText(String html) {
    final blocks = convert(html);
    return blocks
        .where((block) => block.type != BlockType.image)
        .map((block) => block.content)
        .join('\n\n');
  }

  static bool _isBlockLevel(XmlElement element) => <String>{
        ..._headingLevels.keys,
        'p',
        'div',
        'section',
        'article',
        'li',
        'blockquote',
        'pre',
        'figcaption',
      }.contains(element.name.local.toLowerCase());

  /// Concatenated text of [element]'s descendants, with `<br>` as a break.
  static String _text(XmlElement element) {
    final buffer = StringBuffer();
    for (final node in element.descendants) {
      if (node is XmlText) {
        buffer.write(node.value);
      } else if (node is XmlElement && node.name.local.toLowerCase() == 'br') {
        buffer.write('\n');
      }
    }
    return buffer.toString();
  }

  static String _rawText(XmlElement element) => _text(element);

  /// HTML collapses runs of whitespace, and a reader that kept them would show
  /// the source indentation as accidental indentation of the text.
  static String _collapseWhitespace(String value) =>
      value.replaceAll(RegExp(r'[ \t\r\f\v]+'), ' ').replaceAll(RegExp(r'\n{2,}'), '\n').trim();
}
