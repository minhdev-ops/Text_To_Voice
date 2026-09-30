import '../../domain/models/tts.dart';
import '../../domain/speech/synthesis_cache.dart';
import '../repository/document_repository.dart';

/// Persistent synthesis cache backed by the `tts_audio` table (SRS §32).
///
/// Implements the same [SynthesisCache] interface as [InMemorySynthesisCache]
/// so the sentence queue doesn't need to change. The [SynthesisCache] key is
/// `TtsOptions.cacheKey`, which already folds the text, voice, speed, volume
/// and format together — so a single `textHash` column lookup is enough to
/// honour SRS §32's "never re-synthesize" rule.
class PersistentSynthesisCache implements SynthesisCache {
  PersistentSynthesisCache(this._repository);

  final DocumentRepository _repository;

  @override
  Future<AudioResult?> find(String key) => _repository.getCachedAudio(key);

  @override
  Future<void> save(String key, AudioResult result) =>
      _repository.cacheAudio(key, result);

  @override
  Future<void> clear() async {
    // Not implemented for persistent cache; use cleanupAudioCache instead.
  }
}
