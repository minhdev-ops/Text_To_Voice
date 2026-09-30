import 'package:flutter_test/flutter_test.dart';

import 'package:text_to_voice/core/isolate/isolate_runner.dart';

/// Busy-waits so there is something to actually kill. Short enough that a
/// broken cancel() still finishes the suite.
int _spin(int millis) {
  final until = DateTime.now().add(Duration(milliseconds: millis));
  var acc = 0;
  while (DateTime.now().isBefore(until)) {
    acc = (acc + 1) % 1000;
  }
  return acc;
}

void main() {
  group('runOnBackgroundIsolate', () {
    test('runs the task off the current isolate and returns its value', () async {
      final result = await runOnBackgroundIsolate<int, int>(
        (value) => value * 2,
        21,
        debugLabel: 'unit.double',
      );
      expect(result, 42);
    });

    test('forwards the task error', () async {
      await expectLater(
        runOnBackgroundIsolate<int, int>(
          (value) {
            throw StateError('boom $value');
          },
          1,
          debugLabel: 'unit.throw',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('spawnIsolateTask', () {
    test('completes with the task value', () async {
      final task = spawnIsolateTask<int, String>(
        (value) => 'value=$value',
        7,
        debugLabel: 'unit.label',
      );
      expect(await task.future, 'value=7');
      expect(task.isCancelled, isFalse);
    });

    test('surfaces a failing task as IsolateTaskError with the remote stack',
        () async {
      final task = spawnIsolateTask<int, int>(
        (value) {
          if (value > 0) throw ArgumentError('bad input');
          return value;
        },
        3,
        debugLabel: 'unit.bad',
      );

      await expectLater(task.future, throwsA(isA<IsolateTaskError>()));
      try {
        await task.future;
      } on IsolateTaskError catch (error) {
        expect(error.remoteStackTrace.toString(), isNotEmpty);
        expect(error.message, contains('bad input'));
      }
    });

    test('cancel() kills the work and is distinguishable from a failure',
        () async {
      final task = spawnIsolateTask<int, int>(
        (millis) => _spin(millis),
        3000,
        debugLabel: 'unit.slow',
      );

      // Let the isolate actually start spinning before cancelling.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      task.cancel();

      expect(task.isCancelled, isTrue);
      await expectLater(
        task.future,
        throwsA(isA<IsolateCancelledError>()),
        reason: 'cancellation must never look like a crash to the UI',
      );
    });

    test('cancelling twice is a no-op, not a crash', () async {
      final task = spawnIsolateTask<int, int>(
        (millis) => _spin(millis),
        2000,
        debugLabel: 'unit.double-cancel',
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      task.cancel();
      expect(() => task.cancel(), returnsNormally);
      await expectLater(task.future, throwsA(isA<IsolateCancelledError>()));
    });
  });
}
