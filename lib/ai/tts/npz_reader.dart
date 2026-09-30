import 'dart:io' show File, RandomAccessFile;
import 'dart:typed_data';

import '../../core/result/result.dart';

/// One `float32` array read out of an `.npz` archive.
///
/// The checkpoint keeps its tied embeddings and its speaker projection in
/// `vieneu_v3_heads.npz`, not in the ONNX graphs — the graphs take
/// already-embedded rows (`inputs_embeds`) precisely so embeddings can live as
/// plain NumPy arrays. Something has to read them, and a 52 MB binary blob is
/// not something a Dart app gets for free.
class NpyArray {
  const NpyArray({
    required this.name,
    required this.shape,
    required this.values,
  });

  /// Entry name without the `.npy` suffix, e.g. `text_emb`.
  final String name;

  /// Dimensions, outermost first. Empty for a scalar.
  final List<int> shape;

  /// Row-major payload. Little-endian on every platform this app targets.
  final Float32List values;

  int get elementCount => shape.fold<int>(1, (product, dim) => product * dim);

  /// `true` when this is a vector (`[n]`).
  bool get isVector => shape.length == 1;

  /// `true` when this is a matrix (`[rows, columns]`).
  bool get isMatrix => shape.length == 2;
}

/// A minimal reader for the subset of `.npz` this checkpoint uses.
///
/// Two deliberate limits, both stated rather than silently tolerated:
///
/// * **stored entries only.** NumPy writes `np.savez` members uncompressed. A
///   DEFLATE member would need an inflater *and* a 52 MB allocation; refusing
///   with a real message is better than a slow, surprising decompress that
///   still cannot be checked. ([CorruptModelFailure] with the method named.)
/// * **little-endian `float32` only.** `descr` is asserted, so a `>f4` or `f2`
///   export fails loudly instead of being reinterpreted as garbage — which is
///   exactly what happens if you `Float32List.view` over the wrong `descr`.
class NpzArchive {
  NpzArchive._(this._file, this._reader, this._entries);

  final File _file;
  final RandomAccessFile _reader;

  /// Entry name (without `.npy`) to the central-directory record.
  final Map<String, _ZipEntry> _entries;

  List<String> get names => _entries.keys.toList(growable: false);

  static const int _endOfCentralDirectory = 0x06054b50;
  static const int _centralDirectoryHeader = 0x02014b50;
  static const int _localFileHeader = 0x04034b50;
  static const int _stored = 0;

  static Future<Result<NpzArchive>> open(File file) async {
    if (!await file.exists()) {
      return Result<NpzArchive>.failure(ModelUnavailableFailure(
        message: 'Thiếu tệp trọng số model (${file.uri.pathSegments.last}).',
        modelId: 'vieneu-v3-turbo',
      ));
    }
    RandomAccessFile? reader;
    try {
      reader = await file.open();
      final length = await reader.length();
      final entries = await _readCentralDirectory(reader, length);
      return Result<NpzArchive>.success(NpzArchive._(file, reader, entries));
    } catch (error) {
      await reader?.close();
      return Result<NpzArchive>.failure(CorruptModelFailure(
        message: 'Tệp trọng số model bị hỏng. Cần tải lại model.',
        detail: '${file.path}: $error',
        cause: error,
      ));
    }
  }

  /// Reads one array. The payload is streamed straight into a new
  /// [Float32List]'s buffer — no intermediate byte copy of a 50 MB table.
  Future<Result<NpyArray>> read(String name) async {
    final entry = _entries[name] ?? _entries['$name.npy'];
    if (entry == null) {
      return Result<NpyArray>.failure(CorruptModelFailure(
        message: 'Model thiếu bảng trọng số "$name". Cần tải lại model.',
        // Names the missing table *and* what is present: a diagnostic that only
        // listed the available keys would leave the reader hunting for the
        // request that asked for the wrong name.
        detail: 'no "$name" in ${_file.path}; has ${_entries.keys.join(', ')}',
      ));
    }
    if (entry.method != _stored) {
      return Result<NpyArray>.failure(CorruptModelFailure(
        message: 'Trọng số model dùng định dạng nén chưa hỗ trợ.',
        detail: '$name: compression method ${entry.method}',
      ));
    }

    try {
      final header = await _readLocalHeader(entry);
      // NPY: magic(6) + version(2) + headerLength(2 for v1) + header text.
      final prefix = await _readAt(header.dataOffset, 12);
      if (prefix[0] != 0x93 ||
          prefix[1] != 0x4E || // N
          prefix[2] != 0x55 || // U
          prefix[3] != 0x4D || // M
          prefix[4] != 0x50 || // P
          prefix[5] != 0x59) {
        return Result<NpyArray>.failure(CorruptModelFailure(
          message: 'Bảng trọng số "$name" không đúng định dạng NumPy.',
        ));
      }
      final major = prefix[6];
      final headerLength = major == 1
          ? prefix[8] | (prefix[9] << 8)
          : prefix[8] | (prefix[9] << 8) | (prefix[10] << 16) | (prefix[11] << 24);
      final headerBytes =
          await _readAt(header.dataOffset + (major == 1 ? 10 : 12), headerLength);
      final parsed = _parseNpyHeader(String.fromCharCodes(headerBytes), name);

      final dataOffset =
          header.dataOffset + (major == 1 ? 10 : 12) + headerLength;
      final values = Float32List(parsed.elementCount);
      if (parsed.elementCount > 0) {
        await _reader.setPosition(dataOffset);
        await _reader.readInto(values.buffer.asUint8List());
      }
      return Result<NpyArray>.success(NpyArray(
        name: name,
        shape: parsed.shape,
        values: values,
      ));
    } catch (error) {
      return Result<NpyArray>.failure(CorruptModelFailure(
        message: 'Không đọc được bảng trọng số "$name".',
        detail: error.toString(),
        cause: error,
      ));
    }
  }

