import 'dart:convert';
import 'dart:io' show File;

import '../../core/result/result.dart';

/// Typed view of the checkpoint's `config.json`.
///
/// Everything here is read from the file the checkpoint actually ships rather
/// than hard-coded, because the token ids, the layer counts and the codec frame
/// geometry are properties of *this* export. A model whose config says
/// `n_vq = 8` must drive an 8-channel prompt, not a 16-channel one guessed from
/// the model card — so a missing or malformed key is a [CorruptModelFailure]
/// (the UI answers `Re-download`, FR-20), not a silent default.
class VieNeuConfig {
  const VieNeuConfig({
    required this.nVq,
    required this.hiddenSize,
    required this.numHiddenLayers,
    required this.numKeyValueHeads,
    required this.headDim,
    required this.localNumHiddenLayers,
    required this.localNumAttentionHeads,
    required this.textVocabSize,
    required this.audioVocabSize,
    required this.audioSampleRate,
    required this.audioPadTokenId,
    required this.textPromptStartTokenId,
    required this.textPromptEndTokenId,
    required this.speechGenerationStartTokenId,
    required this.speechGenerationEndTokenId,
    required this.audioRefSlotTokenId,
    required this.defaultStyleTokenId,
    required this.maxPositionEmbeddings,
    required this.speakerEmbeddingDim,
  });

  /// Number of audio codebooks: one code per channel per frame (FR-12's unit).
  final int nVq;

  final int hiddenSize;
  final int numHiddenLayers;
  final int numKeyValueHeads;
  final int headDim;

  /// The acoustic decoder is a *single* local layer with its own head count and
  /// head width, which is why these are read separately from the backbone.
  final int localNumHiddenLayers;
  final int localNumAttentionHeads;

  final int textVocabSize;
  final int audioVocabSize;
  final int audioSampleRate;

  /// Fill value for a channel that carries no code on a given row.
  final int audioPadTokenId;

  final int textPromptStartTokenId;
  final int textPromptEndTokenId;
  final int speechGenerationStartTokenId;
  final int speechGenerationEndTokenId;
  final int audioRefSlotTokenId;
  final int defaultStyleTokenId;
  final int maxPositionEmbeddings;
  final int speakerEmbeddingDim;

  /// Width of one acoustic-attention head (`hidden / heads`), matching the
  /// `past_k_0` shape the acoustic graph declares.
  int get localHeadDim => hiddenSize ~/ localNumAttentionHeads;

  /// Number of prompt columns: the text column plus one per codebook.
  int get rowWidth => nVq + 1;

  static Future<Result<VieNeuConfig>> fromFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return const Result<VieNeuConfig>.failure(ModelUnavailableFailure(
        message: 'Thiếu tệp cấu hình model (config.json).',
        modelId: 'vieneu-v3-turbo',
      ));
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return const Result<VieNeuConfig>.failure(CorruptModelFailure(
          message: 'Tệp cấu hình model không đúng định dạng.',
          detail: 'config.json is not a JSON object',
        ));
      }
      return Result<VieNeuConfig>.success(VieNeuConfig.fromJson(decoded));
    } on CorruptModelFailure catch (failure) {
      return Result<VieNeuConfig>.failure(failure);
    } catch (error) {
      return Result<VieNeuConfig>.failure(CorruptModelFailure(
        message: 'Không đọc được cấu hình model.',
        detail: error.toString(),
        cause: error,
      ));
    }
  }

  factory VieNeuConfig.fromJson(Map<String, dynamic> json) {
    int requiredInt(String key) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      throw CorruptModelFailure(
        message: 'Cấu hình model thiếu trường "$key".',
        detail: 'config.json[$key] = $value',
      );
    }

    return VieNeuConfig(
      nVq: requiredInt('n_vq'),
      hiddenSize: requiredInt('hidden_size'),
      numHiddenLayers: requiredInt('num_hidden_layers'),
      numKeyValueHeads: requiredInt('num_key_value_heads'),
      headDim: requiredInt('head_dim'),
      localNumHiddenLayers: requiredInt('local_num_hidden_layers'),
      localNumAttentionHeads: requiredInt('local_num_attention_heads'),
      textVocabSize: requiredInt('text_vocab_size'),
      audioVocabSize: requiredInt('audio_vocab_size'),
      audioSampleRate: requiredInt('audio_sample_rate'),
      audioPadTokenId: requiredInt('audio_pad_token_id'),
      textPromptStartTokenId: requiredInt('text_prompt_start_token_id'),
      textPromptEndTokenId: requiredInt('text_prompt_end_token_id'),
      speechGenerationStartTokenId: requiredInt('speech_generation_start_token_id'),
      speechGenerationEndTokenId: requiredInt('speech_generation_end_token_id'),
      audioRefSlotTokenId: requiredInt('audio_ref_slot_token_id'),
      defaultStyleTokenId: requiredInt('default_style_token_id'),
      maxPositionEmbeddings: requiredInt('max_position_embeddings'),
      speakerEmbeddingDim: requiredInt('speaker_embedding_dim'),
    );
  }
}
