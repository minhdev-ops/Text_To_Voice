import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'model_descriptor.dart';

/// Matcha-TTS Vietnamese ONNX (int8) model descriptor.
class MatchaVietnameseManifest implements ModelDescriptor {
  MatchaVietnameseManifest._();

  factory MatchaVietnameseManifest() = _Instance;

  static const String _modelId = 'matcha-vietnamese-onnx-int8';
  static const String _checkpointName = 'Matcha-TTS Vietnamese (int8)';
  static const String _engineId = 'matcha-vietnamese-onnx-v1-int8';
  static const String baseUrl =
      'https://huggingface.co/Cong123779/matcha-tts-vietnamese-onnx-int8/resolve/main';

  static const List<ModelFileSpec> _files = <ModelFileSpec>[
    ModelFileSpec(
      relativePath: 'matcha-vietnamese-int8/int8/matcha_encoder.onnx',
      url: '$baseUrl/int8/matcha_encoder.onnx',
      sizeBytes: 29308586,
      sha256: '11649d7db105a69279986602b1b11fe0da6bed588482606547d4865d21f404c6',
      note: 'Matcha encoder (int8)',
    ),
    ModelFileSpec(
      relativePath: 'matcha-vietnamese-int8/int8/matcha_decoder.onnx',
      url: '$baseUrl/int8/matcha_decoder.onnx',
      sizeBytes: 24290024,
      sha256: 'f200595512899dbe3042893bd7d76e8dc001791365936889c34466366501cbe8',
      note: 'Matcha decoder (int8)',
    ),
    ModelFileSpec(
      relativePath: 'matcha-vietnamese-int8/int8/vocos.onnx',
      url: '$baseUrl/int8/vocos.onnx',
      sizeBytes: 14876202,
      sha256: 'bf85f803487143287520c761686bd4ce88cadf85a2e53ed20f5a56ace8fd7bb2',
      note: 'Vocos vocoder (int8)',
    ),
    ModelFileSpec(
      relativePath: 'matcha-vietnamese-int8/prompt_encoder.onnx',
      url: '$baseUrl/prompt_encoder.onnx',
      sizeBytes: 155208,
      sha256: '7a859cb799d907dd30417bda6afacbd613be7e21bb1705a06d5ed8aed2b08772',
      note: 'Prompt encoder',
    ),
    ModelFileSpec(
      relativePath: 'matcha-vietnamese-int8/symbols.json',
      url: '$baseUrl/symbols.json',
      sizeBytes: 5706,
      sha256: '8a4a19d7a70fd5649b3a9ac09bd87955660fb20c9ab157b39954b7c2162798f9',
      note: 'Symbols map',
    ),
  ];

  @override
  String get modelId => _modelId;
  @override
  String get checkpointName => _checkpointName;
  @override
  String get engineId => _engineId;
  @override
  String get license => 'MIT';
  @override
  String get licenseSource => 'Cong123779/matcha-tts-vietnamese-onnx-int8 (Matcha-TTS + Vocos)';
  @override
  int get sampleRate => 22050;
  @override
  String get summary => 'Nhẹ, nhanh trên CPU — phù hợp thiết bị hạn chế.';
  @override
  int get voiceCount => 1;

  @override
  int totalBytesFor(String platform) => filesFor(platform)
      .fold<int>(0, (sum, file) => sum + file.sizeBytes);

  @override
  List<ModelFileSpec> filesFor(String platform) => List<ModelFileSpec>.from(_files);

  @override
  Map<String, String> get componentDirectories => <String, String>{
        ModelComponent.model: modelId,
      };

  @override
  String get manifestDigest {
    final material = <String>[
      modelId,
      engineId,
      for (final file in filesFor('linux'))
        '${file.relativePath}:${file.sizeBytes}:${file.sha256}',
    ].join('\n');
    return sha256.convert(utf8.encode(material)).toString();
  }
}

class _Instance extends MatchaVietnameseManifest {
  _Instance() : super._();
}
