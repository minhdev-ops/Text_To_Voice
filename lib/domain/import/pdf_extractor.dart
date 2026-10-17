import 'dart:async' show Completer;
import 'dart:convert' show LineSplitter;
import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui show Image, ImageByteFormat, PixelFormat, decodeImageFromPixels;

import 'package:flutter/foundation.dart' show kIsWeb;

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

const int _maxOcrRenderEdge = 2000;

class PdfExtractor implements DocumentExtractor {
  const PdfExtractor({this.ocr, this.structurer, this.scanner});

  final OcrEngine? ocr;
  final OcrStructurer? structurer;
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
    return const Failure(
      ProcessingFailure(
        message: 'Trích xuất PDF chưa được hỗ trợ trên Windows.',
      ),
    );
  }

  Future<Result<List<StructuredBlock>>> _ocrPage(
    Object page, {
    required int pageNumber,
    required int startOrder,
    required void Function(double progress) onProgress,
  }) async {
    return const Failure(ModelUnavailableFailure(
      message: 'PDF extraction không khả dụng trên Windows.',
      modelId: 'pdf',
    ));
  }

  Future<ImageInput> _prepare(
    int pageNumber,
    Uint8List rendered,
    void Function(double progress) onProgress,
  ) async {
    return ImageInput.bytes(rendered, mimeType: 'image/png');
  }

  Future<Uint8List?> _renderPage(Object page) async {
    if (kIsWeb) {
      return null;
    }
    return null;
  }

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

  List<StructuredBlock> _paragraphsToBlocks(String text, {int startOrder = 0}) {
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
    for (final line in const LineSplitter().convert(text)) {
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