  Future<void> close() => _reader.close();

  // ── internals ────────────────────────────────────────────────────────────

  static Future<Map<String, _ZipEntry>> _readCentralDirectory(
    RandomAccessFile reader,
    int length,
  ) async {
    // The end-of-central-directory record is at most 22 bytes + a 64 KB
    // comment, so the tail is all that ever has to be read.
    final tailLength = length < 0xFFFF + 22 ? length : 0xFFFF + 22;
    final tail = await _readAtFrom(reader, length - tailLength, tailLength);
    int? eocd;
    for (var i = tail.length - 22; i >= 0; i--) {
      if (_uint32(tail, i) == _endOfCentralDirectory) {
        eocd = i;
        break;
      }
    }
    if (eocd == null) {
      throw const FormatException('Không phải tệp .npz hợp lệ (thiếu EOCD).');
    }
    final entryCount = _uint16(tail, eocd + 10);
    final directoryOffset = _uint32(tail, eocd + 16);

    final directory = await _readAtFrom(
      reader,
      directoryOffset,
      // Truncated for the read only; the loop below stops on the signature.
      0x10000,
    );
    final entries = <String, _ZipEntry>{};
    var cursor = 0;
    for (var i = 0; i < entryCount; i++) {
      if (_uint32(directory, cursor) != _centralDirectoryHeader) break;
      final method = _uint16(directory, cursor + 10);
      final compressedSize = _uint32(directory, cursor + 20);
      final uncompressedSize = _uint32(directory, cursor + 24);
      final nameLength = _uint16(directory, cursor + 28);
      final extraLength = _uint16(directory, cursor + 30);
      final commentLength = _uint16(directory, cursor + 32);
      final localOffset = _uint32(directory, cursor + 42);
      final name = String.fromCharCodes(
        directory.sublist(cursor + 46, cursor + 46 + nameLength),
      );
      entries[name.replaceAll('.npy', '')] = _ZipEntry(
        name: name,
        method: method,
        compressedSize: compressedSize,
        uncompressedSize: uncompressedSize,
        localHeaderOffset: localOffset,
      );
      cursor += 46 + nameLength + extraLength + commentLength;
    }
    return entries;
  }

  Future<_LocalHeader> _readLocalHeader(_ZipEntry entry) async {
    final fixed = await _readAt(entry.localHeaderOffset, 30);
    if (_uint32(fixed, 0) != _localFileHeader) {
      throw const FormatException('Zip local header không hợp lệ.');
    }
    final nameLength = _uint16(fixed, 26);
    final extraLength = _uint16(fixed, 28);
    return _LocalHeader(
      dataOffset: entry.localHeaderOffset + 30 + nameLength + extraLength,
    );
  }

  Future<Uint8List> _readAt(int offset, int length) async {
    await _reader.setPosition(offset);
    return _reader.read(length);
  }

  static Future<Uint8List> _readAtFrom(
    RandomAccessFile reader,
    int offset,
    int length,
  ) async {
    await reader.setPosition(offset);
    return reader.read(length);
  }

  static _NpyHeader _parseNpyHeader(String header, String name) {
    final descr = RegExp(r"'descr'\s*:\s*'([^']+)'").firstMatch(header)?.group(1);
    final fortran =
        RegExp(r"'fortran_order'\s*:\s*(True|False)").firstMatch(header)?.group(1);
    final shapeText =
        RegExp(r"'shape'\s*:\s*\(([^)]*)\)").firstMatch(header)?.group(1);

    if (descr == null || shapeText == null) {
      throw FormatException('NPY header thiếu descr/shape: $header', name);
    }
    // Named, not reinterpreted: viewing bytes as float32 when the file says
    // something else produces plausible-looking noise, which is the worst
    // possible failure for a voice.
    if (descr != '<f4') {
      throw FormatException(
        'Bảng trọng số "$name" dùng kiểu $descr; chỉ hỗ trợ <f4.',
      );
    }
    if (fortran == 'True') {
      throw FormatException('Bảng trọng số "$name" dùng thứ tự Fortran.');
    }

    final shape = <int>[];
    for (final part in shapeText.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      shape.add(int.parse(trimmed));
    }
    if (shape.isEmpty) {
      // A 0-d array (the LayerNorm epsilon) has one value, not zero.
      return const _NpyHeader(elementCount: 1, shape: []);
    }
    return _NpyHeader(
      elementCount: shape.fold<int>(1, (product, dim) => product * dim),
      shape: shape,
    );
  }

  static int _uint16(Uint8List bytes, int offset) =>
      bytes[offset] | (bytes[offset + 1] << 8);

  static int _uint32(Uint8List bytes, int offset) =>
      bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);
}

class _ZipEntry {
  const _ZipEntry({
    required this.name,
    required this.method,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.localHeaderOffset,
  });

  final String name;
  final int method;
  final int compressedSize;
  final int uncompressedSize;
  final int localHeaderOffset;
}

class _LocalHeader {
  const _LocalHeader({required this.dataOffset});
  final int dataOffset;
}

class _NpyHeader {
  const _NpyHeader({required this.elementCount, required this.shape});
  final int elementCount;
  final List<int> shape;
}
