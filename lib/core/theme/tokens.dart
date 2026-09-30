/// Design tokens — the single source of truth for every visual value in the app.
///
/// Derived from and locked by `.ulpi/design/DESIGN.md`. Nothing in the UI may
/// introduce a value that is not here; screens vary in composition, never in
/// palette, type, radius or motion.
library;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Color
// ---------------------------------------------------------------------------

/// Named color roles. Light and dark are **separate derivations** — dark is not
/// an inversion of light, it is re-derived with the same tint and guarantees.
///
/// Contrast figures are the measured WCAG 2.1 ratios against [background] of
/// the same palette, used by `test/core/theme/app_theme_test.dart` as the guard
/// that keeps this table honest. "Decorative" means the role is restricted to
/// non-text, non-UI-boundary use and is never load-bearing on its own.
@immutable
class AppPalette {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.elevated,
    required this.text,
    required this.textMuted,
    required this.textSubtle,
    required this.border,
    required this.accent,
    required this.accentInk,
    required this.onAccent,
    required this.accentWash,
    required this.spineRule,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  /// App background and the reading surface. 60% of visual weight.
  final Color background;

  /// List rows, sheets, panels.
  final Color surface;

  /// Focused row, popover, active input. 30% of visual weight with text/border.
  final Color elevated;

  /// Body copy and headings. **12.8:1** on [background] (light) / 14.7:1 (dark).
  final Color text;

  /// Secondary copy and metadata. **5.0:1** (light) / 8.0:1 (dark).
  final Color textMuted;

  /// Timestamps, disabled, hints. **Decorative only** — 2.5:1 (light) is below
  /// 4.5:1, so it must never carry meaning a user has to read.
  final Color textSubtle;

  /// Hairlines and list dividers. **Decorative only** — 1.2:1 (light) / 1.4:1
  /// (dark). Interactive input/button outlines use [textMuted] instead, which
  /// clears the 3:1 UI-component threshold.
  final Color border;

  /// The single accent: primary action, active scrubber tick. **4.8:1** (light)
  /// / 8.3:1 (dark).
  final Color accent;

  /// Accent when it has to be *read as text* on a light surface. **8.0:1**.
  final Color accentInk;

  /// Foreground on top of [accent] fills. **5.2:1** (light) / 8.3:1 (dark).
  final Color onAccent;

  /// [accent] at 8% alpha (light) / 12% (dark) — the Listening Spine sentence
  /// wash. Never used as a stand-alone background.
  final Color accentWash;

  /// The 3px Listening Spine rule. Equals [accent]; named separately so the
  /// signature element is traceable in code and in review.
  final Color spineRule;

  /// Model installed, import complete. **4.7:1** (light) / 8.0:1 (dark).
  final Color success;

  /// Low storage, low-memory mode. **4.6:1** (light) / 8.1:1 (dark).
  final Color warning;

  /// Delete, failed processing. **5.6:1** (light) / 6.3:1 (dark).
  final Color danger;

  /// Queued, processing hints. **5.1:1** (light) / 8.2:1 (dark).
  final Color info;

  // -- Light ---------------------------------------------------------------

  /// Ink on tinted paper: a faint green-cyan cast, never pure gray.
  static const AppPalette light = AppPalette(
    background: Color(0xFFF4F8F6),
    surface: Color(0xFFFBFDFC),
    elevated: Color(0xFFFFFFFF),
    text: Color(0xFF22302E),
    textMuted: Color(0xFF5E6D6B),
    textSubtle: Color(0xFF94A09D),
    border: Color(0xFFD8E2DE),
    accent: Color(0xFF1F7A6B),
    accentInk: Color(0xFF12564B),
    onAccent: Color(0xFFFFFFFF),
    accentWash: Color(0x141F7A6B),
    spineRule: Color(0xFF1F7A6B),
    success: Color(0xFF2E7D4F),
    warning: Color(0xFF9A6612),
    danger: Color(0xFFB03A3A),
    info: Color(0xFF2F6E9E),
  );

  // -- Dark ----------------------------------------------------------------

