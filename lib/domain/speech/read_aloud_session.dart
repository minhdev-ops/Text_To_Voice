import 'dart:async';

import 'package:flutter/foundation.dart' show immutable;

import '../../core/logging/app_log.dart';
import '../../core/result/result.dart';
import '../engines/audio_output.dart';
import '../models/reading.dart';
import '../models/tts.dart';
import 'sentence_synthesis_queue.dart';

/// Everything the read-aloud surface renders, as one value.
///
/// One immutable state for the whole surface (not a set of independent flags)
/// because the transport bar, the sentence ruler and the Listening Spine are
/// three views of the same facts: which sentence is being spoken, what is ready
/// to be spoken, and what failed.
@immutable
class ReadAloudState {
  const ReadAloudState({
    this.sentences = const <Sentence>[],
    this.currentIndex = 0,
    this.isPlaying = false,
    this.positionInSentence = Duration.zero,
    this.failedSentenceIndex,
    this.failureMessage,
    this.finished = false,
  });

  final List<Sentence> sentences;

  /// Index into [sentences] — the sentence the Spine is on.
  final int currentIndex;

  final bool isPlaying;

  /// Offset inside the current sentence, for the ruler's free-scrub state.
  final Duration positionInSentence;

  /// A sentence that could not be synthesized and was skipped. Playback
  /// continues regardless; this only drives the banner and `Retry sentence`.
  final int? failedSentenceIndex;
  final String? failureMessage;

  /// Playback reached the end of the document.
  final bool finished;

  bool get isEmpty => sentences.isEmpty;

  int get total => sentences.length;

  Sentence? get current =>
      currentIndex >= 0 && currentIndex < sentences.length
          ? sentences[currentIndex]
          : null;

  /// Elapsed audio before the current sentence plus the offset inside it.
  ///
  /// Sums the *actual* measured durations (`Duration` from the engine), never
  /// an estimate from text length — the SRS forbids fake-precise numbers.
  Duration get elapsed {
    var total = positionInSentence;
    for (var i = 0; i < currentIndex && i < sentences.length; i++) {
      total += Duration(milliseconds: sentences[i].durationMs ?? 0);
    }
    return total;
  }

  /// Duration of every sentence already synthesized. Grows while the document
  /// is being prepared, which is why the transport bar renders it as the
  /// "known so far" figure rather than pretending to know the final total.
  Duration get knownDuration {
    var total = Duration.zero;
    for (final sentence in sentences) {
      total += Duration(milliseconds: sentence.durationMs ?? 0);
    }
    return total;
  }

  bool get hasAnyAudio =>
      sentences.any((s) => s.status == SentenceStatus.ready);

  /// How long a sentence cost to synthesize, in milliseconds, or `null` until one
  /// has been measured.
  ///
  /// The **slowest** measurement, not the average: this is a wait estimate, and
  /// the number that decides whether someone thinks the app is stuck is the
  /// longest wait, not the typical one. An average would understate it, and a
  /// progress message must never be quietly optimistic.
  int? get synthesisMs {
    final measured = <int>[
      for (final sentence in sentences)
        if (sentence.synthesisMs != null) sentence.synthesisMs!,
    ];
    if (measured.isEmpty) return null;
    return measured.reduce((a, b) => a > b ? a : b);
  }

  /// How many sentences a speed change would throw away right now.
  ///
  /// FR-10 keeps the sentence being spoken and re-synthesizes everything after
  /// it, which is correct and — on a phone where a sentence takes seconds to
  /// make — expensive enough that the user deserves to be told before it
  /// happens, not after.
  int get sentencesAfterCurrent {
    final remaining = sentences.length - (currentIndex + 1);
    return remaining < 0 ? 0 : remaining;
  }

  ReadAloudState copyWith({
    List<Sentence>? sentences,
    int? currentIndex,
    bool? isPlaying,
    Duration? positionInSentence,
    Object? failedSentenceIndex = _unset,
    Object? failureMessage = _unset,
    bool? finished,
  }) =>
      ReadAloudState(
        sentences: sentences ?? this.sentences,
        currentIndex: currentIndex ?? this.currentIndex,
        isPlaying: isPlaying ?? this.isPlaying,
        positionInSentence: positionInSentence ?? this.positionInSentence,
        failedSentenceIndex: identical(failedSentenceIndex, _unset)
            ? this.failedSentenceIndex
            : failedSentenceIndex as int?,
        failureMessage: identical(failureMessage, _unset)
            ? this.failureMessage
            : failureMessage as String?,
        finished: finished ?? this.finished,
      );

