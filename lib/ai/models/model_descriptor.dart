/// What one downloadable TTS model *is*, in the terms the app needs to decide
/// whether to offer it, install it, and run it.
///
/// This is the seam that turned a single hardcoded class
/// (`VieNeuModelManifest`, a pile of statics) into a catalogue. The two
/// implementations are not variations of one model — they are different
/// architectures with different input contracts, different sample rates and
/// different licences — so the interface is drawn around what genuinely
/// generalises, and nothing else.
///
/// **Deliberately not in this interface:**
///
/// * *How* to synthesize. A Piper model is one ONNX pass; a VieNeu model is
///   seventeen. Encoding that as a method here would put a `switch` in the
///   middle of the app instead of at the edge, where `TtsEngine` already does
///   the job.
/// * *Whether the phonemizer can run here*. That is a property of the device,
///   not of the bytes on the server, and it is answered by
///   [ModelDescriptor.phonemizerNote] for display and by the engine itself at
///   load time for fact.
///
/// Adding a third model means adding a manifest and an engine — not editing
/// this file.
library;

/// One downloadable artifact. See the field docs for why each is here.
class ModelFileSpec {
  const ModelFileSpec({
    required this.relativePath,
    required this.url,
    required this.sizeBytes,
    required this.sha256,
    this.platforms = const <String>{},
    this.note,
  });

  /// Path under the models root, e.g. `vieneu-v3-turbo-int8/config.json`.
  /// The sub-directory is part of the path because the engine is handed one
  /// directory per component and must not have to guess where files landed.
  final String relativePath;

  final String url;

  /// Expected byte length. Checked while streaming, so a truncated download
  /// fails before 100 MB of hashing is wasted.
  final int sizeBytes;

  /// Lower-case hex SHA-256 of the artifact.
  final String sha256;

  /// Empty means "every platform". Non-empty lists the platforms this file is
  /// needed on — the g2p native library, which is per-architecture.
  final Set<String> platforms;

  /// Why this file is here, for the Models screen's detail line.
  final String? note;

  bool appliesTo(String platform) =>
      platforms.isEmpty || platforms.contains(platform);

  String get fileName => relativePath.split('/').last;
}

/// Everything the catalogue, the installer and the Models screen need to know
/// about a model without loading any of its bytes.
abstract interface class ModelDescriptor {
  /// Stable id. Also the on-disk directory name, so it must be filesystem-safe
  /// and must not change once released: a rename orphans every user's install.
  String get modelId;

  /// The name a person reads in the list.
  String get checkpointName;

  /// Which [TtsEngine] runs it. Two models sharing an engine id are weights
  /// swaps; different ids mean different engines.
  String get engineId;

  /// The exact licence string, displayed on the row. Not decorative — SRS §47
  /// warns that different checkpoints of the same family carry different terms.
  String get license;

  /// Where that licence was read from, shown next to it so the claim is
  /// checkable rather than asserted.
  String get licenseSource;

  /// Output sample rate in Hz. Shown on the row so the row is a spec of what
  /// will be heard rather than just a name.
  int get sampleRate;

  /// One line on what this model is for — the sentence that lets someone pick
  /// between rows without opening a browser.
  String get summary;

  /// How many distinct voices ship with it, or 0 if the count is not fixed.
  int get voiceCount;

  /// Exact download size on [platform], summed from the files rather than
  /// rounded on a screen.
  int totalBytesFor(String platform);

  /// Every file [platform] needs, in install order — small and structural first,
  /// so cancelling early costs the least.
  List<ModelFileSpec> filesFor(String platform);

  /// The sub-directories this model occupies under the models root, keyed by the
  /// role the engine expects to be handed.
  ///
  /// A map rather than one `directoryName` because the roles genuinely differ:
  /// VieNeu needs a codec and a sea-g2p dictionary beside its weights, Piper needs
  /// espeak-ng data and has no codec at all. The engine still receives a fixed
  /// `ModelDirectories` shape — this map is what fills it, and a role the model
  /// does not have is simply absent rather than pointed at something empty.
  ///
  /// Keys are the constants on `ModelComponent`.
  Map<String, String> get componentDirectories;

  /// One digest over the manifest itself, stored as `models.checksum`
  /// (SRS §35). Names the *set* of files and their expected hashes, so a row
  /// written by an older build of the app is recognisable as such instead of
  /// looking like a corrupt install.
  String get manifestDigest;
}

/// The roles a model can occupy under the models root.
///
/// Strings rather than an enum so a manifest can name a role without this file
/// changing, but named here so the contract is written down in one place.
abstract final class ModelComponent {
  /// The weights and their configuration. Every model has exactly one.
  static const String model = 'model';

  /// A neural audio codec, where the architecture predicts discrete codes that
  /// have to be turned back into a waveform.
  static const String codec = 'codec';

  /// Text → phoneme resources.
  static const String phonemizer = 'phonemizer';
}

/// Human size for the UI, in the unit a user can act on.
String formatModelBytes(int bytes) {
  if (bytes >= 1000 * 1000 * 1000) {
    return '${(bytes / 1000000000).toStringAsFixed(1)} GB';
  }
  if (bytes >= 1000 * 1000) {
    return '${(bytes / 1000000).round()} MB';
  }
  if (bytes >= 1000) return '${(bytes / 1000).round()} KB';
  return '$bytes B';
}
