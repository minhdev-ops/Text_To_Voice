/// What the Model Manager installs, and exactly how big and which bytes it is.
///
/// The manifest is baked into the app rather than fetched, because a manifest
/// that arrives over the network is a manifest an attacker can change; these
/// hashes are the only reason a download can be called verified.
///
/// **Every digest here was measured, not copied from a web page.** The seven
/// model files were compared byte-for-byte against the pinned HuggingFace
/// revision and the three g2p libraries were hashed from the release assets
/// themselves (`tool/fetch_model.sh` reproduces the check). A wrong hash in this
/// file is worse than no hash: it would fail a perfectly good download forever.
///
/// Nothing here is bundled in the APK. Weights, codec and dictionary are
/// downloaded and deletable (FR-20); the only model-adjacent asset that ships
/// with the app is the 180 KB voice catalog.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// One downloadable artifact.
class ModelFileSpec {
  const ModelFileSpec({
    required this.relativePath,
    required this.url,
    required this.sizeBytes,
    required this.sha256,
    this.platforms = const <String>{},
    this.note,
  });

  /// Path under the models root, e.g. `vieneu-v3-turbo-int8/config.json`.
  /// The sub-directory is part of the path because the engine is handed one
  /// directory per component and must not have to guess where files landed.
  final String relativePath;

  final String url;

  /// Expected byte length. Checked while streaming, so a truncated download
  /// fails before 100 MB of hashing is wasted.
  final int sizeBytes;

  /// Lower-case hex SHA-256 of the artifact.
  final String sha256;

  /// Empty means "every platform". Non-empty lists the platforms this file is
  /// needed on — the g2p native library, which is per-architecture.
  final Set<String> platforms;

  /// Why this file is here, for the Models screen's detail line.
  final String? note;

  bool appliesTo(String platform) =>
      platforms.isEmpty || platforms.contains(platform);

  String get fileName => relativePath.split('/').last;
}

/// The VieNeu-TTS v3 Turbo int8 checkpoint plus everything needed to run it.
class VieNeuModelManifest {
  VieNeuModelManifest._();

  static const String modelId = 'vieneu-v3-turbo-int8';
  static const String checkpointName = 'VieNeu-TTS v3 Turbo';
  static const String version = 'int8';
  static const String quantization = 'int8';

  /// Read from the pinned repositories, not assumed from the model family: SRS
  /// §47 is explicit that different VieNeu checkpoints carry different terms.
  static const String license = 'Apache-2.0';
  static const String licenseSource =
      'pnnbao-ump/VieNeu-TTS-v3-Turbo · OpenMOSS-Team/MOSS-Audio-Tokenizer-Nano-ONNX · pnnbao97/sea-g2p';

  /// Sample rate the codec produces, shown in the Models row so the row is a
  /// spec of what will be heard rather than a name.
  static const int sampleRate = 48000;

  /// Directory names, matching what the engine and the g2p loader are given.
  static const String modelDirectoryName = 'vieneu-v3-turbo-int8';
  static const String codecDirectoryName = 'codec-nano';
  static const String phonemizerDirectoryName = 'sea-g2p';

  static const String _modelBase =
      'https://huggingface.co/pnnbao-ump/VieNeu-TTS-v3-Turbo/resolve/'
      '61b85e3d937fbbacb387714180e8182823512523/onnx_int8';
  static const String _codecBase =
      'https://huggingface.co/OpenMOSS-Team/MOSS-Audio-Tokenizer-Nano-ONNX/resolve/'
      'ceff0d0749bfb3fa2d61149794ec6feef0d1e1ae';
  static const String _g2pBase =
      'https://github.com/pnnbao97/sea-g2p/releases/download/v0.10.0';

