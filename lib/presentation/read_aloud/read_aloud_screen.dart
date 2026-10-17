import 'dart:async' show Timer, unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:file_picker/file_picker.dart' show PlatformFile;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ai/tts/vieneu_voices.dart';
import '../../core/logging/app_log.dart';
import '../../core/result/result.dart' show Failure, Success;
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/semantic_colors.dart';
import '../../core/theme/tokens.dart';
import '../../data/providers.dart';
import '../../data/repository/document_repository.dart' show DocumentWithData;
import '../../domain/engines/progress.dart' show JobStage;
import '../../domain/export/document_export_service.dart' show ExportOutcome;
import '../../domain/import/document_importer.dart' show DocumentImporter;
import '../../domain/models/reading.dart';
import '../../domain/models/tts.dart' show TtsOptions;
import '../../domain/speech/read_aloud_session.dart' show ReadAloudState;
import '../../domain/text/sentence_splitter.dart';
import '../common/duration_label.dart';
import '../library/library_providers.dart' show importServiceProvider;
import '../library/resume_strip.dart' show latestReadingPositionProvider;
import 'background_synthesis_controller.dart';
import 'export_sheet.dart';
import 'read_aloud_providers.dart';
import 'reading_view.dart';
import 'sentence_ruler.dart';
import 'transport_bar.dart';
import 'tts_options_sheet.dart';

/// Second destination: the direct text → speech path (SRS §39 Flow 1, FR-09).
///
/// The surface changes shape with the state instead of showing everything at
/// once: a composer while there is nothing to read, a measured reading column —
/// the document as **continuous prose**, images in their places — with the
/// Listening Spine while reading, and the sticky transport bar inside it. There
/// is deliberately no separate full-screen player — audio controls live with
/// the words they control.
class ReadAloudScreen extends ConsumerStatefulWidget {
  const ReadAloudScreen({super.key});

  static const String location = '/read-aloud';
  static const String navLabel = 'Đọc';

  @override
  ConsumerState<ReadAloudScreen> createState() => _ReadAloudScreenState();
}

class _ReadAloudScreenState extends ConsumerState<ReadAloudScreen> {
  /// Text being composed. Ephemeral UI state, so it stays in the widget; the
  /// reading state itself lives in the session (never here).
  final TextEditingController _text = TextEditingController();

  final SentenceSplitter _splitter = const SentenceSplitter();

  /// The `documentId` whose text is currently on screen, so a repeat navigation
  /// to the same document does not reload it.
  String? _loadedDocumentId;
  bool _resume = false;

  /// The full location last acted on. GoRouter only notifies when the URI
  /// actually changes, so every navigation carries a `nonce` and this is what
  /// tells a *new* request apart from a re-delivery of the current one.
  String? _lastHandledLocation;

  /// A paragraph a search result asked to land on (its block order), applied
  /// once the document's text has been split into sentences.
  int? _pendingParagraph;

  /// Why the surface is blank when a document carried no text. Null otherwise.
  String? _loadFailure;

  /// The loaded document with its blocks and page images, so the reading view
  /// can show the pictures where the document put them.
  DocumentWithData? _document;

  /// Debounces the composer draft write and the reading-position write: one
  /// write per pause in activity, not one per keystroke or per sentence.
  Timer? _draftSaveTimer;
  Timer? _positionSaveTimer;

  /// A file being read into the composer right now (`Thêm ảnh hoặc tệp`).
  bool _importing = false;
  double _importProgress = 0;
  String _importStage = JobStage.queued;

