import '../../core/result/result.dart';
import '../../domain/engines/tts_engine.dart';
import '../../domain/models/tts.dart' show AudioResult, TtsOptions;

/// The engine the app ships with **until a Vietnamese checkpoint is bundled**.
///
/// This is not a test double and not a stub that pretends to work: it is the
/// honest state of the product today, and it exists so that state is a *typed*
/// one the UI can act on rather than a crash or a spinner. SRS §47 warns that
/// different VieNeu checkpoints carry different licenses, so the model is
/// deliberately not in the repository; until that decision is made, every
/// read-aloud request must resolve to "model chưa cài" and route to the Models
/// tab (the state the spec already specifies).
///
/// `isReady` is `false`, so the read-aloud button stays disabled and nothing is
/// ever sent to the player — the app never claims to be reading when it is not.
class ModelMissingTtsEngine implements TtsEngine {
  const ModelMissingTtsEngine({
    this.modelId = 'vieneu-tts',
    this.licenseNote,
  });

  /// Model this slot expects to hold once a checkpoint is chosen.
  final String modelId;

  /// Shown by the Model Manager so a release decision can be made in the app.
  final String? licenseNote;

  @override
  String get id => 'model-missing';

  @override
  String get displayName => 'Chưa có model đọc tiếng Việt';

  @override
  bool get isReady => false;

  @override
  Future<Result<AudioResult>> synthesize(String text, TtsOptions options) async {
    return Result<AudioResult>.failure(
      ModelUnavailableFailure(
        message: 'Chưa cài model đọc tiếng Việt. Cần mạng để tải model.',
        modelId: modelId,
      ),
    );
  }

  @override
  Future<void> close() async {}
}
