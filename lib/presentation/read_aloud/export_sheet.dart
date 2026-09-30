import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/semantic_colors.dart';
import '../../core/theme/tokens.dart';
import '../../domain/export/document_export_service.dart';
import '../../domain/export/text_exporter.dart';
import '../../domain/export/wav_merger.dart';
import '../../domain/models/reading.dart';
import '../common/duration_label.dart';

/// What the user asked to write.
@immutable
class ExportSelection {
  const ExportSelection({required this.formats, required this.includeAudio});

  final Set<TextExportFormat> formats;
  final bool includeAudio;

  bool get isEmpty => formats.isEmpty && !includeAudio;
}

/// The export sheet: a ruled list, one row per artifact.
///
/// Multi-select rather than a menu of single choices, because "give me the text
/// and the audio" is one intention. MP3 is **absent with a reason** rather than
/// silently missing: FR-15 says WAV comes first and `mp3` only if an on-device
/// encoder exists, and a user who cannot find MP3 deserves to know why.
class ExportSheet extends StatefulWidget {
  const ExportSheet({super.key, required this.sentences});

  final List<Sentence> sentences;

  static Future<ExportSelection?> show(
    BuildContext context, {
    required List<Sentence> sentences,
  }) =>
      showModalBottomSheet<ExportSelection>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => ExportSheet(sentences: sentences),
      );

  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  final Set<TextExportFormat> _formats = <TextExportFormat>{TextExportFormat.txt};
  late bool _includeAudio = _hasAudio;

  static const WavMerger _merger = WavMerger();

  bool get _hasAudio =>
      widget.sentences.any((sentence) => sentence.audioPath != null);

  Duration get _audioDuration =>
      DocumentExportService.measuredDuration(widget.sentences);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semanticColors;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.s20, Spacing.s8, Spacing.s20, Spacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Xuất tài liệu', style: theme.textTheme.titleMedium),
                const SizedBox(height: Spacing.s2),
                Text(
                  'Tệp được lưu trong bộ nhớ riêng của ứng dụng.',
                  style: theme.utility,
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                for (final format in TextExportFormat.values)
                  CheckboxListTile(
                    value: _formats.contains(format),
                    onChanged: (selected) => setState(() {
                      if (selected ?? false) {
                        _formats.add(format);
                      } else {
                        _formats.remove(format);
                      }
                    }),
                    title: Text(format.label, style: theme.textTheme.bodyMedium),
                    controlAffinity: ListTileControlAffinity.leading,
                    shape: const RoundedRectangleBorder(borderRadius: RadiusTokens.row),
                  ),
                CheckboxListTile(
                  value: _includeAudio,
                  // Disabled while no sentence has audio yet, with the reason
                  // underneath rather than an unresponsive control.
                  onChanged: _hasAudio
                      ? (selected) => setState(() => _includeAudio = selected ?? false)
                      : null,
                  title: Text('Audio (.wav)', style: theme.textTheme.bodyMedium),
                  subtitle: Text(
                    _hasAudio
                        ? '≈ ${_megabytes(_merger.estimateBytes(_audioDuration))} '
                            '· ${durationLabel(_audioDuration)} đã tạo'
                        : 'Chưa có câu nào được tạo audio.',
                    style: theme.utility,
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  shape: const RoundedRectangleBorder(borderRadius: RadiusTokens.row),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Spacing.s20, Spacing.s8, Spacing.s20, Spacing.s4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.info_outline, size: Spacing.s20, color: semantic.info),
                      const SizedBox(width: Spacing.s12),
                      Expanded(
                        child: Text(
                          // The honest version of "no MP3": the format needs an
                          // encoder the device does not have, so WAV is what can
                          // be produced fully offline.
                          'Chưa có bộ mã hoá MP3 trên máy. WAV không cần mã hoá nên '
                          'xuất được hoàn toàn ngoại tuyến.',
                          style: theme.utility,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.gutter, Spacing.s8, Spacing.gutter, Spacing.s16),
            child: FilledButton(
              onPressed: _formats.isEmpty && !_includeAudio
                  ? null
                  : () => Navigator.of(context).pop(
                        ExportSelection(
                          formats: _formats,
                          includeAudio: _includeAudio,
                        ),
                      ),
              child: const Text('Xuất'),
            ),
          ),
        ],
      ),
    );
  }

  static String _megabytes(int bytes) {
    final mb = bytes / (1000 * 1000);
    // One decimal: the estimate is honest to that precision and no further.
    return '${mb.toStringAsFixed(1)} MB';
  }
}
