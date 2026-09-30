import 'dart:convert' show utf8;
import 'dart:typed_data' show Uint8List;

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../core/result/result.dart';
import '../engines/document_extractor.dart';
import '../engines/progress.dart' show JobStage, ProgressCallback;
import '../models/document_block.dart' show BlockType;
import '../models/extraction.dart' show ExtractionResult, ExtractedPage;
import '../models/imported_file.dart' show ImportedFile;
import '../models/structured_block.dart' show StructuredBlock;
import 'file_bytes.dart' show readImportedBytes;
import 'html_text.dart' show HtmlTextConverter;

/// EPUB → blocks, over `archive` + `xml` rather than a package.
///
/// `epubx` was the candidate and was **rejected on evidence**, not taste:
/// `test/domain/import/epub_extractor_test.dart` records why in prose, and the
/// short version is that its last release predates this project's `image`
/// dependency by two major versions and its constraint cannot be satisfied
/// alongside `image ^4`. An EPUB is a zip of XHTML; `archive` (already present via
/// `image`) and `xml` read it directly, and the parts that actually need care —
/// spine order, entity decoding, block structure — are the parts a package would
/// have made harder to test.
///
/// Reading order comes from the **spine**, which is the only ordering the format
/// guarantees. The manifest's order is arbitrary and sorting by file name puts
/// chapter 10 before chapter 2.
class EpubExtractor implements DocumentExtractor {
  const EpubExtractor();

  @override
  String get id => 'epub';

  @override
  Set<String> get supportedExtensions => const <String>{'epub'};

  @override
  Future<Result<ExtractionResult>> extract(
    ImportedFile file, {
    ProgressCallback? onProgress,
  }) async {
    onProgress?.call(0, JobStage.analyzing);
    try {
      final read = readImportedBytes(file);
      final bytes = read.valueOrNull;
      if (bytes == null) {
        return Failure<ExtractionResult>(read.failureOrNull!);
      }

      final archive = ZipDecoder().decodeBytes(bytes, verify: false);

      final containerFile = _entry(archive, 'META-INF/container.xml');
      if (containerFile == null) {
        return const Failure(ValidationFailure(
          message: 'Tệp này không phải EPUB hợp lệ: thiếu '
              'META-INF/container.xml.',
        ));
      }

      final opfPath = _rootfilePath(_readString(containerFile));
      if (opfPath == null) {
        return const Failure(ValidationFailure(
          message: 'Tệp EPUB không khai báo tài liệu gốc (rootfile).',
        ));
      }

      final opfFile = _entry(archive, opfPath);
      if (opfFile == null) {
        return Failure(ValidationFailure(
          message: 'Không tìm thấy tệp nội dung "$opfPath" trong EPUB.',
        ));
      }

      final opf = XmlDocument.parse(_readString(opfFile));
      final baseDirectory = _directoryOf(opfPath);
      final manifest = _manifest(opf);
      final spine = _spineOrder(opf);
      final title = _title(opf);

      if (spine.isEmpty) {
        return const Failure(ValidationFailure(
          message: 'EPUB này không có chương nào trong phần spine.',
        ));
      }

      final blocks = <StructuredBlock>[];
      var order = 0;
      var processed = 0;

      for (final id in spine) {
        final href = manifest[id];
        if (href == null) continue;
        final entry = _entry(archive, _join(baseDirectory, href));
        if (entry == null) continue;

        processed++;
        onProgress?.call(
          processed / spine.length,
          JobStage.extracting,
        );

        final produced = HtmlTextConverter.convert(
          _readString(entry),
          startOrder: order,
          // Only the first chapter carries the book title, and only if that
          // chapter has no heading of its own.
          documentTitle: order == 0 ? title : null,
        );
        blocks.addAll(produced);
        order += produced.length;
      }

      if (blocks.isEmpty) {
        return const Failure(ValidationFailure(
          message: 'EPUB này không có nội dung văn bản đọc được.',
        ));
      }

      onProgress?.call(1, JobStage.done);
      return Success(ExtractionResult(
        blocks: blocks,
        title: title,
        pages: <ExtractedPage>[
          for (var i = 0; i < processed; i++)
            ExtractedPage(pageNumber: i + 1, hasTextLayer: true),
        ],
      ));
    } on FormatException catch (error) {
      // A zip that will not decode, or XHTML that will not parse. Both mean the
      // same thing to the user, and naming the cause is still honest.
      return Failure(ValidationFailure(
        message: 'Tệp EPUB bị hỏng hoặc không đúng định dạng.',
        detail: error.message,
        cause: error,
      ));
    } catch (error) {
      return Failure(ProcessingFailure(
        message: 'Không trích xuất được nội dung từ EPUB này.',
        detail: error.toString(),
        cause: error,
      ));
    }
  }

