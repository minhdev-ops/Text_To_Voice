import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show immutable, listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/document.dart' show Document;
import '../../domain/models/structured_block.dart' show StructuredBlock;

/// A document that exists in this session but has not been written to storage yet.
///
/// Phase 5 replaces this with the `documents` / `document_blocks` /
/// `document_images` tables (SRS §30–§31) behind a repository. It lives here, and
/// not in the capture controller, so that when that happens the capture flow keeps
/// calling one method (`add`) and nothing else changes — which is why the sink is
/// a provider rather than a field.
@immutable
class KeptDocument {
  const KeptDocument({
    required this.document,
    required this.blocks,
    this.pageImages = const <Uint8List>[],
  });

  final Document document;

  /// Blocks in reading order, with gapless `order` values across all pages.
  final List<StructuredBlock> blocks;

  /// The untouched page images, one per page, so the reader can show the source
  /// next to the text without re-reading anything.
  final List<Uint8List> pageImages;

  String get id => document.id;

  int get pageCount => pageImages.isEmpty ? 1 : pageImages.length;

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
    state = <KeptDocument>[document, ...state];
    return document.id;
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

/// The most recently kept document, which the reader opens after `Keep text`.
final latestKeptDocumentProvider = Provider<KeptDocument?>(
  (ref) => ref.watch(keptDocumentsProvider).firstOrNull,
);