  /// The backbone, the acoustic decoder, the codec's configuration and the
  /// tied embedding tables.
  static const List<ModelFileSpec> _modelFiles = <ModelFileSpec>[
    ModelFileSpec(
      relativePath: '$modelDirectoryName/config.json',
      url: '$_modelBase/config.json',
      sizeBytes: 2152,
      sha256: 'a9f8d9c4b4736448ab355d1a98cfe48f5e39aecf2916c37b0806c228612e9a2d',
      note: 'Token ids, layer counts, codebook geometry',
    ),
    ModelFileSpec(
      relativePath: '$modelDirectoryName/tokenizer.json',
      url: '$_modelBase/tokenizer.json',
      sizeBytes: 22320,
      sha256: '6cc6bcbe380b8c37bd9f2514e37c5dfa3e00e122c6e3125dae5c4afe48e39158',
      note: 'Byte-level BPE over the phoneme alphabet',
    ),
    ModelFileSpec(
      relativePath: '$modelDirectoryName/vieneu_prefill.onnx',
      url: '$_modelBase/vieneu_prefill.onnx',
      sizeBytes: 1090823,
      sha256: 'c6a80dabf67c820de798f8deb7d4e0f37d81b5d76e33fbe20ab5a67f2d371f4e',
      note: 'Backbone prompt pass',
    ),
    ModelFileSpec(
      relativePath: '$modelDirectoryName/vieneu_decode_step.onnx',
      url: '$_modelBase/vieneu_decode_step.onnx',
      sizeBytes: 1062040,
      sha256: '2c5b30bd8ccb751c58d651f44c074df10c4113efd08719adaa8e3dec6a6ce2ca',
      note: 'Backbone decode step (KV cache)',
    ),
    ModelFileSpec(
      relativePath: '$modelDirectoryName/vieneu_acoustic_cached.onnx',
      url: '$_modelBase/vieneu_acoustic_cached.onnx',
      sizeBytes: 7207223,
      sha256: 'f631e3387c788c3d8b9a5ac5df94952af5bc4c4d1049ff8a751e76a246fff2d4',
      note: 'Acoustic decoder (16 codebooks per frame)',
    ),
    ModelFileSpec(
      relativePath: '$modelDirectoryName/vieneu_backbone_shared.data',
      url: '$_modelBase/vieneu_backbone_shared.data',
      sizeBytes: 103891968,
      sha256: 'bb683925f7c8d826fadca4f8a0252ae4d5fc5b7837c14f6857e18f4c6666588d',
      note: 'External weights for the backbone graphs',
    ),
    ModelFileSpec(
      relativePath: '$modelDirectoryName/vieneu_v3_heads.npz',
      url: '$_modelBase/vieneu_v3_heads.npz',
      sizeBytes: 52219622,
      sha256: 'fb22484baa424bbb775133a6e5f0d00d6299b2b256fbe3312a864b85b9aed01e',
      note: 'Tied embeddings + speaker projection',
    ),
  ];

  /// MOSS-Audio-Tokenizer-Nano: codes → 48 kHz waveform.
  static const List<ModelFileSpec> _codecFiles = <ModelFileSpec>[
    ModelFileSpec(
      relativePath: '$codecDirectoryName/moss_audio_tokenizer_decode_full.onnx',
      url: '$_codecBase/moss_audio_tokenizer_decode_full.onnx',
      sizeBytes: 681902,
      sha256: '0fbbafe3fd4afa2a019af5c5ced204af6e2d1db044fa40f021525d2aee95b4ac',
      note: 'MOSS audio codec decoder',
    ),
    ModelFileSpec(
      relativePath:
          '$codecDirectoryName/moss_audio_tokenizer_decode_shared.data',
      url: '$_codecBase/moss_audio_tokenizer_decode_shared.data',
      sizeBytes: 44198912,
      sha256: 'e69d52e0f4e84ca27850557ee54face46632d3a5a16c89bd246c7c408466dcad',
      note: 'External weights for the codec graph',
    ),
  ];

