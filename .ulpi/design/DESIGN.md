---
project: VietDoc AI — Offline AI Document & Vietnamese TTS Reader
register: product
aesthetic_direction: editorial / magazine
color_strategy: restrained
design_system: Material 3 (Flutter)
design_variance: 5
motion_intensity: 3
visual_density: 6
platform: Flutter (Android-first)
locked: true
---

# Design Language — VietDoc AI (LOCKED)

> **Identity lock:** Every screen must read as the same product if placed side by side.

This file is the single source of truth. Any value used anywhere that is not in this file is a defect.
Re-read this file before specifying any new screen or feature.

---

## Design Read

**An instrument for reading, not a toy.** The product's whole value is trust: your document never
leaves the phone, and the app tells you the truth about what it did with it. So the interface is
built like a printed journal with a machined control surface beside it — quiet, paper-like reading
area; hard-edged, legible instrument panel for processing, progress, and playback.

**The bet:** most on-device-AI apps reach for dark surfaces with a violet glow and rounded glass
cards to signal "AI". We go the other way. A light, ink-on-tint reading surface with one verdigris
accent, ruled lines instead of floating cards, and a signature vertical "listening spine" that marks
the sentence being spoken. It says *document tool*, not *chatbot*.

## Counterfactual default test (passed)

The default answer for "offline AI document + TTS reader" is: dark mode default, purple→blue gradient
accent, Inter/Roboto, rounded 16–24px cards everywhere, centered hero, and a pill-shaped audio
scrubber. We produce none of those. Palette, type, layout family and signature are all derived from
the subject (Vietnamese long-form text read aloud) and would not be the same answer for a different brief.

## Signature

**The Listening Spine.** In the reader, the sentence currently being synthesized/played is marked by:

1. a 3px verdigris vertical rule in the left margin, and
2. a very low-chroma verdigris wash behind the sentence (≤ 8% alpha).

It is the single memorable element, and it is functional: it is how a user answers "where am I in this
document?" while listening. Everything around it stays quiet — one accent, no second highlight color,
no glow, no rounded highlight blob. Per the "remove one accessory" rule, boldness is spent here only.

Corollary: the audio scrubber is **not** a rounded pill. It renders as a **sentence ruler** — a 1px
hairline baseline with one tick per sentence, the played portion inked in accent, the current tick
taller. This is the same idea as the Spine in horizontal form, so the two read as one system.

## Inspiration

No reference links were supplied for this brief, so no external DNA was imported. The direction is
derived from the subject: Vietnamese typography (diacritic-heavy, needs generous line-height), the
physical act of reading long documents, and the "instrument/utility" register implied by an offline,
CPU-only, privacy-first tool. Nothing in this file is cloned from a reference, and no anti-slop ban
is inherited.

---

## Color (locked)

Derived from the subject: ink on tinted paper, with **verdigris** (aged copper-green, the color of
ink-stamped document seals) as the single accent. Neutrals carry a faint green-cyan tint
(chroma +0.006 to +0.020 at hue 175–195) so nothing reads as a pure generic gray.

### Light (default)

| role | hex | use | WCAG vs `bg` |
|------|-----|-----|--------------|
| `bg` | `#F4F8F6` | app background, reader backdrop | — |
| `surface` | `#FBFDFC` | list rows, sheets, panels | — |
| `elevated` | `#FFFFFF` | focused row, popover, active input | — |
| `text` | `#22302E` | body copy, headings | **12.81:1** ✅ |
| `text-muted` | `#5E6D6B` | secondary copy, metadata, and **interactive outlines** | **5.06:1** ✅ |
| `text-subtle` | `#94A09D` | timestamps, disabled, hints | **2.52:1** ⚠️ decorative only |
| `border` | `#D8E2DE` | hairlines and dividers only | **1.24:1** ⚠️ decorative only |
| `accent` | `#1F7A6B` | primary action, Spine rule, active tick | **4.84:1** ✅ · 5.18:1 on `elevated` |
| `accent-ink` | `#12564B` | accent when read as text on light | **7.97:1** ✅ |
| `on-accent` | `#FFFFFF` | text/icon on accent fills | **5.18:1** on `accent` ✅ |
| `accent-wash` | `#141F7A6B` (8%) | Listening Spine sentence wash | — |
| `success` | `#2E7D4F` | model installed, import complete | **4.71:1** ✅ |
| `warning` | `#9A6612` | low storage, low-memory mode | **4.58:1** ✅ |
| `danger` | `#B03A3A` | delete, failed processing | **5.58:1** ✅ |
| `info` | `#2F6E9E` | queued, processing hints | **5.10:1** ✅ |

