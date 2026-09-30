import 'dart:async';
import 'dart:io' show File;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart'
    show BackgroundIsolateBinaryMessenger, RootIsolateToken;

import '../../core/logging/app_log.dart';
import '../../core/result/result.dart';
import '../onnx/flutter_onnx_session_factory.dart';
import '../onnx/onnx_session.dart';
import 'npz_reader.dart';
import 'vieneu_config.dart';
import 'vieneu_heads.dart';
import 'vieneu_pipeline.dart';
import 'vieneu_tokenizer.dart';

/// One synthesis request. Plain data only — this crosses an isolate boundary.
class VieNeuSynthesisJob {
  const VieNeuSynthesisJob({
    required this.phonemes,
    required this.speakerEmbedding,
    required this.refCodes,
    required this.refFrames,
    this.temperature = VieNeuPipeline.defaultTemperature,
    this.topK = VieNeuPipeline.defaultTopK,
    this.topP = VieNeuPipeline.defaultTopP,
    this.maxNewFrames = VieNeuPipeline.defaultMaxNewFrames,
    this.repetitionPenalty = VieNeuPipeline.defaultRepetitionPenalty,
    this.repetitionWindow = 64,
  });

  final String phonemes;
  final Float32List speakerEmbedding;
  final Int32List refCodes;
  final int refFrames;
  final double temperature;
  final int topK;
  final double topP;
  final int maxNewFrames;
  final double repetitionPenalty;
  final int repetitionWindow;
}

/// Something that can synthesize a job and be shut down.
///
/// The engine depends on this rather than on the concrete worker, so the whole
/// read-aloud path can be tested without loading 165 MB of weights, and so a
/// future engine (a different checkpoint, an fp32 export) is a swap here.
abstract interface class VieNeuSynthesizer {
  Future<Result<SynthesisOutput>> synthesize(
    VieNeuSynthesisJob job, {
    Duration? timeout,
  });

  Future<void> dispose();
}

/// Runs the whole TTS pipeline **inside one worker isolate**.
///
/// Why the work lives here rather than on the UI isolate: one sentence is ~40
/// frame iterations, each with 17 acoustic-decoder runs, 16 logit matrix-vector
/// products over a 1024×768 table, and a backbone step with a 24-tensor cache.
/// On the main isolate that is seconds of jank per sentence (NFR-03).
///
/// Why it is a *single* isolate for all four graphs: an ONNX session owns a
/// native handle and cannot be moved between isolates, so the sessions must be
/// created where they are used. A separate isolate per graph would work and be
/// slower — every acoustic step would cross an isolate boundary — and would hold
/// the weights four times over.
///
/// The reply routing rule that the old single-model host established still
/// applies and is preserved here: **replies are keyed by request id, not queued.**
/// A FIFO queue is correct until one request times out, after which every
/// answer is delivered to the wrong caller.
class VieNeuSynthesisWorker implements VieNeuSynthesizer {
  VieNeuSynthesisWorker._({
    required SendPort commands,
    required ReceivePort responses,
    required Isolate isolate,
    required StreamSubscription<dynamic> subscription,
    required _ReplyRouter router,
    required this.isolateName,
    required this.loadTime,
    required this.loadedGraphs,
  })  : _commands = commands,
        _responses = responses,
        _isolate = isolate,
        _subscription = subscription,
        _router = router;

  /// Debug name of the isolate the sessions actually live in. Exposed because
  /// "this work runs off the UI isolate" is a claim worth being able to check.
  final String isolateName;

  /// Measured load time of the four graphs plus the weight tables.
  final Duration loadTime;

  /// Absolute paths of the four graphs created in the worker isolate. Exposed
  /// for the same reason as [isolateName]: "all four graphs live in one isolate"
  /// is a claim worth being able to check, and this is also the provenance
  /// record when a load fails.
  final List<String> loadedGraphs;

  final SendPort _commands;
  final ReceivePort _responses;
  final Isolate _isolate;
  final StreamSubscription<dynamic> _subscription;
  final _ReplyRouter _router;

  int _nextRequestId = 1;
  int _completed = 0;
  bool _closed = false;

  /// Syntheses answered so far.
  @visibleForTesting
  int get completedRequests => _completed;

