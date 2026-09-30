import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:text_to_voice/core/result/result.dart';
import 'package:text_to_voice/domain/export/wav_merger.dart';

/// A WAV whose samples are all [sample], so a merge can be checked for order
/// and not just for length.
Uint8List wavWithSample(
  int sample, {
  int sampleCount = 8,
  int sampleRate = 24000,
  int channels = 1,
  int bitsPerSample = 16,
  int audioFormat = 1,
}) {
  final bytesPerSample = bitsPerSample ~/ 8;
  final dataBytes = sampleCount * channels * bytesPerSample;
  final bytes = ByteData(44 + dataBytes);

  void ascii(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, audioFormat, Endian.little);
  bytes.setUint16(22, channels, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * channels * bytesPerSample, Endian.little);
  bytes.setUint16(32, channels * bytesPerSample, Endian.little);
  bytes.setUint16(34, bitsPerSample, Endian.little);
  ascii(36, 'data');
  bytes.setUint32(40, dataBytes, Endian.little);

  for (var i = 0; i < dataBytes; i += bytesPerSample) {
    bytes.setInt16(44 + i, sample, Endian.little);
  }
  return bytes.buffer.asUint8List();
}

void main() {
  const merger = WavMerger();

  group('parse', () {
    test('reads the format from the file itself', () {
      final parsed = merger.parse(wavWithSample(0)).valueOrNull!;

      expect(parsed.format.audioFormat, 1);
      expect(parsed.format.channels, 1);
      expect(parsed.format.sampleRate, 24000);
      expect(parsed.format.bitsPerSample, 16);
      expect(parsed.samples.length, 16, reason: '8 samples of 16-bit mono');
    });

    test('computes the duration from the sample count, not from a guess', () {
      final parsed = merger.parse(wavWithSample(0, sampleCount: 24000)).valueOrNull!;

      expect(parsed.format.durationOf(parsed.samples.length).inMilliseconds, 1000);
    });

    test('refuses something that is not a WAV', () {
      final bytes = Uint8List.fromList(List<int>.filled(64, 7).toList());

      final result = merger.parse(bytes);

      expect(result.failureOrNull, isA<ProcessingFailure>());
      expect(result.failureOrNull!.message, contains('không phải định dạng WAV'));
    });

    test('refuses a file whose data chunk is shorter than declared', () {
      final full = wavWithSample(0);
      final truncated = Uint8List.sublistView(full, 0, full.length - 8);

      final result = merger.parse(Uint8List.fromList(truncated));

      expect(result.failureOrNull, isA<ProcessingFailure>());
      expect(result.failureOrNull!.message, contains('thiếu dữ liệu'));
    });

    test('refuses a header that is too short to be a WAV', () {
      final result = merger.parse(Uint8List.fromList(<int>[0x52, 0x49, 0x46, 0x46]));

      expect(result.failureOrNull, isA<ProcessingFailure>());
    });

    test('refuses compressed audio, which cannot be joined by concatenation', () {
      final result = merger.parse(wavWithSample(0, audioFormat: 2));

      expect(result.failureOrNull, isA<ProcessingFailure>());
      expect(result.failureOrNull!.message, contains('không nén'));
    });
  });

  group('merge', () {
    test('joins the samples in the order given', () {
      final first = merger.parse(wavWithSample(1)).valueOrNull!;
      final second = merger.parse(wavWithSample(2)).valueOrNull!;

      final merged = merger.merge(<WavData>[first, second]).valueOrNull!;

      expect(merged.length, 44 + 16 + 16);
      expect(merged[43 + 1] | (merged[43 + 2] << 8), 1, reason: 'first part first');
      expect(merged[59 + 1] | (merged[59 + 2] << 8), 2, reason: 'second part after');
      // A single valid container, ready for a player.
      expect(String.fromCharCodes(merged.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(merged.sublist(8, 12)), 'WAVE');
      expect(String.fromCharCodes(merged.sublist(36, 40)), 'data');
      expect(merged.length - 44, 32);
    });

    test('writes the declared sizes so the file plays as one stream', () {
      final parts = <WavData>[
        merger.parse(wavWithSample(1, sampleCount: 4)).valueOrNull!,
        merger.parse(wavWithSample(2, sampleCount: 12)).valueOrNull!,
      ];

      final merged = merger.merge(parts).valueOrNull!;
      final dataSize = merged[40] |
          (merged[41] << 8) |
          (merged[42] << 16) |
          (merged[43] << 24);

      expect(dataSize, 32, reason: '(4 + 12) samples of 16-bit mono');
      expect(merged.length, 44 + dataSize);
    });

    test('refuses to join different formats and names the difference', () {
      final base = merger.parse(wavWithSample(0)).valueOrNull!;
      final other = merger.parse(wavWithSample(0, sampleRate: 48000)).valueOrNull!;

      final result = merger.merge(<WavData>[base, other]);

      expect(result.failureOrNull, isA<ProcessingFailure>());
      expect(result.failureOrNull!.message, contains('24000Hz'));
      expect(result.failureOrNull!.message, contains('48000Hz'));
    });

    test('refuses an empty export instead of writing a header-only file', () {
      final result = merger.merge(const <WavData>[]);

      expect(result.failureOrNull, isA<ProcessingFailure>());
      expect(result.failureOrNull!.message, contains('Chưa có câu nào'));
    });
  });

  group('size estimate', () {
    test('comes from the measured duration and the actual sample format', () {
      // 4:52 of 24kHz 16-bit mono.
      const duration = Duration(minutes: 4, seconds: 52);

      final bytes = merger.estimateBytes(duration);

      expect(bytes, 44 + 24000 * 2 * 292);
      expect(bytes, greaterThan(14 * 1000 * 1000));
      expect(bytes, lessThan(15 * 1000 * 1000));
    });

    test('scales with the format it is told about', () {
      const duration = Duration(seconds: 10);

      expect(
        merger.estimateBytes(duration, channels: 2),
        merger.estimateBytes(duration) * 2 - 44,
      );
    });
  });
}
