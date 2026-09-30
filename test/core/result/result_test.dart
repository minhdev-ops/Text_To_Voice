import 'package:flutter_test/flutter_test.dart';

import 'package:text_to_voice/core/result/result.dart';

void main() {
  group('Result', () {
    test('success exposes its value and maps', () {
      const r = Result<int>.success(7);
      expect(r.isSuccess, isTrue);
      expect(r.valueOrNull, 7);
      expect(r.failureOrNull, isNull);
      expect(r.map((v) => v * 2), const Result<int>.success(14));
      expect(r.when(success: (v) => 'ok$v', onError: (_) => 'err'), 'ok7');
    });

    test('failure exposes its typed cause and maps without losing it', () {
      const failure = ValidationFailure(message: 'Dung lượng tệp quá lớn.');
      const r = Result<int>.failure(failure);

      expect(r.isSuccess, isFalse);
      expect(r.valueOrNull, isNull);
      expect(r.failureOrNull, same(failure));
      expect(r.map((v) => v * 2).failureOrNull, same(failure));
      expect(
        r.when(success: (_) => 'ok', onError: (f) => f.message),
        'Dung lượng tệp quá lớn.',
      );
    });

    test('failures are distinguishable by type for the UI', () {
      const failures = <AppFailure>[
        ValidationFailure(message: 'sai'),
        UnsupportedFormatFailure(message: 'sai', extension: 'exe'),
        EncryptedDocumentFailure(),
        CancelledFailure(),
        StorageFailure(message: 'sai'),
        ModelUnavailableFailure(message: 'sai', modelId: 'vien.v3'),
        PermissionFailure(message: 'sai', permission: 'camera'),
        ProcessingFailure(message: 'sai', pageNumber: 7),
        NotFoundFailure(message: 'sai'),
        UnexpectedFailure(),
      ];

      // Each subtype must be assignable to the sealed base so a switch in the
      // UI stays exhaustive.
      expect(failures, hasLength(10));

      final processing =
          failures.whereType<ProcessingFailure>().single;
      expect(processing.pageNumber, 7);
      expect(processing.retryable, isTrue);

      expect(
        const EncryptedDocumentFailure().retryable,
        isFalse,
        reason: 'retrying an encrypted file without a password never works',
      );
      expect(const CancelledFailure().message, 'Đã hủy.');
    });

    test('identity is by type and message, not by instance', () {
      const a = ValidationFailure(message: 'x');
      const b = ValidationFailure(message: 'x');
      const c = ValidationFailure(message: 'y');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a, isNot(const StorageFailure(message: 'x')));
    });
  });
}
