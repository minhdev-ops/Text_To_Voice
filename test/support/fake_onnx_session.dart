import 'dart:typed_data';

import 'package:text_to_voice/ai/onnx/onnx_session.dart';
import 'package:text_to_voice/ai/onnx/onnx_tensor.dart';

/// A session that answers from Dart and never touches a native runtime.
///
/// It exists so the ONNX-*shaped* parts of the app can be exercised without a
/// checkpoint: what gets sent, which outputs get read, what gets released, and
/// whether the cache is carried forward are the parts that break silently, and
/// none of them needs real weights to check.
///
/// It is deliberately shape-aware. `hidden` comes back with the row count of the
/// tensor it was fed, because a fake that always returned `[1, 1, 8]` would make
/// the pipeline's row handling untestable — and row handling is exactly where an
/// off-by-one hides.
class FakeOnnxSession implements OnnxSession {
  FakeOnnxSession({
    this.inputs_ = const <OnnxInputInfo>[
      OnnxInputInfo(
        name: 'inputs_embeds',
        shape: <int>[1, -1, 4],
        type: OnnxDataType.float32,
      ),
    ],
    this.outputs = const <String>['hidden'],
    this.throwOnRun = false,
  });

  final List<OnnxInputInfo> inputs_;
  final List<String> outputs;
  final bool throwOnRun;

  /// Number of [run] calls — used to assert the pipeline advances rather than
  /// restarts.
  int handlesRun = 0;

  /// Tensors the app uploaded, in call order.
  final List<OnnxTensor> created = <OnnxTensor>[];

  /// Ids released, in call order. A double release shows up here.
  final List<String> released = <String>[];

  final Map<String, List<int>> _createdShapes = <String, List<int>>{};

  @override
  List<OnnxInputInfo> get inputs => inputs_;

  @override
  Future<OnnxHandle> create(OnnxTensor tensor) async {
    created.add(tensor);
    final id = '${tensor.name}#${created.length}';
    _createdShapes[id] = tensor.shape;
    return _FakeHandle(id, tensor.shape, tensor.type);
  }

  @override
  Future<Map<String, OnnxHandle>> run(Map<String, OnnxHandle> inputs) async {
    handlesRun++;
    if (throwOnRun) {
      throw StateError('graph failed after load');
    }

    final tokenInput = inputs['inputs_embeds'] ?? inputs['token_emb'];
    final rows = (tokenInput != null && tokenInput.shape.length >= 2)
        ? tokenInput.shape[1]
        : 1;
    final width = (tokenInput != null && tokenInput.shape.length >= 3)
        ? tokenInput.shape[2]
        : 4;

    final result = <String, OnnxHandle>{};
    for (final name in outputs) {
      if (name == 'hidden') {
        result[name] = _FakeHandle(
          'hidden@$handlesRun',
          <int>[1, rows, width],
          OnnxDataType.float32,
        );
      } else {
        result[name] = _FakeHandle(
          '$name@$handlesRun',
          const <int>[1, 1, 8],
          OnnxDataType.float32,
        );
      }
    }

    // Echo the cache through as new handles, which is what the real graphs do
    // (a fresh native value, not the same one handed back).
    for (final entry in inputs.entries) {
      if (!entry.key.startsWith('past_')) continue;
      final present = entry.key.replaceFirst('past_', 'present_');
      result[present] = _FakeHandle(
        '$present@$handlesRun',
        entry.value.shape,
        entry.value.type,
      );
    }
    return result;
  }

  @override
  Future<OnnxTensor> read(OnnxHandle handle, String name) async {
    final shape = handle.shape;
    final count = shape.isEmpty
        ? 1
        : shape.fold<int>(1, (product, dim) => product * dim);
    return switch (handle.type) {
      OnnxDataType.float32 => OnnxTensor.float32(
          name: name,
          shape: shape,
          values: Float32List(count),
        ),
      OnnxDataType.int32 => OnnxTensor.int32(
          name: name,
          shape: shape,
          values: Int32List(count),
        ),
      OnnxDataType.int64 => OnnxTensor.int64(
          name: name,
          shape: shape,
          values: Int64List(count),
        ),
    };
  }

  @override
  Future<void> release(OnnxHandle handle) async {
    released.add(handle is _FakeHandle ? handle.id : '?');
  }

  @override
  Future<void> close() async {}
}

class _FakeHandle implements OnnxHandle {
  _FakeHandle(this.id, this.shape, this.type);

  final String id;

  @override
  final List<int> shape;

  @override
  final OnnxDataType type;

  @override
  String toString() => 'FakeHandle($id, $shape)';
}

/// A factory for the worker's load path, with a switch for the failure case.
///
/// Outputs are chosen **per graph**, because that is what the pipeline reads:
/// the codec answers a single waveform tensor named `audio`, while the backbone,
/// acoustic and decode-step graphs answer a hidden row plus the KV-cache slots.
/// A fake that returned one global set would fail the codec read.
OnnxSessionFactory fakeSessionFactory({
  bool throwOnCreate = false,
  FakeOnnxSession? shared,
  List<String>? outputs,
}) {
  return (String path) async {
    if (throwOnCreate) {
      throw StateError('cannot load $path');
    }
    if (shared != null) return shared;
    if (outputs != null) return FakeOnnxSession(outputs: outputs);
    final isCodec = path.contains('moss_audio_tokenizer');
    return FakeOnnxSession(
      outputs: isCodec
          ? const <String>['audio']
          : const <String>['hidden', 'present_k_0', 'present_v_0'],
    );
  };
}
