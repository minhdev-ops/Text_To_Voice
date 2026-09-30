import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'database/app_database.dart';
import 'repository/document_repository.dart';
import '../core/storage/app_storage.dart';
import '../domain/models/tts.dart' show TtsOptions, SpeechFormat;

/// The Drift database instance.
///
/// Initialized once at app start with the app-private database file.
/// Uses `sqlite3_flutter_libs` for a bundled SQLite on Android.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final dir = ref.watch(appDocumentsDirectoryProvider).value;
  if (dir == null) {
    throw StateError('App documents directory not available yet');
  }
  final dbFile = File('${dir.path}${Platform.pathSeparator}app.db');
  if (Platform.isAndroid) {
    applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
  }
  return AppDatabase(NativeDatabase(dbFile));
});

/// The app documents directory from path_provider.
final appDocumentsDirectoryProvider = FutureProvider<Directory>((ref) async {
  return getApplicationDocumentsDirectory();
});

/// `<app documents>/models`: the root the Model Manager installs into and the
/// engine reads from.
///
/// Resolved through the provider graph rather than the initialized [appStorage]
/// singleton, for the same reason as [appDatabaseProvider]: the documents
/// directory is the seam a test overrides, and a path read off the singleton
/// would throw before `initialize()` ever ran.
final modelsDirectoryProvider = Provider<Directory>((ref) {
  final documents = ref.watch(appDocumentsDirectoryProvider).value;
  if (documents == null) {
    throw StateError('App documents directory not available yet');
  }
  return AppStorage.modelsRootIn(documents);
});

/// `<app documents>/audio/_synthesis`: where sentence WAVs are cached.
final synthesisAudioDirectoryProvider = Provider<Directory>((ref) {
  final documents = ref.watch(appDocumentsDirectoryProvider).value;
  if (documents == null) {
    throw StateError('App documents directory not available yet');
  }
  return AppStorage.synthesisAudioRootIn(documents);
});

/// The document repository.
final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository(ref.watch(appDatabaseProvider));
});

/// Initializes the app storage layout.
final appStorageInitializerProvider = FutureProvider<void>((ref) async {
  await appStorage.initialize();
});

/// Initializes the database (runs migrations).
final databaseInitializerProvider = FutureProvider<void>((ref) async {
  // The database is initialized lazily when first accessed.
  // This provider ensures it's ready before the UI loads.
  final db = ref.watch(appDatabaseProvider);
  // Trigger a simple query to ensure the database is created
  await db.select(db.documents).get();
});

/// Provides the default TTS options from settings.
final defaultTtsOptionsProvider = FutureProvider<TtsOptions>((ref) async {
  final repo = ref.watch(documentRepositoryProvider);
  final voiceId = await repo.getSetting('default_voice_id');
  final speedStr = await repo.getSetting('default_speed');
  final volumeStr = await repo.getSetting('default_volume');
  final formatStr = await repo.getSetting('default_format');

  return TtsOptions(
    voiceId: voiceId,
    speed: double.tryParse(speedStr ?? '1.0') ?? 1.0,
    volume: double.tryParse(volumeStr ?? '1.0') ?? 1.0,
    format: SpeechFormat.values.byName(formatStr ?? 'wav'),
  );
});