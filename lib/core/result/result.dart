import 'package:flutter/foundation.dart' show immutable;

/// The return shape for anything that can fail — repositories, engines, parsers.
///
/// Typed failures instead of thrown exceptions, because every screen in this
/// product has to say *why* something failed ("PDF có mật khẩu" is not the same
/// message as "Dung lượng không đủ"), and an exception hierarchy cannot be
/// pattern-matched from a `switch` in the UI without losing exhaustiveness.
@immutable
sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = Success<T>;
  const factory Result.failure(AppFailure failure) = Failure<T>;

  R when<R>({
    required R Function(T value) success,
    required R Function(AppFailure failure) onError,
  }) =>
      switch (this) {
        Success<T>(:final value) => success(value),
        Failure<T>(:final failure) => onError(failure),
      };

  /// Returns the value, or `null` when this is a failure.
  T? get valueOrNull => switch (this) {
        Success<T>(:final value) => value,
        Failure<T>() => null,
      };

  AppFailure? get failureOrNull => switch (this) {
        Failure<T>(:final failure) => failure,
        Success<T>() => null,
      };

  bool get isSuccess => this is Success<T>;

  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Success<T>(:final value) => Success<R>(transform(value)),
        Failure<T>(:final failure) => Failure<R>(failure),
      };
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;

  @override
  bool operator ==(Object other) => other is Success<T> && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Success($value)';
}

final class Failure<T> extends Result<T> {
  const Failure(this.failure);
  final AppFailure failure;

  @override
  bool operator ==(Object other) =>
      other is Failure<T> && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'Failure($failure)';
}

/// Why something failed, in terms a user can act on.
///
/// Contract (DESIGN.md → Voice): [message] names the actual cause and the
/// actual next step. Never "Đã có lỗi xảy ra". [detail] carries technical
/// context for logs only and is never rendered.
@immutable
sealed class AppFailure {
  const AppFailure({
    required this.message,
    this.detail,
    this.retryable = false,
    this.cause,
  });

  /// Vietnamese-first, user-facing. States the cause and, where relevant, the fix.
  final String message;

  /// Technical context for local logs. Not shown in the UI.
  final String? detail;

  /// Whether offering a `Retry` action would be honest.
  final bool retryable;

  /// The underlying error, kept for logging only.
  final Object? cause;

  @override
  bool operator ==(Object other) =>
      other is AppFailure &&
      other.runtimeType == runtimeType &&
      other.message == message &&
      other.retryable == retryable;

  @override
  int get hashCode => Object.hash(runtimeType, message, retryable);

  @override
  String toString() => '$runtimeType($message)';
}

/// Import file failed validation: MIME, extension, size or integrity.
final class ValidationFailure extends AppFailure {
  const ValidationFailure({
    required super.message,
    super.detail,
    super.retryable,
    super.cause,
  });
}

/// The file type has no extractor at all (e.g. `.exe` pasted in).
final class UnsupportedFormatFailure extends AppFailure {
  const UnsupportedFormatFailure({
    required super.message,
    required this.extension,
    super.cause,
  });

  final String extension;
}

/// Document is password-protected. Distinct from a parse failure so the UI can
/// offer a password prompt instead of a retry.
final class EncryptedDocumentFailure extends AppFailure {
  const EncryptedDocumentFailure({
    super.message = 'Tệp được đặt mật khẩu, không thể trích xuất.',
    super.cause,
  });
}

/// The user backed out (cancelled the picker, stopped the job). Not an error —
/// the UI must not show a failure banner for it.
final class CancelledFailure extends AppFailure {
  const CancelledFailure({super.message = 'Đã hủy.'});
}

/// Filesystem / storage problems: full disk, revoked URI, IO error.
final class StorageFailure extends AppFailure {
  const StorageFailure({
    required super.message,
    super.detail,
    super.retryable = true,
    super.cause,
  });
}

/// The AI model needed for this job is not installed locally.
final class ModelUnavailableFailure extends AppFailure {
  const ModelUnavailableFailure({
    required super.message,
    required this.modelId,
    super.cause,
  });

  final String modelId;
}

/// The model file is present but cannot do its job: a half-finished download, a
/// wrong export, or a graph that fails its warm-up pass.
///
/// Distinct from [ModelUnavailableFailure] because the honest answer differs:
/// "chưa cài" offers `Install`, this offers `Re-download` (SRS FR-20 status
/// `Corrupt`), and a user who is offered the wrong one will keep re-installing a
/// file that is already there.
final class CorruptModelFailure extends AppFailure {
  const CorruptModelFailure({
    required super.message,
    super.detail,
    super.retryable = true,
    super.cause,
  });
}

/// A permission was denied (camera, storage).
final class PermissionFailure extends AppFailure {
  const PermissionFailure({
    required super.message,
    required this.permission,
    super.cause,
  });

  final String permission;
}

/// Parsing / OCR / synthesis failed for a specific unit of work. [pageNumber]
/// narrows the blame when the unit is a page, so one bad page does not read as
/// a bad document.
final class ProcessingFailure extends AppFailure {
  const ProcessingFailure({
    required super.message,
    super.detail,
    super.retryable = true,
    this.pageNumber,
    super.cause,
  });

  final int? pageNumber;
}

/// Referenced entity no longer exists (deleted document, missing asset).
final class NotFoundFailure extends AppFailure {
  const NotFoundFailure({required super.message, super.cause});
}

/// Anything unanticipated. Always logged; always told to the user with its real
/// cause rather than swallowed.
final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure({
    super.message = 'Không rõ nguyên nhân. Xem nhật ký để biết thêm.',
    super.detail,
    super.retryable = true,
    super.cause,
  });
}
