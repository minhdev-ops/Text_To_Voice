import 'dart:convert' show utf8;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show immutable;

import '../../core/result/result.dart';
import '../models/imported_file.dart' show ImportedFile;

/// What a file actually is, decided from its bytes.
enum FileKind {
  pdf,
  epub,
  text,
  markdown,
  imageJpeg,
  imagePng,
  imageWebp,
}

/// The size above which the app refuses rather than tries.
///
/// SRS §38 asks for a size cap. 200 MB is above any real document and below the
/// point where a phone would start thrashing; the honest failure is cheaper than
/// an out-of-memory kill the user cannot explain.
const int maxImportBytes = 200 * 1024 * 1024;

/// A file whose bytes match its claimed type.
@immutable
class ValidatedFile {
  const ValidatedFile({
    required this.kind,
    required this.mimeType,
    required this.extension,
    this.encrypted = false,
  });

  final FileKind kind;

  /// MIME type **derived from the bytes**, never taken from the provider.
  final String mimeType;

  final String extension;

  /// `true` for an encrypted PDF. Detected here so the password prompt is a
  /// different screen from a parse failure.
  final bool encrypted;

  /// Whether an extractor can do anything with text directly.
  bool get isTextual => kind == FileKind.text || kind == FileKind.markdown;

  @override
  String toString() => 'ValidatedFile(${kind.name}, $mimeType)';
}

/// Content-based validation, per SRS §38.
///
/// A `.pdf` that is really an executable must be rejected **here**, at the
/// boundary, before any parser sees it. Extensions and provider MIME types are
/// both attacker-controlled in the sense that matters: they are metadata about a
/// file, not the file.
abstract final class ImportValidator {
  /// Recognizes [headBytes] (the first few hundred bytes) plus the claimed
  /// extension.
  ///
  /// Returns a typed failure naming both what was claimed and what was found,
  /// because "tệp không hợp lệ" is not something a user can act on.
  static Result<ValidatedFile> validate(ImportedFile file) {
    if (file.size > maxImportBytes) {
      return Failure(ValidationFailure(
        message: 'Tệp lớn hơn ${maxImportBytes ~/ (1024 * 1024)} MB nên chưa '
            'xử lý được.',
      ));
    }

    final head = file.headBytes;
    if (head == null || head.isEmpty) {
      return const Failure(ValidationFailure(
        message: 'Không đọc được nội dung tệp để kiểm tra.',
      ));
    }

    final claimed = file.extension;
    final sniffed = sniff(head);

    if (sniffed == null) {
      // No recognised magic number. That is legitimate for text, which has none —
      // so text is validated by *decodability* instead, and anything else that
      // reaches here is rejected.
      if (!_isTextualExtension(claimed)) {
        return Failure(ValidationFailure(
          message: 'Tệp ".$claimed" không đúng định dạng mà phần mở rộng của '
              'nó khai báo.',
        ));
      }
      if (!_looksLikeDecodableText(head)) {
        return Failure(ValidationFailure(
          message: 'Tệp ".$claimed" không phải văn bản đọc được.',
        ));
      }
      return Success(ValidatedFile(
        kind: claimed == 'md' ? FileKind.markdown : FileKind.text,
        mimeType: claimed == 'md' ? 'text/markdown' : 'text/plain',
        extension: claimed,
      ));
    }

    if (!_matchesExtension(sniffed, claimed)) {
      return Failure(ValidationFailure(
        message: 'Tệp có đuôi ".$claimed" nhưng nội dung là '
            '${_describe(sniffed)}. Có thể tệp đã bị đổi tên.',
      ));
    }

    return Success(ValidatedFile(
      kind: sniffed.kind,
      mimeType: sniffed.mimeType,
      extension: claimed,
      encrypted: sniffed.encrypted,
    ));
  }

