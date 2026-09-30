import 'dart:async';

import '../../core/logging/app_log.dart';
import '../../core/result/result.dart';
import '../engines/tts_engine.dart';
import '../models/reading.dart';
import '../models/tts.dart';
import '../text/sentence_splitter.dart';
import '../text/text_normalizer.dart';
import 'synthesis_cache.dart';

/// The FR-09 pipeline as a queue: normalize → split → synthesize **one sentence
/// at a time**, with a bounded look-ahead.
///
/// FR-12 is a correctness rule here, not an optimisation: the audio for
/// sentence 1 must exist before sentence 200 does, so playback starts on the
/// first sentence instead of after the whole document. Nothing in this class
/// holds more than [lookAhead] sentences of work in advance, and a change to
/// the text or the options cancels what was in flight rather than finishing
/// audio nobody will hear (NFR-04).
///
/// The queue owns the whole [SentenceStatus] machine, including the playback
/// states: the Listening Spine and the sentence ruler read the same list, so
/// they cannot disagree about which sentence is being spoken.
class SentenceSynthesisQueue {
  SentenceSynthesisQueue({
    required TtsEngine engine,
    required SynthesisCache cache,
    this.lookAhead = 2,
    TextNormalizer normalizer = const TextNormalizer(),
    SentenceSplitter splitter = const SentenceSplitter(),
    DateTime Function() clock = DateTime.now,
  })  : _engine = engine,
        _cache = cache,
        _normalizer = normalizer,
        _splitter = splitter,
        _clock = clock;

  final TtsEngine _engine;
  final SynthesisCache _cache;
  final TextNormalizer _normalizer;
  final SentenceSplitter _splitter;

  /// Reads the wall clock used to measure how long synthesis took.
  ///
  /// Injectable so the measurement can be tested. `tester.pump()` advances
  /// Flutter's *fake* time while a real `DateTime.now()` does not move, so a
  /// fake engine that delays 4 seconds of fake time still measures as ~0 ms —
  /// and a test that cannot reach a slow device cannot test what a slow device
  /// does. Only the two behaviours that need it pass anything else.
  final DateTime Function() _clock;

  /// How many sentences after the requested one are synthesized ahead.
  /// Deliberately small: every extra sentence costs RAM and CPU on a phone
  /// (NFR-04/NFR-05), and only the next one is likely to be heard soon.
  final int lookAhead;

  final StreamController<List<Sentence>> _changes =
      StreamController<List<Sentence>>.broadcast();

  List<Sentence> _sentences = const <Sentence>[];
  final Map<int, Future<Result<AudioResult>>> _inFlight =
      <int, Future<Result<AudioResult>>>{};

  TtsOptions _options = const TtsOptions();

  /// Bumped by every [load] and [invalidateFrom]. Work that finishes against a
  /// stale generation is dropped instead of published, so a slow synthesis of
  /// the previous text can never overwrite the current one.
  int _generation = 0;

  bool _disposed = false;

  /// Sentences in reading order with their current status.
  List<Sentence> get sentences => List<Sentence>.unmodifiable(_sentences);

  /// Emits the full list on every status change. Both the Spine and the ruler
  /// subscribe to this one stream.
  Stream<List<Sentence>> get changes => _changes.stream;

  TtsOptions get options => _options;

  int get length => _sentences.length;

  /// Replaces the contents from [rawText] and cancels everything in flight.
  ///
  /// Order follows SRS §12 (normalize → split → synthesize). [Sentence.text] is
  /// therefore the **normalized** sentence — what gets spoken — while the
  /// reader keeps showing the user's original text.
  Future<List<Sentence>> load(
    String rawText, {
    required TtsOptions options,
  }) async {
    _generation++;
    _inFlight.clear();
    _options = options;

    final normalized = _normalizer.normalize(rawText);
    final texts = _splitter.split(normalized);
    _sentences = <Sentence>[
      for (var i = 0; i < texts.length; i++)
        Sentence(
          index: i,
          text: texts[i],
          // Read-aloud is a flat text stream, so every sentence belongs to the
          // same synthetic block. Phase 3 supplies real block ids.
          blockId: 'read-aloud',
        ),
    ];

    AppLog.info('speech.queue.loaded', data: <String, Object?>{
      'sentences': texts.length,
      'text': AppLog.textDigest(rawText),
    });
    _publish();
    return sentences;
  }

