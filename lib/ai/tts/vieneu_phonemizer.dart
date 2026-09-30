import 'dart:ffi' as ffi;
import 'dart:io' show File, Platform;

import 'package:ffi/ffi.dart';

import '../../core/result/result.dart';

/// Vietnamese text → phonemes.
///
/// A port, in the sense the rest of this codebase uses the word: the engine
/// depends on this interface, and the FFI binding is one implementation behind
/// it. That is what lets the read-aloud path be tested without a native library
/// (and, on a platform where the library is not built yet, without pretending
/// the feature works).
abstract interface class VieNeuPhonemizer {
  /// `false` when the native library or its dictionary is missing.
  bool get isAvailable;

  /// Phonemizes one sentence. [puncNorm] applies sea-g2p's trailing-punctuation
  /// rule (see [SeaG2pPhonemizer.phonemize]).
  String phonemize(String text, {bool puncNorm});

  void close();
}

/// Vietnamese text → phonemes, via the sea-g2p C ABI.
///
/// The checkpoint does not take Vietnamese text; it takes a *phoneme string*
/// produced by sea-g2p (a Rust dictionary + normalizer + G2P: numbers, dates,
/// units, abbreviations, URLs, and the Vietnamese/English reading of each token).
/// The reference implementation calls the same library through its Python
/// binding (`vieneu_utils.phonemize_text`).
///
/// **Not reimplemented in Dart, deliberately.** sea-g2p's own README warns that a
/// second implementation drifts: the rules are ~60 KB of Rust plus a 44 KB
/// resource table plus a 550 KB bigram model. A hand-written approximation would
/// produce phonemes that look plausible and read wrong.
///
/// **Android caveat, measured not assumed.** The upstream release ships
/// prebuilt libraries for linux-x86_64, macos-aarch64 and windows-x86_64 — there
/// is no Android `.so`. On Android this class therefore reports
/// [isAvailable]` == false` with a specific message until the library is built
/// with `tool/build_g2p.sh` (cargo-ndk) and dropped into
/// `android/app/src/main/jniLibs/`. That is a real gap in the shipped feature,
/// so it says so instead of failing obscurely mid-sentence.
class SeaG2pPhonemizer implements VieNeuPhonemizer {
  SeaG2pPhonemizer._(this._library, this._handle);

  final ffi.DynamicLibrary _library;
  final ffi.Pointer<ffi.Void> _handle;

  /// Filenames to try, in order, for the current platform.
  ///
  /// The release names carry a platform/arch suffix; the packaged names do not
  /// (Android loads `.so` files from `jniLibs` by their bare name, and the
  /// desktop bundle ships whatever the build script produced).
  static List<String> libraryFileNames() => switch (Platform.operatingSystem) {
        'linux' => <String>[
            'libsea_g2p_rs.so',
            'libsea_g2p_rs-linux-x86_64.so',
          ],
        'macos' => <String>[
            'libsea_g2p_rs.dylib',
            'libsea_g2p_rs-macos-aarch64.dylib',
          ],
        'windows' => <String>[
            'sea_g2p_rs.dll',
            'sea_g2p_rs-windows-x86_64.dll',
          ],
        _ => <String>['libsea_g2p_rs.so'],
      };

  /// The dictionary file, next to whatever the install placed the library in.
  static const String dictionaryFileName = 'sea_g2p.bin';

  bool get _isOpen => _handle != ffi.nullptr;

  @override
  bool get isAvailable => _isOpen;

