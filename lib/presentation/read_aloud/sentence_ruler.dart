import 'package:flutter/material.dart';

import '../../core/theme/semantic_colors.dart';
import '../../domain/models/reading.dart';

/// The signature scrubber: a **hairline baseline with one tick per sentence**.
///
/// Deliberately not a pill slider (DESIGN.md bans those): it is the Listening
/// Spine in horizontal form — the same idea read sideways — so the two register
/// as one system. Played sentences are inked in accent, the current tick is
/// taller, a sentence still being synthesized is a hollow tick, and a failed
/// sentence is a dashed tick in the danger tone.
///
/// Seeking snaps to sentence boundaries (FR-12): dragging picks the nearest
/// sentence, so text and audio cannot end up mid-word apart.
class SentenceRuler extends StatelessWidget {
  const SentenceRuler({
    super.key,
    required this.sentences,
    required this.currentIndex,
    this.positionInSentence = Duration.zero,
    this.onSeekToSentence,
    this.height = 40,
  });

  final List<Sentence> sentences;
  final int currentIndex;

  /// Offset inside the current sentence, so the inked span moves while a long
  /// sentence is being read instead of jumping tick by tick.
  final Duration positionInSentence;

  final ValueChanged<int>? onSeekToSentence;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semanticColors;
    final total = sentences.length;

    if (total == 0) {
      // Nothing to scrub: a bare baseline, not an empty control pretending to
      // be interactive.
      return SizedBox(
        height: height,
        child: Center(child: Container(height: 1, color: semantic.border)),
      );
    }

    final current = currentIndex.clamp(0, total - 1);
    final sentenceDurationMs = sentences[current].durationMs;
    final fraction = (sentenceDurationMs == null || sentenceDurationMs == 0)
        ? 0.0
        : (positionInSentence.inMilliseconds / sentenceDurationMs).clamp(0.0, 1.0);
    final progress = ((current + fraction) / total).clamp(0.0, 1.0);

    return Semantics(
      slider: true,
      label: 'Vị trí đọc',
      value: _valueLabel(),
      increasedValue: _valueLabel(index: current + 1),
      decreasedValue: _valueLabel(index: current - 1),
      onIncrease: onSeekToSentence == null ? null : () => onSeekToSentence!(current + 1),
      onDecrease: onSeekToSentence == null ? null : () => onSeekToSentence!(current - 1),
      child: LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          // A drag is a sequence of sentence seeks: seeking snaps to sentence
          // boundaries, so a scrub never lands mid-sentence (FR-12).
          onHorizontalDragUpdate: (details) =>
              _seekTo(details.localPosition.dx, constraints.maxWidth),
          onTapDown: (details) =>
              _seekTo(details.localPosition.dx, constraints.maxWidth),
          child: SizedBox(
            height: height,
            child: CustomPaint(
              painter: _RulerPainter(
                sentences: sentences,
                currentIndex: current,
                progress: progress,
                baseline: semantic.border,
                ink: theme.colorScheme.primary,
                pending: semantic.textSubtle,
                failed: semantic.danger,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Maps a horizontal offset to the tick nearest it and asks for that
  /// sentence. Ticks occupy equal shares of the width, so `x / width * total`
  /// is the tick under the finger.
  void _seekTo(double dx, double width) {
    final onSeek = onSeekToSentence;
    final total = sentences.length;
    if (onSeek == null || total == 0 || width <= 0) return;
    final index = ((dx / width) * total).floor().clamp(0, total - 1);
    onSeek(index);
  }

  String _valueLabel({int? index}) {
    final total = sentences.length;
    final current = (index ?? currentIndex).clamp(1, total);
    final elapsed = _positionLabel(index ?? currentIndex);
    final known = sentences.fold<Duration>(
      Duration.zero,
      (sum, s) => sum + Duration(milliseconds: s.durationMs ?? 0),
    );
    return 'Câu $current/$total, $elapsed trên ${_format(known)}';
  }

  String _positionLabel(int index) {
    var total = Duration.zero;
    for (var i = 0; i < index && i < sentences.length; i++) {
      total += Duration(milliseconds: sentences[i].durationMs ?? 0);
    }
    return _format(total);
  }

  static String _format(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _RulerPainter extends CustomPainter {
  _RulerPainter({
    required this.sentences,
    required this.currentIndex,
    required this.progress,
    required this.baseline,
    required this.ink,
    required this.pending,
    required this.failed,
  });

  final List<Sentence> sentences;
  final int currentIndex;
  final double progress;
  final Color baseline;
  final Color ink;
  final Color pending;
  final Color failed;

  @override
  void paint(Canvas canvas, Size size) {
    final total = sentences.length;
    if (total == 0) return;

    final middle = size.height / 2;
    final hairline = Paint()
      ..color = baseline
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, middle), Offset(size.width, middle), hairline);

    // The played span, inked in accent — the same "you are here" idea as the
    // Spine, read horizontally.
    final inked = Paint()
      ..color = ink
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, middle),
      Offset(size.width * progress, middle),
      inked,
    );

    for (var i = 0; i < total; i++) {
      final x = (i + 0.5) * size.width / total;
      final sentence = sentences[i];
      final isCurrent = i == currentIndex;
      final height = isCurrent ? 14.0 : 8.0;

      if (sentence.status == SentenceStatus.failed) {
        _dashedTick(canvas, x, middle, height);
        continue;
      }

      final isReady = sentence.status == SentenceStatus.ready ||
          sentence.status == SentenceStatus.playing ||
          sentence.status == SentenceStatus.played;

      final paint = Paint()
        ..color = isReady ? ink : pending
        ..strokeWidth = isCurrent ? 2 : 1;

      canvas.drawLine(
        Offset(x, middle - height / 2),
        Offset(x, middle + height / 2),
        paint,
      );
    }
  }

  void _dashedTick(Canvas canvas, double x, double middle, double height) {
    final paint = Paint()
      ..color = failed
      ..strokeWidth = 1;
    const dash = 3.0;
    const gap = 2.0;
    var y = middle - height / 2;
    while (y < middle + height / 2) {
      final end = (y + dash).clamp(y, middle + height / 2);
      canvas.drawLine(Offset(x, y), Offset(x, end), paint);
      y = end + gap;
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.currentIndex != currentIndex ||
      old.progress != progress ||
      old.sentences != sentences;
}
