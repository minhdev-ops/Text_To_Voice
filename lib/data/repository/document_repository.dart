import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/document.dart';
import '../../domain/models/document_block.dart';
import '../../domain/models/document_image.dart';
import '../../domain/models/reading.dart';
import '../../domain/models/tts.dart';
import '../../domain/speech/synthesis_cache.dart';
import '../database/app_database.dart' hide Document, DocumentBlock, DocumentImage;
import '../database/app_database.dart' as sql show Document, DocumentBlock, DocumentImage;
import '../database/database_daos.dart';

/// Repository for document persistence (SRS §30–§33).
///
/// Bridges domain models and the Drift database, enforcing:
/// - Immutable domain models with value equality
/// - App-private storage paths (no external paths ever stored)
/// - Content-hash duplicate detection on import
/// - Transactional writes for multi-table operations
class DocumentRepository {
  DocumentRepository(this._db);

  final AppDatabase _db;
  late final DatabaseDaos _daos = DatabaseDaos(_db);

  /// Creates a new document with all its related data in a single transaction.
  ///
  /// [status] defaults to [DocumentStatus.ready] because every caller has
  /// already finished extracting by the time it inserts; a caller that enqueues
  /// work instead passes [DocumentStatus.queued] explicitly.
  Future<String> createDocument({
    required String id,
    required String name,
    required DocumentSource source,
    required String mimeType,
    String? originalFileName,
    required int fileSize,
    String? filePath,
    String? extractedText,
    String? category,
    DocumentStatus status = DocumentStatus.ready,
    List<DocumentBlock> blocks = const [],
    List<DocumentImage> images = const [],
    Map<String, Object?> metadata = const {},
  }) async {
    final now = DateTime.now();

    return _db.transaction(() async {
      // Insert document
      await _daos.insertDocument(DocumentsCompanion(
        uuid: Value(id),
        name: Value(name),
        source: Value(source.name),
        mimeType: Value(mimeType),
        originalFileName: originalFileName != null ? Value(originalFileName) : const Value.absent(),
        fileSize: Value(fileSize),
        filePath: filePath != null ? Value(filePath) : const Value.absent(),
        status: Value(status.name),
        extractedText: extractedText != null ? Value(extractedText) : const Value.absent(),
        category: category != null ? Value(category) : const Value.absent(),
        isFavorite: const Value(false),
        createdAt: Value(now),
        updatedAt: Value(now),
        metadata: Value(jsonEncode(metadata)),
      ));

      // Insert blocks
      if (blocks.isNotEmpty) {
        final blockCompanions = blocks.map((b) => _blockToCompanion(b, id, now)).toList();
        await _daos.insertBlocks(blockCompanions);
      }

      // Insert images
      if (images.isNotEmpty) {
        final imageCompanions = images.map((i) => _imageToCompanion(i, id, now)).toList();
        await _daos.insertImages(imageCompanions);
      }

      return id;
    });
  }

  /// Updates an existing document's metadata.
  Future<void> updateDocument(Document document) async {
    await _daos.updateDocument(DocumentsCompanion(
      uuid: Value(document.id),
      name: Value(document.name),
      source: Value(document.source.name),
      mimeType: Value(document.mimeType),
      originalFileName: document.originalFileName != null
          ? Value(document.originalFileName!)
          : const Value.absent(),
      fileSize: Value(document.fileSize),
      filePath: document.filePath != null ? Value(document.filePath!) : const Value.absent(),
      status: Value(document.status.name),
      extractedText: document.extractedText != null ? Value(document.extractedText!) : const Value.absent(),
      isFavorite: Value(document.isFavorite),
      category: document.category != null ? Value(document.category!) : const Value.absent(),
      updatedAt: Value(document.updatedAt),
      lastOpenedAt: document.lastOpenedAt != null ? Value(document.lastOpenedAt!) : const Value.absent(),
      failureMessage: document.failureMessage != null ? Value(document.failureMessage!) : const Value.absent(),
      metadata: Value(jsonEncode(document.metadata)),
    ));
  }