  /// Opens the library and its dictionary.
  ///
  /// [searchDirectories] is tried in order; on Android the packaged name is also
  /// attempted through the loader's default search path, which is how `jniLibs`
  /// libraries are found.
  static Result<SeaG2pPhonemizer> open({
    required List<String> searchDirectories,
    String? explicitLibraryPath,
    String? explicitDictionaryPath,
  }) {
    final dictionaryPath = _resolveDictionary(
      searchDirectories,
      explicitDictionaryPath,
    );
    if (dictionaryPath == null) {
      return Result<SeaG2pPhonemizer>.failure(ModelUnavailableFailure(
        message: 'Thiếu từ điển ngữ âm ($dictionaryFileName) cho giọng đọc.',
        modelId: 'sea-g2p',
      ));
    }

    ffi.DynamicLibrary? library;
    final failures = <String>[];
    if (explicitLibraryPath != null) {
      final candidate = _tryOpen(explicitLibraryPath, failures);
      if (candidate != null) library = candidate;
    }
    if (library == null) {
      for (final directory in searchDirectories) {
        if (library != null) break;
        for (final fileName in libraryFileNames()) {
          final candidate = _tryOpen('$directory/$fileName', failures);
          if (candidate != null) {
            library = candidate;
            break;
          }
        }
      }
    }
    if (library == null) {
      // Last resort: let the platform loader search its own paths.
      for (final fileName in libraryFileNames()) {
        final candidate = _tryOpen(fileName, failures);
        if (candidate != null) {
          library = candidate;
          break;
        }
      }
    }
    if (library == null) {
      return Result<SeaG2pPhonemizer>.failure(ModelUnavailableFailure(
        message: Platform.isAndroid
            ? 'Bộ chuyển ngữ âm tiếng Việt chưa có trên thiết bị này.'
            : 'Không nạp được thư viện chuyển ngữ âm.',
        modelId: 'sea-g2p',
        // The detail names every path tried, so "not found" can be diagnosed
        // instead of re-discovered.
        cause: failures.join('\n'),
      ));
    }

    try {
      final version = library.lookupFunction<ffi.Int32 Function(), int Function()>(
        'sea_g2p_abi_version',
      );
      final abi = version();
      if (abi != _expectedAbiVersion) {
        return Result<SeaG2pPhonemizer>.failure(CorruptModelFailure(
          message: 'Thư viện chuyển ngữ âm không tương thích (ABI $abi).',
          detail: 'expected $_expectedAbiVersion',
        ));
      }

      final open = library.lookupFunction<
          ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Char>),
          ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Char>)>('sea_g2p_open');
      final dictionary = dictionaryPath.toNativeUtf8();
      ffi.Pointer<ffi.Void> handle;
      try {
        handle = open(dictionary.cast());
      } finally {
        malloc.free(dictionary);
      }
      if (handle == ffi.nullptr) {
        final message = _lastError(library) ?? 'không rõ nguyên nhân';
        return Result<SeaG2pPhonemizer>.failure(CorruptModelFailure(
          message: 'Không mở được từ điển ngữ âm.',
          detail: message,
        ));
      }
      return Result<SeaG2pPhonemizer>.success(
          SeaG2pPhonemizer._(library, handle));
    } catch (error) {
      return Result<SeaG2pPhonemizer>.failure(ModelUnavailableFailure(
        message: 'Thư viện chuyển ngữ âm không dùng được.',
        modelId: 'sea-g2p',
        cause: error,
      ));
    }
  }

  static const int _expectedAbiVersion = 1;

  static ffi.DynamicLibrary? _tryOpen(String path, List<String> failures) {
    try {
      return ffi.DynamicLibrary.open(path);
    } catch (error) {
      failures.add('$path → $error');
      return null;
    }
  }

  static String? _resolveDictionary(
    List<String> directories,
    String? explicit,
  ) {
    if (explicit != null && File(explicit).existsSync()) return explicit;
    for (final directory in directories) {
      final candidate = File('$directory/$dictionaryFileName');
      if (candidate.existsSync()) return candidate.path;
    }
    return null;
  }

  /// Normalizes and phonemizes one sentence.
  ///
  /// [puncNorm] mirrors the reference's always-on trailing-punctuation rule: a
  /// sentence under five words is forced to end in exactly one `.`, a longer one
  /// gets `.` appended if it lacks a terminal mark. Turning it off is only right
  /// for a fragment *inside* a sentence (the reference does that when splicing
  /// inline emotion cues).
  @override
  String phonemize(String text, {bool puncNorm = true}) {
    if (!_isOpen) {
      throw StateError('Bộ chuyển ngữ âm chưa được mở.');
    }
    final phonemize = _library.lookupFunction<
        ffi.Pointer<ffi.Char> Function(
            ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Char>, ffi.Int32),
        ffi.Pointer<ffi.Char> Function(
            ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Char>, int)>('sea_g2p_phonemize');

    final input = text.toNativeUtf8();
    try {
      final result = phonemize(_handle, input.cast(), puncNorm ? 1 : 0);
      if (result == ffi.nullptr) {
        throw StateError(_lastError(_library) ?? 'chuyển ngữ âm thất bại');
      }
      try {
        return result.cast<Utf8>().toDartString();
      } finally {
        _stringFree(_library, result);
      }
    } finally {
      malloc.free(input);
    }
  }

  @override
  void close() {
    if (!_isOpen) return;
    final close = _library.lookupFunction<
        ffi.Void Function(ffi.Pointer<ffi.Void>),
        void Function(ffi.Pointer<ffi.Void>)>('sea_g2p_close');
    close(_handle);
  }

  static void _stringFree(ffi.DynamicLibrary library, ffi.Pointer<ffi.Char> text) {
    final free = library.lookupFunction<
        ffi.Void Function(ffi.Pointer<ffi.Char>),
        void Function(ffi.Pointer<ffi.Char>)>('sea_g2p_string_free');
    free(text);
  }

  static String? _lastError(ffi.DynamicLibrary library) {
    final lastError = library.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('sea_g2p_last_error');
    final pointer = lastError();
    if (pointer == ffi.nullptr) return null;
    // Borrowed, per the header: valid until the next failing call on this
    // thread, so it is copied immediately.
    return pointer.cast<Utf8>().toDartString();
  }
}
