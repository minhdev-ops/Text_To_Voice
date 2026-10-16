import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/document.dart';
import '../../domain/models/document_block.dart';
import '../../domain/models/document_image.dart';
import '../../domain/models/reading.dart';
import '../../domain/models/search.dart' show SearchHit, SearchResults;
import '../../domain/models/tts.dart';
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

      // Pages, then blocks.
      //
      // **Order matters**: a block's `page_id` is a foreign key into
      // `document_pages`, and SRS FR-17 §20 reports "Page 5" by joining the two.
      // `document_pages` was defined and never written, so every block had a null
      // page and every search result would have had to omit the one piece of
      // information that makes a result findable. The page numbers already exist
      // on the blocks — the OCR structurer puts them there — so persisting them
      // is deriving a fact, not inventing one.
      final pages = _pagesForBlocks(id, source, blocks);
      if (pages.isNotEmpty) {
        await _daos.insertPages(pages);
      }

      if (blocks.isNotEmpty) {
        final blockCompanions = <DocumentBlocksCompanion>[
          for (final block in blocks)
            _blockToCompanion(block, id, now, pageId: _pageUuidForBlock(id, block)),
        ];
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

  // ============ Search (SRS FR-17 §20) ============

  /// Finds [query] across document bodies and titles, as locations.
  ///
  /// SRS FR-17 wants `Document · Page · excerpt`, which is a different question
  /// from the library filter's "which documents match" — so this does not reuse
  /// [getDocuments]. A document matched on four pages is four results, because
  /// the reader wants to know which four.
  ///
  /// [maxHits] bounds the work, because this walks `document_blocks` and an
  /// unbounded scan of a large library on every keystroke is exactly the
  /// behaviour that makes a search box feel broken.
  Future<SearchResults> search(String query, {int maxHits = 200}) async {
    final term = query.trim();
    if (term.isEmpty) {
      return SearchResults(hits: const <SearchHit>[], query: term);
    }

    // The SQL pattern is a **permissive prefilter**, not the answer: `%` and `_`
    // are LIKE wildcards and drift emits no `ESCAPE` clause, so backslash-escaping
    // them here would produce a literal backslash and match nothing. Left
    // unescaped, `100%` reads as "100 then anything", which is a *superset* of
    // "contains 100%". Every candidate is therefore re-checked exactly in Dart
    // below, which is what makes a `%` in a Vietnamese price or a percentage
    // searchable instead of catastrophic.
    final pattern = '%$term%';

    var rows = await _daos.searchBlocks(
      pattern: pattern,
      limit: maxHits,
    );
    var titles = await _daos.searchByName(
      pattern: pattern,
      limit: maxHits,
    );

    // SQLite case-folds ASCII only, so `%giáo%` never sees a heading stored as
    // `GIÁO TRÌNH` and a whole library can come back empty even though every
    // document really contains the term. When the fast path finds nothing,
    // scan a bounded window and let Dart — which case-folds the whole string —
    // answer instead.
    if (rows.isEmpty) {
      rows = await _daos.scanBlocks(limit: _caseFallbackScanLimit);
    }
    if (titles.isEmpty) {
      titles = await _daos.scanDocumentNames();
    }

    final bodyHits = <SearchHit>[
      for (final row in rows)
        if (_indexOfInsensitive(row.content, term) case final int at when at >= 0)
          _hitFromRow(row, term, at),
    ];

    // A document whose *name* matched is a result even when no block did — the
    // title is part of the text a user searches, and SRS shows the name on every
    // result line anyway. Only added when it is not already covered by a body
    // hit, so one document is not listed twice for one query. The set is built
    // from the hits that **survived** the exact re-check: using the raw SQL
    // rows would let a wildcard false positive (`100` matching `100%`'s LIKE)
    // suppress the title hit and lose the document from the results entirely.
    final bodyIds = bodyHits.map((hit) => hit.documentId).toSet();
    final titleHits = <SearchHit>[
      for (final document in titles)
        if (!bodyIds.contains(document.uuid))
          if (_indexOfInsensitive(document.name, term) >= 0)
            _titleHit(document.uuid, document.name, term),
    ];

    return SearchResults(
      query: term,
      hits: <SearchHit>[...bodyHits, ...titleHits],
    );
  }

  /// How many blocks the case-folding fallback scans when SQL found nothing —
  /// large enough to cover a phone-sized library, small enough that one
  /// keystroke never walks an unbounded table.
  static const int _caseFallbackScanLimit = 2000;

  /// A title match, with the matched run split out exactly like a body match.
  SearchHit _titleHit(String documentId, String name, String term) {
    final at = _indexOfInsensitive(name, term);
    if (at < 0) {
      // Cannot happen for the caller's check, but a title is not worth a crash:
      // `at` indexes the *lower-cased* name, and a few characters change length
      // when case-folded, so the match is re-proved before it is sliced.
      return SearchHit(
        documentId: documentId,
        documentName: name,
        excerptBefore: '',
        match: '',
        excerptAfter: name,
        matchedInTitle: true,
      );
    }
    final end = at + term.length > name.length ? name.length : at + term.length;
    return SearchHit(
      documentId: documentId,
      documentName: name,
      excerptBefore: at > 0 ? name.substring(0, at) : '',
      match: name.substring(at, end),
      excerptAfter: end < name.length ? name.substring(end) : '',
      matchedInTitle: true,
    );
  }

  /// Builds a hit with the matched run kept separate from its surroundings, so
  /// the UI can underline exactly the term without re-finding it in the excerpt.
  ///
  /// The window is asymmetric on purpose: more text after the match than before,
  /// because in Vietnamese prose the words that identify a passage usually follow
  /// the term the reader searched for.
  SearchHit _hitFromRow(BlockSearchRow row, String term, int at) {
    final content = row.content;
    final before = at > _excerptBeforeChars ? at - _excerptBeforeChars : 0;
    // Clamped: `at` comes from the lower-cased content, and case folding is not
    // guaranteed to preserve length. A match must never slice past the string.
    final after = (at + term.length).clamp(0, content.length);
    final afterEnd =
        after + _excerptAfterChars > content.length
            ? content.length
            : after + _excerptAfterChars;
    return SearchHit(
      documentId: row.documentId,
      documentName: row.documentName,
      pageNumber: row.pageNumber,
      blockOrder: row.blockOrder,
      excerptBefore: _clip(content, before, at),
      match: content.substring(at, after),
      excerptAfter: _clip(content, after, afterEnd),
    );
  }

  /// Characters of context kept before the match.
  static const int _excerptBeforeChars = 48;

  /// Characters of context kept after the match.
  static const int _excerptAfterChars = 96;

  static String _clip(String source, int from, int to) {
    if (from >= to || from >= source.length) return '';
    final end = to > source.length ? source.length : to;
    var start = from;
    // Never cut a Vietnamese word in half: a snippet starting mid-syllable is
    // unreadable, and the base letters of a split diacritic are worse.
    while (start < end && _isContinuation(source.codeUnitAt(start))) {
      start++;
    }
    return source.substring(start, end);
  }

  /// A combining mark or a tone-modifier letter that must not begin a snippet.
  static bool _isContinuation(int unit) {
    // Vietnamese tone marks and vowel modifiers sit in the combining ranges, and
    // the precomposed forms are letters in U+1EA0–U+1EF9. Splitting between a
    // base letter and its mark is the specific failure worth preventing.
    return (unit >= 0x0300 && unit <= 0x036F) ||
        (unit >= 0x1AB0 && unit <= 0x1AFF) ||
        (unit >= 0x20D0 && unit <= 0x20FF) ||
        (unit >= 0xFE20 && unit <= 0xFE2F);
  }

  static int _indexOfInsensitive(String haystack, String needle) {
    if (needle.isEmpty) return -1;
    return haystack.toLowerCase().indexOf(needle.toLowerCase());
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

  Document _mapDocument(sql.Document doc) {
    return Document(
      id: doc.uuid,
      name: doc.name,
      source: _enumByName(
        DocumentSource.values,
        doc.source,
        DocumentSource.typedText,
      ),
      mimeType: doc.mimeType,
      originalFileName: doc.originalFileName,
      fileSize: doc.fileSize,
      filePath: doc.filePath,
      status: _enumByName(
        DocumentStatus.values,
        doc.status,
        DocumentStatus.ready,
      ),
      extractedText: doc.extractedText,
      isFavorite: doc.isFavorite,
      category: doc.category,
      createdAt: doc.createdAt,
      updatedAt: doc.updatedAt,
      lastOpenedAt: doc.lastOpenedAt,
      failureMessage: doc.failureMessage,
      metadata: _decodeMetadata(doc.metadata),
    );
  }

  /// Reads a stored enum name, tolerating one this build does not know.
  ///
  /// `values.firstWhere(...)` without an `orElse` throws `StateError` on an
  /// unrecognised name, and a single unreadable row would then make the *whole*
  /// library (or the whole reader) throw with no way out for the user — not even
  /// a delete button, because the list never loads. A name from a newer build, a
  /// downgrade, or a half-written row degrades one field instead of the screen.
  static T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
    if (name == null) return fallback;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  /// Decodes a metadata/payload JSON column.
  ///
  /// A column that is not a JSON object (truncated by a full disk, written by
  /// another build) yields an empty map rather than throwing out of every read
  /// that touches the row.
  static Map<String, Object?> _decodeMetadata(String? raw) {
    if (raw == null || raw.isEmpty) return const <String, Object?>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, Object?>.from(decoded);
    } catch (_) {
      // Deliberately swallowed: metadata is context, never the document.
    }
    return const <String, Object?>{};
  }

  /// The page number a block's `page_id` names (`<documentId>-p3` → `3`).
  ///
  /// Parsed from the trailing `-p` marker, **not** by stripping every non-digit
  /// from the id. A document id is derived from a timestamp (`doc-1759…`), so
  /// stripping digits returned the timestamp followed by the page number — a
  /// number that matches no page. Every image placement compares against this
  /// value, so the wrong number sent every scanned page's picture to the end of
  /// the reader instead of into the flow where it was read.
  static int? _pageNumberFromId(String? pageId) {
    if (pageId == null) return null;
    final marker = pageId.lastIndexOf('-p');
    if (marker < 0) return null;
    return int.tryParse(pageId.substring(marker + 2));
  }

  DocumentBlocksCompanion _blockToCompanion(
    DocumentBlock block,
    String documentId,
    DateTime now, {
    String? pageId,
  }) {
    // An explicit page wins over the caller's own value: `createDocument` derives
    // it from the block's page number so the two can never disagree.
    final resolvedPageId = pageId ?? block.pageId;
    return DocumentBlocksCompanion(
      uuid: Value(block.id),
      documentId: Value(documentId),
      pageId: resolvedPageId != null ? Value(resolvedPageId) : const Value.absent(),
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

  /// The `document_pages` rows implied by the blocks' page numbers.
  ///
  /// Distinct and ordered, because a 40-block page contributes one row, not
  /// forty. A document with no page numbers (typed text, plain `txt`) produces
  /// none — and then it honestly has no pages, rather than one invented page 1.
  List<DocumentPagesCompanion> _pagesForBlocks(
    String documentId,
    DocumentSource source,
    List<DocumentBlock> blocks,
  ) {
    final pageNumbers = <int>{
      for (final block in blocks)
        if (block.position?.pageNumber != null) block.position!.pageNumber!,
    }.toList()
      ..sort();

    final now = DateTime.now();
    return <DocumentPagesCompanion>[
      for (final pageNumber in pageNumbers)
        DocumentPagesCompanion.insert(
          uuid: _pageUuid(documentId, pageNumber),
          documentId: documentId,
          pageNumber: pageNumber,
          sourceType: _pageSourceType(source),
          createdAt: Value(now),
        ),
    ];
  }

  /// The page uuid a block with [pageNumber] belongs to.
  ///
  /// Derived, not stored, on both sides: `createDocument` writes the row and
  /// `search` joins back to it, so the two agree by construction.
  static String _pageUuid(String documentId, int pageNumber) =>
      '$documentId-p$pageNumber';

  String? _pageUuidForBlock(String documentId, DocumentBlock block) {
    final pageNumber = block.position?.pageNumber;
    if (pageNumber == null) return null;
    return _pageUuid(documentId, pageNumber);
  }

  /// What kind of page this is, in the vocabulary SRS §30 uses.
  static String _pageSourceType(DocumentSource source) => switch (source) {
        DocumentSource.camera => 'camera',
        DocumentSource.image => 'imported',
        DocumentSource.pdf => 'pdf',
        DocumentSource.epub => 'epub',
        DocumentSource.typedText ||
        DocumentSource.textFile ||
        DocumentSource.markdown =>
          'text',
      };

  DocumentBlock _mapBlock(sql.DocumentBlock block) {
    return DocumentBlock(
      id: block.uuid,
      documentId: block.documentId,
      pageId: block.pageId,
      type: _enumByName(BlockType.values, block.type, BlockType.unknown),
      level: block.level,
      content: block.content,
      order: block.order,
      position: (block.left != null && block.top != null && block.width != null && block.height != null)
          ? BlockPosition(
              pageNumber: _pageNumberFromId(block.pageId),
              left: block.left,
              top: block.top,
              width: block.width,
              height: block.height,
            )
          : null,
      confidence: block.confidence,
      createdAt: block.createdAt,
      metadata: _decodeMetadata(block.metadata),
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
      sourceType: _enumByName(
        ImageSourceType.values,
        image.sourceType,
        ImageSourceType.imported,
      ),
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
      payload: _decodeMetadata(job.payload),
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