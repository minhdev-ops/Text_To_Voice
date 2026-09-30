import 'dart:io';

import 'package:text_to_voice/core/storage/app_storage.dart';

/// Where exported files land.
///
/// App-private (`<app documents>/exports`) and nothing else in Phase 1: the app
/// never writes outside its own storage (SRS §38 / NFR-02), and the export screen
/// prints the real path so the user knows where the files are. A share target
/// (`share_plus`, still unverified) and SRS §30's full `exports/` layout are
/// Phase 5/6 work — this function is the seam they will replace.
Future<Directory> appExportDirectory() async {
  return appStorage.exportsDir;
}
