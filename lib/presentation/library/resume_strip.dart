import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart' show readAloudLocation;
import '../../core/theme/app_theme.dart';
import '../../core/theme/semantic_colors.dart';
import '../../core/theme/tokens.dart';
import '../../data/providers.dart';
import '../../domain/models/document.dart' show Document;
import '../../domain/models/reading.dart';

/// Resume strip shown at the top of Library when there's a reading position to continue.
///
/// "Continue reading?" with Continue / Start over — the only card in the product
/// (DESIGN.md bans cards everywhere except this one).
class ResumeStrip extends ConsumerWidget {
  const ResumeStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positionAsync = ref.watch(latestReadingPositionProvider);

    return positionAsync.when(
      data: (position) {
        if (position == null) return const SizedBox.shrink();
        return _ResumeStripCard(position: position);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Provider for the latest reading position across all documents.
final latestReadingPositionProvider = FutureProvider<ReadingPosition?>((ref) async {
  final repo = ref.watch(documentRepositoryProvider);
  return repo.getLatestReadingPosition();
});

/// Card widget for the resume strip.
class _ResumeStripCard extends ConsumerWidget {
  const _ResumeStripCard({required this.position});

  final ReadingPosition position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.semanticColors;
    final repo = ref.watch(documentRepositoryProvider);

    return FutureBuilder<Document?>(
      future: repo.getDocumentById(position.documentId),
      builder: (context, snapshot) {
        final doc = snapshot.data;
        if (doc == null || !doc.hasText) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.all(Spacing.gutter),
          padding: const EdgeInsets.all(Spacing.s16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(RadiusTokens.lg),
            border: Border.all(color: semantic.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history, size: 20, color: semantic.accentInk),
                  const SizedBox(width: Spacing.s8),
                  Text('Tiếp tục đọc?', style: theme.textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: Spacing.s8),
              Text(
                doc.name,
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: Spacing.s4),
              Text(
                _positionLabel(position),
                style: theme.utility.copyWith(color: semantic.textSubtle),
              ),
              const SizedBox(height: Spacing.s12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        repo.deleteReadingPosition(doc.id);
                        repo.markOpened(doc.id);
                        // The strip is built from a snapshot of the saved
                        // position: without this it keeps offering a place the
                        // user has just chosen to abandon.
                        ref.invalidate(latestReadingPositionProvider);
                        // `fromStart` as well as the deleted position: the reader
                        // is kept alive in its own tab, and its text is still on
                        // screen, so a plain navigation was ignored and the
                        // reading carried on from the sentence it had reached.
                        context.go(readAloudLocation(
                          documentId: doc.id,
                          fromStart: true,
                        ));
                      },
                      child: const Text('Đọc từ đầu'),
                    ),
                  ),
                  const SizedBox(width: Spacing.s12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        repo.markOpened(doc.id);
                        context.go(readAloudLocation(
                          documentId: doc.id,
                          resume: true,
                        ));
                      },
                      child: const Text('Tiếp tục'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _positionLabel(ReadingPosition position) {
    final parts = <String>[];
    if (position.pageNumber != null) {
      parts.add('Trang ${position.pageNumber}');
    }
    final blockId = position.blockId;
    if (blockId != null && blockId.isNotEmpty) {
      // Shortened for the strip, but only as far as the id actually goes: a
      // hard `substring(0, 8)` throws on a short id, and a crash while painting
      // the resume strip is the worst possible place for one.
      final short = blockId.length > 8 ? blockId.substring(0, 8) : blockId;
      parts.add('Đoạn $short');
    }
    parts.add('Câu ${position.sentenceIndex + 1}');
    if (position.positionMs > 0) {
      final mins = position.positionMs ~/ 60000;
      final secs = (position.positionMs % 60000) ~/ 1000;
      parts.add('${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}');
    }
    return parts.join(' · ');
  }
}