  /// Gets a document by ID only.
  Future<Document?> getDocumentById(String id) async {
    final doc = await _daos.getDocumentById(id);
    if (doc == null) return null;
    return _mapDocument(doc);
  }

  /// Gets a document by ID with all its blocks and images.
  Future<DocumentWithData?> getDocumentWithData(String id) async {
    final doc = await _daos.getDocumentById(id);
    if (doc == null) return null;

    final blocks = await _daos.getBlocksForDocument(id);
    final images = await _daos.getImagesForDocument(id);

    return DocumentWithData(
      document: _mapDocument(doc),
      blocks: blocks.map(_mapBlock).toList(),
      images: images.map(_mapImage).toList(),
    );
  }

  /// Gets all documents with optional filtering and sorting.
  Future<List<Document>> getDocuments({
    String? query,
    DocumentStatus? status,
    DocumentSource? source,
    bool? isFavorite,
    String? category,
    DocumentSortBy sortBy = DocumentSortBy.updatedAt,
    bool ascending = false,
    int? limit,
    int? offset,
  }) {
    return _daos.getAllDocuments(
      query: query,
      status: status,
      source: source,
      isFavorite: isFavorite,
      category: category,
      sortBy: sortBy,
      ascending: ascending,
      limit: limit,
      offset: offset,
    ).then((list) => list.map(_mapDocument).toList());
  }

  /// Watches all documents with optional filtering and sorting.
  Stream<List<Document>> watchDocuments({
    String? query,
    DocumentStatus? status,
    DocumentSource? source,
    bool? isFavorite,
    String? category,
    DocumentSortBy sortBy = DocumentSortBy.updatedAt,
    bool ascending = false,
  }) {
    return _daos.watchAllDocuments(
      query: query,
      status: status,
      source: source,
      isFavorite: isFavorite,
      category: category,
      sortBy: sortBy,
      ascending: ascending,
    ).map((list) => list.map(_mapDocument).toList());
  }

  /// Deletes a document and all its related data.
  Future<void> deleteDocument(String id) async {
    await _db.transaction(() async {
      // Get images first to delete files
      final images = await _daos.getImagesForDocument(id);
      for (final image in images) {
        await _deleteFileIfExists(image.filePath);
      }

      await _daos.deleteImagesForDocument(id);
      await _daos.deleteBlocksForDocument(id);
      await _daos.deletePagesForDocument(id);
      await _daos.deleteReadingProgress(id);
      await _daos.deleteDocument(id);
    });
  }

  /// Toggles the favorite status of a document.
  Future<void> toggleFavorite(String id, bool isFavorite) {
    return _daos.toggleFavorite(id, isFavorite);
  }

  /// Renames a document.
  Future<void> renameDocument(String id, String newName) {
    return _daos.renameDocument(id, newName);
  }

  /// Sets the category of a document.
  Future<void> setCategory(String id, String? category) {
    return _daos.setDocumentCategory(id, category);
  }

  /// Marks a document as opened (updates lastOpenedAt).
  Future<void> markOpened(String id) {
    return _daos.markDocumentOpened(id);
  }

  /// Updates document status.
  Future<void> updateStatus(String id, DocumentStatus status, {String? failureMessage}) {
    return _daos.updateDocumentStatus(id, status, failureMessage: failureMessage);
  }

  /// Gets total document count.
  Future<int> getDocumentCount() {
    return _daos.getDocumentCount();
  }

  /// Gets total storage usage in bytes.
  Future<int> getStorageUsage() {
    return _daos.getStorageUsage();
  }

  /// Gets the size of a specific document's files.
  Future<int> getDocumentSize(String id) {
    return _daos.getDocumentSize(id);
  }

  // ============ TTS Audio Cache (SRS §32) ============