  /// Audio for sentence [index], synthesized now when it is not cached.
  ///
  /// Resolves as soon as *that* sentence is ready; [lookAhead] successors are
  /// warmed in the background, which is what makes playback start before the
  /// document is finished.
  ///
  /// Repeated calls for the same index join the in-flight synthesis instead of
  /// starting a second one, so a tap-happy user cannot double the CPU cost.
  Future<Result<AudioResult>> audioAt(int index) {
    if (index < 0 || index >= _sentences.length) {
      return Future<Result<AudioResult>>.value(
        Result.failure(
          NotFoundFailure(message: 'Câu ${index + 1} không tồn tại.'),
        ),
      );
    }

    final pending = _inFlight[index];
    if (pending != null) return pending;

    final generation = _generation;
    final requested = _synthesize(index, generation);
    _inFlight[index] = requested;

    var warmed = 0;
    for (var ahead = 1; ahead <= lookAhead; ahead++) {
      final next = index + ahead;
      if (next >= _sentences.length) break;
      if (_inFlight.containsKey(next)) continue;
      final status = _sentences[next].status;
      // Already synthesized at these options: no reason to spend CPU again.
      if (status == SentenceStatus.ready || status == SentenceStatus.played) {
        continue;
      }
      _inFlight[next] = _synthesize(next, generation);
      warmed++;
    }
    if (warmed > 0) {
      AppLog.debug('speech.queue.warmed',
          data: <String, Object?>{'from': index, 'ahead': warmed});
    }
    return requested;
  }

  /// Drops every sentence from [fromIndex] on: it was synthesized with the old
  /// options and would sound wrong (FR-10).
  ///
  /// Sentences before [fromIndex] keep their audio, so changing speed does not
  /// throw away what was already heard, and passing `fromIndex: current + 1`
  /// is what keeps the change from restarting the sentence mid-word.
  void invalidateFrom(int fromIndex, {TtsOptions? options}) {
    _generation++;
    _inFlight.clear();
    if (options != null) _options = options;

    final start = fromIndex.clamp(0, _sentences.length);
    for (var i = start; i < _sentences.length; i++) {
      _sentences[i] = _sentences[i].copyWith(
        status: SentenceStatus.idle,
        audioPath: null,
        durationMs: null,
        // The measurement described work that has just been thrown away; keeping
        // it would make the surface quote a cost for audio that no longer exists.
        synthesisMs: null,
        failureMessage: null,
      );
    }
    AppLog.info('speech.queue.invalidated',
        data: <String, Object?>{'from': fromIndex});
    _publish();
  }

  /// Clears the failure on [index] so the next [audioAt] tries again.
  void retry(int index) {
    if (index < 0 || index >= _sentences.length) return;
    _inFlight.remove(index);
    _sentences[index] = _sentences[index].copyWith(
      status: SentenceStatus.idle,
      failureMessage: null,
    );
    _publish();
  }

  /// Marks [index] as being spoken, and releases any sentence that was speaking
  /// before it — at most one sentence may carry the Spine.
  void markPlaying(int index) {
    for (var i = 0; i < _sentences.length; i++) {
      final status = _sentences[i].status;
      if (i == index) {
        _sentences[i] = _sentences[i].copyWith(status: SentenceStatus.playing);
      } else if (status == SentenceStatus.playing) {
        _sentences[i] = _sentences[i].copyWith(status: SentenceStatus.played);
      }
    }
    _publish();
  }

