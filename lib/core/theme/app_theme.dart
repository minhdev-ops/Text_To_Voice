import 'package:flutter/material.dart';

import 'semantic_colors.dart';
import 'tokens.dart';

/// Builds the two [ThemeData] instances for the project.
///
/// Two rules this file exists to enforce:
///
/// 1. **No `ColorScheme.fromSeed`.** Material's tonal generator would re-derive
///    our accent into a family of purple-ish tonal steps and silently break the
///    locked palette. Every role is written out literally below.
/// 2. **One radius, one accent, one icon family, one type pairing.** Components
///    are themed through Material 3's own hooks — we theme them, we never
///    re-implement them.
abstract final class AppTheme {
  // -------------------------------------------------------------------------
  // ColorScheme
  // -------------------------------------------------------------------------

  static ColorScheme colorScheme(AppPalette p, Brightness brightness) {
    return ColorScheme(
      brightness: brightness,

      // One accent. Material's secondary/tertiary are deliberately the same
      // hue — a second accent would break DESIGN.md's 60-30-10.
      primary: p.accent,
      onPrimary: p.onAccent,
      primaryContainer: p.accent,
      onPrimaryContainer: p.onAccent,
      primaryFixed: p.accent,
      primaryFixedDim: p.accentInk,
      onPrimaryFixed: p.onAccent,
      onPrimaryFixedVariant: p.onAccent,

      secondary: p.accent,
      onSecondary: p.onAccent,
      secondaryContainer: p.surface,
      onSecondaryContainer: p.text,
      secondaryFixed: p.accent,
      secondaryFixedDim: p.accentInk,
      onSecondaryFixed: p.onAccent,
      onSecondaryFixedVariant: p.onAccent,

      tertiary: p.accent,
      onTertiary: p.onAccent,
      tertiaryContainer: p.surface,
      onTertiaryContainer: p.text,
      tertiaryFixed: p.accent,
      tertiaryFixedDim: p.accentInk,
      onTertiaryFixed: p.onAccent,
      onTertiaryFixedVariant: p.onAccent,

      error: p.danger,
      onError: p.onAccent,
      errorContainer: p.danger,
      onErrorContainer: p.onAccent,

      // Surfaces: bg is the reading surface, elevated is the focused one.
      surface: p.background,
      onSurface: p.text,
      surfaceDim: p.background,
      surfaceBright: p.elevated,
      surfaceContainerLowest: p.background,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.elevated,
      surfaceContainerHighest: p.elevated,
      onSurfaceVariant: p.textMuted,

      // `outline` is an interactive boundary (input/button edges) and must
      // clear 3:1 — that is textMuted, not border. `outlineVariant` is the
      // decorative divider between ruled rows.
      outline: p.textMuted,
      outlineVariant: p.border,

      inverseSurface: p.elevated,
      onInverseSurface: p.text,
      inversePrimary: p.accent,
      surfaceTint: p.accent,

      // Structural, not identity: shadows and scrims must be neutral so they
      // read as depth rather than as a tinted wash.
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
    );
  }

  // -------------------------------------------------------------------------
  // Type
  // -------------------------------------------------------------------------

  /// Literata ships as a single variable face (axes: `wght`, `opsz`), so weight
  /// is selected through `fontVariations`, not through `fontWeight`. Both are
  /// passed so anything reading `.fontWeight` still sees a sane value.
  static TextStyle _serif({
    required double fontSize,
    required double wght,
    FontWeight weight = FontWeight.normal,
    double height = 1.4,
    double? letterSpacing,
    Color? color,
  }) {
    // Display sizes get a negative tracking floor of -0.02em.
    final tracking = letterSpacing ?? (fontSize >= TypeScale.title ? -0.02 * fontSize : 0.0);
    return TextStyle(
      fontFamily: FontFamilies.display,
      fontSize: fontSize,
      height: height,
      letterSpacing: tracking,
      color: color,
      fontWeight: weight,
      fontVariations: <FontVariation>[
        FontVariation('wght', wght),
        // Optical size tracks the rendered size, as the axis intends.
        FontVariation('opsz', fontSize),
      ],
    );
  }