  static const Object _unset = Object();
}

/// Sentence-addressable playback over a [SentenceSynthesisQueue] (FR-11).
///
/// Playback is expressed in *sentences*, never in raw offsets: every transport
/// action, every seek and every speed change resolves to a sentence boundary, so
/// text and audio cannot drift apart. The two rules this class exists to
/// enforce:
///
/// * **a failed sentence is skipped, not fatal** — one bad sentence must not
///   stop the document (Phase 1 todo 16);
/// * **a speed change never restarts what is already being spoken** (FR-10);
///   it applies from the next sentence.
class ReadAloudSession {
  ReadAloudSession({
    required SentenceSynthesisQueue queue,
    required AudioOutput output,
    TtsOptions options = const TtsOptions(),
  })  : _queue = queue,
        _output = output,
        _options = options {
    _queueSubscription = _queue.changes.listen(_onQueueChanged);
    _completedSubscription = _output.completed.listen((_) => _onCompleted());
    _positionSubscription = _output.position.listen(_onPosition);
  }

  final SentenceSynthesisQueue _queue;
  final AudioOutput _output;

  late final StreamSubscription<List<Sentence>> _queueSubscription;
  late final StreamSubscription<void> _completedSubscription;
  late final StreamSubscription<Duration> _positionSubscription;

  final StreamController<ReadAloudState> _states =
      StreamController<ReadAloudState>.broadcast();

  ReadAloudState _state = const ReadAloudState();
  TtsOptions _options;
  bool _disposed = false;

  /// Incremented by every playback request so a slower previous request cannot
  /// finish later and steal the transport. Without this, tapping a sentence
  /// while the current one is still synthesizing can leave audio playing from a
  /// sentence the user has already moved on from.
  int _request = 0;

  Stream<ReadAloudState> get states => _states.stream;

  ReadAloudState get state => _state;

  TtsOptions get options => _options;

  /// Loads [rawText] and starts reading it from the first sentence.
  Future<void> read(String rawText, {TtsOptions? options}) async {
    if (options != null) _options = options;
    _request++;
    await _output.stop();

    final sentences = await _queue.load(rawText, options: _options);
    _set(_state.copyWith(
      sentences: sentences,
      currentIndex: 0,
      isPlaying: false,
      positionInSentence: Duration.zero,
      failedSentenceIndex: null,
      failureMessage: null,
      finished: false,
    ));

    if (sentences.isEmpty) {
      AppLog.info('speech.read.empty');
      return;
    }
    await _playFrom(0);
  }

  Future<void> play() async {
    if (_state.sentences.isEmpty || _state.isPlaying) return;
    final start = _state.finished ? 0 : _state.currentIndex;
    await _playFrom(start);
  }

  Future<void> pause() async {
    if (!_state.isPlaying) return;
    _request++;
    await _output.pause();
    _set(_state.copyWith(isPlaying: false));
  }

  Future<void> toggle() => _state.isPlaying ? pause() : play();

  /// Moves to the next sentence, playing it if the transport was playing.
  Future<void> next() => _seekTo(_state.currentIndex + 1);

  /// Moves to the previous sentence. Seeking back is always a deliberate act,
  /// so it starts that sentence from its beginning.
  Future<void> previous() => _seekTo(_state.currentIndex - 1);

  /// Tap on a sentence in the reader or a tick in the ruler (FR-12 seeking
  /// always snaps to a sentence).
  Future<void> seekToSentence(int index) => _seekTo(index);

  /// Changes speed for the **next** sentence onward (FR-10).
  ///
  /// The sentence being spoken keeps the audio it started with, so its words do
  /// not change rate mid-sentence; everything after it is re-synthesized.
  Future<void> setSpeed(double speed) async {
    final clamped = speed.clamp(TtsOptions.minSpeed, TtsOptions.maxSpeed);
    if (clamped == _options.speed) return;

    _options = _options.copyWith(speed: clamped);
    _queue.invalidateFrom(_state.currentIndex + 1, options: _options);
    await _output.setSpeed(clamped);
    _set(_state.copyWith(finished: false));
  }

  /// Volume is a playback property, not a synthesis one: it changes the sound
  /// without invalidating a single cached sentence (see [TtsOptions.cacheKey]).
  Future<void> setVolume(double volume) async {
    _options = _options.copyWith(volume: volume);
    await _output.setVolume(_options.volume);
  }

  /// Dismisses the skipped-sentence banner without retrying it.
  void dismissFailure() =>
      _set(_state.copyWith(failedSentenceIndex: null, failureMessage: null));

