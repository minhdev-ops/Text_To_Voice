# Read-Aloud Enhancements — Design Spec

**Date**: 2026-10-06
**Status**: Implemented (2026-10-07) — see §10 for what shipped and where it deviated
**Scope**: Composer UX, image rendering in read-aloud, per-document TTS preferences, production polish

---

## 1. Overview

This spec covers four cohesive improvements to make the read-aloud experience production-ready for Play Store release:

1. **Enhanced Composer** — Auto-save, restore, character/word/sentence counts, virtualization for long texts
2. **Image Rendering in Read-Aloud** — Inline images at their document order with full-screen viewer
3. **Per-Document TTS Preferences + Voice Selector in Transport Bar** — Voice/speed/volume/format saved per document, accessible during reading
4. **Production Polish** — Accessibility, error recovery, performance tuning, offline-first validation

---

## 2. Enhanced Composer

### 2.1 Current State
- `ReadAloudScreen._text` is a `TextEditingController` with `maxLines: null, expands: true`
- Text lost when navigating away (no auto-save)
- No character/word/sentence count
- No virtualization — large texts may cause jank

### 2.2 Design

#### Auto-Save Controller
```dart
class AutoSaveController {
  final TextEditingController controller;
  final Duration debounce;
  final String storageKey; // 'composer_draft'
  
  AutoSaveController({required this.controller, this.debounce = const Duration(seconds: 2)});
  
  void initialize() {
    _restore();
    controller.addListener(_onChange);
  }
  
  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final draft = prefs.getString(storageKey);
    if (draft != null && draft != controller.text) {
      controller.text = draft;
    }
  }
  
  void _onChange() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, _save);
  }
  
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, controller.text);
  }
  
  void dispose() {
    controller.removeListener(_onChange);
    _debounceTimer?.cancel();
  }
}
```

#### Integration in `ReadAloudScreen`
- Initialize in `initState`, dispose in `dispose`
- Only active when `_loadedDocumentId == null` (composer mode)
- Restore happens before first build

#### Count Badge
- Add `_buildStatsBadge()` showing: `{chars} ký tự · {words} từ · {sentences} câu`
- Uses existing `SentenceSplitter` + `split(' ')` for words
- Updates on `onChanged` via `setState`

#### Virtualization (Optional, Phase 2)
- For texts > 5000 chars: wrap `TextField` in `RawScrollbar` + `SingleChildScrollView`
- Only if profiling shows jank; current `TextField` handles 10k+ chars adequately

### 2.3 Files Touched
- `lib/presentation/read_aloud/read_aloud_screen.dart` — add `AutoSaveController`, stats badge
- New: `lib/presentation/read_aloud/auto_save_controller.dart`

---

## 3. Image Rendering in Read-Aloud

### 3.1 Current State
- Camera capture produces `DocumentBlock(type: image)` + `DocumentImage`
- `ReadAloudScreen._buildReader` only renders `SentenceBlock` for text sentences
- Images exist in DB but never displayed

### 3.2 Design

#### Data Flow
```
DocumentWithData.blocks (includes BlockType.image)
    → ReadAloudController.read(text) 
    → SentenceSynthesisQueue.load() splits text into sentences
    → Need: parallel image blocks rendered alongside sentences
```

#### Option A: Inline in Sentence List (Recommended)
- Extend `ReadAloudState.sentences` to include `ImageSentence` subtype
- Or: render `ListView` with mixed `SentenceBlock` + `ImageBlock` items
- Use `DocumentBlock.order` for unified reading order

#### Option B: Separate Gallery Strip
- Top/bottom horizontal scroll of images
- Loses reading order context — rejected

#### Implementation: Mixed List View
```dart
// In ReadAloudScreen._buildReader
ListView.builder(
  itemCount: _displayItems.length, // sentences + images
  itemBuilder: (context, index) {
    final item = _displayItems[index];
    return switch (item) {
      SentenceDisplayItem(:final sentence) => SentenceBlock(...),
      ImageDisplayItem(:final block, :final image) => ImageBlock(block: block, image: image),
    };
  },
)
```

