# Feature Spec — Offline AI Document Reader + Vietnamese TTS (VietDoc AI)

Binds to `.ulpi/design/DESIGN.md` (LOCKED). **Every screen must read as the same product if placed
side by side.** Any visual value not in `DESIGN.md` is a defect.

Source requirements: `document/SRS.txt` (FR-01 … FR-20, NFR-01 … NFR-05).

---

## 1. Information architecture

Four top-level destinations (≤ 5, satisfies cognitive-load rule). Material 3 `NavigationBar`, labels
always visible, Material Symbols outlined.

| # | Destination | Purpose |
|---|-------------|---------|
| 1 | **Library** | documents, search, import entry |
| 2 | **Read aloud** | text-only quick path: paste text → speak |
| 3 | **Models** | model inventory, install/delete, storage |
| 4 | **Settings** | TTS defaults, low-memory mode, language, storage, about/privacy |

Everything else (reader, player, OCR review, extraction results, export) is a pushed route or a
bottom sheet over one of these four. No fifth tab.

**Reader and the sticky player are the same surface.** Per the SRS, "read" and "listen" are not two
apps: the reader shows the document column and the Listening Spine, and the transport bar is a sticky
bottom bar inside the reader. There is no separate full-screen "TTS Player" screen that hides the
text — audio controls live with the words they control.

---

## 2. Flow: Library & Import (FR-01, FR-02, FR-18)

**Goal:** get a document into the app and see it in the library.
**Trigger:** app launch, or `Import` from the Library.
**Entry points:** app cold start (Library), FAB/secondary button, share-sheet intent (Android
`ACTION_VIEW` / `ACTION_SEND` for supported MIME types), "Import" empty state.

```
Library (cold start)
   │
   ▼
◇ Library empty?
   ├── yes ──▶ Empty state: "Library" + Import / Paste text
   └── no  ──▶ Ruled list of documents (name, type glyph, size · age)
                  │
                  ├─ tap row ─────▶ Reader (F4/F6)
                  ├─ long-press ──▶ selection bar: Rename · Favorite · Export · Delete
                  └─ Import ──────▶ Android SAF picker (multi-select allowed)
                                        │
                                        ▼
                                   File validation (MIME + extension + size + integrity)
                                        │
                              ┌─────────┴──────────┐
                          rejected              accepted
                              │                    │
                              ▼                    ▼
                    Inline row error        Create document row, status = QUEUED
                    "Unsupported: .exe"            │
                                                   ▼
                                            Processing queue (F5)
```

**Steps**

1. **Import tap** → system Storage Access Framework. Allowed: `pdf`, `txt`, `md`, `epub`, `jpg`,
   `jpeg`, `png`, `webp`. Multi-select allowed.
2. **Validation** → MIME type is checked against the actual bytes, not just the extension. Size cap
   is configurable; oversized files are rejected with the actual size shown. Files are never executed,
   never moved out of app-private storage unless the user exports.
3. **Enqueue** → a row appears immediately with `QUEUED`, so the user is never left on a spinner.
   Processing continues on a background isolate; the app may be closed and the queue resumes.
4. **Processing list** (instrument strip, not cards): one ruled row per job with a determinate
   progress line and a status word (`Analyzing` → `Extracting` → `Running OCR` → `Done`).

**States**

| State | Presentation |
|-------|--------------|
| Loading | Ruled rows with a 1px single-pass shimmer on the name line only; never a centered spinner over the whole list |
| Empty | `EmptyState`: Literata headline `Library`, plain body line, primary `Import` + secondary `Paste text` |
| Partial | Rows render as soon as known; unknown metadata shows `—` not `0` |
| Success | Row status becomes `Done`; on-device chip is shown once per document ("On this device") |
| Error | Row keeps `border` but gains a `danger` status word + explanation line ("Có mật khẩu (password-protected)") and a `Retry` text button; one failing row never blocks the others |
| Offline | Fully functional; the only offline-blocked action is model download, which says so |

**Edge cases:** duplicate import (detect by content hash, offer "Open existing" / "Import anyway");
zero-byte file; file whose provider revokes the URI (Surface `Re-import needed`); import while queue
is running; import cancelled mid-picker (no row created); storage nearly full (`warning` banner,
offers low-memory mode).

---

