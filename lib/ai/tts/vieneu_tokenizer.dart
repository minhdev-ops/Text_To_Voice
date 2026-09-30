import 'dart:convert';
import 'dart:io' show File;

import '../../core/result/result.dart';

/// Byte-level BPE tokenizer for the VieNeu-TTS v3 Turbo checkpoint.
///
/// This is a port of what `tokenizer.json` actually declares, not of "a
/// tokenizer": a GPT-2 style pipeline of
///
///   1. `Split` (regex, behavior `Isolated`) — a word/punctuation splitter,
///   2. `ByteLevel` (`use_regex: false`, `add_prefix_space: false`) — the
///      byte → unicode-char mapping, so *any* byte sequence is representable,
///   3. BPE with the file's 119 merges, ranked by order,
///
/// with no post-processor, because the caller passes
/// `add_special_tokens: false` and builds the prompt itself (`build_rows`).
///
/// The earlier version of this file was wrong in three ways that would each
/// have degraded every sentence: it skipped the byte-level mapping entirely, it
/// pre-tokenized with a simplified regex, and it wrapped the output in BOS/EOS
/// the model never asked for. The golden fixtures in
/// `test/fixtures/vieneu_tokenizer_golden.json` were produced by the official
/// HuggingFace `tokenizers` library against this exact file so that claim is
/// checked rather than asserted.
///
/// **Known limit, deliberate:** the pipeline's `normalizer` is NFC and Dart has
/// no Unicode normalizer. It does not bite here because the tokenizer's only
/// input is the phoneme stream produced by sea-g2p, which normalizes its own
/// output; user text never reaches `encode` directly. A decomposed input would
/// still tokenize (every byte is in the vocabulary) but to different ids — and
/// the tokenizer golden test would catch the day that stops being true.
class VieNeuTokenizer {
  VieNeuTokenizer._({
    required Map<String, int> vocab,
    required Map<String, int> mergeRanks,
    required Map<int, String> reverseVocab,
    required Map<String, int> addedTokens,
    required int unkId,
  })  : _vocab = vocab,
        _mergeRanks = mergeRanks,
        _reverseVocab = reverseVocab,
        _addedTokens = addedTokens,
        _unkId = unkId;

  final Map<String, int> _vocab;

  /// `'a\u0000b'` → merge rank. A map rather than a list because the lookup is
  /// per adjacent pair per merge round.
  final Map<String, int> _mergeRanks;

  final Map<int, String> _reverseVocab;

  /// `<|emotion_2|>` and friends: matched *before* BPE, as HF's added-token
  /// vocabulary does. Without this an inline cue would be spelled out byte by
  /// byte and lose its meaning to the model.
  final Map<String, int> _addedTokens;

  final int _unkId;

  int get vocabSize => _vocab.length;

  /// The `<|unk|>` id, used when a symbol somehow has no entry.
  int get unkId => _unkId;

  int? idFor(String token) => _vocab[token];

