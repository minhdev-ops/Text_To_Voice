import 'dart:io';

import '../../core/logging/app_log.dart';
import '../../core/result/result.dart';
import 'model_download_service.dart';
import 'vieneu_model_manifest.dart';

/// The states the Models screen renders (SRS FR-20 / the approved spec §7).
///
/// [corrupt] is separate from [notInstalled] because the honest answer differs:
/// "not installed" offers `Tải về`, "corrupt" offers `Tải lại`, and a user shown
/// the wrong one re-installs a model that is already there.
enum ModelInstallStage {
  notInstalled,
  downloading,
  verifying,
  installed,
  corrupt,
  error,
}

/// Immutable install state — one value, so the screen cannot render a
/// contradictory pair like "Đã cài" with a live progress bar.
class ModelInstallState {
  const ModelInstallState({
    required this.stage,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.currentFile,
    this.installedBytes = 0,
    this.failure,
    this.modelPath,
  });

  const ModelInstallState.notInstalled({required int totalBytes})
      : this(stage: ModelInstallStage.notInstalled, totalBytes: totalBytes);

  final ModelInstallStage stage;

  /// Bytes received across the whole install (not just the current file), so the
  /// bar does not reset thirteen times.
  final int receivedBytes;
  final int totalBytes;
  final String? currentFile;
  final int installedBytes;
  final AppFailure? failure;
  final String? modelPath;

  /// 0..1, monotonic while downloading.
  double get progress {
    if (totalBytes <= 0) return 0;
    final value = receivedBytes / totalBytes;
    return value < 0 ? 0 : (value > 1 ? 1 : value);
  }

  bool get isBusy =>
      stage == ModelInstallStage.downloading || stage == ModelInstallStage.verifying;

  /// The read-aloud button's enablement: only a verified install counts.
  bool get engineUsable => stage == ModelInstallStage.installed;

  ModelInstallState copyWith({
    ModelInstallStage? stage,
    int? receivedBytes,
    int? totalBytes,
    String? currentFile,
    int? installedBytes,
    AppFailure? failure,
    String? modelPath,
    bool clearFailure = false,
    bool clearCurrentFile = false,
  }) =>
      ModelInstallState(
        stage: stage ?? this.stage,
        receivedBytes: receivedBytes ?? this.receivedBytes,
        totalBytes: totalBytes ?? this.totalBytes,
        currentFile: clearCurrentFile ? null : (currentFile ?? this.currentFile),
        installedBytes: installedBytes ?? this.installedBytes,
        failure: clearFailure ? null : (failure ?? this.failure),
        modelPath: modelPath ?? this.modelPath,
      );

  @override
  bool operator ==(Object other) =>
      other is ModelInstallState &&
      other.stage == stage &&
      other.receivedBytes == receivedBytes &&
      other.totalBytes == totalBytes &&
      other.currentFile == currentFile &&
      other.installedBytes == installedBytes &&
      other.failure == failure &&
      other.modelPath == modelPath;

  @override
  int get hashCode => Object.hash(
      stage, receivedBytes, totalBytes, currentFile, installedBytes, failure, modelPath);
}

/// Downloads, verifies and removes the TTS model set (FR-20).
///
/// Orchestration only: the byte-level work is [ModelDownloadService]'s, and the
/// file list is [VieNeuModelManifest]'s. What this class owns is the *order* and
/// the invariant that matters — an install is reported as complete only after
/// every file's SHA-256 matched, and a failure leaves nothing behind that could
/// be mistaken for an install.
class ModelInstallService {
  ModelInstallService({
    required this.root,
    required this.files,
    ModelDownloadService? downloads,
    String? platform,
  })  : _downloads = downloads ?? ModelDownloadService(),
        platform = platform ?? Platform.operatingSystem;

  /// `<app documents>/models`.
  final Directory root;

  /// Exactly what to install, in order. Passed in rather than read from the
  /// manifest inside the class, so the orchestrator is testable against a
  /// handful of byte-sized files instead of 280 MB of weights — and so a future
  /// second checkpoint is a different list, not a branch in here.
  final List<ModelFileSpec> files;

  final String platform;
  final ModelDownloadService _downloads;

  bool _cancelRequested = false;

  int get totalBytes =>
      files.fold<int>(0, (sum, file) => sum + file.sizeBytes);

  String get modelPath =>
      '${root.path}/${VieNeuModelManifest.modelDirectoryName}';

  String get codecPath => '${root.path}/${VieNeuModelManifest.codecDirectoryName}';

  String get phonemizerPath =>
      '${root.path}/${VieNeuModelManifest.phonemizerDirectoryName}';

  /// The cheap check run at app start: presence and size.
  ///
  /// Size-only on purpose. Hashing 280 MB on every launch would put a
  /// multi-second stall in front of the first screen for a check the explicit
  /// `Kiểm tra model` action already covers.
  Future<ModelInstallState> audit() async {
    var present = 0;
    var installedBytes = 0;
    for (final file in files) {
      final target = File('${root.path}/${file.relativePath}');
      if (!await target.exists()) continue;
      final length = await target.length();
      if (length == file.sizeBytes) {
        present++;
        installedBytes += length;
      }
    }

    if (present == 0) {
      // Nothing at all: a fresh install, not a broken one.
      final partial = await _hasPartialFiles();
      return ModelInstallState(
        stage: partial ? ModelInstallStage.corrupt : ModelInstallStage.notInstalled,
        totalBytes: totalBytes,
        failure: partial
            ? const CorruptModelFailure(
                message: 'Bản tải trước chưa hoàn tất. Cần tải lại model.',
                detail: 'leftover .part files',
              )
            : null,
      );
    }
    if (present < files.length) {
      return ModelInstallState(
        stage: ModelInstallStage.corrupt,
        totalBytes: totalBytes,
        installedBytes: installedBytes,
        failure: CorruptModelFailure(
          message: 'Model thiếu ${files.length - present} tệp. Cần tải lại.',
          detail: '$present/${files.length} present',
        ),
      );
    }
    return ModelInstallState(
      stage: ModelInstallStage.installed,
      totalBytes: totalBytes,
      receivedBytes: totalBytes,
      installedBytes: installedBytes,
      modelPath: modelPath,
    );
  }

