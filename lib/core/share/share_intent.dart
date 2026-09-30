import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A file the operating system handed the app through `ACTION_VIEW` or
/// `ACTION_SEND` — the other half of FR-02, alongside the picker.
@immutable
class SharedFile {
  const SharedFile({
    required this.name,
    required this.path,
    required this.mimeType,
    this.size = 0,
  });

  final String name;
  final String path;

  /// MIME as reported by the platform. Untrusted until checked against the
  /// file's magic numbers (SRS §38), which is validation's job, not ours.
  final String mimeType;

  final int size;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SharedFile &&
          other.name == name &&
          other.path == path &&
          other.mimeType == mimeType &&
          other.size == size);

  @override
  int get hashCode => Object.hash(name, path, mimeType, size);

  @override
  String toString() => 'SharedFile($name, $mimeType, $size bytes)';
}

/// Where incoming share intents come from.
abstract interface class ShareIntentSource {
  /// `false` while no plugin is wired — see [UnsupportedShareIntentSource].
  bool get isSupported;

  /// Emits each file as the platform delivers it.
  Stream<SharedFile> get sharedFiles;
}

/// Phase 0's honest stand-in.
///
/// The Android side is already declared: `AndroidManifest.xml` carries the
/// `ACTION_VIEW` and `ACTION_SEND` filters for every supported MIME type, so
/// the OS will offer this app. Nothing on the Dart side listens yet, so the
/// source reports `isSupported == false` and never emits rather than pretending
/// to work. Phase 3 replaces it by overriding [shareIntentSourceProvider] in
/// `main()` once a intent plugin is installed.
///
/// A test overrides this with a fake source and asserts the Library surfaces
/// an arrival, so the wiring is proven before the plugin exists.
class UnsupportedShareIntentSource implements ShareIntentSource {
  const UnsupportedShareIntentSource();

  @override
  bool get isSupported => false;

  @override
  Stream<SharedFile> get sharedFiles => const Stream<SharedFile>.empty();
}

/// Composition-root seam: throws nothing, defaults to the honest stub, and is
/// overridden once in `main()` when Phase 3 installs the real source.
final shareIntentSourceProvider = Provider<ShareIntentSource>(
  (ref) => const UnsupportedShareIntentSource(),
);

/// Bridge from the source to the UI.
///
/// A [StreamProvider] rather than raw stream wiring so there is exactly one
/// subscription for the whole app — a `StreamBuilder` per screen would open one
/// connection per rebuild.
///
/// Value type is nullable on purpose: Riverpod keeps a `StreamProvider` in
/// *loading* forever if its stream ends without emitting, and disposing it in
/// that state throws. Both branches here are therefore guaranteed to reach a
/// value — [UnsupportedShareIntentSource] emits an immediate `null`, and a
/// source that ends empty gets a trailing one.
final sharedFilesProvider = StreamProvider<SharedFile?>((ref) {
  final source = ref.watch(shareIntentSourceProvider);
  if (!source.isSupported) return Stream<SharedFile?>.value(null);
  return _terminal(source.sharedFiles);
});

Stream<SharedFile?> _terminal(Stream<SharedFile> source) async* {
  var emitted = false;
  await for (final file in source) {
    emitted = true;
    yield file;
  }
  if (!emitted) yield null;
}