## 3. Flow: Text → Speech (FR-09, FR-10, FR-15; the Phase-1 MVP)

**Goal:** hear Vietnamese speech from typed text, fully offline.
**Entry:** Read-aloud tab, or reader overflow → "Read aloud".

```
Read aloud
   │
   ▼
Text field (Literata, ≥ 16sp) ── paste / select existing document
   │
   ▼
◇ Toolbar: Voice ▾ · Speed ▾
   │
   ▼
[ Read aloud ]
   │
   ▼
Text normalization → sentence split → per-sentence synthesis queue
   │
   ▼
Sentence ruler appears; first sentence plays as soon as its audio is ready
(words are NOT pre-rendered as one file — SRS FR-12)
```

**System response**
- The first sentence starts playing as soon as its audio buffer exists; the rest synthesize ahead in
  the background. The ruler shows ticks for sentences not yet ready as "pending" (hollow) ticks.
- Changing Speed or Voice invalidates the queue from the current sentence forward and re-synthesizes
  from there; already-played sentences are kept.
- Text edits while reading are blocked behind an explicit `Apply` so audio and text cannot desync.

**States:** empty text (button disabled + hint), over-long text (soft cap with "will read N sentences"),
synthesis failure on a sentence (that sentence is marked `danger`, playback skips it and continues,
banner offers `Retry sentence`), model not installed (route to Models, with `Install` primary).

---

## 4. Flow: Image → OCR → Text → Speech (FR-03, FR-04)

```
Camera / Gallery
     │
     ▼
Capture → crop → perspective correction → enhancement (grayscale, contrast, deskew, denoise)
     │            (each step skippable; "Original" always retrievable)
     ▼
OCR (Vietnamese + English, Unicode, diacritics preserved)
     │
     ▼
OCR Review: image left, text right (two-pane at expanded, stacked with a drag divider at compact)
     │  · tap a text line → corresponding region is outlined on the image
     │  · low-confidence lines are underlined with a `warning` hairline, not a colored block
     ▼
[ Keep text ] ──▶ Document created (source = CAMERA / IMPORTED)
     │
     ▼
Reader (spine + transport) → Read aloud
```

**Camera scanning** supports auto-detection of the document quad, manual corner drag, rotate,
grayscale, contrast, and rotation/orientation lock. Multi-page capture is allowed and produces one
document with N pages, one OCR pass per page.

**States:** no camera permission (explain why, `Open settings`, plus `Choose file` fallback);
nothing detected in the frame (guide line, no error toast); partially legible page (OCR still
returns text, low-confidence lines flagged, banner: "N dòng cần kiểm tra"); OCR engine missing
(model not installed) — the image is still saved and the document is marked `Text pending`.

---

## 5. Flow: PDF → Text → Speech (FR-05, FR-07)

```
Import PDF → Analyze
   │
   ▼
◇ Has extractable text layer? (sample first N pages)
   ├── yes ──▶ text parser   → structured blocks
   └── no  ──▶ render page → image → OCR (per page, streaming, page released after use)
   │
   ▼
Structured document (titles, headings, paragraphs, lists, tables, images, footnotes)
   │
   ▼
Reader → Read aloud
```

The **mixed** case is handled per page, not per document: a PDF whose page 1 has a text layer and
page 9 is a scan uses the parser for 1 and OCR for 9. The UI reports this honestly:
`12 trang có text · 3 trang chạy OCR`.

Reading order matters for TTS: blocks are ordered by the detected reading order, and
footnote/header/footer blocks are tagged so they can be skipped (default: skipped during Read aloud,
visible in the reader).

**States:** encrypted PDF (password prompt, clear failure if wrong); malformed PDF (row-level error,
original preserved); very large PDF (page-at-a-time, never whole-file in memory, progress by page);
PDF with no extractable content (offer "Render pages and OCR everything", showing estimated time).

---

## 6. Flow: Document extraction — images, pages, structure (FR-06, FR-16)

```
Document → Extract All
   │
   ▼
Instrument strip: Text · Images · Pages · Metadata · Structure  (counts, tabular)
   │
   ▼
Tabs (instrument strip header): each tab is a ruled list, not a card grid
   │  Images: thumbnail, page number, W×H, format, size, [Save] [Share]
   │  Pages:  rendered page thumbnails + "OCR this page"
   │  Structure: the block outline (heading levels) — the same tree the reader uses
   │
   ▼
[ Export package ] → document.json + text.txt + pages/ + images/
```

