/// Frame budgeting for one synthesis chunk.
///
/// Ported from `vieneu_utils.core_utils` (`max_expected_frames` and
/// `syllable_count`). The autoregressive model decides for itself when to stop
/// via an end-of-speech token, but on a *short* chunk it occasionally misses the
/// stop and keeps talking — the authors measured this on 720 chunks and added a
/// cap derived from the phoneme string. Without it, a one-word title can produce
/// several seconds of invented speech, which is a content-correctness bug, not a
/// quality nit.
///
/// Every constant below matches the reference; they are named and explained
/// rather than inlined, because they are measurements (frame counts at 12.5
/// frames/second) and not round numbers someone liked.
library;

/// Fixed allowance for lead-in and other costs that do not scale with length.
const int _frameCapSlack = 24;

/// Ceiling on frames per phoneme character of an ordinary chunk.
const double _maxFramesPerPhone = 2.0;

/// Ceiling for a chunk of one syllable (~1 s at 12.5 frames/s).
const int _singleWordMaxFrames = 13;

/// Added per extra syllable, for chunks of up to [_syllableCapMaxSyllables].
const int _syllableCapPerExtra = 5;

/// Above this many syllables the phoneme-length formula is the only rule, since
/// short-chunk hallucination is not what a long sentence does.
const int _syllableCapMaxSyllables = 4;

/// A "syllable" longer than this (phonemes per syllable) is really several words
/// glued together by normalization, and must not earn the short-chunk ceiling.
const int _singleWordMaxPhones = 24;

/// The codec emits 3840 samples per frame at 48 kHz, i.e. one frame every 80 ms.
const double _framesPerSecond = 12.5;

/// Vietnamese reading pace, in syllables per second of finished audio.
///
/// Measured against the reference: an ordinary sentence lands near 4.5, so this
/// is a typical pace with a little headroom, not a ceiling.
const double _syllablesPerSecond = 4.5;

/// How many times longer than the audio it produces, a synthesis may take.
///
/// The reference figure is the 13.5x measured on a Galaxy A75 (Exynos 2200,
/// CPU-only) — see `flutter_onnx_session_factory.dart`. The margin over it is
/// deliberate: a budget that is too short **drops a sentence that would have
/// succeeded**, which the user sees as a silent gap in the reading; a budget that
/// is too long only delays a request that was genuinely stuck, and that one the
/// user can retry. Erring towards the second failure is the right way round.
const double _slowerThanRealtime = 25.0;

/// Fixed allowance for prefill, the codec pass and writing the WAV — work that
/// happens once per sentence and does not scale with its length.
const Duration _fixedOverhead = Duration(seconds: 30);

/// Floor, so a one-word title still survives a cold model and a slow disk.
const Duration _minBudget = Duration(minutes: 1);

/// Ceiling. Beyond this the sentence is pathological rather than slow, and a
/// wait this long is worse than a reported failure.
const Duration _maxBudget = Duration(minutes: 8);

/// How long the host should let one synthesis run before giving up on it.
///
/// **A fixed timeout is wrong here, and it was a real bug.** At 13.5x realtime a
/// flat 120 s ceiling ruled out every sentence producing more than ~8.9 s of
/// audio — so a long clause failed *every* time, with a message about a timeout
/// rather than about the sentence being long. Nothing about the model's cost is
/// constant, so nothing about the ceiling should be either.
///
/// Sized from the finished audio the sentence is expected to produce, converted
/// through the measured realtime factor and padded for fixed work. [phonemes]
/// must be the phoneme string, not the original text: syllables are what the
/// model turns into frames, and counting them is what makes the budget a fact
/// about this sentence rather than a guess.
Duration synthesisTimeout(
  String phonemes, {
  double slowerThanRealtime = _slowerThanRealtime,
}) {
  // A cue-only chunk ("<|emotion_1|>") has no syllable to count; the frame cap
  // is what bounds it, so derive the expectation from that instead.
  final syllables = isCueOnly(phonemes)
      ? (maxExpectedFrames(phonemes) / _framesPerSecond * _syllablesPerSecond)
      : syllableCount(phonemes).toDouble();
  final audioSeconds = syllables < 1 ? 1.0 : syllables / _syllablesPerSecond;
  final budget = Duration(
    milliseconds:
        (audioSeconds * slowerThanRealtime * 1000).round() +
            _fixedOverhead.inMilliseconds,
  );
  if (budget < _minBudget) return _minBudget;
  if (budget > _maxBudget) return _maxBudget;
  return budget;
}