  bool get isClosed => _closed;

  /// Files a synthesis needs, relative to the model directory.
  static const List<String> requiredModelFiles = <String>[
    'config.json',
    'tokenizer.json',
    'vieneu_prefill.onnx',
    'vieneu_decode_step.onnx',
    'vieneu_acoustic_cached.onnx',
    'vieneu_backbone_shared.data',
    'vieneu_v3_heads.npz',
  ];

  /// Files the codec needs.
  static const List<String> requiredCodecFiles = <String>[
    'moss_audio_tokenizer_decode_full.onnx',
    'moss_audio_tokenizer_decode_shared.data',
  ];

  /// Loads all four graphs in a worker isolate and returns a host for them.
  ///
  /// [fileExists] is injectable so the "model not installed" path is testable
  /// without a file system — and so a missing file is always a
  /// [ModelUnavailableFailure] naming that file, never a mystery load error.
  static Future<Result<VieNeuSynthesisWorker>> start({
    required String modelDirectory,
    required String codecDirectory,
    OnnxSessionFactory factory = _defaultFactory,
    Future<bool> Function(String path)? fileExists,
    String isolateLabel = 'vietdoc.vieneu',
    Duration loadTimeout = const Duration(minutes: 5),
    Duration requestTimeout = const Duration(minutes: 8),
  }) async {
    final exists = fileExists ?? _fileExists;
    for (final name in requiredModelFiles) {
      if (!await exists('$modelDirectory/$name')) {
        AppLog.warning('vieneu.model.missing', data: <String, Object?>{'file': name});
        return Result<VieNeuSynthesisWorker>.failure(ModelUnavailableFailure(
          message: 'Model đọc tiếng Việt chưa được cài đặt đầy đủ.',
          modelId: 'vieneu-v3-turbo',
          cause: 'thiếu $modelDirectory/$name',
        ));
      }
    }
    for (final name in requiredCodecFiles) {
      if (!await exists('$codecDirectory/$name')) {
        AppLog.warning('vieneu.codec.missing', data: <String, Object?>{'file': name});
        return Result<VieNeuSynthesisWorker>.failure(ModelUnavailableFailure(
          message: 'Model đọc tiếng Việt chưa được cài đặt đầy đủ.',
          modelId: 'vieneu-codec',
          cause: 'thiếu $codecDirectory/$name',
        ));
      }
    }

    final responses = ReceivePort();
    // One router from the first byte to the last: the handshake completer and
    // the request map must be the same objects both sides use, or every reply is
    // dropped as "late" while its caller waits for a timeout.
    final router = _ReplyRouter();
    unawaited(router.handshake.future.then((_) {}, onError: (_) {}));

    final subscription = responses.listen(
      router.handle,
      onError: (Object error, StackTrace stack) {
        AppLog.error('vieneu.worker.error',
            data: <String, Object?>{'error': '$error'}, error: error, stackTrace: stack);
        router.failAll('Tiến trình model gặp lỗi: $error');
      },
      onDone: () => router.failAll('Tiến trình model đã dừng.'),
    );

    Isolate? isolate;
    var keepAlive = false;
    try {
      isolate = await Isolate.spawn<_WorkerBootstrap>(
        _vieneuWorkerMain,
        _WorkerBootstrap(
          replyTo: responses.sendPort,
          modelDirectory: modelDirectory,
          codecDirectory: codecDirectory,
          factory: factory,
          rootIsolateToken: _rootIsolateToken(),
        ),
        debugName: isolateLabel,
      );

      final result = await router.handshake.future.timeout(
        loadTimeout,
        onTimeout: () => throw TimeoutException(
          'Nạp model quá lâu (>${loadTimeout.inSeconds}s).',
        ),
      );

      switch (result) {
        case _WorkerReady(
            :final isolateName,
            :final loadTime,
            :final commands,
            :final loadedGraphs,
          ):
          keepAlive = true;
          AppLog.info('vieneu.model.ready', data: <String, Object?>{
            'isolate': isolateName,
            'ms': loadTime.inMilliseconds,
          });
          final worker = VieNeuSynthesisWorker._(
            commands: commands,
            responses: responses,
            isolate: isolate,
            subscription: subscription,
            router: router,
            isolateName: isolateName,
            loadTime: loadTime,
            loadedGraphs: loadedGraphs,
          );
          worker._requestTimeout = requestTimeout;
          return Result<VieNeuSynthesisWorker>.success(worker);
        case _WorkerFailed(:final message, :final corrupt):
          return Result<VieNeuSynthesisWorker>.failure(
            _failureFor(message, corrupt: corrupt),
          );
        default:
          return Result<VieNeuSynthesisWorker>.failure(ProcessingFailure(
            message: 'Tiến trình model trả về trạng thái không mong đợi.',
            detail: '${result.runtimeType}',
          ));
      }
    } on TimeoutException catch (error) {
      AppLog.error('vieneu.load.timeout', error: error.message);
      return Result<VieNeuSynthesisWorker>.failure(ProcessingFailure(
        message: 'Nạp model quá lâu. Kiểm tra lại model rồi thử lại.',
        detail: error.message,
        cause: error,
      ));
    } catch (error, stack) {
      AppLog.error('vieneu.load.failed', error: error, stackTrace: stack);
      return Result<VieNeuSynthesisWorker>.failure(ProcessingFailure(
        message: 'Không nạp được model: $error',
        detail: stack.toString(),
        cause: error,
      ));
    } finally {
      // Nothing may leak on a failure path: a live isolate holding four loaded
      // graphs is exactly the battery drain this design exists to avoid.
      if (!keepAlive) {
        isolate?.kill(priority: Isolate.immediate);
        await subscription.cancel();
        responses.close();
        router.failAll('Phiên model đã đóng.');
      }
    }
  }

