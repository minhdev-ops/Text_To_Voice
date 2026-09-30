import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/logging/app_log.dart';
import '../../core/result/result.dart';
import '../onnx/onnx_session.dart';
import '../onnx/onnx_tensor.dart';
import 'vieneu_config.dart';
import 'vieneu_frames.dart';
import 'vieneu_heads.dart';
import 'vieneu_sampling.dart';
import 'vieneu_tokenizer.dart';

/// The four graphs one synthesis needs.
class VieNeuSessions {
  const VieNeuSessions({
    required this.prefill,
    required this.decodeStep,
    required this.acoustic,
    required this.codec,
  });

  /// Text + reference prompt, once per sentence.
  final OnnxSession prefill;

  /// One backbone step per generated frame.
  final OnnxSession decodeStep;

  /// The single-layer acoustic decoder, run `nVq` times per frame.
  final OnnxSession acoustic;

  /// MOSS codec: audio codes → 48 kHz waveform.
  final OnnxSession codec;

  Future<void> close() async {
    await prefill.close();
    await decodeStep.close();
    await acoustic.close();
    await codec.close();
  }
}

/// What one synthesis produced.
class SynthesisOutput {
  const SynthesisOutput({
    required this.samples,
    required this.sampleRate,
    required this.frames,
    required this.maxFrames,
  });

  final Float32List samples;
  final int sampleRate;

  /// Frames actually generated — measured, not estimated.
  final int frames;

  /// The ceiling this run was allowed to reach, so "did it stop talking on its
  /// own?" is a fact a caller can check instead of re-deriving.
  final int maxFrames;

  Duration get duration => Duration(
        milliseconds: sampleRate == 0
            ? 0
            : (samples.length / sampleRate * 1000).round(),
      );

  bool get hitFrameCap => frames >= maxFrames;
}

/// One sentence: phonemes in, 48 kHz samples out.
///
/// A port of `onnx_runtime_lite.OnnxV3LiteEngine.infer` (the torch-free path).
/// The structure is worth stating because each part exists for a reason:
///
/// 1. **Prompt** — `(T, nVq + 1)` rows: `[style, TEXT_PROMPT_START, …phones,
///    TEXT_PROMPT_END]` in column 0 with the audio pad everywhere else, followed
///    by one row per reference frame carrying that frame's 16 codes and the
///    `audio_ref_slot` id. The reference rows are what carry the *voice*; without
///    them the model produces a generic timbre.
/// 2. **Prefill** — the whole prompt through the 12-layer backbone once. Its last
///    hidden row seeds the acoustic decoder, and its 24 `present_k`/`present_v`
///    outputs become the initial decode cache.
/// 3. **Frame loop** — the acoustic decoder emits 16 codes per frame, in
///    codebook order (each channel consumes the previous channel's code, which is
///    why they cannot be batched). The frame's *first* slot decides whether the
///    sentence is over, via the end-of-speech token in the text head.
/// 4. **Backbone step** — `[SPEECH_GENERATION_START, code0…code15]` embedded and
///    appended, cache carried forward. A frame that stopped does not feed the
///    backbone again.
/// 5. **Codec** — every frame at once through the MOSS decoder.
///
/// The KV cache is held as native [OnnxHandle]s on purpose: only the 768-wide
/// hidden row is ever read into Dart, so carrying ~10 MB of cache per step costs
/// a map of ids instead of ~10 MB of copies per step.
class VieNeuPipeline {
  VieNeuPipeline({
    required this.config,
    required this.heads,
    required this.tokenizer,
    required this.sessions,
    VieNeuSampler? sampler,
  }) : sampler = sampler ?? VieNeuSampler();

  final VieNeuConfig config;
  final VieNeuHeads heads;
  final VieNeuTokenizer tokenizer;
  final VieNeuSessions sessions;
  final VieNeuSampler sampler;

  /// Reference defaults, from `OnnxV3LiteEngine.infer`.
  static const double defaultTemperature = 0.8;
  static const int defaultTopK = 25;
  static const double defaultTopP = 0.95;
  static const int defaultMaxNewFrames = 300;
  static const double defaultRepetitionPenalty = 1.2;

  int get sampleRate => config.audioSampleRate;

