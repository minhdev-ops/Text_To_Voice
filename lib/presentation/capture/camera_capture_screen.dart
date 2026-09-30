import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/result/result.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/semantic_colors.dart';
import '../../core/theme/tokens.dart';
import '../../domain/import/import_service.dart';
import '../../domain/import/file_validation.dart';
import '../../domain/models/imported_file.dart';
import '../../domain/models/ocr.dart' show OcrLine, OcrResult;
import '../../domain/models/extraction.dart' show ExtractionResult;
import '../../domain/engines/progress.dart' show JobStage;
import 'capture_providers.dart';
import 'camera_source.dart' show CaptureResolution;
import 'scan_review_screen.dart';

/// Camera → crop → enhance → recognize (FR-03/FR-04, UX spec §4).
///
/// One document, N pages: the shutter appends, `Xong` reviews. Every state the UX
/// spec names is rendered, because each one has a different honest next step:
///
/// * **no permission** — explain why, offer `Mở Cài đặt` and `Chọn ảnh`;
/// * **no camera** — offer `Chọn ảnh` and say so, rather than a dead preview;
/// * **nothing detected** — no error toast, just the note in the review pane.
class CameraCaptureScreen extends ConsumerStatefulWidget {
  const CameraCaptureScreen({super.key});

  static const String location = '/capture';
  static const String title = 'Chụp tài liệu';

