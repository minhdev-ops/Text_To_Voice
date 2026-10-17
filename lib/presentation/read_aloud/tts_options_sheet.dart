import 'package:flutter/material.dart';

import '../../ai/tts/vieneu_voices.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/semantic_colors.dart';
import '../../core/theme/tokens.dart';
import '../../domain/models/tts.dart' show TtsOptions;
import '../common/duration_label.dart' show speedLabel;

/// Voice, speed and volume in one sheet, reachable from the transport bar
/// mid-read.
///
/// Replaces the old speed-only sheet: "điều chỉnh giọng đọc" is a request to
/// change *who* is speaking while the document is open, not a trip into
/// Settings — so the voice list lives beside the speed presets it used to sit
/// next to, and one "Xong" applies the whole set.
///
/// Edits are local until confirmed: a voice half-chosen is not a voice being
/// spoken, and dismissing the sheet cancels the change instead of leaving the
/// document half re-synthesized.
class TtsOptionsSheet extends StatefulWidget {
  const TtsOptionsSheet({
    super.key,
    required this.current,
    required this.voices,
  });

  final TtsOptions current;
  final VieNeuVoiceCatalog voices;

  /// Opens the sheet and resolves to the confirmed options, or `null` when
  /// dismissed without confirming.
  static Future<TtsOptions?> show(
    BuildContext context, {
    required TtsOptions current,
    required VieNeuVoiceCatalog voices,
  }) =>
      showModalBottomSheet<TtsOptions>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => TtsOptionsSheet(current: current, voices: voices),
      );

  @override
  State<TtsOptionsSheet> createState() => _TtsOptionsSheetState();
}

class _TtsOptionsSheetState extends State<TtsOptionsSheet> {
  late String? _voiceId = _effectiveVoiceId;
  late double _speed = widget.current.speed;
  late double _volume = widget.current.volume;

  /// The voice currently in force: the chosen one, or the catalog's own
  /// default when the document has never picked one.
  String? get _effectiveVoiceId =>
      widget.current.voiceId ?? _catalog.defaultVoiceId;

  VieNeuVoiceCatalog get _catalog => widget.voices;

  void _commit() =>
      Navigator.of(context).pop(TtsOptions(
        voiceId: _voiceId,
        speed: _speed,
        volume: _volume,
        format: widget.current.format,
      ));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semanticColors;

    return SafeArea(
      child: ConstrainedBox(
        // Tall enough to breathe, short enough that the drag handle and the
        // confirm button stay reachable one-handed.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.s20,
                Spacing.s8,
                Spacing.s20,
                Spacing.s4,
              ),
              child: Text('Giọng đọc & tốc độ', style: theme.textTheme.titleMedium),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: Spacing.s8),
                children: <Widget>[
                  _SectionLabel('Giọng đọc'),
                  if (_catalog.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Spacing.s20, 0, Spacing.s20, Spacing.s12),
                      child: Text(
                        'Chưa có giọng đọc nào trong danh mục.',
                        style: theme.utility,
                      ),
                    )
                  else
                    for (final voice in _catalog.voices)
                      ListTile(
                        shape: const RoundedRectangleBorder(
                          borderRadius: RadiusTokens.row,
                        ),
                        title: Text(
                          voice.label,
                          style: theme.utility.copyWith(
                            fontSize: TypeScale.bodyLarge,
                            fontWeight: voice.id == _voiceId
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: voice.id == _voiceId
                                ? semantic.accentInk
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        subtitle: voice.subtitle.isEmpty
                            ? null
                            : Text(voice.subtitle, style: theme.utility),
                        trailing: voice.id == _voiceId
                            ? Icon(Icons.check, color: theme.colorScheme.primary)
                            : null,
                        onTap: () => setState(() => _voiceId = voice.id),
                      ),
                  _SectionLabel('Tốc độ'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.s16),
                    child: Wrap(
                      spacing: Spacing.s8,
                      runSpacing: Spacing.s8,
                      children: <Widget>[
                        for (final speed in TtsOptions.speedPresets)
                          _SpeedChip(
                            label: speedLabel(speed),
                            selected: speed == _speed,
                            onTap: () => setState(() => _speed = speed),
                          ),
                      ],
                    ),
                  ),
                  _SectionLabel('Âm lượng'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.s8),
                    child: Slider(
                      value: _volume.clamp(0.0, 1.0),
                      divisions: 10,
                      label: '${(_volume * 100).round()}%',
                      onChanged: (value) => setState(() => _volume = value),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.s20, Spacing.s8, Spacing.s20, Spacing.s12),
              child: FilledButton(
                onPressed: _commit,
                child: const Text('Xong'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A right-aligned section title, set small and quiet so the choices dominate.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.s20, Spacing.s12, Spacing.s20, Spacing.s4),
      child: Text(
        text.toUpperCase(),
        style: theme.utility.copyWith(
          fontSize: 12,
          letterSpacing: 0.6,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// One speed preset. A chip, not a list row: six rows for six numbers pushed
/// the voice list — the reason this sheet exists — below the fold.
class _SpeedChip extends StatelessWidget {
  const _SpeedChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semanticColors;

    return Semantics(
      button: true,
      selected: selected,
      label: 'Tốc độ $label',
      child: Material(
        color: selected ? semantic.accentWash : theme.colorScheme.surfaceContainerHigh,
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
                color: selected ? semantic.accentInk : theme.colorScheme.onSurface,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
