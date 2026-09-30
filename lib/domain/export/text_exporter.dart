import 'dart:convert';

import '../models/reading.dart';

/// The three text formats FR-14 asks for.
///
/// An enum rather than a string so the UI cannot offer a format the writer does
/// not implement, and so "which formats exist" is answerable in one place.
enum TextExportFormat {
  txt('txt', 'Văn bản (.txt)', 'text/plain'),
  md('md', 'Markdown (.md)', 'text/markdown'),
  json('json', 'JSON (.json)', 'application/json');

  const TextExportFormat(this.extension, this.label, this.mimeType);

  final String extension;

  /// Vietnamese label, shown in the export sheet.
  final String label;

  final String mimeType;
}

/// Renders read-aloud text into the requested format.
///
/// Deliberately pure: no file system, no plugin, no clock. What gets written is
/// decided here and tested here; where it lands is the service's problem.
///
/// Every renderer keeps the text **as the user typed it** — the normalizer's
/// output (numbers spelled out, currency expanded) is for the ear, and exporting
/// it would silently rewrite the user's document (FR-08: the reader shows the
/// original, and so must the export).
class TextExporter {
  const TextExporter();

  String render({
    required String text,
    required String title,
    required TextExportFormat format,
    List<Sentence> sentences = const <Sentence>[],
    DateTime? exportedAt,
  }) =>
      switch (format) {
        TextExportFormat.txt => _txt(text),
        TextExportFormat.md => _markdown(text, title),
        TextExportFormat.json => _json(text, title, sentences, exportedAt),
      };

  /// Plain text, verbatim. No header: a `.txt` export is the document, not a
  /// report about the document.
  String _txt(String text) => _ensureTrailingNewline(text);

  /// A heading plus the body, paragraphs preserved.
  String _markdown(String text, String title) {
    final body = text.trim();
    return _ensureTrailingNewline('# $title\n\n$body');
  }

  /// The structured form. Sentence-level, because sentence granularity is what
  /// this app actually has (FR-12) — inventing sections here would be a claim
  /// the reader cannot back up.
  String _json(
    String text,
    String title,
    List<Sentence> sentences,
    DateTime? exportedAt,
  ) {
    final payload = <String, Object?>{
      'title': title,
      if (exportedAt != null) 'exportedAt': exportedAt.toIso8601String(),
      'text': text.trim(),
      'sentenceCount': sentences.length,
      'sentences': <Map<String, Object?>>[
        for (final sentence in sentences)
          <String, Object?>{
            'index': sentence.index,
            'text': sentence.text,
            // Only when it was actually measured: a duration the app never
            // observed is not written as `0`.
            if (sentence.durationMs != null) 'durationMs': sentence.durationMs,
          },
      ],
    };
    // Indented: an export a human is expected to open should be readable.
    return '${const JsonEncoder.withIndent('  ').convert(payload)}\n';
  }

  static String _ensureTrailingNewline(String value) {
    final trimmed = value.trimRight();
    return trimmed.isEmpty ? '' : '$trimmed\n';
  }
}

/// A file name that is safe on disk **and still Vietnamese**.
///
/// DESIGN.md requires diacritics to survive into file names, so this does not
/// fold `ế` to `e`: it replaces only what a file system cannot carry
/// (separators, control characters, leading dots) and keeps the words.
String exportFileName(String title, String extension) {
  final cleaned = title
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '')
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^[.\-]+|[.\-]+$'), '');

  final stem = cleaned.isEmpty ? 'van-ban' : cleaned;
  // Long names are truncated by the filesystem anyway; truncating here keeps the
  // extension, which truncation would otherwise eat.
  final capped = stem.length > 60 ? stem.substring(0, 60) : stem;
  return '$capped.$extension';
}

/// A human title for a document that has no name yet.
///
/// Takes the opening words: it is derived from the text rather than invented,
/// which is the only kind of title this app can honestly produce before the
/// library exists (Phase 5 lets the user name documents).
String documentTitleFrom(String text, {int words = 8}) {
  final flattened = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flattened.isEmpty) return 'Văn bản';

  final parts = flattened.split(' ');
  final taken = parts.take(words).join(' ');
  if (parts.length <= words) return taken;
  return '$taken…';
}
