import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/semantic_colors.dart';
import '../../core/theme/tokens.dart';
import '../../domain/models/tts.dart' show TtsOptions;
import '../common/duration_label.dart';

/// The six FR-10 speeds, in a sheet rather than inline: six choices on the
/// transport bar would turn a control surface into a menu (DESIGN.md →
/// cognitive load).
///
/// A ruled list, not cards — the same list family as the library and the model
/// manager. The active value is marked by a check **and** by weight, so the mark
/// survives grayscale.
class SpeedSheet extends StatelessWidget {
  const SpeedSheet({super.key, required this.current});

  final double current;

  /// Opens the sheet and resolves to the chosen speed, or `null` if dismissed.
  static Future<double?> show(BuildContext context, {required double current}) =>
      showModalBottomSheet<double>(
        context: context,
        showDragHandle: true,
        builder: (context) => SpeedSheet(current: current),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.s20, Spacing.s8, Spacing.s20, Spacing.s12),
            child: Text('Tốc độ đọc', style: theme.textTheme.titleMedium),
          ),
          // Scrollable: a bottom sheet on a short screen must not clip the last
          // two presets, and the values are the point of this sheet.
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: TtsOptions.speedPresets.length,
              itemBuilder: (context, index) {
                final speed = TtsOptions.speedPresets[index];
                return ListTile(
                  // Rows are square and ruled, like every other list here.
                  shape:
                      const RoundedRectangleBorder(borderRadius: RadiusTokens.row),
                  minVerticalPadding: Spacing.s16,
                  title: Text(
                    speedLabel(speed),
                    style: theme.utility.copyWith(
                      fontSize: TypeScale.bodyLarge,
                      fontWeight:
                          speed == current ? FontWeight.w600 : FontWeight.w500,
                      color: speed == current
                          ? theme.semanticColors.accentInk
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  trailing: speed == current
                      ? Icon(Icons.check, color: theme.colorScheme.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(speed),
                );
              },
            ),
          ),
          const SizedBox(height: Spacing.s8),
        ],
      ),
    );
  }
}