  /// Saves the draft and the reading position when the app leaves the fore-
  /// ground — the moment the debounce can no longer be trusted to fire.
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreComposerDraft());
    _lifecycle = AppLifecycleListener(onPause: _flushOnPause);
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _draftSaveTimer?.cancel();
    _positionSaveTimer?.cancel();
    _locations?.removeListener(_onLocationChanged);
    _text.dispose();
    super.dispose();
  }

  bool get _hasText => _text.text.trim().isNotEmpty;

  /// Sentence count of what is typed, shown before reading starts.
  ///
  /// A count, not an invented time estimate: the app cannot know how long audio
  /// will take before it is synthesized, and a made-up duration would be a
  /// fake-precise number (DESIGN.md → Voice).
  int get _sentenceCount {
    if (!_hasText) return 0;
    return _splitter.split(_text.text).length;
  }

  // ---------------------------------------------------------------------------
  // Composer draft — typed text survives leaving the screen, backgrounding the
  // app, and killing the process (settings key [composerDraftSettingKey]).
  // ---------------------------------------------------------------------------

  Future<void> _restoreComposerDraft() async {
    try {
      // Inside the `try`: this screen is also mounted without a database
      // (widget tests, previews) and a draft that cannot be read must cost the
      // composer nothing.
      final repo = ref.read(documentRepositoryProvider);
      final draft = await repo.getSetting(composerDraftSettingKey);
      if (!mounted) return;
      if (draft == null || draft.isEmpty) return;
      // A document opened before the restore resolved wins: its text is on
      // screen and overwriting it with the draft would be data corruption.
      if (_loadedDocumentId != null || _text.text.isNotEmpty) return;
      _text.text = draft;

      // And the voice the composer was last read with.
      final saved = await repo.getSetting(ttsOptionsSettingKey(composerDocumentId));
      final options = _decodeOptions(saved);
      if (options != null && mounted) {
        await ref
            .read(readAloudControllerProvider.notifier)
            .setOptions(options);
      }
      if (mounted) setState(() {});
    } catch (error, stack) {
      // A draft that cannot be read is a missing draft, not a broken composer.
      AppLog.error('composer.draft.restoreFailed',
          error: error, stackTrace: stack);
    }
  }

  void _scheduleDraftSave() {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 800), () {
      try {
        final repo = ref.read(documentRepositoryProvider);
        unawaited(repo.setSetting(composerDraftSettingKey, _text.text));
      } catch (error, stack) {
        AppLog.error('composer.draft.saveFailed',
            error: error, stackTrace: stack);
      }
    });
  }

  /// Reads a picked file — an image, a scanned PDF, a text file — into the
  /// composer, appending its text to whatever is already there.
  ///
  /// This is the image half of "một văn bản dài": a photo of a page becomes
  /// paragraphs in the same draft as the typed text, instead of a separate
  /// document the reader has to open on its own. OCR runs on-device (the same
  /// pipeline the camera uses), and the extraction reports its own progress
  /// because a scanned page takes seconds, not milliseconds.
  Future<void> _addFileToComposer() async {
    final importer = DocumentImporter(
      importService: ref.read(importServiceProvider),
    );
    final PlatformFile? picked = await importer.pick();
    // Cancelling the picker is not a failure and is never announced.
    if (picked == null || !mounted) return;

    setState(() {
      _importing = true;
      _importProgress = 0;
      _importStage = JobStage.queued;
    });

    final result = await importer.importFile(
      platformFile: picked,
      onProgress: (progress, stage) {
        if (!mounted) return;
        setState(() {
          _importProgress = progress;
          _importStage = stage;
        });
      },
    );
    if (!mounted) return;
    setState(() => _importing = false);

    switch (result) {
      case Success(:final value):
        final text = value.extractedText.trim();
        if (text.isEmpty) {
          _tell('Tệp này không có nội dung văn bản để đọc.');
          return;
        }
        // Appended, not replaced: adding a page to a draft must never throw
        // away what the reader already typed.
        final separator = _text.text.trim().isEmpty ? '' : '\n\n';
        _text.text = '${_text.text}$separator$text';
        _draftSaveTimer?.cancel();
        unawaited(_saveDraftNow());
        setState(() {});
        _tell(
          value.needsReview
              ? 'Đã thêm "${value.name}", nhưng ${value.lowConfidenceCount} dòng '
                  'nhận dạng không chắc chắn. Nên kiểm tra lại.'
              : 'Đã thêm "${value.name}" vào bản nháp.',
        );
      case Failure(:final failure):
        AppLog.warning('composer.import.failed',
            data: <String, Object?>{'reason': failure.message});
        _tell(failure.message);
    }
  }

  Future<void> _saveDraftNow() async {
    try {
      await ref
          .read(documentRepositoryProvider)
          .setSetting(composerDraftSettingKey, _text.text);
    } catch (error, stack) {
      AppLog.error('composer.draft.saveFailed', error: error, stackTrace: stack);
    }
  }

  void _tell(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------------------
  // Per-document reading state — position and voice options, so leaving and
  // coming back resumes exactly where the reading stopped.
  // ---------------------------------------------------------------------------

  /// Persists the sentence the Spine is on, debounced.
  void _schedulePositionSave(ReadAloudState state) {
    final documentId = _loadedDocumentId;
    if (documentId == null || state.isEmpty) return;
    _positionSaveTimer?.cancel();
    _positionSaveTimer = Timer(const Duration(seconds: 1), () {
      try {
        unawaited(ref
            .read(documentRepositoryProvider)
            .saveReadingPosition(ReadingPosition(
              documentId: documentId,
              sentenceIndex: state.currentIndex,
              updatedAt: DateTime.now(),
            )));
        // The Library's resume strip reads the latest position once and caches
        // it; without this it keeps offering the sentence the reading was on when
        // the tab was first built.
        ref.invalidate(latestReadingPositionProvider);
      } catch (error, stack) {
        AppLog.error('reading.position.saveFailed',
            error: error, stackTrace: stack);
      }
    });
  }

  /// Persists the reading voice for whichever document (or the composer) is
  /// current, so reopening restores it.
  void _saveOptions(TtsOptions options) {
    try {
      final key = ttsOptionsSettingKey(_loadedDocumentId ?? composerDocumentId);
      final repo = ref.read(documentRepositoryProvider);
      unawaited(repo.setSetting(key, jsonEncode(options.toJson())));
    } catch (error, stack) {
      AppLog.error('reading.options.saveFailed',
          error: error, stackTrace: stack);
    }
  }

  /// Decodes a stored options JSON. A corrupt entry is a missing one — the
  /// document just opens with the app defaults.
  static TtsOptions? _decodeOptions(String? stored) {
    if (stored == null || stored.isEmpty) return null;
    try {
      return TtsOptions.tryFromJson(jsonDecode(stored));
    } catch (_) {
      return null;
    }
  }

  /// Writes everything debounceable right now — the app is going to the
  /// background, and the debounce timer may never fire.
  void _flushOnPause() {
    _draftSaveTimer?.cancel();
    _positionSaveTimer?.cancel();
    try {
      final repo = ref.read(documentRepositoryProvider);
      if (_loadedDocumentId == null) {
        if (_hasText) {
          unawaited(repo.setSetting(composerDraftSettingKey, _text.text));
        }
        return;
      }
      final state = ref.read(readAloudControllerProvider);
      if (state.isEmpty) return;
      unawaited(repo.saveReadingPosition(ReadingPosition(
        documentId: _loadedDocumentId!,
        sentenceIndex: state.currentIndex,
        updatedAt: DateTime.now(),
      )));
      ref.invalidate(latestReadingPositionProvider);
    } catch (error, stack) {
      AppLog.error('reading.flush.failed', error: error, stackTrace: stack);
    }
  }

  /// Subscribes to the router's location the first time this screen is under
  /// one, and loads whatever document the route names.
  ///
  /// A listener rather than a read in `build`, because this tab is kept alive by
  /// an `indexedStack`: nothing rebuilds it when another tab navigates it to a
  /// different document, and `InheritedGoRouter` never changes either, so no
  /// framework callback fires at all. Without this the screen silently kept
  /// showing the first document the app ever opened.
  RouteInformationProvider? _locations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_locations == null) {
      // `maybeOf` rather than `of`: the screen is also pumped without a router
      // (tests, previews), and having no route is not worth a throw.
      final router = GoRouter.maybeOf(context);
      if (router == null) return;
      _locations = router.routeInformationProvider
        ..addListener(_onLocationChanged);
    }

    _onLocationChanged();
  }

  void _onLocationChanged() {
    final uri = _locations?.value.uri;
    if (uri == null) return;

    // Every navigation carries a `nonce`, so the same URI means the *same*
    // request delivered twice (`didChangeDependencies` calls this on every
    // dependency change) — acting on it again would yank a playing reading
    // back to a resume point or a search hit the user already visited.
    final location = uri.toString();
    if (location == _lastHandledLocation) return;

    final documentId = uri.queryParameters['documentId'];
    final resume = uri.queryParameters['resume'] == 'true';
    // `Đọc từ đầu` from the Library's resume strip. The position row is deleted
    // there, but this screen keeps its tab alive with the text still loaded, so
    // the navigation alone changed nothing — the reading carried on from the
    // sentence it had reached and the button looked dead.
    final fromStart = uri.queryParameters['fromStart'] == 'true';

    final paragraph = int.tryParse(uri.queryParameters['block'] ?? '');

    if (documentId == null) {
      // No document in the route — a tab tap, or the router's default location.
      // The reading on screen is untouched, and so is the document it belongs
      // to: clearing the id here would silently stop saving the reading
      // position for a document the user is still listening to.
      return;
    }

    _lastHandledLocation = location;

    if (documentId == _loadedDocumentId) {
      // Start over: reload the document so the queue and the reading begin at
      // sentence one, exactly as the button promises.
      if (fromStart) {
        _resume = false;
        _pendingParagraph = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_loadDocument(documentId));
        });
        return;
      }
      // A new search hit on the document already open: the text is loaded, so
      // only the seek has to happen.
      if (paragraph != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_seekToParagraph(paragraph));
        });
        return;
      }
      // `Tiếp tục` on a document whose text is already open has to seek, and
      // skipping it here was why that button could look inert.
      if (resume) {
        _resume = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_resumeFromSavedPosition(documentId));
        });
      }
      return;
    }

    _loadedDocumentId = documentId;
    _resume = resume;
    _pendingParagraph = paragraph;

    // Deferred: this can be reached from a dependency phase, and loading is
    // async I/O that must not run mid-frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadDocument(documentId));
    });
  }

  /// Seeks to the first sentence of the paragraph a search hit named.
  ///
  /// One paragraph per text block, and `Sentence.paragraph` is the block order,
  /// so this is the exact passage with no second scan of the text. A paragraph
  /// the split did not produce (an old hit, an edited document) leaves the
  /// reading where it was instead of moving it somewhere wrong.
  Future<void> _seekToParagraph(int paragraph) async {
    final index = _sentenceIndexForBlock(paragraph);
    if (index == null || !mounted) return;
    await ref
        .read(readAloudControllerProvider.notifier)
        .seekToSentence(index);
  }

  /// The first sentence of block [paragraph], or `null` when the mapping cannot
  /// be trusted.
  ///
  /// `Sentence.paragraph` is the paragraph's index in the *split text* while a
  /// search hit carries the stored block's order. They only line up when every
  /// block became exactly one paragraph — an empty block shifts every later
  /// index, and seeking to the wrong passage silently is worse than not
  /// moving. The reading view applies the same guard before placing images.
  int? _sentenceIndexForBlock(int paragraph) {
    final paragraphs = _splitter.splitByParagraph(_text.text);
    if (paragraph < 0 || paragraph >= paragraphs.length) return null;
    final blocks = _document?.blocks.length;
    if (blocks != null && blocks != paragraphs.length) return null;
    var index = 0;
    for (var p = 0; p < paragraph; p++) {
      index += paragraphs[p].length;
    }
    return paragraphs[paragraph].isEmpty ? null : index;
  }

  Future<void> _loadDocument(String documentId) async {
    try {
      final repo = ref.read(documentRepositoryProvider);
      final doc = await repo.getDocumentWithData(documentId);
      // A newer navigation supersedes this load: without this guard two quick
      // taps interleave, and the slower load's session/`_text` land last —
      // mixing one document's sentences with another's id.
      if (!mounted || documentId != _loadedDocumentId) return;
      if (doc == null) return;
      _document = doc;

      final text = doc.document.extractedText ?? '';
      if (text.trim().isEmpty) {
        // Say why the surface is blank instead of showing an empty composer that
        // looks like the text simply vanished.
        setState(() {
          _text.clear();
          _loadFailure = 'Tài liệu này chưa có nội dung văn bản để đọc.';
        });
        return;
      }

      _text.text = text;
      await repo.markOpened(documentId);
      if (!mounted || documentId != _loadedDocumentId) return;

      final controller = ref.read(readAloudControllerProvider.notifier);
      // This document's own voice, falling back to the composer's last-used one
      // and finally to the defaults set in Settings: reopening a document must
      // sound like it did before, and a first read inherits what the user chose
      // — in Settings, if nowhere else.
      try {
        final saved = await repo.getSetting(ttsOptionsSettingKey(documentId));
        final own = _decodeOptions(saved);
        if (own != null) {
          await controller.setOptions(own);
        } else {
          final lastUsed = await repo
              .getSetting(ttsOptionsSettingKey(composerDocumentId))
              .then(_decodeOptions);
          if (lastUsed != null) {
            await controller.setOptions(lastUsed);
          } else {
            final defaults = await ref.read(defaultTtsOptionsProvider.future);
            await controller.setOptions(defaults);
          }
        }
      } catch (error, stack) {
        AppLog.error('document.options.restoreFailed',
            error: error, stackTrace: stack);
      }
      if (!mounted || documentId != _loadedDocumentId) return;

      // Resume and search-hit landing are decided **before** `read`, which
      // synthesizes from the index it is given: awaiting a read that starts at
      // sentence 0 would hold the jump behind a full synthesis (~15 s measured
      // on a phone) and briefly play the wrong sentence first.
      var startIndex = 0;
      final paragraph = _pendingParagraph;
      _pendingParagraph = null;
      if (_resume) {
        _resume = false;
        final position = await repo.getReadingPosition(documentId);
        if (!mounted || documentId != _loadedDocumentId) return;
        if (position != null) startIndex = position.sentenceIndex;
      } else if (paragraph != null) {
        startIndex = _sentenceIndexForBlock(paragraph) ?? 0;
      }

      // `read` is awaited rather than raced with a timer: the seek below needs
      // the queue loaded, and a fixed delay is a guess about how long that takes.
      await controller.read(text, startIndex: startIndex);
      if (!mounted || documentId != _loadedDocumentId) return;

      setState(() => _loadFailure = null);
    } catch (error, stack) {
      AppLog.error('document.load.failed',
          error: error, stackTrace: stack);
      if (!mounted || documentId != _loadedDocumentId) return;
      setState(() {
        _loadFailure = 'Không mở được tài liệu này. Thử lại sau.';
      });
    }
  }

  /// Seeks to the sentence the document was last left on (SRS §33).
  ///
  /// Also reachable on its own, so `Tiếp tục` works on a document whose text is
  /// already open — not only on a fresh load.
  Future<void> _resumeFromSavedPosition(String documentId) async {
    final repo = ref.read(documentRepositoryProvider);
    final position = await repo.getReadingPosition(documentId);
    if (!mounted || position == null) return;
    await ref
        .read(readAloudControllerProvider.notifier)
        .seekToSentence(position.sentenceIndex);
  }

  /// Starts reading what the composer holds, and detaches the saved position
  /// from whatever document was on screen: this reading belongs to no document,
  /// and writing the composer's sentence index over a document's saved place
  /// would move the reader's bookmark for a different text.
  Future<void> _readComposed() async {
    _loadedDocumentId = null;
    _document = null;
    await ref.read(readAloudControllerProvider.notifier).read(_text.text);
  }

  /// Back to editing, which is also the end of the document's reading session.
  void _editText() {
    _loadedDocumentId = null;
    _document = null;
    unawaited(ref.read(readAloudControllerProvider.notifier).editText());
  }

  /// A measured sentence cost below this is not worth interrupting the user over.
  ///
  /// One threshold, two uses: the progress label and the voice/speed-change
  /// warning both ask the same question — *is this device slow enough that
  /// waiting is something the user should be told about?* — and they must
  /// answer it the same way, or the app contradicts itself between the label
  /// and the dialog.
  ///
  /// Three seconds rather than one because a second is not long enough to read a
  /// sentence aloud; a number below it is noise wearing a decimal point.
  static const int _slowSynthesisMs = 3000;

  /// The "still preparing" label, with a measured expectation once there is one.
  ///
  /// [priorMs] is the slowest sentence **this device** measured on an earlier
  /// read. It is what makes the *first* sentence legible: until one has been
  /// measured in this session there is nothing else to quote, and on a phone
  /// that gap is half a minute of bare "Đang xử lý…" — indistinguishable from a
  /// hang. A session's own measurement always wins over it.
  static String _preparingLabel(ReadAloudState state, {int? priorMs}) {
    final measured = state.synthesisMs ?? priorMs;
    if (measured == null || measured < _slowSynthesisMs) return 'Đang xử lý…';
    return 'Đang xử lý… ~${_secondsLabel(measured)}';
  }

  /// A whole number of seconds, rounded up, because a promise of "0 giây" while
  /// work is in flight is worse than no promise at all.
  static String _secondsLabel(int milliseconds) =>
      '${(milliseconds / 1000).ceil()} giây';

  /// Opens the voice sheet and applies what it confirms.
  ///
  /// A voice change and a speed change both discard the audio after the current
  /// sentence, so both are confirmed first on a device where that audio is
  /// expensive — the same measured rule [_slowSynthesisMs] sets for the
  /// progress label.
  Future<void> _pickOptions() async {
    final session = ref.read(readAloudSessionProvider);
    final state = ref.read(readAloudControllerProvider);

    // Awaiting the cached future: it resolves the moment the catalog is
    // parsed (and the asset parse is one-shot for the whole app), so the
    // sheet always opens with the real voice list. A catalog that cannot be
    // read is reported, not thrown out of the tap handler.
    final VieNeuVoiceCatalog catalog;
    try {
      catalog = await ref.read(voiceCatalogProvider.future);
    } catch (error, stack) {
      AppLog.error('voice.catalog.loadFailed',
          error: error, stackTrace: stack);
      if (mounted) _tell('Không mở được danh sách giọng đọc.');
      return;
    }
    if (!mounted) return;

    final current = session.options;
    // The sheet always commits a concrete voice, and the document usually has
    // none (`voiceId == null` *means* "the catalog default", which resolves to
    // the same speaker). Comparing the raw value would make "Xong" without any
    // change look like a real voice change and throw away every cached
    // sentence after the current one.
    final effectiveCurrent = current.voiceId == null
        ? current.copyWith(voiceId: catalog.defaultVoiceId)
        : current;
    final chosen = await TtsOptionsSheet.show(
      context,
      current: current,
      voices: catalog,
    );
    if (chosen == null || !mounted) return;
    if (chosen == effectiveCurrent) return;

    final waveformChanged = chosen.voiceId != effectiveCurrent.voiceId ||
        chosen.speed != effectiveCurrent.speed;
    if (waveformChanged && state.sentencesAfterCurrent > 0) {
      final measured = state.synthesisMs ?? ref.read(synthesisPriorsProvider);
      final expensive = measured != null && measured >= _slowSynthesisMs;
      if (expensive && !await _confirmDiscard(state, measured)) return;
      if (!mounted) return;
    }

    await ref.read(readAloudControllerProvider.notifier).setOptions(chosen);
    if (!mounted) return;
    _saveOptions(chosen);
  }

  /// Generates audio for the whole document, in the background.
  ///
  /// Announced with a confirmation because it is slow and it costs battery: a
  /// measured sentence on a mid-range phone costs ~15 s, so a 200-sentence
  /// document is closer to an hour of work. The notification makes it visible and
  /// stoppable, but the user still has to agree to start it.
  Future<void> _generateAllAudio() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo toàn bộ audio?'),
        content: const Text(
          'App sẽ tạo trước audio cho mọi câu của tài liệu.\n\n'
          'Việc này mất khá lâu và tốn pin, nhưng bạn có thể đóng app — '
          'tiến trình sẽ chạy tiếp và có thể dừng bất cứ lúc nào từ thông báo.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bắt đầu'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // The session's own options, not the runner's defaults: a run that
    // synthesized with `voiceId: null, speed: 1.0` writes cache keys the
    // reader — which reads with the document's voice and speed — will never
    // ask for, so the whole run would be invisible work.
    final options = ref.read(readAloudSessionProvider).options;
    final accepted = await ref.read(backgroundSynthesisProvider.notifier).start(
          documentId: _loadedDocumentId ?? 'composer',
          rawText: _text.text,
          options: options,
        );

    if (!accepted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang tạo audio cho tài liệu khác.')),
      );
    }
  }

  /// Confirms a voice/speed change when it would discard audio that has already
  /// been paid for, on a device where that audio is expensive.
  ///
  /// FR-10 is right that the change must re-synthesize the rest, and right that
  /// the current sentence keeps its audio. What it does not say is that the
  /// work is expensive: at the measured rate on a mid-range phone a single
  /// sentence costs 15 s, so silently discarding a page of prepared audio is a
  /// decision the user should be making.
  ///
  /// But only when there is something to tell them. Without a measurement the
  /// dialog would be a modal interruption warning about a cost nobody has
  /// established, so the change simply applies — and on a device fast enough to
  /// make a sentence in under [_slowSynthesisMs] the question is not worth
  /// asking at all.
  Future<bool> _confirmDiscard(ReadAloudState state, int measured) async {
    // The measured cost of **one** sentence, not `sentencesAfterCurrent ×` it.
    // Multiplying would assume every sentence costs what the slowest one seen so
    // far cost, and sentence cost tracks length — the total would be a made-up
    // number wearing the clothes of a measurement.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi giọng đọc?'),
        content: Text(
          '${state.sentencesAfterCurrent} câu phía sau sẽ được tạo lại với cài '
          'đặt mới. Câu đang đọc giữ nguyên; mỗi câu sau mất khoảng '
          '${_secondsLabel(measured)} trên máy này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đổi'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// FR-14 (text) and FR-15 (audio).
  ///
  /// Exports what the *user* typed — the controller still holds the original
  /// text, while the queue holds the normalized copy used for speech — and
  /// reports the real outcome, including a partial one.
  Future<void> _export(ReadAloudState state) async {
    final selection = await ExportSheet.show(context, sentences: state.sentences);
    if (selection == null || selection.isEmpty || !mounted) return;

    final formats = selection.formats.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    final outcome = await ref.read(exportServiceProvider).export(
          text: _text.text,
          sentences: state.sentences,
          directory: await ref.read(exportDirectoryProvider),
          formats: formats,
          includeAudio: selection.includeAudio,
          now: DateTime.now(),
        );

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          // A failure says which artifact and why; a success says where the
          // files are. Neither is a generic reassurance.
          outcome.failed.isEmpty
              ? outcome.summary
              : '${outcome.summary} ${outcome.failed.first.message}',
        ),
        // The path alone is not an outcome the user can act on: exports live in
        // app-private storage, which no file manager shows. Sharing is how the
        // file actually leaves the app, so it is offered here rather than left
        // as a step the user has to know about.
        action: outcome.written.isEmpty
            ? null
            : SnackBarAction(
                label: 'Chia sẻ',
                onPressed: () => unawaited(_share(outcome)),
              ),
      ),
    );
  }

  /// Hands the exported files to another app (FR-16).
  ///
  /// The failure is stated rather than swallowed: a share sheet that closes with
  /// nothing attached looks like the app failed silently, and on a device with
  /// no app registered for `.wav` that is exactly what happened.
  Future<void> _share(ExportOutcome outcome) async {
    try {
      await ref.read(shareTargetProvider).shareFiles(
            <String>[for (final artifact in outcome.written) artifact.path],
            title: outcome.written.length == 1
                ? outcome.written.first.label
                : 'Tài liệu đã xuất',
          );
    } catch (error) {
      AppLog.error('share.failed', error: error);
      // The share sheet spans a route, and the screen can be gone by the time
      // it closes — showing a snack on a disposed scaffold would throw inside
      // the very handler meant to report the failure.
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Không chia sẻ được: không có ứng dụng nào nhận loại tệp này.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Persists the reading position while it moves. `ref.listen` in build —
    // not a stream subscription in a controller — because only this screen
    // knows which document it is showing.
    ref.listen<ReadAloudState>(readAloudControllerProvider, (previous, next) {
      if (previous?.currentIndex == next.currentIndex) return;
      _schedulePositionSave(next);
    });

    final state = ref.watch(readAloudControllerProvider);
    final engine = ref.watch(ttsEngineProvider);
    final session = ref.read(readAloudSessionProvider);
    final controller = ref.read(readAloudControllerProvider.notifier);
    final background = ref.watch(backgroundSynthesisProvider);
    final backgroundController = ref.read(backgroundSynthesisProvider.notifier);
    final catalog = ref.watch(voiceCatalogProvider).value;
    // The voice lives in the AppBar so it is visible without opening the sheet,
    // and so a tap on the button opens the voice list (which is why the label
    // matches the transport bar's, not the speed-only button the bar used to
    // carry). It is non-null whenever the voice catalog is loaded.
    final voiceName = _voiceLabel(session.options.voiceId, catalog);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đọc thành tiếng'),
        actions: <Widget>[
          if (!state.isEmpty)
            IconButton(
              // Text edits while reading are blocked behind this explicit exit,
              // so the words and the audio cannot desync mid-sentence (FR-08).
              onPressed: _editText,
              tooltip: 'Sửa văn bản',
              icon: const Icon(Icons.edit_note_outlined),
            ),
          if (!state.isEmpty)
            IconButton(
              onPressed: () => _export(state),
              tooltip: 'Xuất tài liệu',
              icon: const Icon(Icons.file_download_outlined),
            ),
          if (!state.isEmpty)
            IconButton(
              // Generating everything up front is what lets reading start on
              // sentence one and lets Export Audio produce a complete file
              // (FR-15) instead of only the sentences read so far.
              onPressed: _hasText && engine.isReady && !background.running
                  ? _generateAllAudio
                  : null,
              tooltip: 'Tạo toàn bộ audio',
              icon: const Icon(Icons.library_music_outlined),
            ),
          Padding(
            padding: const EdgeInsets.only(right: Spacing.s8),
            child: TextButton(
              onPressed: _pickOptions,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // The active voice is named first: a speed-only label is what
                  // made the voice look unchangeable from the app bar. The whole
                  // row opens the options sheet, whose voice list is every voice
                  // the model ships with — so any of the many voices can be
                  // chosen here.
                  if (voiceName != null) ...<Widget>[
                    Flexible(
                      child: Text(
                        voiceName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: Spacing.s8),
                    Text('·', style: theme.textTheme.bodyMedium),
                    const SizedBox(width: Spacing.s8),
                  ],
                  Text(
                    speedLabel(session.options.speed),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (!engine.isReady) _ModelMissingBanner(modelName: engine.displayName),
            if (!state.isEmpty)
              _BackgroundSynthesisBanner(
                state: background,
                onStop: backgroundController.stop,
              ),
            Expanded(
              child: state.isEmpty
                  ? _buildComposer(
                      theme,
                      engineReady: engine.isReady,
                      loadFailure: _loadFailure,
                    )
                  : _buildReader(state, controller),
            ),
            if (state.failureMessage != null)
              _FailureBanner(
                index: state.failedSentenceIndex,
                message: state.failureMessage!,
                onRetry: controller.retryFailed,
                onDismiss: controller.dismissFailure,
              ),
            if (!state.isEmpty)
              _buildTransport(state, controller, session.options, catalog),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(
    ThemeData theme, {
    required bool engineReady,
    String? loadFailure,
  }) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _text,
              maxLines: null,
              expands: true,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              // Literata: the text being read is reading matter, not UI copy.
              style: theme.reading.copyWith(fontSize: TypeScale.bodyLarge),
              decoration: const InputDecoration(
                hintText: 'Nhập hoặc dán văn bản dài vào đây…',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                // Rebuild for the count line, and start the write clock: one
                // debounced save per pause, so typing never blocks on I/O.
                setState(() {});
                _scheduleDraftSave();
              },
            ),
          ),
          const SizedBox(height: Spacing.s12),
          if (_importing)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.s8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  LinearProgressIndicator(
                    value: _importProgress == 0 ? null : _importProgress,
                    minHeight: 2,
                  ),
                  const SizedBox(height: Spacing.s4),
                  Text(_importStage, style: theme.utility),
                ],
              ),
            ),
          Text(
            loadFailure ??
                (_hasText
                    ? 'Sẽ đọc $_sentenceCount câu. Bản nháp được tự lưu — thoát '
                        'ra rồi vào lại vẫn còn nguyên.'
                    : 'Chưa có văn bản để đọc.'),
            // A document that was opened but carried no words is a different
            // state from an empty composer, and colouring it as one hides the
            // reason the user is looking at.
            style: loadFailure != null
                ? theme.utility.copyWith(color: theme.semanticColors.danger)
                : theme.utility,
          ),
          const SizedBox(height: Spacing.s12),
          OutlinedButton.icon(
            // Images count as text too: a photo of a page is read on-device and
            // appended to the draft, so one long document can be typed *and*
            // photographed.
            onPressed: _importing ? null : _addFileToComposer,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(_importing ? 'Đang đọc tệp…' : 'Thêm ảnh hoặc tệp'),
          ),
          const SizedBox(height: Spacing.s8),
          FilledButton.icon(
            // Disabled while there is nothing to read, or while no engine can
            // read it: an enabled button that produces nothing is worse than no
            // button at all.
            onPressed: _hasText && engineReady ? _readComposed : null,
            icon: const Icon(Icons.play_arrow_outlined),
            label: const Text('Đọc thành tiếng'),
          ),
        ],
      ),
    );
  }

  Widget _buildReader(ReadAloudState state, ReadAloudController controller) {
    return Center(
      child: ConstrainedBox(
        // The reader column is capped, never full-bleed (DESIGN.md → Type):
        // 65–75 characters is what keeps Vietnamese diacritics readable.
        constraints: const BoxConstraints(maxWidth: Layout.readerMaxWidth),
        child: ReadingView(
          sentences: state.sentences,
          currentIndex: state.currentIndex,
          images: _imageSlots(state),
          onSentenceTap: controller.seekToSentence,
        ),
      ),
    );
  }

  /// Page images placed at their reading order (see [readingImageSlots]).
  List<ReadingImageSlot> _imageSlots(ReadAloudState state) {
    final data = _document;
    if (data == null) return const <ReadingImageSlot>[];
    return readingImageSlots(
      sentences: state.sentences,
      blocks: data.blocks,
      images: data.images,
      documentId: data.document.id,
    );
  }

  Widget _buildTransport(
    ReadAloudState state,
    ReadAloudController controller,
    TtsOptions options,
    VieNeuVoiceCatalog? catalog,
  ) {
    // While the current sentence has no audio yet, its clocks would both read
    // 0:00 — which looks broken. Say what is actually happening instead.
    final preparing = switch (state.current?.status) {
      SentenceStatus.synthesizing || SentenceStatus.queued => true,
      _ => false,
    };
    return TransportBar(
      ruler: SentenceRuler(
        sentences: state.sentences,
        currentIndex: state.currentIndex,
        positionInSentence: state.positionInSentence,
        onSeekToSentence: controller.seekToSentence,
      ),
      isPlaying: state.isPlaying,
      onPlayPause: controller.toggle,
      onPrevious: controller.previous,
      onNext: controller.next,
      onSpeedTap: _pickOptions,
      speedLabel: speedLabel(options.speed),
      // The voice the document is being read with, one tap from being changed —
      // mid-read, not buried in Settings. Tapping opens the same options sheet
      // as the speed chip, whose voice list is every voice in the catalog.
      onVoiceTap: _pickOptions,
      voiceLabel: _voiceLabel(options.voiceId, catalog),
      sentenceLabel: 'Câu ${state.currentIndex + 1}/${state.total}',
      // "known so far" rather than a final total: the document is still being
      // synthesized, and pretending to know the end would be a lie the user
      // catches the moment the number moves.
      timeLabel: preparing
          // Once a sentence has actually been measured, say how long this is
          // expected to take. A bare "Đang xử lý…" that sits for a quarter of a
          // minute is indistinguishable from a hang — measured on a phone, one
          // sentence took 15 s to make. The figure is the slowest sentence
          // measured so far, never a guess.
          ? _preparingLabel(state, priorMs: ref.watch(synthesisPriorsProvider))
          : '${durationLabel(state.elapsed)} / '
              '${durationLabel(state.knownDuration)}',
      canGoPrevious: state.currentIndex > 0,
      canGoNext: state.currentIndex + 1 < state.total,
    );
  }

  /// The transport bar's voice chip label: the voice's own name, or the
  /// catalog's default when the user never picked one.
  static String? _voiceLabel(String? voiceId, VieNeuVoiceCatalog? catalog) {
    if (catalog == null || catalog.isEmpty) return null;
    final voice = catalog.byId(voiceId) ??
        catalog.byId(catalog.defaultVoiceId) ??
        catalog.voices.first;
    return voice.label;
  }
}