#### ImageBlock Widget
```dart
class ImageBlock extends StatelessWidget {
  final DocumentBlock block;
  final DocumentImage image;
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openFullScreen(context, image.filePath),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.s12, horizontal: Spacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (block.content.isNotEmpty) // OCR caption/alt-text
              Text(block.content, style: theme.utility),
            const SizedBox(height: Spacing.s8),
            ClipRRect(
              borderRadius: BorderRadius.circular(RadiusTokens.md),
              child: Image.file(
                File(image.filePath),
                width: double.infinity,
                fit: BoxFit.fitWidth,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

#### Full-Screen Viewer
- `Navigator.push` to `ImageViewerScreen` with `PhotoView` (pinch zoom, pan)
- Hero animation from thumbnail
- AppBar with close button, share action

#### Background Synthesis
- `BackgroundSynthesisRunner` already processes all sentences
- Add: for image blocks, synthesize `block.content` (OCR caption) as sentence
- If no caption, skip audio for that block (visual only)

### 3.3 Files Touched
- `lib/presentation/read_aloud/read_aloud_screen.dart` — `_buildReader` mixed list, `_displayItems` computation
- New: `lib/presentation/read_aloud/image_block.dart`
- New: `lib/presentation/read_aloud/image_viewer_screen.dart`
- `lib/domain/speech/background_synthesis_runner.dart` — handle image blocks
- Dependency: add `photo_view` to `pubspec.yaml`

---

## 4. Per-Document TTS Preferences + Voice Selector in Transport Bar

### 4.1 Current State
- `ReadingPosition` stores: `sentenceIndex`, `positionMs`, `pageNumber`, `blockId`
- Default TTS options from Settings (`defaultTtsOptionsProvider`)
- Voice selector only in Settings → Models tab
- Speed in transport bar via `SpeedSheet`
- Volume/format only in Settings

### 4.2 Design

#### Extended ReadingPosition
```dart
@immutable
class ReadingPosition {
  // ... existing fields
  final String? voiceId;
  final double? speed;
  final double? volume;
  final SpeechFormat? format;
  
  // copyWith extended
}
```

#### Database Migration
- Add columns to `reading_progress` table: `voice_id`, `speed`, `volume`, `format`
- Drift migration: `ALTER TABLE reading_progress ADD COLUMN voice_id TEXT; ...`

#### Repository Updates
```dart
// DocumentRepository
Future<void> saveReadingPosition(ReadingPosition position) // stores all fields
Future<ReadingPosition?> getReadingPosition(String documentId) // reads all fields
```

#### ReadAloudSession Integration
```dart
Future<void> read(String rawText, {TtsOptions? options}) async {
  // If options not provided, load from saved position
  final saved = await _repo.getReadingPosition(documentId);
  _options = options ?? saved?.toTtsOptions() ?? _defaultOptions;
  // ...
}

Future<void> setSpeed(double speed) async {
  // ... existing logic
  await _savePositionWithOptions(); // persist voice/speed/volume/format
}
```

#### TtsOptionsSheet (Replaces SpeedSheet)
```dart
class TtsOptionsSheet extends StatelessWidget {
  final TtsOptions current;
  final List<VoicePreset> availableVoices;
  
  // Sections: Speed (6 presets), Voice (list), Volume (slider), Format (WAV/MP3)
  // Returns TtsOptions? on confirm
}
```

#### Transport Bar Updates
- Add voice chip next to speed chip (condensed: shows voice label, tap opens sheet)
- `TtsOptionsSheet.show()` returns full `TtsOptions`
- `ReadAloudController` gets `setOptions(TtsOptions)` method

### 4.3 Files Touched
- `lib/domain/models/reading.dart` — extend `ReadingPosition`
- `lib/data/database/app_database.dart` — add columns, migration
- `lib/data/database/database_daos.dart` — update DAOs
- `lib/data/repository/document_repository.dart` — update save/load
- `lib/domain/speech/read_aloud_session.dart` — load/save options
- `lib/presentation/read_aloud/read_aloud_providers.dart` — pass repo to session
- `lib/presentation/read_aloud/speed_sheet.dart` → rename to `tts_options_sheet.dart`, extend
- `lib/presentation/read_aloud/transport_bar.dart` — add voice chip
- `lib/presentation/read_aloud/read_aloud_screen.dart` — wire new sheet

---

## 5. Production Polish

### 5.1 Accessibility
| Component | Requirement |
|-----------|-------------|
| Transport bar | `Semantics` labels on all buttons, `Shortcuts` for Space/Enter |
| SentenceBlock | `selected` on current, `hint` for tap-to-seek |
| ImageBlock | `image` role, `label` = caption or "Hình ảnh trang X" |
| TtsOptionsSheet | `RadioListTile` semantics, focus order |
| Composer | `TextField` already accessible; add live region for count updates |

#### Reduce Motion
- `SentenceBlock` spine animation: respect `MediaQuery.maybeDisableAnimationsOf`
- `TransportBar` ruler: no animation on seek
- `BackgroundSynthesisBanner` progress: instant updates when reduced

### 5.2 Error Recovery
#### Failed Sentence Retry with Backoff
```dart
// In SentenceSynthesisQueue._synthesize
int _retryCount = 0;
static const maxRetries = 3;
static const baseDelay = Duration(seconds: 2);