  Future<SynthesisOutput> synthesize({
    required String phonemes,
    required Float32List speakerEmbedding,
    Int32List? refCodes,
    int refFrames = 0,
    double temperature = defaultTemperature,
    int topK = defaultTopK,
    double topP = defaultTopP,
    int maxNewFrames = defaultMaxNewFrames,
    double repetitionPenalty = defaultRepetitionPenalty,
    int repetitionWindow = VieNeuSampler.defaultRepetitionWindow,
    bool frameCap = true,
  }) async {
    if (phonemes.trim().isEmpty) {
      return SynthesisOutput(
        samples: Float32List(0),
        sampleRate: sampleRate,
        frames: 0,
        maxFrames: 0,
      );
    }

    final cap = frameCap
        ? math.min(maxNewFrames, maxExpectedFrames(phonemes))
        : maxNewFrames;

    // Phase timings answer "where did the time go" when a sentence exceeds the
    // host-side timeout — printed to the debug console (AppLog info), because
    // a hang inside a phase leaves no other trace.
    var clock = DateTime.now();
    int sinceClock() => DateTime.now().difference(clock).inMilliseconds;

    final hiddenSize = config.hiddenSize;
    final layers = config.numHiddenLayers;
    final anchor = heads.speakerAnchor(speakerEmbedding);
    final rows = _buildRows(phonemes, refCodes, refFrames);
    final rowCount = rows.length ~/ config.rowWidth;
    final promptEmbeds = heads.embedRows(rows, rowCount, anchor: anchor);

    var pastK = <OnnxHandle>[];
    var pastV = <OnnxHandle>[];

    try {
      // ── Prefill ───────────────────────────────────────────────────────────
      final promptHandle = await sessions.prefill.create(OnnxTensor.float32(
        name: 'inputs_embeds',
        shape: <int>[1, rowCount, hiddenSize],
        values: promptEmbeds,
      ));
      Map<String, OnnxHandle> prefillOutputs;
      try {
        prefillOutputs = await sessions.prefill
            .run(<String, OnnxHandle>{'inputs_embeds': promptHandle});
      } finally {
        await sessions.prefill.release(promptHandle);
      }

      final prefillHiddenHandle = _require(prefillOutputs, 'hidden');
      final prefillHidden =
          (await sessions.prefill.read(prefillHiddenHandle, 'hidden')).asFloat32;
      await sessions.prefill.release(prefillHiddenHandle);
      var current = _row(prefillHidden, rowCount - 1, hiddenSize);

      for (var layer = 0; layer < layers; layer++) {
        pastK.add(_require(prefillOutputs, 'present_k_$layer'));
        pastV.add(_require(prefillOutputs, 'present_v_$layer'));
      }
      AppLog.info('vieneu.phase.prefill', data: {'ms': sinceClock()});
      clock = DateTime.now();

      // ── Frame loop ────────────────────────────────────────────────────────
      final history = repetitionPenalty != 1.0
          ? RepetitionHistory(config.nVq, window: repetitionWindow)
          : null;
      final frames = <Int32List>[];

      for (var step = 0; step < cap; step++) {
        // Liveness: a sentence that dies to the host timeout leaves this as
        // its last trace, naming the step it stalled on.
        if (step % 50 == 0) {
          AppLog.info('vieneu.phase.frames.step',
              data: {'step': step, 'of': cap});
        }
        final frame = await _acousticFrame(
          current,
          history: history,
          anchor: anchor,
          temperature: temperature,
          topK: topK,
          topP: topP,
          repetitionPenalty: repetitionPenalty,
        );
        frames.add(frame.codes);
        if (frame.endOfSpeech) break;

        final slotRows = Int32List(config.rowWidth);
        slotRows[0] = config.speechGenerationStartTokenId;
        for (var ch = 0; ch < config.nVq; ch++) {
          slotRows[ch + 1] = frame.codes[ch];
        }
        final stepEmbeds = heads.embedRows(slotRows, 1, anchor: anchor);

        final embedsHandle = await sessions.decodeStep.create(OnnxTensor.float32(
          name: 'inputs_embeds',
          shape: <int>[1, 1, hiddenSize],
          values: stepEmbeds,
        ));
        final positionsHandle = await sessions.decodeStep.create(OnnxTensor.int64(
          name: 'position_ids',
          shape: <int>[1, 1],
          values: Int64List.fromList(<int>[rowCount + step]),
        ));

        final inputs = <String, OnnxHandle>{
          'inputs_embeds': embedsHandle,
          'position_ids': positionsHandle,
        };
        for (var layer = 0; layer < layers; layer++) {
          inputs['past_k_$layer'] = pastK[layer];
          inputs['past_v_$layer'] = pastV[layer];
        }

        Map<String, OnnxHandle> outputs;
        try {
          outputs = await sessions.decodeStep.run(inputs);
        } finally {
          // Tensors this app created are ours to free; the cache handles were
          // borrowed from the previous step and are freed just below.
          await sessions.decodeStep.release(embedsHandle);
          await sessions.decodeStep.release(positionsHandle);
        }

        // Free the consumed cache before adopting the new one, so peak native
        // memory is two steps of cache rather than a whole sentence (NFR-04).
        for (final handle in pastK) {
          await sessions.decodeStep.release(handle);
        }
        for (final handle in pastV) {
          await sessions.decodeStep.release(handle);
        }
        pastK = <OnnxHandle>[
          for (var layer = 0; layer < layers; layer++)
            _require(outputs, 'present_k_$layer'),
        ];
        pastV = <OnnxHandle>[
          for (var layer = 0; layer < layers; layer++)
            _require(outputs, 'present_v_$layer'),
        ];

        final stepHiddenHandle = _require(outputs, 'hidden');
        final stepHidden =
            (await sessions.decodeStep.read(stepHiddenHandle, 'hidden')).asFloat32;
        current = Float32List(hiddenSize)
          ..setRange(0, hiddenSize, stepHidden);
        await sessions.decodeStep.release(stepHiddenHandle);
      }

      AppLog.info('vieneu.phase.frames',
          data: {'ms': sinceClock(), 'frames': frames.length, 'cap': cap});
      clock = DateTime.now();

      if (frames.isEmpty) {
        return SynthesisOutput(
          samples: Float32List(0),
          sampleRate: sampleRate,
          frames: 0,
          maxFrames: cap,
        );
      }

      final samples = await _decodeCodes(frames);
      AppLog.info('vieneu.phase.decode',
          data: {'ms': sinceClock(), 'frames': frames.length});
      return SynthesisOutput(
        samples: samples,
        sampleRate: sampleRate,
        frames: frames.length,
        maxFrames: cap,
      );
    } finally {
      // Nothing may leak on any path: a surviving cache per sentence is exactly
      // the native-memory growth NFR-04 forbids.
      for (final handle in pastK) {
        await sessions.decodeStep.release(handle);
      }
      for (final handle in pastV) {
        await sessions.decodeStep.release(handle);
      }
    }
  }