/// Progress of a whole-document generation run.
///
/// Shown while it runs and kept afterwards when there is something to say — a
/// run that ended with failed sentences, or one the user stopped. A clean finish
/// shows nothing: the sentences that already had audio are the visible proof, and
/// a banner congratulating someone for a button press is noise.
class _BackgroundSynthesisBanner extends StatelessWidget {
  const _BackgroundSynthesisBanner({required this.state, required this.onStop});

  final BackgroundSynthesisState state;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = state.progress;

    final String label;
    if (state.running) {
      label = progress.total == 0
          ? 'Đang tạo audio…'
          : 'Đang tạo audio · ${progress.completed}/${progress.total} câu';
    } else if (state.message != null) {
      label = state.message!;
    } else {
      return const SizedBox.shrink();
    }

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.gutter,
          Spacing.s4,
          Spacing.s4,
          Spacing.s4,
        ),
        child: Row(
          children: <Widget>[
            if (state.running) ...<Widget>[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: Spacing.s4),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(label, style: theme.textTheme.bodyMedium),
                  if (progress.total > 0 && state.running)
                    Padding(
                      padding: const EdgeInsets.only(top: Spacing.s2),
                      child: LinearProgressIndicator(value: progress.fraction),
                    ),
                ],
              ),
            ),
            if (state.running)
              TextButton(onPressed: onStop, child: const Text('Dừng')),
          ],
        ),
      ),
    );
  }
}

