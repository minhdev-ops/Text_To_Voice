import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../core/result/result.dart';
import 'npz_reader.dart';
import 'vieneu_config.dart';

/// The tables that live in `vieneu_v3_heads.npz` rather than in the ONNX graphs.
///
/// The exported graphs take **already-embedded rows** (`inputs_embeds`) and give
/// back hidden states; embeddings, the speaker projection and the output heads
/// are plain NumPy arrays. `onnx_runtime_lite.py` does that arithmetic in NumPy;
/// this class is the same arithmetic in Dart, and it is where the audio either
/// has the right voice or does not.
///
/// Two operations, both ports of the reference:
///
/// * [speakerAnchor] — the 192-d voice embedding is projected to 768 and
///   LayerNorm'ed. The reference calls this `xvec_proj` and adds the result to
///   *every* prompt row, which is how one checkpoint carries all 25 voices.
/// * [embedRows] — the prompt is a `(T, nVq + 1)` table of token ids: column 0
///   is a text token, columns 1..nVq are one audio code per codebook or the pad
///   id. Each row becomes `text_emb[col0] + Σ audio_emb[ch][col] + anchor`.
class VieNeuHeads {
  VieNeuHeads._({
    required this.textEmbeddings,
    required this.audioEmbeddings,
    required this.xvecWeight,
    required this.xvecBias,
    required this.xvecLayerNormWeight,
    required this.xvecLayerNormBias,
    required this.xvecLayerNormEps,
    required this.textVocabSize,
    required this.audioVocabSize,
    required this.codebookCount,
    required this.hiddenSize,
    required this.speakerDimension,
  });

  /// `(textVocab, hidden)`, row-major.
  final Float32List textEmbeddings;

  /// `(nVq, audioVocab, hidden)`, row-major.
  final Float32List audioEmbeddings;

  /// `(hidden, speakerDimension)`.
  final Float32List xvecWeight;

  /// `(hidden,)`.
  final Float32List xvecBias;
  final Float32List xvecLayerNormWeight;
  final Float32List xvecLayerNormBias;
  final double xvecLayerNormEps;

  final int textVocabSize;
  final int audioVocabSize;
  final int codebookCount;
  final int hiddenSize;
  final int speakerDimension;

  /// Builds a table set with arbitrary dimensions, for tests.
  ///
  /// The real tables are 52 MB; a test that only needs to check the *arithmetic*
  /// (which is where a wrong transpose or a forgotten pad mask hides) can use
  /// dimensions small enough to verify by hand.
  @visibleForTesting
  factory VieNeuHeads.forTesting({
    required Float32List textEmbeddings,
    required Float32List audioEmbeddings,
    required Float32List xvecWeight,
    required Float32List xvecBias,
    required Float32List xvecLayerNormWeight,
    required Float32List xvecLayerNormBias,
    double xvecLayerNormEps = 1e-6,
    required int textVocabSize,
    required int audioVocabSize,
    required int codebookCount,
    required int hiddenSize,
    required int speakerDimension,
  }) =>
      VieNeuHeads._(
        textEmbeddings: textEmbeddings,
        audioEmbeddings: audioEmbeddings,
        xvecWeight: xvecWeight,
        xvecBias: xvecBias,
        xvecLayerNormWeight: xvecLayerNormWeight,
        xvecLayerNormBias: xvecLayerNormBias,
        xvecLayerNormEps: xvecLayerNormEps,
        textVocabSize: textVocabSize,
        audioVocabSize: audioVocabSize,
        codebookCount: codebookCount,
        hiddenSize: hiddenSize,
        speakerDimension: speakerDimension,
      );