  /// Re-derived, not inverted: same tint direction, contrast guarantees kept.
  static const AppPalette dark = AppPalette(
    background: Color(0xFF131B1A),
    surface: Color(0xFF1B2422),
    elevated: Color(0xFF232E2B),
    text: Color(0xFFE4EDEA),
    textMuted: Color(0xFFA3B2AF),
    textSubtle: Color(0xFF77857F),
    border: Color(0xFF2C3835),
    accent: Color(0xFF59C4AE),
    accentInk: Color(0xFF59C4AE),
    onAccent: Color(0xFF131B1A),
    accentWash: Color(0x1F59C4AE),
    spineRule: Color(0xFF59C4AE),
    success: Color(0xFF6FC08C),
    warning: Color(0xFFD9A94E),
    danger: Color(0xFFE2807C),
    info: Color(0xFF7FB8DE),
  );

  static AppPalette of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

// ---------------------------------------------------------------------------
// Spacing — one 4px rhythm. No other steps are permitted.
// ---------------------------------------------------------------------------

abstract final class Spacing {
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;
  static const double s64 = 64;

  /// Page gutter. The reader column is capped, so it uses [s16]–[s24], not
  /// [s48], to keep the 65–72ch measure on a phone.
  static const double gutter = s20;
}

// ---------------------------------------------------------------------------
// Radius — one scale. Tight on purpose: this is paper-and-instrument, not bubbles.
// ---------------------------------------------------------------------------

abstract final class RadiusTokens {
  /// Buttons, chips that are not pills.
  static const double sm = 2;

  /// Sheets' inner controls, dialogs' fields.
  static const double md = 4;

  /// Bottom sheets, dialogs, and the single ResumeStrip card.
  static const double lg = 8;

  /// Circular play button and the speed chip only.
  static const double full = 9999;

  static const BorderRadius smBorder = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdBorder = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgBorder = BorderRadius.all(Radius.circular(lg));

  /// Top-only rounding for bottom sheets.
  static const BorderRadius sheetBorder = BorderRadius.only(
    topLeft: Radius.circular(lg),
    topRight: Radius.circular(lg),
  );

  /// List rows are square — they are ruled rows, not cards.
  static const BorderRadius row = BorderRadius.zero;
}

// ---------------------------------------------------------------------------
// Motion — motivated only. Three cases are allowed to animate:
// the Spine advancing, a processing row changing state, a sheet entering.
// ---------------------------------------------------------------------------

abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 240);
  static const Duration emphasis = Duration(milliseconds: 400);

  /// The one easing curve for the project. No bounce, no elastic.
  static const Curve standard = Cubic(0.2, 0, 0, 1);

  /// Exit durations run at ~75% of enter.
  static const Duration exit = Duration(milliseconds: 180);
}

// ---------------------------------------------------------------------------
// Type scale — modular and product-tight.
// ---------------------------------------------------------------------------

abstract final class TypeScale {
  static const double caption = 11;
  static const double label = 12;
  static const double body = 14;
  static const double bodyLarge = 16;
  static const double reading = 18;
  static const double title = 22;
  static const double headline = 28;
  static const double display = 36;
}

// ---------------------------------------------------------------------------
// Families — chosen for Vietnamese diacritic coverage.
// ---------------------------------------------------------------------------

abstract final class FontFamilies {
  /// Reading surface and screen titles. Deliberately not a reflex default.
  static const String display = 'Literata';

  /// UI copy, labels, buttons. Deliberately not Inter/Roboto.
  static const String body = 'BeVietnamPro';
}

// ---------------------------------------------------------------------------
// Structure
// ---------------------------------------------------------------------------

abstract final class Layout {
  /// Android touch target floor (Android Material guidance).
  static const double minTouchTarget = 48;

  /// Body measure ceiling in the reader — never full-bleed on a wide screen.
  static const double readerMaxWidth = 720;

  /// Breakpoints (Flutter `Breakpoints`).
  static const double compactMax = 599;
  static const double mediumMax = 839;
}