  /// `tts_audio.textHash` is capped at 64 characters, while a cache key embeds
  /// the whole sentence (`TtsOptions.cacheKey`). Store a SHA-256 digest of the
  /// key — exactly 64 hex characters — at every DAO boundary, and hand callers
  /// the raw key back on [AudioResult], so save/find stay symmetric without
  /// the storage detail leaking into the domain.
  static String _hashCacheKey(String cacheKey) =>
      sha256.convert(utf8.encode(cacheKey)).toString();

  /// Gets cached audio for the given cache key (folds text + voice + speed +
  /// format, per `TtsOptions.cacheKey`).
  Future<AudioResult?> getCachedAudio(String cacheKey) async {
    final hash = _hashCacheKey(cacheKey);
    final row = await _daos.getTtsAudioByHash(hash);
    if (row == null) return null;

    // Verify file still exists
    final file = File(row.filePath);
    if (!await file.exists()) {
      await _daos.deleteTtsAudioByHash(hash);
      return null;
    }

    // Update last accessed time
    await _daos.updateTtsAudioLastAccessed(hash, row.voiceId, row.speed, row.format);

    return AudioResult(
      path: row.filePath,
      duration: Duration(milliseconds: row.durationMs),
      textHash: cacheKey,
      sampleRate: row.sampleRate,
      channels: row.channels,
      voiceId: row.voiceId == '' ? null : row.voiceId,
      speed: row.speed,
      cacheHit: true,
    );
  }

  /// Caches synthesized audio under [cacheKey].
  Future<void> cacheAudio(String cacheKey, AudioResult result) async {
    await _daos.insertTtsAudio(TtsAudioCompanion(
      textHash: Value(_hashCacheKey(cacheKey)),
      voiceId: Value(result.voiceId ?? ''),
      speed: Value(result.speed),
      format: Value(SpeechFormat.wav.name),
      filePath: Value(result.path),
      durationMs: Value(result.duration.inMilliseconds),
      sampleRate: Value(result.sampleRate),
      channels: Value(result.channels),
      createdAt: Value(DateTime.now()),
      lastAccessedAt: Value(DateTime.now()),
    ));
  }

  /// Cleans up old cached audio.
  Future<int> cleanupAudioCache({int maxEntries = 1000, int maxAgeDays = 30}) {
    return _daos.cleanupOldTtsAudio(maxEntries: maxEntries, maxAgeDays: maxAgeDays);
  }

  // ============ Reading Progress (SRS §33) ============

  /// Gets the reading position for a document.
  Future<ReadingPosition?> getReadingPosition(String documentId) async {
    final row = await _daos.getReadingProgress(documentId);
    if (row == null) return null;

    return ReadingPosition(
      documentId: row.documentId,
      pageNumber: row.pageNumber,
      blockId: row.blockId,
      sentenceIndex: row.sentenceIndex,
      positionMs: row.positionMs,
      updatedAt: row.updatedAt,
    );
  }

  /// Saves the reading position for a document.
  Future<void> saveReadingPosition(ReadingPosition position) async {
    await _daos.upsertReadingProgress(ReadingProgressCompanion(
      documentId: Value(position.documentId),
      pageNumber: position.pageNumber != null ? Value(position.pageNumber!) : const Value.absent(),
      blockId: position.blockId != null ? Value(position.blockId!) : const Value.absent(),
      sentenceIndex: Value(position.sentenceIndex),
      positionMs: Value(position.positionMs),
      updatedAt: Value(position.updatedAt),
    ));
  }

  /// Deletes the reading position for a document.
  Future<void> deleteReadingPosition(String documentId) {
    return _daos.deleteReadingProgress(documentId);
  }

  /// Gets the most recent reading position across all documents.
  Future<ReadingPosition?> getLatestReadingPosition() async {
    final row = await _daos.getLatestReadingProgress();
    if (row == null) return null;

    return ReadingPosition(
      documentId: row.documentId,
      pageNumber: row.pageNumber,
      blockId: row.blockId,
      sentenceIndex: row.sentenceIndex,
      positionMs: row.positionMs,
      updatedAt: row.updatedAt,
    );
  }

