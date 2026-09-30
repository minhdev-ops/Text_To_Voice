import '../models/tts.dart' show AudioResult;

/// Audio that has already been synthesized — SRS §32 `tts_audio`.
///
/// Keyed by [TtsOptions.cacheKey], which folds the voice, speed, volume and
/// format in alongside the text. That is what makes SRS §32's rule ("re-reading
/// the same text must not re-synthesize") true *without* becoming wrong: audio
/// generated at `1.0x` can never be served for a `1.5x` request.
///
/// Phase 1 ships the in-memory implementation; Phase 5 swaps in the `tts_audio`
/// table and the queue does not change.
abstract interface class SynthesisCache {
  /// `null` when the key has never been synthesized.
  Future<AudioResult?> find(String key);

  Future<void> save(String key, AudioResult result);

  Future<void> clear();
}

/// Bounded, insertion-ordered cache.
///
/// The bound is not decoration: NFR-04/NFR-05 ask low-memory mode to cap the
/// audio cache, and an unbounded map over a 500-page document would be exactly
/// the whole-document retention the SRS forbids.
///
/// Honest limitation: this does not survive process death, so a cold start
/// re-synthesizes. Persistence is Phase 5's job (SRS §32).
class InMemorySynthesisCache implements SynthesisCache {
  InMemorySynthesisCache({this.maxEntries = 256});

  /// Upper bound on retained entries; the oldest is evicted first.
  final int maxEntries;

  final Map<String, AudioResult> _entries = <String, AudioResult>{};

  int get length => _entries.length;

  @override
  Future<AudioResult?> find(String key) async => _entries[key];

  @override
  Future<void> save(String key, AudioResult result) async {
    // Re-inserting moves the key to the young end, so a hot sentence is not
    // evicted by a cold one.
    _entries.remove(key);
    _entries[key] = result;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  @override
  Future<void> clear() async => _entries.clear();
}
