import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/semantic_colors.dart';
import '../../core/theme/tokens.dart';
import '../../domain/models/reading.dart';

/// One sentence of the reading surface, with the **Listening Spine**.
///
/// The Spine is the product's signature (DESIGN.md → Signature): the sentence
/// currently being synthesized or spoken is marked by a 3px verdigris rule in
/// the left margin plus a very low-chroma accent wash behind it. It is the only
/// place boldness is spent, so nothing else here competes with it.
///
/// The full state machine is rendered, not just the happy path: a sentence that
/// is still being synthesized, one that has been spoken, and one that failed
/// all look different *without* colour being the only signal — the failed
/// sentence carries a warning-toned hairline and a `Retry` affordance.
class SentenceBlock extends StatelessWidget {
  const SentenceBlock({
    super.key,
    required this.sentence,
    required this.isCurrent,
    this.onTap,
    this.onRetry,
  });

  /// Sentence text for display. Phase 1's read-aloud tab shows the user's own
  /// typing, so nothing here re-writes it.
  final Sentence sentence;

  /// `true` when this is the sentence the Spine is on (playing or synthesizing).
  final bool isCurrent;

  final VoidCallback? onTap;

  /// Only rendered for a failed sentence — the banner offers it too, but a
  /// reader looking at the sentence should not have to hunt for the control.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semanticColors;
    final status = sentence.status;

    final isFailed = status == SentenceStatus.failed;
    final isPlayed = status == SentenceStatus.played;
    final isSynthesizing = status == SentenceStatus.synthesizing;

    final textColor = isPlayed ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final spineMotion = reduceMotion ? Duration.zero : Motion.base;

    return Semantics(
      // One node per sentence, announced with its own text: the Spine is never
      // the only signal (DESIGN.md → accessibility contract).
      label: sentence.text,
      hint: 'Nhấn để đọc từ câu này',
      selected: isCurrent,
      button: onTap != null,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: spineMotion,
          curve: Motion.standard,
          color: isCurrent ? semantic.accentWash : Colors.transparent,
          // IntrinsicHeight gives the row a bounded height so the Spine rule
          // can stretch the full height of the sentence; a list item has no
          // height of its own to stretch against.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // The Spine rule. Kept in the tree when inactive (transparent)
                // so text does not shift sideways as playback advances.
                AnimatedContainer(
                  duration: spineMotion,
                  curve: Motion.standard,
                  width: 3,
                  color: isCurrent && !isFailed
                      ? semantic.spineRule
                      : Colors.transparent,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.s12,
                      vertical: Spacing.s8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          sentence.text,
                          style: theme.reading.copyWith(color: textColor),
                        ),
                        // Preparing is a state with a potentially long wait
                        // (first load + synthesis), so it says so in words —
                        // a hairline alone is not a signal (FR-09 usability).
                        if (isSynthesizing)
                          Padding(
                            padding: const EdgeInsets.only(top: Spacing.s8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const SizedBox(
                                  width: Spacing.s16,
                                  height: Spacing.s16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: Spacing.s8),
                                Text(
                                  'Đang chuẩn bị câu…',
                                  style: theme.utility,
                                ),
                              ],
                            ),
                          ),
                        if (isSynthesizing || isFailed)
                          Padding(
                            padding: const EdgeInsets.only(top: Spacing.s4),
                            child: _Underline(
                              color: isFailed
                                  ? semantic.danger
                                  : semantic.textSubtle,
                            ),
                          ),
                        if (isFailed && sentence.failureMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: Spacing.s4),
                            child: Row(
                              children: <Widget>[
                                Flexible(
                                  child: Text(
                                    sentence.failureMessage!,
                                    style: theme.utility
                                        .copyWith(color: semantic.danger),
                                  ),
                                ),
                                if (onRetry != null) ...<Widget>[
                                  const SizedBox(width: Spacing.s8),
                                  TextButton(
                                    onPressed: onRetry,
                                    child: const Text('Đọc lại câu này'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The 1px hairline that marks a sentence as `synthesizing` or `failed`.
///
/// A hairline rather than a coloured block: a block would shout, and the
/// Listening Spine is the element allowed to be loud (DESIGN.md → Signature).
class _Underline extends StatelessWidget {
  const _Underline({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        width: double.infinity,
        color: color,
      );
}
