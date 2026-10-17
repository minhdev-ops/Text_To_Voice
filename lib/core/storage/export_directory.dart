import 'dart:io';

import 'package:text_to_voice/core/storage/app_storage.dart';

/// Where exported files land.
///
/// App-private (`<app documents>/exports`) and nothing else: the app never writes
/// outside its own storage (SRS §38 / NFR-02). **That is also why sharing
/// exists** — app-private storage is invisible to every file manager, so a path
/// printed to the user is a location they cannot open. `PluginShareTarget`
/// (`lib/core/share/share_target.dart`) is how a file actually leaves the app.
Future<Directory> appExportDirectory() async {
  return appStorage.exportsDir;
}
