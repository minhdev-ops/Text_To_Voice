import 'dart:async';
import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show immutable, listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ocr/mlkit_ocr_engine.dart';
import '../../core/camera/camera_plugin_source.dart';
import '../../core/result/result.dart';
import '../../domain/engines/ocr_engine.dart';
import '../../domain/engines/progress.dart' show JobStage;
import '../../domain/imaging/document_scanner.dart';
import '../../domain/imaging/enhancement.dart';
import '../../domain/models/document.dart'
    show Document, DocumentSource, DocumentStatus;
import '../../domain/models/document_image.dart' show ImageInput;
import '../../domain/models/ocr.dart' show OcrLine, OcrResult;
import '../../domain/models/structured_block.dart' show StructuredBlock;
import '../../domain/ocr/ocr_structurer.dart';
import '../library/kept_documents.dart';
import 'camera_source.dart';

/// The OCR engine the app recognizes with.
///
/// Overridden at the composition root with an ONNX engine when one exists, and in
/// tests with `FakeOcrEngine`. Its [OcrEngine.dataHandlingNote] is what the About
/// screen says out loud, which is why the note lives on the port.
final ocrEngineProvider = Provider<OcrEngine>((ref) {
  final engine = MlKitOcrEngine();
  ref.onDispose(engine.close);
  return engine;
});

/// Decode → detect → enhance → encode, off the UI isolate.
final documentScannerProvider = Provider<DocumentScanner>(
  (ref) => const DocumentScanner(),
);

/// Lines → structure. Reset per document so running-header detection does not
/// carry one document's headers into the next.
final ocrStructurerProvider = Provider<OcrStructurer>((ref) => OcrStructurer());

/// The camera, behind its port. Tests override this with a fake; a platform with
/// no camera reports `isSupported == false` and the screen offers file import.
final cameraSourceProvider = Provider<CameraSource>((ref) {
  final source = CameraPluginSource();
  ref.onDispose(source.close);
  return source;
});

/// Where the capture flow is.
enum CaptureStatus {
  /// Nothing started yet.
  idle,

  /// Asking the platform for its cameras, or opening one.
  opening,

  /// Preview is live.
  ready,

  /// Permission was refused. A different screen state from a generic failure,
  /// because the honest next step is different (`Open settings` vs `Retry`).
  permissionDenied,

  /// The platform has no camera at all. File import is the only path.
  unsupported,

  /// A frame is being captured and processed.
  working,
}

/// One captured page, from raw bytes to reviewable text.
@immutable
class CapturedPage {
  const CapturedPage({
    required this.index,
    required this.originalBytes,
    this.scan,
    this.ocr,
    this.sections = const <StructuredSection>[],
    this.text,
    this.failureMessage,
    this.textPending = false,
  });

  final int index;

  /// The frame as captured. Kept so `Bản gốc` can always be shown: enhancement
  /// that cannot be undone is destructive editing.
  final Uint8List originalBytes;

  final ScanOutcome? scan;
  final OcrResult? ocr;
  final List<StructuredSection> sections;

  /// The editable text. Starts as the OCR text and is what `Keep text` stores —
  /// the user's corrections are the document, not a suggestion.
  final String? text;

  final String? failureMessage;

  /// `true` when OCR did not run (engine unavailable, or it failed) but the
  /// image was still saved. The document is then marked `Chờ nhận dạng` rather
  /// than pretending it has no text.
  final bool textPending;

  bool get hasText => (text?.trim().isNotEmpty ?? false);

  /// Lines the OCR engine was unsure about, across the whole page.
  List<OcrLine> get lowConfidenceLines =>
      ocr?.lowConfidenceLines ?? const <OcrLine>[];

  int get lowConfidenceCount => lowConfidenceLines.length;

  List<StructuredBlock> get blocks =>
      sections.map((section) => section.block).toList(growable: false);

  CapturedPage copyWith({
    ScanOutcome? scan,
    OcrResult? ocr,
    List<StructuredSection>? sections,
    String? text,
    String? failureMessage,
    bool? textPending,
  }) =>
      CapturedPage(
        index: index,
        originalBytes: originalBytes,
        scan: scan ?? this.scan,
        ocr: ocr ?? this.ocr,
        sections: sections ?? this.sections,
        text: text ?? this.text,
        failureMessage: failureMessage ?? this.failureMessage,
        textPending: textPending ?? this.textPending,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CapturedPage &&
          other.index == index &&
          listEquals(other.originalBytes, originalBytes) &&
          other.scan == scan &&
          other.ocr == ocr &&
          listEquals(other.sections, sections) &&
          other.text == text &&
          other.failureMessage == failureMessage &&
          other.textPending == textPending);