/// "Model chưa cài" — the state the spec already specifies, with the *next*
/// action (`Install`, which lives in Models) rather than a dead button.
class _ModelMissingBanner extends StatelessWidget {
  const _ModelMissingBanner({required this.modelName});

  final String modelName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semanticColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.s16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: semantic.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, size: Spacing.s20, color: semantic.info),
          const SizedBox(width: Spacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(modelName, style: theme.textTheme.titleSmall),
                const SizedBox(height: Spacing.s2),
                // Privacy copy rule: this is the one step that needs the network,
                // and it says so (DESIGN.md → Voice).
                Text(
                  'Cần mạng để tải model. Tài liệu của bạn vẫn không rời khỏi máy.',
                  style: theme.utility,
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.s8),
          FilledButton(
            onPressed: () => context.go(RoutePaths.models),
            child: const Text('Mở Models'),
          ),
        ],
      ),
    );
  }
}

/// One failed sentence never blocks the rest, but it is stated plainly and
/// offers the action that fixes it — never a generic "Đã có lỗi xảy ra".
class _FailureBanner extends StatelessWidget {
  const _FailureBanner({
    required this.index,
    required this.message,
    required this.onRetry,
    required this.onDismiss,
  });

  final int? index;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semanticColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(Spacing.s16, Spacing.s8, Spacing.s8, Spacing.s8),
      color: theme.colorScheme.surfaceContainerHigh,
      child: Row(
        children: <Widget>[
          Icon(Icons.warning_amber_outlined, size: Spacing.s20, color: semantic.warning),
          const SizedBox(width: Spacing.s12),
          Expanded(
            child: Text(
              index == null ? message : 'Câu ${index! + 1}: $message',
              style: theme.utility.copyWith(color: theme.colorScheme.onSurface),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Đọc lại câu này')),
          IconButton(
            onPressed: onDismiss,
            tooltip: 'Bỏ qua thông báo',
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