Future<Result<AudioResult>> _synthesizeWithRetry(int index, int generation) async {
  for (int attempt = 0; attempt <= maxRetries; attempt++) {
    final result = await _engine.synthesize(...);
    if (result is Success) return result;
    if (attempt < maxRetries) {
      await Future.delayed(baseDelay * (1 << attempt)); // 2s, 4s, 8s
      if (generation != _generation) return CancelledFailure();
    }
  }
  return Failure(...);
}
```

#### Network-Free Synthesis Guard
- `TtsEngine.isReady` already checks model installed
- Add: `SynthesisPlatform` check before background synthesis start
- Show "Cần mô hình TTS" banner if not ready (already exists)

### 5.3 Performance Tuning
- `ListView.builder` in `_buildReader`: add `cacheExtent: 500` (pre-render 2-3 screens)
- `SentenceSynthesisQueue.lookAhead: 2` — keep (validated)
- Background synthesis: process in batches of 10, yield via `Future.microtask`
- Image loading: `Image.file` with `cacheWidth`/`cacheHeight` for thumbnails

### 5.4 Offline-First Validation
- Models tab: show download progress, pause/resume, cancel
- Read-aloud: if model missing, disable "Đọc thành tiếng" with clear message
- Export: WAV works offline; MP3 disabled with reason (already implemented)

### 5.5 Files Touched
- Multiple files for accessibility semantics
- `lib/domain/speech/sentence_synthesis_queue.dart` — retry logic
- `lib/presentation/read_aloud/background_synthesis_controller.dart` — batch yielding
- `lib/presentation/models/models_screen.dart` — download progress UI

---

## 6. Migration & Compatibility

| Change | Migration Strategy |
|--------|-------------------|
| `ReadingPosition` new fields | Nullable columns, default to null; `toTtsOptions()` falls back to defaults |
| Image blocks in read-aloud | No migration needed — blocks already stored |
| Composer auto-save | `SharedPreferences` key `composer_draft` — no conflict |
| TtsOptionsSheet | Replaces `SpeedSheet` — same call sites, extended return type |

---

## 7. Testing Strategy

| Feature | Unit Tests | Widget Tests | Integration Tests |
|---------|------------|--------------|-------------------|
| Auto-save | `AutoSaveController` debounce/restore | Composer restores draft | — |
| Image rendering | — | `ImageBlock` tap → viewer | Camera → capture → read-aloud shows image |
| Per-doc TTS prefs | `ReadingPosition` copyWith | Transport bar voice chip | Read doc A (voice 1), doc B (voice 2), return to A → voice 1 |
| Retry backoff | `SentenceSynthesisQueue` retry count | Failed sentence banner | Network disconnect during synthesis |
| Accessibility | — | Semantics tree audit | TalkBack walkthrough |

---

## 8. Open Questions (Resolved in Design)

1. **Image rendering**: Inline at document order (Option A) — approved
2. **Voice selector**: Merge into `TtsOptionsSheet` replacing `SpeedSheet` — approved
3. **Composer auto-save**: `SharedPreferences` (not DB document) — approved
4. **Export images**: Out of scope for this round — deferred

---

## 9. Acceptance Criteria

- [x] Composer restores draft after app kill/restart (`settings` key `composer_draft`)
- [x] Composer shows live sentence count (a count, never an invented duration)
- [x] Read-aloud displays images inline at correct reading order
- [x] Tapping image opens full-screen zoomable viewer (`InteractiveViewer`)
- [x] Voice/speed/volume saved per document (`settings` key `tts_options:<documentId>`)
- [x] Transport bar shows voice chip; tapping opens `TtsOptionsSheet`
- [x] Switching documents restores each document's voice settings
- [x] Failed sentence retries up to 3× with exponential backoff (2 s/4 s/8 s)
- [x] Reduce-motion disables the spine and auto-scroll animation
- [x] No regression in existing library/capture/settings flows (571 tests green)
- [x] Captured documents and their page images are persisted (see §10.1)

---

## 10. Implementation notes (2026-10-07)

### 10.1 The compose→capture→read path was broken, not just unfinished

The spec assumed captured documents were already in the database. They were not:
`CaptureController.keep()` wrote a `KeptDocument` into the session-scoped
`keptDocumentsProvider` and nothing ever wrote a `documents` row, a block or a
page image. Consequences the user hit directly:

* a captured document never appeared in the Library and was gone on restart;
* `document_images` was never written by anyone, so inline images had no data;
* `ReadAloudScreen` loads from the repository, so it could never open a capture.

Fixed by `KeptDocumentSink` (`RepositoryKeptDocumentSink`): page bytes are
written to `documents/<id>/pages/page-N.png`, `document_images` rows are created,
and one transaction writes the document with its blocks. `keep()` stays
synchronous (the review screen and its tests use the id immediately) and exposes
`persisting` so the review screen can hold navigation until the write lands — and
stay put with an honest error if it fails.

### 10.2 Deviations from the draft

| Draft | Shipped | Why |
|-------|---------|-----|
| `AutoSaveController` class | Debounced write inside the screen | One key, one timer; a class would have been a second owner of the same state |
| `ReadingPosition` gains 4 columns + Drift migration | `settings` key `tts_options:<documentId>` | The `settings` table is already the app's KV store; no migration, no codegen, and a corrupt entry degrades to defaults |
| Sentence list with `ImageBlock` items | **Continuous paragraphs** with per-sentence tap targets | The user's report: the text must read as one long document, not a stack of sentence rows |
| `photo_view` dependency | `InteractiveViewer` (SDK) | Pinch/pan/double-tap is all the viewer needs; every dependency must earn its bytes in the store listing |
| Voice selector in a merged sheet | Shipped as designed | — |
| Character/word counts | Sentence count only | Counts that a person can act on; a word count adds nothing read-aloud needs |

### 10.3 Continuous reading surface

`ReadingView` renders the document as prose: sentences of a paragraph flow
together, each keeps its own tap target and semantics label, the current one
carries the accent wash (the Listening Spine, inline), played sentences mute, and
a failed sentence keeps its place with a warning underline. Paragraph structure
is first-class in the model (`Sentence.paragraph`, computed by
`SentenceSplitter.splitByParagraph`), and `Sentence.displayText` keeps the user's
own words on screen while `Sentence.text` stays the normalized spoken form — so
`50%` is shown as `50%` and read as "năm mươi phần trăm".

### 10.4 Bugs found and fixed during the review pass

* Library row taps in **History** and **Favorites** had empty `onTap` handlers —
  tapping a document did nothing.
* The **theme choice was session-only**: pick "Tối", reopen, and the app was back
  on "Theo hệ thống". Now persisted (`settings` key `theme_mode`).
* The **reading position stopped being saved** as soon as the route lost its
  `documentId` (a tab tap), and `Tiếp tục` on an already-loaded document was
  ignored because the screen returned early on the same id.
* **Android release builds had no `INTERNET` permission**: Flutter adds it to
  debug builds only, so model download (FR-20) would have failed in the store
  build alone.
* The background-synthesis **notification permission was never requested**, so on
  API 33+ a long run was invisible and unstoppable.

---

## 11. Play Store readiness (CH Play)

| Item | State |
|------|-------|
| `INTERNET` permission declared | ✅ added — without it release builds cannot download the model |
| `applicationId` no longer `com.example.*` | ✅ `vn.vietdoc.ai` (**cannot change after first release**) |
| Foreground service + `FOREGROUND_SERVICE_DATA_SYNC` | ✅ already declared |
| `POST_NOTIFICATIONS` requested at runtime | ✅ via `SynthesisService` bridge (`requestNotifications`) |
| Offline-first, no analytics/crash reporting | ✅ by construction (NFR-02) |
| `versionName` / `versionCode` | ✅ `1.0.0+1` in `pubspec.yaml` |
| **Release signing** | ⚠️ still `signingConfigs.getByName("debug")` — a keystore and `key.properties` must be added before uploading |
| **Launcher icon** | ⚠️ still the Flutter default (`@mipmap/ic_launcher`) — needs real icon assets |
| **R8 keep rules** | ⚠️ only worth trusting after a release build runs the engine end-to-end on a device (`flutter_onnxruntime` + ML Kit) |
| Play Console requirements | Data-safety form, privacy policy URL, content rating, target API level |
| Background audio playback (lock screen) | Out of scope: needs `audio_service`. Reading position now survives the app being closed; playback itself does not continue when the process is killed |