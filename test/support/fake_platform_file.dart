import 'dart:typed_data';

import 'package:cross_file/cross_file.dart' show XFile;
import 'package:file_picker/file_picker.dart' show PlatformFile;

/// A [PlatformFile]-shaped stand-in, extending the platform's `base` class so
/// the concrete plugin types stay untouched. Covers only what
/// `DocumentImporter` reads.
///
/// Lives in `support/` because both the importer and the image-import tests need
/// it, and a private helper cannot be shared across test files.
final class FakePlatformFile extends PlatformFile {
  FakePlatformFile(this.name, this.bytes, {this.localPath});

  @override
  final String name;

  final Uint8List bytes;

  /// `null` models a provider that hands back a non-`file` URI (a cloud
  /// document or a web blob), which is the case that used to crash.
  final String? localPath;

  @override
  String? get extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? null : name.substring(dot + 1);
  }

  @override
  Uri get uri => localPath == null
      ? Uri.parse('blob:https://example.invalid/${Uri.encodeComponent(name)}')
      : Uri.file(localPath!);

  @override
  String? get path => localPath;

  @override
  XFile get xFile => throw UnimplementedError();

  @override
  int? lengthSync() => bytes.length;

  @override
  Future<int?> length() async => bytes.length;

  @override
  Future<Uint8List> readAsBytes() async => bytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream<Uint8List>.value(bytes);
}