  /// Fallback only, for a caller that does not size its own request.
  ///
  /// The engine passes an explicit budget per sentence (`synthesisTimeout`),
  /// because a flat ceiling cannot serve both a one-word title and a long clause:
  /// it is generous enough not to cut short sentences off, and bounded so a
  /// request that really is stuck still reports instead of hanging the reader.
  Duration _requestTimeout = const Duration(minutes: 8);

  /// Synthesizes one sentence. Requests are serialized inside the worker, so
  /// starting a second call without awaiting is safe.
  @override
  Future<Result<SynthesisOutput>> synthesize(
    VieNeuSynthesisJob job, {
    Duration? timeout,
  }) async {
    if (_closed) {
      return const Result<SynthesisOutput>.failure(ProcessingFailure(
        message: 'Phiên model đã đóng. Mở lại tài liệu để đọc tiếp.',
      ));
    }
    try {
      final id = _nextRequestId++;
      final completer = Completer<_WorkerMessage>();
      _router.inflight[id] = completer;
      _commands.send(_SynthesizeRequest(id, job));

      final message = await completer.future.timeout(
        timeout ?? _requestTimeout,
        onTimeout: () {
          // Deregister: the worker may still answer, and that answer must be
          // dropped rather than handed to whoever asks next.
          _router.inflight.remove(id);
          throw TimeoutException('Không có phản hồi trong thời gian cho phép.');
        },
      );

      switch (message) {
        case _WorkerOutput(:final output):
          _completed++;
          return Result<SynthesisOutput>.success(output);
        case _WorkerFailed(:final message, :final corrupt):
          return Result<SynthesisOutput>.failure(
            _failureFor(message, corrupt: corrupt),
          );
        default:
          return Result<SynthesisOutput>.failure(ProcessingFailure(
            message: 'Phản hồi không mong đợi từ tiến trình model.',
            detail: '${message.runtimeType}',
          ));
      }
    } on TimeoutException catch (error) {
      return Result<SynthesisOutput>.failure(ProcessingFailure(
        message: 'Model không trả kết quả kịp. Câu này bị bỏ qua.',
        detail: error.message,
        cause: error,
      ));
    } catch (error) {
      return Result<SynthesisOutput>.failure(ProcessingFailure(
        message: 'Lỗi khi chạy model: $error',
        cause: error,
      ));
    }
  }

