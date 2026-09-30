import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable, listEquals;

/// Element type of a model tensor, limited to what this app actually exchanges.
///
/// A TTS pipeline needs exactly three: `float32` for activations, `int64` for
/// token/position ids, and `int32` for the MOSS codec, which declares
/// `audio_codes` as int32 rather than int64. The full ONNX type list is
/// deliberately not mirrored here, because an unused enum case is a claim that
/// it is handled.
enum OnnxDataType {
  float32('float32'),
  int32('int32'),
  int64('int64');

  const OnnxDataType(this.wireName);

  /// Name used by the ONNX Runtime binding.
  final String wireName;

  /// `null` for a type this app does not carry — a model declaring `float16`
  /// must fail loudly at conversion time, not silently lose precision.
  static OnnxDataType? fromWireName(String? name) {
    if (name == null) return null;
    for (final type in OnnxDataType.values) {
      if (type.wireName == name) return type;
    }
    return null;
  }
}

/// One input a model expects, as declared by the model itself.
@immutable
class OnnxInputInfo {
  const OnnxInputInfo({required this.name, required this.shape, this.type});

  final String name;

  /// Declared dimensions. A non-positive entry is a dynamic axis.
  final List<int> shape;

  final OnnxDataType? type;

  /// `true` when every axis has a known, non-zero size — the only case in which
  /// a zero-filled warm-up pass is meaningful.
  bool get hasConcreteShape => shape.isNotEmpty && shape.every((dim) => dim > 0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OnnxInputInfo &&
          other.name == name &&
          listEquals(other.shape, shape) &&
          other.type == type);

  @override
  int get hashCode => Object.hash(name, Object.hashAll(shape), type);

  @override
  String toString() => 'OnnxInputInfo($name, $shape, ${type?.wireName})';
}

/// A tensor as **plain data**: shape plus a typed payload.
///
/// Typed on purpose. The obvious signature — `List<num> values` — boxes every
/// element, and the decode loop hands 24 KV-cache tensors (~450 000 floats each)
/// across an isolate boundary per frame. Sending `Float32List` keeps that a
/// pointer move instead of half a million heap allocations.
@immutable
class OnnxTensor {
  const OnnxTensor({
    required this.name,
    required this.type,
    required this.shape,
    required this.data,
  });

  final String name;
  final OnnxDataType type;
  final List<int> shape;

  /// `Float32List` for [OnnxDataType.float32], `Int32List` for
  /// [OnnxDataType.int32], `Int64List` for [OnnxDataType.int64].
  final Object data;

  factory OnnxTensor.float32({
    required String name,
    required List<int> shape,
    required Float32List values,
  }) =>
      OnnxTensor(
          name: name, type: OnnxDataType.float32, shape: shape, data: values);

  factory OnnxTensor.int64({
    required String name,
    required List<int> shape,
    required Int64List values,
  }) =>
      OnnxTensor(
          name: name, type: OnnxDataType.int64, shape: shape, data: values);

  factory OnnxTensor.int32({
    required String name,
    required List<int> shape,
    required Int32List values,
  }) =>
      OnnxTensor(
          name: name, type: OnnxDataType.int32, shape: shape, data: values);

  /// Zero-filled tensor of [shape] — what the warm-up pass feeds the model.
  factory OnnxTensor.zeros({
    required String name,
    required OnnxDataType type,
    required List<int> shape,
  }) {
    final count = shape.fold<int>(1, (product, dim) => product * dim);
    return switch (type) {
      OnnxDataType.float32 => OnnxTensor.float32(
          name: name, shape: shape, values: Float32List(count)),
      OnnxDataType.int32 => OnnxTensor.int32(
          name: name, shape: shape, values: Int32List(count)),
      OnnxDataType.int64 => OnnxTensor.int64(
          name: name, shape: shape, values: Int64List(count)),
    };
  }

  Float32List get asFloat32 => data as Float32List;
  Int32List get asInt32 => data as Int32List;
  Int64List get asInt64 => data as Int64List;

  int get elementCount => shape.fold<int>(1, (product, dim) => product * dim);

  /// Number of values actually present.
  int get valueCount => switch (data) {
        final Float32List values => values.length,
        final Int32List values => values.length,
        final Int64List values => values.length,
        _ => 0,
      };

  /// The payload as boxed numbers. For tests, logging and the rare small tensor
  /// — never in a loop that runs per frame.
  List<num> get values => switch (data) {
        final Float32List values => values,
        final Int32List values => values,
        final Int64List values => values,
        _ => const <num>[],
      };

  /// `false` when the shape and the payload disagree, which would be a bug in a
  /// caller rather than a model failure.
  ///
  /// A zero on an axis is **valid**: the KV cache starts as
  /// `[1, heads, 0, headDim]`, and rejecting that shape would make the first
  /// acoustic step impossible.
  bool get isWellFormed =>
      shape.isNotEmpty &&
      shape.every((dim) => dim >= 0) &&
      elementCount == valueCount;

  /// `true` when every element is exactly zero, i.e. this is warm-up noise
  /// rather than something the user asked to hear.
  bool get isAllZero => values.every((value) => value == 0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OnnxTensor &&
          other.name == name &&
          other.type == type &&
          listEquals(other.shape, shape) &&
          listEquals(other.values, values));

  @override
  int get hashCode =>
      Object.hash(name, type, Object.hashAll(shape), Object.hashAll(values));

  @override
  String toString() => 'OnnxTensor($name, ${type.wireName}, $shape)';
}