  /// Marks [index] as finished. Playback follows the reading order, so the
  /// sentence it came from is the one that just ended.
  void markPlayed(int index) {
    if (index < 0 || index >= _sentences.length) return;
    _sentences[index] = _sentences[index].copyWith(status: SentenceStatus.played);
    _publish();
  }

  /// Audio already known for [index], without synthesizing anything.
  AudioResult? audioFor(int index) {
    if (index < 0 || index >= _sentences.length) return null;
    final sentence = _sentences[index];
    final path = sentence.audioPath;
    final durationMs = sentence.durationMs;
    if (path == null || durationMs == null) return null;
    return AudioResult(
      path: path,
      duration: Duration(milliseconds: durationMs),
      textHash: _options.cacheKey(sentence.text),
      voiceId: _options.voiceId,
      speed: _options.speed,
      cacheHit: true,
    );
  }

  Future<void> dispose() async {
    _disposed = true;
    _generation++;
    _inFlight.clear();
    await _changes.close();
  }

  // ---------------------------------------------------------------------------

  Future<Result<AudioResult>> _synthesize(int index, int generation) async {
    final sentence = _sentences[index];
    final key = _options.cacheKey(sentence.text);

    Future<Result<AudioResult>> finish(Result<AudioResult> result) {
      if (generation == _generation) _inFlight.remove(index);
      return Future<Result<AudioResult>>.value(result);
    }

    final cached = await _cache.find(key);
    if (generation != _generation) {
      return const Result<AudioResult>.failure(CancelledFailure());
    }
    if (cached != null) {
      final hit = AudioResult(
        path: cached.path,
        duration: cached.duration,
        textHash: cached.textHash,
        sampleRate: cached.sampleRate,
        channels: cached.channels,
        voiceId: cached.voiceId,
        speed: cached.speed,
        cacheHit: true,
      );
      _setStatus(index, SentenceStatus.ready, audio: hit);
      AppLog.debug('speech.cache.hit',
          data: <String, Object?>{'sentence': index});
      return finish(Result<AudioResult>.success(hit));
    }

    _setStatus(index, SentenceStatus.synthesizing);
    AppLog.debug('speech.synthesize',
        data: <String, Object?>{'sentence': index});

    // Measured around the engine call only, so it is the cost of making audio —
    // not the cost of a cache lookup that skipped the work, and not the time the
    // UI happened to sit idle. This is what lets the surface say "câu này mất
    // khoảng N giây" from a fact rather than a guess.
    final startedAt = _clock();
    final Result<AudioResult> result =
        await _engine.synthesize(sentence.text, _options);
    final synthesisMs = _clock().difference(startedAt).inMilliseconds;

    if (generation != _generation) {
      return const Result<AudioResult>.failure(CancelledFailure());
    }

    switch (result) {
      case Success<AudioResult>(:final value):
        await _cache.save(key, value);
        if (generation != _generation) {
          return const Result<AudioResult>.failure(CancelledFailure());
        }
        _setStatus(index, SentenceStatus.ready, audio: value, synthesisMs: synthesisMs);
      case Failure<AudioResult>(:final failure):
        AppLog.error('speech.synthesize.failed',
            data: <String, Object?>{'sentence': index}, error: failure.message);
        _setStatus(index, SentenceStatus.failed,
            failureMessage: failure.message, synthesisMs: synthesisMs);
    }
    return finish(result);
  }

  void _setStatus(
    int index,
    SentenceStatus status, {
    AudioResult? audio,
    int? synthesisMs,
    String? failureMessage,
  }) {
    if (index < 0 || index >= _sentences.length) return;
    _sentences[index] = _sentences[index].copyWith(
      status: status,
      audioPath: audio?.path ?? _sentences[index].audioPath,
      durationMs: audio?.duration.inMilliseconds ?? _sentences[index].durationMs,
      synthesisMs: synthesisMs ?? _sentences[index].synthesisMs,
      failureMessage: failureMessage,
    );
    _publish();
  }

  void _publish() {
    if (_disposed || _changes.isClosed) return;
    _changes.add(sentences);
  }
}