  /// Stops the worker and releases all four native sessions.
  @override
  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    try {
      final id = _nextRequestId++;
      final completer = Completer<_WorkerMessage>();
      _router.inflight[id] = completer;
      _commands.send(_CloseRequest(id));
      await completer.future.timeout(const Duration(seconds: 10));
    } catch (error) {
      AppLog.warning('vieneu.dispose.noAck', data: <String, Object?>{'error': '$error'});
    } finally {
      _isolate.kill(priority: Isolate.immediate);
      await _subscription.cancel();
      _responses.close();
      _router.failAll('Phiên model đã đóng.');
      AppLog.info('vieneu.model.closed');
    }
  }
}

Future<OnnxSession> _defaultFactory(String modelPath) =>
    const FlutterOnnxSessionFactory().create(modelPath);

// ---------------------------------------------------------------------------
// Worker protocol. Plain classes: each crosses an isolate boundary.
// ---------------------------------------------------------------------------

sealed class _WorkerMessage {
  const _WorkerMessage(this.requestId);
  final int? requestId;
}

class _WorkerReady extends _WorkerMessage {
  _WorkerReady(
    this.isolateName,
    this.loadTime,
    this.commands,
    this.loadedGraphs,
  ) : super(null);
  final String isolateName;
  final Duration loadTime;
  final SendPort commands;
  final List<String> loadedGraphs;
}

class _WorkerOutput extends _WorkerMessage {
  const _WorkerOutput(super.requestId, this.output);
  final SynthesisOutput output;
}

class _WorkerClosed extends _WorkerMessage {
  const _WorkerClosed(super.requestId);
}

class _WorkerFailed extends _WorkerMessage {
  const _WorkerFailed(super.requestId, this.message, {this.corrupt = false});
  final String message;
  final bool corrupt;
}

sealed class _WorkerRequest {
  const _WorkerRequest(this.requestId);
  final int requestId;
}

class _SynthesizeRequest extends _WorkerRequest {
  const _SynthesizeRequest(super.requestId, this.job);
  final VieNeuSynthesisJob job;
}

class _CloseRequest extends _WorkerRequest {
  const _CloseRequest(super.requestId);
}

/// Routes replies: the handshake (requestId `null`) or one specific in-flight
/// request. Keyed rather than queued — see the class doc.
class _ReplyRouter {
  final Completer<_WorkerMessage> handshake = Completer<_WorkerMessage>();
  final Map<int, Completer<_WorkerMessage>> inflight =
      <int, Completer<_WorkerMessage>>{};

  void handle(dynamic message) {
    if (message is! _WorkerMessage) return;
    final id = message.requestId;
    if (id == null) {
      if (!handshake.isCompleted) handshake.complete(message);
      return;
    }
    final completer = inflight.remove(id);
    if (completer != null && !completer.isCompleted) {
      completer.complete(message);
    }
    // A reply nobody waits for (already timed out) is dropped.
  }

  void failAll(String reason) {
    if (!handshake.isCompleted) {
      handshake.complete(_WorkerFailed(null, reason));
    }
    final pending = List<Completer<_WorkerMessage>>.of(inflight.values);
    inflight.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) {
        completer.complete(_WorkerFailed(null, reason));
      }
    }
  }
}

class _WorkerBootstrap {
  const _WorkerBootstrap({
    required this.replyTo,
    required this.modelDirectory,
    required this.codecDirectory,
    required this.factory,
    required this.rootIsolateToken,
  });

  final SendPort replyTo;
  final String modelDirectory;
  final String codecDirectory;
  final OnnxSessionFactory factory;
  final RootIsolateToken? rootIsolateToken;
}

