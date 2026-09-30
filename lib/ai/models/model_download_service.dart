import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../core/logging/app_log.dart';
import '../../core/result/result.dart';
import 'vieneu_model_manifest.dart';

/// Streams one artifact into app-private storage and verifies it.
///
/// Three properties, each of which is the reason this is a class and not a
/// `client.get` call:
///
/// * **It streams.** The largest file is 104 MB; buffering it in memory on a
///   low-end phone is how an install becomes an OOM kill (NFR-04).
/// * **It verifies before it commits.** The download lands in a `.part` file and
///   is hashed before being renamed, so a half-written or tampered file can
///   never be mistaken for an installed model (FR-20 `Corrupt`).
/// * **It cancels cleanly.** A cancelled or failed download leaves no `.part`
///   and no target file behind — a stray partial file is what makes the next
///   install report "already installed" and then fail at synthesis.
class ModelDownloadService {
  ModelDownloadService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Downloads [file] under [root], creating directories as needed.
  ///
  /// [onProgress] receives bytes received for this file. [shouldCancel] is polled
  /// between chunks; returning `true` aborts with [CancelledFailure] and removes
  /// the partial file.
  Future<Result<File>> download(
    ModelFileSpec file, {
    required Directory root,
    void Function(int received, int total)? onProgress,
    Future<bool> Function()? shouldCancel,
  }) async {
    final target = File('${root.path}/${file.relativePath}');
    final partial = File('${target.path}.part');

    // Checked before any directory is created, so a cancel that arrived before
    // the download started leaves the disk untouched rather than an empty
    // directory behind.
    if (shouldCancel != null && await shouldCancel()) {
      return const Result<File>.failure(CancelledFailure());
    }

    try {
      await target.parent.create(recursive: true);
      if (await partial.exists()) await partial.delete();

      final request = http.Request('GET', Uri.parse(file.url));
      final response = await _client.send(request);
      if (response.statusCode != 200) {
        return Result<File>.failure(StorageFailure(
          message: 'Máy chủ trả về lỗi ${response.statusCode} khi tải '
              '${file.fileName}.',
          detail: file.url,
        ));
      }

      final sink = partial.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.stream) {
          if (shouldCancel != null && await shouldCancel()) {
            await sink.close();
            await _deleteQuietly(partial);
            return const Result<File>.failure(CancelledFailure());
          }
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, file.sizeBytes);
        }
      } finally {
        await sink.close();
      }

      // Size first: a truncated stream is caught before hashing 100 MB.
      final actualSize = await partial.length();
      if (actualSize != file.sizeBytes) {
        await _deleteQuietly(partial);
        return Result<File>.failure(CorruptModelFailure(
          message: 'Tệp ${file.fileName} tải về không đúng dung lượng.',
          detail: '$actualSize so với ${file.sizeBytes} byte',
        ));
      }

      // The hash is computed by streaming the file rather than from the bytes in
      // memory, for the same reason the download streams.
      final digest = (await sha256.bind(partial.openRead()).first).toString();
      if (digest != file.sha256) {
        await _deleteQuietly(partial);
        AppLog.error('model.download.hashMismatch', data: <String, Object?>{
          'file': file.fileName,
          'expected': file.sha256,
          'actual': digest,
        });
        return Result<File>.failure(CorruptModelFailure(
          message: 'Tệp ${file.fileName} tải về không khớp mã kiểm tra.',
          detail: 'sha256 $digest, mong đợi ${file.sha256}',
        ));
      }

      if (await target.exists()) await target.delete();
      final installed = await partial.rename(target.path);
      return Result<File>.success(installed);
    } catch (error, stack) {
      await _deleteQuietly(partial);
      AppLog.error('model.download.failed',
          data: <String, Object?>{'file': file.relativePath},
          error: error,
          stackTrace: stack);
      return Result<File>.failure(StorageFailure(
        message: 'Không tải được ${file.fileName}: $error',
        detail: stack.toString(),
        cause: error,
      ));
    }
  }

  /// `true` when the file is already present at the right size.
  ///
  /// Size only, deliberately: hashing 280 MB on every app start would make the
  /// Models screen slow for a check that only needs to catch the common case
  /// (missing or truncated). The full check is [verify].
  static Future<bool> isPresent(ModelFileSpec file, Directory root) async {
    final target = File('${root.path}/${file.relativePath}');
    if (!await target.exists()) return false;
    return await target.length() == file.sizeBytes;
  }

  /// Re-hashes every file. The `Kiểm tra model` action (FR-20).
  ///
  /// Returns the name of the first file that fails, or `null` when all match.
  Future<String?> verify(List<ModelFileSpec> files, Directory root) async {
    for (final file in files) {
      final target = File('${root.path}/${file.relativePath}');
      if (!await target.exists()) return file.relativePath;
      if (await target.length() != file.sizeBytes) return file.relativePath;
      final digest = (await sha256.bind(target.openRead()).first).toString();
      if (digest != file.sha256) return file.relativePath;
    }
    return null;
  }

  /// Bytes actually on disk for [files] — the number the Models row shows, which
  /// can be smaller than the download total when a platform needs fewer files.
  Future<int> installedBytes(List<ModelFileSpec> files, Directory root) async {
    var total = 0;
    for (final file in files) {
      final target = File('${root.path}/${file.relativePath}');
      if (await target.exists()) total += await target.length();
    }
    return total;
  }

  /// Removes everything this manifest installed, including stray `.part` files.
  Future<void> delete(List<ModelFileSpec> files, Directory root) async {
    for (final file in files) {
      await _deleteQuietly(File('${root.path}/${file.relativePath}.part'));
      await _deleteQuietly(File('${root.path}/${file.relativePath}'));
    }
    // Sweep the whole tree rather than only the expected paths: a `.part` from a
    // download interrupted under an older manifest has no matching entry here,
    // and a stray partial is exactly what makes the next audit report `corrupt`.
    if (await root.exists()) {
      await for (final entity in root.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.part')) {
          await _deleteQuietly(entity);
        }
      }
    }
    // Empty component directories would otherwise accumulate across installs.
    for (final directory in <String>{
      for (final file in files) file.relativePath.split('/').first,
    }) {
      final dir = Directory('${root.path}/$directory');
      if (await dir.exists() && await dir.list().isEmpty) {
        await dir.delete();
      }
    }
  }

  void dispose() => _client.close();

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // A leftover partial file is harmless: the next install overwrites it.
    }
  }
}