  static TextStyle _sans({
    required double fontSize,
    FontWeight weight = FontWeight.w400,
    double height = 1.5,
    double letterSpacing = 0,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: FontFamilies.body,
        fontSize: fontSize,
        height: height,
        letterSpacing: letterSpacing,
        color: color,
        fontWeight: weight,
      );

  static TextTheme textTheme(AppPalette p) {
    final c = p.text;
    final muted = p.textMuted;

    return TextTheme(
      displayLarge: _serif(fontSize: TypeScale.display, wght: 600, weight: FontWeight.w600, height: 1.15, color: c),
      displayMedium: _serif(fontSize: TypeScale.headline, wght: 600, weight: FontWeight.w600, height: 1.2, color: c),
      displaySmall: _serif(fontSize: TypeScale.title, wght: 600, weight: FontWeight.w600, height: 1.25, color: c),

      // Screen titles are Literata per DESIGN.md — titles are reading, not UI.
      headlineLarge: _serif(fontSize: TypeScale.title, wght: 600, weight: FontWeight.w600, height: 1.3, color: c),
      headlineMedium: _serif(fontSize: TypeScale.reading, wght: 600, weight: FontWeight.w600, height: 1.4, letterSpacing: 0, color: c),
      headlineSmall: _serif(fontSize: TypeScale.bodyLarge, wght: 600, weight: FontWeight.w600, height: 1.45, letterSpacing: 0, color: c),

      titleLarge: _sans(fontSize: TypeScale.bodyLarge, weight: FontWeight.w600, height: 1.35, color: c),
      titleMedium: _sans(fontSize: TypeScale.body, weight: FontWeight.w500, height: 1.4, color: c),
      titleSmall: _sans(fontSize: TypeScale.label, weight: FontWeight.w500, height: 1.35, color: c),

      bodyLarge: _sans(fontSize: TypeScale.bodyLarge, color: c),
      bodyMedium: _sans(fontSize: TypeScale.body, color: c),
      bodySmall: _sans(fontSize: TypeScale.label, height: 1.45, color: muted),

      labelLarge: _sans(fontSize: TypeScale.body, weight: FontWeight.w600, height: 1.2, letterSpacing: 0.01 * TypeScale.body, color: c),
      labelMedium: _sans(fontSize: TypeScale.label, weight: FontWeight.w500, height: 1.3, letterSpacing: 0.01 * TypeScale.label, color: c),
      labelSmall: _sans(fontSize: TypeScale.caption, weight: FontWeight.w500, height: 1.3, letterSpacing: 0.01 * TypeScale.caption, color: muted),
    );
  }

  // -------------------------------------------------------------------------
  // ThemeData
  // -------------------------------------------------------------------------

  static ThemeData build(Brightness brightness) {
    final p = AppPalette.of(brightness);
    final scheme = colorScheme(p, brightness);
    final text = textTheme(p);

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: p.background,
      extensions: <ThemeExtension<dynamic>>[SemanticColors.of(p)],

      appBarTheme: AppBarThemeData(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineLarge,
      ),

      // Four top-level destinations, labels always visible.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.accentWash,
        height: 72,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? p.accent : p.textMuted,
          );
        }),
      ),

      // Ruled rows, not cards: square, no elevation, hairline dividers only.
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: RadiusTokens.row),
        tileColor: Colors.transparent,
        contentPadding: EdgeInsets.symmetric(horizontal: Spacing.s20),
        minLeadingWidth: Spacing.s32,
      ),

      // The product's only card is ResumeStrip. Material's default radius would
      // drift, so it is pinned to the locked scale.
      cardTheme: CardThemeData(
        color: p.elevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: RadiusTokens.lgBorder,
          side: BorderSide(color: p.border),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: p.textSubtle,
        shape: const RoundedRectangleBorder(
          borderRadius: RadiusTokens.sheetBorder,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          minimumSize: const Size(Layout.minTouchTarget, Layout.minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.s20,
            vertical: Spacing.s12,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: RadiusTokens.smBorder,
          ),
          textStyle: text.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.accentInk,
          minimumSize: const Size(Layout.minTouchTarget, Layout.minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.s20,
            vertical: Spacing.s12,
          ),
          side: BorderSide(color: p.textMuted),
          shape: const RoundedRectangleBorder(
            borderRadius: RadiusTokens.smBorder,
          ),
          textStyle: text.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accentInk,
          minimumSize: const Size(Layout.minTouchTarget, Layout.minTouchTarget),
          textStyle: text.labelLarge,
        ),
      ),

      // Hairline-first: separation comes from `border`, not from shadow.
      dividerTheme: DividerThemeData(
        color: p.border,
        thickness: 1,
        space: 1,
        indent: 0,
        endIndent: 0,
      ),

      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: p.elevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.s16,
          vertical: Spacing.s12,
        ),
        hintStyle: text.bodyMedium?.copyWith(color: p.textSubtle),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.md),
          borderSide: BorderSide(color: p.textMuted),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.md),
          borderSide: BorderSide(color: p.textMuted),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.md),
          borderSide: BorderSide(color: p.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.md),
          borderSide: BorderSide(color: p.danger),
        ),
      ),

      // The SentenceRuler's ticks are drawn by the component; this is only the
      // fallback slider used in settings (2dp track, no thumb halo).
      sliderTheme: SliderThemeData(
        trackHeight: 2,
        activeTrackColor: p.accent,
        inactiveTrackColor: p.border,
        thumbColor: p.accent,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        showValueIndicator: ShowValueIndicator.never,
        tickMarkShape: SliderTickMarkShape.noTickMark,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.elevated,
        contentTextStyle: text.bodyMedium?.copyWith(color: p.text),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.md),
          side: BorderSide(color: p.border),
        ),
      ),
    );
  }

  static ThemeData light() => build(Brightness.light);
  static ThemeData dark() => build(Brightness.dark);
}

/// Type roles Material's `TextTheme` has no slot for.
///
/// Kept here rather than as hand-written styles in widgets so the reader and
/// the utility line stay bound to the locked palette.
extension AppTextStylesX on ThemeData {
  /// The reader body: Literata 18sp at 1.65 leading, which is what gives
  /// Vietnamese stacked diacritics (ế ộ ữ) room not to clip against the line
  /// above (DESIGN.md → Type).
  TextStyle get reading => TextStyle(
        fontFamily: FontFamilies.display,
        fontSize: TypeScale.reading,
        height: 1.65,
        color: colorScheme.onSurface,
        fontWeight: FontWeight.normal,
        fontVariations: const <FontVariation>[
          FontVariation('wght', 400),
          FontVariation('opsz', TypeScale.reading),
        ],
      );

  /// Captions, metadata, file sizes: tabular figures so durations and byte
  /// counts do not jitter while audio plays (DESIGN.md → Type / utility).
  TextStyle get utility => TextStyle(
        fontFamily: FontFamilies.body,
        fontSize: TypeScale.label,
        height: 1.35,
        letterSpacing: 0.01 * TypeScale.label,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurfaceVariant,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      );
}
