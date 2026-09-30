import 'dart:async' show Completer;
import 'dart:convert' show LineSplitter;
import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui show Image, ImageByteFormat, PixelFormat, decodeImageFromPixels;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdfrx/pdfrx.dart';

import '../../core/logging/app_log.dart';
import '../../core/result/result.dart';
import '../engines/document_extractor.dart';
import '../engines/ocr_engine.dart';
import '../engines/progress.dart' show JobStage, ProgressCallback;
import '../imaging/document_scanner.dart';
import '../imaging/enhancement.dart';
import '../models/document_block.dart' show BlockType;
import '../models/document_image.dart' show ImageInput;
import '../models/extraction.dart' show ExtractionResult, ExtractedPage;
import '../models/imported_file.dart' show ImportedFile;
import '../models/structured_block.dart' show StructuredBlock;
import '../ocr/ocr_structurer.dart';
import '../text/text_normalizer.dart';
import 'file_bytes.dart' show readImportedBytes;

/// Longest edge, in pixels, a scanned page is rendered to before OCR.
///
/// A 300 dpi A4 scan is 2480×3508 — 8.7 megapixels, which ML Kit has to
/// downscale anyway and which a mid-range phone pays for in memory (NFR-04).
/// 2000 px keeps small print legible while staying inside what the recognizer
/// is tuned for.
const int _maxOcrRenderEdge = 2000;

/// PDF → text blocks, using text layer when available, OCR when scanned.
///
/// Follows the contract in [DocumentExtractor]:
/// * Page-at-a-time loading (NFR-04)
/// * Per-page OCR decision (FR-05) - reports hasTextLayer honestly per page
/// * Preserves reading order in blocks.order
/// * Reports progress
/// * Typed failures for encrypted/corrupt PDFs
class PdfExtractor implements DocumentExtractor {
  const PdfExtractor({this.ocr, this.structurer, this.scanner});

  /// All three are optional: without them a text-layer PDF still imports, and
  /// only a scanned page reports that it needs OCR.
  final OcrEngine? ocr;
  final OcrStructurer? structurer;

  /// Prepares each rendered page for recognition, the same way an imported image
  /// is prepared. A scanned page carries every one of a phone photo's problems —
  /// skew, uneven lighting, low contrast — and the render cannot fix any of them.
  final DocumentScanner? scanner;

  @override
  String get id => 'pdf';

  @override
  Set<String> get supportedExtensions => const <String>{'pdf'};

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

