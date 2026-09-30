import 'dart:io' show File, FileSystemException;
import 'dart:typed_data' show Uint8List;

import '../../core/result/result.dart';
import '../models/imported_file.dart' show ImportedFile;

/// Reads the bytes of an imported file, with the failure the user should see.
///
/// Kept in one place because every extractor needs it and each one inventing its
/// own message is how a product ends up saying five different things about a file
/// that was moved.
Result<Uint8List> readImportedBytes(ImportedFile file) {
  try {
    final handle = File(file.path);
    if (!handle.existsSync()) {
      return const Failure(StorageFailure(
        message: 'Không tìm thấy tệp. Có thể tệp đã bị di chuyển hoặc xoá.',
      ));
    }
    return Success(handle.readAsBytesSync());
  } on FileSystemException catch (error) {
    return Failure(StorageFailure(
      message: 'Không đọc được tệp.',
      detail: error.message,
      cause: error,
    ));
  } catch (error) {
    return Failure<Uint8List>(StorageFailure(
      message: 'Không đọc được tệp.',
      detail: error.toString(),
      cause: error,
    ));
  }
}