  // ============ Settings (SRS §34) ============

  Future<String?> getSetting(String key) {
    return _daos.getSetting(key);
  }

  Future<void> setSetting(String key, String value) {
    return _daos.setSetting(key, value);
  }

  Future<void> deleteSetting(String key) {
    return _daos.deleteSetting(key);
  }

  // ============ Models (SRS §35) ============

  Future<List<VoicePreset>> getInstalledModels() async {
    final rows = await _daos.getAllModels();
    return rows.where((m) => m.isInstalled).map(_mapModel).toList();
  }

  Future<VoicePreset?> getActiveModel() async {
    final row = await _daos.getActiveModel();
    return row != null ? _mapModel(row) : null;
  }

  Future<void> setActiveModel(String uuid) {
    return _daos.setActiveModel(uuid);
  }

  Future<void> addModel(VoicePreset model, String filePath, String checksum) async {
    await _daos.insertModel(ModelsCompanion(
      uuid: Value(model.id),
      engineId: Value(model.engineId ?? 'vieneu-onnx'),
      checkpointName: Value(model.label),
      version: Value('1.0'),
      license: Value(model.license ?? 'Unknown'),
      sizeBytes: Value(model.sizeBytes),
      filePath: Value(filePath),
      isInstalled: Value(true),
      isActive: Value(false),
      checksum: Value(checksum),
      installedAt: Value(DateTime.now()),
    ));
  }

  Future<void> removeModel(String uuid) async {
    final model = await _daos.getModelById(uuid);
    if (model != null && model.filePath != null) {
      await _deleteFileIfExists(model.filePath!);
    }
    await _daos.deleteModel(uuid);
  }

  /// Records an installed model, idempotently.
  ///
  /// `addModel` alone is not enough: `models.uuid` is unique, so re-installing a
  /// model the user deleted-but-not-forgotten, or repairing a corrupt one, would
  /// throw on the second insert instead of simply updating the row.
  Future<void> upsertModel(
    VoicePreset model,
    String filePath,
    String checksum,
  ) async {
    final existing = await _daos.getModelById(model.id);
    if (existing == null) {
      await addModel(model, filePath, checksum);
      await _daos.setActiveModel(model.id);
      return;
    }
    await _daos.updateModel(ModelsCompanion(
      uuid: Value(model.id),
      engineId: Value(model.engineId ?? 'vieneu-onnx'),
      checkpointName: Value(model.label),
      version: Value(existing.version),
      license: Value(model.license ?? 'Unknown'),
      sizeBytes: Value(model.sizeBytes),
      filePath: Value(filePath),
      isInstalled: Value(true),
      isActive: Value(true),
      checksum: Value(checksum),
      installedAt: Value(DateTime.now()),
    ));
    await _daos.setActiveModel(model.id);
  }

  /// Drops the `models` row **without** touching files.
  ///
  /// Used when the Model Manager deleted the bytes itself: calling
  /// [removeModel] here would delete a path the install service already removed,
  /// and a *directory* handed to `File.delete` throws.
  Future<void> forgetModel(String uuid) {
    return _daos.deleteModel(uuid);
  }

  // ============ Processing Jobs ============

  Future<void> enqueueJob({
    required String id,
    required String type,
    String? documentId,
    Map<String, Object?> payload = const {},
  }) async {
    await _daos.insertJob(ProcessingJobsCompanion(
      uuid: Value(id),
      type: Value(type),
      documentId: documentId != null ? Value(documentId) : const Value.absent(),
      status: Value('queued'),
      payload: Value(jsonEncode(payload)),
    ));
  }

  Future<void> updateJobStatus(String id, String status, {int? progress, String? errorMessage}) {
    return _daos.updateJobStatus(id, status, progress: progress, errorMessage: errorMessage);
  }

  Future<List<ProcessingJobData>> getPendingJobs() async {
    final rows = await _daos.getPendingJobs();
    return rows.map(_mapJob).toList();
  }