      final pdfDocument = await PdfDocument.openData(bytes);
      try {
        final pages = pdfDocument.pages;
        final pageCount = pages.length;
        if (pageCount == 0) {
          return const Failure(ValidationFailure(
            message: 'Tệp PDF này không có trang nào.',
          ));
        }

        // Running headers repeat across pages, so the structurer's memory is
        // per document and must start empty.
        structurer?.reset();

        final blocks = <StructuredBlock>[];
        final pageInfo = <ExtractedPage>[];
        var order = 0;
        var scannedPages = 0;

        for (var pageNumber = 0; pageNumber < pageCount; pageNumber++) {
          onProgress?.call(
            (pageNumber + 1) / pageCount,
            JobStage.extracting,
          );

          final page = pages[pageNumber];

          // pdfrx exposes the text layer via `loadText()`; a null result or an
          // empty string means this page has no extractable text (a scanned
          // image) and belongs to the OCR path.
          final rawText = await page.loadText();
          final pageText = rawText?.fullText;
          final hasTextLayer = pageText != null && pageText.trim().isNotEmpty;

          var pageBlocks = const <StructuredBlock>[];
          if (hasTextLayer) {
            // Normalize the extracted text (numbers, currency, etc.)
            final normalizedText = TextNormalizer().normalize(pageText);
            // Convert to blocks (paragraphs)
            pageBlocks = _paragraphsToBlocks(normalizedText, startOrder: order);
            blocks.addAll(pageBlocks);
            order += pageBlocks.length;
          } else {
            scannedPages++;
            final ocrOutcome = await _ocrPage(
              page,
              pageNumber: pageNumber + 1,
              startOrder: order,
              onProgress: (value) => onProgress?.call(
                (pageNumber + value) / pageCount,
                JobStage.runningOcr,
              ),
            );
            switch (ocrOutcome) {
              case Success(:final value):
                pageBlocks = value;
                blocks.addAll(pageBlocks);
                order += pageBlocks.length;
              case Failure(:final failure):
                return Failure<ExtractionResult>(failure);
            }
          }

          // Record page info for reporting
          pageInfo.add(ExtractedPage(
            pageNumber: pageNumber + 1,
            hasTextLayer: hasTextLayer,
            blockCount: pageBlocks.length,
          ));
        }

        if (blocks.isEmpty) {
          if (scannedPages > 0) {
            // OCR ran and found nothing: a blank scan, not a broken file.
            return const Failure(ValidationFailure(
              message: 'PDF này là ảnh chụp nhưng không nhận dạng được chữ nào. '
                  'Thử bản có lớp chữ, hoặc chụp lại trang rõ hơn.',
            ));
          }
          return const Failure(ValidationFailure(
            message: 'Tệp PDF này không có nội dung văn bản đọc được.',
          ));
        }

        onProgress?.call(1, JobStage.done);
        return Success(ExtractionResult(
          blocks: blocks,
          pages: pageInfo,
        ));
      } finally {
        await pdfDocument.dispose();
      }
    } on PdfException catch (error) {
      // Handle PDF-specific errors
      if (error.message.contains('encrypted') ||
          error.message.contains('password') ||
          error.message.contains('encrypt')) {
        return Failure(EncryptedDocumentFailure(
          message: 'Tệp PDF này được mã hóa và cần mật khẩu để mở.',
          cause: error,
        ));
      } else {
        return Failure(ValidationFailure(
          message: 'Tệp PDF bị hỏng hoặc không đúng định dạng.',
          detail: error.message,
          cause: error,
        ));
      }
    } catch (error) {
      return Failure(ProcessingFailure(
        message: 'Không thể xử lý tệp PDF này.',
        detail: error.toString(),
        cause: error,
      ));
    }
  }

  /// Renders one scanned page and runs it through OCR.
  ///
  /// The render is what makes a scanned PDF readable at all: there is no text to
  /// parse, so the page has to become a bitmap before the recognizer can see it.
  /// The bitmap is encoded to PNG and handed over as bytes rather than a path
  /// because a temp file per page would leave the app cleaning up after itself
  /// for the rest of the document.
  Future<Result<List<StructuredBlock>>> _ocrPage(
    PdfPage page, {
    required int pageNumber,
    required int startOrder,
    required void Function(double progress) onProgress,
  }) async {
    final engine = ocr;
    final structures = structurer;
    if (engine == null || structures == null) {
      return const Failure(ModelUnavailableFailure(
        message: 'PDF này là ảnh chụp và cần nhận dạng chữ, nhưng bộ nhận dạng '
            'chưa được bật.',
        modelId: 'ocr',
      ));
    }
    if (!engine.isReady) {
      return const Failure(ModelUnavailableFailure(
        message: 'Chưa có bộ nhận dạng chữ trên máy.',
        modelId: 'ocr',
      ));
    }

    onProgress(0);
    final Uint8List? rendered = await _renderPage(page);
    if (rendered == null) {
      return Failure(ProcessingFailure(
        message: 'Không dựng được trang $pageNumber để nhận dạng chữ.',
        pageNumber: pageNumber,
      ));
    }

    onProgress(0.3);
    final recognized = await engine.recognize(
      await _prepare(pageNumber, rendered, onProgress),
      onProgress: (value, _) => onProgress(0.3 + value * 0.6),
    );

    switch (recognized) {
      case Failure(:final failure):
        return Failure(failure);
      case Success(:final value):
        if (value.isEmpty) {
          // A blank page in a scan is normal; it contributes no blocks but must
          // not abort the document.
          return const Success(<StructuredBlock>[]);
        }
        onProgress(0.95);
        return Success(structures.structure(
          value.lines,
          pageNumber: pageNumber,
          startOrder: startOrder,
        ));
    }
  }

  /// Runs a rendered page through the same preparation an imported image gets.
  ///
  /// Falls back to the render untouched when preparation fails: the render is
  /// already something the recognizer can attempt, and refusing it would turn a
  /// merely imperfect scan into a document that cannot be opened.
  Future<ImageInput> _prepare(
    int pageNumber,
    Uint8List rendered,
    void Function(double progress) onProgress,
  ) async {
    final scanner = this.scanner;
    if (scanner == null) {
      return ImageInput.bytes(rendered, mimeType: 'image/png');
    }

    final scan = await scanner.scan(
      ScanRequest(bytes: rendered, plan: EnhancementPlan.ocrDefault),
    );
    switch (scan) {
      case Success(:final value):
        return ImageInput.bytes(value.enhancedBytes, mimeType: 'image/png');
      case Failure(:final failure):
        AppLog.warning('import.pdf.enhance_failed', data: <String, Object?>{
          'page': pageNumber,
          'detail': failure.message,
        });
        return ImageInput.bytes(rendered, mimeType: 'image/png');
    }
  }

  /// Renders [page] to PNG bytes, or `null` when the platform cannot.
  Future<Uint8List?> _renderPage(PdfPage page) async {
    if (kIsWeb) {
      // The render pipeline is native-only; on the web the text layer is the
      // only path that works, and a scanned page reports that below.
      return null;
    }

    PdfImage? image;
    try {
      final width = page.width;
      final height = page.height;
      if (width <= 0 || height <= 0) return null;

      final scale = _maxOcrRenderEdge / (width > height ? width : height);
      final renderWidth = (width * (scale < 1 ? scale : 1)).round();
      final renderHeight = (height * (scale < 1 ? scale : 1)).round();

      image = await page.render(
        fullWidth: renderWidth.toDouble(),
        fullHeight: renderHeight.toDouble(),
        width: renderWidth,
        height: renderHeight,
      );
      if (image == null) return null;

      // `pixels` is BGRA8888; the recognizer needs encoded bytes, so the
      // buffer goes through dart:ui's decoder on the way out.
      final decoded = await _decode(
        image.pixels,
        width: image.width,
        height: image.height,
      );
      if (decoded == null) return null;

      final data = await decoded.toByteData(format: ui.ImageByteFormat.png);
      decoded.dispose();
      return data?.buffer.asUint8List();
    } catch (error) {
      AppLog.warning('import.pdf.render_failed', data: <String, Object?>{
        'reason': error.toString(),
      });
      return null;
    } finally {
      image?.dispose();
    }
  }

  /// Decodes raw BGRA pixels into a [ui.Image].
  Future<ui.Image?> _decode(
    Uint8List pixels, {
    required int width,
    required int height,
  }) {
    final completer = Completer<ui.Image?>();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.bgra8888,
      completer.complete,
    );
    return completer.future;
  }

  /// Convert blank-line-separated paragraphs to StructuredBlock list.
  List<StructuredBlock> _paragraphsToBlocks(String text, {int startOrder = 0}) {
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
}