import 'dart:typed_data';

import '../../core/result/result.dart';

/// The audio format of a WAV file, as declared by its own `fmt ` chunk.
///
/// Read from the bytes rather than assumed: the app must refuse to stitch two
/// files together when their formats differ, and it cannot know that from a file
/// extension.
class WavFormat {
  const WavFormat({
    required this.audioFormat,
    required this.channels,
    required this.sampleRate,
    required this.bitsPerSample,
  });

  /// 1 = uncompressed PCM, 3 = IEEE float. Anything else is refused: this
  /// merger concatenates samples, which is only valid for uncompressed data.
  final int audioFormat;

  final int channels;
  final int sampleRate;
  final int bitsPerSample;

  int get bytesPerSample => bitsPerSample ~/ 8;

  int get byteRate => sampleRate * channels * bytesPerSample;

  Duration durationOf(int dataBytes) =>
      Duration(milliseconds: (dataBytes * 1000 / byteRate).round());

  bool isCompatibleWith(WavFormat other) =>
      other.audioFormat == audioFormat &&
      other.channels == channels &&
      other.sampleRate == sampleRate &&
      other.bitsPerSample == bitsPerSample;

  /// Why the formats cannot be joined, in terms a user can act on.
  String describeMismatch(WavFormat other) {
    final differences = <String>[
      if (other.sampleRate != sampleRate)
        'tần số lấy mẫu ${sampleRate}Hz và ${other.sampleRate}Hz',
      if (other.channels != channels)
        'số kênh $channels và ${other.channels}',
      if (other.bitsPerSample != bitsPerSample)
        'độ sâu $bitsPerSample-bit và ${other.bitsPerSample}-bit',
      if (other.audioFormat != audioFormat)
        'kiểu mã hoá $audioFormat và ${other.audioFormat}',
    ];
    return differences.join(', ');
  }

  @override
  String toString() =>
      'WavFormat(format: $audioFormat, ${sampleRate}Hz, ${channels}ch, $bitsPerSample-bit)';
}

/// One parsed WAV: its format plus the payload of its `data` chunk.
class WavData {
  const WavData({required this.format, required this.samples});

  final WavFormat format;

  /// Raw PCM bytes, without the container.
  final Uint8List samples;
}

/// Joins per-sentence WAV files into one file — FR-15's `wav` export.
///
/// No encoder is involved, which is the point: WAV is the format this app can
/// produce **fully offline** with no licence and no third-party binary. MP3 is
/// offered only when a device encoder exists, and the UI says so.
///
/// Concatenating samples is only valid when every file shares one format, so a
/// mismatch is a typed failure naming the actual difference rather than a file
/// that plays as noise.
class WavMerger {
  const WavMerger();

  /// `Result.failure` for anything that is not one consistent PCM stream.
  Result<Uint8List> merge(List<WavData> parts) {
    if (parts.isEmpty) {
      return const Result<Uint8List>.failure(ProcessingFailure(
        message: 'Chưa có câu nào được tạo audio để xuất.',
      ));
    }

    final format = parts.first.format;
    var totalSamples = 0;
    for (final part in parts) {
      if (!format.isCompatibleWith(part.format)) {
        return Result<Uint8List>.failure(ProcessingFailure(
          message: 'Không ghép được audio: các câu có định dạng khác nhau '
              '(${format.describeMismatch(part.format)}).',
          detail: '$format vs ${part.format}',
        ));
      }
      totalSamples += part.samples.length;
    }

    final output = Uint8List(44 + totalSamples);
    _writeHeader(output, format, totalSamples);
    var offset = 44;
    for (final part in parts) {
      output.setRange(offset, offset + part.samples.length, part.samples);
      offset += part.samples.length;
    }
    return Result<Uint8List>.success(output);
  }

