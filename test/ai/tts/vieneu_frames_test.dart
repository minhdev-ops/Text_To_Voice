import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:text_to_voice/ai/tts/vieneu_frames.dart';

/// The frame cap is the guard against a short chunk that misses its stop token
/// and keeps talking — a content bug, not a quality nit. Its two rules come from
/// measurements in the reference (a one-syllable chunk stops at 6–9 frames and
/// runs to 12–13 when it fails), so the values are checked rather than "roughly
/// right".
void main() {
  test('counts Vietnamese syllables by vowel groups', () {
    expect(syllableCount('hˈom nˈaj'), 2);
    expect(syllableCount('sˈin tʃˈaː2w'), 2);
    expect(syllableCount(''), 0);
  });

  test('a one-syllable chunk gets the short ceiling, not the linear one', () {
    // 9 phoneme characters would allow 24 + 18 = 42 frames; a single syllable
    // must not be allowed to keep talking that long.
    expect(maxExpectedFrames('hˈom nˈaj'), 13 + 5);
    expect(maxExpectedFrames('hˈom'), 13);
  });

  test('a cue-only chunk is treated as one syllable', () {
    expect(isCueOnly('<|emotion_1|>'), isTrue);
    expect(isCueOnly('hˈom <|emotion_1|>'), isFalse);
    expect(isCueOnly('hˈom'), isFalse);
    expect(maxExpectedFrames('<|emotion_2|>'), 13);
  });

  test('a real sentence is capped well above what it needs', () {
    // The cap must not bite for ordinary text: if it did, sentences would be cut
    // mid-word. The reference's own default (300) has to be the binding limit.
    final golden = jsonDecode(
      File('test/fixtures/vieneu_pipeline_golden.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final phonemes = golden['phonemes'] as String;
    final cap = maxExpectedFrames(phonemes);
    expect(cap, greaterThan(38), reason: 'a 38-frame sentence must fit');
    expect(cap, greaterThan(100));
  });

  test('a very short sentence is not capped below its measured length', () {
    // "Hôm nay trời đẹp quá!" measured 13 frames in the reference run; the cap
    // for a 4-syllable chunk is 13 + 3*5 = 28, comfortably above it.
    expect(maxExpectedFrames('hˈom nˈaj tʃˈəː2j ɗˈɛ6p kwˈaːɜ!'), greaterThanOrEqualTo(28));
  });

  // The synthesis timeout replaced a flat 120 s ceiling that made every sentence
  // producing more than ~8.9 s of audio fail, at the measured 13.5x realtime
  // factor. These tests pin the property that fixed it: the budget grows with the
  // sentence, instead of one constant deciding what is too long.
  group('synthesisTimeout', () {
    test('a longer sentence gets a longer budget', () {
      const short = 'hˈom nˈaj';
      const long = 'tʃˈəː2ŋ maːj baːj tɕaːj laːm viˈec baːo laːn ' // 8 syllables
          'vaː nɤˈɔːk ɗuːɔc tɕɨˈeŋ khǔɤc naː ɡiːaː phẩ́m';
      expect(
        synthesisTimeout(long),
        greaterThan(synthesisTimeout(short)),
      );
    });

    test('a sentence that the old 120 s ceiling killed now fits', () {
      // ~14 syllables ≈ 3.1 s of audio. At the measured 13.5x that costs ~42 s
      // of work; the old constant still allowed it. The point of this test is the
      // ~9 s audio case: 40 syllables ≈ 8.9 s audio ≈ 120 s of work, which the
      // old constant rejected outright.
      final forty = List<String>.filled(40, 'tʃˈəː2ŋ').join(' ');
      expect(syllableCount(forty), 40);
      expect(
        synthesisTimeout(forty),
        greaterThan(const Duration(seconds: 120)),
      );
    });

    test('a title still gets the floor, so a cold model does not kill it', () {
      expect(
        synthesisTimeout('hˈom'),
        greaterThanOrEqualTo(const Duration(minutes: 1)),
      );
    });

    test('the budget is clamped, so a pathological sentence still reports', () {
      // 4000 syllables is not a sentence. It must not buy 6 hours of waiting.
      final absurd = List<String>.filled(4000, 'tʃˈəː2ŋ').join(' ');
      expect(synthesisTimeout(absurd), const Duration(minutes: 8));
    });

    test('a cue-only chunk gets a bounded budget like any other', () {
      expect(
        synthesisTimeout('<|emotion_1|>'),
        greaterThanOrEqualTo(const Duration(minutes: 1)),
      );
    });
  });
}
