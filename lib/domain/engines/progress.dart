/// Progress reporting for long, page-at-a-time background work.
///
/// [progress] is 0..1 and only meaningful for work whose total is known
/// upfront (a 40-page PDF). For open-ended work such as OCR on a camera
/// capture, engines report stage changes only and leave [progress] at 0.
///
/// Callbacks are invoked from a background isolate, so implementations must
/// hand back to the UI thread themselves — this signature deliberately carries
/// no `BuildContext`.
typedef ProgressCallback = void Function(double progress, String stage);

/// Stages a user can be told about, in Vietnamese, chosen once so every
/// processing row says the same words (DESIGN.md → Voice, action vocabulary).
abstract final class JobStage {
  static const String queued = 'Đang chờ';
  static const String analyzing = 'Đang phân tích';
  static const String extracting = 'Đang trích xuất';
  static const String runningOcr = 'Đang chạy OCR';
  static const String synthesizing = 'Đang tổng hợp giọng nói';
  static const String done = 'Xong';
}
