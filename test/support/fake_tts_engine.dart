import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:text_to_voice/core/result/result.dart';
import 'package:text_to_voice/domain/engines/tts_engine.dart';
import 'package:text_to_voice/domain/models/tts.dart';

/// A [TtsEngine] that synthesizes nothing but is honest about it.
///
/// Phase 1's real engine is `VieNeuOnnxTtsEngine` (ONNX + a model file that is
/// not in the repository). Every rule the app must obey — start on sentence 1,
/// never re-synthesize cached text, skip a failed sentence, apply a speed change
/// from the next sentence — is enforced by the *queue and session*, not by the
/// model, so those rules are tested against this instead (Phase 1 risk
/// mitigation in `document/ROADMAP.md`).
///
/// By default audio is only described, never written; pass [directory] to get
/// real WAV files on disk, which is what the end-to-end test needs.
class FakeTtsEngine implements TtsEngine {
  FakeTtsEngine({
    this.directory,
    Set<String>? failingTexts,
    this.latency = Duration.zero,
    this.sampleRate = 24000,
    this.millisecondsPerCharacter = 40,
  }) : failingTexts = failingTexts ?? <String>{};


  /// Where WAV files are written. `null` keeps everything in memory.
  final Directory? directory;

  /// Sentences whose synthesis must fail, to exercise the skip path. Mutable so
  /// a test can clear it and prove that a retry succeeds.
  final Set<String> failingTexts;

  /// Simulated model latency, so tests can observe look-ahead behaviour.
  /// Mutable: a test can make one pass slow and the next pass fast.
  Duration latency;

  final int sampleRate;

  /// Crude but deterministic duration model: N characters ≈ N × this at `1.0x`.
  final int millisecondsPerCharacter;

  /// Every text handed to [synthesize], in order. Asserting on this is how the
  /// tests prove that a repeated read does not re-synthesize (SRS §32).
  final List<String> synthesizedTexts = <String>[];

  /// Speed used for each call, in the same order as [synthesizedTexts], so a
  /// test can prove that audio after a speed change was made at the new rate.
  final List<double> synthesizedSpeeds = <double>[];

  int get synthesizeCalls => synthesizedTexts.length;

  /// `isReady` is settable so the "model not installed" path is testable.
  bool ready = true;

  @override
  String get id => 'fake-tts';

  @override
  String get displayName => 'Fake TTS (test only)';

  @override
  bool get isReady => ready;

  @override
  Future<Result<AudioResult>> synthesize(String text, TtsOptions options) async {
    synthesizedTexts.add(text);
    synthesizedSpeeds.add(options.speed);

    if (latency > Duration.zero) await Future<void>.delayed(latency);

    if (!ready) {
      return const Result<AudioResult>.failure(ModelUnavailableFailure(
        message: 'Model đọc tiếng Việt chưa được cài đặt.',
        modelId: 'vieneu-tts',
      ));
    }
    if (failingTexts.contains(text)) {
      return Result<AudioResult>.failure(ProcessingFailure(
        message: 'Không tổng hợp được câu này.',
        detail: 'fake engine was told to fail',
      ));
    }

    final ms = (text.length * millisecondsPerCharacter / options.speed).round();
    final duration = Duration(milliseconds: ms);
    final bytes = buildWav(
      sampleCount: (sampleRate * duration.inMilliseconds / 1000).round().clamp(1, 1 << 30),
      sampleRate: sampleRate,
    );

    final path = directory == null
        ? 'memory://tts/${_slug(text)}-${options.speed}.wav'
        : await _write(bytes, text, options);

    return Result<AudioResult>.success(AudioResult(
      path: path,
      duration: duration,
      textHash: options.cacheKey(text),
      sampleRate: sampleRate,
      voiceId: options.voiceId,
      speed: options.speed,
    ));
  }

  @override
  Future<void> close() async {}

  Future<String> _write(Uint8List bytes, String text, TtsOptions options) async {
    await directory!.create(recursive: true);
    final file = File(
      '${directory!.path}/${_slug(text)}-${options.speed}-${bytes.length}.wav',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static String _slug(String text) {
    var hash = 0x811C9DC5;
    for (var i = 0; i < text.length; i++) {
      hash ^= text.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }
}

/// A real 16-bit PCM mono WAV of silence with a valid 44-byte header.
///
/// Real bytes rather than a placeholder string, so the export test can assert
/// on the header and a player would genuinely accept the file (FR-15).
Uint8List buildWav({required int sampleCount, required int sampleRate}) {
  const int channels = 1;
  const int bitsPerSample = 16;
  final int dataBytes = sampleCount * channels * (bitsPerSample ~/ 8);
  final int byteRate = sampleRate * channels * (bitsPerSample ~/ 8);

  final bytes = ByteData(44 + dataBytes);
  void writeAscii(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  writeAscii(0, 'RIFF');
  bytes.setUint32(4, 36 + dataBytes, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little); // PCM chunk size
  bytes.setUint16(20, 1, Endian.little); // PCM, uncompressed
  bytes.setUint16(22, channels, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, byteRate, Endian.little);
  bytes.setUint16(32, channels * (bitsPerSample ~/ 8), Endian.little);
  bytes.setUint16(34, bitsPerSample, Endian.little);
  writeAscii(36, 'data');
  bytes.setUint32(40, dataBytes, Endian.little);
  // Samples stay zero: silence is the honest output of an engine that is not
  // loaded, and the tests assert on structure, never on the waveform.
  return bytes.buffer.asUint8List();
}
