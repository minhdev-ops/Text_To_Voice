import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:text_to_voice/ai/tts/vieneu_heads.dart';
import 'package:text_to_voice/core/result/result.dart';

/// The embedding arithmetic is checked against values computed by hand.
///
/// This is the layer where a transposed projection or a forgotten pad mask
/// produces *plausible* audio that says the wrong thing, so the assertions below
/// are exact numbers rather than "it ran".
void main() {
  // text_emb (3, 2):          [[0,1],[2,3],[4,5]]
  // audio_emb (2 codebooks, 4 codes, 2): ch0 [[0,1],[2,3],[4,5],[6,7]]
  //                                      ch1 [[8,9],[10,11],[12,13],[14,15]]
  // xvec_w (2, 3) = [[0,1,2],[3,4,5]], xvec_b = [1, 2]
  late VieNeuHeads heads;

  setUp(() {
    heads = VieNeuHeads.forTesting(
      textEmbeddings: Float32List.fromList(<double>[0, 1, 2, 3, 4, 5]),
      audioEmbeddings: Float32List.fromList(
        List<double>.generate(16, (i) => i.toDouble()),
      ),
      xvecWeight: Float32List.fromList(<double>[0, 1, 2, 3, 4, 5]),
      xvecBias: Float32List.fromList(<double>[1, 2]),
      xvecLayerNormWeight: Float32List.fromList(<double>[1, 1]),
      xvecLayerNormBias: Float32List.fromList(<double>[0, 0]),
      xvecLayerNormEps: 1e-6,
      textVocabSize: 3,
      audioVocabSize: 4,
      codebookCount: 2,
      hiddenSize: 2,
      speakerDimension: 3,
    );
  });

  test('speakerAnchor projects then normalizes (Linear + LayerNorm)', () {
    // v = [1,0,0] → W·v + b = [0*1+1*0+2*0+1, 3*1+4*0+5*0+2] = [1, 5]
    // mean 3, var 4 → [(1-3)/2, (5-3)/2] = [-1, 1]
    final anchor = heads.speakerAnchor(Float32List.fromList(<double>[1, 0, 0]));
    expect(anchor[0], closeTo(-1.0, 1e-5));
    expect(anchor[1], closeTo(1.0, 1e-5));
  });

  test('speakerAnchor names a wrong-width vector instead of reading past it', () {
    expect(
      () => heads.speakerAnchor(Float32List.fromList(<double>[1, 0])),
      throwsA(isA<CorruptModelFailure>()),
    );
  });

  test('embedRows sums text row, every codebook row and the anchor', () {
    // row = [text=1, ch0=2, ch1=3]
    // text_emb[1] = [2,3]
    // + audio_emb[0][2] = [4,5]  → [6,8]
    // + audio_emb[1][3] = [14,15] → [20,23]
    final rows = Int32List.fromList(<int>[1, 2, 3]);
    final without = heads.embedRows(rows, 1);
    expect(without.toList(), <double>[20, 23]);

    // + anchor [1,5] → [21,28]
    final anchor = Float32List.fromList(<double>[1, 5]);
    final with_ = heads.embedRows(rows, 1, anchor: anchor);
    expect(with_.toList(), <double>[21, 28]);
  });

  test('the pad id contributes nothing', () {
    // ch1 = pad (audioVocabSize) → only text + ch0 → [6, 8]
    final rows = Int32List.fromList(<int>[1, 2, 4]);
    expect(heads.embedRows(rows, 1).toList(), <double>[6, 8]);
  });

  test('a text token outside the vocabulary fails loudly', () {
    expect(
      () => heads.embedRows(Int32List.fromList(<int>[9, 0, 0]), 1),
      throwsA(isA<CorruptModelFailure>()),
    );
  });

  test('codebookLogits is the tied-embedding row product', () {
    // vector [1,1] · audio_emb[0] → [0+1, 2+3, 4+5, 6+7] = [1, 5, 9, 13]
    final logits = heads.codebookLogits(0, Float32List.fromList(<double>[1, 1]));
    expect(logits.toList(), <double>[1, 5, 9, 13]);
    // codebook 1 is a different table: [8+9, 10+11, 12+13, 14+15]
    expect(
      heads.codebookLogits(1, Float32List.fromList(<double>[1, 1])).toList(),
      <double>[17, 21, 25, 29],
    );
  });

  test('textLogits is the tied text table product', () {
    final logits = heads.textLogits(Float32List.fromList(<double>[1, 1]));
    expect(logits.toList(), <double>[1, 5, 9]);
  });

  test('audioRow is a view, so the frame loop does not copy 768 floats', () {
    final row = heads.audioRow(1, 2);
    expect(row.length, 2);
    expect(row.toList(), <double>[12, 13]);
  });
}
