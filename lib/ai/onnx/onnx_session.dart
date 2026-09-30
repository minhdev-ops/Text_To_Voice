import 'dart:typed_data';

import 'onnx_tensor.dart';

/// A tensor that lives **inside the native runtime**.
///
/// Only its id, shape and type are visible to Dart. `flutter_onnxruntime`
/// passes tensors between Dart and the platform by id (`runInference` sends
/// `{'valueId': id}` and nothing else — verified in the installed 1.8.5
/// `flutter_onnxruntime_method_channel.dart`), which is the property this whole
/// abstraction exists to exploit.
///
/// It matters because of scale. The backbone's KV cache is
/// `12 layers × 2 × [1, 4, T, 64]`; at `T = 150` that is ~10 MB per decode step.
/// Reading it into Dart and writing it back through a method channel would cost
/// more than the inference itself. Handles let the cache be *handed back* to the
/// next run instead of copied, and the cascade the runtime already owns stays
/// where it is.
abstract interface class OnnxHandle {
  /// Dimensions as the runtime reports them for this value.
  List<int> get shape;

  OnnxDataType get type;
}

/// A loaded ONNX model.
///
/// Implementations own a **native handle**, so an instance is only valid inside
/// the isolate that created it and must never be returned from one.
abstract interface class OnnxSession {
  /// Inputs as declared by the model graph. The graph is the authority on this:
  /// input names, their order and their output order all come from here rather
  /// than from a hard-coded list, so a re-export with different names fails at
  /// load time instead of producing a wrong result.
  List<OnnxInputInfo> get inputs;

  /// Output names in graph order.
  List<String> get outputs;

  /// Uploads plain data into a native tensor.
  ///
  /// Called for inputs the app genuinely owns — prompt embeddings, position ids
  /// and the codec's code matrix — not for anything the previous run produced.
  Future<OnnxHandle> create(OnnxTensor tensor);

  /// Runs inference. [inputs] maps graph input name to handle, and may mix
  /// handles this app created with handles returned by an earlier [run].
  ///
  /// Throws on a graph/runtime error. Callers are expected to run this inside a
  /// worker isolate (NFR-03) and map the failure to a typed one there.
  Future<Map<String, OnnxHandle>> run(Map<String, OnnxHandle> inputs);

  /// Materializes one output into plain data.
  ///
  /// Deliberately explicit: reading a value costs a channel round trip, so only
  /// the tensors the Dart side actually computes with — the 768-wide hidden
  /// state, the codec waveform, a length vector — are ever read.
  Future<OnnxTensor> read(OnnxHandle handle, String name);

  /// Releases one native tensor.
  Future<void> release(OnnxHandle handle);

  /// Releases the native session. Safe to call twice.
  Future<void> close();
}

/// Creates a session for a model file.
///
/// A seam for two reasons: the pipeline can be tested without a checkpoint, and
/// the concrete binding stays in one file.
typedef OnnxSessionFactory = Future<OnnxSession> Function(String modelPath);

/// Convenience for the codec, which returns a one-element int32 length vector
/// alongside its waveform.
Future<int> readFirstInt32(OnnxSession session, OnnxHandle handle) async {
  final tensor = await session.read(handle, 'length');
  final values = tensor.asInt32;
  return values.isEmpty ? 0 : values[0];
}

/// Materializes a float32 tensor, asserting it is one.
Future<Float32List> readFloat32(OnnxSession session, OnnxHandle handle, String name) async {
  final tensor = await session.read(handle, name);
  if (tensor.type != OnnxDataType.float32) {
    throw StateError('$name: mong đợi float32, nhận ${tensor.type.wireName}');
  }
  return tensor.asFloat32;
}
