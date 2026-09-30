// E2E gate (spec §9.2): the full read-aloud pipeline against the **real** int8
// checkpoint on Linux desktop.
//
// Run with:
//   flutter test integration_test/vieneu_model_e2e_test.dart -d linux
//
// Needs `assets/models/` staged first (`tool/fetch_model.sh`, ~273 MB —
// gitignored, not in pubspec assets). Skips with a clear message when staging
// is incomplete, so a fresh clone fails honestly instead of mysteriously.
//
// This is deliberately the real everything: the FFI phonemizer through the
// sea-g2p C ABI, the byte-level BPE tokenizer, the four ONNX graphs through the
// flutter_onnxruntime plugin in a worker isolate, the WAV cache writer, and the
// sentence queue with its cache seam. A silent or all-zero waveform means the
// port drifted from the reference — the exact failure goldens cannot catch
// alone.
@Tags(['model'])
library;

import 'dart:io' show Directory, File;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:text_to_voice/ai/models/vieneu_model_manifest.dart';
import 'package:text_to_voice/ai/tts/vieneu_onnx_tts_engine.dart';
import 'package:text_to_voice/domain/models/tts.dart';
import 'package:text_to_voice/domain/speech/sentence_synthesis_queue.dart';
import 'package:text_to_voice/domain/speech/synthesis_cache.dart';

/// Staging layout, which uses underscores where the manifest's install layout
/// uses hyphens (`vieneu-v3-turbo-int8/`). The e2e points at the staging names
/// so it exercises exactly the bytes `tool/fetch_model.sh --verify` checked.
const String _stagingModel = 'assets/models/vieneu_v3_turbo_int8';
const String _stagingCodec = 'assets/models/moss_audio_tokenizer_nano';
const String _stagingG2p = 'assets/models/sea_g2p';

/// One sentence, chosen to exercise numbers, a proper noun and diacritics
/// through sea-g2p — the shapes a hand-rolled G2P most often gets wrong.
const String _sentence = 'Xin chào Việt Nam';

