import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:text_to_voice/ai/tts/vieneu_tokenizer.dart';

/// The tokenizer is checked against vectors produced by the official
/// HuggingFace `tokenizers` library on the checkpoint's own `tokenizer.json`
/// (`tool/reference/vieneu_reference.py`). A hand-written BPE that merely looks
/// right would silently degrade every sentence, so "looks right" is not the bar.
void main() {
  late VieNeuTokenizer tokenizer;
  late List<Map<String, dynamic>> cases;

  setUpAll(() {
    tokenizer = VieNeuTokenizer.fromJsonString(
      File('test/fixtures/vieneu_tokenizer.json').readAsStringSync(),
    );
    final golden = jsonDecode(
      File('test/fixtures/vieneu_tokenizer_golden.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    cases = (golden['cases'] as List).cast<Map<String, dynamic>>();
  });

  test('reads the checkpoint vocabulary and merges', () {
    expect(tokenizer.vocabSize, 419);
    expect(tokenizer.idFor('<|unk|>'), 43);
    expect(tokenizer.idFor('<|style_0|>'), 16);
    expect(tokenizer.idFor('<|SPEECH_GENERATION_END|>'), 6);
  });

  test('encodes phoneme strings to the same ids as HF tokenizers', () {
    expect(cases, isNotEmpty);
    for (final testCase in cases) {
      final phonemes = testCase['phonemes'] as String;
      final expected = (testCase['ids'] as List).cast<int>();
      expect(
        tokenizer.encode(phonemes),
        expected,
        reason: 'phonemes: $phonemes\n'
            'text: ${testCase['text']}',
      );
    }
  });

  test('does not wrap output in BOS/EOS', () {
    // `add_special_tokens: false` is what the prompt builder relies on: the
    // prompt already carries style + TEXT_PROMPT_START/END, and a third set of
    // markers would be a token sequence the model never saw in training.
    final ids = tokenizer.encode('sˈin');
    expect(ids, isNot(contains(1)));
    expect(ids, isNot(contains(2)));
    expect(ids, isNot(contains(3)));
    expect(ids, isNot(contains(4)));
  });

  test('emotion cues resolve to their added-token id, not spelled-out text', () {
    // Added tokens are matched before BPE, exactly as HF's added vocabulary
    // does — an inline cue is a control token, not letters.
    expect(tokenizer.encode('<|emotion_2|>'), [10]);
    expect(tokenizer.encode('hˈom <|emotion_1|>.'), [
      ...tokenizer.encode('hˈom '),
      9,
      ...tokenizer.encode('.'),
    ]);
  });

  test('round-trips Vietnamese and IPA text through the byte-level mapping', () {
    for (final sample in <String>[
      'sˈin tʃˈaː2w',
      'ɗˈəɪ lˌaː2 bˈaː4n',
      'xin chào Việt Nam',
      't̪ˈiɛɜŋ vˈiɛ6t̪',
    ]) {
      expect(tokenizer.decode(tokenizer.encode(sample)), sample,
          reason: 'round trip failed for $sample');
    }
  });

  test('every byte is representable, so no input is un-encodable', () {
    // 256 single-byte pieces: the property that makes the byte-level mapping
    // worth having. A vocabulary miss here would surface as <|unk|> in the
    // prompt, which the model reads as a real token.
    final ids = tokenizer.encode('ăâêôơưđĐ');
    expect(ids, isNotEmpty);
    expect(ids, isNot(contains(tokenizer.unkId)));
  });
}
