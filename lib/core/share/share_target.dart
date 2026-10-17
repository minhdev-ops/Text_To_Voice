import 'dart:io';

import 'package:share_plus/share_plus.dart';

import '../logging/app_log.dart';

/// Hands exported files to another app — FR-16, and the reason an export is
/// useful at all.
///
/// **Why the seam exists.** Exports land in app-private storage (SRS §38), which
/// on Android is unreachable: the user cannot browse to it, and a file the app
/// can write but nobody can open is not an export. Before this, the sheet printed
/// a path and stopped, which left the user with a location they had no way to
/// use.
///
/// Behind an interface so the sheet can be widget-tested without a platform
/// channel, and so the "no app accepted the share" case is a typed failure the
/// UI can say out loud rather than a silent no-op.
abstract interface class ShareTarget {
  /// Offers [paths] to the system share sheet.
  ///
  /// Returns a failure when nothing accepted the share — a real outcome on a
  /// device with no app registered for the type, and one the user needs to hear
  /// rather than see a sheet close for no reason.
  Future<void> shareFiles(
    List<String> paths, {
    required String title,
    String? text,
  });
}

class PluginShareTarget implements ShareTarget {
  const PluginShareTarget();

  @override
  Future<void> shareFiles(
    List<String> paths, {
    required String title,
    String? text,
  }) async {
    final existing = <XFile>[];
    for (final path in paths) {
      final file = File(path);
      if (await file.exists()) {
        existing.add(XFile(file.path));
      } else {
        AppLog.warning('share.missing', data: <String, Object?>{'path': path});
      }
    }

    if (existing.isEmpty) {
      throw const ShareUnavailableFailure();
    }

    await SharePlus.instance.share(
      ShareParams(
        files: existing,
        // A share sheet with no title is unrecognisable in the app switcher and
        // in the chooser's header, so the document's own name goes there.
        title: title,
        text: text,
      ),
    );
  }
}

/// Nothing accepted the share, or the file is gone.
class ShareUnavailableFailure implements Exception {
  const ShareUnavailableFailure();

  @override
  String toString() => 'ShareUnavailableFailure';
}