  /// Retries the sentence that failed, then continues from it.
  Future<void> retryFailed() async {
    final index = _state.failedSentenceIndex;
    if (index == null) return;
    _queue.retry(index);
    _set(_state.copyWith(failedSentenceIndex: null, failureMessage: null));
    await _seekTo(index);
  }

  /// Stops playback and clears the queue's playback marking, keeping the text.
  Future<void> stop() async {
    _request++;
    await _output.stop();
    _set(_state.copyWith(isPlaying: false, positionInSentence: Duration.zero));
  }

  Future<void> dispose() async {
    _disposed = true;
    _request++;
    await _queueSubscription.cancel();
    await _completedSubscription.cancel();
    await _positionSubscription.cancel();
    // Stop, don't dispose: the output and the queue are owned by their own
    // providers, and the session chain can rebuild underneath us (engine swap
    // after the model audit finishes) while those providers stay alive.
    await _output.stop();
    await _states.close();
  }

  // ---------------------------------------------------------------------------

  /// Walks forward from [startIndex] until a sentence actually produces audio.
  ///
  /// A loop rather than recursion: a document where every sentence fails must
  /// not become a stack overflow on top of a synthesis failure.
  Future<void> _playFrom(int startIndex) async {
    final request = ++_request;
    final sentences = _state.sentences;

    for (var index = startIndex; index < sentences.length; index++) {
      if (request != _request || _disposed) return;

      final result = await _queue.audioAt(index);
      if (request != _request || _disposed) return;

      switch (result) {
        case Success<AudioResult>(:final value):
          _queue.markPlaying(index);
          // The skipped-sentence banner is deliberately **not** cleared here:
          // playback moving on is not the same as the failure being resolved,
          // so it stays until the user retries or dismisses it.
          _set(_state.copyWith(
            currentIndex: index,
            isPlaying: true,
            positionInSentence: Duration.zero,
            finished: false,
          ));
          // Each call is named before it is awaited: a device that goes silent
          // leaves its last printed stage as the exact await it stalled in.
          AppLog.info('speech.play.speed',
              data: <String, Object?>{'speed': _options.speed});
          await _output.setSpeed(_options.speed);
          if (request != _request || _disposed) return;
          AppLog.info('speech.play.call',
              data: <String, Object?>{'sentence': index});
          await _output.play(value.path, volume: _options.volume);
          AppLog.info('speech.play.returned',
              data: <String, Object?>{'sentence': index});
          return;
        case Failure<AudioResult>(:final failure):
          // Superseded by a newer request: not a failure the user should see.
          if (failure is CancelledFailure) return;
          // NFR-02: the position and the reason are logged, never the sentence
          // text itself.
          AppLog.warning('speech.sentence.skipped', data: <String, Object?>{
            'sentence': index,
            'reason': failure.message,
          });
          _set(_state.copyWith(
            failedSentenceIndex: index,
            failureMessage: failure.message,
            isPlaying: true,
          ));
      }
    }

    // Nothing in the remaining document could be synthesized.
    _set(_state.copyWith(
      isPlaying: false,
      finished: true,
      positionInSentence: Duration.zero,
    ));
  }

  Future<void> _seekTo(int index) async {
    if (_state.sentences.isEmpty) return;
    final target = index.clamp(0, _state.sentences.length - 1);
    final wasPlaying = _state.isPlaying;

    _request++;
    await _output.stop();

    if (!wasPlaying) {
      _set(_state.copyWith(
        currentIndex: target,
        positionInSentence: Duration.zero,
        finished: false,
      ));
      return;
    }
    await _playFrom(target);
  }

  void _onCompleted() {
    if (!_state.isPlaying || _disposed) return;
    final finished = _state.currentIndex;
    _queue.markPlayed(finished);

    if (finished + 1 >= _state.sentences.length) {
      AppLog.info('speech.read.finished',
          data: <String, Object?>{'sentences': _state.sentences.length});
      _set(_state.copyWith(
        isPlaying: false,
        finished: true,
        positionInSentence: Duration.zero,
      ));
      return;
    }
    unawaited(_playFrom(finished + 1));
  }

  void _onPosition(Duration position) {
    if (!_state.isPlaying || _disposed) return;
    _set(_state.copyWith(positionInSentence: position));
  }

  void _onQueueChanged(List<Sentence> sentences) {
    if (_disposed) return;
    _set(_state.copyWith(sentences: sentences));
  }

  void _set(ReadAloudState next) {
    if (_disposed || _states.isClosed) return;
    _state = next;
    _states.add(next);
  }
}
