import 'package:flutter/material.dart';

import 'tokens.dart';

/// Semantic colors Material 3 has no slot for.
///
/// Material's [ColorScheme] covers primary/secondary/tertiary/error, but this
/// project bans extra accents — there is exactly one — so those three slots all
/// receive the accent. What genuinely needs its own token (the three semantic
/// states, the Listening Spine, accent-as-text) lives here rather than being
/// smuggled into [ColorScheme].
///
/// Access it through `theme.semanticColors`.
@immutable
class SemanticColors extends ThemeExtension<SemanticColors> {
  const SemanticColors({
    required this.accentWash,
    required this.spineRule,
    required this.accentInk,
    required this.border,
    required this.textSubtle,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  /// [accent] at 8% (light) / 12% (dark) — the Listening Spine sentence wash.
  final Color accentWash;

  /// The 3px Listening Spine rule itself.
  final Color spineRule;

  /// Accent when it must be read as text on a light surface (8.0:1).
  final Color accentInk;

  /// Hairline dividers. Decorative; use `outline` for interactive boundaries.
  final Color border;

  /// Decorative-only muted tone. Never load-bearing.
  final Color textSubtle;

  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  static SemanticColors of(AppPalette palette) => SemanticColors(
        accentWash: palette.accentWash,
        spineRule: palette.spineRule,
        accentInk: palette.accentInk,
        border: palette.border,
        textSubtle: palette.textSubtle,
        success: palette.success,
        warning: palette.warning,
        danger: palette.danger,
        info: palette.info,
      );

  @override
  SemanticColors copyWith({
    Color? accentWash,
    Color? spineRule,
    Color? accentInk,
    Color? border,
    Color? textSubtle,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
  }) {
    return SemanticColors(
      accentWash: accentWash ?? this.accentWash,
      spineRule: spineRule ?? this.spineRule,
      accentInk: accentInk ?? this.accentInk,
      border: border ?? this.border,
      textSubtle: textSubtle ?? this.textSubtle,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
    );
  }

  @override
  SemanticColors lerp(SemanticColors? other, double t) {
    if (other is! SemanticColors) return this;
    return SemanticColors(
      accentWash: Color.lerp(accentWash, other.accentWash, t)!,
      spineRule: Color.lerp(spineRule, other.spineRule, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      border: Color.lerp(border, other.border, t)!,
      textSubtle: Color.lerp(textSubtle, other.textSubtle, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SemanticColors &&
      other.accentWash == accentWash &&
      other.spineRule == spineRule &&
      other.accentInk == accentInk &&
      other.border == border &&
      other.textSubtle == textSubtle &&
      other.success == success &&
      other.warning == warning &&
      other.danger == danger &&
      other.info == info;

  @override
  int get hashCode => Object.hash(accentWash, spineRule, accentInk, border,
      textSubtle, success, warning, danger, info);
}

/// Convenience accessors so a widget never has to null-check the extension.
extension SemanticColorsX on ThemeData {
  SemanticColors get semanticColors => extension<SemanticColors>()!;
}
