import 'package:flutter/foundation.dart' show immutable;

/// Where a saved position sits in a document — SRS §33 `reading_progress`.
///
/// Keyed by block and sentence rather than by character offset, because a
/// character offset is meaningless once the user edits extracted text (FR-08).
@immutable
class ReadingPosition {
  const ReadingPosition({
    required this.documentId,
    this.pageNumber,
    this.blockId,
    this.sentenceIndex = 0,
    this.positionMs = 0,
    required this.updatedAt,
  });

  final String documentId;
  final int? pageNumber;
  final String? blockId;

  /// Index into the document's flattened sentence list (FR-12).
  final int sentenceIndex;

  /// Playback offset inside the current sentence, so resuming does not repeat
  /// a word the user already heard.
  final int positionMs;

  final DateTime updatedAt;

  static ReadingPosition initial(String documentId, DateTime at) =>
      ReadingPosition(documentId: documentId, updatedAt: at);

  ReadingPosition copyWith({
    int? pageNumber,
    Object? blockId = _unset,
    int? sentenceIndex,
    int? positionMs,
    DateTime? updatedAt,
  }) =>
      ReadingPosition(
        documentId: documentId,
        pageNumber: pageNumber ?? this.pageNumber,
        blockId: identical(blockId, _unset) ? this.blockId : blockId as String?,
        sentenceIndex: sentenceIndex ?? this.sentenceIndex,
        positionMs: positionMs ?? this.positionMs,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  static const Object _unset = Object();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingPosition &&
          other.documentId == documentId &&
          other.pageNumber == pageNumber &&
          other.blockId == blockId &&
          other.sentenceIndex == sentenceIndex &&
          other.positionMs == positionMs &&
          other.updatedAt == updatedAt);

  @override
  int get hashCode => Object.hash(
      documentId, pageNumber, blockId, sentenceIndex, positionMs, updatedAt);

  @override
  String toString() =>
      'ReadingPosition($documentId, page $pageNumber, sentence $sentenceIndex)';
}

/// The synthesis/playback state machine for a single sentence.
///
/// One enum rather than several loose booleans: `isQueued` + `isFailed` at once
/// is an impossible state that a boolean pair would happily encode.
enum SentenceStatus {
  idle,
  queued,
  synthesizing,
  ready,
  playing,
  played,
  failed,
}

/// One unit of FR-12 sentence-level TTS.
///
/// Documents are never generated as a single audio file: each sentence is
/// synthesized and cached on its own so playback starts immediately, pause and
/// seek are cheap, and the Listening Spine always has a discrete thing to point
/// at.
@immutable
class Sentence {
  const Sentence({
    required this.index,
    required this.text,
    required this.blockId,
    this.pageNumber,
    this.status = SentenceStatus.idle,
    this.audioPath,
    this.durationMs,
    this.synthesisMs,
    this.failureMessage,
  });

  /// Position in the document's flattened sentence list, 0-based.
  final int index;

  final String text;
  final String blockId;
  final int? pageNumber;

  final SentenceStatus status;

  final String? audioPath;
  final int? durationMs;

  /// Wall-clock milliseconds this sentence's audio took to produce, or `null` if
  /// it came from the cache or has not been made yet.
  ///
  /// Distinct from [durationMs], which is how long the audio *plays* for. The
  /// gap between the two is the whole story of this app on a phone: on the
  /// device this was measured on, 1.1 s of audio cost 15.2 s to make, and a user
  /// left guessing whether the app had hung has no way to tell that from the
  /// audio alone.
  ///
  /// A measurement, never a guess — the same rule as [durationMs].
  final int? synthesisMs;

  /// Real cause when [status] is [SentenceStatus.failed].
  final String? failureMessage;

  bool get hasAudio => audioPath != null;

  Sentence copyWith({
    SentenceStatus? status,
    Object? audioPath = _unset,
    Object? durationMs = _unset,
    Object? synthesisMs = _unset,
    Object? failureMessage = _unset,
  }) =>
      Sentence(
        index: index,
        text: text,
        blockId: blockId,
        pageNumber: pageNumber,
        status: status ?? this.status,
        audioPath:
            identical(audioPath, _unset) ? this.audioPath : audioPath as String?,
        durationMs:
            identical(durationMs, _unset) ? this.durationMs : durationMs as int?,
        synthesisMs: identical(synthesisMs, _unset)
            ? this.synthesisMs
            : synthesisMs as int?,
        failureMessage: identical(failureMessage, _unset)
            ? this.failureMessage
            : failureMessage as String?,
      );

  static const Object _unset = Object();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Sentence &&
          other.index == index &&
          other.text == text &&
          other.blockId == blockId &&
          other.pageNumber == pageNumber &&
          other.status == status &&
          other.audioPath == audioPath &&
          other.durationMs == durationMs &&
          other.synthesisMs == synthesisMs &&
          other.failureMessage == failureMessage);

  @override
  int get hashCode => Object.hash(index, text, blockId, pageNumber, status,
      audioPath, durationMs, synthesisMs, failureMessage);

  @override
  String toString() => 'Sentence($index, ${status.name})';
}
