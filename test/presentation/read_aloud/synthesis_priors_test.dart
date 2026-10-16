import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:text_to_voice/presentation/read_aloud/read_aloud_providers.dart';

/// The device's slowest sentence synthesis, banked so the *first* wait of the
/// next read is not a bare "Đang xử lý…".
void main() {
  group('SynthesisPriors', () {
    test('a fresh install has no prior, and says nothing rather than guessing',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(synthesisPriorsProvider), isNull);
    });

    test('the first measurement becomes the prior', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final priors = container.read(synthesisPriorsProvider.notifier);

      await priors.record(26000);

      expect(container.read(synthesisPriorsProvider), 26000);
    });

    test('a slower sentence raises the prior', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final priors = container.read(synthesisPriorsProvider.notifier);

      await priors.record(26000);
      await priors.record(31000);

      expect(container.read(synthesisPriorsProvider), 31000);
    });

    test('a faster sentence does not lower it', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final priors = container.read(synthesisPriorsProvider.notifier);

      await priors.record(31000);
      await priors.record(4000);

      // Slowest, not latest or average: the number that decides whether someone
      // thinks the app is stuck is the longest wait.
      expect(container.read(synthesisPriorsProvider), 31000);
    });

    test('a nonsense measurement is ignored', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final priors = container.read(synthesisPriorsProvider.notifier);

      await priors.record(0);
      expect(container.read(synthesisPriorsProvider), isNull);

      await priors.record(-5);
      expect(container.read(synthesisPriorsProvider), isNull);
    });
  });
}