  /// The explicit `Kiểm tra model` action: full SHA-256 over every file.
  Future<ModelInstallState> verify({
    void Function(ModelInstallState)? onState,
  }) async {
    onState?.call(ModelInstallState(
      stage: ModelInstallStage.verifying,
      totalBytes: totalBytes,
    ));
    final bad = await _downloads.verify(files, root);
    if (bad == null) {
      final installed = await audit();
      final state = installed.copyWith(stage: ModelInstallStage.installed);
      onState?.call(state);
      return state;
    }
    final state = ModelInstallState(
      stage: ModelInstallStage.corrupt,
      totalBytes: totalBytes,
      failure: CorruptModelFailure(
        message: 'Model hỏng — cần tải lại.',
        detail: 'hash mismatch: $bad',
      ),
    );
    onState?.call(state);
    return state;
  }

  /// Downloads every missing file, verifying each before it is committed.
  Future<ModelInstallState> install({
    void Function(ModelInstallState) onState = _ignore,
  }) async {
    // The cancel flag is honoured on entry and cleared only once this run is
    // over. `cancel()` can legitimately arrive *before* `install()` — the UI can
    // cancel a queued download — and clearing the flag at the top here would drop
    // that cancel on the floor and start downloading anyway.
    try {
      return await _runInstall(onState);
    } finally {
      _cancelRequested = false;
    }
  }

  Future<ModelInstallState> _runInstall(
    void Function(ModelInstallState) onState,
  ) async {
    final total = totalBytes;
    var received = 0;

    // Files already present and correctly sized are skipped, so a cancelled
    // install resumes by simply installing again.
    final pending = <ModelFileSpec>[];
    for (final file in files) {
      if (await ModelDownloadService.isPresent(file, root)) {
        received += file.sizeBytes;
      } else {
        pending.add(file);
      }
    }

    onState(ModelInstallState(
      stage: ModelInstallStage.downloading,
      receivedBytes: received,
      totalBytes: total,
      currentFile: pending.isEmpty ? null : pending.first.relativePath,
    ));

    for (final file in pending) {
      final baseline = received;
      final result = await _downloads.download(
        file,
        root: root,
        shouldCancel: () async => _cancelRequested,
        onProgress: (fileReceived, _) {
          onState(ModelInstallState(
            stage: ModelInstallStage.downloading,
            receivedBytes: baseline + fileReceived,
            totalBytes: total,
            currentFile: file.relativePath,
          ));
        },
      );

      switch (result) {
        case Success<File>():
          received = baseline + file.sizeBytes;
          onState(ModelInstallState(
            stage: ModelInstallStage.downloading,
            receivedBytes: received,
            totalBytes: total,
          ));
        case Failure<File>(:final failure):
          // Cancel and failure both leave no committed file behind; the state
          // says which happened so the UI does not offer `Retry` after a
          // deliberate cancel.
          final cancelled = failure is CancelledFailure;
          final state = ModelInstallState(
            stage: cancelled ? ModelInstallStage.notInstalled : ModelInstallStage.error,
            receivedBytes: received,
            totalBytes: total,
            failure: cancelled ? null : failure,
          );
          onState(state);
          return state;
      }
    }

    onState(ModelInstallState(
      stage: ModelInstallStage.verifying,
      receivedBytes: total,
      totalBytes: total,
    ));
    final bad = await _downloads.verify(files, root);
    if (bad != null) {
      final state = ModelInstallState(
        stage: ModelInstallStage.corrupt,
        totalBytes: total,
        failure: CorruptModelFailure(
          message: 'Tệp $bad không khớp mã kiểm tra sau khi tải.',
          detail: 'post-install verify failed',
        ),
      );
      onState(state);
      return state;
    }

    AppLog.info('model.installed', data: <String, Object?>{
      'bytes': total,
      'files': files.length,
      'platform': platform,
    });
    final state = ModelInstallState(
      stage: ModelInstallStage.installed,
      receivedBytes: total,
      totalBytes: total,
      installedBytes: total,
      modelPath: modelPath,
    );
    onState(state);
    return state;
  }

  /// Asks an in-flight install to stop, or a not-yet-started one not to start.
  /// The `.part` file is removed by the download service, so a cancel leaves the
  /// disk exactly as it was.
  void cancel() => _cancelRequested = true;

  /// Deletes every installed file, returning the state the screen should show.
  Future<ModelInstallState> delete() async {
    await _downloads.delete(files, root);
    AppLog.info('model.deleted', data: <String, Object?>{'platform': platform});
    return ModelInstallState.notInstalled(totalBytes: totalBytes);
  }

  /// Releases the HTTP client. The service is otherwise stateless.
  void dispose() => _downloads.dispose();

  Future<bool> _hasPartialFiles() async {
    if (!await root.exists()) return false;
    await for (final entity in root.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.part')) return true;
    }
    return false;
  }

  static void _ignore(ModelInstallState _) {}
}