  @override
  int get hashCode => Object.hash(index, originalBytes.length, scan, ocr,
      sections.length, text, failureMessage, textPending);

  @override
  String toString() =>
      'CapturedPage($index, ${sections.length} blocks, textPending=$textPending)';
}

/// Everything the capture flow renders from.
@immutable
class CaptureState {
  const CaptureState({
    this.status = CaptureStatus.idle,
    this.cameras = const <CameraInfo>[],
    this.selectedCamera = 0,
    this.resolution = CaptureResolution.high,
    this.plan = EnhancementPlan.ocrDefault,
    this.pages = const <CapturedPage>[],
    this.currentPage = 0,
    this.failureMessage,
    this.progress = 0,
    this.stage,
    this.lastScanNote,
    this.keptDocumentId,
  });

  final CaptureStatus status;
  final List<CameraInfo> cameras;
  final int selectedCamera;
  final CaptureResolution resolution;
  final EnhancementPlan plan;

  final List<CapturedPage> pages;
  final int currentPage;

  /// Set when something failed. Always a real sentence, never "Đã có lỗi".
  final String? failureMessage;

  final double progress;
  final String? stage;

  /// What the enhancement pass actually did to the last frame — including the
  /// steps it skipped and why.
  final String? lastScanNote;

  /// Set by `keep()`, so the screen knows a document now exists and can stop
  /// offering to create another.
  final String? keptDocumentId;

  CameraInfo? get activeCamera =>
      cameras.isEmpty || selectedCamera >= cameras.length
          ? null
          : cameras[selectedCamera];

  bool get hasPages => pages.isNotEmpty;

  CapturedPage? get page =>
      pages.isEmpty || currentPage >= pages.length ? null : pages[currentPage];

  int get lowConfidenceCount =>
      pages.fold<int>(0, (sum, page) => sum + page.lowConfidenceCount);

  bool get isWorking => status == CaptureStatus.working;

  /// The pending page count the tray shows, and what `Keep text` would store.
  bool get canKeep => pages.any((page) => page.hasText || page.textPending);

  /// The plan's toggles as a value the UI can render without touching the enum
  /// order.
  List<CaptureStepToggle> get stepToggles => <CaptureStepToggle>[
        for (final step in EnhancementPipeline.order)
          CaptureStepToggle(
            step: step,
            label: step.label,
            note: step.note,
            enabled: plan.isEnabled(step),
          ),
      ];

  CaptureState copyWith({
    CaptureStatus? status,
    List<CameraInfo>? cameras,
    int? selectedCamera,
    CaptureResolution? resolution,
    EnhancementPlan? plan,
    List<CapturedPage>? pages,
    int? currentPage,
    Object? failureMessage = _unset,
    double? progress,
    Object? stage = _unset,
    Object? lastScanNote = _unset,
    Object? keptDocumentId = _unset,
  }) =>
      CaptureState(
        status: status ?? this.status,
        cameras: cameras ?? this.cameras,
        selectedCamera: selectedCamera ?? this.selectedCamera,
        resolution: resolution ?? this.resolution,
        plan: plan ?? this.plan,
        pages: pages ?? this.pages,
        currentPage: currentPage ?? this.currentPage,
        failureMessage: identical(failureMessage, _unset)
            ? this.failureMessage
            : failureMessage as String?,
        progress: progress ?? this.progress,
        stage: identical(stage, _unset) ? this.stage : stage as String?,
        lastScanNote: identical(lastScanNote, _unset)
            ? this.lastScanNote
            : lastScanNote as String?,
        keptDocumentId: identical(keptDocumentId, _unset)
            ? this.keptDocumentId
            : keptDocumentId as String?,
      );

  static const Object _unset = Object();

  @override
  String toString() =>
      'CaptureState(${status.name}, ${pages.length} pages, at $currentPage)';
}

/// One toggle row in the enhancement strip. A plain value so the widget does not
/// need to know [EnhancementPipeline.order].
@immutable
class CaptureStepToggle {
  const CaptureStepToggle({
    required this.step,
    required this.label,
    required this.note,
    required this.enabled,
  });

