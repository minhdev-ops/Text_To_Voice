import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/storage/app_storage.dart';

/// Entry point.
///
/// Deliberately thin: no engine, database or file system is constructed here.
/// Collaborators are wired as Riverpod providers — `ProviderScope` is the
/// composition root — so this file stays a description of what the running app
/// is made of, not a place where anything is built.
///
/// Notably absent: a model-path override. Which TTS engine is live is decided by
/// install state (`models/model_providers.dart`), so installing or deleting a
/// model in the Models tab takes effect without restarting the app.
///
/// No analytics, no crash reporting, and no warm-up network call: NFR-02
/// (documents never leave the device) holds by construction rather than by
/// policy.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The app-private layout has to exist before the Model Manager can audit what
  // is installed in it (SRS §38).
  await appStorage.initialize();

  runApp(const ProviderScope(child: VietDocApp()));
}