  static Future<Result<VieNeuHeads>> load({
    required NpzArchive archive,
    required VieNeuConfig config,
  }) async {
    try {
      final text = await _require(archive, 'text_emb');
      final audio = await _require(archive, 'audio_emb');
      final weight = await _require(archive, 'xvec_w');
      final bias = await _require(archive, 'xvec_b');
      final lnWeight = await _require(archive, 'xvec_ln_w');
      final lnBias = await _require(archive, 'xvec_ln_b');
      final lnEps = await _require(archive, 'xvec_ln_eps');

      _expectShape(text, [config.textVocabSize, config.hiddenSize]);
      _expectShape(audio, [config.nVq, config.audioVocabSize, config.hiddenSize]);
      _expectShape(weight, [config.hiddenSize, config.speakerEmbeddingDim]);
      _expectShape(bias, [config.hiddenSize]);
      _expectShape(lnWeight, [config.hiddenSize]);
      _expectShape(lnBias, [config.hiddenSize]);

      return Result<VieNeuHeads>.success(VieNeuHeads._(
        textEmbeddings: text.values,
        audioEmbeddings: audio.values,
        xvecWeight: weight.values,
        xvecBias: bias.values,
        xvecLayerNormWeight: lnWeight.values,
        xvecLayerNormBias: lnBias.values,
        xvecLayerNormEps: lnEps.values.isEmpty ? 1e-6 : lnEps.values[0].toDouble(),
        textVocabSize: config.textVocabSize,
        audioVocabSize: config.audioVocabSize,
        codebookCount: config.nVq,
        hiddenSize: config.hiddenSize,
        speakerDimension: config.speakerEmbeddingDim,
      ));
    } on CorruptModelFailure catch (failure) {
      return Result<VieNeuHeads>.failure(failure);
    } catch (error) {
      return Result<VieNeuHeads>.failure(CorruptModelFailure(
        message: 'Không đọc được bảng trọng số của model.',
        detail: error.toString(),
        cause: error,
      ));
    }
  }

  static Future<NpyArray> _require(NpzArchive archive, String name) async {
    final result = await archive.read(name);
    return switch (result) {
      Success<NpyArray>(:final value) => value,
      Failure<NpyArray>(:final failure) => throw failure,
    };
  }

  /// The shape check that turns a wrong export into a sentence, not a crash.
  static void _expectShape(NpyArray array, List<int> expected) {
    if (array.shape.length != expected.length) {
      throw CorruptModelFailure(
        message: 'Bảng trọng số "${array.name}" sai kích thước.',
        detail: '${array.shape} so với $expected',
      );
    }
    for (var i = 0; i < expected.length; i++) {
      if (array.shape[i] != expected[i]) {
        throw CorruptModelFailure(
          message: 'Bảng trọng số "${array.name}" sai kích thước.',
          detail: '${array.shape} so với $expected',
        );
      }
    }
  }

  /// 192-d voice embedding → the 768-d anchor added to every prompt row.
  ///
  /// Mirrors `_speaker_anchor`: `Linear` (weight is `(hidden, speakerDim)`, so
  /// `v @ W.T`), then a LayerNorm over the hidden axis — **including** the
  /// learned scale/shift, and using the epsilon the checkpoint stores rather
  /// than a conventional 1e-5, which would silently change the gain.
  Float32List speakerAnchor(Float32List speakerEmbedding) {
    if (speakerEmbedding.length != speakerDimension) {
      throw CorruptModelFailure(
        message: 'Vector giọng đọc sai kích thước.',
        detail: '${speakerEmbedding.length} so với $speakerDimension',
      );
    }
    final out = Float32List(hiddenSize);
    for (var h = 0; h < hiddenSize; h++) {
      final rowOffset = h * speakerDimension;
      var sum = 0.0;
      for (var k = 0; k < speakerDimension; k++) {
        sum += speakerEmbedding[k] * xvecWeight[rowOffset + k];
      }
      out[h] = sum + xvecBias[h];
    }

    var mean = 0.0;
    for (var i = 0; i < hiddenSize; i++) {
      mean += out[i];
    }
    mean /= hiddenSize;
    var variance = 0.0;
    for (var i = 0; i < hiddenSize; i++) {
      final d = out[i] - mean;
      variance += d * d;
    }
    variance /= hiddenSize;
    final inverse = 1.0 / math.sqrt(variance + xvecLayerNormEps);
    for (var i = 0; i < hiddenSize; i++) {
      out[i] = ((out[i] - mean) * inverse) * xvecLayerNormWeight[i] +
          xvecLayerNormBias[i];
    }
    return out;
  }