  /// The magic number of [head], or `null` when there is none.
  ///
  /// The EPUB case is worth spelling out: an EPUB *is* a zip, so `PK\x03\x04`
  /// alone cannot tell one from the other, and a `.epub` that is really a plain
  /// zip would fail later in a confusing way. The `mimetype` entry is therefore
  /// checked by name, which is what the format requires to be first and stored
  /// uncompressed.
  static _Sniffed? sniff(Uint8List head) {
    if (_startsWith(head, <int>[0x25, 0x50, 0x44, 0x46])) {
      // %PDF — and the encrypted flag comes from the trailer, which only the
      // parser can read, so it is answered there.
      return const _Sniffed(FileKind.pdf, 'application/pdf');
    }
    if (_startsWith(head, <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
      return const _Sniffed(FileKind.imagePng, 'image/png');
    }
    if (_startsWith(head, <int>[0xFF, 0xD8, 0xFF])) {
      return const _Sniffed(FileKind.imageJpeg, 'image/jpeg');
    }
    if (_startsWith(head, <int>[0x52, 0x49, 0x46, 0x46]) &&
        head.length >= 12 &&
        head[8] == 0x57 &&
        head[9] == 0x45 &&
        head[10] == 0x42 &&
        head[11] == 0x50) {
      return const _Sniffed(FileKind.imageWebp, 'image/webp');
    }
    if (_startsWith(head, <int>[0x50, 0x4B, 0x03, 0x04])) {
      final isEpub = _zipEntryText(head, 'mimetype') == 'application/epub+zip';
      return isEpub
          ? const _Sniffed(FileKind.epub, 'application/epub+zip')
          : null;
    }
    return null;
  }

  /// Reads the content of a **stored** (uncompressed) zip entry by name from the
  /// local file header.
  ///
  /// Only used for `mimetype`, which the EPUB specification requires to be the
  /// first entry and uncompressed precisely so that this cheap check works.
  static String? _zipEntryText(Uint8List head, String name) {
    if (head.length < 30) return null;
    final nameLength = head[26] | (head[27] << 8);
    final extraLength = head[28] | (head[29] << 8);
    final start = 30 + nameLength + extraLength;
    if (start > head.length) return null;
    final bytes = head.sublist(0, nameLength);
    if (utf8.decode(bytes, allowMalformed: true) != name) return null;
    final compressedSize = head[18] | (head[19] << 8);
    final end = (start + compressedSize).clamp(start, head.length);
    return utf8.decode(head.sublist(start, end), allowMalformed: true).trim();
  }

  static bool _matchesExtension(_Sniffed sniffed, String extension) =>
      switch (sniffed.kind) {
        FileKind.pdf => extension == 'pdf',
        FileKind.epub => extension == 'epub',
        FileKind.imageJpeg => extension == 'jpg' || extension == 'jpeg',
        FileKind.imagePng => extension == 'png',
        FileKind.imageWebp => extension == 'webp',
        FileKind.text => extension == 'txt',
        FileKind.markdown => extension == 'md',
      };

  static bool _isTextualExtension(String extension) =>
      extension == 'txt' || extension == 'md';

  /// Text has no magic number, so the check is that the bytes decode and contain
  /// almost no control characters.
  ///
  /// A binary file renamed to `.txt` is the case this catches: it will decode as
  /// malformed UTF-8 full of NULs, and handing that to the reader would produce
  /// pages of replacement characters.
  static bool _looksLikeDecodableText(Uint8List head) {
    if (head.contains(0)) return false;
    final text = utf8.decode(head, allowMalformed: true);
    if (text.isEmpty) return false;
    var control = 0;
    for (final unit in text.codeUnits) {
      final isAllowedWhitespace = unit == 0x09 || unit == 0x0A || unit == 0x0D;
      if (unit < 0x20 && !isAllowedWhitespace) control++;
    }
    return control / text.length < 0.02;
  }

  static bool _startsWith(Uint8List bytes, List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }

  static String _describe(_Sniffed sniffed) => switch (sniffed.kind) {
        FileKind.pdf => 'PDF',
        FileKind.epub => 'EPUB',
        FileKind.imageJpeg => 'ảnh JPEG',
        FileKind.imagePng => 'ảnh PNG',
        FileKind.imageWebp => 'ảnh WebP',
        FileKind.text => 'văn bản',
        FileKind.markdown => 'Markdown',
      };
}

@immutable
class _Sniffed {
  const _Sniffed(this.kind, this.mimeType, {this.encrypted = false});

  final FileKind kind;
  final String mimeType;
  final bool encrypted;
}