  @override
  ConsumerState<CameraCaptureScreen> createState() =>
      _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends ConsumerState<CameraCaptureScreen> {
  @override
  void initState() {
    super.initState();
    // After the first frame: opening a camera touches platform channels, and
    // doing it during `build` would make the screen's own first paint wait on it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(captureControllerProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(captureControllerProvider);
    final controller = ref.read(captureControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.hasPages
              ? '${CameraCaptureScreen.title} · ${state.pages.length} trang'
              : CameraCaptureScreen.title,
        ),
        actions: <Widget>[
          if (state.cameras.length > 1)
            IconButton(
              onPressed: state.isWorking ? null : controller.switchCamera,
              tooltip: 'Đổi camera',
              icon: const Icon(Icons.cameraswitch_outlined),
            ),
          if (state.hasPages)
            TextButton(
              onPressed: () => context.push(ScanReviewScreen.location),
              child: const Text('Xong'),
            ),
          const SizedBox(width: Spacing.s8),
        ],
      ),
      body: switch (state.status) {
        CaptureStatus.unsupported => _UnsupportedView(
            message: state.failureMessage,
            onChooseFile: () => _chooseFile(context, controller),
          ),
        CaptureStatus.permissionDenied => _PermissionView(
            message: state.failureMessage,
            onChooseFile: () => _chooseFile(context, controller),
            onRetry: controller.start,
          ),
        _ => _PreviewView(
            controller: controller,
            state: state,
            preview: state.status == CaptureStatus.ready
                ? ref.read(cameraSourceProvider).buildPreview()
                : null,
          ),
      },
    );
  }

  /// Opens the system file picker and processes the selected file.
  ///
  /// For images: adds directly to the capture flow for OCR processing.
  /// For documents (PDF, text, markdown, EPUB): extracts text via ImportService
  /// and creates a CapturedPage with the extracted content.
  Future<void> _chooseFile(BuildContext context, CaptureController controller) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>[
          'pdf',
          'txt',
          'md',
          'epub',
          'jpg',
          'jpeg',
          'png',
          'webp',
        ],
      );

      if (result.isEmpty) {
        return; // User canceled the picker
      }

      final file = result.first;
      if (file == null) {
        return;
      }

      // Read the file bytes (file_picker 13 exposes no eager `bytes` getter)
      final Uint8List fileBytes = await file.readAsBytes();
      final Uint8List headBytes = fileBytes.length > 512
          ? fileBytes.sublist(0, 512)
          : fileBytes;

      // Create ImportedFile for validation
      String? mimeType;
      if (file.extension != null) {
        switch (file.extension!.toLowerCase()) {
          case 'pdf':
            mimeType = 'application/pdf';
            break;
          case 'txt':
            mimeType = 'text/plain';
            break;
          case 'md':
            mimeType = 'text/markdown';
            break;
          case 'epub':
            mimeType = 'application/epub+zip';
            break;
          case 'jpg':
          case 'jpeg':
            mimeType = 'image/jpeg';
            break;
          case 'png':
            mimeType = 'image/png';
            break;
          case 'webp':
            mimeType = 'image/webp';
            break;
        }
      }
      mimeType ??= 'application/octet-stream';

      final importedFile = ImportedFile(
        name: file.name,
        path: file.path!,
        mimeType: mimeType,
        size: await file.length() ?? fileBytes.length,
        headBytes: headBytes,
      );

      // Validate the file to determine its actual type
      final validationResult = ImportValidator.validate(importedFile);
      if (validationResult case Failure<ValidatedFile>(:final failure)) {
        // Show validation error
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(SnackBar(content: Text(failure.message)));
        }
        return;
      }

      final ValidatedFile validated = validationResult.valueOrNull!;

      // Handle based on file type
      switch (validated.kind) {
        case FileKind.imageJpeg:
        case FileKind.imagePng:
        case FileKind.imageWebp:
          // Image files - use existing path
          controller.addPageFromBytes(fileBytes);
          break;
        case FileKind.pdf:
        case FileKind.text:
        case FileKind.markdown:
        case FileKind.epub:
          // Document files - extract text
          final importService = const ImportService();
          final extractResult = await importService.importFile(
            importedFile,
            onProgress: (progress, stage) {
              // Update progress if needed
              if (stage == JobStage.done && context.mounted) {
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(const SnackBar(
                    content: Text('Đã nhập tệp thành công!'),
                  ));
              }
            },
          );

          if (extractResult case Success<ExtractionResult>(:final value)) {
            // Convert extracted text to CapturedPage
            final text = value.text;
            if (text == null || text.trim().isEmpty) {
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(const SnackBar(
                    content: Text('Tệp này không có nội dung văn bản để đọc.'),
                  ));
              }
            } else {
              // Create a CapturedPage from the extracted text
              final page = await _createDocumentPage(
                bytes: fileBytes,
                text: text,
                fileName: file.name,
                controller: controller,
              );
              if (page != null && context.mounted) {
                // Add the page to the capture state
                final pages = <CapturedPage>[...controller.state.pages, page];
                controller.state = controller.state.copyWith(
                  pages: pages,
                  currentPage: pages.length - 1,
                );
                await controller.processPage(page.index);
              }
            }
          } else if (extractResult case Failure<ExtractionResult>(:final failure)) {
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(SnackBar(content: Text(failure.message)));
            }
          }
          break;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text('Lỗi khi nhập tệp: $e')));
      }
    }
  }

  /// Creates a CapturedPage from extracted document text.
  ///
  /// Uses the OCR structurer to convert plain text into structured sections
  /// so it integrates seamlessly with the existing capture flow.
  Future<CapturedPage?> _createDocumentPage({
    required Uint8List bytes,
    required String text,
    required String fileName,
    required CaptureController controller,
  }) async {
    try {
      // Convert text to OcrLine objects for the structurer
      final lines = text.split('\n').map((line) {
        return OcrLine(
          text: line.trim(),
          confidence: 1.0,
          position: null,
          pageNumber: 1,
        );
      }).where((line) => line.text.isNotEmpty).toList();

      if (lines.isEmpty) {
        return null;
      }

      // Use the OCR structurer to convert lines to structured sections
      final structurer = ref.read(ocrStructurerProvider);
      structurer.reset();
      final sections = structurer.sections(lines, pageNumber: 1);

      return CapturedPage(
        index: controller.state.pages.length,
        originalBytes: bytes,
        scan: null,
        ocr: OcrResult(lines: lines),
        sections: sections,
        text: text,
        failureMessage: null,
        textPending: false,
      );
    } catch (e) {
      // If structuring fails, create a simple page with just the text
      return CapturedPage(
        index: controller.state.pages.length,
        originalBytes: bytes,
        scan: null,
        ocr: null,
        sections: const [],
        text: text,
        failureMessage: null,
        textPending: false,
      );
    }
  }
}

/// Permission denied view with retry and file import options.
class _PermissionView extends StatelessWidget {
  const _PermissionView({
    required this.message,
    required this.onChooseFile,
    required this.onRetry,
  });

  final String? message;
  final VoidCallback onChooseFile;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Chưa có quyền dùng camera', style: theme.textTheme.titleLarge),
              const SizedBox(height: Spacing.s12),
              Text(
                message ??
                    'VietDoc AI cần quyền dùng camera để chụp tài liệu. Bạn có '
                        'thể cấp lại trong phần Cài đặt của máy.',
                style: theme.utility.copyWith(height: 1.5),
              ),
              const SizedBox(height: Spacing.s24),
              Wrap(
                spacing: Spacing.s12,
                runSpacing: Spacing.s12,
                children: <Widget>[
                  FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
                  OutlinedButton(
                    onPressed: onChooseFile,
                    child: const Text('Chọn ảnh có sẵn'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The live preview: the camera feed with the shutter and controls over it.
class _PreviewView extends StatelessWidget {
  const _PreviewView({
    required this.controller,
    required this.state,
    required this.preview,
  });

  final CaptureController controller;
  final CaptureState state;

  /// The live preview widget, or `null` while the camera is still opening. Built
  /// by the caller, which is the only place that has a `WidgetRef`.
  final Widget? preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semanticColors;

    return Column(
      children: <Widget>[
        if (state.failureMessage != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.s16,
              vertical: Spacing.s8,
            ),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: semantic.danger)),
            ),
            child: Text(
              state.failureMessage!,
              style: theme.utility.copyWith(color: semantic.danger),
            ),
          ),
        Expanded(
          child: ColoredBox(
            color: theme.colorScheme.surfaceContainerLowest,
            child: preview ??
                Center(
                  child: Text(
                    state.failureMessage ?? 'Đang mở camera…',
                    style: theme.utility.copyWith(color: semantic.textSubtle),
                  ),
                ),
          ),
        ),
        _EnhancementStrip(state: state, controller: controller),
        _ShutterBar(controller: controller, state: state),
      ],
    );
  }
}