  final EnhancementStep step;
  final String label;
  final String note;
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CaptureStepToggle &&
          other.step == step &&
          other.enabled == enabled);

  @override
  int get hashCode => Object.hash(step, enabled);
}

/// Drives capture → enhance → recognize → review.
///
/// One `Notifier` over one immutable state value, per the project's state rule:
/// the screen calls an intent method and re-renders from the published value, so
/// the preview, the tray and the review pane can never disagree about how many
/// pages exist or which one is current.
class CaptureController extends Notifier<CaptureState> {
  @override
  CaptureState build() => const CaptureState();

  CameraSource get _camera => ref.read(cameraSourceProvider);
  DocumentScanner get _scanner => ref.read(documentScannerProvider);
  OcrEngine get _ocr => ref.read(ocrEngineProvider);

  /// Opens the camera, or lands on the honest state that explains why not.
  Future<void> start() async {
    if (state.status == CaptureStatus.opening) return;

    if (!_camera.isSupported) {
      state = state.copyWith(
        status: CaptureStatus.unsupported,
        failureMessage: 'Thiết bị này không có camera. Bạn vẫn có thể chọn ảnh '
            'hoặc tệp có sẵn.',
      );
      return;
    }

    state = state.copyWith(
      status: CaptureStatus.opening,
      failureMessage: null,
    );

    final discovery = await _camera.discover();
    switch (discovery) {
      case Failure(:final failure):
        state = state.copyWith(
          status: failure is PermissionFailure
              ? CaptureStatus.permissionDenied
              : CaptureStatus.idle,
          failureMessage: failure.message,
        );
        return;
      case Success(:final value):
        state = state.copyWith(cameras: value, selectedCamera: 0);
    }

    await _openActiveCamera();
  }

  Future<void> _openActiveCamera() async {
    final camera = state.activeCamera;
    if (camera == null) {
      state = state.copyWith(
        status: CaptureStatus.idle,
        failureMessage: 'Không tìm thấy camera nào trên máy.',
      );
      return;
    }

    final opened = await _camera.open(camera, resolution: state.resolution);
    switch (opened) {
      case Failure(:final failure):
        state = state.copyWith(
          status: failure is PermissionFailure
              ? CaptureStatus.permissionDenied
              : CaptureStatus.idle,
          failureMessage: failure.message,
        );
      case Success():
        state = state.copyWith(status: CaptureStatus.ready, failureMessage: null);
    }
  }

  Future<void> switchCamera() async {
    if (state.cameras.length < 2) return;
    state = state.copyWith(
      selectedCamera: (state.selectedCamera + 1) % state.cameras.length,
    );
    await _openActiveCamera();
  }

  Future<void> setResolution(CaptureResolution resolution) async {
    if (resolution == state.resolution) return;
    state = state.copyWith(resolution: resolution);
    // The preset is fixed at open time, so a change has to reopen the camera.
    await _openActiveCamera();
  }

  /// Turns one enhancement step on or off and re-processes the current page, so
  /// the preview the user sees is the result of the toggles they just changed
  /// rather than a promise to apply them later.
  Future<void> toggleStep(EnhancementStep step, bool enabled) async {
    state = state.copyWith(plan: state.plan.toggle(step, enabled));
    final page = state.page;
    if (page != null) await _processPage(page.index);
  }

  /// Back to the untouched frame (the "Original" escape hatch).
  Future<void> useOriginal() async {
    state = state.copyWith(plan: EnhancementPlan.original);
    final page = state.page;
    if (page != null) await _processPage(page.index);
  }

  /// Captures a frame and runs it through the pipeline. Multi-page capture is
  /// just calling this again (FR-03): pages accumulate in one document.
  Future<void> capture() async {
    if (state.status != CaptureStatus.ready) return;

    state = state.copyWith(status: CaptureStatus.working, failureMessage: null);
    final shot = await _camera.capture();

    switch (shot) {
      case Failure(:final failure):
        state = state.copyWith(
          status: CaptureStatus.ready,
          failureMessage: failure.message,
        );
        return;
      case Success(:final value):
        final page = CapturedPage(
          index: state.pages.length,
          originalBytes: value.bytes,
        );
        final pages = <CapturedPage>[...state.pages, page];
        state = state.copyWith(
          pages: pages,
          currentPage: pages.length - 1,
        );
        await _processPage(page.index);
    }
  }

