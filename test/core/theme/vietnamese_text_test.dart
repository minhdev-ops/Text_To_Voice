import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:text_to_voice/core/theme/app_theme.dart';
import 'package:text_to_voice/core/theme/tokens.dart';

import '../../support/ttf_coverage.dart';

/// Codepoints that must exist as real glyphs. Covers the three groups that
/// Vietnamese needs and that naive Latin subsets drop: tone-marked vowels,
/// the horn letters (ơ ư), and đ/Đ.
const Map<int, String> _requiredVietnamese = <int, String>{
  0x0110: 'Đ',
  0x0111: 'đ',
  0x01A1: 'ơ',
  0x01B0: 'ư',
  0x1EA1: 'ạ',
  0x1EA7: 'ầ',
  0x1EA9: 'ẩ',
  0x1EBF: 'ế',
  0x1EC7: 'ệ',
  0x1ED9: 'ộ',
  0x1EE3: 'ợ',
  0x1EE9: 'ứ',
  0x1EEB: 'ủ',
  0x1EEF: 'ữ',
  0x1EF9: 'ỹ',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bundled fonts cover Vietnamese', () {
    for (final entry in const <String, String>{
      'Literata': 'assets/fonts/Literata-Variable.ttf',
      'BeVietnamPro': 'assets/fonts/BeVietnamPro-Regular.ttf',
      'BeVietnamPro/SemiBold': 'assets/fonts/BeVietnamPro-SemiBold.ttf',
    }.entries) {
      test('${entry.key} has a glyph for every required character', () {
        final font = TrueTypeCoverage.fromFile(entry.value);
        final missing = <String>[];
        for (final entry in _requiredVietnamese.entries) {
          if (!font.covers(entry.key)) {
            missing.add(
              '${entry.value} U+${entry.key.toRadixString(16).toUpperCase()}',
            );
          }
        }
        expect(missing, isEmpty,
            reason: '${entry.key} is missing: ${missing.join(', ')}');
      });
    }

    test('fonts are the families the theme actually references', () {
      expect(FontFamilies.display, 'Literata');
      expect(FontFamilies.body, 'BeVietnamPro');
    });
  });

  group('reading style', () {
    test('round-trips Vietnamese text through the text pipeline intact', () {
      const sample = 'Tiếng Việt: ế ộ ữ ẩ ứ đ Đ, “nháy kép”, 100%, COVID-19.';

      final painter = TextPainter(
        text: TextSpan(text: sample, style: AppTheme.light().reading),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 600);

      expect(painter.text!.toPlainText(), sample,
          reason: 'the pipeline must not normalize or strip diacritics');
      expect(painter.width, greaterThan(0));
      expect(painter.height, greaterThan(0));
      expect(
        painter.height,
        greaterThanOrEqualTo(18 * 1.65 - 0.5),
        reason: 'leading must leave room for stacked diacritics',
      );
    });

    test('the reader column stays inside the locked measure', () {
      final style = AppTheme.light().reading;
      expect(style.fontSize, 18);
      expect(Layout.readerMaxWidth, 720);
    });
  });
}