  // ============ Cleanup ============

  /// Removes orphaned files (images, audio) whose database records are gone.
  Future<CleanupResult> cleanupOrphanFiles() async {
    int deletedImages = 0;
    int deletedAudio = 0;
    int freedBytes = 0;

    // Orphan images
    final orphanImages = await _daos.getOrphanImages();
    for (final image in orphanImages) {
      final file = File(image.filePath);
      if (await file.exists()) {
        freedBytes += await file.length();
        await file.delete();
        deletedImages++;
      }
    }

    // Note: Audio cache cleanup is handled by cleanupAudioCache

    return CleanupResult(
      deletedImages: deletedImages,
      deletedAudio: deletedAudio,
      freedBytes: freedBytes,
    );
  }

  Future<int> cleanupOldJobs({int maxAgeDays = 7}) {
    return _daos.cleanupOldJobs(maxAgeDays: maxAgeDays);
  }

  // ============ Helpers ============

  DocumentsCompanion _documentToCompanion(Document doc) {
    return DocumentsCompanion(
      uuid: Value(doc.id),
      name: Value(doc.name),
      source: Value(doc.source.name),
      mimeType: Value(doc.mimeType),
      originalFileName: doc.originalFileName != null ? Value(doc.originalFileName!) : const Value.absent(),
      fileSize: Value(doc.fileSize),
      filePath: doc.filePath != null ? Value(doc.filePath!) : const Value.absent(),
      status: Value(doc.status.name),
      extractedText: doc.extractedText != null ? Value(doc.extractedText!) : const Value.absent(),
      isFavorite: Value(doc.isFavorite),
      category: doc.category != null ? Value(doc.category!) : const Value.absent(),
      createdAt: Value(doc.createdAt),
      updatedAt: Value(doc.updatedAt),
      lastOpenedAt: doc.lastOpenedAt != null ? Value(doc.lastOpenedAt!) : const Value.absent(),
      failureMessage: doc.failureMessage != null ? Value(doc.failureMessage!) : const Value.absent(),
      metadata: Value(jsonEncode(doc.metadata)),
    );
  }

  Document _mapDocument(sql.Document doc) {
    return Document(
      id: doc.uuid,
      name: doc.name,
      source: DocumentSource.values.firstWhere((s) => s.name == doc.source),
      mimeType: doc.mimeType,
      originalFileName: doc.originalFileName,
      fileSize: doc.fileSize,
      filePath: doc.filePath,
      status: DocumentStatus.values.firstWhere((s) => s.name == doc.status),
      extractedText: doc.extractedText,
      isFavorite: doc.isFavorite,
      category: doc.category,
      createdAt: doc.createdAt,
      updatedAt: doc.updatedAt,
      lastOpenedAt: doc.lastOpenedAt,
      failureMessage: doc.failureMessage,
      metadata: jsonDecode(doc.metadata) as Map<String, Object?>,
    );
  }

  DocumentBlocksCompanion _blockToCompanion(DocumentBlock block, String documentId, DateTime now) {
    return DocumentBlocksCompanion(
      uuid: Value(block.id),
      documentId: Value(documentId),
      pageId: block.pageId != null ? Value(block.pageId!) : const Value.absent(),
      type: Value(block.type.name),
      level: Value(block.level),
      content: Value(block.content),
      order: Value(block.order),
      left: block.position?.left != null ? Value(block.position!.left!) : const Value.absent(),
      top: block.position?.top != null ? Value(block.position!.top!) : const Value.absent(),
      width: block.position?.width != null ? Value(block.position!.width!) : const Value.absent(),
      height: block.position?.height != null ? Value(block.position!.height!) : const Value.absent(),
      confidence: block.confidence != null ? Value(block.confidence!) : const Value.absent(),
      createdAt: Value(now),
      metadata: Value(jsonEncode(block.metadata)),
    );
  }