/// The enhancement toggles. Every step is switchable and `Bản gốc` restores the
/// untouched frame, because enhancement the user cannot undo is destructive
/// editing of their photo.
class _EnhancementStrip extends StatelessWidget {
  const _EnhancementStrip({required this.state, required this.controller});

  final CaptureState state;
  final CaptureController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semanticColors;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: semantic.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: Spacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.s12),
            child: Row(
              children: <Widget>[
                for (final toggle in state.stepToggles) ...<Widget>[
                  FilterChip(
                    label: Text(toggle.label),
                    selected: toggle.enabled,
                    onSelected: state.isWorking
                        ? null
                        : (value) => controller.toggleStep(toggle.step, value),
                  ),
                  const SizedBox(width: Spacing.s8),
                ],
                const SizedBox(width: Spacing.s4),
                TextButton(
                  onPressed: state.isWorking ? null : controller.useOriginal,
                  child: const Text('Bản gốc'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.s16),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    state.stage ?? 'Sẵn sàng chụp',
                    style: theme.utility
                        .copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                _ResolutionMenu(controller: controller, state: state),
                if (state.pages.isNotEmpty)
                  Text(
                    '${state.pages.length} trang',
                    style: theme.utility.copyWith(color: semantic.textSubtle),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Capture size. `Cao` is the default: enough pixels for Vietnamese diacritics
/// without the decode cost of a 12 MP frame on every page.
class _ResolutionMenu extends StatelessWidget {
  const _ResolutionMenu({required this.controller, required this.state});

  final CaptureController controller;
  final CaptureState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<CaptureResolution>(
      enabled: !state.isWorking,
      initialValue: state.resolution,
      onSelected: controller.setResolution,
      tooltip: 'Độ phân giải',
      itemBuilder: (context) => <PopupMenuEntry<CaptureResolution>>[
        for (final resolution in CaptureResolution.values)
          PopupMenuItem<CaptureResolution>(
            value: resolution,
            child: Text(_label(resolution)),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.s4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              _label(state.resolution),
              style: theme.utility,
            ),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }

  String _label(CaptureResolution resolution) => switch (resolution) {
        CaptureResolution.standard => 'Thường',
        CaptureResolution.high => 'Cao',
        CaptureResolution.maximum => 'Tối đa',
      };
}

class _ShutterBar extends StatelessWidget {
  const _ShutterBar({required this.controller, required this.state});

  final CaptureController controller;
  final CaptureState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semanticColors;
    final enabled = state.status == CaptureStatus.ready;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: semantic.border)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.s16,
        vertical: Spacing.s12,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            SizedBox(
              width: Layout.minTouchTarget,
              child: state.pages.isEmpty
                  ? null
                  : TextButton(
                      onPressed: () =>
                          controller.removePage(state.currentPage),
                      child: const Text('Xoá'),
                    ),
            ),
            Semantics(
              button: true,
              label: 'Chụp trang',
              child: IconButton.filled(
                onPressed: enabled ? controller.capture : null,
                iconSize: 40,
                tooltip: 'Chụp trang',
                icon: const Icon(Icons.camera_alt_outlined),
              ),
            ),
            SizedBox(
              width: Layout.minTouchTarget,
              child: state.hasPages
                  ? TextButton(
                      onPressed: () => context.push(ScanReviewScreen.location),
                      child: const Text('Xong'),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// View shown when the device has no camera.
class _UnsupportedView extends StatelessWidget {
  const _UnsupportedView({required this.message, required this.onChooseFile});

  final String? message;
  final VoidCallback onChooseFile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Không có camera', style: theme.textTheme.titleLarge),
              const SizedBox(height: Spacing.s12),
              Text(
                message ?? 'Thiết bị này không có camera.',
                style: theme.utility.copyWith(height: 1.5),
              ),
              const SizedBox(height: Spacing.s24),
              FilledButton(
                onPressed: onChooseFile,
                child: const Text('Chọn ảnh có sẵn'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}