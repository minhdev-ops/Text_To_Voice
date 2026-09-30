import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

/// Sampling for the audio tokens, ported from `onnx_runtime_lite._sample` and
/// `rep_history.py`.
///
/// The quality knobs matter more than they look. With plain greedy decoding the
/// voice loops on held vowels; with an unbounded repetition penalty (the older
/// behaviour) it slowly drifts, because after a few hundred frames a permanent
/// set of "already used" codes covers half of each 1024-code bookbook — including
/// codes that legitimately repeat (silence, a long vowel). The fix in the
/// reference is a **sliding window**: only codes from the last
/// [defaultRepetitionWindow] frames are penalised. That is what is ported here,
/// window semantics included.
class VieNeuSampler {
  VieNeuSampler({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;

  /// ~2.5 s of audio at 12.5 frames/s: long enough to catch a local loop, short
  /// enough that a finished vowel is no longer penalised.
  static const int defaultRepetitionWindow = 64;

  /// Draws one code.
  ///
  /// [temperature] `<= 0` means greedy — the one mode that is deterministic, and
  /// therefore the only one a golden test can pin down.
  int sample(
    Float32List logits, {
    required double temperature,
    required int topK,
    required double topP,
    required double repetitionPenalty,
    int channel = 0,
    RepetitionHistory? history,
  }) {
    final previous = history?[channel];
    final scores = Float32List.fromList(logits);

    if (repetitionPenalty != 1.0 &&
        previous != null &&
        previous.isNotEmpty) {
      // Sign-preserving: dividing a negative logit by the penalty would *lower*
      // it, i.e. reward a repeated token, which is the opposite of the intent.
      for (final code in previous.codes) {
        if (code < 0 || code >= scores.length) continue;
        final value = scores[code];
        scores[code] =
            value < 0 ? value * repetitionPenalty : value / repetitionPenalty;
      }
    }

    if (temperature <= 0) return _argmax(scores);

    final scale = 1.0 / temperature;
    for (var i = 0; i < scores.length; i++) {
      scores[i] *= scale;
    }

    final votes = scores.length;
    final List<int> candidates;
    if (topK > 0 && topK < votes) {
      candidates = _topIndices(scores, topK);
    } else {
      candidates = List<int>.generate(votes, (index) => index);
    }
    // Highest first, matching `np.argsort(cs)[::-1]`.
    candidates.sort((a, b) {
      final byScore = scores[b].compareTo(scores[a]);
      return byScore != 0 ? byScore : a.compareTo(b);
    });

    final probabilities = Float32List(candidates.length);
    var maxValue = double.negativeInfinity;
    for (final index in candidates) {
      if (scores[index] > maxValue) maxValue = scores[index];
    }
    var total = 0.0;
    for (var i = 0; i < candidates.length; i++) {
      final value = math.exp(scores[candidates[i]] - maxValue);
      probabilities[i] = value;
      total += value;
    }
    if (total <= 0) return candidates.first;
    for (var i = 0; i < probabilities.length; i++) {
      probabilities[i] /= total;
    }

    if (topP < 1.0) {
      // Nucleus cut inside the candidate set, computed exactly as the reference
      // does (`cumsum(p) - p < topP`) so the boundary case — where a single
      // candidate already exceeds topP — keeps that one candidate rather than
      // producing an empty distribution.
      var cumulative = 0.0;
      var keep = 0;
      for (var i = 0; i < probabilities.length; i++) {
        if (cumulative < topP) {
          keep++;
          cumulative += probabilities[i];
        } else {
          probabilities[i] = 0.0;
        }
      }
      if (keep == 0) {
        probabilities[0] = 1.0;
      } else {
        var mass = 0.0;
        for (var i = 0; i < keep; i++) {
          mass += probabilities[i];
        }
        if (mass <= 0) {
          probabilities[0] = 1.0;
          for (var i = 1; i < probabilities.length; i++) {
            probabilities[i] = 0.0;
          }
        } else {
          for (var i = 0; i < keep; i++) {
            probabilities[i] /= mass;
          }
        }
      }
    }

    var draw = _random.nextDouble();
    for (var i = 0; i < probabilities.length; i++) {
      draw -= probabilities[i];
      if (draw <= 0) return candidates[i];
    }
    return candidates.last;
  }

  int _argmax(Float32List values) {
    var best = 0;
    var bestValue = values[0];
    // First maximum wins, like `np.argmax` — a tie is not a reason to pick a
    // different token than the reference implementation would.
    for (var i = 1; i < values.length; i++) {
      if (values[i] > bestValue) {
        bestValue = values[i];
        best = i;
      }
    }
    return best;
  }

  static List<int> _topIndices(Float32List values, int count) {
    final ordered = List<int>.generate(values.length, (index) => index)
      ..sort((a, b) => values[b].compareTo(values[a]));
    return ordered.sublist(0, count);
  }
}

/// Per-codebook sliding-window history of generated codes.
///
/// Exposes the same surface the reference gives its sampling code (`iter`, `len`,
/// `isNotEmpty`, `add`) so the penalty rule reads the same on both sides.
class RepetitionHistory {
  RepetitionHistory(this.codebookCount,
      {this.window = VieNeuSampler.defaultRepetitionWindow})
      : channels = List<RepetitionChannel>.generate(
          codebookCount,
          (_) => RepetitionChannel(window),
        );

  final int codebookCount;
  final int window;
  final List<RepetitionChannel> channels;

  RepetitionChannel operator [](int channel) => channels[channel];
}

/// One codebook's window: counts plus FIFO order, so eviction is O(1) and a
/// code that appears twice inside the window survives the first eviction.
class RepetitionChannel {
  RepetitionChannel(this.window);

  final int window;
  final Map<int, int> _counts = <int, int>{};
  final Queue<int> _order = Queue<int>();

  void add(int code) {
    _counts[code] = (_counts[code] ?? 0) + 1;
    if (window <= 0) return;
    _order.addLast(code);
    while (_order.length > window) {
      final evicted = _order.removeFirst();
      final remaining = (_counts[evicted] ?? 1) - 1;
      if (remaining <= 0) {
        _counts.remove(evicted);
      } else {
        _counts[evicted] = remaining;
      }
    }
  }

  /// Codes currently inside the window, at most once each.
  Iterable<int> get codes => _counts.keys;

  int get length => _counts.length;

  bool get isNotEmpty => _counts.isNotEmpty;
}
