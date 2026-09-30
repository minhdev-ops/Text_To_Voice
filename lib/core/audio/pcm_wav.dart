import 'dart:typed_data';

/// Serializes a float waveform as a 16-bit PCM WAV container.
///
/// One function, no encoder, no options: WAV is the only format this app can
/// produce fully offline (FR-15), and the model already emits exactly the shape
/// it needs — mono, 48 kHz, `float32` in `[-1, 1]`.
///
/// Samples are clamped before conversion rather than scaled down: a codec can
/// overshoot `1.0`, and clamping keeps the loudness the model produced instead of
/// making the whole sentence quieter to accommodate one peak.
Uint8List pcm16WavBytes(
  Float32List samples, {
  required int sampleRate,
  int channels = 1,
}) {
  const headerBytes = 44;
  final dataBytes = samples.length * 2;
  final output = Uint8List(headerBytes + dataBytes);
  final view = ByteData.view(output.buffer);

  void ascii(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      output[offset + i] = value.codeUnitAt(i);
    }
  }

  final byteRate = sampleRate * channels * 2;
  final blockAlign = channels * 2;

  ascii(0, 'RIFF');
  view.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, 1, Endian.little); // PCM
  view.setUint16(22, channels, Endian.little);
  view.setUint32(24, sampleRate, Endian.little);
  view.setUint32(28, byteRate, Endian.little);
  view.setUint16(32, blockAlign, Endian.little);
  view.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  view.setUint32(40, dataBytes, Endian.little);

  for (var i = 0; i < samples.length; i++) {
    final value = samples[i];
    final clamped = value.isNaN ? 0.0 : (value < -1.0 ? -1.0 : (value > 1.0 ? 1.0 : value));
    view.setInt16(headerBytes + i * 2, (clamped * 32767).round(), Endian.little);
  }
  return output;
}
