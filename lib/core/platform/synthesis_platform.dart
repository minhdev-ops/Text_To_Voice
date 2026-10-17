import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../logging/app_log.dart';

/// Dart's side of `SynthesisService.kt`.
///
/// Every method is a no-op that reports failure off Android rather than throwing.
/// The service is an Android concept; the desktop gate (`flutter test -d linux`)
/// and the unit tests both run without it, and a test that had to care about the
/// host platform would be testing the host, not the code.
///
/// Kept free of Riverpod on purpose: this is a thin platform seam, and the state
/// that decides *when* to call it belongs to a controller.
class SynthesisPlatform {
  SynthesisPlatform({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'text_to_voice/synthesis';

  final MethodChannel _channel;

  void Function()? _stopListener;
  bool _stopListenerInstalled = false;

  /// Raised when the notification's Stop button is tapped.
  ///
  /// Set before [start]: the notification can be tapped at any time, and a
  /// listener registered afterwards would miss the one tap that matters most.
  set onStopRequested(void Function()? listener) {
    _stopListener = listener;
    _stopListenerInstalled = false;
  }

  /// Asks for the notification permission the progress notification needs.
  ///
  /// Called before [start] on Android 13+: the service runs either way, but its
  /// notification — the only way the reader can see or stop a long run — stays
  /// hidden until the user allows it. The answer is informational; a refusal
  /// never blocks the work.
  Future<bool> requestNotifications() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      await _channel.invokeMethod<void>('requestNotifications', null);
      // The dialog is asynchronous, so the honest answer at this moment is "the
      // request was made". What the user chose arrives through the permission
      // state the OS reports at the next start.
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error, stack) {
      AppLog.error('synthesis.notifications.failed',
          error: error, stackTrace: stack);
      return false;
    }
  }

  /// Promotes the process to foreground with a progress notification.
  Future<bool> start({required int done, required int total}) =>
      _invoke('start', <String, Object?>{'done': done, 'total': total});

  /// Repaints the notification's progress.
  Future<bool> progress({required int done, required int total}) =>
      _invoke('progress', <String, Object?>{'done': done, 'total': total});

  /// Tears the notification and wake lock down when the run ends.
  Future<bool> finished() => _invoke('finished', null);

  /// Asks the service to stop. The Dart run is ended by [onStopRequested], not
  /// here, so the audio already produced is kept either way.
  Future<bool> stop() => _invoke('stop', null);

  Future<bool> _invoke(String method, Map<String, Object?>? arguments) async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      await _channel.invokeMethod<void>(method, arguments);
      return true;
    } on MissingPluginException {
      // An Android build without the service registered: generation still runs,
      // it just will not survive leaving the app.
      AppLog.warning('synthesis.platform.missing', data: <String, Object?>{
        'method': method,
      });
      return false;
    } on PlatformException catch (error, stack) {
      AppLog.error('synthesis.platform.failed',
          error: error, stackTrace: stack, data: <String, Object?>{
        'method': method,
        'code': error.code,
      });
      return false;
    }
  }

  /// Wires the Kotlin → Dart stop callback, once.
  ///
  /// Guarded like every other method here: off Android there is no service to
  /// call back, and touching the channel without an engine binding asserts.
  void ensureStopListener() {
    if (_stopListenerInstalled) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    _stopListenerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'stopRequested') _stopListener?.call();
    });
  }
}