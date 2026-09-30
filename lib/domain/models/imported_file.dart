import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show immutable;

/// File types the app accepts (SRS §3.1 / FR-02).
///
/// Kept as a single constant so the SAF picker filter, the validation step and
/// the extractor registry cannot drift apart.
abstract final class SupportedFiles {
  static const Set<String> extensions = <String>{
    'pdf',
    'txt',
    'md',
    'epub',
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  /// MIME types offered to the Storage Access Framework.
  static const Set<String> mimeTypes = <String>{
    'application/pdf',
    'text/plain',
    'text/markdown',
    'application/epub+zip',
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  static bool supportsExtension(String extension) =>
      extensions.contains(extension.toLowerCase().replaceFirst('.', ''));
}

/// A file the user picked, before any processing — the input to validation and
/// then to a [DocumentExtractor].
///
/// [headBytes] carries the first few hundred bytes so validation can check the
/// **magic number**, not just the extension. SRS §38 requires verifying MIME
/// against the actual file, and a `.pdf` that is really an executable must be
/// rejected at this boundary.
@immutable
class ImportedFile {
  const ImportedFile({
    required this.name,
    required this.path,
    required this.mimeType,
    required this.size,
    this.headBytes,
  });

  /// Display name as supplied by the provider.
  final String name;

  /// Absolute path in local storage (already copied into app-private storage
  /// when the provider only handed us a content URI).
  final String path;

  /// MIME **claimed by the provider**. Untrusted until checked against
  /// [headBytes].
  final String mimeType;

  final int size;

  /// Leading bytes, for magic-number verification.
  final Uint8List? headBytes;

  /// Lowercase extension without the dot; `''` when the name has none.
  String get extension {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  bool get hasSupportedExtension => SupportedFiles.supportsExtension(extension);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportedFile &&
          other.name == name &&
          other.path == path &&
          other.mimeType == mimeType &&
          other.size == size);

  @override
  int get hashCode => Object.hash(name, path, mimeType, size);

  @override
  String toString() => 'ImportedFile($name, $size bytes, $mimeType)';
}
