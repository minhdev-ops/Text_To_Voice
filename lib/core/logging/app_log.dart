import 'dart:collection' show ListQueue;

import 'package:flutter/foundation.dart' show immutable, visibleForTesting;

enum LogLevel { debug, info, warning, error }

@immutable
class LogEntry {
  const LogEntry({
    required this.at,
    required this.level,
    required this.message,
    this.data = const <String, Object?>{},
    this.error,
    this.stackTrace,
  });

  final DateTime at;
  final LogLevel level;
  final String message;
  final Map<String, Object?> data;
  final Object? error;
  final StackTrace? stackTrace;

  @override
  String toString() {
    final extras = data.isEmpty ? '' : ' $data';
    final cause = error == null ? '' : ' error=$error';
    return '[${level.name}] $message$extras$cause';
  }
}

/// Local, in-memory log.
///
/// **NFR-02 applies here too.** Entries live in a process-wide ring buffer and
/// are never written to disk or sent anywhere — the "Xem nhật ký" line in
/// `UnexpectedFailure` is only honest if the log actually exists and actually
/// stays on the device.
///
/// The one rule this type exists to enforce: **never log document content.**
/// Use [AppLog.textDigest] to log a text's shape instead of its text.
abstract final class AppLog {
  static LogLevel level = LogLevel.debug;
  static const int _capacity = 200;

  /// Maximum retained entries. Exposed so the buffer bound is testable.
  static int get capacity => _capacity;

  static final ListQueue<LogEntry> _entries = ListQueue<LogEntry>();

  static void debug(String message, {Map<String, Object?>? data}) =>
      _add(LogLevel.debug, message, data);

  static void info(String message, {Map<String, Object?>? data}) =>
      _add(LogLevel.info, message, data);

  static void warning(String message, {Map<String, Object?>? data}) =>
      _add(LogLevel.warning, message, data);

  static void error(
    String message, {
    Map<String, Object?>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (_dropped(LogLevel.error)) return;
    _push(LogEntry(
      at: DateTime.now(),
      level: LogLevel.error,
      message: message,
      data: data ?? const <String, Object?>{},
      error: error,
      stackTrace: stackTrace,
    ));
    // Errors are also surfaced in debug builds so a failure is never silent.
    assert(() {
      // ignore: avoid_print
      print('[error] $message${error == null ? '' : ' $error'}');
      return true;
    }());
  }

  static void _add(LogLevel messageLevel, String message,
      Map<String, Object?>? data) {
    if (_dropped(messageLevel)) return;
    _push(LogEntry(
      at: DateTime.now(),
      level: messageLevel,
      message: message,
      data: data ?? const <String, Object?>{},
    ));
    // Info and warning also go to the debug console (logcat), because stage
    // timings like `vieneu.model.ready ms` are unreadable from a ring buffer
    // on a phone. Debug stays buffered only: it is chatty by design.
    // Errors print from [error] above.
    if (messageLevel == LogLevel.debug) return;
    assert(() {
      final extras = data == null || data.isEmpty ? '' : ' $data';
      // ignore: avoid_print
      print('[${messageLevel.name}] $message$extras');
      return true;
    }());
  }

  static void _push(LogEntry entry) {
    if (_entries.length >= _capacity) _entries.removeFirst();
    _entries.addLast(entry);
  }

  /// Newest last.
  static List<LogEntry> get entries => List<LogEntry>.unmodifiable(_entries);

  /// Describes a piece of user text **without revealing it**: length, line
  /// count and a short hash. Use this instead of logging the text itself.
  ///
  /// `AppLog.textDigest(document.extractedText)` → `len=12840 lines=214 hash=a3f9c1`
  static String textDigest(String? text) {
    if (text == null || text.isEmpty) return 'len=0';
    var lines = 1;
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) == 0x0A) lines++;
    }
    // FNV-1a 32 — stable, tiny, and non-reversible enough for log correlation.
    var hash = 0x811C9DC5;
    for (var i = 0; i < text.length; i++) {
      hash ^= text.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return 'len=${text.length} lines=$lines hash=${hash.toRadixString(16)}';
  }

  /// `debug` (0) is the most verbose; a message is dropped when it sits
  /// *below* the configured [level].
  static bool _dropped(LogLevel messageLevel) =>
      messageLevel.index < level.index;

  @visibleForTesting
  static void clear() => _entries.clear();
}
