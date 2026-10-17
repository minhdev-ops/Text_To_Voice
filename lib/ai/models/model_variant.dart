/// The catalogue of downloadable TTS model variants — int8 (fast, compact) and
/// fp16 (full precision, larger). Both share the same codec and phonemizer.
library;

import 'vieneu_model_manifest.dart';

/// A model variant the user can download and switch to.
class ModelVariant {
  const ModelVariant({
    required this.modelId,
    required this.checkpointName,
    required this.version,
    required this.quantization,
    required this.engineId,
    required this.sampleRate,
    required this.voiceCount,
    required this.modelDirectoryName,
    required this.summary,
    required this.totalBytesEstimate,
    required this.license,
    required this.licenseSource,
  });

  /// int8 — the default: ~280 MB, fast on CPU.
  static const ModelVariant int8 = ModelVariant(
    modelId: 'vieneu-v3-turbo-int8',
    checkpointName: 'VieNeu-TTS v3 Turbo (int8)',
    version: 'int8',
    quantization: 'int8',
    engineId: 'vieneu-onnx-v3-turbo',
    sampleRate: 48000,
    voiceCount: 25,
    modelDirectoryName: 'vieneu-v3-turbo-int8',
    summary: 'Nhanh, nhẹ — phù hợp thiết bị yếu.',
    totalBytesEstimate: 279538606,
    license: 'Apache-2.0',
    licenseSource:
        'pnnbao-ump/VieNeu-TTS-v3-Turbo · OpenMOSS-Team/MOSS-Audio-Tokenizer-Nano-ONNX · pnnbao97/sea-g2p',
  );

  /// fp16 — full precision, ~2× larger but better audio quality.
  static const ModelVariant fp16 = ModelVariant(
    modelId: 'vieneu-v3-turbo-fp16',
    checkpointName: 'VieNeu-TTS v3 Turbo (fp16)',
    version: 'fp16',
    quantization: 'fp16',
    engineId: 'vieneu-onnx-v3-turbo',
    sampleRate: 48000,
    voiceCount: 25,
    modelDirectoryName: 'vieneu-v3-turbo-fp16',
    summary: 'Chất lượng cao — âm thanh tự nhiên hơn.',
    // ~1.1 GB: fp16 weights are ~4× the int8 backbone, shared codec/g2p.
    totalBytesEstimate: 1118004224,
    license: 'Apache-2.0',
    licenseSource:
        'pnnbao-ump/VieNeu-TTS-v3-Turbo · OpenMOSS-Team/MOSS-Audio-Tokenizer-Nano-ONNX · pnnbao97/sea-g2p',
  );

  /// All available variants, in display order.
  static final List<ModelVariant> all = <ModelVariant>[
    int8,
    fp16,
    matchaInt8,
    matchaFp16,
  ];

  /// The variant a fresh install lands on.

  /// Matcha-TTS Vietnamese int8 — lightweight, MIT.
  static final ModelVariant matchaInt8 = ModelVariant(
    modelId: 'matcha-vietnamese-onnx-int8',
    checkpointName: 'Matcha-TTS Vietnamese (int8)',
    version: 'int8',
    quantization: 'int8',
    engineId: 'matcha-vietnamese-onnx-v1-int8',
    sampleRate: 22050,
    voiceCount: 1,
    modelDirectoryName: 'matcha-vietnamese-onnx-int8',
    summary: 'Nhẹ, nhanh trên CPU — phù hợp thiết bị hạn chế.',
    totalBytesEstimate: 29308586 + 24290024 + 14876202 + 155208 + 5706,
    license: 'MIT',
    licenseSource: 'Cong123779/matcha-tts-vietnamese-onnx-int8 (Matcha-TTS + Vocos)',
  );

  /// Matcha-TTS Vietnamese fp16 — higher quality.
  static final ModelVariant matchaFp16 = ModelVariant(
    modelId: 'matcha-vietnamese-onnx-fp16',
    checkpointName: 'Matcha-TTS Vietnamese (fp16)',
    version: 'fp16',
    quantization: 'fp16',
    engineId: 'matcha-vietnamese-onnx-v1-fp16',
    sampleRate: 22050,
    voiceCount: 1,
    modelDirectoryName: 'matcha-vietnamese-onnx-fp16',
    summary: 'Chất lượng cao hơn — âm thanh tự nhiên hơn.',
    totalBytesEstimate: 55636762 + 45776414 + 27611670 + 155208 + 5706,
    license: 'MIT',
    licenseSource: 'Cong123779/matcha-tts-vietnamese-onnx-int8 (Matcha-TTS + Vocos)',
  );
  static const ModelVariant defaultVariant = int8;

  final String modelId;
  final String checkpointName;
  final String version;
  final String quantization;
  final String engineId;
  final int sampleRate;
  final int voiceCount;
  final String modelDirectoryName;

  /// One line for the Models screen subtitle.
  final String summary;

  /// Approximate download size for display before install begins.
  final int totalBytesEstimate;

  final String license;
  final String licenseSource;

  /// Whether a loadable native g2p library ships for [platform].
  ///
  /// Shared by both variants — the phonemizer is the same regardless of
  /// quantization, only the model weights differ.
  static bool shipsPhonemizerLibrary(String platform) =>
      VieNeuModelManifest.shipsPhonemizerLibrary(platform);

  /// Human-readable size for the Models screen, in the unit a user can act on.
  static String formatBytes(int bytes) => VieNeuModelManifest.formatBytes(bytes);
}