  /// One frame: 16 codes plus whether the model said "stop".
  Future<_AcousticFrame> _acousticFrame(
    Float32List condition, {
    required RepetitionHistory? history,
    required Float32List anchor,
    required double temperature,
    required int topK,
    required double topP,
    required double repetitionPenalty,
  }) async {
    final hiddenSize = config.hiddenSize;
    final acoustic = sessions.acoustic;
    final previousCodes =
        Float32List(config.audioVocabSize); // scratch, reused per channel

    // Slot 0 is conditioned on the backbone's last hidden row *and* on the
    // speech-generation token: that pair is what tells the acoustic decoder
    // "begin a frame here".
    final openingEmbeds = Float32List(2 * hiddenSize);
    openingEmbeds.setRange(0, hiddenSize, condition);
    heads.writeTextRow(
      config.speechGenerationStartTokenId,
      openingEmbeds,
      hiddenSize,
    );

    var tokenHandle = await acoustic.create(OnnxTensor.float32(
      name: 'token_emb',
      shape: <int>[1, 2, hiddenSize],
      values: openingEmbeds,
    ));
    var positionHandle = await acoustic.create(OnnxTensor.int64(
      name: 'position_ids',
      shape: <int>[1, 2],
      values: Int64List.fromList(<int>[0, 1]),
    ));
    var cacheK = await acoustic.create(_emptyAcousticPastTensor('past_k_0'));
    var cacheV = await acoustic.create(_emptyAcousticPastTensor('past_v_0'));

    Map<String, OnnxHandle> outputs;
    try {
      outputs = await acoustic.run(<String, OnnxHandle>{
        'token_emb': tokenHandle,
        'position_ids': positionHandle,
        'past_k_0': cacheK,
        'past_v_0': cacheV,
      });
    } finally {
      await acoustic.release(tokenHandle);
      await acoustic.release(positionHandle);
      await acoustic.release(cacheK);
      await acoustic.release(cacheV);
    }

    var presentK = _require(outputs, 'present_k_0');
    var presentV = _require(outputs, 'present_v_0');
    var hidden = await _readHidden(outputs);

    // The stop verdict comes from slot 0 only, and it is read once, before the
    // channel loop overwrites anything.
    final slotZero = _row(hidden, 0, hiddenSize);
    final endOfSpeech = _argmax(heads.textLogits(slotZero)) ==
        config.speechGenerationEndTokenId;

    final codes = Int32List(config.nVq);
    codes[0] = _draw(0, _row(hidden, 1, hiddenSize), previousCodes, history,
        temperature, topK, topP, repetitionPenalty);

    for (var channel = 1; channel < config.nVq; channel++) {
      final embedding = heads.audioRow(channel - 1, codes[channel - 1]);
      tokenHandle = await acoustic.create(OnnxTensor.float32(
        name: 'token_emb',
        shape: <int>[1, 1, hiddenSize],
        values: embedding,
      ));
      positionHandle = await acoustic.create(OnnxTensor.int64(
        name: 'position_ids',
        shape: <int>[1, 1],
        values: Int64List.fromList(<int>[channel + 1]),
      ));

      Map<String, OnnxHandle> channelOutputs;
      try {
        channelOutputs = await acoustic.run(<String, OnnxHandle>{
          'token_emb': tokenHandle,
          'position_ids': positionHandle,
          'past_k_0': presentK,
          'past_v_0': presentV,
        });
      } finally {
        await acoustic.release(tokenHandle);
        await acoustic.release(positionHandle);
        await acoustic.release(presentK);
        await acoustic.release(presentV);
      }

      presentK = _require(channelOutputs, 'present_k_0');
      presentV = _require(channelOutputs, 'present_v_0');
      hidden = await _readHidden(channelOutputs);
      codes[channel] = _draw(channel, _row(hidden, 0, hiddenSize), previousCodes,
          history, temperature, topK, topP, repetitionPenalty);
    }

    await acoustic.release(presentK);
    await acoustic.release(presentV);
    return _AcousticFrame(codes: codes, endOfSpeech: endOfSpeech);
  }