  /// `(rowCount, nVq + 1)` token ids → `(rowCount, hidden)` embeddings.
  Float32List embedRows(
    Int32List rows,
    int rowCount, {
    Float32List? anchor,
  }) {
    final width = codebookCount + 1;
    final out = Float32List(rowCount * hiddenSize);
    for (var row = 0; row < rowCount; row++) {
      final rowOffset = row * width;
      final textToken = rows[rowOffset];
      if (textToken < 0 || textToken >= textVocabSize) {
        throw CorruptModelFailure(
          message: 'Token văn bản nằm ngoài từ vựng model.',
          detail: 'id $textToken, từ vựng $textVocabSize',
        );
      }
      final source = textToken * hiddenSize;
      final destination = row * hiddenSize;
      for (var h = 0; h < hiddenSize; h++) {
        out[destination + h] = textEmbeddings[source + h];
      }

      for (var ch = 0; ch < codebookCount; ch++) {
        final code = rows[rowOffset + ch + 1];
        // The pad id is a real vocabulary entry used to mean "no code here";
        // it must contribute nothing, exactly as `valid[:, None]` does in the
        // reference.
        if (code < 0 || code >= audioVocabSize) continue;
        final codeOffset =
            ((ch * audioVocabSize) + code) * hiddenSize;
        for (var h = 0; h < hiddenSize; h++) {
          out[destination + h] += audioEmbeddings[codeOffset + h];
        }
      }

      if (anchor != null) {
        for (var h = 0; h < hiddenSize; h++) {
          out[destination + h] += anchor[h];
        }
      }
    }
    return out;
  }

  /// The raw text-embedding row for one token, **without** the speaker anchor.
  ///
  /// The acoustic decoder's second slot wants exactly this: the reference reads
  /// `self.text_emb[self.sgs]` while the first slot carries the anchored hidden
  /// state. Adding the anchor here too would condition every frame on the voice
  /// twice, which is not what the checkpoint was trained on.
  Float32List textRow(int token) {
    if (token < 0 || token >= textVocabSize) {
      throw CorruptModelFailure(
        message: 'Token văn bản nằm ngoài từ vựng model.',
        detail: 'id $token, từ vựng $textVocabSize',
      );
    }
    return Float32List.sublistView(
      textEmbeddings,
      token * hiddenSize,
      (token + 1) * hiddenSize,
    );
  }

  /// Copies one raw text-embedding row into [into] at [offset].
  void writeTextRow(int token, Float32List into, int offset) {
    final row = textRow(token);
    into.setRange(offset, offset + hiddenSize, row);
  }

  /// The raw embedding of one audio code in one codebook, as a **view** — no
  /// copy, because this sits inside the per-frame channel loop.
  Float32List audioRow(int codebook, int code) {
    if (codebook < 0 || codebook >= codebookCount) {
      throw CorruptModelFailure(
        message: 'Chỉ số codebook nằm ngoài model.',
        detail: 'codebook $codebook, tổng $codebookCount',
      );
    }
    if (code < 0 || code >= audioVocabSize) {
      throw CorruptModelFailure(
        message: 'Mã audio nằm ngoài từ vựng model.',
        detail: 'code $code, từ vựng $audioVocabSize',
      );
    }
    final start = ((codebook * audioVocabSize) + code) * hiddenSize;
    return Float32List.sublistView(audioEmbeddings, start, start + hiddenSize);
  }

  /// `hidden`-wide vector · one codebook's embedding table → `audioVocab` logits.
  ///
  /// This is the output head for every audio code: the checkpoint ties it to the
  /// embedding table, so there is no separate matrix to load and no chance of
  /// using the wrong one.
  Float32List codebookLogits(int codebook, Float32List vector, {Float32List? into}) {
    final logits = into ?? Float32List(audioVocabSize);
    final base = codebook * audioVocabSize * hiddenSize;
    for (var code = 0; code < audioVocabSize; code++) {
      final offset = base + code * hiddenSize;
      var sum = 0.0;
      for (var h = 0; h < hiddenSize; h++) {
        sum += vector[h] * audioEmbeddings[offset + h];
      }
      logits[code] = sum;
    }
    return logits;
  }

  /// `hidden`-wide vector · the text embedding table → `textVocab` logits.
  ///
  /// Used for exactly one decision: whether the end-of-speech token wins, which
  /// is how the model says "this sentence is finished" (the reference reads only
  /// the argmax, so nothing else from these logits is needed).
  Float32List textLogits(Float32List vector, {Float32List? into}) {
    final logits = into ?? Float32List(textVocabSize);
    for (var token = 0; token < textVocabSize; token++) {
      final offset = token * hiddenSize;
      var sum = 0.0;
      for (var h = 0; h < hiddenSize; h++) {
        sum += vector[h] * textEmbeddings[offset + h];
      }
      logits[token] = sum;
    }
    return logits;
  }
}
