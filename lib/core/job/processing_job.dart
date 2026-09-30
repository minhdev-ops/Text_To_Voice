import 'package:collection/collection.dart' show ListEquality;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../result/result.dart';

/// What kind of work a job is doing. Drives the row's icon and the stage copy.
enum JobKind {
  /// FR-02: reading and validating a picked file.
  importFile,

  /// FR-04 / FR-05: OCR pass.
  ocr,

  /// FR-05 / FR-07: parsing into structured blocks.
  extraction,

  /// FR-12: synthesizing sentence audio.
  synthesis,

  /// FR-20: downloading an AI model. The only job that may use the network,
  /// which is why it is a distinct kind rather than an import.
  modelDownload,
}

enum JobStatus {
  /// Accepted, not started. Survives process death (Phase 5).
  queued,
  running,
  succeeded,
  failed,
  cancelled,
}

/// One unit of background work shown in the processing strip — SRS §44 "17
/// Processing Queue", and DESIGN.md's `ProcessingStrip` component.
///
/// Immutable with value equality: the notifier publishes a **new** list of
/// **new** jobs, so Riverpod's listeners diff by value instead of missing an
/// in-place edit.
@immutable
class ProcessingJob {
  const ProcessingJob({
    required this.id,
    required this.kind,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.stage = 'Đang chờ',
    this.progress = 0,
    this.failure,
  });

  final String id;
  final JobKind kind;

  /// What the row says — the file or document name. **Never** document text.
  final String title;

  /// User-facing stage word from `JobStage`.
  final String stage;

  /// 0..1. `-1` means indeterminate (total unknown, e.g. camera OCR).
  final double progress;

  final JobStatus status;
  final AppFailure? failure;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive =>
      status == JobStatus.queued || status == JobStatus.running;

  bool get isTerminal =>
      status == JobStatus.succeeded ||
      status == JobStatus.failed ||
      status == JobStatus.cancelled;

  /// A cancelled job is not a failure: the UI must not render a failure
  /// banner or a retry for it.
  bool get isRetryable =>
      status == JobStatus.failed && (failure?.retryable ?? false);

  ProcessingJob copyWith({
    JobStatus? status,
    String? stage,
    double? progress,
    DateTime? updatedAt,
    Object? failure = _unset,
  }) =>
      ProcessingJob(
        id: id,
        kind: kind,
        title: title,
        status: status ?? this.status,
        stage: stage ?? this.stage,
        progress: progress ?? this.progress,
        failure: identical(failure, _unset) ? this.failure : failure as AppFailure?,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  static const Object _unset = Object();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProcessingJob &&
          other.id == id &&
          other.kind == kind &&
          other.title == title &&
          other.status == status &&
          other.stage == stage &&
          other.progress == progress &&
          other.failure == failure &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt);

  @override
  int get hashCode => Object.hash(id, kind, title, status, stage, progress,
      failure, createdAt, updatedAt);

  @override
  String toString() => 'ProcessingJob($id, ${status.name}, $progress)';
}

@immutable
class ProcessingQueueState {
  const ProcessingQueueState([this.jobs = const <ProcessingJob>[]]);

  final List<ProcessingJob> jobs;

  int get activeCount => jobs.where((job) => job.isActive).length;

  List<ProcessingJob> get active =>
      jobs.where((job) => job.isActive).toList(growable: false);

  List<ProcessingJob> get failed =>
      jobs.where((job) => job.status == JobStatus.failed).toList(growable: false);

  bool get isEmpty => jobs.isEmpty;
  bool get isBusy => activeCount > 0;

  ProcessingJob? operator [](String id) {
    for (final job in jobs) {
      if (job.id == id) return job;
    }
    return null;
  }

  ProcessingQueueState _replace(ProcessingJob updated) =>
      ProcessingQueueState(jobs
          .map((job) => job.id == updated.id ? updated : job)
          .toList(growable: false));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProcessingQueueState &&
          const ListEquality().equals(other.jobs, jobs));

  @override
  int get hashCode => const ListEquality().hash(jobs);
}

/// App-scope queue. Deliberately **not** `autoDispose`: background work must
/// outlive whichever screen started it, and dismissing a row is an explicit
/// action rather than a side effect of popping a route.
///
/// Phase 0 keeps jobs in memory only. Persistence (so a queued import survives
/// process death, NFR-03) lands in Phase 5 with the rest of the schema — this
/// notifier stays the single write path for job state either way.
class ProcessingQueueNotifier extends Notifier<ProcessingQueueState> {
  @override
  ProcessingQueueState build() => const ProcessingQueueState();

  int _sequence = 0;

  /// Creates a job and returns its id. The id is what every later call uses, so
  /// the view never has to locate a row by title.
  String enqueue({
    required JobKind kind,
    required String title,
    String stage = 'Đang chờ',
  }) {
    final now = DateTime.now();
    final id = 'job-${now.microsecondsSinceEpoch}-${_sequence++}';
    final job = ProcessingJob(
      id: id,
      kind: kind,
      title: title,
      status: JobStatus.queued,
      stage: stage,
      createdAt: now,
      updatedAt: now,
    );
    state = ProcessingQueueState([...state.jobs, job]);
    return id;
  }

  void start(String id, {String? stage}) => _update(
        id,
        (job, now) => job.copyWith(
          status: JobStatus.running,
          stage: stage ?? job.stage,
          updatedAt: now,
        ),
      );

  void report(String id, {required double progress, String? stage}) => _update(
        id,
        (job, now) => job.copyWith(
          status: JobStatus.running,
          progress: progress.clamp(0.0, 1.0),
          stage: stage,
          updatedAt: now,
        ),
        onlyWhenActive: true,
      );

  void succeed(String id) => _update(
        id,
        (job, now) => job.copyWith(
          status: JobStatus.succeeded,
          progress: 1.0,
          stage: 'Xong',
          updatedAt: now,
        ),
      );

  void fail(String id, AppFailure failure) => _update(
        id,
        (job, now) => job.copyWith(
          status: JobStatus.failed,
          stage: 'Thất bại',
          failure: failure,
          updatedAt: now,
        ),
      );

  /// Not a failure — clears any failure so the row never reads as both.
  void cancel(String id) => _update(
        id,
        (job, now) => job.copyWith(
          status: JobStatus.cancelled,
          stage: 'Đã hủy',
          failure: null,
          progress: job.progress,
          updatedAt: now,
        ),
      );

  void retry(String id) => _update(
        id,
        (job, now) => job.copyWith(
          status: JobStatus.queued,
          stage: 'Đang chờ',
          failure: null,
          progress: 0,
          updatedAt: now,
        ),
      );

  /// Removes a terminal row. Used when a succeeded row ages out, and when the
  /// user clears the strip.
  void dismiss(String id) {
    state = ProcessingQueueState(
      state.jobs.where((job) => job.id != id).toList(growable: false),
    );
  }

  /// Clears every terminal row in one action.
  void clearFinished() {
    state = ProcessingQueueState(
      state.jobs.where((job) => job.isActive).toList(growable: false),
    );
  }

  void _update(
    String id,
    ProcessingJob Function(ProcessingJob job, DateTime now) transform, {
    bool onlyWhenActive = false,
  }) {
    final existing = state[id];
    if (existing == null) return;
    // A terminal row must not be resurrected by a late progress callback
    // arriving from an isolate that was not cancelled in time.
    if (onlyWhenActive && !existing.isActive) return;
    state = state._replace(transform(existing, DateTime.now()));
  }
}

final processingQueueProvider =
    NotifierProvider<ProcessingQueueNotifier, ProcessingQueueState>(
  ProcessingQueueNotifier.new,
);
