import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:text_to_voice/ai/tts/npz_reader.dart';
import 'package:text_to_voice/core/result/result.dart';

/// The reader is checked against a real archive written by `numpy.savez`, not a
/// hand-built stand-in: the parts that break are the zip central directory and
/// the NPY header, and a fixture that skipped either would test nothing.
void main() {
  late NpzArchive archive;

  setUpAll(() async {
    final result = await NpzArchive.open(File('test/fixtures/heads_sample.npz'));
    archive = result.valueOrNull!;
    expect(archive, isNotNull, reason: 'fixture must open');
  });

  test('lists every entry without the .npy suffix', () {
    expect(archive.names..sort(), <String>[
      'audio_emb',
      'text_emb',
      'xvec_b',
      'xvec_ln_b',
      'xvec_ln_eps',
      'xvec_ln_w',
      'xvec_w',
    ]);
  });

  test('reads a 2-D float32 matrix with the right shape and values', () async {
    final matrix = (await archive.read('text_emb')).valueOrNull!;
    expect(matrix.shape, <int>[3, 2]);
    expect(matrix.values.toList(), <double>[0, 1, 2, 3, 4, 5]);
  });

  test('reads a 3-D matrix in row-major order', () async {
    final tensor = (await archive.read('audio_emb')).valueOrNull!;
    expect(tensor.shape, <int>[2, 4, 2]);
    expect(tensor.values.first, 0);
    expect(tensor.values.last, 15);
    // Row-major: [codebook][code][hidden], and a codebook is 4 codes × 2 hidden
    // = stride 8, so index 8 starts the second codebook.
    expect(tensor.values[8], 8);
  });

  test('reads a 0-d scalar as one value', () async {
    final scalar = (await archive.read('xvec_ln_eps')).valueOrNull!;
    expect(scalar.shape, isEmpty);
    expect(scalar.values.single, closeTo(1e-6, 1e-12));
  });

  test('a missing table is a CorruptModelFailure that names it', () async {
    final result = await archive.read('nope');
    expect(result.failureOrNull, isA<CorruptModelFailure>());
    expect(result.failureOrNull!.detail, contains('nope'));
  });

  test('a missing file is ModelUnavailableFailure, not a parse error', () async {
    final result = await NpzArchive.open(File('test/fixtures/does_not_exist.npz'));
    expect(result.failureOrNull, isA<ModelUnavailableFailure>());
  });

  test('a non-zip file is reported as corrupt', () async {
    final result = await NpzArchive.open(File('test/fixtures/vieneu_tokenizer.json'));
    expect(result.failureOrNull, isA<CorruptModelFailure>());
  });
}
