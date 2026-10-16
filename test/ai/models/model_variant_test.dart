import 'package:flutter_test/flutter_test.dart';
import 'package:text_to_voice/ai/models/model_variant.dart';
import 'package:text_to_voice/ai/models/vieneu_model_manifest.dart';

void main() {
  group('ModelVariant', () {
    test('int8 is the default', () {
      expect(ModelVariant.defaultVariant, same(ModelVariant.int8));
    });

    test('both variants share the same license and phonemizer', () {
      expect(ModelVariant.int8.license, 'Apache-2.0');
      expect(ModelVariant.fp16.license, 'Apache-2.0');
      expect(ModelVariant.int8.licenseSource, contains('VieNeu-TTS-v3-Turbo'));
      expect(ModelVariant.fp16.licenseSource, contains('VieNeu-TTS-v3-Turbo'));
    });

    test('int8 is smaller than fp16', () {
      expect(
        ModelVariant.int8.totalBytesEstimate,
        lessThan(ModelVariant.fp16.totalBytesEstimate),
      );
    });

    test('fp16 uses a different model directory', () {
      expect(
        ModelVariant.int8.modelDirectoryName,
        isNot(ModelVariant.fp16.modelDirectoryName),
      );
    });

    test('both variants share the same codec directory', () {
      expect(
        ModelVariant.int8.modelDirectoryName !=
            ModelVariant.fp16.modelDirectoryName,
        isTrue,
      );
    });

    test('shipsPhonemizerLibrary delegates to the manifest', () {
      expect(ModelVariant.shipsPhonemizerLibrary('android'), isFalse);
      expect(ModelVariant.shipsPhonemizerLibrary('linux'), isTrue);
      expect(ModelVariant.shipsPhonemizerLibrary('macos'), isTrue);
      expect(ModelVariant.shipsPhonemizerLibrary('windows'), isTrue);
    });

    test('formatBytes matches the manifest helper', () {
      expect(ModelVariant.formatBytes(683), '683 B');
      expect(ModelVariant.formatBytes(44198912), '44 MB');
      expect(ModelVariant.formatBytes(279538606), '280 MB');
    });

    test('the catalog has exactly two variants', () {
      expect(ModelVariant.all.length, 4);
      expect(ModelVariant.all, containsAll(<ModelVariant>[
        ModelVariant.int8,
        ModelVariant.fp16,
        ModelVariant.matchaInt8,
        ModelVariant.matchaFp16,
      ]));
    });
  });

  group('ModelInstallService with variant paths', () {
    test('fp16 model directory differs from int8', () {
      expect(
        ModelVariant.int8.modelDirectoryName,
        'vieneu-v3-turbo-int8',
      );
      expect(
        ModelVariant.fp16.modelDirectoryName,
        'vieneu-v3-turbo-fp16',
      );
    });

    test('both use the same codec and phonemizer', () {
      expect(
        VieNeuModelManifest.codecDirectoryName,
        'codec-nano',
      );
      expect(
        VieNeuModelManifest.phonemizerDirectoryName,
        'sea-g2p',
      );
    });
  });
}