/// Worker entry point: load everything once, then serve synthesis requests.
///
/// `@pragma('vm:entry-point')` keeps it reachable in a release build, where the
/// tree shaker cannot see that `Isolate.spawn` needs it.
@pragma('vm:entry-point')
Future<void> _vieneuWorkerMain(_WorkerBootstrap bootstrap) async {
  final commands = ReceivePort();
  final reply = bootstrap.replyTo;

  void report(Object error, {int? requestId, bool corrupt = true}) {
    reply.send(_WorkerFailed(requestId, error.toString(), corrupt: corrupt));
  }

  VieNeuPipeline? pipeline;
  try {
    // The ONNX binding is a plugin, so a background isolate needs its own binary
    // messenger before any channel call works.
    final token = bootstrap.rootIsolateToken;
    if (token != null) {
      try {
        BackgroundIsolateBinaryMessenger.ensureInitialized(token);
      } catch (error) {
        AppLog.debug('vieneu.messenger.unavailable',
            data: <String, Object?>{'error': '$error'});
      }
    }

    final started = DateTime.now();
    final model = bootstrap.modelDirectory;
    final codec = bootstrap.codecDirectory;

    final configResult = await VieNeuConfig.fromFile('$model/config.json');
    final config = switch (configResult) {
      Success<VieNeuConfig>(:final value) => value,
      Failure<VieNeuConfig>(:final failure) => throw failure,
    };

    final archiveResult = await NpzArchive.open(File('$model/vieneu_v3_heads.npz'));
    final archive = switch (archiveResult) {
      Success<NpzArchive>(:final value) => value,
      Failure<NpzArchive>(:final failure) => throw failure,
    };

    try {
      final headsResult = await VieNeuHeads.load(archive: archive, config: config);
      final heads = switch (headsResult) {
        Success<VieNeuHeads>(:final value) => value,
        Failure<VieNeuHeads>(:final failure) => throw failure,
      };

      final tokenizerResult = await VieNeuTokenizer.fromFile('$model/tokenizer.json');
      final tokenizer = switch (tokenizerResult) {
        Success<VieNeuTokenizer>(:final value) => value,
        Failure<VieNeuTokenizer>(:final failure) => throw failure,
      };

      // Named first so the loaded set can be reported back: the four graphs must
      // all be created *here*, in the isolate that will run them, because an
      // ONNX session owns a native handle and cannot move between isolates.
      final graphPaths = <String>[
        '$model/vieneu_prefill.onnx',
        '$model/vieneu_decode_step.onnx',
        '$model/vieneu_acoustic_cached.onnx',
        '$codec/moss_audio_tokenizer_decode_full.onnx',
      ];
      final sessions = VieNeuSessions(
        prefill: await bootstrap.factory(graphPaths[0]),
        decodeStep: await bootstrap.factory(graphPaths[1]),
        acoustic: await bootstrap.factory(graphPaths[2]),
        codec: await bootstrap.factory(graphPaths[3]),
      );
      pipeline = VieNeuPipeline(
        config: config,
        heads: heads,
        tokenizer: tokenizer,
        sessions: sessions,
      );
      reply.send(_WorkerReady(
        Isolate.current.debugName ?? '',
        DateTime.now().difference(started),
        commands.sendPort,
        graphPaths,
      ));
    } finally {
      await archive.close();
    }
  } catch (error) {
    report(error);
    await pipeline?.sessions.close();
    commands.close();
    return;
  }

  await for (final dynamic message in commands) {
    switch (message) {
      case _SynthesizeRequest(:final requestId, :final job):
        try {
          final output = await pipeline.synthesize(
            phonemes: job.phonemes,
            speakerEmbedding: job.speakerEmbedding,
            refCodes: job.refCodes,
            refFrames: job.refFrames,
            temperature: job.temperature,
            topK: job.topK,
            topP: job.topP,
            maxNewFrames: job.maxNewFrames,
            repetitionPenalty: job.repetitionPenalty,
            repetitionWindow: job.repetitionWindow,
          );
          reply.send(_WorkerOutput(requestId, output));
        } catch (error, stack) {
          AppLog.error('vieneu.synthesize.failed', error: error, stackTrace: stack);
          report(error, requestId: requestId);
        }
      case _CloseRequest(:final requestId):
        await pipeline.sessions.close();
        reply.send(_WorkerClosed(requestId));
        commands.close();
        return;
    }
  }
}

AppFailure _failureFor(String message, {required bool corrupt}) {
  if (corrupt) {
    return CorruptModelFailure(
      message: 'Model đọc tiếng Việt không chạy được. Tải lại model.',
      detail: message,
    );
  }
  return ProcessingFailure(
    message: 'Không nạp được model đọc tiếng Việt: $message',
    detail: message,
  );
}

Future<bool> _fileExists(String path) => File(path).exists();

/// The token that lets a spawned isolate use plugins. Absent outside a running
/// Flutter app, which is fine: the worker is tested against a fake factory that
/// needs no plugin.
RootIsolateToken? _rootIsolateToken() {
  try {
    return RootIsolateToken.instance;
  } catch (_) {
    return null;
  }
}
