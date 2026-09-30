import 'dart:convert' show LineSplitter, utf8;
import 'dart:typed_data' show Uint8List;

import '../../core/result/result.dart';
import '../engines/document_extractor.dart';
import '../engines/progress.dart' show JobStage, ProgressCallback;
import '../models/document_block.dart' show BlockType;
import '../models/extraction.dart' show ExtractionResult;
import '../models/imported_file.dart' show ImportedFile;
import '../models/structured_block.dart' show StructuredBlock;
import 'file_bytes.dart' show readImportedBytes;

/// Plain text → blocks (FR-02's cheapest path).
///
/// Paragraphs are blank-line separated. That is the only structural signal a
/// `.txt` file actually carries, so inventing more (indenting as nesting, blank
/// runs as page breaks) would be guessing dressed up as parsing.
class TextExtractor implements DocumentExtractor {
  const TextExtractor();

  @override
  String get id => 'text-plain';

  @override
  Set<String> get supportedExtensions => const <String>{'txt'};

  @override
  Future<Result<ExtractionResult>> extract(
    ImportedFile file, {
    ProgressCallback? onProgress,
  }) async {
    onProgress?.call(0, JobStage.analyzing);
    return decodeTextFile(file).map((text) {
      onProgress?.call(1, JobStage.done);
      return ExtractionResult(
        blocks: paragraphsToBlocks(text, startOrder: 0),
        detectedLanguage: null,
      );
    });
  }
}

/// Markdown → blocks, keeping the heading hierarchy and lists.
///
/// Deliberately not a Markdown implementation. It reads the line-level structure
/// the reader and read-aloud actually use — headings, lists, blockquotes, fenced
/// code — and leaves inline emphasis as the characters the author typed. Stripping
/// `**bold**` would be a rewrite of the user's text; SRS FR-08 says the document is
/// what they wrote.
class MarkdownExtractor implements DocumentExtractor {
  const MarkdownExtractor();

  @override
  String get id => 'text-markdown';

  @override
  Set<String> get supportedExtensions => const <String>{'md'};

  @override
  Future<Result<ExtractionResult>> extract(
    ImportedFile file, {
    ProgressCallback? onProgress,
  }) async {
    onProgress?.call(0, JobStage.analyzing);
    return decodeTextFile(file).map((text) {
      onProgress?.call(1, JobStage.done);
      return ExtractionResult(blocks: markdownToBlocks(text));
    });
  }
}

/// Decodes a text file: UTF-8 (BOM tolerated), falling back to Latin-1.
///
/// The fallback matters because Vietnamese plain text exported from older Windows
/// tooling is routinely Latin-1, and refusing it would reject a file the user can
/// plainly read.
Result<String> decodeTextFile(ImportedFile file) {
  try {
    final read = readImportedBytes(file);
    final bytes = read.valueOrNull;
    if (bytes == null) {
      return Failure<String>(read.failureOrNull ??
          const StorageFailure(message: 'Không đọc được tệp này.'));
    }
    // Reject a UTF-16 BOM explicitly rather than decoding it as mojibake.
    if (bytes.length >= 2) {
      final b0 = bytes[0];
      final b1 = bytes[1];
      if ((b0 == 0xFF && b1 == 0xFE) || (b0 == 0xFE && b1 == 0xFF)) {
        return const Failure(ValidationFailure(
          message: 'Tệp dùng bảng mã UTF-16. Hãy lưu lại dạng UTF-8 rồi nhập '
              'lại.',
        ));
      }
    }
    return Success(_decode(bytes));
  } catch (error) {
    return Failure(StorageFailure(
      message: 'Không đọc được tệp này.',
      detail: error.toString(),
      cause: error,
    ));
  }
}

String _decode(Uint8List bytes) {
  try {
    final decoded = utf8.decode(bytes);
    return decoded.startsWith('\uFEFF') ? decoded.substring(1) : decoded;
  } on FormatException {
    return String.fromCharCodes(bytes);
  }
}

