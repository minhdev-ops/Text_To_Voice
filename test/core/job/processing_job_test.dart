import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:text_to_voice/core/job/processing_job.dart';
import 'package:text_to_voice/core/result/result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProcessingQueueNotifier notifier;

  setUp(() {
    // Fresh container per test: the provider is app-scope by design, so the
    // notifier cannot be reused between cases.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    notifier = container.read(processingQueueProvider.notifier);
  });

  group('lifecycle', () {
    test('enqueue starts queued and counted as active', () {
      final id = notifier.enqueue(
        kind: JobKind.importFile,
        title: 'sach.pdf',
      );

      final job = notifier.state[id]!;
      expect(job.status, JobStatus.queued);
      expect(job.title, 'sach.pdf');
      expect(notifier.state.activeCount, 1);
      expect(notifier.state.isBusy, isTrue);
      expect(job.isRetryable, isFalse);
    });

    test('progress moves the job to running with a clamped value', () {
      final id = notifier.enqueue(kind: JobKind.ocr, title: 'anh.png');

      notifier.report(id, progress: 0.5, stage: 'Đang chạy OCR');
      var job = notifier.state[id]!;
      expect(job.status, JobStatus.running);
      expect(job.progress, 0.5);
      expect(job.stage, 'Đang chạy OCR');

      notifier.report(id, progress: 4.0);
      job = notifier.state[id]!;
      expect(job.progress, 1.0, reason: 'progress must never exceed 1');
    });

    test('success ends the job and marks it not active', () {
      final id = notifier.enqueue(kind: JobKind.extraction, title: 'a.pdf');
      notifier.start(id);
      notifier.succeed(id);

      final job = notifier.state[id]!;
      expect(job.status, JobStatus.succeeded);
      expect(job.progress, 1.0);
      expect(job.stage, 'Xong');
      expect(job.isActive, isFalse);
      expect(notifier.state.isBusy, isFalse);
    });

    test('a late progress callback cannot resurrect a finished job', () {
      final id = notifier.enqueue(kind: JobKind.ocr, title: 'b.png');
      notifier.start(id);
      notifier.succeed(id);

      // e.g. an isolate that was not cancelled in time reports back anyway.
      notifier.report(id, progress: 0.42);

      final job = notifier.state[id]!;
      expect(job.status, JobStatus.succeeded);
      expect(job.progress, 1.0);
    });

    test('progress after an explicit cancel is ignored', () {
      final id = notifier.enqueue(kind: JobKind.synthesis, title: 'doc');
      notifier.start(id);
      notifier.cancel(id);

      notifier.report(id, progress: 0.9, stage: 'Đang tổng hợp giọng nói');

      expect(notifier.state[id]!.status, JobStatus.cancelled);
      expect(notifier.state[id]!.stage, 'Đã hủy');
    });
  });

  group('failures are typed and actionable', () {
    test('failure is stored and marked retryable only when it can be retried',
        () {
      final id = notifier.enqueue(kind: JobKind.importFile, title: 'c.pdf');
      notifier.start(id);
      notifier.fail(
        id,
        const ProcessingFailure(message: 'Trang 7 trích xuất thất bại.'),
      );

      final job = notifier.state[id]!;
      expect(job.status, JobStatus.failed);
      expect(job.failure, isA<ProcessingFailure>());
      expect(job.isRetryable, isTrue);
      expect(notifier.state.failed, hasLength(1));
    });

    test('a non-retryable failure offers no retry', () {
      final id = notifier.enqueue(kind: JobKind.importFile, title: 'locked.pdf');
      notifier.fail(id, const EncryptedDocumentFailure());

      expect(notifier.state[id]!.isRetryable, isFalse);
    });

    test('retry returns the job to the queue and clears the failure', () {
      final id = notifier.enqueue(kind: JobKind.ocr, title: 'd.png');
      notifier.start(id);
      notifier.fail(id, const ProcessingFailure(message: 'OCR lỗi.'));
      notifier.retry(id);

      final job = notifier.state[id]!;
      expect(job.status, JobStatus.queued);
      expect(job.failure, isNull);
      expect(job.progress, 0);
      expect(job.stage, 'Đang chờ');
    });
  });

  group('cancellation is not a failure', () {
    test('cancel clears any failure and is not retryable', () {
      final id = notifier.enqueue(kind: JobKind.importFile, title: 'e.pdf');
      notifier.start(id);
      notifier.fail(id, const ProcessingFailure(message: 'x'));
      notifier.cancel(id);

      final job = notifier.state[id]!;
      expect(job.status, JobStatus.cancelled);
      expect(job.failure, isNull,
          reason: 'a row must never read as failed AND cancelled');
      expect(job.isRetryable, isFalse);
      expect(job.isTerminal, isTrue);
    });

    test('cancelling an unknown job is a no-op', () {
      expect(() => notifier.cancel('nope'), returnsNormally);
      expect(notifier.state.isEmpty, isTrue);
    });
  });

  group('clearing the strip', () {
    test('clearFinished keeps active work and drops terminal rows', () {
      final done = notifier.enqueue(kind: JobKind.importFile, title: 'done.pdf');
      final running =
          notifier.enqueue(kind: JobKind.ocr, title: 'running.png');
      final failed =
          notifier.enqueue(kind: JobKind.importFile, title: 'failed.pdf');

      notifier.succeed(done);
      notifier.start(running);
      notifier.fail(failed, const ProcessingFailure(message: 'x'));

      notifier.clearFinished();

      expect(notifier.state.jobs, hasLength(1));
      expect(notifier.state.jobs.single.id, running);
    });

    test('dismiss removes exactly one row', () {
      final a = notifier.enqueue(kind: JobKind.ocr, title: 'a');
      final b = notifier.enqueue(kind: JobKind.ocr, title: 'b');
      notifier.succeed(a);

      notifier.dismiss(a);

      expect(notifier.state[a], isNull);
      expect(notifier.state[b], isNotNull);
    });
  });

  group('state is a value', () {
    test('publishing an identical queue does not change identity by value', () {
      final id = notifier.enqueue(kind: JobKind.ocr, title: 'x');
      final before = notifier.state;
      notifier.report(id, progress: 0.25);

      expect(notifier.state == before, isFalse);
      expect(notifier.state.hashCode, isNot(before.hashCode));
    });
  });
}
