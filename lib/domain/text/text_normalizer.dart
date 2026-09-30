/// Step 1 of the FR-09 pipeline: **Text Normalization**.
///
/// Turns what a human typed into something a speech synthesizer can read,
/// without changing what the text *says*. Pure and synchronous so it can be
/// unit-tested exhaustively — the pipeline is
/// normalize → split → synthesize, and an error here would be audible rather
/// than visible.
///
/// What it deliberately does **not** do: reword, re-punctuate or delete
/// content. The reader still shows the original text; normalization only ever
/// feeds the audio path.
class TextNormalizer {
  const TextNormalizer();

  /// Normalizes [raw] for speech.
  String normalize(String raw) {
    if (raw.isEmpty) return '';

    var text = _normalizeLineEndings(raw);
    text = _collapseWhitespace(text);
    text = _expandPercentAndCurrency(text);
    text = _expandDotGroupedThousands(text);
    text = _expandNumbers(text);
    return text.trim();
  }

  // -------------------------------------------------------------------------

  static String _normalizeLineEndings(String text) =>
      text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').replaceAll('\t', ' ');

  /// Collapses runs of horizontal whitespace and trims each line while keeping
  /// **paragraph** breaks (two or more newlines): a paragraph break is a pause
  /// the reader should hear, so it survives.
  static String _collapseWhitespace(String text) {
    final paragraphs = text.split(RegExp(r'\n\s*\n+'));
    return paragraphs
        .map((p) => p.split('\n').map((l) => l.trim()).join('\n'))
        .join('\n\n')
        .replaceAll(RegExp(r'[ ]{2,}'), ' ')
        .trim();
  }

  /// `%` → `phần trăm`, `₫`/`VND` → `đồng`.
  ///
  /// Runs before number expansion so `50%` becomes `50 phần trăm` and its
  /// digits are then read out.
  static String _expandPercentAndCurrency(String text) => text
      .replaceAll(RegExp(r'(?<=\d)\s*%'), ' phần trăm')
      .replaceAll('₫', ' đồng')
      .replaceAll(RegExp(r'(?<=\d)\s*VND', caseSensitive: false), ' đồng');

  // -- numbers --------------------------------------------------------------

  static const List<String> _units = <String>[
    'không', 'một', 'hai', 'ba', 'bốn', 'năm', 'sáu', 'bảy', 'tám', 'chín',
  ];

  /// `1.234.567` is grouped thousands and must be resolved *before* the
  /// decimal pass, otherwise the leading digits are consumed separately.
  ///
  /// The lookarounds stop a malformed `1234.567` from being stitched into a
  /// nonsense integer.
  static final RegExp _dotGroupedThousands =
      RegExp(r'(?<!\d)\d{1,3}(?:\.\d{3})+(?!\d)');

  /// Anything left: an integer, or an integer with a decimal part.
  static final RegExp _remainingNumber = RegExp(r'\d+(?:[.,]\d+)?');

  static String _expandDotGroupedThousands(String text) =>
      text.replaceAllMapped(_dotGroupedThousands,
          (m) => m.group(0)!.replaceAll('.', ''));

  /// Reads digit runs out loud in Vietnamese.
  ///
  /// Convention (SRS FR-09): after grouped thousands are resolved, `.` and `,`
  /// are both read as the Vietnamese decimal separator (`phẩy`) followed by
  /// digits one at a time.
  ///
  /// **Known limitation, deliberate:** identifiers containing digits
  /// (`COVID-19`, `iPhone15`, phone numbers) are read as ordinary numbers.
  /// Suppressing that needs a domain lexicon, and misreading a phone number
  /// beats leaving digits unpronounced for a screen-reader user.
  String _expandNumbers(String text) {
    return text.replaceAllMapped(_remainingNumber, (match) {
      final token = match.group(0)!;

      // Longer than any integer Dart can hold: read it digit by digit rather
      // than throwing.
      final digits = token.replaceAll(RegExp(r'[.,]'), '');
      if (digits.length > 15) {
        return digits.split('').map((d) => _units[int.parse(d)]).join(' ');
      }

      final separatorIndex = _firstIndexWhere(token, (c) => c == '.' || c == ',');
      if (separatorIndex < 0) return _readInteger(int.parse(token));

      final head = token.substring(0, separatorIndex);
      final tail = token.substring(separatorIndex + 1);
      if (head.isEmpty) return token;

      final words = <String>[_readInteger(int.parse(head))];
      if (tail.isNotEmpty) {
        words.add('phẩy');
        words.addAll(tail.split('').map((d) => _units[int.parse(d)]));
      }
      return words.join(' ');
    });
  }

  static int _firstIndexWhere(String s, bool Function(String ch) test) {
    for (var i = 0; i < s.length; i++) {
      if (test(s[i])) return i;
    }
    return -1;
  }

  /// Reads a non-negative integer in Vietnamese: `tỷ` / `triệu` / `nghìn`
  /// groups with the `lẻ`, `lăm` and `mốt` rules inside each group.
  static String _readInteger(int value) {
    if (value == 0) return 'không';
    if (value < 0) return 'âm ${_readInteger(-value)}';

    final groups = <(int, String)>[
      (value ~/ 1000000000, 'tỷ'),
      ((value % 1000000000) ~/ 1000000, 'triệu'),
      ((value % 1000000) ~/ 1000, 'nghìn'),
    ];

    final parts = <String>[];
    var sawHigherGroup = false;

    for (final (amount, unit) in groups) {
      if (amount <= 0) continue;
      parts.add('${_readBelowThousand(amount, padZero: sawHigherGroup)} $unit');
      sawHigherGroup = true;
    }

    final tail = value % 1000;
    if (tail > 0 || parts.isEmpty) {
      final piece = _readBelowThousand(tail, padZero: sawHigherGroup);
      if (piece.isNotEmpty) parts.add(piece);
    }
    return parts.join(' ');
  }

  /// Reads 0..999. [padZero] fills in an empty hundreds place when the group
  /// follows a higher one, so the group is never silently dropped:
  ///
  /// * a tens/units pair keeps the place named — `2026` is
  ///   "hai nghìn không trăm hai mươi sáu";
  /// * a bare unit shortens to `lẻ` — `1.005` is "một nghìn lẻ năm".
  static String _readBelowThousand(int n, {bool padZero = false}) {
    if (n <= 0) return '';

    final hundreds = n ~/ 100;
    final rest = n % 100;
    final parts = <String>[];

    if (hundreds > 0) {
      parts.add('${_units[hundreds]} trăm');
    } else if (padZero && rest >= 10) {
      parts.add('không trăm');
    } else if (padZero && rest > 0) {
      parts.add('lẻ');
    }

    if (rest > 0) {
      if (rest < 10) {
        parts.add(hundreds > 0 ? 'lẻ ${_units[rest]}' : _units[rest]);
      } else if (rest < 20) {
        parts.add(rest == 10 ? 'mười' : 'mười ${_tail(rest - 10)}');
      } else {
        final unit = rest % 10;
        parts.add('${_units[rest ~/ 10]} mươi');
        if (unit == 1) {
          parts.add('mốt');
        } else if (unit > 0) {
          parts.add(_tail(unit));
        }
      }
    }
    return parts.join(' ');
  }

  /// `5 → lăm` after a ten; every other digit keeps its plain form.
  static String _tail(int digit) => digit == 5 ? 'lăm' : _units[digit];
}