  int _draw(
    int channel,
    Float32List vector,
    Float32List scratch,
    RepetitionHistory? history,
    double temperature,
    int topK,
    double topP,
    double repetitionPenalty,
  ) {
    final logits = heads.codebookLogits(channel, vector, into: scratch);
    final code = sampler.sample(
      logits,
      temperature: temperature,
      topK: topK,
      topP: topP,
      repetitionPenalty: repetitionPenalty,
      channel: channel,
      history: history,
    );
    history?[channel].add(code);
    return code;
  }

  Future<Float32List> _readHidden(Map<String, OnnxHandle> outputs) async {
    final handle = _require(outputs, 'hidden');
    try {
      return (await sessions.acoustic.read(handle, 'hidden')).asFloat32;
    } finally {
      await sessions.acoustic.release(handle);
    }
  }

  OnnxTensor _emptyAcousticPastTensor(String name) => OnnxTensor.zeros(
        name: name,
        type: OnnxDataType.float32,
        shape: <int>[1, config.localNumAttentionHeads, 0, config.localHeadDim],
      );

  /// `(T, nVq)` codes → one mono waveform at 48 kHz.
  Future<Float32List> _decodeCodes(List<Int32List> frames) async {
    final frameCount = frames.length;
    final codes = Int32List(frameCount * config.nVq);
    for (var frame = 0; frame < frameCount; frame++) {
      codes.setRange(
        frame * config.nVq,
        (frame + 1) * config.nVq,
        frames[frame],
      );
    }

    final codec = sessions.codec;
    final codesHandle = await codec.create(OnnxTensor.int32(
      name: 'audio_codes',
      shape: <int>[1, frameCount, config.nVq],
      values: codes,
    ));
    final lengthsHandle = await codec.create(OnnxTensor.int32(
      name: 'audio_code_lengths',
      shape: <int>[1],
      values: Int32List.fromList(<int>[frameCount]),
    ));

    Map<String, OnnxHandle> outputs;
    try {
      outputs = await codec.run(<String, OnnxHandle>{
        'audio_codes': codesHandle,
        'audio_code_lengths': lengthsHandle,
      });
    } finally {
      await codec.release(codesHandle);
      await codec.release(lengthsHandle);
    }

    final audioHandle = _require(outputs, 'audio');
    try {
      final tensor = await codec.read(audioHandle, 'audio');
      final data = tensor.asFloat32;
      final shape = tensor.shape;
      // `(1, channels, samples)`. The reference averages the channels
      // (`out[0][0].mean(0)`), which is how the codec's two output channels
      // collapse to the mono track this app plays.
      final channels = shape.length >= 3 ? shape[shape.length - 2] : 1;
      final samples = shape.isEmpty ? 0 : shape.last;
      if (channels <= 1) {
        return Float32List(samples)..setRange(0, math.min(samples, data.length), data);
      }
      final mono = Float32List(samples);
      for (var i = 0; i < samples; i++) {
        var sum = 0.0;
        for (var c = 0; c < channels; c++) {
          final index = c * samples + i;
          if (index < data.length) sum += data[index];
        }
        mono[i] = sum / channels;
      }
      return mono;
    } finally {
      await codec.release(audioHandle);
    }
  }

