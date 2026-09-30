import 'dart:io' show File;
import 'dart:typed_data' show ByteData, Uint8List;

/// Minimal TrueType `cmap` reader — enough to answer one question:
/// *"does this font file actually contain the glyph for codepoint X?"*
///
/// Written by hand because Flutter's text pipeline will happily draw a
/// notdef box for a missing Vietnamese precomposed glyph and nothing in the
/// widget tree will complain. Checking the binary is the only way to catch a
/// wrong or truncated font file before it ships.
final class TrueTypeCoverage {
  TrueTypeCoverage._(this._data) : _bytes = ByteData.sublistView(_data);

  factory TrueTypeCoverage.fromFile(String path) =>
      TrueTypeCoverage._(File(path).readAsBytesSync());

  final Uint8List _data;
  final ByteData _bytes;

  int _u16(int offset) => _bytes.getUint16(offset);
  int _u32(int offset) => _bytes.getUint32(offset);

  int _tagAt(int offset) => (_bytes.getUint8(offset) << 24) |
      (_bytes.getUint8(offset + 1) << 16) |
      (_bytes.getUint8(offset + 2) << 8) |
      _bytes.getUint8(offset + 3);

  static const int _tagCmap = 0x636D6170; // 'cmap'

  int get _cmapTableOffset {
    final numTables = _u16(4);
    for (var i = 0; i < numTables; i++) {
      final record = 12 + i * 16;
      if (_tagAt(record) == _tagCmap) return _u32(record + 8);
    }
    return -1;
  }

  /// Best available subtable, preferring full Unicode (3,10) then BMP (3,1).
  int get _subtableOffset {
    final cmap = _cmapTableOffset;
    if (cmap < 0) return -1;

    final numEncodings = _u16(cmap + 2);
    var best = -1;
    var bestScore = -1;
    for (var i = 0; i < numEncodings; i++) {
      final record = cmap + 4 + i * 8;
      final platform = _u16(record);
      final encoding = _u16(record + 2);
      final subtable = cmap + _u32(record + 4);
      if (subtable + 2 > _data.length) continue;

      final format = _u16(subtable);
      final score = switch ((platform, encoding, format)) {
        (3, 10, 12) => 4,
        (3, 1, 12) => 3,
        (3, 1, 4) => 2,
        (0, _, _) => 1,
        _ => 0,
      };
      if (score > bestScore) {
        bestScore = score;
        best = subtable;
      }
    }
    return best;
  }

  /// Whether [codepoint] maps to a real glyph (never `.notdef`).
  bool covers(int codepoint) {
    final subtable = _subtableOffset;
    if (subtable < 0) return false;

    return switch (_u16(subtable)) {
      12 => _coversFormat12(subtable, codepoint),
      4 => _coversFormat4(subtable, codepoint),
      _ => false,
    };
  }

  bool _coversFormat12(int base, int codepoint) {
    final groupCount = _u32(base + 12);
    for (var g = 0; g < groupCount; g++) {
      final record = base + 16 + g * 12;
      final start = _u32(record);
      if (codepoint < start) return false;
      if (codepoint <= _u32(record + 4)) return true;
    }
    return false;
  }

  bool _coversFormat4(int base, int codepoint) {
    final segCount = _u16(base + 6) ~/ 2;
    final endBase = base + 14;
    final startBase = endBase + segCount * 2 + 2;
    final idDeltaBase = startBase + segCount * 2;
    final idRangeOffsetBase = idDeltaBase + segCount * 2;

    for (var i = 0; i < segCount; i++) {
      final end = _u16(endBase + i * 2);
      if (codepoint > end) continue;

      final start = _u16(startBase + i * 2);
      if (codepoint < start) return false;

      final idRangeOffset = _u16(idRangeOffsetBase + i * 2);
      if (idRangeOffset == 0) {
        // Glyph index is `codepoint + idDelta` mod 65536; 0 means .notdef.
        final idDelta = _u16(idDeltaBase + i * 2);
        return ((codepoint + idDelta) & 0xFFFF) != 0;
      }
      // Offset table: the idRangeOffset word points at itself, plus
      // `codepoint - start` entries of 2 bytes each.
      final glyphAddress = idRangeOffsetBase + idRangeOffset + (codepoint - start) * 2;
      if (glyphAddress + 2 > _data.length) return false;
      return _u16(glyphAddress) != 0;
    }
    return false;
  }
}
