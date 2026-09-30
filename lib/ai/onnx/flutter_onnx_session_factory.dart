import 'dart:io' show Platform;
import 'dart:typed_data' show Float32List, Int32List, Int64List;

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import '../../core/logging/app_log.dart';
import 'onnx_session.dart';
import 'onnx_tensor.dart';

/// The only file in the app that knows `flutter_onnxruntime` exists.
///
/// Binding facts verified against the installed package (1.8.5) rather than
/// guessed: `OnnxRuntime.createSession(path, options:)`,
/// `OrtSession.getInputInfo()/getOutputInfo()`, `OrtSession.run` over
/// `Map<String, OrtValue>`, `OrtValue.fromList` (typed data only — a plain
/// `List<num>` is converted, but a `List<double>` costs an allocation per
/// element, so this file always passes typed data), and
/// `OrtValue.asFlattenedList()` for reads.
///
/// Two things about the binding shape the whole pipeline:
///
/// * **`runInference` sends only value ids.** So an output kept alive as an
///   [OnnxHandle] can be fed straight back into the next run and the KV cache
///   never crosses the channel. Copies happen only where the app computes with
///   the values.
/// * **Values are not garbage collected.** Every tensor returned by [run] is
///   owned by the caller and must be released, or native memory grows by ~10 MB
///   per decode step (NFR-04).
class FlutterOnnxSessionFactory {
  const FlutterOnnxSessionFactory();

  /// Creates the session with an explicitly **CPU-only** provider list, using
  /// XNNPACK when the runtime offers it.
  ///
  /// **No GPU, on any device.** `NNAPI`, `QNN`, `TENSOR_RT` and `CUDA` are all
  /// available in the binding and all excluded here, because SRS §18 / §64 /
  /// §458 require the TTS to run on-device on the CPU with no GPU dependency —
  /// and because a GPU path would change the numerics this app was verified
  /// against, unmeasured, on hardware this team does not own.
  ///
  /// **XNNPACK is not a GPU, and that distinction is the point.** It is an
  /// optimized CPU backend (fused kernels for the int8 matmuls this model is
  /// dominated by) that executes on the same cores as the CPU provider. Enabling
  /// it is a CPU optimization, so it satisfies the requirement rather than
  /// trading it away. It is also **asked for, never assumed**: [providers]
  /// queries what the runtime actually supports and falls back to plain CPU when
  /// XNNPACK is absent, so a device without it degrades in speed rather than
  /// failing to start.
  ///
  /// **The slowness is now a measurement, not a decision.** The baseline on a
  /// Galaxy A75 (Exynos 2200) was 13.5x realtime — 1.12 s of audio cost 15.2 s —
  /// because the acoustic decoder runs 17 sequential ONNX passes per frame and a
  /// frame budget of 80 ms buys about 4.4 ms per pass. XNNPACK targets exactly
  /// those passes. The gain is device-dependent and is **not asserted here**: the
  /// engine logs the real per-sentence cost (`tts.synthesized`), and the UI
  /// quotes that measured number, so the effect is visible rather than claimed.
  ///
  /// Even after this change, synthesis is slower than real time on a phone, and
  /// the app is built for that: sentence-level synthesis with look-ahead, a
  /// persistent cache, and a measured wait shown to the reader. The remaining
  /// cost lives in the UI, not in a stall.
  Future<OnnxSession> create(String modelPath) async {
    final runtime = OnnxRuntime();
    final providers = await _providers(runtime);
    final session = await runtime.createSession(
      modelPath,
      options: OrtSessionOptions(
        providers: providers,
        // The reference sets inter-op 1 and intra-op to half the cores (capped
        // at 8). Left at the plugin's defaults, every session spawns a pool of
        // all cores that busy-waits between ops; with four sessions loaded, that
        // is the difference between usable and not on a phone (NFR-05).
        interOpNumThreads: 1,
        intraOpNumThreads: _intraOpThreads(),
      ),
    );

    try {
      final inputs = await session.getInputInfo();
      final outputs = await session.getOutputInfo();
      return _PluginSession(
        session,
        inputs: _mapInputs(inputs),
        outputs: <String>[
          for (final entry in outputs) '${entry['name']}',
        ],
      );
    } catch (_) {
      // Do not leave a loaded graph behind when the handshake fails.
      await session.close();
      rethrow;
    }
  }