  /// Rebuilds the reference's `build_rows`.
  Int32List _buildRows(String phonemes, Int32List? refCodes, int refFrames) {
    final tokenIds = tokenizer.encode(phonemes);
    final width = config.rowWidth;
    final textRows = 2 + tokenIds.length + 1;
    final total = textRows + refFrames;
    final rows = Int32List(total * width)
      ..fillRange(0, total * width, config.audioPadTokenId);

    rows[0] = config.defaultStyleTokenId;
    rows[width] = config.textPromptStartTokenId;
    for (var i = 0; i < tokenIds.length; i++) {
      rows[(2 + i) * width] = tokenIds[i];
    }
    rows[(2 + tokenIds.length) * width] = config.textPromptEndTokenId;

    if (refCodes != null && refFrames > 0) {
      for (var frame = 0; frame < refFrames; frame++) {
        final rowOffset = (textRows + frame) * width;
        rows[rowOffset] = config.audioRefSlotTokenId;
        for (var ch = 0; ch < config.nVq; ch++) {
          rows[rowOffset + ch + 1] = refCodes[frame * config.nVq + ch];
        }
      }
    }
    return rows;
  }

  OnnxHandle _require(Map<String, OnnxHandle> outputs, String name) {
    final handle = outputs[name];
    if (handle == null) {
      throw CorruptModelFailure(
        message: 'Model trả về thiếu đầu ra "$name". Cần tải lại model.',
        detail: 'có: ${outputs.keys.join(', ')}',
      );
    }
    return handle;
  }

  /// One row of a `(rows, hiddenSize)` activation block, copied out so the
  /// source buffer can be freed.
  static Float32List _row(Float32List matrix, int row, int width) {
    final start = row * width;
    if (start + width > matrix.length) {
      throw CorruptModelFailure(
        message: 'Model trả về dữ liệu kích thước không mong đợi.',
        detail: 'cần hàng $row rộng $width trong ${matrix.length} giá trị',
      );
    }
    return Float32List(width)..setRange(0, width, matrix, start);
  }

  static int _argmax(Float32List values) {
    var best = 0;
    var bestValue = values[0];
    // First maximum wins, like `np.argmax`.
    for (var i = 1; i < values.length; i++) {
      if (values[i] > bestValue) {
        bestValue = values[i];
        best = i;
      }
    }
    return best;
  }
}

class _AcousticFrame {
  const _AcousticFrame({required this.codes, required this.endOfSpeech});
  final Int32List codes;
  final bool endOfSpeech;
}
