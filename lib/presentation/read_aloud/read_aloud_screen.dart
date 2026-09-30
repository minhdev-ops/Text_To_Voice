import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/semantic_colors.dart';
import '../../core/theme/tokens.dart';
import '../../data/providers.dart';
import '../../domain/models/reading.dart';
import '../../domain/models/tts.dart' show TtsOptions;
import '../../domain/speech/read_aloud_session.dart' show ReadAloudState;
import '../../domain/text/sentence_splitter.dart';
import '../common/duration_label.dart';
import 'export_sheet.dart';
import 'read_aloud_providers.dart';
import 'sentence_block.dart';
import 'sentence_ruler.dart';
import 'speed_sheet.dart';
import 'transport_bar.dart';

/// Second destination: the direct text → speech path (SRS §39 Flow 1, FR-09).
///
/// The surface changes shape with the state instead of showing everything at
/// once: a composer while there is nothing to read, a measured reading column
/// with the Listening Spine while reading, and the sticky transport bar inside
/// it. There is deliberately no separate full-screen player — audio controls
/// live with the words they control.
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

  /// Why the surface is blank when a document carried no text. Null otherwise.
  String? _loadFailure;

  /// The router's location source, once this screen is under a router.
  ///
  /// Listening to it — rather than reading the route in `build` or
  /// `didChangeDependencies` — is what makes a *second* document load. Both of
  /// those were tried and neither fires: this tab sits in a
  /// `StatefulShellRoute.indexedStack`, so it is not rebuilt when another tab
  /// navigates it, and `InheritedGoRouter` is the same widget instance for the
  /// app's whole life, so it never triggers a dependency change either. The
  /// screen silently kept showing the first document forever.
  RouteInformationProvider? _locations;

  @override
  void dispose() {
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

  /// Subscribes to the router's location the first time this screen is under
  /// one, and loads whatever document the route names.
  ///
  /// A listener rather than a read in `build`, because this tab is kept alive by
  /// an `indexedStack`: nothing rebuilds it when another tab navigates it to a
  /// different document, and `InheritedGoRouter` never changes either, so no
  /// framework callback fires at all. Without this the screen silently kept
  /// showing the first document the app ever opened.
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
    final documentId = uri?.queryParameters['documentId'];
    if (documentId == _loadedDocumentId) return;

    _loadedDocumentId = documentId;
    _resume = uri?.queryParameters['resume'] == 'true';
    if (documentId == null) return;

    // Deferred: this can be reached from a dependency phase, and loading is
    // async I/O that must not run mid-frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadDocument(documentId);
    });
  }

  Future<void> _loadDocument(String documentId) async {
    final repo = ref.read(documentRepositoryProvider);
    final doc = await repo.getDocumentWithData(documentId);
    if (!mounted) return;
    if (doc == null) return;

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
    if (!mounted) return;

    final controller = ref.read(readAloudControllerProvider.notifier);
    // `read` is awaited rather than raced with a timer: the seek below needs the
    // queue loaded, and a fixed delay is a guess about how long that takes.
    await controller.read(text);
    if (!mounted) return;

    if (_resume) {
      final position = await repo.getReadingPosition(documentId);
      if (!mounted) return;
      if (position != null) {
        await controller.seekToSentence(position.sentenceIndex);
        if (!mounted) return;
      }
    }
    setState(() => _loadFailure = null);
  }

  /// A measured sentence cost below this is not worth interrupting the user over.
  ///
  /// One threshold, two uses: the progress label and the speed-change warning
  /// both ask the same question — *is this device slow enough that waiting is
  /// something the user should be told about?* — and they must answer it the
  /// same way, or the app contradicts itself between the label and the dialog.
  ///
  /// Three seconds rather than one because a second is not long enough to read a
  /// sentence aloud; a number below it is noise wearing a decimal point.
  static const int _slowSynthesisMs = 3000;

  /// The "still preparing" label, with a measured expectation once there is one.
  static String _preparingLabel(ReadAloudState state) {
    final measured = state.synthesisMs;
    if (measured == null || measured < _slowSynthesisMs) return 'Đang xử lý…';
    return 'Đang xử lý… ~${_secondsLabel(measured)}';
  }

  /// A whole number of seconds, rounded up, because a promise of "0 giây" while
  /// work is in flight is worse than no promise at all.
  static String _secondsLabel(int milliseconds) =>
      '${(milliseconds / 1000).ceil()} giây';

  /// Confirms a speed change when it would discard audio that has already been
  /// paid for, on a device where that audio is expensive.
  ///
  /// FR-10 is right that a speed change must re-synthesize the rest, and right
  /// that the current sentence keeps its audio. What it does not say is that the
  /// work is expensive: at the measured rate on a mid-range phone a single
  /// sentence costs 15 s, so silently discarding a page of prepared audio is a
  /// decision the user should be making.
  ///
  /// But only when there is something to tell them. Without a measurement the
  /// dialog would be a modal interruption warning about a cost nobody has
  /// established, so the speed simply changes — and on a device fast enough to
  /// make a sentence in under [_slowSynthesisMs] the question is not worth
  /// asking at all.
  Future<void> _pickSpeed() async {
    final controller = ref.read(readAloudControllerProvider.notifier);
    final options = ref.read(readAloudSessionProvider).options;
    final state = ref.read(readAloudControllerProvider);
    final chosen = await SpeedSheet.show(context, current: options.speed);
    if (chosen == null || chosen == options.speed || !mounted) return;

    final measured = state.synthesisMs;
    final expensive = measured != null && measured >= _slowSynthesisMs;
    if (expensive && state.sentencesAfterCurrent > 0) {
      if (!await _confirmDiscard(state, measured)) return;
    }
    await controller.setSpeed(chosen);
  }

  Future<bool> _confirmDiscard(ReadAloudState state, int measured) async {
    // The measured cost of **one** sentence, not `sentencesAfterCurrent ×` it.
    // Multiplying would assume every sentence costs what the slowest one seen so
    // far cost, and sentence cost tracks length — the total would be a made-up
    // number wearing the clothes of a measurement.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi tốc độ?'),
        content: Text(
          '${state.sentencesAfterCurrent} câu phía sau sẽ được tạo lại với tốc '
          'độ mới. Câu đang đọc giữ nguyên; mỗi câu sau mất khoảng '
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
    if (selection == null || selection.isEmpty) return;

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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(readAloudControllerProvider);
    final engine = ref.watch(ttsEngineProvider);
    final session = ref.read(readAloudSessionProvider);
    final controller = ref.read(readAloudControllerProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đọc thành tiếng'),
        actions: <Widget>[
          if (!state.isEmpty)
            IconButton(
              // Text edits while reading are blocked behind this explicit exit,
              // so the words and the audio cannot desync mid-sentence (FR-08).
              onPressed: controller.editText,
              tooltip: 'Sửa văn bản',
              icon: const Icon(Icons.edit_note_outlined),
            ),
          if (!state.isEmpty)
            IconButton(
              onPressed: () => _export(state),
              tooltip: 'Xuất tài liệu',
              icon: const Icon(Icons.file_download_outlined),
            ),
          Padding(
            padding: const EdgeInsets.only(right: Spacing.s8),
            child: TextButton(
              onPressed: _pickSpeed,
              child: Text(speedLabel(session.options.speed)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (!engine.isReady) _ModelMissingBanner(modelName: engine.displayName),
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
            if (!state.isEmpty) _buildTransport(state, controller, session.options),
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
                hintText: 'Nhập hoặc dán văn bản vào đây…',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: Spacing.s12),
          Text(
            loadFailure ??
                (_hasText
                    ? 'Sẽ đọc $_sentenceCount câu, theo từng câu một.'
                    : 'Chưa có văn bản để đọc.'),
            // A document that was opened but carried no words is a different
            // state from an empty composer, and colouring it as one hides the
            // reason the user is looking at.
            style: loadFailure != null
                ? theme.utility.copyWith(color: theme.semanticColors.danger)
                : theme.utility,
          ),
          const SizedBox(height: Spacing.s12),
          FilledButton.icon(
            // Disabled while there is nothing to read, or while no engine can
            // read it: an enabled button that produces nothing is worse than no
            // button at all.
            onPressed: _hasText && engineReady
                ? () => ref.read(readAloudControllerProvider.notifier).read(_text.text)
                : null,
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
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: Spacing.s16),
          itemCount: state.sentences.length,
          itemBuilder: (context, index) {
            final sentence = state.sentences[index];
            return SentenceBlock(
              sentence: sentence,
              isCurrent: index == state.currentIndex,
              onTap: () => controller.seekToSentence(index),
              onRetry: sentence.status == SentenceStatus.failed
                  ? controller.retryFailed
                  : null,
            );
          },
        ),
      ),
    );
  }

  Widget _buildTransport(
    ReadAloudState state,
    ReadAloudController controller,
    TtsOptions options,
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
      onSpeedTap: _pickSpeed,
      speedLabel: speedLabel(options.speed),
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
          ? _preparingLabel(state)
          : '${durationLabel(state.elapsed)} / '
              '${durationLabel(state.knownDuration)}',
      canGoPrevious: state.currentIndex > 0,
      canGoNext: state.currentIndex + 1 < state.total,
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