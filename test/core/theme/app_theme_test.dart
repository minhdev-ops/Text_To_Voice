import 'dart:math' show pow;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:text_to_voice/core/theme/app_theme.dart';
import 'package:text_to_voice/core/theme/semantic_colors.dart';
import 'package:text_to_voice/core/theme/tokens.dart';

/// WCAG 2.1 relative luminance.
///
/// Uses `Color.r/g/b` (0..1 doubles) rather than the deprecated `.red/.green/
/// .blue` accessors.
double _luminance(Color color) {
  double channel(double c) => c <= 0.04045
      ? c / 12.92
      : pow((c + 0.055) / 1.055, 2.4).toDouble();

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('locked palette (identity guard)', () {
    test('light scheme is built from the locked hex values, not fromSeed', () {
      final scheme = AppTheme.colorScheme(AppPalette.light, Brightness.light);

      expect(scheme.primary, const Color(0xFF1F7A6B));
      expect(scheme.onPrimary, const Color(0xFFFFFFFF));
      expect(scheme.surface, const Color(0xFFF4F8F6));
      expect(scheme.onSurface, const Color(0xFF22302E));
      expect(scheme.onSurfaceVariant, const Color(0xFF5E6D6B));
      expect(scheme.outline, const Color(0xFF5E6D6B));
      expect(scheme.outlineVariant, const Color(0xFFD8E2DE));
      expect(scheme.error, const Color(0xFFB03A3A));
      expect(scheme.brightness, Brightness.light);
    });

    test('dark scheme is re-derived, not inverted', () {
      final scheme = AppTheme.colorScheme(AppPalette.dark, Brightness.dark);

      expect(scheme.primary, const Color(0xFF59C4AE));
      expect(scheme.onPrimary, const Color(0xFF131B1A));
      expect(scheme.surface, const Color(0xFF131B1A));
      expect(scheme.onSurface, const Color(0xFFE4EDEA));
      expect(scheme.outline, const Color(0xFFA3B2AF));
      expect(scheme.outlineVariant, const Color(0xFF2C3835));
      expect(scheme.error, const Color(0xFFE2807C));
      expect(scheme.brightness, Brightness.dark);
    });

    test('exactly one accent: primary, secondary and tertiary share it', () {
      for (final brightness in Brightness.values) {
        final scheme =
            AppTheme.colorScheme(AppPalette.of(brightness), brightness);
        expect(scheme.secondary, scheme.primary);
        expect(scheme.tertiary, scheme.primary);
        expect(scheme.inversePrimary, scheme.primary);
        expect(scheme.surfaceTint, scheme.primary);
      }
    });

    test('themes expose the SemanticColors extension', () {
      final light = AppTheme.light();
      final dark = AppTheme.dark();

      expect(light.extension<SemanticColors>(), isNotNull);
      expect(dark.extension<SemanticColors>(), isNotNull);
      expect(light.extension<SemanticColors>()!.spineRule,
          const Color(0xFF1F7A6B));
      expect(dark.extension<SemanticColors>()!.spineRule,
          const Color(0xFF59C4AE));
      expect(light.semanticColors.accentWash, const Color(0x141F7A6B));
      expect(dark.semanticColors.accentWash, const Color(0x1F59C4AE));
    });

    test('one radius scale, and list rows stay square', () {
      expect(RadiusTokens.sm, 2);
      expect(RadiusTokens.md, 4);
      expect(RadiusTokens.lg, 8);
      expect(RadiusTokens.row, BorderRadius.zero);
      expect(AppTheme.light().listTileTheme.shape,
          isA<RoundedRectangleBorder>());
    });

    test('motion is one curve with no bounce', () {
      expect(Motion.fast, const Duration(milliseconds: 120));
      expect(Motion.base, const Duration(milliseconds: 240));
      expect(Motion.emphasis, const Duration(milliseconds: 400));
      expect(Motion.standard, isA<Cubic>());
    });

    test('touch targets meet the Android floor', () {
      final filled = AppTheme.light().filledButtonTheme.style!;
      expect(filled.minimumSize!.resolve(const {})!.width, greaterThanOrEqualTo(48));
      expect(filled.minimumSize!.resolve(const {})!.height,
          greaterThanOrEqualTo(48));
    });
  });

  group('WCAG AA contrast', () {
    void expectPasses(String label, Color fg, Color bg, double min) {
      final ratio = _contrast(fg, bg);
      expect(
        ratio,
        greaterThanOrEqualTo(min),
        reason: '$label measured ${ratio.toStringAsFixed(2)}:1, needs $min:1',
      );
    }

    for (final (name, p) in <(String, AppPalette)>[
      ('light', AppPalette.light),
      ('dark', AppPalette.dark),
    ]) {
      test('$name: text pairs pass 4.5:1', () {
        expectPasses('text', p.text, p.background, 4.5);
        expectPasses('textMuted', p.textMuted, p.background, 4.5);
        expectPasses('accent', p.accent, p.background, 4.5);
        expectPasses('accentInk', p.accentInk, p.background, 4.5);
        expectPasses('onAccent', p.onAccent, p.accent, 4.5);
        expectPasses('success', p.success, p.background, 4.5);
        expectPasses('warning', p.warning, p.background, 4.5);
        expectPasses('danger', p.danger, p.background, 4.5);
        expectPasses('info', p.info, p.background, 4.5);
        expectPasses('accent on elevated', p.accent, p.elevated, 4.5);
      });

      test('$name: interactive outline passes 3:1', () {
        // `outline` is bound to textMuted, not to the hairline border, so
        // input and button edges clear WCAG 1.4.11.
        expectPasses('outline', p.textMuted, p.background, 3.0);
      });

      test('$name: decorative roles are classified honestly', () {
        // `border` must never be an interactive boundary — it sits far below
        // the 3:1 UI-component threshold, which is exactly why `outline` is
        // bound to textMuted instead.
        expect(_contrast(p.border, p.background), lessThan(3.0),
            reason: 'border is a divider, never an interactive boundary');

        // textSubtle must always be quieter than textMuted, so the weaker tone
        // can never be mistaken for the readable one.
        expect(
          _contrast(p.textSubtle, p.background),
          lessThan(_contrast(p.textMuted, p.background)),
        );
      });
    }
  });

  group('type', () {
    test('reading style uses Literata with diacritic-safe leading', () {
      final reading = AppTheme.light().reading;
      expect(reading.fontFamily, FontFamilies.display);
      expect(reading.fontSize, 18);
      expect(reading.height!, greaterThanOrEqualTo(1.65));
      expect(
        reading.fontVariations!.any((v) => v.axis == 'wght'),
        isTrue,
        reason: 'Literata is a variable face — weight must come from the axis',
      );
    });

    test('utility style uses tabular figures so durations do not jitter', () {
      final utility = AppTheme.light().utility;
      expect(utility.fontFamily, FontFamilies.body);
      expect(
        utility.fontFeatures!.any((f) => f.feature == 'tnum'),
        isTrue,
      );
    });

    test('display tracking never exceeds the -0.02em floor', () {
      final text = AppTheme.light().textTheme;
      for (final style in [text.displayLarge, text.headlineLarge]) {
        expect(style!.letterSpacing!, lessThanOrEqualTo(0));
        expect(
          style.letterSpacing!,
          greaterThanOrEqualTo(-0.02 * style.fontSize! - 0.001),
        );
      }
    });

    test('no reflex default fonts anywhere in the TextTheme', () {
      final banned = {'Inter', 'Roboto', 'Arial', 'Helvetica', 'system-ui'};
      final theme = AppTheme.light().textTheme;
      final styles = [
        theme.displayLarge,
        theme.displayMedium,
        theme.displaySmall,
        theme.headlineLarge,
        theme.headlineMedium,
        theme.headlineSmall,
        theme.titleLarge,
        theme.titleMedium,
        theme.titleSmall,
        theme.bodyLarge,
        theme.bodyMedium,
        theme.bodySmall,
        theme.labelLarge,
        theme.labelMedium,
        theme.labelSmall,
      ];
      for (final style in styles) {
        expect(banned.contains(style!.fontFamily), isFalse,
            reason: 'banned family: ${style.fontFamily}');
      }
    });
  });
}
