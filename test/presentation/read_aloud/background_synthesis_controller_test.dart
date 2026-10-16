import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:text_to_voice/core/platform/synthesis_platform.dart';
import 'package:text_to_voice/domain/speech/background_synthesis_runner.dart';
import 'package:text_to_voice/domain/speech/synthesis_cache.dart';
import 'package:text_to_voice/presentation/read_aloud/read_aloud_providers.dart';

import '../../support/fake_tts_engine.dart';

/// Records what the controller asked the Android service to do, and lets the
/// test press the notification's Stop button.
class _FakePlatform extends SynthesisPlatform {
  final List<String> calls = <String>[];
  final List<(int, int)> progressCalls = <(int, int)>[];

  void Function()? stopListener;

  /// Presses Stop after this many progress updates, making the stop test
  /// deterministic instead of racing a fake engine that finishes instantly.
  int? stopAfterProgressCalls;

  @override
  set onStopRequested(void Function()? listener) {
    stopListener = listener;
  }

  @override
  void ensureStopListener() {
    // The base implementation touches the real MethodChannel, which asserts
    // without an engine binding; this fake owns its own stop plumbing.
  }

  /// Kept apart from [calls] on purpose: the notification-permission request is
  /// not part of the service's start/progress/finish conversation, and folding
  /// it in would have changed what every existing ordering assertion means.
  final List<String> permissionCalls = <String>[];

  @override
  Future<bool> requestNotifications() async {
    permissionCalls.add('requestNotifications');
    return true;
  }

  @override
  Future<bool> start({required int done, required int total}) async {
    calls.add('start');
    return true;
  }

  @override
  Future<bool> progress({required int done, required int total}) async {
    progressCalls.add((done, total));
    if (stopAfterProgressCalls != null &&
        progressCalls.length >= stopAfterProgressCalls!) {
      pressStop();
    }
    return true;
  }

  @override
  Future<bool> finished() async {
    calls.add('finished');
    return true;
  }

  @override
  Future<bool> stop() async {
    calls.add('stop');
    return true;
  }

  /// Simulates the user tapping "Dừng" on the notification.
  void pressStop() => stopListener?.call();
}

void main() {
  group('BackgroundSynthesisController', () {
    late FakeTtsEngine engine;
    late InMemorySynthesisCache cache;
    late _FakePlatform platform;

    ProviderContainer makeContainer() => ProviderContainer(
          overrides: [
            backgroundSynthesisRunnerProvider.overrideWithValue(
              BackgroundSynthesisRunner(engine: engine, cache: cache),
            ),
            synthesisPlatformProvider.overrideWithValue(platform),
          ],
        );

    setUp(() {
      engine = FakeTtsEngine();
      cache = InMemorySynthesisCache();
      platform = _FakePlatform();
    });

    /// Lets the controller's async stream be pumped by the test binding.
    Future<void> settle(ProviderContainer container) =>
        container.read(backgroundSynthesisProvider.notifier).start(
              documentId: 'doc-1',
              rawText: 'Câu một. Câu hai. Câu ba.',
            );

    test('a clean run finishes and tells the service to stop', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      await settle(container);
      await pumpEventQueue();

      final state = container.read(backgroundSynthesisProvider);
      expect(state.running, isFalse);
      expect(state.progress.completed, 3);
      expect(state.progress.failed, 0);
      expect(platform.calls, contains('start'));
      expect(platform.calls.last, 'finished');
    });

    test('the notification is started before any sentence is made', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      await settle(container);
      await pumpEventQueue();

      // Order matters: `start` must precede any `progress`, or the first update
      // would arrive with no notification to repaint.
      expect(platform.calls.first, 'start');
    });

    test('progress reaches the notification with real counts', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      await settle(container);
      await pumpEventQueue();

      expect(platform.progressCalls, isNotEmpty);
      final last = platform.progressCalls.last;
      expect(last.$1, 3);
      expect(last.$2, 3);
    });

    test('the notification is not repainted for progress it cannot show',
        () async {
      // 200 sentences at one percent each: a notification redraw per sentence
      // would be 200 system calls for a bar that moves 200 times by 1%.
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(backgroundSynthesisProvider.notifier).start(
            documentId: 'doc-1',
            rawText: List<String>.filled(200, 'Câu.').join(' '),
          );
      await pumpEventQueue();

      // The opening 0%, one call per whole percent (100), and the final update.
      expect(platform.progressCalls.length, lessThanOrEqualTo(102),
          reason: 'one call per whole percent, not one per sentence');
      expect(platform.progressCalls.length, lessThan(200));
    });

    test('the notification permission is requested for the run', () async {
      // On Android 13+ the foreground service's notification — the only place
      // the reader can watch or stop a long run — stays hidden until this is
      // asked for, so a run must never start without asking.
      final container = makeContainer();
      addTearDown(container.dispose);

      await settle(container);
      await pumpEventQueue();

      expect(platform.permissionCalls, isNotEmpty);
    });

    test('a second run is refused while one is going', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      final controller = container.read(backgroundSynthesisProvider.notifier);
      final first = controller.start(
        documentId: 'doc-1',
        rawText: List<String>.filled(60, 'Câu.').join(' '),
      );
      // Requested before the first run could possibly finish.
      final second = await controller.start(
        documentId: 'doc-2',
        rawText: 'Câu khác.',
      );
      expect(second, isFalse);
      await first;
      await pumpEventQueue();

      expect(container.read(backgroundSynthesisProvider).documentId, 'doc-1');
    });

    test('the notification Stop button stops the run but keeps the audio',
        () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      platform.stopAfterProgressCalls = 3;
      await container.read(backgroundSynthesisProvider.notifier).start(
            documentId: 'doc-1',
            rawText: List<String>.filled(200, 'Câu.').join(' '),
          );
      await pumpEventQueue();

      final state = container.read(backgroundSynthesisProvider);
      expect(state.running, isFalse);
      expect(state.cancelled, isTrue);
      expect(cache.length, greaterThan(0),
          reason: 'audio made before the stop must be kept');
      expect(platform.calls, contains('finished'));
    });

    test('a stop before any progress is still reported as a clean finish',
        () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(backgroundSynthesisProvider.notifier).start(
            documentId: 'doc-1',
            rawText: 'Câu một.',
          );
      container.read(backgroundSynthesisProvider.notifier).stop();
      await pumpEventQueue();

      final state = container.read(backgroundSynthesisProvider);
      expect(state.running, isFalse);
      expect(platform.calls, contains('finished'));
    });

    test('failed sentences are reported rather than swallowed', () async {
      engine.failingTexts.add('Câu hai.');
      final container = makeContainer();
      addTearDown(container.dispose);

      await settle(container);
      await pumpEventQueue();

      final state = container.read(backgroundSynthesisProvider);
      expect(state.message, isNotNull);
      expect(state.message, contains('1'));
    });

    test('a run with nothing left to do still finishes cleanly', () async {
      // Everything is already cached, which is what a resumed run looks like.
      await BackgroundSynthesisRunner(engine: engine, cache: cache)
          .generate('Câu một.')
          .drain<void>();
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(backgroundSynthesisProvider.notifier).start(
            documentId: 'doc-1',
            rawText: 'Câu một.',
          );
      await pumpEventQueue();

      final state = container.read(backgroundSynthesisProvider);
      expect(state.running, isFalse);
      expect(state.message, isNull);
    });
  });
}