### Dark (re-derived, not inverted — tint and contrast preserved)

| role | hex | use | WCAG vs `bg` |
|------|-----|-----|--------------|
| `bg` | `#131B1A` | app background | — |
| `surface` | `#1B2422` | rows, sheets, panels | — |
| `elevated` | `#232E2B` | focused row, popover | — |
| `text` | `#E4EDEA` | body copy | **14.67:1** ✅ |
| `text-muted` | `#A3B2AF` | secondary copy, interactive outlines | **7.96:1** ✅ |
| `text-subtle` | `#77857F` | decorative only | **4.54:1** (passes, but still restricted) |
| `border` | `#2C3835` | hairlines and dividers only | **1.44:1** ⚠️ decorative only |
| `accent` | `#59C4AE` | primary action, Spine rule | **8.28:1** ✅ · 6.63:1 on `elevated` |
| `on-accent` | `#131B1A` | text/icon on accent fills | **8.28:1** on `accent` ✅ |
| `accent-wash` | `#1F59C4AE` (12%) | Listening Spine sentence wash | — |
| `success` | `#6FC08C` | installed | **8.00:1** ✅ |
| `warning` | `#D9A94E` | warnings | **8.12:1** ✅ |
| `danger` | `#E2807C` | delete | **6.35:1** ✅ |
| `info` | `#7FB8DE` | queued | **8.18:1** ✅ |

**Distribution (60-30-10):** 60% `bg`/paper reading surface · 30% `surface`/`border` structure and text ·
10% `accent` (Spine, primary action, active tick). No second accent. No gradients anywhere except the
import-progress fill, which is a flat accent fill at reduced alpha.

**WCAG (measured, not estimated).** Every ratio above is computed by
`test/core/theme/app_theme_test.dart` with the real WCAG 2.1 formula and asserted at its threshold,
so the table cannot rot. Two rules follow from the numbers:

1. `text-subtle` and `border` are **decorative only**. Neither may carry meaning: `border` at 1.24:1
   is a divider, never an interactive boundary.
2. Interactive outlines (input borders, button edges) use `text-muted`, not `border` — that is what
   clears the 3:1 WCAG 1.4.11 component threshold.

**hex is the normative value.** The OKLCH figures from the derivation step were approximate and have
been dropped rather than left as a second, subtly wrong source of truth; the hex values above are what
the implementation must use, and the test enforces them.

---

## Type (locked)

Paired on the **serif + sans** contrast axis, and both chosen because they carry **full Vietnamese
diacritic support** (a hard requirement — this is a Vietnamese-first reading app). No Reflex defaults
(Inter / Roboto / Arial / Space Grotesk / Playfair / Fraunces) are used as the primary face.

| role | family | use | notes |
|------|--------|-----|-------|
| `display` | **Literata** (serif) | screen titles, document headings, reader body | designed for long-form reading; Vietnamese subset; measure 65–75ch in the reader; line-height ≥ 1.65 for diacritic stacking |
| `body` | **Be Vietnam Pro** (humanist/geometric sans) | UI copy, list rows, buttons, forms | drawn for Vietnamese; replaces the Inter/Roboto reflex |
| `utility` | **Be Vietnam Pro** (Medium, +0.01em tracking, tabular numerals) | timestamps, durations, file sizes, page numbers, model stats | tabular figures mandatory so durations do not jitter during playback |

**Scale (modular, product-tight):** `11 / 12 / 14 / 16 / 18 / 22 / 28 / 36` sp.
Reader body is 18sp; UI body is 14–16sp; screen title 22sp; the player's document title 28sp.

**Craft:** headings use `text-wrap: balance` equivalent (Dart: soft-wrap at word boundaries via
`TextWidthBasis`); display letter-spacing floor −0.02em at ≥ 28sp; body never exceeds ~72ch in the
reader (the reader column is capped, not full-bleed on tablets).

---

## Scales (locked)

**Spacing** (4px rhythm): `2 / 4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 / 48 / 64`. No other steps.

**Radius** — one scale, deliberately tight (this is a paper-and-instrument product, not a bubble app):
`sm 2 · md 4 · lg 8 · full 999`.
Sheets and dialogs take `lg`; list rows are **square** (radius 0) because they are ruled rows, not cards;
buttons take `sm`; only the speed chip and circular play button use `full`. **Cards are not used in this
product** except the single "Continue reading?" resume strip, which takes `lg`.

**Elevation** — hairline-first. `border` provides separation; shadows are reserved for the bottom sheet,
dialog, and the sticky player bar only. Two levels: `sheet` (soft, low-opacity) and `sticky`.
No shadow on list rows, no nested elevation.

