import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:text_to_voice/domain/speech/sentence_synthesis_queue.dart';
import 'package:text_to_voice/domain/speech/synthesis_cache.dart';
import 'package:text_to_voice/presentation/read_aloud/read_aloud_providers.dart';

import '../../support/fake_audio_output.dart';
import '../../support/fake_tts_engine.dart';

/// The controller binds to `readAloudSessionProvider` inside `build`, and that
/// chain rebuilds for reasons the screen does not control: the documents
/// directory resolving, the model audit finishing, an engine swap after an
/// install (FR-20 → FR-09 handoff). The second `build` on the same Notifier
/// must re-bind instead of throwing `LateInitializationError`.
void main() {
  late FakeTtsEngine engine;
  late FakeAudioOutput output;
  late SentenceSynthesisQueue queue;

  setUp(() {
    engine = FakeTtsEngine(millisecondsPerCharacter: 20);
    output = FakeAudioOutput();
    queue = SentenceSynthesisQueue(
      engine: engine,
      cache: InMemorySynthesisCache(),
      lookAhead: 1,
    );
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        ttsEngineProvider.overrideWithValue(engine),
        sentenceQueueProvider.overrideWithValue(queue),
        audioOutputProvider.overrideWithValue(output),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('survives a rebuild of the session provider it watches', () {
    final container = createContainer();

    container.read(readAloudControllerProvider);

    // Same trigger as a model install completing or the async directories
    // resolving: the session provider recomputes, so the controller's build
    // runs a second time on the same Notifier instance.
    container.invalidate(readAloudSessionProvider);
    final afterRebuild = container.read(readAloudControllerProvider);

    expect(afterRebuild, isNotNull);
  });

  test('intent methods still reach the rebound session after a rebuild', () async {
    final container = createContainer();

    final controller = container.read(readAloudControllerProvider.notifier);
    container.invalidate(readAloudSessionProvider);
    container.read(readAloudControllerProvider);

    await controller.read('Một câu kiểm tra.');
    expect(engine.synthesizedTexts, contains('Một câu kiểm tra.'));
  });
}