  static Future<Result<VieNeuTokenizer>> fromFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return Result<VieNeuTokenizer>.failure(ModelUnavailableFailure(
        message: 'Thiếu tệp từ vựng model (tokenizer.json).',
        modelId: 'vieneu-v3-turbo',
      ));
    }
    try {
      return Result<VieNeuTokenizer>.success(
        VieNeuTokenizer.fromJsonString(await file.readAsString()),
      );
    } on CorruptModelFailure catch (failure) {
      return Result<VieNeuTokenizer>.failure(failure);
    } catch (error) {
      return Result<VieNeuTokenizer>.failure(CorruptModelFailure(
        message: 'Không đọc được tệp từ vựng model.',
        detail: error.toString(),
        cause: error,
      ));
    }
  }

  factory VieNeuTokenizer.fromJsonString(String jsonString) {
    final dynamic decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const CorruptModelFailure(
        message: 'Tệp từ vựng model không đúng định dạng.',
        detail: 'tokenizer.json is not a JSON object',
      );
    }
    final model = decoded['model'];
    if (model is! Map<String, dynamic>) {
      throw const CorruptModelFailure(
        message: 'Tệp từ vựng model thiếu bảng BPE.',
        detail: 'tokenizer.json has no model',
      );
    }

    final rawVocab = model['vocab'];
    if (rawVocab is! Map) {
      throw const CorruptModelFailure(
        message: 'Tệp từ vựng model thiếu vocab.',
        detail: 'tokenizer.json model.vocab missing',
      );
    }
    final vocab = <String, int>{};
    final reverse = <int, String>{};
    rawVocab.forEach((key, value) {
      final id = value is int ? value : (value as num).toInt();
      vocab['$key'] = id;
      reverse[id] = '$key';
    });

    final mergeRanks = <String, int>{};
    final rawMerges = model['merges'];
    if (rawMerges is List) {
      for (var rank = 0; rank < rawMerges.length; rank++) {
        final entry = rawMerges[rank];
        String? left;
        String? right;
        if (entry is List && entry.length >= 2) {
          left = '${entry[0]}';
          right = '${entry[1]}';
        } else if (entry is String) {
          // Older files write merges space-separated on one line.
          final parts = entry.split(' ');
          if (parts.length >= 2) {
            left = parts[0];
            right = parts[1];
          }
        }
        if (left != null && right != null) {
          mergeRanks['$left\u0000$right'] = rank;
        }
      }
    }

    final addedTokens = <String, int>{};
    final rawAdded = decoded['added_tokens'];
    if (rawAdded is List) {
      for (final token in rawAdded) {
        if (token is Map && token['content'] is String && token['id'] is int) {
          addedTokens[token['content'] as String] = token['id'] as int;
        }
      }
    }

    final unkId = vocab['<|unk|>'] ?? 0;
    return VieNeuTokenizer._(
      vocab: vocab,
      mergeRanks: mergeRanks,
      reverseVocab: reverse,
      addedTokens: addedTokens,
      unkId: unkId,
    );
  }

  /// Encodes [text] to ids, **without** special tokens — the prompt builder is
  /// the only place style/prompt tokens are added.
  List<int> encode(String text) {
    if (text.isEmpty) return const <int>[];
    final ids = <int>[];
    var cursor = 0;
    while (cursor < text.length) {
      var matchIndex = -1;
      String? matchToken;
      for (final token in _addedTokens.keys) {
        final index = text.indexOf(token, cursor);
        if (index < 0) continue;
        if (matchIndex < 0 ||
            index < matchIndex ||
            (index == matchIndex && token.length > matchToken!.length)) {
          matchIndex = index;
          matchToken = token;
        }
      }
      if (matchIndex < 0) {
        _encodeSpan(text.substring(cursor), ids);
        break;
      }
      if (matchIndex > cursor) {
        _encodeSpan(text.substring(cursor, matchIndex), ids);
      }
      ids.add(_addedTokens[matchToken!]!);
      cursor = matchIndex + matchToken.length;
    }
    return ids;
  }

  /// Decodes ids back to text. Used by the round-trip test, which is what makes
  /// the byte-level mapping checkable without a running model.
  String decode(List<int> ids) {
    final buffer = <int>[];
    for (final id in ids) {
      final token = _reverseVocab[id];
      if (token == null) continue;
      if (_addedTokens.containsKey(token)) continue;
      for (final char in token.runes) {
        final byte = _byteForUnicodeChar(char);
        if (byte != null) buffer.add(byte);
      }
    }
    return utf8.decode(buffer, allowMalformed: true);
  }

  void _encodeSpan(String span, List<int> ids) {
    if (span.isEmpty) return;
    for (final piece in _splitWithGpt2Pattern(span)) {
      if (piece.isEmpty) continue;
      final symbols = <String>[
        for (final byte in utf8.encode(piece)) _byteToUnicode[byte],
      ];
      for (final symbol in _applyMerges(symbols)) {
        ids.add(_vocab[symbol] ?? _unkId);
      }
    }
  }

  /// The checkpoint's `pre_tokenizer` regex, verbatim except for one
  /// substitution: HF writes the leading alternative as `(?i:'s|'t|'re|'ve|'m|'ll|'d)`,
  /// and Dart's RegExp rejects inline flag groups, so case-insensitivity is
  /// spelled out. Same language, same matches.
  static final RegExp _gpt2Pattern = RegExp(
    r"(?:'[sS]|'[tT]|'[rR][eE]|'[vV][eE]|'[mM]|'[lL][lL]|'[dD])"
    r"|[^\r\n\p{L}\p{N}]?\p{L}+"
    r"|\p{N}"
    r"| ?[^\s\p{L}\p{N}]+[\r\n]*"
    r"|\s*[\r\n]+"
    r"|\s+(?!\S)"
    r"|\s+",
    unicode: true,
  );

  /// `Split` with behavior `Isolated`: each regex match is its own piece and the
  /// gaps between matches are pieces too, so a merge can never straddle a
  /// boundary the tokenizer itself drew.
  static List<String> _splitWithGpt2Pattern(String text) {
    final pieces = <String>[];
    var cursor = 0;
    for (final match in _gpt2Pattern.allMatches(text)) {
      if (match.start > cursor) pieces.add(text.substring(cursor, match.start));
      pieces.add(match[0]!);
      cursor = match.end;
    }
    if (cursor < text.length) pieces.add(text.substring(cursor));
    return pieces;
  }

  List<String> _applyMerges(List<String> symbols) {
    if (symbols.length < 2 || _mergeRanks.isEmpty) return symbols;
    var current = symbols;
    while (true) {
      var bestRank = 1 << 30;
      var bestIndex = -1;
      for (var i = 0; i + 1 < current.length; i++) {
        final rank = _mergeRanks['${current[i]}\u0000${current[i + 1]}'];
        if (rank != null && rank < bestRank) {
          bestRank = rank;
          bestIndex = i;
        }
      }
      if (bestIndex < 0) break;
      current = <String>[
        ...current.sublist(0, bestIndex),
        current[bestIndex] + current[bestIndex + 1],
        ...current.sublist(bestIndex + 2),
      ];
    }
    return current;
  }

  /// The GPT-2 byte ↔ unicode table, derived the way the original does it:
  /// printable ranges keep their own code point, every other byte is mapped into
  /// a private range starting at U+0100.
  static final List<String> _byteToUnicode = _buildByteToUnicode();

  static List<String> _buildByteToUnicode() {
    final byteToChar = List<String>.filled(256, '');
    final used = <int>[
      for (var b = 0x21; b <= 0x7E; b++) b,
      for (var b = 0xA1; b <= 0xAC; b++) b,
      for (var b = 0xAE; b <= 0xFF; b++) b,
    ];
    for (final byte in used) {
      byteToChar[byte] = String.fromCharCode(byte);
    }
    var extra = 0;
    for (var byte = 0; byte < 256; byte++) {
      if (byteToChar[byte].isEmpty) {
        byteToChar[byte] = String.fromCharCode(256 + extra);
        extra++;
      }
    }
    return byteToChar;
  }

  static final Map<int, int> _unicodeCharToByte = {
    for (var byte = 0; byte < 256; byte++) _byteToUnicode[byte].codeUnitAt(0): byte,
  };

  static int? _byteForUnicodeChar(int charCode) => _unicodeCharToByte[charCode];
}

/// Special token ids, read from `config.json` at runtime rather than duplicated
/// here. Kept as a named group only for the ids the prompt builder needs to
/// *identify* (an end-of-speech verdict), not to inject.
class VieNeuSpecialTokens {
  const VieNeuSpecialTokens({
    required this.textPromptStart,
    required this.textPromptEnd,
    required this.speechGenerationStart,
    required this.speechGenerationEnd,
    required this.audioRefSlot,
    required this.audioPad,
    required this.defaultStyle,
  });

  final int textPromptStart;
  final int textPromptEnd;
  final int speechGenerationStart;
  final int speechGenerationEnd;
  final int audioRefSlot;
  final int audioPad;
  final int defaultStyle;
}
