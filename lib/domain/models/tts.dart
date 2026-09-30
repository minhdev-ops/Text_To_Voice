import 'package:flutter/foundation.dart' show immutable;

/// Output container for a synthesized chunk.
enum SpeechFormat {
  /// Phase 1 default. No encoder needed, fully offline (SRS FR-15).
  wav,

  /// Only offered when an on-device encoder is actually present; the UI must
  /// say so rather than silently failing.
  mp3,
}

/// One selectable voice. [license] is not decorative: SRS §47 warns that
/// different checkpoints of the same family carry different terms, so the
/// Model Manager shows exactly this string.
@immutable
class VoicePreset {
  const VoicePreset({
    required this.id,
    required this.label,
    required this.language,
    this.engineId,
    this.license,
    this.isInstalled = false,
    this.sizeBytes = 0,
  });

  final String id;
  final String label;

  /// BCP-47, e.g. `vi-VN`.
  final String language;

  final String? engineId;
  final String? license;
  final bool isInstalled;
  final int sizeBytes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VoicePreset &&
          other.id == id &&
          other.label == label &&
          other.language == language &&
          other.engineId == engineId &&
          other.license == license &&
          other.isInstalled == isInstalled &&
          other.sizeBytes == sizeBytes);

  @override
  int get hashCode => Object.hash(
      id, label, language, engineId, license, isInstalled, sizeBytes);

  @override
  String toString() => 'VoicePreset($id, $label)';
}

/// Everything that changes a synthesis result. Two calls with equal options and
/// equal text must produce the same audio, which is what makes the
/// `text_hash` cache (SRS §32) correct.
@immutable
class TtsOptions {
  const TtsOptions({
    this.voiceId,
    this.speed = 1.0,
    this.volume = 1.0,
    this.format = SpeechFormat.wav,
  });

  /// FR-10 speed presets. Exactly these six — no others in the UI.
  static const List<double> speedPresets = <double>[
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    2.0,
  ];

  static const double minSpeed = 0.5;
  static const double maxSpeed = 2.0;

  final String? voiceId;

  /// Multiplier, clamped to [minSpeed]–[maxSpeed].
  final double speed;

  /// 0..1.
  final double volume;

  final SpeechFormat format;

  TtsOptions copyWith({
    String? voiceId,
    double? speed,
    double? volume,
    SpeechFormat? format,
  }) =>
      TtsOptions(
        voiceId: voiceId ?? this.voiceId,
        speed: (speed ?? this.speed).clamp(minSpeed, maxSpeed),
        volume: (volume ?? this.volume).clamp(0.0, 1.0),
        format: format ?? this.format,
      );

  /// Keys the synthesis cache.
  ///
  /// Includes the voice and the speed, because either one changes the waveform:
  /// a speed change must never be served audio generated at the old speed
  /// (FR-10). It deliberately **excludes [volume]**: volume is applied by the
  /// player, so folding it in would re-synthesize every sentence in a document
  /// for a slider move, which NFR-05 cannot afford.
  String cacheKey(String normalizedText) =>
      '$voiceId|${speed.toStringAsFixed(2)}|${format.name}|$normalizedText';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TtsOptions &&
          other.voiceId == voiceId &&
          other.speed == speed &&
          other.volume == volume &&
          other.format == format);

  @override
  int get hashCode => Object.hash(voiceId, speed, volume, format);

  @override
  String toString() =>
      'TtsOptions($voiceId, ${speed}x, ${(volume * 100).round()}%)';
}

/// What [TtsEngine.synthesize] returns for one sentence.
@immutable
class AudioResult {
  const AudioResult({
    required this.path,
    required this.duration,
    required this.textHash,
    this.sampleRate = 24000,
    this.channels = 1,
    this.voiceId,
    this.speed = 1.0,
    this.cacheHit = false,
  });

  /// Path to the audio file inside app-private storage.
  final String path;

  /// Measured duration, not estimated from text.
  final Duration duration;

  /// Hash of the normalized input text — the SRS §32 cache key.
  final String textHash;

  final int sampleRate;
  final int channels;

  final String? voiceId;
  final double speed;

  /// `true` when this audio came from cache instead of synthesis. Surfaced in
  /// tests so a regression in cache behaviour is visible immediately.
  final bool cacheHit;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AudioResult &&
          other.path == path &&
          other.duration == duration &&
          other.textHash == textHash &&
          other.sampleRate == sampleRate &&
          other.channels == channels &&
          other.voiceId == voiceId &&
          other.speed == speed &&
          other.cacheHit == cacheHit);

  @override
  int get hashCode => Object.hash(
      path, duration, textHash, sampleRate, channels, voiceId, speed, cacheHit);

  @override
  String toString() => 'AudioResult($path, $duration)';
}
