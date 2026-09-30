import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/models/model_install_service.dart';
import '../../ai/models/vieneu_model_manifest.dart';
import '../../core/logging/app_log.dart';
import '../../data/providers.dart';
import '../../domain/models/tts.dart' show VoicePreset;

/// The install service, rooted at the app's private `models/` directory.
///
/// Overridden in tests with a temporary directory, which is the only way to
/// exercise install/cancel/delete without touching the real app storage.
final modelInstallServiceProvider = Provider<ModelInstallService>((ref) {
  final service = ModelInstallService(
    root: ref.watch(modelsDirectoryProvider),
    files: VieNeuModelManifest.filesFor(Platform.operatingSystem),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Where the engine looks for the installed checkpoint (F-20 → FR-09 handoff).
///
/// Derived from the same directory the install service writes to, so the two can
/// never disagree about where the model is.
final modelDirectoriesProvider = Provider<ModelDirectories>((ref) {
  final service = ref.watch(modelInstallServiceProvider);
  return ModelDirectories(
    model: service.modelPath,
    codec: service.codecPath,
    phonemizer: service.phonemizerPath,
    audio: ref.watch(synthesisAudioDirectoryProvider).path,
  );
});

class ModelDirectories {
  const ModelDirectories({
    required this.model,
    required this.codec,
    required this.phonemizer,
    required this.audio,
  });

  final String model;
  final String codec;
  final String phonemizer;
  final String audio;
}

/// One `Notifier` over one immutable install state (state-management rule: the
/// widget layer calls intent methods and re-renders from the published value, so
/// the progress bar, the action button and the license line cannot disagree).
///
/// The state machine is exactly the six FR-20 states; `download()` is the only
/// place progress is written, and `installed` is only ever entered after a full
/// SHA-256 pass over every file.
class ModelInstallController extends Notifier<ModelInstallState> {
  @override
  ModelInstallState build() {
    final service = ref.watch(modelInstallServiceProvider);
    // The audit is I/O, so it is kicked off rather than awaited: `build` must be
    // synchronous and must not read the file system during a frame.
    unawaited(Future<void>.microtask(_audit));
    return ModelInstallState.notInstalled(totalBytes: service.totalBytes);
  }

  Future<void> _audit() async {
    final service = ref.read(modelInstallServiceProvider);
    final next = await service.audit();
    if (ref.mounted) state = next;
    await _syncDatabase(next);
  }

  /// `Tải về` / `Tải lại`.
  Future<void> install() async {
    final service = ref.read(modelInstallServiceProvider);
    final result = await service.install(onState: (next) {
      if (ref.mounted) state = next;
    });
    await _syncDatabase(result);
  }

  /// `Hủy` — the download service removes its `.part` file, so the disk is left
  /// exactly as it was.
  void cancel() {
    ref.read(modelInstallServiceProvider).cancel();
  }

  /// `Kiểm tra model` — full hash verification.
  Future<void> verify() async {
    final service = ref.read(modelInstallServiceProvider);
    final result = await service.verify(onState: (next) {
      if (ref.mounted) state = next;
    });
    await _syncDatabase(result);
  }

  /// `Xóa` — deletes every byte the install added, then the DB row.
  Future<void> delete() async {
    final service = ref.read(modelInstallServiceProvider);
    final result = await service.delete();
    if (ref.mounted) state = result;
    await ref.read(documentRepositoryProvider).forgetModel(VieNeuModelManifest.modelId);
  }

  /// Mirrors the install state into the `models` table (SRS §35) so the Model
  /// Manager's record survives a restart and the active model is unambiguous.
  Future<void> _syncDatabase(ModelInstallState state) async {
    try {
      final repository = ref.read(documentRepositoryProvider);
      if (state.stage == ModelInstallStage.installed) {
        await repository.upsertModel(
          VoicePreset(
            id: VieNeuModelManifest.modelId,
            label: VieNeuModelManifest.checkpointName,
            language: 'vi-VN',
            engineId: 'vieneu-onnx-v3-turbo',
            license: VieNeuModelManifest.license,
            isInstalled: true,
            sizeBytes: state.installedBytes,
          ),
          state.modelPath ?? ref.read(modelInstallServiceProvider).modelPath,
          VieNeuModelManifest.manifestDigest,
        );
      }
    } catch (error, stack) {
      // A bookkeeping failure must not make a verified install look broken.
      AppLog.error('model.db.syncFailed', error: error, stackTrace: stack);
    }
  }
}

final modelInstallControllerProvider =
    NotifierProvider<ModelInstallController, ModelInstallState>(
  ModelInstallController.new,
);

/// Just the fact the read-aloud screen needs: is a verified model installed?
///
/// A separate provider so the reader does not rebuild on every progress tick.
///
/// `false` while the documents directory is still resolving (or is unavailable):
/// there is no audited checkpoint this session could read with, so the honest
/// answer the button needs is "not ready" — and asking before storage exists must
/// not throw out of a `build`.
final modelReadyProvider = Provider<bool>((ref) {
  if (ref.watch(appDocumentsDirectoryProvider).value == null) return false;
  return ref.watch(modelInstallControllerProvider.select((s) => s.engineUsable));
});
