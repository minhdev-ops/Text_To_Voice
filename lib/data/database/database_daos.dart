import 'package:drift/drift.dart';

import 'app_database.dart';
import '../../domain/models/document.dart' show DocumentStatus, DocumentSource, DocumentSortBy;

part 'database_daos.g.dart';

@DriftAccessor(tables: [
  Documents,
  DocumentPages,
  DocumentBlocks,
  DocumentImages,
  TtsAudio,
  ReadingProgress,
  Settings,
  Models,
  ProcessingJobs,
])
class DatabaseDaos extends DatabaseAccessor<AppDatabase> with _$DatabaseDaosMixin {
  DatabaseDaos(super.db);

  // ============ Documents ============

  Future<List<Document>> getAllDocuments({
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
    var q = select(documents);

    if (query != null && query.isNotEmpty) {
      q.where((d) => d.name.like('%$query%') | d.extractedText.like('%$query%'));
    }
    if (status != null) {
      q.where((d) => d.status.equals(status.name));
    }
    if (source != null) {
      q.where((d) => d.source.equals(source.name));
    }
    if (isFavorite != null) {
      q.where((d) => d.isFavorite.equals(isFavorite));
    }
    if (category != null && category.isNotEmpty) {
      q.where((d) => d.category.equals(category));
    }

    switch (sortBy) {
      case DocumentSortBy.name:
        q.orderBy([(t) => ascending ? OrderingTerm.asc(t.name) : OrderingTerm.desc(t.name)]);
        break;
      case DocumentSortBy.createdAt:
        q.orderBy([(t) => ascending ? OrderingTerm.asc(t.createdAt) : OrderingTerm.desc(t.createdAt)]);
        break;
      case DocumentSortBy.updatedAt:
        q.orderBy([(t) => ascending ? OrderingTerm.asc(t.updatedAt) : OrderingTerm.desc(t.updatedAt)]);
        break;
      case DocumentSortBy.fileSize:
        q.orderBy([(t) => ascending ? OrderingTerm.asc(t.fileSize) : OrderingTerm.desc(t.fileSize)]);
        break;
      case DocumentSortBy.lastOpenedAt:
        q.orderBy([
          (t) => ascending
              ? OrderingTerm.asc(t.lastOpenedAt, nulls: NullsOrder.first)
              : OrderingTerm.desc(t.lastOpenedAt, nulls: NullsOrder.last),
        ]);
        break;
    }

    if (limit != null) {
      q.limit(limit, offset: offset);
    }

    return q.get();
  }

  Stream<List<Document>> watchAllDocuments({
    String? query,
    DocumentStatus? status,
    DocumentSource? source,
    bool? isFavorite,
    String? category,
    DocumentSortBy sortBy = DocumentSortBy.updatedAt,
    bool ascending = false,
  }) {
    var q = select(documents);

    if (query != null && query.isNotEmpty) {
      q.where((d) => d.name.like('%$query%') | d.extractedText.like('%$query%'));
    }
    if (status != null) {
      q.where((d) => d.status.equals(status.name));
    }
    if (source != null) {
      q.where((d) => d.source.equals(source.name));
    }
    if (isFavorite != null) {
      q.where((d) => d.isFavorite.equals(isFavorite));
    }
    if (category != null && category.isNotEmpty) {
      q.where((d) => d.category.equals(category));
    }

    switch (sortBy) {
      case DocumentSortBy.name:
        q.orderBy([(t) => ascending ? OrderingTerm.asc(t.name) : OrderingTerm.desc(t.name)]);
        break;
      case DocumentSortBy.createdAt:
        q.orderBy([(t) => ascending ? OrderingTerm.asc(t.createdAt) : OrderingTerm.desc(t.createdAt)]);
        break;
      case DocumentSortBy.updatedAt:
        q.orderBy([(t) => ascending ? OrderingTerm.asc(t.updatedAt) : OrderingTerm.desc(t.updatedAt)]);
        break;
      case DocumentSortBy.fileSize:
        q.orderBy([(t) => ascending ? OrderingTerm.asc(t.fileSize) : OrderingTerm.desc(t.fileSize)]);
        break;
      case DocumentSortBy.lastOpenedAt:
        q.orderBy([
          (t) => ascending
              ? OrderingTerm.asc(t.lastOpenedAt, nulls: NullsOrder.first)
              : OrderingTerm.desc(t.lastOpenedAt, nulls: NullsOrder.last),
        ]);
        break;
    }

    return q.watch();
  }

  Future<Document?> getDocumentById(String uuid) {
    return (select(documents)..where((d) => d.uuid.equals(uuid))).getSingleOrNull();
  }

  Future<int> insertDocument(DocumentsCompanion document) {
    return into(documents).insert(document);
  }

  Future<bool> updateDocument(DocumentsCompanion document) async {
    final matched = await (update(documents)..where((d) => d.uuid.equals(document.uuid.value)))
        .write(document);
    return matched > 0;
  }

  Future<int> deleteDocument(String uuid) {
    return (delete(documents)..where((d) => d.uuid.equals(uuid))).go();
  }

  Future<void> _updateDocumentFields(DocumentsCompanion companion) async {
    await (update(documents)..where((d) => d.uuid.equals(companion.uuid.value)))
        .write(companion);
  }

  Future<void> updateDocumentStatus(String uuid, DocumentStatus status, {String? failureMessage}) async {
    final companion = DocumentsCompanion(
      uuid: Value(uuid),
      status: Value(status.name),
      updatedAt: Value(DateTime.now()),
      failureMessage: failureMessage != null ? Value(failureMessage) : const Value.absent(),
    );
    await _updateDocumentFields(companion);
  }

  Future<void> markDocumentOpened(String uuid) async {
    final companion = DocumentsCompanion(
      uuid: Value(uuid),
      lastOpenedAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    );
    await _updateDocumentFields(companion);
  }

  Future<void> toggleFavorite(String uuid, bool isFavorite) async {
    final companion = DocumentsCompanion(
      uuid: Value(uuid),
      isFavorite: Value(isFavorite),
      updatedAt: Value(DateTime.now()),
    );
    await _updateDocumentFields(companion);
  }

  Future<void> renameDocument(String uuid, String newName) async {
    final companion = DocumentsCompanion(
      uuid: Value(uuid),
      name: Value(newName),
      updatedAt: Value(DateTime.now()),
    );
    await _updateDocumentFields(companion);
  }

  Future<void> setDocumentCategory(String uuid, String? category) async {
    final companion = DocumentsCompanion(
      uuid: Value(uuid),
      // Clearing must write NULL; absent would leave the old value untouched.
      category: category != null ? Value(category) : const Value<String?>(null),
      updatedAt: Value(DateTime.now()),
    );
    await _updateDocumentFields(companion);
  }

  Future<int> getDocumentCount() async {
    final count = documents.uuid.count();
    final row = await (selectOnly(documents)..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  Future<int> getStorageUsage() async {
    final total = documents.fileSize.sum();
    final row = await (selectOnly(documents)..addColumns([total])).getSingle();
    return row.read(total) ?? 0;
  }

  Future<int> getDocumentSize(String uuid) async {
    final size = documents.fileSize;
    final query = selectOnly(documents)
      ..where(documents.uuid.equals(uuid))
      ..addColumns([size]);
    final row = await query.getSingleOrNull();
    return row?.read(size) ?? 0;
  }

  // ============ Document Pages ============

  Future<List<DocumentPage>> getPagesForDocument(String documentId) {
    return (select(documentPages)..where((p) => p.documentId.equals(documentId))..orderBy([(t) => OrderingTerm.asc(t.pageNumber)])).get();
  }

  Future<int> insertPage(DocumentPagesCompanion page) {
    return into(documentPages).insert(page);
  }

  Future<void> insertPages(List<DocumentPagesCompanion> pages) {
    return batch((b) {
      b.insertAll(documentPages, pages);
    });
  }

  Future<int> deletePagesForDocument(String documentId) {
    return (delete(documentPages)..where((p) => p.documentId.equals(documentId))).go();
  }

  // ============ Document Blocks ============

  Future<List<DocumentBlock>> getBlocksForDocument(String documentId) {
    return (select(documentBlocks)
          ..where((b) => b.documentId.equals(documentId))
          ..orderBy([(t) => OrderingTerm.asc(t.order)]))
        .get();
  }

  Future<void> insertBlocks(List<DocumentBlocksCompanion> blocks) {
    return batch((b) {
      b.insertAll(documentBlocks, blocks);
    });
  }

  Future<int> deleteBlocksForDocument(String documentId) {
    return (delete(documentBlocks)..where((b) => b.documentId.equals(documentId))).go();
  }

  // ============ Document Images ============

  Future<List<DocumentImage>> getImagesForDocument(String documentId) {
    return (select(documentImages)
          ..where((i) => i.documentId.equals(documentId))
          ..orderBy([(t) => OrderingTerm.asc(t.pageNumber, nulls: NullsOrder.first)]))
        .get();
  }

  Future<int> insertImage(DocumentImagesCompanion image) {
    return into(documentImages).insert(image);
  }

  Future<void> insertImages(List<DocumentImagesCompanion> images) {
    return batch((b) {
      b.insertAll(documentImages, images);
    });
  }

  Future<int> deleteImagesForDocument(String documentId) {
    return (delete(documentImages)..where((i) => i.documentId.equals(documentId))).go();
  }

  Future<List<DocumentImage>> getOrphanImages() {
    // Images whose document no longer exists
    final docIds = selectOnly(documents)..addColumns([documents.uuid]);
    return (select(documentImages)
          ..where((i) => i.documentId.isNotInQuery(docIds)))
        .get();
  }

  // ============ TTS Audio Cache ============

  Future<TtsAudioData?> getTtsAudio({
    required String textHash,
    required String? voiceId,
    required double speed,
    required String format,
  }) {
    return (select(ttsAudio)
          ..where((a) =>
              a.textHash.equals(textHash) &
              a.voiceId.equals(voiceId ?? '') &
              a.speed.equals(speed) &
              a.format.equals(format)))
        .getSingleOrNull();
  }

  Future<TtsAudioData?> getTtsAudioByHash(String cacheKey) {
    return (select(ttsAudio)..where((a) => a.textHash.equals(cacheKey)))
        .getSingleOrNull();
  }

  Future<int> deleteTtsAudioByHash(String cacheKey) {
    return (delete(ttsAudio)..where((a) => a.textHash.equals(cacheKey))).go();
  }

  Future<int> insertTtsAudio(TtsAudioCompanion audio) {
    return into(ttsAudio).insert(audio);
  }

  Future<void> updateTtsAudioLastAccessed(String textHash, String? voiceId, double speed, String format) async {
    final companion = TtsAudioCompanion(
      textHash: Value(textHash),
      voiceId: Value(voiceId ?? ''),
      speed: Value(speed),
      format: Value(format),
      lastAccessedAt: Value(DateTime.now()),
    );
    await (update(ttsAudio)..where((a) => a.textHash.equals(textHash))).write(companion);
  }

  Future<int> deleteTtsAudio({
    required String textHash,
    required String? voiceId,
    required double speed,
    required String format,
  }) {
    return (delete(ttsAudio)
          ..where((a) =>
              a.textHash.equals(textHash) &
              a.voiceId.equals(voiceId ?? '') &
              a.speed.equals(speed) &
              a.format.equals(format)))
        .go();
  }

  Future<int> cleanupOldTtsAudio({int maxEntries = 1000, int maxAgeDays = 30}) {
    final cutoff = DateTime.now().subtract(Duration(days: maxAgeDays));
    // Keep only the most recently accessed entries up to maxEntries
    // This is a simplified version; a full implementation would need a more complex query
    return (delete(ttsAudio)..where((a) => a.lastAccessedAt.isSmallerThanValue(cutoff))).go();
  }

  Future<int> getTtsAudioCount() async {
    final count = ttsAudio.textHash.count();
    final row = await (selectOnly(ttsAudio)..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  Future<int> getTtsAudioTotalSize() async {
    // We don't store file size in tts_audio, would need to check filesystem
    return 0;
  }

  // ============ Reading Progress ============

  Future<ReadingProgressData?> getReadingProgress(String documentId) {
    return (select(readingProgress)..where((r) => r.documentId.equals(documentId))).getSingleOrNull();
  }

  /// Gets the most recent reading position across all documents.
  Future<ReadingProgressData?> getLatestReadingProgress() {
    return (select(readingProgress)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<int> upsertReadingProgress(ReadingProgressCompanion progress) {
    return into(readingProgress).insert(
      progress,
      onConflict: DoUpdate((_) => progress, target: [readingProgress.documentId]),
    );
  }

  Future<int> deleteReadingProgress(String documentId) {
    return (delete(readingProgress)..where((r) => r.documentId.equals(documentId))).go();
  }

  // ============ Settings ============

  Future<String?> getSetting(String key) {
    return (select(settings)..where((s) => s.key.equals(key))).getSingleOrNull().then((r) => r?.value);
  }

  Future<void> setSetting(String key, String value) {
    final companion = SettingsCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(DateTime.now()),
    );
    return into(settings).insert(
      companion,
      onConflict: DoUpdate((_) => companion, target: [settings.key]),
    );
  }

  Future<void> deleteSetting(String key) {
    return (delete(settings)..where((s) => s.key.equals(key))).go();
  }

  // ============ Models ============

  Future<List<Model>> getAllModels() {
    return select(models).get();
  }

  Future<Model?> getModelById(String uuid) {
    return (select(models)..where((m) => m.uuid.equals(uuid))).getSingleOrNull();
  }

  Future<Model?> getActiveModel() {
    return (select(models)..where((m) => m.isActive.equals(true))).getSingleOrNull();
  }

  Future<int> insertModel(ModelsCompanion model) {
    return into(models).insert(model);
  }

  Future<bool> updateModel(ModelsCompanion model) async {
    final matched = await (update(models)..where((m) => m.uuid.equals(model.uuid.value)))
        .write(model);
    return matched > 0;
  }

  Future<int> deleteModel(String uuid) {
    return (delete(models)..where((m) => m.uuid.equals(uuid))).go();
  }

  Future<void> setActiveModel(String uuid) async {
    await transaction(() async {
      // Deactivate all
      await (update(models)..where((m) => m.isActive.equals(true))).write(ModelsCompanion(isActive: const Value(false)));
      // Activate the selected one
      final companion = ModelsCompanion(
        isActive: const Value(true),
      );
      await (update(models)..where((m) => m.uuid.equals(uuid))).write(companion);
    });
  }

  // ============ Processing Jobs ============

  Future<List<ProcessingJob>> getPendingJobs() {
    return (select(processingJobs)
          ..where((j) => j.status.equals('queued') | j.status.equals('extracting') | j.status.equals('ocr'))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<ProcessingJob?> getJobById(String uuid) {
    return (select(processingJobs)..where((j) => j.uuid.equals(uuid))).getSingleOrNull();
  }

  Future<int> insertJob(ProcessingJobsCompanion job) {
    return into(processingJobs).insert(job);
  }

  Future<void> updateJobStatus(String uuid, String status, {int? progress, String? errorMessage}) async {
    final companion = ProcessingJobsCompanion(
      uuid: Value(uuid),
      status: Value(status),
      updatedAt: Value(DateTime.now()),
      progress: progress != null ? Value(progress) : const Value.absent(),
      errorMessage: errorMessage != null ? Value(errorMessage) : const Value.absent(),
    );
    await (update(processingJobs)..where((j) => j.uuid.equals(uuid))).write(companion);
  }

  Future<int> deleteJob(String uuid) {
    return (delete(processingJobs)..where((j) => j.uuid.equals(uuid))).go();
  }

  Future<int> cleanupOldJobs({int maxAgeDays = 7}) {
    final cutoff = DateTime.now().subtract(Duration(days: maxAgeDays));
    return (delete(processingJobs)
          ..where((j) =>
              (j.status.equals('completed') | j.status.equals('failed')) & j.updatedAt.isSmallerThanValue(cutoff)))
        .go();
  }
}