  /// Adds a page from bytes the user picked rather than shot (FR-02's image path,
  /// and the fallback the permission-denied state offers).
  Future<void> addPageFromBytes(Uint8List bytes) async {
    final page = CapturedPage(index: state.pages.length, originalBytes: bytes);
    final pages = <CapturedPage>[...state.pages, page];
    state = state.copyWith(
      pages: pages,
      currentPage: pages.length - 1,
      status: state.cameras.isEmpty ? CaptureStatus.idle : state.status,
    );
    await _processPage(page.index);
  }

  /// Public entry point to (re)run analysis for a page by index.
  Future<void> processPage(int index) => _processPage(index);

  Future<void> _processPage(int index) async {
    final page = _pageAt(index);
    if (page == null) return;

    state = state.copyWith(
      status: CaptureStatus.working,
      progress: 0,
      stage: JobStage.analyzing,
      failureMessage: null,
    );

    final scanned = await _scanner.scan(ScanRequest(
      bytes: page.originalBytes,
      plan: state.plan,
    ));

    final outcome = scanned.valueOrNull;
    if (outcome == null) {
      _replace(index, page.copyWith(
        failureMessage: scanned.failureOrNull?.message ??
            'Không xử lý được ảnh này.',
      ));
      state = state.copyWith(status: CaptureStatus.ready);
      return;
    }

    _replace(index, page.copyWith(
      scan: outcome,
      failureMessage: null,
      textPending: true,
    ));
    state = state.copyWith(
      lastScanNote: _scanNote(outcome),
      progress: 0.4,
      stage: JobStage.runningOcr,
    );

    final recognized = await _ocr.recognize(
      ImageInput.bytes(
        outcome.enhancedBytes,
        mimeType: 'image/png',
      ),
      onProgress: (progress, stage) {
        state = state.copyWith(progress: 0.4 + progress * 0.6, stage: stage);
      },
    );

    switch (recognized) {
      case Failure(:final failure):
        // The image is still saved and the document is marked `Text pending`
        // (UX spec §4): losing the photo because recognition failed would be the
        // worst possible trade.
        _replace(index, _pageAt(index)!.copyWith(
          textPending: true,
          failureMessage: failure.message,
        ));
      case Success(:final value):
        final structurer = ref.read(ocrStructurerProvider);
        structurer.reset();
        final sections = structurer.sections(
          value.lines,
          pageNumber: index + 1,
        );
        _replace(index, _pageAt(index)!.copyWith(
          ocr: value,
          sections: sections,
          text: _textOf(sections),
          textPending: false,
          failureMessage: null,
        ));
    }

    state = state.copyWith(
      status: state.cameras.isEmpty ? CaptureStatus.idle : CaptureStatus.ready,
      progress: 1,
      stage: JobStage.done,
    );
  }

  /// Re-runs detection and enhancement on the current page, keeping its text
  /// edits. `Re-scan` in the review pane is this.
  Future<void> rescanCurrentPage() async {
    final page = state.page;
    if (page == null) return;
    await _processPage(page.index);
  }

  Future<void> retryCurrentPage() => rescanCurrentPage();

  /// Applies the user's edits. The corrected text is the document (FR-08).
  void updateText(String text) {
    final page = state.page;
    if (page == null) return;
    _replace(
      page.index,
      CapturedPage(
        index: page.index,
        originalBytes: page.originalBytes,
        scan: page.scan,
        ocr: page.ocr,
        sections: page.sections,
        text: text,
        failureMessage: null,
        textPending: page.textPending,
      ),
    );
  }

  void selectPage(int index) {
    if (index < 0 || index >= state.pages.length) return;
    state = state.copyWith(currentPage: index);
  }

  void removePage(int index) {
    if (index < 0 || index >= state.pages.length) return;
    final pages = <CapturedPage>[
      for (final page in state.pages)
        if (page.index != index) page,
    ];
    // Re-index so `currentPage` and the tray labels stay consistent; a page's
    // index is also its page number in the stored document.
    final renumbered = <CapturedPage>[
      for (var i = 0; i < pages.length; i++)
        CapturedPage(
          index: i,
          originalBytes: pages[i].originalBytes,
          scan: pages[i].scan,
          ocr: pages[i].ocr,
          sections: pages[i].sections,
          text: pages[i].text,
          failureMessage: pages[i].failureMessage,
          textPending: pages[i].textPending,
        ),
    ];
    state = state.copyWith(
      pages: renumbered,
      currentPage: state.currentPage.clamp(0, renumbered.isEmpty ? 0 : renumbered.length - 1),
      keptDocumentId: null,
    );
  }

