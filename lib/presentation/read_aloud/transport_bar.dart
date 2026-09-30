import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/semantic_colors.dart';
import '../../core/theme/tokens.dart';

/// The sticky transport bar — **audio controls live with the words they
/// control**, which is why this is a bar inside the reader and not a separate
/// full-screen player (the spec removed that screen on purpose).
///
/// Order is fixed: previous sentence · play/pause · next sentence · speed ·
/// voice · times. Play/pause is the single most prominent control, the speed
/// chip is the only pill in the product (DESIGN.md → radius), and every target
/// is at least 48dp.
///
/// Keyboard: focus enters at play/pause and `Space` toggles, so the whole
/// transport is reachable without a pointer.
class TransportBar extends StatelessWidget {
  const TransportBar({
    super.key,
    required this.ruler,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onSpeedTap,
    this.onVoiceTap,
    this.speedLabel = '1.0×',
    this.voiceLabel,
    this.sentenceLabel,
    this.timeLabel,
    this.canGoPrevious = true,
    this.canGoNext = true,
  });

  /// The [SentenceRuler], passed in so the bar stays a layout, not a controller.
  final Widget ruler;

  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onSpeedTap;
  final VoidCallback? onVoiceTap;

  final String speedLabel;
  final String? voiceLabel;

  /// `Câu 12/240` — the position in words, so colour is never the only signal.
  final String? sentenceLabel;

  /// `0:31 / 4:52`, tabular numerals.
  final String? timeLabel;

  final bool canGoPrevious;
  final bool canGoNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semanticColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: semantic.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.s12, Spacing.s4, Spacing.s12, Spacing.s8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ruler,
              const SizedBox(height: Spacing.s4),
              Row(
                children: <Widget>[
                  IconButton(
                    onPressed: canGoPrevious ? onPrevious : null,
                    tooltip: 'Câu trước',
                    icon: const Icon(Icons.skip_previous_outlined),
                  ),
                  _PlayButton(
                    isPlaying: isPlaying,
                    onPressed: onPlayPause,
                    semanticLabel: isPlaying ? 'Tạm dừng' : 'Đọc tiếp',
                  ),
                  IconButton(
                    onPressed: canGoNext ? onNext : null,
                    tooltip: 'Câu sau',
                    icon: const Icon(Icons.skip_next_outlined),
                  ),
                  const SizedBox(width: Spacing.s8),
                  if (sentenceLabel != null)
                    Text(sentenceLabel!, style: theme.utility),
                  const Spacer(),
                  _SpeedChip(label: speedLabel, onTap: onSpeedTap),
                  if (voiceLabel != null) ...<Widget>[
                    const SizedBox(width: Spacing.s8),
                    // Voice is not a pill: only the speed chip earns `full`.
                    TextButton(
                      onPressed: onVoiceTap,
                      child: Text(voiceLabel!, style: theme.utility),
                    ),
                  ],
                  if (timeLabel != null) ...<Widget>[
                    const SizedBox(width: Spacing.s8),
                    Text(timeLabel!, style: theme.utility),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.isPlaying,
    required this.onPressed,
    required this.semanticLabel,
  });

  final bool isPlaying;
  final VoidCallback onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onPressed();
              return null;
            },
          ),
        },
        child: Semantics(
          button: true,
          label: semanticLabel,
          child: Material(
            color: theme.colorScheme.primary,
            shape: RoundedRectangleBorder(borderRadius: RadiusTokens.mdBorder),
            child: InkWell(
              onTap: onPressed,
              child: SizedBox(
                // 56dp: the most important control is also the largest target.
                width: 56,
                height: Layout.minTouchTarget,
                child: Icon(
                  isPlaying ? Icons.pause_outlined : Icons.play_arrow_outlined,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The one pill in the product (DESIGN.md → radius: only the speed chip and the
/// circular play button take `full`). Tabular numerals so `1.0×` does not jitter
/// as the value changes.
class _SpeedChip extends StatelessWidget {
  const _SpeedChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: 'Tốc độ đọc, $label',
      child: Material(
        color: theme.semanticColors.accentWash,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: Layout.minTouchTarget),
            padding: const EdgeInsets.symmetric(horizontal: Spacing.s16),
            alignment: Alignment.center,
            child: Text(
              label,
              style: theme.utility.copyWith(
                color: theme.semanticColors.accentInk,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
