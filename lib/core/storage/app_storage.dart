import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// App-private storage layout (SRS §38 / NFR-02).
///
/// All content lives under the app's private documents directory:
/// - documents/<doc-id>/          — original imported files
/// - documents/<doc-id>/pages/    — rendered page images
/// - documents/<doc-id>/images/   — extracted/OCR images
/// - audio/<doc-id>/              — synthesized sentence audio (WAV)
/// - models/                      — downloaded ONNX checkpoints
/// - exports/                     — user-initiated exports (txt/md/json/wav/zip)
/// - temp/                        — transient files during processing
///
/// Nothing is ever written outside this tree. The OS deletes it all on uninstall.
class AppStorage {
  AppStorage._();

  static final AppStorage _instance = AppStorage._();

  factory AppStorage() => _instance;

  Directory? _baseDir;
  Directory? _documentsDir;
  Directory? _audioDir;
  Directory? _modelsDir;
  Directory? _exportsDir;
  Directory? _tempDir;

  /// The `models/` root beneath an app documents directory.
  ///
  /// A pure function, like [synthesisAudioRootIn], so the provider graph can
  /// resolve the same path from `appDocumentsDirectoryProvider` — the seam a test
  /// overrides — without needing the initialized singleton. [initialize] uses it
  /// too, so the layout still has exactly one definition.
  static Directory modelsRootIn(Directory documents) =>
      Directory('${documents.path}${Platform.pathSeparator}models');

  /// The `audio/_synthesis/` root beneath an app documents directory.
  static Directory synthesisAudioRootIn(Directory documents) => Directory(
        '${documents.path}${Platform.pathSeparator}audio'
        '${Platform.pathSeparator}_synthesis',
      );

  /// Initializes the storage layout. Must be called once at app start.
  Future<void> initialize() async {
    _baseDir = await getApplicationDocumentsDirectory();
    _documentsDir = Directory('${_baseDir!.path}${Platform.pathSeparator}documents');
    _audioDir = Directory('${_baseDir!.path}${Platform.pathSeparator}audio');
    _modelsDir = modelsRootIn(_baseDir!);
    _exportsDir = Directory('${_baseDir!.path}${Platform.pathSeparator}exports');
    _tempDir = Directory('${_baseDir!.path}${Platform.pathSeparator}temp');

    // Create all directories
    await Future.wait([
      _documentsDir!.create(recursive: true),
      _audioDir!.create(recursive: true),
      synthesisAudioDir.create(recursive: true),
      _modelsDir!.create(recursive: true),
      _exportsDir!.create(recursive: true),
      _tempDir!.create(recursive: true),
    ]);
  }

  /// Base app-private directory.
  Directory get base => _baseDir!;

  /// Document storage: documents/<doc-id>/
  Directory documentDir(String documentId) {
    return Directory('${_documentsDir!.path}${Platform.pathSeparator}$documentId');
  }

  /// Page images: documents/<doc-id>/pages/
  Directory documentPagesDir(String documentId) {
    return Directory('${documentDir(documentId).path}${Platform.pathSeparator}pages');
  }

  /// Extracted/OCR images: documents/<doc-id>/images/
  Directory documentImagesDir(String documentId) {
    return Directory('${documentDir(documentId).path}${Platform.pathSeparator}images');
  }

  /// Audio cache: audio/<doc-id>/
  Directory audioDir(String documentId) {
    return Directory('${_audioDir!.path}${Platform.pathSeparator}$documentId');
  }

  /// Synthesized speech for text that belongs to no document: audio/_synthesis/.
  ///
  /// Kept in the same tree as document audio so one storage cleanup covers both,
  /// but under a reserved name (leading underscore) so it can never collide with
  /// a document id.
  Directory get synthesisAudioDir => synthesisAudioRootIn(_baseDir!);

  /// Models directory: models/
  Directory get modelsDir => _modelsDir!;

  /// Specific model directory: models/<model-id>/
  Directory modelDir(String modelId) {
    return Directory('${_modelsDir!.path}${Platform.pathSeparator}$modelId');
  }

  /// Exports directory: exports/
  Directory get exportsDir => _exportsDir!;

  /// Temp directory: temp/
  Directory get tempDir => _tempDir!;

  /// Ticks once per temp name so two calls in the same microsecond (or even
  /// the same call repeating) can never collide.
  static int _tempSequence = 0;

  String _uniqueTempName(String prefix, {String? extension}) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final name = '${prefix}_${stamp}_${_tempSequence++}';
    return extension == null ? name : '$name.$extension';
  }

  /// Creates a unique temp file path.
  String tempFilePath(String prefix, String extension) {
    return '${_tempDir!.path}${Platform.pathSeparator}'
        '${_uniqueTempName(prefix, extension: extension)}';
  }

  /// Creates a unique temp directory path.
  Directory tempSubDir(String prefix) {
    return Directory(
        '${_tempDir!.path}${Platform.pathSeparator}${_uniqueTempName(prefix)}');
  }

  /// Ensures a document's directories exist.
  Future<void> ensureDocumentDirs(String documentId) async {
    await Future.wait([
      documentDir(documentId).create(recursive: true),
      documentPagesDir(documentId).create(recursive: true),
      documentImagesDir(documentId).create(recursive: true),
      audioDir(documentId).create(recursive: true),
    ]);
  }

  /// Deletes all files for a document (called when document is deleted).
  Future<void> deleteDocumentFiles(String documentId) async {
    await Future.wait([
      _deleteDirIfExists(documentDir(documentId)),
      _deleteDirIfExists(audioDir(documentId)),
    ]);
  }

  /// Deletes a model's files.
  Future<void> deleteModelFiles(String modelId) async {
    await _deleteDirIfExists(modelDir(modelId));
  }

  /// Gets the total size of all app storage in bytes.
  Future<int> getTotalSize() async {
    int total = 0;
    for (final dir in [_documentsDir, _audioDir, _modelsDir, _exportsDir, _tempDir]) {
      if (dir != null && await dir.exists()) {
        total += await _getDirSize(dir);
      }
    }
    return total;
  }

  /// Gets the size of a specific document's files.
  Future<int> getDocumentSize(String documentId) async {
    int total = 0;
    for (final dir in [documentDir(documentId), audioDir(documentId)]) {
      if (await dir.exists()) {
        total += await _getDirSize(dir);
      }
    }
    return total;
  }

  /// Gets the size of the audio cache.
  Future<int> getAudioCacheSize() async {
    if (await _audioDir!.exists()) {
      return _getDirSize(_audioDir!);
    }
    return 0;
  }

  /// Gets the size of the models directory.
  Future<int> getModelsSize() async {
    if (await _modelsDir!.exists()) {
      return _getDirSize(_modelsDir!);
    }
    return 0;
  }

  /// Cleans the temp directory (removes files older than maxAge).
  Future<int> cleanTemp({Duration maxAge = const Duration(days: 1)}) async {
    if (!await _tempDir!.exists()) return 0;

    int freed = 0;
    final cutoff = DateTime.now().subtract(maxAge);
    await for (final entity in _tempDir!.list(recursive: true)) {
      if (entity is File) {
        final stat = await entity.stat();
        if (stat.modified.isBefore(cutoff)) {
          freed += await entity.length();
          await entity.delete();
        }
      }
    }
    return freed;
  }

  Future<int> _getDirSize(Directory dir) async {
    int size = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          size += await entity.length();
        } catch (_) {
          // Ignore errors reading file size
        }
      }
    }
    return size;
  }

  Future<void> _deleteDirIfExists(Directory dir) async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}

/// Convenience getter for the singleton.
AppStorage get appStorage => AppStorage();