/// Strips markup the model does not speak.
final RegExp _frameMarkup = RegExp(r'<\|emotion_\d+\|>|</?en>');

/// Any letter at all — distinguishes a cue-only chunk from a spoken one.
final RegExp _hasLetter = RegExp(r'\p{L}', unicode: true);

/// IPA symbols that count as vowels for syllable estimation.
///
/// Vietnamese: one syllable is one word, so the count is close to the word
/// count. English words in `<en>` tags can have several, so they are counted by
/// vowel groups. The four r-coloured/reduced vowels are included because
/// leaving them out erased a whole syllable from the count for English words.
const String _ipaVowels = 'aeiouyæɐɑɒɔəɘɛɜɤɯɵøœʉʊʌɪɨɚɝᵻᵿ';

/// `true` when the chunk is only a non-verbal cue — a laugh, a sigh, a throat
/// clear — with no spoken syllable in it.
bool isCueOnly(String phonemes) {
  if (!phonemes.contains('<|emotion_')) return false;
  return !_hasLetter.hasMatch(phonemes.replaceAll(_frameMarkup, ''));
}

/// Estimated syllable count of a phoneme string.
int syllableCount(String phonemes) {
  final stripped = phonemes.replaceAll(_frameMarkup, '');
  var total = 0;
  for (final token in stripped.split(RegExp(r'\s+'))) {
    if (token.isEmpty) continue;
    var groups = 0;
    var inVowel = false;
    // A vowel group starts only after a real consonant, so vowel symbols used
    // as Vietnamese tone marks do not open a new syllable.
    var consonantSeen = true;
    for (final rune in token.runes) {
      final char = String.fromCharCode(rune);
      if (_ipaVowels.contains(char)) {
        if (!inVowel && consonantSeen) groups++;
        inVowel = true;
        consonantSeen = false;
      } else if (char == 'ː' || char == 'ˈ' || char == 'ˌ' || _isDigit(rune)) {
        // Length marks, stress marks and tone digits do not split a group.
      } else {
        inVowel = false;
        consonantSeen = true;
      }
    }
    if (groups > 0) total += groups;
  }
  return total;
}

/// Frames this chunk may generate at most.
int maxExpectedFrames(String phonemes) {
  final stripped = phonemes.replaceAll(_frameMarkup, '');
  final effectiveLength = stripped.length;
  var cap = _frameCapSlack + (_maxFramesPerPhone * effectiveLength).ceil();

  if (isCueOnly(phonemes)) {
    // A standalone cue is not a word: measured laughs/sighs run 5–12 frames, and
    // a failed stop jumps to 19-60. Treat it like a one-syllable chunk.
    final single = _singleWordMaxFrames;
    return cap < single ? cap : single;
  }

  if (!phonemes.contains('<|emotion_')) {
    final syllables = syllableCount(phonemes);
    final effective = syllables < 1 ? 1 : syllables;
    if (effective <= _syllableCapMaxSyllables &&
        effectiveLength <= _singleWordMaxPhones * effective) {
      final shortCap = _singleWordMaxFrames + _syllableCapPerExtra * (effective - 1);
      if (shortCap < cap) cap = shortCap;
    }
  }
  return cap;
}

bool _isDigit(int rune) => rune >= 0x30 && rune <= 0x39;