  DocumentBlock _mapBlock(sql.DocumentBlock block) {
    return DocumentBlock(
      id: block.uuid,
      documentId: block.documentId,
      pageId: block.pageId,
      type: BlockType.values.firstWhere((t) => t.name == block.type),
      level: block.level,
      content: block.content,
      order: block.order,
      position: (block.left != null && block.top != null && block.width != null && block.height != null)
          ? BlockPosition(
              pageNumber: block.pageId != null ? int.tryParse(block.pageId!.replaceAll(RegExp(r'[^0-9]'), '')) : null,
              left: block.left,
              top: block.top,
              width: block.width,
              height: block.height,
            )
          : null,
      confidence: block.confidence,
      createdAt: block.createdAt,
      metadata: jsonDecode(block.metadata) as Map<String, Object?>,
    );
  }

  DocumentImagesCompanion _imageToCompanion(DocumentImage image, String documentId, DateTime now) {
    return DocumentImagesCompanion(
      uuid: Value(image.id),
      documentId: Value(documentId),
      pageId: image.pageId != null ? Value(image.pageId!) : const Value.absent(),
      pageNumber: image.pageNumber != null ? Value(image.pageNumber!) : const Value.absent(),
      sourceType: Value(image.sourceType.name),
      filePath: Value(image.filePath),
      format: Value(image.format),
      width: Value(image.width),
      height: Value(image.height),
      fileSize: Value(image.fileSize),
      createdAt: Value(now),
    );
  }

  DocumentImage _mapImage(sql.DocumentImage image) {
    return DocumentImage(
      id: image.uuid,
      documentId: image.documentId,
      pageId: image.pageId,
      pageNumber: image.pageNumber,
      sourceType: ImageSourceType.values.firstWhere((s) => s.name == image.sourceType),
      filePath: image.filePath,
      format: image.format,
      width: image.width,
      height: image.height,
      fileSize: image.fileSize,
      createdAt: image.createdAt,
    );
  }

  VoicePreset _mapModel(Model model) {
    return VoicePreset(
      id: model.uuid,
      label: model.checkpointName,
      language: 'vi-VN',
      engineId: model.engineId,
      license: model.license,
      isInstalled: model.isInstalled,
      sizeBytes: model.sizeBytes,
    );
  }

  ProcessingJobData _mapJob(ProcessingJob job) {
    return ProcessingJobData(
      id: job.uuid,
      type: job.type,
      documentId: job.documentId,
      status: job.status,
      progress: job.progress,
      errorMessage: job.errorMessage,
      payload: jsonDecode(job.payload) as Map<String, Object?>,
      createdAt: job.createdAt,
      updatedAt: job.updatedAt,
    );
  }

  Future<void> _deleteFileIfExists(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore file deletion errors
    }
  }
}

/// Document with its blocks and images loaded.
@immutable
class DocumentWithData {
  const DocumentWithData({
    required this.document,
    required this.blocks,
    required this.images,
  });

  final Document document;
  final List<DocumentBlock> blocks;
  final List<DocumentImage> images;
}

/// Result of a cleanup operation.
@immutable
class CleanupResult {
  const CleanupResult({
    required this.deletedImages,
    required this.deletedAudio,
    required this.freedBytes,
  });

  final int deletedImages;
  final int deletedAudio;
  final int freedBytes;

  String get freedBytesHuman {
    if (freedBytes < 1024) return '$freedBytes B';
    if (freedBytes < 1024 * 1024) return '${(freedBytes / 1024).toStringAsFixed(1)} KB';
    return '${(freedBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Processing job data for the queue.
@immutable
class ProcessingJobData {
  const ProcessingJobData({
    required this.id,
    required this.type,
    this.documentId,
    required this.status,
    required this.progress,
    this.errorMessage,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String type;
  final String? documentId;
  final String status;
  final int progress;
  final String? errorMessage;
  final Map<String, Object?> payload;
  final DateTime createdAt;
  final DateTime updatedAt;
}