**Motion** — durations `fast 120ms · base 240ms · emphasis 400ms`; one easing curve
`cubic-bezier(0.2, 0, 0, 1)` (Android `FastOutSlowIn`-adjacent). **No bounce, no elastic.**
Exit ≈ 75% of enter. Honor `MediaQuery.disableAnimations` / reduced-motion: all non-essential motion
collapses to a 0ms cut. Motion is motivated only as: (a) the Spine advancing to the next sentence,
(b) a processing row changing state, (c) the sheet entering. Everything else is instant.

**Touch targets:** ≥ 48dp everywhere (Android), including transport buttons and list row overflow.
Safe areas respected on all reader/player screens.

**Breakpoints (Flutter):** `compact < 600` (phone portrait) · `medium 600–839` (phone landscape,
foldable) · `expanded ≥ 840` (tablet). Two-pane (library \| reader) starts at `expanded`.

---

## Layout families (locked variety)

Long surfaces must not repeat one block. The product uses four distinct families:

1. **Ruled list** (Library, Search results, Model list) — full-width rows separated by 1px `border`
   hairlines, no card chrome, leading type glyph, trailing metadata in `utility`.
2. **Measure-constrained editorial column** (Reader) — capped column with generous leading, headings as
   numbered section rules, Listening Spine in the left margin, images as full-column blocks with
   captions in `utility`.
3. **Instrument strip** (Processing queue, Model Manager stats, Extraction results) — horizontal stat
   strip / table-first, tabular numerals, status as text + shape (never a bare colored dot).
4. **Full-bleed sheet** (TTS Player, Import, OCR review) — bottom sheet at `lg` radius, content aligned
   to the same measure as the reader.

**Banned in this project:** three equal feature cards in a row; nested cards; centered hero over a
dark mesh; glassmorphism; decorative status dots; eyebrow numbering (`01 / 02`) as decoration;
pill-shaped audio scrubbers; purple/blue gradients.

---

## Voice

- **register:** plain, technical, calm. Speaks like a careful instrument, not a marketing page
  and not a chatbot. Prefers naming the format and the state ("PDF has no text layer — running OCR")
  over reassurance ("Hang tight!").
- **language:** Vietnamese-first UI strings, English technical terms only when they are the real term
  (`OCR`, `PDF`, `ONNX`, `WAV`).
- **action vocabulary (locked, consistent through each flow):**
  `Import` → `Imported` · `Extract` → `Extracted` · `Scan` → `Scanned` · `Read aloud` → `Reading` ·
  `Install` (model) → `Installed` · `Export` → `Exported`.
  A button and its resulting toast/status use the same stem — never "Generate" as a button and
  "Created" as its result.
- **banned copy:** elevate, unleash, seamless, next-gen, transformative, revolutionize, powerful
  solution; fake names (Acme, NovaCore...); fake-precise numbers; the em-dash as a stylistic crutch.
- **privacy copy rule:** any statement about data staying on-device must be literally true at that
  point in the flow. If a step needs the network (model download), the UI says so explicitly and does
  not claim offline for that step.

---

## Material 3 mapping (build contract)

- `ColorScheme.fromSeed` is **not** used. The locked palette is authored as a literal
  `ColorScheme` (light + dark) so Material 3's generated tonal palette cannot drift the accent.
- Token name mapping: `bg → surface` · `surface → surfaceContainerLow` · `elevated →
  surfaceContainerHigh` · `text → onSurface` · `text-muted → onSurfaceVariant` **and** `outline`
  (it is what clears the 3:1 interactive-boundary threshold) · `border → outlineVariant` (dividers
  only) · `accent → primary` · `on-accent → onPrimary` · semantic states → `error` plus
  project-level extension tokens (`success`, `warning`, `info`, `accentWash`, `spineRule`).
- Component overrides: `ListTile` shape → square, `Card` → `outlined` (or not used),
  `Slider` theme → 2dp track, no thumb halo beyond focus ring, `FilledButton` radius `sm`,
  `BottomSheet` radius `lg` + drag handle 32×4dp.
- Validation: an early widget test asserts the resolved `ThemeData` contains the locked hex values,
  so a refactor cannot silently change the identity.

---

## Success criteria for this file

- One accent, one radius scale, one icon family (Material Symbols, outlined), one type pairing,
  one copy register, across every screen.
- No screen introduces a value outside this file. Variation happens in composition, never in identity.
- The Listening Spine and the sentence ruler are present and identical in behavior everywhere playback
  exists.
