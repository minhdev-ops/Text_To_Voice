import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart' show readAloudLocation;
import '../../core/theme/semantic_colors.dart';
import '../../data/providers.dart' show documentRepositoryProvider;
import '../../core/theme/tokens.dart';
import '../../domain/models/search.dart' show SearchHit, SearchResults;
import '../common/empty_state.dart';

/// SRS FR-17 §20: search results as *locations*.
///
/// ```text
/// Document A
/// Page 5
/// "...machine learning..."
/// ```
///
/// Three decisions worth naming:
///
/// * **A hit is a row, not a card.** The library is a ruled list (DESIGN.md) and
///   results are the same content at finer grain; a grid of cards here would
///   contradict the screen the results replace.
/// * **The matched run is a separate span, not a substring to find again.** The
///   repository already knows where it is, and re-locating it in the widget is a
///   second chance to highlight the wrong characters — or, with Vietnamese
///   combining marks, to split a syllable.
/// * **A missing page number says nothing.** A typed-text document has no pages,
///   and printing "Trang ?" would be inventing a fact. The row simply omits it.
class SearchResultsList extends ConsumerWidget {
  const SearchResultsList({super.key, required this.results, required this.term});

  final SearchResults results;
  final String term;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (results.isEmpty) {
      return EmptyState(
        title: 'Không tìm thấy',
        message: 'Không có tài liệu nào chứa "$term".',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: Spacing.s8),
      itemCount: results.hits.length + 1,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == 0) return _Summary(results: results, term: term);
        return _SearchHitRow(hit: results.hits[index - 1]);
      },
    );
  }
}

/// How much was found, in the app's own words.
class _Summary extends StatelessWidget {
  const _Summary({required this.results, required this.term});

  final SearchResults results;
  final String term;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context);
    final locations = results.hits.length;
    final documents = results.documentCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.gutter,
        Spacing.s12,
        Spacing.gutter,
        Spacing.s12,
      ),
      child: Text(
        // A count of documents alone would hide that one document matched in
        // nine places, which is the more useful number when deciding what to
        // open.
        '$locations chỗ trong $documents tài liệu khớp với "$term"',
        style: text.textTheme.bodySmall?.copyWith(
          color: text.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SearchHitRow extends ConsumerWidget {
  const _SearchHitRow({required this.hit});

  final SearchHit hit;

  /// Opens the document **at the passage that matched**.
  ///
  /// A result the user cannot open is a dead end, and opening the document at
  /// its first sentence is nearly as bad: the reader searched for a paragraph.
  /// `blockOrder` is the hit's paragraph, and the reader's paragraph indices are
  /// block indices (one paragraph per text block), so the screen can seek to the
  /// first sentence of it. A title-only hit carries no block and simply opens
  /// the document, resuming where the reader left off.
  void _open(BuildContext context, WidgetRef ref) {
    unawaited(ref.read(documentRepositoryProvider).markOpened(hit.documentId));
    final block = hit.blockOrder;
    context.go(readAloudLocation(
      documentId: hit.documentId,
      block: block,
      // A title-only hit has no passage to land on, so it resumes where the
      // reader left off — which is also what makes a repeat tap act.
      resume: block == null,
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context);
    final semantics = text.colorScheme;
    final accent = Theme.of(context).extension<SemanticColors>()?.accentInk;

    return ListTile(
      onTap: () => _open(context, ref),
      trailing: const Icon(Icons.chevron_right, size: 20),
      // One node per hit, so a screen reader announces "Bản chụp, trang 5,
      // …machine learning…" rather than three disconnected strings.
      title: Text(
        hit.documentName,
        style: text.textTheme.titleSmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (hit.pageNumber != null) ...<Widget>[
            Text(
              'Trang ${hit.pageNumber}',
              style: text.textTheme.labelSmall
                  ?.copyWith(color: semantics.onSurfaceVariant),
            ),
            const SizedBox(height: Spacing.s4),
          ],
          _Excerpt(hit: hit, accent: accent),
        ],
      ),
      isThreeLine: true,
    );
  }
}

/// The line the term was found on, with the match accented.
class _Excerpt extends StatelessWidget {
  const _Excerpt({required this.hit, required this.accent});

  final SearchHit hit;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context);
    final base = text.textTheme.bodyMedium;

    if (hit.matchedInTitle) {
      return Text(
        'Tên tài liệu khớp với từ khoá',
        style: base?.copyWith(color: text.colorScheme.onSurfaceVariant),
      );
    }

    if (hit.match.isEmpty) {
      // The block matched under SQLite's rules but the term could not be located
      // for highlighting. Show the text rather than nothing, and do not fake a
      // highlight.
      return Text(
        hit.excerpt,
        style: base,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Text.rich(
      TextSpan(
        style: base,
        children: <InlineSpan>[
          if (hit.excerptBefore.isNotEmpty) TextSpan(text: hit.excerptBefore),
          TextSpan(
            text: hit.match,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          if (hit.excerptAfter.isNotEmpty) TextSpan(text: hit.excerptAfter),
        ],
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}