/// Blank-line-separated paragraphs, with blank runs collapsed.
List<StructuredBlock> paragraphsToBlocks(String text, {int startOrder = 0}) {
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final blocks = <StructuredBlock>[];
  var order = startOrder;

  final buffer = StringBuffer();
  void flush() {
    final content = buffer.toString().trim();
    buffer.clear();
    if (content.isEmpty) return;
    blocks.add(StructuredBlock(
      type: BlockType.paragraph,
      content: content,
      order: order++,
    ));
  }

  for (final line in const LineSplitter().convert(normalized)) {
    if (line.trim().isEmpty) {
      flush();
    } else {
      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write(line.trimRight());
    }
  }
  flush();
  return blocks;
}

/// Line-level Markdown structure.
List<StructuredBlock> markdownToBlocks(String text, {int startOrder = 0}) {
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final lines = const LineSplitter().convert(normalized);
  final blocks = <StructuredBlock>[];
  var order = startOrder;
  var inFence = false;

  final paragraph = StringBuffer();
  void flushParagraph() {
    final content = paragraph.toString().trim();
    paragraph.clear();
    if (content.isEmpty) return;
    blocks.add(StructuredBlock(
      type: BlockType.paragraph,
      content: content,
      order: order++,
    ));
  }

  for (final rawLine in lines) {
    final line = rawLine.trimRight();

    if (line.trimLeft().startsWith('```') || line.trimLeft().startsWith('~~~')) {
      // A fence toggles code mode; the fence line itself is not content.
      if (inFence) {
        final code = paragraph.toString().trim();
        paragraph.clear();
        if (code.isNotEmpty) {
          blocks.add(StructuredBlock(
            type: BlockType.paragraph,
            content: code,
            order: order++,
            metadata: const <String, Object?>{'preformatted': true},
          ));
        }
      } else {
        flushParagraph();
      }
      inFence = !inFence;
      continue;
    }

    if (inFence) {
      // Code keeps its own line breaks: reflowing it would change what it says.
      if (paragraph.isNotEmpty) paragraph.write('\n');
      paragraph.write(rawLine);
      continue;
    }

    final heading = _headingPattern.firstMatch(line);
    if (heading != null) {
      flushParagraph();
      blocks.add(StructuredBlock(
        type: BlockType.heading,
        content: heading.group(2)!.trim(),
        order: order++,
        level: heading.group(1)!.length.clamp(1, 3),
      ));
      continue;
    }

    if (line.trim().isEmpty) {
      flushParagraph();
      continue;
    }

    if (_listPattern.hasMatch(line)) {
      flushParagraph();
      blocks.add(StructuredBlock(
        type: BlockType.list,
        content: '• ${line.replaceFirst(_listPattern, '').trim()}',
        order: order++,
      ));
      continue;
    }

    if (line.startsWith('> ')) {
      flushParagraph();
      blocks.add(StructuredBlock(
        type: BlockType.paragraph,
        content: line.substring(2).trim(),
        order: order++,
        metadata: const <String, Object?>{'quote': true},
      ));
      continue;
    }

    final image = _imagePattern.firstMatch(line.trim());
    if (image != null) {
      flushParagraph();
      blocks.add(StructuredBlock(
        type: BlockType.image,
        content: image.group(1)!,
        order: order++,
        metadata: <String, Object?>{'src': image.group(3)!},
      ));
      continue;
    }

    if (paragraph.isNotEmpty) paragraph.write(' ');
    paragraph.write(line.trim());
  }

  flushParagraph();
  return blocks;
}

final RegExp _headingPattern = RegExp(r'^(#{1,6})\s+(.*)$');
final RegExp _listPattern = RegExp(r'^\s*(?:[-*+]|\d{1,3}[.)])\s+');
final RegExp _imagePattern = RegExp(r'^!\[([^\]]*)\]\(([^)]+)\)$');
