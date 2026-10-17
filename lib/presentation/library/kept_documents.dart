import 'dart:io' show File, Platform;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show immutable, listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/app_log.dart';
import '../../core/storage/app_storage.dart';
import '../../data/providers.dart' show documentRepositoryProvider;
import '../../domain/models/document.dart' show Document, DocumentSource;
import '../../domain/models/document_block.dart' show DocumentBlock;
import '../../domain/models/document_image.dart' show DocumentImage, ImageSourceType;
import '../../domain/models/structured_block.dart' show StructuredBlock;
import '../settings/memory_settings.dart';

/// A document that exists in this session but has not been written to storage yet.
///
/// Phase 5 replaces this with the `documents` / `document_blocks` /
/// `document_images` tables (SRS §30–§31) behind a repository. It lives here, and
/// not in the capture controller, so that when that happens the capture flow keeps
/// calling one method (`add`) and nothing else changes — which is why the sink is
/// a provider rather than a field.
@immutable
class KeptDocument {
  KeptDocument({
    required this.document,
    required this.blocks,
    List<Uint8List> pageImages = const <Uint8List>[],
    int? pageCount,
  })  : pageImages = List<Uint8List>.unmodifiable(pageImages),
        pageCount = pageCount ??
            (pageImages.isEmpty ? 1 : pageImages.length);

  final Document document;

  /// Blocks in reading order, with gapless `order` values across all pages.
  final List<StructuredBlock> blocks;

  /// The untouched page images, one per page, so the reader can show the source
  /// next to the text without re-reading anything.
  ///
  /// **Empty in low-memory mode**, and that costs nothing: nothing in the app
  /// reads these bytes today, so they were a few megabytes per document held for
  /// the whole session for nothing. Kept because the reader is expected to show
  /// the source image beside the text, and because dropping them unconditionally
  /// would take away a capability rather than a cost.
  final List<Uint8List> pageImages;

  /// How many pages this document has.
  ///
  /// A field rather than `pageImages.length`, because the two stop agreeing the
  /// moment the images are released: a 20-page scan whose bytes were dropped is
  /// still a 20-page scan, and the library must keep saying so.
  final int pageCount;

  String get id => document.id;

  /// Lines the OCR engine was not sure about, across the whole document.
  int get lowConfidenceBlockCount =>
      blocks.where((block) => block.isLowConfidence).length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KeptDocument &&
          other.document == document &&
          listEquals(other.blocks, blocks) &&
          other.pageImages.length == pageImages.length);

  @override
  int get hashCode => Object.hash(document, blocks.length, pageImages.length);

  @override
  String toString() =>
      'KeptDocument(${document.id}, ${blocks.length} blocks, $pageCount pages)';
}

/// Session-scoped document list.
class KeptDocuments extends Notifier<List<KeptDocument>> {
  var _sequence = 0;

  @override
  List<KeptDocument> build() => const <KeptDocument>[];

  /// Adds [document] and returns its id, so the caller can navigate to it.
  String add(KeptDocument document) {
    _sequence++;
    state = <KeptDocument>[_retain(document), ...state];
    return document.id;
  }

  /// Drops the page bytes in low-memory mode (NFR-04/NFR-05), keeping the page
  /// count so the document still describes itself correctly.
  ///
  /// The text, the blocks and the document row are untouched: this is the
  /// "không giữ toàn bộ tài liệu trong RAM" half of the setting, and the reason
  /// the toggle can honestly claim to do something.
  KeptDocument _retain(KeptDocument document) {
    if (!ref.read(lowMemoryModeProvider) || document.pageImages.isEmpty) {
      return document;
    }
    return KeptDocument(
      document: document.document,
      blocks: document.blocks,
      pageCount: document.pageCount,
    );
  }

  void remove(String id) {
    state = <KeptDocument>[
      for (final document in state)
        if (document.id != id) document,
    ];
  }

  KeptDocument? byId(String id) {
    for (final document in state) {
      if (document.id == id) return document;
    }
    return null;
  }

  /// How many documents this sequence has created, used to build stable ids.
  int get createdCount => _sequence;
}

final keptDocumentsProvider =
    NotifierProvider<KeptDocuments, List<KeptDocument>>(KeptDocuments.new);

/// Where a kept document ends up for good.
///
/// The in-memory list above is a session convenience for the review screen;
/// this is the write that survives leaving the app. It writes the page images
/// to app-private storage and creates the `documents` / `document_blocks` /
/// `document_images` rows behind the repository, so a captured document shows
/// up in the library and its pages can be shown inline in the reader.
abstract interface class KeptDocumentSink {
  /// Persists [document]. Resolves once the rows and image files are safely on
  /// disk, so the caller can hold navigation until then.
  Future<void> save(KeptDocument document);
}

/// The real sink: page images to `documents/<id>/pages/`, then one transaction
/// for the document and its blocks and images.
class RepositoryKeptDocumentSink implements KeptDocumentSink {
  RepositoryKeptDocumentSink(this._ref);

  final Ref _ref;

  @override
  Future<void> save(KeptDocument kept) async {
    final id = kept.document.id;
    final storage = appStorage;
    final images = <DocumentImage>[];

    // Page images first: the document row may be created even if a file write
    // fails, but an image row pointing at a file that was never written would
    // be a promise the reader cannot keep.
    if (kept.pageImages.isNotEmpty) {
      try {
        await storage.ensureDocumentDirs(id);
        final pagesDir = storage.documentPagesDir(id);
        for (var i = 0; i < kept.pageImages.length; i++) {
          final path =
              '${pagesDir.path}${Platform.pathSeparator}page-${i + 1}.png';
          await File(path).writeAsBytes(kept.pageImages[i], flush: true);
          images.add(DocumentImage(
            id: '$id-img$i',
            documentId: id,
            pageNumber: i + 1,
            sourceType: kept.document.source == DocumentSource.camera
                ? ImageSourceType.camera
                : ImageSourceType.imported,
            filePath: path,
            format: 'png',
            fileSize: kept.pageImages[i].length,
          ));
        }
      } catch (error, stack) {
        // The text is the document; the pictures are context. A failed image
        // write is logged and the document is still saved — losing everything
        // over a full disk would be the worse trade.
        AppLog.error('capture.images.failed', error: error, stackTrace: stack);
      }
    }

    await _ref.read(documentRepositoryProvider).createDocument(
          id: id,
          name: kept.document.name,
          source: kept.document.source,
          mimeType: kept.document.mimeType,
          fileSize: kept.document.fileSize,
          extractedText: kept.document.extractedText,
          status: kept.document.status,
          blocks: <DocumentBlock>[
            for (final block in kept.blocks)
              block.toDocumentBlock(
                id: '$id-b${block.order}',
                documentId: id,
              ),
          ],
          images: images,
          metadata: kept.document.metadata,
        );
    AppLog.info('capture.persisted', data: <String, Object?>{
      'document': id,
      'blocks': kept.blocks.length,
      'images': images.length,
    });
  }
}

final keptDocumentSinkProvider = Provider<KeptDocumentSink>(
  (ref) => RepositoryKeptDocumentSink(ref),
);

/// The most recently kept document, which the reader opens after `Keep text`.
final latestKeptDocumentProvider = Provider<KeptDocument?>(
  (ref) => ref.watch(keptDocumentsProvider).firstOrNull,
);