  // -- EPUB internals --------------------------------------------------------

  /// Zip entries are matched case-insensitively: the format demands exact names,
  /// but real-world EPUBs from older tools do not always comply, and refusing a
  /// readable book over letter case helps nobody.
  ArchiveFile? _entry(Archive archive, String path) {
    final wanted = path.replaceAll('\\', '/').toLowerCase();
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final name = file.name.replaceAll('\\', '/').toLowerCase();
      if (name == wanted || name.endsWith('/$wanted')) return file;
    }
    return null;
  }

  String _readString(ArchiveFile file) {
    final content = file.content;
    if (content is Uint8List) {
      return utf8.decode(content, allowMalformed: true);
    }
    return utf8.decode(file.readBytes() ?? const <int>[], allowMalformed: true);
  }

  String? _rootfilePath(String containerXml) {
    try {
      final document = XmlDocument.parse(containerXml);
      for (final element in document.descendants.whereType<XmlElement>()) {
        if (element.name.local == 'rootfile') {
          return element.getAttribute('full-path');
        }
      }
    } on XmlException {
      return null;
    }
    return null;
  }

  String _directoryOf(String path) {
    final index = path.lastIndexOf('/');
    return index < 0 ? '' : path.substring(0, index);
  }

  String _join(String directory, String href) {
    final clean = href.split('#').first;
    if (clean.startsWith('/')) return clean.substring(1);
    if (directory.isEmpty) return clean;
    return '$directory/$clean';
  }

  /// `id` → href, from the OPF manifest.
  Map<String, String> _manifest(XmlDocument opf) {
    final manifest = <String, String>{};
    for (final element in opf.descendants.whereType<XmlElement>()) {
      if (element.name.local != 'item') continue;
      final id = element.getAttribute('id');
      final href = element.getAttribute('href');
      final type = element.getAttribute('media-type') ?? '';
      if (id == null || href == null) continue;
      // Only documents can contribute text; images and fonts cannot.
      if (!type.contains('html')) continue;
      manifest[id] = href;
    }
    return manifest;
  }

  /// The spine's `idref` list, in order, skipping `linear="no"` items.
  ///
  /// Non-linear items are the back matter a reading system is allowed to keep out
  /// of the flow (a colophon, an index), and read-aloud should not walk into them
  /// between chapters.
  List<String> _spineOrder(XmlDocument opf) {
    final order = <String>[];
    for (final element in opf.descendants.whereType<XmlElement>()) {
      if (element.name.local != 'itemref') continue;
      if (element.getAttribute('linear')?.toLowerCase() == 'no') continue;
      final idref = element.getAttribute('idref');
      if (idref != null) order.add(idref);
    }
    return order;
  }

  /// The book's title from the OPF metadata.
  ///
  /// Read with an explicit namespace-agnostic match: the DC namespace prefix is
  /// `dc` in almost every file but not in all of them, and matching on the literal
  /// tag name is what makes this work for both.
  String? _title(XmlDocument opf) {
    for (final element in opf.descendants.whereType<XmlElement>()) {
      if (element.name.local != 'title') continue;
      final value = element.innerText.trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }
}
