import 'dart:async';

import '../../core/logging/app_log.dart';
import '../../core/result/result.dart';
import '../engines/tts_engine.dart';
import '../models/tts.dart';
import '../text/sentence_splitter.dart';
import '../text/text_normalizer.dart';
import 'synthesis_cache.dart';

/// How far a [BackgroundSynthesisRunner] has got.
class SynthesisProgress {
  const SynthesisProgress({
    required this.completed,
    required this.total,
    this.failed = 0,
    this.finished = false,
    this.cancelled = false,
  });

  /// Sentences whose audio is now on disk and in the cache.
  final int completed;

  /// Sentences in the document.
  final int total;

  /// Sentences that failed. They do **not** stop the run: one bad sentence must
  /// not cost the reader the other four hundred.
  final int failed;

  final bool finished;
  final bool cancelled;

  /// `null` while the total is still unknown, so the UI shows a spinner instead
  /// of a misleading `0%`.
  double? get fraction => total == 0 ? null : completed / total;

  SynthesisProgress copyWith({
    int? completed,
    int? total,
    int? failed,
    bool? finished,
    bool? cancelled,
  }) {
    return SynthesisProgress(
      completed: completed ?? this.completed,
      total: total ?? this.total,
      failed: failed ?? this.failed,
      finished: finished ?? this.finished,
      cancelled: cancelled ?? this.cancelled,
    );
  }
}

/// Synthesizes a whole document's audio up front, so reading it later is instant.
///
/// **Why this exists.** Reading used to synthesize on demand, which meant a
/// sentence could not be heard until it had been generated — the 34-second gap
/// and the ~8.7x realtime rate are what that costs on a phone. Generating the
/// document once, in advance, moves the cost to a place where the reader is not
/// waiting on it. It is also the only way "Export Audio" (FR-15) can produce a
/// complete file: the exporter merges the audio that happens to exist, so without
/// this it can only ever export a document the user happened to read to the end.
///
/// **Resuming is free.** [SynthesisCache] is keyed by
/// `text + voice + speed + volume + format` and persisted in the `tts_audio`
/// table, so a run that was interrupted at sentence 200 of 500 picks up at 201
/// rather than starting again. That is the whole resume mechanism — there is no
/// separate checkpoint to get out of sync with the audio that actually exists.
///
/// **Not a queue.** One sentence at a time, in order, never in parallel: the
/// ONNX autoregressive decoder allocates per-frame KV state and the phone has to
/// stay responsive (NFR-04/NFR-05). Concurrency here would trade the reader's
/// responsiveness for nothing.
class BackgroundSynthesisRunner {
  BackgroundSynthesisRunner({
    required TtsEngine engine,
    required SynthesisCache cache,
    TextNormalizer normalizer = const TextNormalizer(),
    SentenceSplitter splitter = const SentenceSplitter(),
  })  : _engine = engine,
        _cache = cache,
        _normalizer = normalizer,
        _splitter = splitter;

  final TtsEngine _engine;
  final SynthesisCache _cache;
  final TextNormalizer _normalizer;
  final SentenceSplitter _splitter;

  /// Generates audio for every sentence of [rawText], emitting progress as it goes.
  ///
  /// Cancellation is cooperative and checked **between** sentences: aborting
  /// mid-sentence would leave a half-written WAV in the cache, and a cache entry
  /// pointing at a truncated file is worse than a missing one, because
  /// [SynthesisCache] would serve it forever.
  ///
  /// A [ModelUnavailableFailure] stops the run rather than failing every sentence
  /// one by one — without a model there is no point spending minutes proving it.
  Stream<SynthesisProgress> generate(
    String rawText, {
    TtsOptions options = const TtsOptions(),
    bool Function()? isCancelled,
  }) async* {
    final sentences = _splitter.split(_normalizer.normalize(rawText));
    final total = sentences.length;
    var completed = 0;
    var failed = 0;

    if (total == 0) {
      AppLog.info('synthesis.background.empty');
      yield const SynthesisProgress(completed: 0, total: 0, finished: true);
      return;
    }

    if (!_engine.isReady) {
      AppLog.warning('synthesis.background.notReady', data: <String, Object?>{
        'engine': _engine.id,
      });
      yield SynthesisProgress(completed: 0, total: total, failed: total, finished: true);
      return;
    }

    AppLog.info('synthesis.background.begin', data: <String, Object?>{
      'sentences': total,
    });
    yield SynthesisProgress(completed: 0, total: total);

    for (final sentence in sentences) {
      if (isCancelled?.call() ?? false) {
        AppLog.info('synthesis.background.cancelled', data: <String, Object?>{
          'completed': completed,
          'total': total,
        });
        yield SynthesisProgress(
          completed: completed,
          total: total,
          failed: failed,
          cancelled: true,
          finished: true,
        );
        return;
      }

      final key = options.cacheKey(sentence);
      if (await _cache.find(key) == null) {
        final result = await _engine.synthesize(sentence, options);
        switch (result) {
          case Success<AudioResult>(:final value):
            await _cache.save(key, value);
          case Failure<AudioResult>(:final failure):
            failed++;
            if (failure is ModelUnavailableFailure) {
              // Every later sentence would fail the same way; saying so now
              // beats reporting thousands of identical failures.
              AppLog.warning('synthesis.background.modelMissing',
                  data: <String, Object?>{'message': failure.message});
              yield SynthesisProgress(
                completed: completed,
                total: total,
                failed: failed,
                finished: true,
              );
              return;
            }
            // NFR-02: the position is logged, never the sentence text.
            AppLog.warning('synthesis.background.sentenceFailed',
                data: <String, Object?>{
                  'index': completed + failed,
                  'message': failure.message,
                });
        }
      }

      completed++;
      yield SynthesisProgress(completed: completed, total: total, failed: failed);
    }

    AppLog.info('synthesis.background.done', data: <String, Object?>{
      'completed': completed,
      'failed': failed,
    });
    yield SynthesisProgress(
      completed: completed,
      total: total,
      failed: failed,
      finished: true,
    );
  }
}