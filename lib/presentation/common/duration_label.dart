/// `4:52`, `1:02:07` — playback times, never a fake-precise decimal.
///
/// Shared by the sentence ruler and the transport bar so the same duration
/// cannot be written two ways in the same bar (DESIGN.md → Voice: consistency
/// through a flow). Rendered with tabular figures by the `utility` text style,
/// so the width does not jitter while audio plays.
String durationLabel(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  final seconds = duration.inSeconds % 60;
  final paddedSeconds = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$paddedSeconds';
  }
  return '$minutes:$paddedSeconds';
}

/// `1.0×`, `1.25×` — the FR-10 speed presets, one decimal except when the value
/// genuinely needs two.
String speedLabel(double speed) {
  final text = speed == speed.roundToDouble()
      ? speed.toStringAsFixed(1)
      : speed.toString();
  return '$text×';
}
