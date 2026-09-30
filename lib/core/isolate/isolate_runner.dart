import 'dart:async' show Completer, unawaited;
import 'dart:isolate' show Isolate, ReceivePort, SendPort;

import '../logging/app_log.dart';

/// CPU-bound work off the UI thread (NFR-03).
///
/// Everything expensive in this product — parsing, OCR, synthesis, image
/// enhancement — runs through here so the frame budget stays with the UI.
///
/// Verified on this SDK before this file was written: closures *and* their
/// captures are sendable between isolates in the same group, so callers do not
/// need top-level task functions.

/// Fire-and-await, no cancellation — the `compute` equivalent.
///
/// [R] must not be `void`; return a value or use [spawnIsolateTask].
Future<R> runOnBackgroundIsolate<T, R>(
  R Function(T) task,
  T input, {
  String debugLabel = 'vietdoc.compute',
}) =>
    Isolate.run<R>(() => task(input), debugName: debugLabel);

/// Background work the caller keeps a handle to.
///
/// [cancel] kills the isolate instead of merely discarding its result: OCR or
/// synthesis on a large page can run for seconds, and leaving it running after
/// the user backed out burns battery and memory the rest of the app needs.
class IsolateTask<R> {
  IsolateTask._();

  late final Future<R> _future;
  Completer<R>? _completer;
  ReceivePort? _port;
  Isolate? _isolate;
  bool _settled = false;
  bool _cancelled = false;

  Future<R> get future => _future;
  bool get isCancelled => _cancelled;

  /// Terminates the isolate. The pending [future] completes with an
  /// [IsolateCancelledError].
  ///
  /// Cancellation is not an unexpected failure, so it is deliberately
  /// distinguishable — callers map it to `CancelledFailure` and must not show
  /// an error banner for it.
  void cancel() {
    if (_cancelled || _settled) return;
    _cancelled = true;
    // Settle *before* closing the port: `ReceivePort.close()` runs the
    // listener's `onDone`, and that path must not win the race and report
    // "ended without a result" instead of a cancellation.
    _settle(() => _completer!.completeError(
        IsolateCancelledError('Tác vụ "$_label" đã bị hủy.')));
    _isolate?.kill(priority: Isolate.immediate);
    _port?.close();
  }

  String _label = '';

  // -- lifecycle -----------------------------------------------------------

  void _start<T>(R Function(T) task, T input, String debugLabel) {
    _label = debugLabel;
    final completer = Completer<R>();
    _completer = completer;
    _future = completer.future;

    final port = ReceivePort();
    _port = port;

    port.listen(
      (Object? message) {
        if (_settled) return;
        if (message is _RemoteError) {
          _settle(() => completer.completeError(IsolateTaskError(
              message.message, StackTrace.fromString(message.stack))));
        } else {
          _settle(() => completer.complete(message as R));
        }
        port.close();
      },
      onError: (Object error, StackTrace stack) {
        if (_settled) return;
        _settle(() => completer.completeError(
            IsolateTaskError(error.toString(), stack)));
        port.close();
      },
      onDone: () {
        // The isolate exited without answering: it was killed or died.
        if (_settled) return;
        _settle(() => completer.completeError(IsolateTaskError(
            'Tác vụ "$debugLabel" kết thúc mà không trả kết quả.',
            StackTrace.empty)));
      },
    );

    unawaited(_spawn(
      port,
      _IsolateMessage(port.sendPort, _wrap(task), input, debugLabel),
      completer,
      debugLabel,
    ));
  }

  Future<void> _spawn(
    ReceivePort port,
    _IsolateMessage message,
    Completer<R> completer,
    String debugLabel,
  ) async {
    try {
      final spawned = await Isolate.spawn<_IsolateMessage>(
        _isolateEntry,
        message,
        debugName: debugLabel,
      );
      _isolate = spawned;
      // cancel() may have raced ahead of the spawn completing.
      if (_cancelled) spawned.kill(priority: Isolate.immediate);
    } catch (error, stack) {
      if (_settled) return;
      _settle(() => completer.completeError(
          IsolateTaskError('Không khởi tạo được isolate: $error', stack)));
      port.close();
    }
  }

  void _settle(void Function() settle) {
    if (_settled) return;
    _settled = true;
    settle();
  }
}

/// Starts [task] on a background isolate and returns a cancellable handle.
IsolateTask<R> spawnIsolateTask<T, R>(
  R Function(T) task,
  T input, {
  String debugLabel = 'vietdoc.isolate',
}) {
  final created = IsolateTask<R>._();
  created._start<T>(task, input, debugLabel);
  AppLog.debug('isolate.spawn', data: {'label': debugLabel});
  return created;
}

/// Thrown into the pending future when [IsolateTask.cancel] runs.
class IsolateCancelledError extends Error {
  IsolateCancelledError(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Thrown when the background task itself fails. The stack is the *remote*
/// stack from the spawned isolate, which is what makes the failure debuggable.
class IsolateTaskError extends Error {
  IsolateTaskError(this.message, this.remoteStackTrace);
  final String message;
  final StackTrace remoteStackTrace;

  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------
// Internals
// ---------------------------------------------------------------------------

typedef _WrappedTask = Object? Function(Object?);

class _IsolateMessage {
  const _IsolateMessage(this.reply, this.task, this.input, this.label);

  final SendPort reply;
  final _WrappedTask task;
  final Object? input;
  final String label;
}

class _RemoteError {
  const _RemoteError(this.message, this.stack);
  final String message;
  final String stack;
}

/// A *function declaration* (not a variable assignment) so the runtime type
/// is exactly `_WrappedTask` — which is what the receiving isolate casts to.
_WrappedTask _wrap<T>(Object? Function(T) task) {
  Object? wrapper(Object? value) => task(value as T);
  return wrapper;
}

@pragma('vm:entry-point')
void _isolateEntry(_IsolateMessage message) {
  try {
    final result = message.task(message.input);
    message.reply.send(result);
  } catch (error, stackTrace) {
    message.reply.send(_RemoteError(error.toString(), stackTrace.toString()));
  }
}

