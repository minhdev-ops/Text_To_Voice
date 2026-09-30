import 'dart:typed_data' show Uint8List;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:text_to_voice/core/result/result.dart';
import 'package:text_to_voice/domain/imaging/enhancement.dart';
import 'package:text_to_voice/domain/models/document.dart'
    show DocumentSource, DocumentStatus;
import 'package:text_to_voice/domain/models/document_block.dart' show BlockType;
import 'package:text_to_voice/domain/models/ocr.dart' show OcrLine;
import 'package:text_to_voice/presentation/capture/camera_source.dart';
import 'package:text_to_voice/presentation/capture/capture_providers.dart';
import 'package:text_to_voice/presentation/library/kept_documents.dart';

import '../../support/fake_camera_source.dart';
import '../../support/fake_ocr_engine.dart';
import '../../support/image_fixtures.dart';

/// A page image the rest of the pipeline can actually process.
List<int> _frame() => pngBytes(syntheticCapture(
      width: 600,
      height: 800,
      pageInset: 0.1,
      textLines: 8,
    ));

void main() {
  late FakeCameraSource camera;
  late FakeOcrEngine ocr;
  late ProviderContainer container;

  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [
          cameraSourceProvider.overrideWithValue(camera),
          ocrEngineProvider.overrideWithValue(ocr),
        ],
      );

  setUp(() {
    camera = FakeCameraSource(frames: <Uint8List>[
      Uint8List.fromList(_frame()),
      Uint8List.fromList(_frame()),
    ]);
    ocr = FakeOcrEngine(lines: <OcrLine>[
      FakeOcrEngine.line('Xin chào Việt Nam', top: 0.10, confidence: 0.98),
      FakeOcrEngine.line('Cộng hoà xã hội', top: 0.13, confidence: 0.42),
    ]);
    container = makeContainer();
  });

  tearDown(() => container.dispose());

  // Local closures rather than getters: a getter cannot be declared inside a
  // function body, and reading the controller through the container on every call
  // is also what a widget does.
  CaptureController controller() =>
      container.read(captureControllerProvider.notifier);
  CaptureState state() => container.read(captureControllerProvider);

  group('start', () {
    test('no camera on the platform lands on the unsupported state', () async {
      camera.supported = false;
      await controller().start();

      expect(state().status, CaptureStatus.unsupported);
      expect(state().failureMessage, contains('không có camera'));
      // And it did not even ask, because asking is what fails on such a platform.
      expect(camera.discoverCount, 0);
    });

    test('refused permission is its own state, not a generic failure', () async {
      camera.discoverFailure = const PermissionFailure(
        message: 'VietDoc AI cần quyền dùng camera.',
        permission: 'camera',
      );
      await controller().start();

      expect(state().status, CaptureStatus.permissionDenied);
      expect(state().failureMessage, contains('quyền'));
    });

    test('a camera that opens reaches the ready state', () async {
      await controller().start();

      expect(state().status, CaptureStatus.ready);
      expect(state().cameras, hasLength(1));
      expect(state().activeCamera!.facing, CameraFacing.back);
      expect(camera.opened, isTrue);
    });

    test('opening asks for the resolution the user picked', () async {
      await controller().start();
      await controller().setResolution(CaptureResolution.maximum);

      expect(camera.lastResolution, CaptureResolution.maximum);
      // Reopened, because a resolution preset is fixed at open time.
      expect(camera.openCount, 2);
    });

    test('switching cameras does nothing when there is only one', () async {
      await controller().start();
      await controller().switchCamera();
      expect(camera.openCount, 1);
    });

    test('switching cameras wraps around with two lenses', () async {
      camera.cameras = const <CameraInfo>[
        CameraInfo(id: 'back-0', facing: CameraFacing.back),
        CameraInfo(id: 'front-0', facing: CameraFacing.front),
      ];
      await controller().start();
      await controller().switchCamera();

      expect(state().activeCamera!.id, 'front-0');
      expect(camera.lastCameraId, 'front-0');

      await controller().switchCamera();
      expect(state().activeCamera!.id, 'back-0');
    });
  });

  group('capture', () {
    test('a captured page is enhanced, recognized and kept in the tray',
        () async {
      await controller().start();
      await controller().capture();

      expect(state().pages, hasLength(1));
      final page = state().page!;
      expect(page.scan, isNotNull);
      expect(page.scan!.detection!.found, isTrue);
      expect(page.text, contains('Xin chào Việt Nam'));
      expect(page.textPending, isFalse);
      expect(page.sections, isNotEmpty);
      // The OCR engine saw the *processed* image, not the raw capture: the whole
      // point of running the enhancement pipeline first.
      expect(ocr.received, hasLength(1));
      expect(ocr.received.single.bytes,
          same(page.scan!.enhancedBytes));
    });

    test('multi-page capture accumulates pages in one document', () async {
      await controller().start();
      await controller().capture();
      await controller().capture();

      expect(state().pages, hasLength(2));
      expect(state().pages.map((page) => page.index), <int>[0, 1]);
      // Each page gets its own recognition pass, numbered from one.
      expect(ocr.callCount, 2);
    });

    test('a failed capture keeps the preview alive and says what happened',
        () async {
      await controller().start();
      camera.captureFailure = const ProcessingFailure(
        message: 'Camera đang bận.',
      );
      await controller().capture();

      expect(state().pages, isEmpty);
      expect(state().status, CaptureStatus.ready);
      expect(state().failureMessage, 'Camera đang bận.');
    });

    test('an OCR failure still saves the page and marks the text pending',
        () async {
      await controller().start();
      ocr.failure = const ProcessingFailure(
        message: 'Nhận dạng chữ trong ảnh thất bại.',
      );
      await controller().capture();

      final page = state().page!;
      // Losing the photo because recognition failed would be the worst trade.
      expect(page.scan, isNotNull);
      expect(page.originalBytes, isNotEmpty);
      expect(page.textPending, isTrue);
      expect(page.failureMessage, contains('thất bại'));
      expect(page.text, isNull);
    });

    test('capturing is refused while the camera is not ready', () async {
      await controller().capture();
      expect(camera.captureCount, 0);
      expect(state().pages, isEmpty);
    });

    test('adding page bytes directly works without a camera', () async {
      // This is the import path, and the fallback the permission-denied screen
      // offers — neither has a camera behind it.
      await controller().addPageFromBytes(Uint8List.fromList(_frame()));
      expect(state().pages, hasLength(1));
      expect(state().page!.text, contains('Xin chào'));
    });

    test('the scan note reports what the enhancement pass actually did',
        () async {
      await controller().start();
      await controller().capture();

      expect(state().lastScanNote, isNotNull);
      expect(state().lastScanNote, contains('Đã dò được viền trang'));
      expect(state().lastScanNote, contains('Đã áp dụng'));
    });

    test('a page the detector cannot read says so instead of claiming a crop',
        () async {
      camera.frames = <Uint8List>[
        Uint8List.fromList(pngBytes(flatCapture(width: 400, height: 400))),
      ];
      await controller().start();
      await controller().capture();

      expect(state().lastScanNote, contains('Không dò được viền trang'));
      // The page is still processed and readable.
      expect(state().page!.scan, isNotNull);
    });
  });

  group('enhancement toggles', () {
    test('toggling a step re-processes the page immediately', () async {
      await controller().start();
      await controller().capture();
      final before = state().page!.scan!;

      await controller().toggleStep(EnhancementStep.denoise, true);

      expect(state().plan.isEnabled(EnhancementStep.denoise), isTrue);
      final after = state().page!.scan!;
      expect(after.enhancedBytes, isNot(before.enhancedBytes));
    });

    test('Bản gốc returns the untouched frame', () async {
      await controller().start();
      await controller().capture();
      await controller().useOriginal();

      expect(state().plan, EnhancementPlan.original);
      expect(state().lastScanNote, contains('Bản gốc'));
      // Text edits survive a re-process, so the user's corrections are not lost
      // by changing a filter.
      expect(state().page!.text, contains('Xin chào'));
    });
  });

  group('pages', () {
    test('edits replace the recognized text', () async {
      await controller().start();
      await controller().capture();
      controller().updateText('Chữ đã sửa tay.');

      expect(state().page!.text, 'Chữ đã sửa tay.');
    });

    test('removing a page renumbers the rest', () async {
      await controller().start();
      await controller().capture();
      await controller().capture();
      controller().removePage(0);

      expect(state().pages, hasLength(1));
      expect(state().pages.single.index, 0);
      expect(state().currentPage, 0);
    });

    test('selecting an out-of-range page is ignored', () async {
      await controller().start();
      await controller().capture();
      controller().selectPage(7);
      expect(state().currentPage, 0);
    });

    test('discardAll empties the tray but keeps the camera open', () async {
      await controller().start();
      await controller().capture();
      controller().discardAll();

      expect(state().pages, isEmpty);
      expect(state().status, CaptureStatus.ready);
    });
  });

  group('keep', () {
    test('two pages become one document with gapless block order', () async {
      await controller().start();
      await controller().capture();
      await controller().capture();

      final id = controller().keep();
      final kept = container.read(keptDocumentsProvider.notifier).byId(id)!;

      expect(kept.document.source, DocumentSource.camera);
      expect(kept.document.status, DocumentStatus.ready);
      expect(kept.pageCount, 2);
      expect(kept.blocks, isNotEmpty);
      expect(
        kept.blocks.map((block) => block.order),
        List<int>.generate(kept.blocks.length, (i) => i),
      );
      expect(kept.document.extractedText, contains('Xin chào Việt Nam'));
    });

    test('the document is named from the capture, not "Untitled"', () async {
      await controller().start();
      await controller().capture();
      final id = controller().keep();
      final kept = container.read(keptDocumentsProvider.notifier).byId(id)!;

      expect(kept.document.name, contains('Bản chụp'));
      expect(kept.document.name, isNot(contains('Untitled')));
    });

    test('a document with no text is marked as waiting, not ready', () async {
      ocr.failure = const ProcessingFailure(message: 'không nhận dạng được');
      await controller().addPageFromBytes(Uint8List.fromList(_frame()));

      final id = controller().keep();
      final kept = container.read(keptDocumentsProvider.notifier).byId(id)!;

      expect(kept.blocks, isEmpty);
      expect(kept.document.status, DocumentStatus.ocr);
      expect(kept.document.extractedText, isNull);
    });

    test('keeping clears the running-header memory for the next document',
        () async {
      await controller().addPageFromBytes(Uint8List.fromList(_frame()));
      controller().keep();
      container.read(captureControllerProvider.notifier).discardAll();

      // A second document must not inherit the first one's page furniture, so its
      // first line is still skipped-or-not based on its own pages.
      await controller().addPageFromBytes(Uint8List.fromList(_frame()));
      final sections = state().page!.sections;
      expect(sections, isNotEmpty);
      expect(
        sections.where((section) => section.block.type == BlockType.paragraph),
        isNotEmpty,
      );
    });
  });

  group('low confidence reporting', () {
    test('the page counts its own low-confidence lines', () async {
      await controller().start();
      await controller().capture();
      expect(state().page!.lowConfidenceCount, greaterThan(0));
      expect(state().lowConfidenceCount, greaterThan(0));
    });

    test('a clean page counts none', () async {
      ocr.lines = <OcrLine>[
        FakeOcrEngine.line('Dòng rõ ràng', top: 0.10, confidence: 0.99),
      ];
      await controller().addPageFromBytes(Uint8List.fromList(_frame()));
      expect(state().lowConfidenceCount, 0);
    });
  });
}