**States:** no images found (state this plainly; don't show an empty grid); extraction of a page
fails (page marked failed, others continue); partial package export (list which artifacts succeeded).

---

## 7. Flow: Read aloud a document + resume (FR-11, FR-13)

```
Reader
   │
   ▼
◇ Saved reading position exists?
   ├── yes ──▶ ResumeStrip (only card in the product, radius lg):
   │            "Đang đọc: trang 17, đoạn 4"   [ Continue ]  [ Start over ]
   └── no  ──▶ top of document
   │
   ▼
Reader column + Listening Spine + sticky TransportBar
   │
   ├─ tap any sentence ──▶ playback restarts from that sentence
   ├─ tap a sentence with the spine active ──▶ play/pause that sentence
   └─ sentence ends ──▶ spine advances with one 240ms emphasis transition (motivated motion)
```

Position persisted as `document_id · page · block_id · sentence_index · position_ms`, written on
pause, on sentence change, and on app background (not every frame).

**TransportBar** (sticky, `sheet` elevation, safe-area aware): play/pause (48dp+), previous/next
sentence, speed chip (`1.0×`, `full` radius — the only pill), voice name, elapsed/total in tabular
numerals, and the **SentenceRuler** scrubber. Seeking snaps to sentence boundaries by default; a long
press enables free scrub within the sentence.

**States:** synthesis ahead of playback (ruler ticks fill in as they become ready); backgrounded app
continues audio via a media session with a notification (Android `Media3`) carrying document title +
transport controls; audio focus lost (phone call) pauses and resumes after; Bluetooth route change
does not restart the sentence; "Continue reading?" answered with `Start over` clears the saved position.

---

## 8. Flow: Model Manager (FR-20)

```
Models
   │
   ▼
Instrument strip: Installed · Available · Storage used (tabular)
   │
   ▼
Ruled list of models: name, size, status word (Installed / Not installed / Verifying), checksum
   │
   ├─ Install ──▶ network required → explicit "Cần mạng để tải model" + progress + [ Cancel ]
   ├─ Verify  ──▶ checksum + checksum of tokenizer assets; failure → status `Corrupt` + [ Re-download ]
   └─ Delete  ──▶ confirm dialog naming exact size freed; if it is the active model, warn TTS stops
```

**Honesty rule (from `DESIGN.md` voice section):** the offline claim is scoped. The app is offline
for documents, OCR, and TTS; it needs the network only to fetch model files, and the UI says exactly
that. A model row shows the exact license string for that checkpoint (SRS note 47), so a commercial
release decision can be made from inside the app.

---

## 9. Flow: Export & Search (FR-14, FR-15, FR-17)

**Export:** text (`txt` / `md` / `json`), audio (`wav` first; `mp3` only if an on-device encoder is
present, otherwise offer `wav` and say why), extraction package (zip). Export audio of a long document
warns with the estimated size computed from the actual sentence durations.

**Search:** one search field over documents, pages, blocks, and (optionally) extracted images by
filename. Results are a ruled list grouped by document, each hit showing page number and an excerpt
with the matched term marked by the accent rule (not a yellow highlighter). Empty query → recent
searches; no results → plain statement + suggestion to widen scope.

---

## 10. Component specs

All components bind to `DESIGN.md`. Props are given in Dart-flavored form for the implementing agent.

### 10.1 `LibraryRow`

**Purpose:** one document in the ruled library list.
**Variants:** `default`, `selected` (long-press selection), `processing`, `failed`.
**Props:** `name`, `typeGlyph` (PDF/TXT/EPUB/IMG), `sizeLabel`, `ageLabel`, `status`, `progress`,
`isFavorite`, `onTap`, `onLongPress`, `onOverflow`.
**States:** default (square row, hairline separator, type glyph leading, metadata trailing in
`utility`) · pressed (surface → `elevated`) · selected (2dp `accent` left rule + `accent-wash`) ·
processing (determinate 2dp progress line under the name; status word replaces the age label) ·
failed (`danger` status word + explanation line) · disabled (no such state — rows are always actionable).
**a11y:** one `Semantics` node per row; label = `"{name}, {type}, {size}, {status}"`; the overflow
button is a separate focusable node, min 48dp; selection announced via `Semantics(selected: true)`.
**Edge:** long names wrap to 2 lines then ellipsize; missing thumbnail → type glyph, never a broken image.

### 10.2 `ProcessingStrip`

**Purpose:** compact, honest status for background work (import, parse, OCR, synthesis).
**Type:** instrument strip. One row per job, each a label + determinate progress + status word + cancel.
**States:** queued (`info` word) · running (accent progress) · done (removed after 2s, no toast spam) ·
failed (persists with explanation + retry) · cancelled (row removed).
**a11y:** container is a polite live region; announces only on state *change*, not on every progress tick.

### 10.3 `ReaderColumn` + `SentenceBlock`

**Purpose:** the measure-constrained reading surface with the Listening Spine.
**Props (column):** `blocks`, `currentBlockId`, `currentSentenceIndex`, `onSentenceTap`, `showFootnotes`.
**Props (block):** `blockType` (TITLE/HEADING/PARAGRAPH/IMAGE/TABLE/LIST/FOOTNOTE), `text`, `level`,
`confidence`, `pageNumber`.
**Sentence state machine (one sentence):** `idle → queued → synthesizing → ready → playing → played`,
plus `failed`. Visual: `queued/ready` = plain text; `synthesizing` = 1px `text-subtle` underline that
grows; `playing` = the Spine (3px `accent` left rule + `accent-wash`); `played` = `text-muted`;
`failed` = `danger` hairline underline + `Retry sentence` affordance.
**Accessibility:** sentence is a real focusable node in reading order; the played sentence announces
"Đang đọc" once on entry; text scales to at least 200% without clipping (line-height already ≥ 1.65);
`Semantics(label: sentenceText, hint: "Nhấn để đọc từ câu này")`.

### 10.4 `SentenceRuler` (scrubber)

**Purpose:** the signature scrubber — a hairline baseline with one tick per sentence.
**Props:** `sentences` (ready | pending | failed), `currentIndex`, `positionInSentence`, `onSeekToSentence`.
**States:** all pending (hairline, hollow ticks, play disabled until first ready) · playing (`accent`
inks the played span, current tick is taller) · failed ticks shown in `danger` hue as a dashed tick ·
dragging (free scrub within the current sentence only).
**a11y:** exposed as a seek bar (`Semantics(slider)`) with value = `"Câu {n}/{total}, {elapsed} trên {total}"`;
supports `increase`/`decrease` to move by sentence; ticks are not separately focusable (they'd flood
the a11y tree).

### 10.5 `TransportBar`

Sticky bottom bar. `sheet` elevation, 48dp+ targets, tabular numerals for time. Order: previous
sentence · play/pause · next sentence · speed chip · voice · elapsed/total. Play/pause is the single
most prominent control. Full keyboard/D-pad path: focus enters at play/pause, arrow keys move within
the bar, `Space` toggles.

### 10.6 `SpeedChip` / `SpeedSheet`

Values exactly `0.5 / 0.75 / 1.0 / 1.25 / 1.5 / 2.0` (SRS FR-10). Chip shows `1.0×` in tabular
numerals; sheet is a ruled list of the six values with a check on the active one. Changing speed
shows the effect immediately on the next sentence; it does not restart the current sentence
mid-word.

### 10.7 `OcrReviewPane`

Two-pane at `expanded` (image | text), stacked with a draggable divider at `compact`. Tap a text line
→ outline the source region on the image with a 2px `accent` stroke (not an opaque block). Low
confidence → `warning` hairline underline. Actions: `Keep text`, `Re-scan`, `Copy`, `Edit`.

### 10.8 `ExtractResultPanel`

Instrument strip: `Text · Images · Pages · Structure` counts with tabular numerals; tabs open ruled
lists. Never an empty decorative grid.

### 10.9 `ModelRow`

Ruled row: name, size, status word, license string, actions (`Install` / `Verify` / `Delete`).
Status is always expressed as **word + shape**, never a bare colored dot. Install progress is a
determinate line; cancel is always available.

### 10.10 `StatusChip`

The one shared way to express system state anywhere in the app. **Word + shape**, tinted by semantic
role: `Done`/`Installed` (success) · `Reading`/`Processing` (accent) · `Queued` (info) ·
`Needs review`/`Low storage` (warning) · `Failed`/`Corrupt` (danger). Shape distinguishes states
without color, so it survives color-blindness and grayscale.

### 10.11 `EmptyState` / `ErrorBanner` / `ResumeStrip`

- `EmptyState`: Literata headline + one plain body line + at most one primary and one secondary action.
- `ErrorBanner`: inline, dismissible, states the actual cause and the actual next action; never a
  generic "Something went wrong".
- `ResumeStrip`: the product's only card (`lg` radius), used solely for "Continue reading?".

---

## 11. Accessibility contract (non-negotiable)

- Every text/UI color pair comes from the ratios in `DESIGN.md` and passes WCAG AA. `text-subtle`
  is decorative only.
- Touch targets ≥ 48dp. Reader and TransportBar respect safe areas and call `MediaQuery.textScaler`
  up to 200% without clipping.
- Full non-gesture path exists for: opening a document, starting/stopping read-aloud, moving by
  sentence, changing speed, switching voice, importing, installing/deleting a model.
- The Listening Spine is never the *only* signal: the current sentence is also announced to the
  screen reader and shown in the TransportBar (`Câu 12/240`). Color is never load-bearing.
- Reduced motion: spine advance and sheet entry collapse to cuts; no motion is required to understand
  state.
- Vietnamese diacritics must render in every string, including file names and OCR output; a widget
  test asserts diacritic integrity through the text pipeline.

---

## 12. Build handoff

- **Target agent:** `flutter-engineer` (Flutter/Dart, Android-first).
- **design_system:** `Material 3 (Flutter)`. Theme it with the locked tokens in `DESIGN.md`.
  **Do NOT use `ColorScheme.fromSeed`; do NOT redesign or re-implement Material components.**
  Author the literal `ColorScheme` + a `ThemeExtension` for `success/warning/info/accentWash/spineRule`.
- **State management:** as chosen in `document/ROADMAP.md` Phase 0 (one mechanism only, project-wide).
- **Delivery order:** implement strictly by phase in `document/ROADMAP.md`. Phase 1 is the only
  phase with no document/DB dependency and must ship Text → Vietnamese speech first.
- **First build step:** import this spec, then build `DESIGN.md` as `lib/core/theme/`
  (tokens + light/dark `ColorScheme` + `ThemeExtension`) plus the widget test that asserts the locked
  hex values, before any feature screen.

**Acceptance criteria**

- [ ] All four destinations use only locked tokens; a theme test asserts the hex values.
- [ ] Listening Spine and SentenceRuler behave identically everywhere playback exists.
- [ ] Every component above has its loading / empty / error states implemented, not just the happy path.
- [ ] Every flow's edge cases in this document are reachable and handled.
- [ ] Sentence-level synthesis works: audio starts on sentence 1 before the document finishes
      synthesizing, and seeking snaps to sentence boundaries.
- [ ] Reading position survives process death and offers "Continue reading?".
- [ ] A11y: 48dp targets, 200% text scaling without clipping, non-gesture path for every core action,
      reduced-motion honored.
- [ ] The app functions with Wi-Fi and mobile data off for every flow except model download, and the
      UI never claims otherwise.

---

## 13. Design Pre-Flight (Step 6) — result

Run against the checklist in the skill's `references/design-preflight.md`.

**Identity lock**
- [x] Every screen/component uses only `DESIGN.md` values; off-system values: 0.
- [x] One accent (verdigris), one radius scale, one icon family (Material Symbols outlined), one type pairing.
- [x] Identity-lock sentence written verbatim at the top of this spec and at the top of `DESIGN.md`.
- [x] Single-feature spec; `DESIGN.md` is the re-read artifact for later sessions.

**Anti-slop**
- [x] 0 banned fonts (Literata + Be Vietnam Pro; no Inter/Roboto/Arial/Playfair/Fraunces/Space Grotesk as primary).
- [x] 0 banned color clichés: no purple/blue glow, no cream/sand/beige default paper, no gradient text,
      no acid-green or vermilion on near-black.
- [x] 0 banned layout patterns: no 3-equal-cards, no nested cards, no eyebrow numbering decoration, no
      centered-dark hero, no glassmorphism, no decorative status dots, no pill scrubber.
- [x] 0 buzzwords, 0 fake names, 0 fake-precise numbers, 0 em-dashes in visible copy. (Note: the
      em-dash ban is enforced on **visible product copy**; this internal spec uses them as prose punctuation.)
- [x] Slop test passes: the verdigris/verdigris-paper direction and the Listening Spine are not the
      generic "AI app" read.
- [x] Counterfactual test passed: this is not the answer I'd produce for an unrelated product brief.
- [x] Signature present (Listening Spine + SentenceRuler) and it embodies the brief (where-am-I-while-listening).
- [x] No inspiration links were used, so no clone risk; synthesis noted in `DESIGN.md`.

**State & flow coverage**
- [x] Every interactive element specs loading / empty / error, not just happy path.
- [x] Edge cases covered: refresh/process-death resume, revoked URI, encrypted PDF, permission denial,
      offline model download, audio-focus loss, concurrent queue, partially failed export.

**Accessibility**
- [x] Contrast ratios listed per token and passing AA; `text-subtle` restricted to decoration.
- [x] Visible keyboard/D-pad path documented per component; SentenceRuler exposes a seek semantics.
- [x] Reduced motion handled; motion inventory limited to 3 motivated cases.
- [x] Semantics specified for LibraryRow, ProcessingStrip live region, SentenceBlock, SentenceRuler,
      ModelRow, StatusChip.
- [x] Touch targets ≥ 48dp; safe areas respected; 200% text scaling verified as a criterion.

**Layout craft**
- [x] 4 distinct layout families (ruled list, editorial column, instrument strip, full-bleed sheet);
      they repeat as families by function, not one decorative block everywhere.
- [x] Clear hierarchy; one focal point per view; whitespace deliberate (4px rhythm).

**Cognitive load**
- [x] Primary nav = 4 top-level items (≤ 5). Search options ≤ 4. Speed choices = 6 in a sheet, not inline.
- [x] Exactly one primary action per view; secondary actions subordinate.

**Scored self-critique (0–4, max 32)**

| axis | score | note |
|------|-------|------|
| distinctiveness | 4 | verdigris-on-tinted-paper + Listening Spine is specific to a reading instrument |
| hierarchy & focus | 3 | reader focal point clear; Models list is inherently flat |
| consistency with `DESIGN.md` | 4 | every component binds to named tokens only |
| accessibility | 3 | strong on targets/contrast/motion; free-scrub gesture needs a documented non-gesture equivalent |
| state/edge coverage | 4 | process-death resume and mixed PDF/OCR pages are both covered |
| copy quality | 3 | voice defined and consistent; Vietnamese/English mixing needs a string audit in Phase 0 |
| restraint | 4 | one accent, one card, one pill; shadows limited to sheet + sticky bar |
| motion motivation | 3 | 3 motivated cases; needs an assertion that no stray animation ships |

**Total: 28 / 32.** No axis scored ≤ 2, so no revise-and-justify cycle was triggered.

Three items were tightened during this gate rather than left as byproducts:
1. **Added** `accent-ink` and explicit `on-accent` tokens — the first draft used `accent` for both
   fills and text, which risked failing 4.5:1 for accent text on `bg`. Why: contrast must be a token
   decision, not a per-screen guess.
2. **Replaced** the initially assumed "three equal feature cards" for the destination overview with a
   4-row table. Why: it was the exact banned pattern, and the content is a list, not a showcase.
3. **Removed** any plan for a separate full-screen TTS Player. Why: splitting text from audio controls
   contradicts the product's core claim and duplicated state; the transport now lives in the reader.

A fourth correction was made **during the Phase 0 build** (revise-and-justify):
4. **Re-measured every contrast ratio with the real WCAG formula and fixed three wrong numbers.** The
   draft claimed `border` at 3.1:1 (measured **1.24:1**) and `text-subtle` at 2.9:1 (**2.52:1**), and
   listed light `warning` as `#B4791A` at 4.5:1 (**3.44:1 — a genuine AA failure**). Changes: light
   `warning` is now `#9A6612` (**4.58:1**), interactive outlines are bound to `text-muted` instead of
   `border`, and `text-subtle`/`border` are recorded as decorative-only. Why: the gate requires ratios
   to be *listed*, and an estimated ratio that fails is worse than no ratio at all. The measurement is
   now an automated test (`test/core/theme/app_theme_test.dart`), so this class of error cannot recur.
