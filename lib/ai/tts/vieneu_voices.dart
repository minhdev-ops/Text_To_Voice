import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/result/result.dart';

/// One selectable voice from the checkpoint's own catalog.
///
/// A voice is not a name — it is two pieces of data the model consumes:
///
/// * [speakerEmbedding] — a 192-d x-vector, projected to the hidden width and
///   added to every prompt row (the "anchor"),
/// * [refCodes] — the MOSS codes of a short reference clip, `(frames, nVq)`,
///   appended to the prompt as `audio_ref_slot` rows.
///
/// Both come from `voices_v3_turbo.json`, which is Apache-2.0 like the
/// checkpoint. An earlier version of this app synthesised *fake* embeddings from
/// a hash of the voice name; that produces noise, so the fake has been deleted
/// rather than kept as a fallback. A voice that is not in the catalog is an
/// error, not a guess.
class VieNeuVoice {
  const VieNeuVoice({
    required this.id,
    required this.label,
    required this.speakerEmbedding,
    required this.refCodes,
    required this.refFrames,
    required this.codebookCount,
    this.description,
    this.gender,
    this.region,
    this.style,
    this.aliases = const <String>[],
  });

  /// Stable id: the catalog's own key (the display name in the shipped file).
  /// Not slugged, so a name keeps its diacritics rather than being mangled into
  /// something a user would not recognise.
  final String id;

  final String label;
  final String? description;
  final String? gender;
  final String? region;
  final String? style;
  final List<String> aliases;

  /// `(speakerDimension,)`.
  final Float32List speakerEmbedding;

  /// `(refFrames, codebookCount)`, row-major.
  final Int32List refCodes;

  final int refFrames;

  /// The `nVq` this voice was encoded with — checked against the config so a
  /// catalog from a different export cannot be silently misread.
  final int codebookCount;

  /// One line for the voice picker: gender · region · style.
  String get subtitle {
    final parts = <String>[];
    final voiceGender = gender;
    if (voiceGender != null) parts.add(_word(voiceGender));
    final voiceRegion = region;
    if (voiceRegion != null) parts.add(voiceRegion);
    final voiceStyle = style;
    if (voiceStyle != null) parts.add(_styleWord(voiceStyle));
    return parts.join(' · ');
  }

  static String _word(String value) => value == 'male' ? 'Nam' : 'Nữ';

  static String _styleWord(String value) => switch (value) {
        'tu_nhien' => 'Tự nhiên',
        'tin_tuc' => 'Tin tức',
        'doc_truyen' => 'Đọc truyện',
        _ => value,
      };
}

/// The whole catalog, plus the default voice.
class VieNeuVoiceCatalog {
  const VieNeuVoiceCatalog({required this.voices, required this.defaultVoiceId});

  final List<VieNeuVoice> voices;
  final String defaultVoiceId;

  bool get isEmpty => voices.isEmpty;

  /// Resolves an id, an alias, or a case-insensitive form of either.
  VieNeuVoice? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final voice in voices) {
      if (voice.id == id || voice.aliases.contains(id)) return voice;
    }
    final lowered = id.toLowerCase();
    for (final voice in voices) {
      if (voice.id.toLowerCase() == lowered) return voice;
      if (voice.aliases.any((alias) => alias.toLowerCase() == lowered)) {
        return voice;
      }
    }
    return null;
  }

  /// The requested voice, or the catalog default.
  VieNeuVoice? resolve(String? id) => byId(id) ?? byId(defaultVoiceId) ?? voices.firstOrNull;

  static Future<Result<VieNeuVoiceCatalog>> fromAsset(String assetPath) async {
    try {
      return _parse(await rootBundle.loadString(assetPath));
    } catch (error) {
      return Result<VieNeuVoiceCatalog>.failure(CorruptModelFailure(
        message: 'Không đọc được danh sách giọng đọc.',
        detail: '$assetPath: $error',
        cause: error,
      ));
    }
  }

  static Future<Result<VieNeuVoiceCatalog>> fromFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return Result<VieNeuVoiceCatalog>.failure(ModelUnavailableFailure(
        message: 'Thiếu danh sách giọng đọc.',
        modelId: 'vieneu-v3-turbo',
      ));
    }
    try {
      return _parse(await file.readAsString());
    } catch (error) {
      return Result<VieNeuVoiceCatalog>.failure(CorruptModelFailure(
        message: 'Không đọc được danh sách giọng đọc.',
        detail: '$path: $error',
        cause: error,
      ));
    }
  }

  static Result<VieNeuVoiceCatalog> _parse(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('not a JSON object');
      }
      final presets = decoded['presets'];
      if (presets is! Map) {
        throw const FormatException('missing presets');
      }
      final voices = <VieNeuVoice>[];
      presets.forEach((key, value) {
        if (value is! Map) return;
        final codes = value['codes'];
        final embedding = value['speaker_emb'];
        if (codes is! List || codes.isEmpty || embedding is! List) return;

        final frames = codes.length;
        final codebookCount = (codes.first as List).length;
        final flatCodes = Int32List(frames * codebookCount);
        for (var frame = 0; frame < frames; frame++) {
          final row = codes[frame] as List;
          for (var ch = 0; ch < codebookCount; ch++) {
            flatCodes[frame * codebookCount + ch] = (row[ch] as num).toInt();
          }
        }
        voices.add(VieNeuVoice(
          id: '$key',
          label: '$key',
          description: value['description'] as String?,
          gender: value['gender'] as String?,
          region: value['region'] as String?,
          style: value['style'] as String?,
          aliases: <String>[
            for (final alias in (value['aliases'] as List? ?? const <dynamic>[]))
              '$alias',
          ],
          speakerEmbedding: Float32List.fromList(<double>[
            for (final value in embedding) (value as num).toDouble(),
          ]),
          refCodes: flatCodes,
          refFrames: frames,
          codebookCount: codebookCount,
        ));
      });
      if (voices.isEmpty) {
        throw const FormatException('no usable presets');
      }
      return Result<VieNeuVoiceCatalog>.success(VieNeuVoiceCatalog(
        voices: voices,
        defaultVoiceId: '${decoded['default_voice'] ?? voices.first.id}',
      ));
    } catch (error) {
      return Result<VieNeuVoiceCatalog>.failure(CorruptModelFailure(
        message: 'Danh sách giọng đọc bị hỏng.',
        detail: error.toString(),
        cause: error,
      ));
    }
  }
}
