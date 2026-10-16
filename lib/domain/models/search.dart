import 'package:flutter/foundation.dart' show immutable;

/// One place a search term was found — SRS FR-17 §20.
///
/// The SRS result is not "a document that matches", it is a **location**:
///
/// ```text
/// Document A
/// Page 5
/// "...machine learning..."
/// ```
///
/// so a hit carries the document, the page it was found on, and the sentence
/// around the match. Returning whole documents — which is all this app could do
/// before — answers "does it exist somewhere" but not "show me where", and makes
/// the user open every candidate to find the one line they wanted.
@immutable
class SearchHit {
  const SearchHit({
    required this.documentId,
    required this.documentName,
    required this.excerptBefore,
    required this.match,
    required this.excerptAfter,
    this.pageNumber,
    this.blockOrder,
    this.matchedInTitle = false,
  });

  /// The `documents.uuid` the hit belongs to, so a tap can open that document.
  final String documentId;

  final String documentName;

  /// `null` when the block has no page — a typed-text document has none, and
  /// inventing "page 1" would be a number the app does not actually know.
  final int? pageNumber;

  /// Reading position of the block within the document, for a jump target.
  final int? blockOrder;

  /// The text before the match, for context. May be empty.
  final String excerptBefore;

  /// The matched text, exactly as it appears in the document.
  final String match;

  /// The text after the match. May be empty.
  final String excerptAfter;

  /// `true` when the document's **name** matched rather than its body, so the UI
  /// can say so instead of inventing an excerpt that is really the title.
  final bool matchedInTitle;

  /// The whole line, for a one-line fallback or an accessibility label.
  String get excerpt => '$excerptBefore$match$excerptAfter';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchHit &&
          other.documentId == documentId &&
          other.pageNumber == pageNumber &&
          other.blockOrder == blockOrder &&
          other.excerpt == excerpt &&
          other.matchedInTitle == matchedInTitle);

  @override
  int get hashCode =>
      Object.hash(documentId, pageNumber, blockOrder, excerpt, matchedInTitle);

  @override
  String toString() =>
      'SearchHit($documentName p$pageNumber "$excerpt")';
}

/// Search results, grouped the way SRS FR-17 shows them.
@immutable
class SearchResults {
  const SearchResults({required this.hits, required this.query});

  final List<SearchHit> hits;

  /// The term that produced these hits, echoed so the UI can say what it found
  /// rather than re-deriving it from a text field that may have moved on.
  final String query;

  bool get isEmpty => hits.isEmpty;

  int get documentCount => hits.map((hit) => hit.documentId).toSet().length;

  /// One group per document, in first-hit order.
  ///
  /// Grouping is presentation, not filtering: the same document found on four
  /// pages is four useful locations, not four documents.
  Map<String, List<SearchHit>> get byDocument {
    final grouped = <String, List<SearchHit>>{};
    for (final hit in hits) {
      grouped.putIfAbsent(hit.documentId, () => <SearchHit>[]).add(hit);
    }
    return grouped;
  }
}