  /// The pronunciation dictionary, plus the native library per platform.
  ///
  /// The library situation is a real limitation, stated rather than hidden:
  /// upstream publishes prebuilt libraries for **linux-x86_64, macos-aarch64 and
  /// windows-x86_64 only**. Android has no downloadable `.so`, so on Android this
  /// manifest installs the dictionary and the app then reports the phonemizer as
  /// unavailable until the library is built with `tool/build_g2p.sh` (cargo-ndk)
  /// and placed in `android/app/src/main/jniLibs/`. Shipping a *guess* at that
  /// library is not an option, and neither is pretending the feature works.
  static const List<ModelFileSpec> _phonemizerFiles = <ModelFileSpec>[
    ModelFileSpec(
      relativePath: '$phonemizerDirectoryName/sea_g2p.bin',
      url: '$_g2pBase/sea_g2p.bin',
      sizeBytes: 62829820,
      sha256: '4346e690d0711ebc5231e7a42c5c88aaf6e40377e894b4617c018fd81c6f4096',
      note: 'sea-g2p dictionary (numbers, dates, units, G2P)',
    ),
    ModelFileSpec(
      relativePath:
          '$phonemizerDirectoryName/libsea_g2p_rs-linux-x86_64.so',
      url: '$_g2pBase/libsea_g2p_rs-linux-x86_64.so',
      sizeBytes: 6331824,
      sha256: '1db713489f688fe3e8b5b52d975853cf7d837834c9ee94c2b5bfb0ff665d0707',
      platforms: <String>{'linux'},
      note: 'sea-g2p native library (x86_64)',
    ),
    ModelFileSpec(
      relativePath:
          '$phonemizerDirectoryName/libsea_g2p_rs-macos-aarch64.dylib',
      url: '$_g2pBase/libsea_g2p_rs-macos-aarch64.dylib',
      sizeBytes: 4809808,
      sha256: 'e73a497541047add91a025419dc098acf64aa1565b3ab27c73ddd81a580d0ed4',
      platforms: <String>{'macos'},
      note: 'sea-g2p native library (Apple silicon)',
    ),
    ModelFileSpec(
      relativePath:
          '$phonemizerDirectoryName/sea_g2p_rs-windows-x86_64.dll',
      url: '$_g2pBase/sea_g2p_rs-windows-x86_64.dll',
      sizeBytes: 4996608,
      sha256: '1daff10cf65304daa56d90814f4f6a54cf6269bf22a684b940a3d7c0bbea25c3',
      platforms: <String>{'windows'},
      note: 'sea-g2p native library (x86_64)',
    ),
  ];

  /// Every file the given platform needs, in install order (small and
  /// structural first, so a cancel early costs the least).
  static List<ModelFileSpec> filesFor(String platform) => <ModelFileSpec>[
        ..._modelFiles,
        ..._codecFiles,
        ..._phonemizerFiles.where((file) => file.appliesTo(platform)),
      ];

  /// Exact download size for the given platform, summed from the manifest
  /// rather than rounded on a screen: the row says "≈ 280 MB" only because that
  /// is what the arithmetic produces.
  static int totalBytesFor(String platform) => filesFor(platform)
      .fold<int>(0, (sum, file) => sum + file.sizeBytes);

  /// Whether the manifest provides a *loadable* native g2p library for
  /// [platform].
  ///
  /// Asks about the platform-scoped binaries specifically, not about every file
  /// that applies to the platform: the dictionary ships everywhere, but a
  /// dictionary without a library cannot phonemize anything, so counting it here
  /// would let the app claim a feature it cannot run.
  static bool shipsPhonemizerLibrary(String platform) =>
      _phonemizerFiles.any((file) => file.platforms.contains(platform));

  /// One digest over the manifest itself, stored as the `models.checksum`
  /// (SRS §35).
  ///
  /// It names the *set* of files and their expected hashes, so a row written by
  /// an older build of the app is recognisable as such instead of looking like a
  /// corrupt install.
  static String get manifestDigest {
    final material = <String>[
      modelId,
      version,
      for (final file in filesFor('linux'))
        '${file.relativePath}:${file.sizeBytes}:${file.sha256}',
    ].join('\n');
    return sha256.convert(utf8.encode(material)).toString();
  }

  /// Human size for the UI, in the unit a user can act on.
  static String formatBytes(int bytes) {
    if (bytes >= 1000 * 1000 * 1000) {
      return '${(bytes / 1000000000).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1000 * 1000) {
      return '${(bytes / 1000000).round()} MB';
    }
    if (bytes >= 1000) return '${(bytes / 1000).round()} KB';
    return '$bytes B';
  }
}
