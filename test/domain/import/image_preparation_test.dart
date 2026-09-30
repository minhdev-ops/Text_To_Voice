// The claim this file exists to keep honest: an imported image goes through the
// same page preparation a captured one does.
//
// A phone photo of a page is crooked, dimly lit and low-contrast. Handing that
// straight to the recognizer is what produced text like "Chss:B Sfot:40C" at 38%
// confidence on a real device import. This asserts the *bytes handed to OCR are
// the prepared ones*, since the recognizer is a fake here — the accuracy claim
// belongs to a device, the wiring claim belongs here.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:text_to_voice/core/result/result.dart';
import 'package:text_to_voice/core/storage/app_storage.dart';
import 'package:text_to_voice/domain/import/image_extractor.dart';
import 'package:text_to_voice/domain/imaging/document_scanner.dart';
import 'package:text_to_voice/domain/models/imported_file.dart'
    show ImportedFile;
import 'package:text_to_voice/domain/models/ocr.dart' show OcrLine;
import 'package:text_to_voice/domain/ocr/ocr_structurer.dart';

import '../../support/fake_ocr_engine.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  late Directory tempDir;
  late File photo;
  late Uint8List originalBytes;
  late FakeOcrEngine ocr;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('prepare_image_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    await AppStorage().initialize();
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  setUp(() {
    // A deliberately awkward "photo of a page": low contrast, uneven lighting,
    // slightly rotated. This is the shape of input that produced unreadable
    // text, so it is the shape worth asserting on.
    const width = 640;
    const height = 420;
    final page = img.Image(width: width, height: height, numChannels: 3);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        // Paper darkens toward the bottom; text bars sit on some rows only.
        final shade = 150 + (40 * y / height).round();
        final onTextRow = (y % 40) < 6 && x > 80 && x < 560;
        final value = onTextRow ? shade - 45 : shade;
        page.setPixelRgb(x, y, value, value, value);
      }
    }
    final rotated = img.copyRotate(page, angle: 1.4);

    photo = File('${tempDir.path}/anh-pho.png');
    photo.writeAsBytesSync(img.encodePng(rotated));
    originalBytes = photo.readAsBytesSync();

    ocr = FakeOcrEngine(
      lines: <OcrLine>[FakeOcrEngine.line('Nội dung.', top: 0.2, confidence: 0.9)],
    );
  });

  ImportedFile imported() => ImportedFile(
        name: 'anh-pho.png',
        path: photo.path,
        mimeType: 'image/png',
        size: photo.lengthSync(),
        headBytes: originalBytes.sublist(0, 512),
      );

  /// Luminance spread: how far the darkest ink sits from the brightest paper.
  /// A wider spread means more contrast for a recognizer to work with.
  double spreadOf(Uint8List pngBytes) {
    final decoded = img.decodePng(pngBytes)!;
    final histogram = List<int>.filled(256, 0);
    for (final pixel in decoded) {
      histogram[pixel.r.round().clamp(0, 255)]++;
    }
    final total = decoded.width * decoded.height;
    var low = 0;
    var high = 255;
    var seen = 0;
    for (var i = 0; i < 256; i++) {
      seen += histogram[i];
      if (seen >= total * 0.02) {
        low = i;
        break;
      }
    }
    seen = 0;
    for (var i = 255; i >= 0; i--) {
      seen += histogram[i];
      if (seen >= total * 0.02) {
        high = i;
        break;
      }
    }
    return (high - low) / 255;
  }

  group('an imported image is prepared before it is recognized', () {
    test('the recognizer is handed the enhanced page, not the raw file',
        () async {
      await ImageExtractor(
        ocr: ocr,
        structurer: OcrStructurer(),
        scanner: const DocumentScanner(),
      ).extract(imported());

      expect(ocr.received, hasLength(1));
      final input = ocr.received.single;
      expect(input.bytes, isNotNull,
          reason: 'a prepared page is handed over as bytes');
      expect(input.path, isNull,
          reason: 'the file on disk is the photo, not the prepared page');
    });

    test('preparation widens the contrast a recognizer has to work with',
        () async {
      await ImageExtractor(
        ocr: ocr,
        structurer: OcrStructurer(),
        scanner: const DocumentScanner(),
      ).extract(imported());

      final prepared = ocr.received.single.bytes!;
      expect(spreadOf(prepared), greaterThan(spreadOf(originalBytes)),
          reason: 'the scan pipeline stretches the tonal range');
    });

    test('without a scanner the original is still attempted, not refused',
        () async {
      await ImageExtractor(
        ocr: ocr,
        structurer: OcrStructurer(),
      ).extract(imported());

      expect(ocr.received, hasLength(1));
      expect(ocr.received.single.path, photo.path);
    });

    test('a file that cannot be read is reported, not silently skipped',
        () async {
      final missing = ImportedFile(
        name: 'khong-ton-tai.png',
        path: '${tempDir.path}/khong-ton-tai.png',
        mimeType: 'image/png',
        size: 10,
        headBytes: Uint8List(0),
      );

      final result = await ImageExtractor(
        ocr: ocr,
        structurer: OcrStructurer(),
        scanner: const DocumentScanner(),
      ).extract(missing);

      expect(result, isA<Failure>());
      expect(ocr.callCount, 0, reason: 'nothing to recognize, so nothing ran');
    });
  });
}
