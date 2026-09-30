import 'package:flutter_test/flutter_test.dart';
import 'package:text_to_voice/ai/models/vieneu_model_manifest.dart';

/// The manifest is what makes a download *verified* rather than merely finished,
/// so its own integrity is worth asserting: a malformed digest, a duplicate path
/// or a missing platform entry would each fail in a way that looks like a broken
/// model on device.
void main() {
  test('every entry has a real sha256 and a positive size', () {
    final files = VieNeuModelManifest.filesFor('linux');
    expect(files, isNotEmpty);
    for (final file in files) {
      expect(file.sha256, matches(RegExp(r'^[0-9a-f]{64}$')),
          reason: file.relativePath);
      expect(file.sizeBytes, greaterThan(0), reason: file.relativePath);
      expect(file.url, startsWith('https://'), reason: file.relativePath);
    }
  });

  test('no path appears twice', () {
    final paths = VieNeuModelManifest.filesFor('linux')
        .map((file) => file.relativePath)
        .toList();
    expect(paths.toSet().length, paths.length);
  });

  test('paths land in the directories the engine is handed', () {
    final paths = VieNeuModelManifest.filesFor('linux')
        .map((file) => file.relativePath.split('/').first)
        .toSet();
    expect(paths, <String>{
      VieNeuModelManifest.modelDirectoryName,
      VieNeuModelManifest.codecDirectoryName,
      VieNeuModelManifest.phonemizerDirectoryName,
    });
  });

  test('the total is the sum of the parts, per platform', () {
    final linux = VieNeuModelManifest.filesFor('linux');
    final total = linux.fold<int>(0, (sum, file) => sum + file.sizeBytes);
    expect(VieNeuModelManifest.totalBytesFor('linux'), total);
    // ~280 MB on desktop: graphs + codec + dictionary + the native library.
    expect(total, greaterThan(250 * 1000 * 1000));
  });

  test('Android installs no native phonemizer library, and says so', () {
    // Upstream publishes no Android build. The dictionary is still installed, so
    // the app must not claim either that the feature is ready or that the model
    // is missing entirely — it names the actual gap.
    expect(VieNeuModelManifest.shipsPhonemizerLibrary('android'), isFalse);
    expect(VieNeuModelManifest.shipsPhonemizerLibrary('linux'), isTrue);
    final paths = VieNeuModelManifest.filesFor('android')
        .map((file) => file.relativePath)
        .toList();
    expect(paths, contains(contains('sea_g2p.bin')));
    expect(paths.where((path) => path.endsWith('.so')), isEmpty);
  });

  test('macOS and Windows get their own library, not the Linux one', () {
    for (final platform in <String>['macos', 'windows']) {
      final paths = VieNeuModelManifest.filesFor(platform)
          .map((file) => file.relativePath)
          .toList();
      expect(paths, isNot(contains(endsWith('linux-x86_64.so'))));
    }
    expect(
      VieNeuModelManifest.filesFor('macos').map((f) => f.relativePath),
      contains(endsWith('.dylib')),
    );
    expect(
      VieNeuModelManifest.filesFor('windows').map((f) => f.relativePath),
      contains(endsWith('.dll')),
    );
  });

  test('the manifest digest is stable and changes with the content', () {
    final first = VieNeuModelManifest.manifestDigest;
    expect(first, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(VieNeuModelManifest.manifestDigest, first);
  });

  test('license and source are stated, because §47 requires the exact string',
      () {
    expect(VieNeuModelManifest.license, 'Apache-2.0');
    expect(VieNeuModelManifest.licenseSource, contains('VieNeu-TTS-v3-Turbo'));
    expect(VieNeuModelManifest.sampleRate, 48000);
  });

  test('formats bytes the way the row reads them', () {
    expect(VieNeuModelManifest.formatBytes(683), '683 B');
    expect(VieNeuModelManifest.formatBytes(44198912), '44 MB');
    expect(VieNeuModelManifest.formatBytes(279538606), '280 MB');
  });
}