  /// Parses a WAV file's bytes. Typed failures for anything malformed — a
  /// half-downloaded or non-WAV file must not be reported as "no audio".
  Result<WavData> parse(Uint8List bytes) {
    if (bytes.length < 44) {
      return Result<WavData>.failure(ProcessingFailure(
        message: 'Tệp audio không hợp lệ: thiếu phần đầu WAV.',
        detail: '${bytes.length} bytes',
      ));
    }
    if (_ascii(bytes, 0, 4) != 'RIFF' || _ascii(bytes, 8, 4) != 'WAVE') {
      return const Result<WavData>.failure(ProcessingFailure(
        message: 'Tệp audio không phải định dạng WAV.',
        detail: 'missing RIFF/WAVE magic',
      ));
    }

    WavFormat? format;
    Uint8List? samples;

    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final id = _ascii(bytes, offset, 4);
      final declared = _uint32(bytes, offset + 4);
      final body = offset + 8;
      // The chunk is padded to an even length; the pad byte is not part of the
      // declared size but is part of the stream.
      final next = body + declared + (declared.isOdd ? 1 : 0);

      if (id == 'fmt ') {
        if (declared < 16 || body + 16 > bytes.length) {
          return const Result<WavData>.failure(ProcessingFailure(
            message: 'Phần mô tả định dạng của tệp audio bị hỏng.',
          ));
        }
        format = WavFormat(
          audioFormat: _uint16(bytes, body),
          channels: _uint16(bytes, body + 2),
          sampleRate: _uint32(bytes, body + 4),
          bitsPerSample: _uint16(bytes, body + 14),
        );
      } else if (id == 'data') {
        if (body + declared > bytes.length) {
          return Result<WavData>.failure(ProcessingFailure(
            message: 'Tệp audio bị thiếu dữ liệu: khai báo $declared byte '
                'nhưng chỉ có ${bytes.length - body}.',
            detail: 'truncated data chunk',
          ));
        }
        samples = Uint8List.sublistView(bytes, body, body + declared);
      }

      if (next <= offset) break; // A zero-size chunk loop would never end.
      offset = next;
    }

    if (format == null) {
      return const Result<WavData>.failure(ProcessingFailure(
        message: 'Tệp audio thiếu phần mô tả định dạng.',
      ));
    }
    if (samples == null) {
      return const Result<WavData>.failure(ProcessingFailure(
        message: 'Tệp audio không có dữ liệu mẫu.',
      ));
    }
    if (format.audioFormat != 1 && format.audioFormat != 3) {
      return Result<WavData>.failure(ProcessingFailure(
        message: 'Chỉ ghép được WAV không nén (PCM). Tệp này dùng kiểu '
            'mã hoá ${format.audioFormat}.',
      ));
    }
    if (format.byteRate <= 0) {
      return const Result<WavData>.failure(ProcessingFailure(
        message: 'Tệp audio khai báo tần số lấy mẫu bằng 0.',
      ));
    }

    return Result<WavData>.success(WavData(format: format, samples: samples));
  }

  /// Size an export will take, computed from the **measured** durations.
  ///
  /// Not from an average bitrate guess: the transport bar already shows real
  /// durations, and an export warning that disagrees with them would be the kind
  /// of fake-precise number DESIGN.md bans.
  int estimateBytes(
    Duration total, {
    int sampleRate = 24000,
    int channels = 1,
    int bitsPerSample = 16,
  }) {
    final bytesPerSecond = sampleRate * channels * (bitsPerSample ~/ 8);
    return 44 + (total.inMilliseconds * bytesPerSecond / 1000).round();
  }

  // ---------------------------------------------------------------------------

  void _writeHeader(Uint8List output, WavFormat format, int dataBytes) {
    void ascii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        output[offset + i] = value.codeUnitAt(i);
      }
    }

    void uint32(int offset, int value) => output.buffer
        .asByteData()
        .setUint32(offset, value, Endian.little);
    void uint16(int offset, int value) =>
        output.buffer.asByteData().setUint16(offset, value, Endian.little);

    ascii(0, 'RIFF');
    uint32(4, 36 + dataBytes);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    uint32(16, 16);
    uint16(20, format.audioFormat);
    uint16(22, format.channels);
    uint32(24, format.sampleRate);
    uint32(28, format.byteRate);
    uint16(32, format.channels * format.bytesPerSample);
    uint16(34, format.bitsPerSample);
    ascii(36, 'data');
    uint32(40, dataBytes);
  }

  static String _ascii(Uint8List bytes, int start, int length) =>
      String.fromCharCodes(bytes.sublist(start, start + length));

  static int _uint16(Uint8List bytes, int offset) =>
      bytes[offset] | (bytes[offset + 1] << 8);

  static int _uint32(Uint8List bytes, int offset) =>
      bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);
}
