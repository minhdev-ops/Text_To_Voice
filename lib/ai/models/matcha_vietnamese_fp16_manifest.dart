import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'model_descriptor.dart';

/// Matcha-TTS Vietnamese ONNX (fp16) model descriptor.
class MatchaVietnameseFp16Manifest implements ModelDescriptor {
  MatchaVietnameseFp16Manifest._();
  factory MatchaVietnameseFp16Manifest() = _Fp16Instance;

  static const String _modelId = 'matcha-vietnamese-onnx-fp16';
  static const String _checkpointName = 'Matcha-TTS Vietnamese (fp16)';
  static const String _engineId = 'matcha-vietnamese-onnx-v1-fp16';
  static const String baseUrl =
      'https://huggingface.co/Cong123779/matcha-tts-vietnamese-onnx-int8/resolve/main';

  static const List<ModelFileSpec> _files = <ModelFileSpec>[
    ModelFileSpec(
      relativePath: 'matcha-vietnamese-fp16/fp16/matcha_encoder.onnx',
      url: '$baseUrl/fp16/matcha_encoder.onnx',
      sizeBytes: 55636762,
      sha256: '937e2342d7713a65080b1807b9a0906fa09d8182ae36374e5fe8bae825ef5417',
      note: 'Matcha encoder (fp16)',
    ),
    ModelFileSpec(
      relativePath: 'matcha-vietnamese-fp16/fp16/matcha_decoder.onnx',
      url: '$baseUrl/fp16/matcha_decoder.onnx',
      sizeBytes: 45776414,
      sha256: '44c81b3e8af451d17f2d474826bee1f465290c7a821aa10cbf8cd489a850edfd',
      note: 'Matcha decoder (fp16)',
    ),
    ModelFileSpec(
      relativePath: 'matcha-vietnamese-fp16/fp16/vocos.onnx',
      url: '$baseUrl/fp16/vocos.onnx',
      sizeBytes: 27611670,
      sha256: '9cf7eca8561b88081b89c7473eb9f84a1d8766bdf444fb2bcb3ab58715f5866e',
      note: 'Vocos vocoder (fp16)',
    ),
    ModelFileSpec(
      relativePath: 'matcha-vietnamese-fp16/prompt_encoder.onnx',
      url: '$baseUrl/prompt_encoder.onnx',
      sizeBytes: 155208,
      sha256: '7a859cb799d907dd30417bda6afacbd613be7e21bb1705a06d5ed8aed2b08772',
      note: 'Prompt encoder',
    ),
    ModelFileSpec(
      relativePath: 'matcha-vietnamese-fp16/symbols.json',
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
  String get summary => 'Chất lượng cao hơn — âm thanh tự nhiên hơn.';
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

class _Fp16Instance extends MatchaVietnameseFp16Manifest {
  _Fp16Instance() : super._();
}
