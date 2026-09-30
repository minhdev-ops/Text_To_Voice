import 'dart:io';
import 'dart:typed_data';

import '../../core/logging/app_log.dart';
import '../../core/result/result.dart';
import '../models/reading.dart';
import 'text_exporter.dart';
import 'wav_merger.dart';

/// One artifact that reached the disk.
class ExportedArtifact {
  const ExportedArtifact({
    required this.path,
    required this.bytes,
    required this.label,
  });

  final String path;
  final int bytes;

  /// Vietnamese label for the result list ("Văn bản (.txt)").
  final String label;

  @override
  String toString() => 'ExportedArtifact($label, $bytes bytes)';
}

/// An artifact that did not.
class FailedArtifact {
  const FailedArtifact({required this.label, required this.message});

  final String label;

  /// The real cause, never "Đã có lỗi xảy ra".
  final String message;

  @override
  String toString() => 'FailedArtifact($label: $message)';
}

/// The outcome of an export.
///
/// Reports successes *and* failures together rather than collapsing to one
/// boolean: the spec requires a partially failed export to say which artifacts
/// succeeded, and "3 of 4 written" is the information the user needs to decide
/// whether to retry.
class ExportOutcome {
  const ExportOutcome({required this.directory, this.written = const [], this.failed = const []});

  final String directory;
  final List<ExportedArtifact> written;
  final List<FailedArtifact> failed;

  bool get isComplete => failed.isEmpty && written.isNotEmpty;

  bool get isTotalFailure => written.isEmpty && failed.isNotEmpty;

  int get totalBytes =>
      written.fold<int>(0, (sum, artifact) => sum + artifact.bytes);

  /// One line for the result banner, stating what actually happened.
  String get summary {
    if (isTotalFailure) return 'Không xuất được tệp nào.';
    if (failed.isEmpty) {
      return 'Đã xuất ${written.length} tệp vào $directory';
    }
    return 'Đã xuất ${written.length}/${written.length + failed.length} tệp; '
        '${failed.length} tệp lỗi.';
  }
}

/// Writes the read-aloud surface's contents to disk — FR-14 (text) and FR-15
/// (audio).
///
/// Each artifact is attempted independently: a missing audio file for sentence 9
/// must not cost the user their text export, and the per-artifact result is what
/// makes that visible instead of silent.
class DocumentExportService {
  const DocumentExportService({
    TextExporter textExporter = const TextExporter(),
    WavMerger wavMerger = const WavMerger(),
  })  : _text = textExporter,
        _wav = wavMerger;

  final TextExporter _text;
  final WavMerger _wav;

  /// Writes the requested artifacts into [directory], creating it if needed.
  ///
  /// [readFile] is injectable so the merge path can be tested without a disk;
  /// the default is `File(path).readAsBytes()`.
  Future<ExportOutcome> export({
    required String text,
    required List<Sentence> sentences,
    required Directory directory,
    required List<TextExportFormat> formats,
    bool includeAudio = false,
    String? title,
    DateTime? now,
    Future<Uint8List> Function(String path)? readFile,
  }) async {
    final documentTitle = title ?? documentTitleFrom(text);
    final written = <ExportedArtifact>[];
    final failed = <FailedArtifact>[];

    try {
      await directory.create(recursive: true);
    } catch (error) {
      // Nothing can be written, so say that once with the real cause.
      return ExportOutcome(
        directory: directory.path,
        failed: <FailedArtifact>[
          FailedArtifact(
            label: 'Thư mục xuất',
            message: 'Không tạo được thư mục ${directory.path}: $error',
          ),
        ],
      );
    }

    for (final format in formats) {
      try {
        final content = _text.render(
          text: text,
          title: documentTitle,
          format: format,
          sentences: sentences,
          exportedAt: now,
        );
        final file = File('${directory.path}/${exportFileName(documentTitle, format.extension)}');
        await file.writeAsString(content, flush: true);
        written.add(ExportedArtifact(
          path: file.path,
          bytes: await file.length(),
          label: format.label,
        ));
      } catch (error) {
        AppLog.error('export.text.failed',
            data: <String, Object?>{'format': format.name}, error: error);
        failed.add(FailedArtifact(
          label: format.label,
          message: 'Không ghi được tệp ${format.extension}: $error',
        ));
      }
    }

    if (includeAudio) {
      const label = 'Audio (.wav)';
      final merged = await _mergeSentenceAudio(
        sentences: sentences,
        readFile: readFile ?? _defaultReadFile,
      );
      switch (merged) {
        case Success<Uint8List>(:final value):
          try {
            final file = File(
              '${directory.path}/${exportFileName(documentTitle, 'wav')}',
            );
            await file.writeAsBytes(value, flush: true);
            written.add(ExportedArtifact(
              path: file.path,
              bytes: value.length,
              label: label,
            ));
          } catch (error) {
            AppLog.error('export.audio.write.failed', error: error);
            failed.add(FailedArtifact(
              label: label,
              message: 'Không ghi được tệp .wav: $error',
            ));
          }
        case Failure<Uint8List>(:final failure):
          AppLog.error('export.audio.merge.failed', error: failure.message);
          failed.add(FailedArtifact(label: label, message: failure.message));
      }
    }

    AppLog.info('export.done', data: <String, Object?>{
      'written': written.length,
      'failed': failed.length,
      'bytes': written.fold<int>(0, (sum, a) => sum + a.bytes),
    });

    return ExportOutcome(
      directory: directory.path,
      written: written,
      failed: failed,
    );
  }

  /// Reads every sentence's audio **in reading order** and joins it.
  ///
  /// Missing audio is counted, and the merge is **refused** rather than patched
  /// over: a WAV with silent holes in the middle of a document sounds like a bug
  /// in the reader, and the user has no way to know two sentences were dropped.
  Future<Result<Uint8List>> _mergeSentenceAudio({
    required List<Sentence> sentences,
    required Future<Uint8List> Function(String path) readFile,
  }) async {
    final parts = <WavData>[];
    var skipped = 0;

    for (final sentence in sentences) {
      final path = sentence.audioPath;
      if (path == null) {
        skipped++;
        continue;
      }
      try {
        final parsed = _wav.parse(await readFile(path));
        switch (parsed) {
          case Success<WavData>(:final value):
            parts.add(value);
          case Failure<WavData>(:final failure):
            return Result<Uint8List>.failure(ProcessingFailure(
              message: 'Câu ${sentence.index + 1}: ${failure.message}',
              detail: path,
            ));
        }
      } catch (error) {
        return Result<Uint8List>.failure(StorageFailure(
          message: 'Không đọc được audio của câu ${sentence.index + 1}: $error',
          detail: path,
        ));
      }
    }

    if (skipped > 0) {
      AppLog.warning('export.audio.skipped', data: <String, Object?>{'count': skipped});
    }
    if (parts.isEmpty) {
      return const Result<Uint8List>.failure(ProcessingFailure(
        message: 'Chưa có câu nào được tạo audio để xuất.',
      ));
    }
    if (skipped > 0) {
      return Result<Uint8List>.failure(ProcessingFailure(
        message: 'Còn $skipped câu chưa có audio. Đọc hết tài liệu rồi xuất lại.',
      ));
    }
    return _wav.merge(parts);
  }

  /// Total duration the export will contain, from **measured** durations only.
  static Duration measuredDuration(List<Sentence> sentences) =>
      sentences.fold<Duration>(
        Duration.zero,
        (sum, sentence) => sum + Duration(milliseconds: sentence.durationMs ?? 0),
      );

  static Future<Uint8List> _defaultReadFile(String path) =>
      File(path).readAsBytes();
}