  /// `Keep text`: creates the document and hands back its id so the screen can
  /// open the reader.
  ///
  /// Phase 5 replaces the in-memory sink with the repository. Nothing else about
  /// this method changes, which is the point of routing it through
  /// [keptDocumentsProvider] rather than writing files here.
  String keep() {
    final pages = state.pages;
    final now = DateTime.now();
    final id = 'doc-${now.microsecondsSinceEpoch}';
    final text = pages
        .map((page) => page.text ?? '')
        .where((pageText) => pageText.trim().isNotEmpty)
        .join('\n\n');

    // Reading order is re-numbered here, not per page: a document assembled from
    // several pages needs gapless `order` values across all of them, and page 2
    // must not restart at 0.
    final blocks = <StructuredBlock>[];
    for (final page in pages) {
      for (final block in page.blocks) {
        blocks.add(block.copyWith(order: blocks.length));
      }
    }

    final kept = KeptDocument(
      document: Document(
        id: id,
        name: _documentName(pages.length),
        source: state.cameras.isEmpty
            ? DocumentSource.image
            : DocumentSource.camera,
        mimeType: 'text/plain',
        fileSize: pages.fold<int>(
          0,
          (sum, page) => sum + page.originalBytes.length,
        ),
        status: blocks.isEmpty ? DocumentStatus.ocr : DocumentStatus.ready,
        extractedText: text.isEmpty ? null : text,
        createdAt: now,
        updatedAt: now,
        metadata: <String, Object?>{
          'page_count': pages.length,
          'ocr_engine': pages.firstOrNull?.ocr?.engineId,
        },
      ),
      blocks: blocks,
      pageImages: pages.map((page) => page.originalBytes).toList(growable: false),
    );

    final keptId = ref.read(keptDocumentsProvider.notifier).add(kept);
    // A new document means new running headers, so the structurer's memory is
    // cleared rather than carried into the next capture.
    ref.read(ocrStructurerProvider).reset();
    state = state.copyWith(keptDocumentId: keptId);
    return keptId;
  }

  /// A real name from what was captured, not "Untitled": the date is something
  /// the user can recognize later in the library.
  String _documentName(int pageCount) {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp = '${two(now.day)}/${two(now.month)}/${now.year} '
        '${two(now.hour)}:${two(now.minute)}';
    return pageCount > 1 ? 'Bản chụp $pageCount trang · $stamp' : 'Bản chụp · $stamp';
  }

  void clearFailure() => state = state.copyWith(failureMessage: null);

  /// Empties the tray and returns the flow to a fresh capture session.
  void discardAll() {
    ref.read(ocrStructurerProvider).reset();
    state = CaptureState(
      status: state.cameras.isEmpty ? state.status : CaptureStatus.ready,
      cameras: state.cameras,
      selectedCamera: state.selectedCamera,
      resolution: state.resolution,
      plan: state.plan,
    );
  }

  CapturedPage? _pageAt(int index) {
    for (final page in state.pages) {
      if (page.index == index) return page;
    }
    return null;
  }

  void _replace(int index, CapturedPage page) {
    state = state.copyWith(
      pages: <CapturedPage>[
        for (final existing in state.pages)
          if (existing.index == index) page else existing,
      ],
      keptDocumentId: null,
    );
  }

  String _textOf(List<StructuredSection> sections) =>
      sections.map((section) => section.block.content).join('\n\n');

  String _scanNote(ScanOutcome outcome) {
    final detection = outcome.detection;
    final parts = <String>[
      if (detection == null)
        'Giữ nguyên khung ảnh.'
      else if (detection.found)
        'Đã dò được viền trang '
            '(${(detection.confidence * 100).round()}% tin cậy).'
      else
        'Không dò được viền trang: ${detection.notFoundReason}',
      outcome.report.summary,
      ...outcome.report.notes,
    ];
    return parts.join(' ');
  }
}

final captureControllerProvider =
    NotifierProvider<CaptureController, CaptureState>(CaptureController.new);
