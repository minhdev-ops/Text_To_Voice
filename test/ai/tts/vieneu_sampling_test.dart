import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:text_to_voice/ai/tts/vieneu_sampling.dart';

void main() {
  group('greedy decoding', () {
    test('temperature 0 returns the argmax, first maximum wins', () {
      final sampler = VieNeuSampler(random: Random(1));
      expect(
        sampler.sample(
          Float32List.fromList(<double>[1, 5, 5, 2]),
          temperature: 0,
          topK: 0,
          topP: 1,
          repetitionPenalty: 1,
        ),
        1,
      );
    });

    test('is deterministic across repeated calls', () {
      final sampler = VieNeuSampler(random: Random(7));
      final logits = Float32List.fromList(<double>[0.1, -3, 9, 4]);
      final first = sampler.sample(logits,
          temperature: 0, topK: 0, topP: 1, repetitionPenalty: 1);
      for (var i = 0; i < 20; i++) {
        expect(
          sampler.sample(logits,
              temperature: 0, topK: 0, topP: 1, repetitionPenalty: 1),
          first,
        );
      }
    });
  });

  group('repetition penalty', () {
    test('demotes a code that is already in the window', () {
      final history = RepetitionHistory(1);
      history[0].add(1);
      final sampler = VieNeuSampler(random: Random(3));
      // Without the penalty, index 1 (5.0) wins over index 2 (3.0).
      expect(
        sampler.sample(
          Float32List.fromList(<double>[1, 5, 3]),
          temperature: 0,
          topK: 0,
          topP: 1,
          repetitionPenalty: 1,
        ),
        1,
      );
      // Divided by 2 it becomes 2.5, so index 2 wins instead.
      expect(
        sampler.sample(
          Float32List.fromList(<double>[1, 5, 3]),
          temperature: 0,
          topK: 0,
          topP: 1,
          repetitionPenalty: 2,
          history: history,
        ),
        2,
      );
    });

    test('a negative logit is pushed further down, not rewarded', () {
      final history = RepetitionHistory(1);
      history[0].add(1);
      final sampler = VieNeuSampler(random: Random(3));
      // Multiplying by the penalty is what makes a negative logit *less* likely;
      // dividing would have made the repeated code the winner.
      expect(
        sampler.sample(
          Float32List.fromList(<double>[-1, -5]),
          temperature: 0,
          topK: 0,
          topP: 1,
          repetitionPenalty: 2,
          history: history,
        ),
        0,
      );
    });

    test('only the history of the same channel is penalised', () {
      final history = RepetitionHistory(2);
      history[1].add(1); // channel 1, not 0
      final sampler = VieNeuSampler(random: Random(3));
      expect(
        sampler.sample(
          Float32List.fromList(<double>[0, 5]),
          temperature: 0,
          topK: 0,
          topP: 1,
          repetitionPenalty: 2,
          channel: 0,
          history: history,
        ),
        1,
      );
    });
  });

  group('sliding window', () {
    test('evicts codes older than the window', () {
      final channel = RepetitionChannel(2);
      channel.add(10);
      channel.add(11);
      channel.add(12);
      expect(channel.codes.toSet(), <int>{11, 12});
      expect(channel.length, 2);
    });

    test('an eviction of a duplicate keeps the code alive', () {
      final channel = RepetitionChannel(2);
      channel.add(5);
      channel.add(5);
      channel.add(9); // window now holds [5, 9]; the first 5 is evicted
      expect(channel.codes.toSet(), <int>{5, 9});
      channel.add(9); // window [9, 9] → 5 finally leaves
      expect(channel.codes.toSet(), <int>{9});
    });

    test('window 0 means unlimited history', () {
      final channel = RepetitionChannel(0);
      for (var i = 0; i < 100; i++) {
        channel.add(i);
      }
      expect(channel.length, 100);
    });
  });

  group('top-k / top-p', () {
    test('topK 1 always returns the argmax, whatever the seed', () {
      for (var seed = 0; seed < 5; seed++) {
        final sampler = VieNeuSampler(random: Random(seed));
        expect(
          sampler.sample(
            Float32List.fromList(<double>[0.1, 8, 0.2]),
            temperature: 0.8,
            topK: 1,
            topP: 1,
            repetitionPenalty: 1,
          ),
          1,
        );
      }
    });

    test('the same seed gives the same draw, different seeds vary', () {
      final logits = Float32List.fromList(<double>[1, 1, 1, 1, 1, 1, 1, 1]);
      List<int> draw(int seed) {
        final sampler = VieNeuSampler(random: Random(seed));
        return <int>[
          for (var i = 0; i < 20; i++)
            sampler.sample(logits,
                temperature: 1, topK: 0, topP: 1, repetitionPenalty: 1),
        ];
      }

      expect(draw(42), draw(42));
      expect(draw(42), isNot(equals(draw(43))));
    });

    test('topP keeps at least one candidate alive', () {
      final sampler = VieNeuSampler(random: Random(5));
      final code = sampler.sample(
        Float32List.fromList(<double>[0, 0, 0, 0]),
        temperature: 1,
        topK: 0,
        // A nucleus of 0 would otherwise leave an empty distribution.
        topP: 0,
        repetitionPenalty: 1,
      );
      expect(code, inInclusiveRange(0, 3));
    });

    test('sampled codes stay inside the vocabulary', () {
      final sampler = VieNeuSampler(random: Random(11));
      final logits = Float32List.fromList(<double>[3, -1, 0.5]);
      for (var i = 0; i < 50; i++) {
        expect(
          sampler.sample(logits,
              temperature: 0.8, topK: 25, topP: 0.95, repetitionPenalty: 1.2),
          inInclusiveRange(0, 2),
        );
      }
    });
  });
}