/// Model load is ~165 MB of int8 weights and one sentence is ~40 frame
/// iterations of CPU inference; the 30 s default test timeout is for unit
/// tests, not for this.
final Timeout _modelTimeout = Timeout(const Duration(minutes: 10));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Working directory is the project root under `flutter test`; resolve
  // absolute paths once so the worker isolate and the FFI loader never depend
  // on that assumption.
  final String root = Directory.current.path;

  test(
    'real int8 model synthesizes non-silent Vietnamese audio (spec §9.2)',
    () async {
      // ---- 1. Staging check --------------------------------------------------
      final missing = <String>[];
      for (final spec in VieNeuModelManifest.filesFor('linux')) {
        final segments = spec.relativePath.split('/');
        // Manifest paths are hyphenated; staging dirs are underscored. Only the
        // first segment differs, so rename just that one.
        final stagedPath =
            '${_stagingDirOf(segments.first)}/${segments.sublist(1).join('/')}';
        final file = File('$root/assets/models/$stagedPath');
        if (!file.existsSync()) missing.add('assets/models/$stagedPath');
      }
      expect(
        missing,
        isEmpty,
        reason: 'Model staging is incomplete. Run `tool/fetch_model.sh` first. '
            'Missing:\n${missing.join('\n')}',
      );

      // ---- 2. Real engine through the real queue ------------------------------
      final audioDir = await Directory.systemTemp.createTemp('vieneu_e2e_audio_');
      final cache = _CountingCache();
      final engine = VieNeuOnnxTtsEngine(
        collaborators: VieNeuCollaborators(
          modelDirectory: '$root/$_stagingModel',
          codecDirectory: '$root/$_stagingCodec',
          phonemizerDirectories: <String>['$root/$_stagingG2p'],
          audioDirectory: audioDir.path,
          // Voices ship with the app as a real bundle asset, and the
          // integration shell serves declared assets, so the default path is
          // used as-is — the same one production reads.
        ),
      );
      final queue = SentenceSynthesisQueue(engine: engine, cache: cache);

      expect(engine.isReady, isTrue, reason: 'installed engine must start ready');

      try {
        final sentences = await queue.load(_sentence, options: const TtsOptions());
        expect(sentences, hasLength(1));

        final result = await queue.audioAt(0);
        final audio = result.valueOrNull;
        expect(
          audio,
          isNotNull,
          reason: 'synthesis failed: ${result.failureOrNull?.message} '
              '(detail: ${result.failureOrNull?.detail})',
        );

        // ---- 3. WAV container (the 44-byte header pcm16WavBytes writes) -------
        final wav = File(audio!.path).readAsBytesSync();
        expect(wav.length, greaterThan(44));
        expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
        expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
        final header = ByteData.sublistView(wav);
        expect(header.getUint16(20, Endian.little), 1, reason: 'PCM format');
        expect(header.getUint16(22, Endian.little), 1, reason: 'mono');
        expect(header.getUint32(24, Endian.little), 48000, reason: '48 kHz');
        expect(header.getUint16(34, Endian.little), 16, reason: '16-bit');
        expect(
          header.getUint32(40, Endian.little),
          wav.length - 44,
          reason: 'data chunk covers the whole payload',
        );

        // ---- 4. The audio is real, not silence ---------------------------------
        final frames = (wav.length - 44) ~/ 2;
        expect(audio.sampleRate, 48000);
        // A spoken "Xin chào Việt Nam" lasts seconds: not milliseconds, and not
        // a frame-capped eternity.
        expect(audio.duration.inMilliseconds, inInclusiveRange(500, 15000));
        expect(
          frames,
          closeTo(audio.duration.inMilliseconds * 48, 96),
          reason: 'WAV length matches the reported duration',
        );

        final data = ByteData.sublistView(wav, 44);
        var sumSquares = 0.0;
        var peak = 0;
        for (var i = 0; i < frames; i++) {
          final sample = data.getInt16(i * 2, Endian.little);
          sumSquares += sample * sample;
          final magnitude = sample.abs();
          if (magnitude > peak) peak = magnitude;
        }
        final rms = math.sqrt(sumSquares / frames);
        // The Python reference produced rms ≈ 0.106 of full scale ≈ 3480 in
        // int16 with audible dynamics. Requiring rms > 200 and peak > 1000 keeps
        // an all-zero or near-zero decode from passing while leaving headroom
        // for a quieter voice preset.
        expect(rms, greaterThan(200), reason: 'waveform is silent (rms=$rms)');
        expect(
          peak,
          greaterThan(1000),
          reason: 'waveform has no dynamics (peak=$peak)',
        );
        // A decoder that emits garbage constants fails this too.
        expect(peak, lessThan(32767), reason: 'waveform is not clipped garbage');

        // ignore: avoid_print
        print('[e2e] rms=$rms peak=$peak frames=$frames '
            'duration=${audio.duration.inMilliseconds}ms path=${audio.path}');

        // ---- 5. Cache hit skips re-synthesis ------------------------------------
        final savesBefore = cache.saves;
        final second = await queue.audioAt(0);
        final secondAudio = second.valueOrNull;
        expect(secondAudio, isNotNull);
        expect(
          secondAudio!.path,
          audio.path,
          reason: 'cache serves the same file',
        );
        expect(secondAudio.cacheHit, isTrue, reason: 'result is marked a hit');
        expect(cache.saves, savesBefore,
            reason: 'a cache hit must not re-synthesize');
        expect(cache.finds, greaterThan(savesBefore),
            reason: 'the cache was consulted again before skipping');
      } finally {
        await queue.dispose();
        await engine.close();
        audioDir.deleteSync(recursive: true);
      }
    },
    timeout: _modelTimeout,
  );
}

/// Maps the manifest's install directory name onto the staging directory name
/// under `assets/models/`. Identical names pass through unchanged.
String _stagingDirOf(String manifestSegment) => switch (manifestSegment) {
      VieNeuModelManifest.modelDirectoryName => _stagingModel.split('/').last,
      VieNeuModelManifest.codecDirectoryName => _stagingCodec.split('/').last,
      VieNeuModelManifest.phonemizerDirectoryName => _stagingG2p.split('/').last,
      final other => other,
    };

/// Counts cache traffic so "a cache hit skips re-synthesis" is observed on the
/// real seam ([SynthesisCache]) rather than inferred from timing.
class _CountingCache implements SynthesisCache {
  final Map<String, AudioResult> _entries = <String, AudioResult>{};

  int finds = 0;
  int saves = 0;

  @override
  Future<AudioResult?> find(String key) async {
    finds++;
    return _entries[key];
  }

  @override
  Future<void> save(String key, AudioResult result) async {
    saves++;
    _entries[key] = result;
  }

  @override
  Future<void> clear() async {
    _entries.clear();
  }
}