  /// XNNPACK first, plain CPU always present as the fallback.
  ///
  /// The query is not decoration: `addXnnpack` on a runtime built without the
  /// backend throws, and a session that fails to open is a
  /// `CorruptModelFailure` telling the user to re-download a perfectly good
  /// model. Asking first turns that into a slower session.
  ///
  /// Cached because it is asked once per graph and the answer cannot change
  /// within a process.
  static List<OrtProvider>? _cachedProviders;

  Future<List<OrtProvider>> _providers(OnnxRuntime runtime) async {
    final cached = _cachedProviders;
    if (cached != null) return cached;

    var providers = const <OrtProvider>[OrtProvider.CPU];
    try {
      final available = await runtime.getAvailableProviders();
      if (available.contains(OrtProvider.XNNPACK)) {
        providers = const <OrtProvider>[OrtProvider.XNNPACK, OrtProvider.CPU];
      }
    } catch (error) {
      // Some platform builds cannot answer the query. Plain CPU is always
      // correct, so an unanswered question must not fail the session.
      AppLog.warning('onnx.providers.queryFailed', data: <String, Object?>{
        'error': '$error',
      });
    }
    _cachedProviders = providers;
    AppLog.info('onnx.providers', data: <String, Object?>{
      'selected': providers.map((p) => p.name).join(','),
    });
    return providers;
  }

  static int _intraOpThreads() {
    final cores = Platform.numberOfProcessors;
    final half = cores ~/ 2;
    if (half < 1) return 1;
    return half > 8 ? 8 : half;
  }

  static List<OnnxInputInfo> _mapInputs(List<Map<String, dynamic>> info) =>
      <OnnxInputInfo>[
        for (final entry in info)
          OnnxInputInfo(
            name: entry['name'] as String,
            shape: (entry['shape'] as List<dynamic>).cast<int>(),
            type: OnnxDataType.fromWireName(entry['type'] as String?),
          ),
      ];
}

class _PluginSession implements OnnxSession {
  _PluginSession(this._session, {required this.inputs, required this.outputs});

  final OrtSession _session;

  @override
  final List<OnnxInputInfo> inputs;

  @override
  final List<String> outputs;

  @override
  Future<OnnxHandle> create(OnnxTensor tensor) async {
    final value = await OrtValue.fromList(_toTypedData(tensor), tensor.shape);
    return _PluginHandle(value, name: tensor.name);
  }

  @override
  Future<Map<String, OnnxHandle>> run(Map<String, OnnxHandle> inputs) async {
    final natives = <String, OrtValue>{
      for (final entry in inputs.entries)
        entry.key: (entry.value as _PluginHandle).value,
    };
    final outputs = await _session.run(natives);
    return <String, OnnxHandle>{
      for (final entry in outputs.entries)
        entry.key: _PluginHandle(entry.value, name: entry.key),
    };
  }

  @override
  Future<OnnxTensor> read(OnnxHandle handle, String name) async {
    final pluginHandle = handle as _PluginHandle;
    final value = pluginHandle.value;
    final list = await value.asFlattenedList();
    final type = OnnxDataType.fromWireName(value.dataType.name);
    if (type == null) {
      // Name the type instead of rounding it to float32 and producing silent
      // nonsense.
      throw UnsupportedError('Kiểu tensor chưa hỗ trợ: ${value.dataType.name}');
    }
    final numbers = list.whereType<num>().toList(growable: false);
    return OnnxTensor(
      name: name,
      type: type,
      shape: value.shape,
      data: switch (type) {
        OnnxDataType.float32 => Float32List.fromList(
            [for (final value in numbers) value.toDouble()],
          ),
        OnnxDataType.int32 => Int32List.fromList(
            [for (final value in numbers) value.toInt()],
          ),
        OnnxDataType.int64 => Int64List.fromList(
            [for (final value in numbers) value.toInt()],
          ),
      },
    );
  }

  @override
  Future<void> release(OnnxHandle handle) async {
    await (handle as _PluginHandle).value.dispose();
  }

  @override
  Future<void> close() => _session.close();

  static Object _toTypedData(OnnxTensor tensor) => switch (tensor.type) {
        OnnxDataType.float32 => tensor.asFloat32,
        OnnxDataType.int32 => tensor.asInt32,
        OnnxDataType.int64 => tensor.asInt64,
      };
}

class _PluginHandle implements OnnxHandle {
  _PluginHandle(this.value, {required this.name});

  final OrtValue value;
  final String name;

  @override
  List<int> get shape => value.shape;

  @override
  OnnxDataType get type =>
      OnnxDataType.fromWireName(value.dataType.name) ?? OnnxDataType.float32;
}
