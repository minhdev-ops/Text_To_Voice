import '../../core/result/result.dart';
import '../models/tts.dart' show AudioResult, TtsOptions;

/// Speech synthesis — SRS §27.
///
/// The seam that keeps FR-09 honest: the app depends on this interface, never
/// on a concrete engine, so swapping `VieNeuOnnxTtsEngine` for another
/// implementation does not touch a single widget. Phase 1 ships the ONNX
/// implementation; a `FakeTtsEngine` backs every test until then.
///
/// Engines are **on-device and CPU-only**: no GPU, no cloud API, no server
/// (FR-09 / NFR-01). Every method must therefore be callable with the network
/// disabled.
abstract interface class TtsEngine {
  /// Stable machine id, used as part of the synthesis cache key.
  String get id;

  /// Human-readable name for the Model Manager.
  String get displayName;

  /// `true` once the model is installed **and** loaded. Reading this must not
  /// trigger I/O — engines load lazily and report readiness afterwards.
  bool get isReady;

  /// Synthesizes one sentence.
  ///
  /// FR-12: callers pass a sentence, never a whole document. An implementation
  /// that tries to buffer an entire book here is a bug.
  ///
  /// Returns [Failure] rather than throwing, so the UI can distinguish a
  /// missing model ([ModelUnavailableFailure]) from a genuine synthesis error
  /// ([ProcessingFailure]) and say something specific.
  Future<Result<AudioResult>> synthesize(String text, TtsOptions options);

  /// Releases the session. Safe to call twice.
  Future<void> close();
}
