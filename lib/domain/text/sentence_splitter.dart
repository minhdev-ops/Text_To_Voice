/// FR-12: documents are never synthesized as one audio file, and the Listening
/// Spine needs a discrete unit to point at. This produces those units.
///
/// The hard part of a Vietnamese sentence splitter is not the terminators —
/// it is knowing when a `.` is **not** one. `TS. Nguyễn Văn A tốt nghiệp.
/// Ông nhận bằng năm 2019.` must yield two sentences, not four. The approach
/// is masking: protect every `.` that cannot end a sentence, split on what
/// remains, then unmask.
class SentenceSplitter {
  const SentenceSplitter();

  /// Character used while masking. In the private-use area so it cannot occur
  /// in real input.
  static const String _mask = '';

  /// Uppercase letters including the Vietnamese ones. Hand-listed rather than
  /// `\p{Lu}` so the behaviour does not depend on the regex engine's unicode
  /// support.
  static const String _upper =
      r'A-ZÀÁẢÃẠĂÂĐÊÉÈẺẼẸÔƠÙÚỦŨỤƯỲÝỶỸỴ';

  /// Abbreviations whose dot never ends a sentence. Lowercase entries are
  /// matched case-insensitively; initials are handled generically below.
  ///
  /// Single letters (`p`, `q`) and `no` are deliberately absent: they collide
  /// with real Vietnamese words (`tiếp`, `no`), and swallowing a genuine
  /// terminator merges two sentences that a listener expects to be separate.
  ///
  /// `v.v` is absent for the opposite reason: the dot that ends `v.v.` is the
  /// sentence's terminator, so masking it would fuse the sentence with the
  /// next one ("... lê, v.v. Rất ngon."). Known limitation: an `v.v.` in the
  /// *middle* of a sentence therefore reads as a sentence end. That trade is
  /// deliberate — ending a sentence is what `v.v.` usually does.
  static const List<String> _abbreviations = <String>[
    'etc', 'vs', 'cf', 'mr', 'mrs', 'ms', 'dr', 'prof',
    'vol', 'fig', 'tp', 'ks', 'ts', 'gs', 'ths', 'bs', 'gv', 'đh', 'khtn',
  ];

  /// An abbreviation counts only when it stands on its own: `tiếp.` ends a
  /// sentence, it is not the abbreviation `ts.` preceded by letters.
  static final RegExp _abbreviationDot = RegExp(
    '(?<![\\p{L}\\p{N}])(?:${_abbreviations.join('|')})\\.',
    caseSensitive: false,
    unicode: true,
  );

  static final RegExp _urlOrEmail = RegExp(
    r'(?:https?://\S+|www\.\S+|[\w.+-]+@[\w-]+\.[\w.]+)',
    caseSensitive: false,
  );

  /// `3.14`, `1.5` — a dot between digits is a decimal, never a terminator.
  static final RegExp _decimalDot = RegExp(r'(?<=\d)\.(?=\d)');

  /// A lone uppercase letter followed by a dot is an initial: `H. Nguyễn`.
  static final RegExp _initial =
      RegExp('[$_upper]\\.(?=\\s)');

  /// A terminator run, optionally followed by closing quotes/brackets, then
  /// whitespace or end of input.
  ///
  /// The straight apostrophe is written as `\u0027` so the pattern can stay a
  /// raw string while still containing both quote characters.
  static final RegExp _boundary =
      RegExp(r'[.!?…]+["”’\u0027»)\]]*(?=\s+|$)', multiLine: true);

  /// Splits [text] into sentences.
  ///
  /// * paragraph breaks are hard boundaries (a paragraph is never merged with
  ///   the next, even without punctuation);
  /// * each terminator stays attached to the sentence it closes;
  /// * line breaks *inside* a paragraph become single spaces — they are usually
  ///   PDF wrapping, not pauses;
  /// * output never contains an empty or whitespace-only entry.
  List<String> split(String text) {
    if (text.trim().isEmpty) return const <String>[];

    final sentences = <String>[];
    for (final paragraph in text.split(RegExp(r'\n\s*\n+'))) {
      final trimmed = paragraph.trim();
      if (trimmed.isEmpty) continue;
      sentences.addAll(_splitParagraph(trimmed));
    }
    return sentences;
  }

  List<String> _splitParagraph(String paragraph) {
    final masked = _maskDots(paragraph);
    final boundaries = <int>[0];
    for (final match in _boundary.allMatches(masked)) {
      final end = match.end;
      if (end > boundaries.last) boundaries.add(end);
    }

    final out = <String>[];
    for (var i = 0; i < boundaries.length; i++) {
      final start = boundaries[i];
      final end = i + 1 < boundaries.length ? boundaries[i + 1] : masked.length;
      final raw = masked.substring(start, end);
      final sentence = _unmask(raw).replaceAll('\n', ' ').trim();
      if (sentence.isNotEmpty) out.add(sentence);
    }
    return out;
  }

  String _maskDots(String text) {
    // Every callback masks **dots only**. Replacing the whole match instead
    // would delete the letters of `TS.` or the tail of a URL.
    var out = text.replaceAllMapped(
        _urlOrEmail, (m) => _maskInteriorDots(m.group(0)!));
    out = out.replaceAllMapped(_decimalDot, (_) => _mask);
    out = out.replaceAllMapped(
        _abbreviationDot, (m) => _maskAllDots(m.group(0)!));
    out = out.replaceAllMapped(_initial, (m) => _maskAllDots(m.group(0)!));
    return out;
  }

  /// Masks each dot that is followed by a non-space character.
  ///
  /// Inside `https://example.com` every dot is real; a trailing `.` after the
  /// address is the sentence's terminator and has to survive, or the sentence
  /// merges with the next one.
  static String _maskInteriorDots(String token) =>
      token.replaceAllMapped(RegExp(r'\.(?=\S)'), (_) => _mask);

  /// Masks the dots of a match and keeps every other character of it.
  static String _maskAllDots(String token) => token.replaceAll('.', _mask);

  String _unmask(String text) => text.replaceAll(_mask, '.');
}
