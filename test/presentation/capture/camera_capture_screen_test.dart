import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:text_to_voice/core/result/result.dart';
import 'package:text_to_voice/core/theme/app_theme.dart';
import 'package:text_to_voice/domain/imaging/enhancement.dart';
import 'package:text_to_voice/domain/models/document_block.dart' show BlockType;
import 'package:text_to_voice/domain/models/ocr.dart' show OcrLine;
import 'package:text_to_voice/presentation/capture/camera_capture_screen.dart';
import 'package:text_to_voice/presentation/capture/capture_providers.dart';

import '../../support/fake_camera_source.dart';
import '../../support/fake_ocr_engine.dart';
import '../../support/image_fixtures.dart';

List<int> frame() => pngBytes(syntheticCapture(
      width: 500,
      height: 700,
      pageInset: 0.1,
      textLines: 6,
    ));

void main() {
  late FakeCameraSource camera;
  late FakeOcrEngine ocr;

  setUp(() {
    camera = FakeCameraSource(
      frames: <Uint8List>[Uint8List.fromList(frame())],
    );
    ocr = FakeOcrEngine(lines: <OcrLine>[
      FakeOcrEngine.line('Xin chào Việt Nam', top: 0.10, confidence: 0.97),
    ]);
  });

  Widget app() => ProviderScope(
        overrides: [
          cameraSourceProvider.overrideWithValue(camera),
          ocrEngineProvider.overrideWithValue(ocr),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CameraCaptureScreen(),
        ),
      );

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(CameraCaptureScreen)));

  testWidgets('a platform with no camera offers file import and says why',
      (tester) async {
    camera.supported = false;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Không có camera'), findsOneWidget);
    expect(find.textContaining('Thiết bị này không có camera'), findsOneWidget);
    expect(find.text('Chọn ảnh có sẵn'), findsOneWidget);
    // No dead preview and no shutter to tap.
    expect(find.byKey(FakeCameraSource.previewKey), findsNothing);
  });

  testWidgets('refused permission explains the next step, not just the failure',
      (tester) async {
    camera.discoverFailure = const PermissionFailure(
      message: 'VietDoc AI cần quyền dùng camera để chụp tài liệu.',
      permission: 'camera',
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Chưa có quyền dùng camera'), findsOneWidget);
    expect(find.textContaining('cần quyền dùng camera'), findsOneWidget);
    // Both honest next steps are offered: ask again, or work around it.
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.text('Chọn ảnh có sẵn'), findsOneWidget);

    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(camera.discoverCount, 2);
  });

  testWidgets('choosing a file surfaces the picker failure instead of nothing',
      (tester) async {
    camera.supported = false;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chọn ảnh có sẵn'));
    await tester.pumpAndSettle();
    // The picker is wired to the platform channel; when that channel has no
    // implementation the tap must say so. A button that silently does nothing
    // is worse than one that reports the failure.
    expect(find.textContaining('Lỗi khi nhập tệp'), findsOneWidget);
  });

  testWidgets('a live camera shows the preview and the enhancement controls',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byKey(FakeCameraSource.previewKey), findsOneWidget);
    for (final step in EnhancementPipeline.order) {
      expect(find.text(step.label), findsOneWidget);
    }
    expect(find.text('Bản gốc'), findsOneWidget);
    expect(find.text('Sẵn sàng chụp'), findsOneWidget);
  });

  testWidgets('the shutter is enabled only when the camera is ready',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final shutter = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.camera_alt_outlined),
        matching: find.byType(IconButton),
      ),
    );
    expect(shutter.onPressed, isNotNull);
  });

  testWidgets('toggling a step calls the controller and updates the chip',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final container = containerOf(tester);

    expect(
      container.read(captureControllerProvider).plan
          .isEnabled(EnhancementStep.denoise),
      isFalse,
    );

    await tester.tap(find.text(EnhancementStep.denoise.label));
    await tester.pumpAndSettle();

    expect(
      container.read(captureControllerProvider).plan
          .isEnabled(EnhancementStep.denoise),
      isTrue,
    );
  });

  testWidgets('once a page exists the title counts it and Xong appears',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final container = containerOf(tester);
    // Driven through `runAsync`: the scanner really runs on a background
    // isolate, and a widget test's fake clock does not pump the real event loop
    // that an isolate completes on.
    await tester.runAsync(() async {
      await container
          .read(captureControllerProvider.notifier)
          .addPageFromBytes(Uint8List.fromList(frame()));
    });
    await tester.pumpAndSettle();

    expect(find.textContaining('1 trang'), findsWidgets);
    expect(find.text('Xong'), findsWidgets);

    final state = container.read(captureControllerProvider);
    expect(state.page!.sections.first.block.type, BlockType.paragraph);
    expect(state.page!.text, contains('Xin chào Việt Nam'));
  });
}
