import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:text_to_voice/domain/export/text_exporter.dart';
import 'package:text_to_voice/domain/models/reading.dart';

void main() {
  const exporter = TextExporter();

  const text = 'Xin chào Việt Nam. Đây là tài liệu thử.\n\nĐoạn thứ hai có dấu.';

  Sentence sentence(int index, {int? durationMs}) => Sentence(
        index: index,
        text: 'Câu số $index.',
        blockId: 'read-aloud',
        durationMs: durationMs,
      );

  group('txt', () {
    test('is the document verbatim, with no added header', () {
      final out = exporter.render(
        text: text,
        title: 'Bất kỳ',
        format: TextExportFormat.txt,
      );

      expect(out, '$text\n');
      expect(out, isNot(contains('# ')));
    });

    test('keeps diacritics and paragraph breaks', () {
      final out = exporter.render(
        text: text,
        title: 'x',
        format: TextExportFormat.txt,
      );

      expect(out, contains('Xin chào Việt Nam.'));
      expect(out, contains('\n\nĐoạn thứ hai có dấu.'));
    });

    test('empty text produces an empty file, not a blank line', () {
      expect(
        exporter.render(text: '   ', title: 'x', format: TextExportFormat.txt),
        '',
      );
    });
  });

  group('markdown', () {
    test('adds the title as a heading', () {
      final out = exporter.render(
        text: text,
        title: 'Tài liệu thử',
        format: TextExportFormat.md,
      );

      expect(out, startsWith('# Tài liệu thử\n\n'));
      expect(out, contains('Đoạn thứ hai có dấu.'));
    });
  });

  group('json', () {
    test('is valid JSON with the text and its sentences', () {
      final out = exporter.render(
        text: text,
        title: 'Tài liệu thử',
        format: TextExportFormat.json,
        sentences: <Sentence>[sentence(0, durationMs: 1200), sentence(1)],
        exportedAt: DateTime.utc(2026, 9, 28, 10, 30),
      );

      final decoded = jsonDecode(out) as Map<String, dynamic>;
      expect(decoded['title'], 'Tài liệu thử');
      expect(decoded['text'], text);
      expect(decoded['sentenceCount'], 2);
      expect(decoded['exportedAt'], '2026-09-28T10:30:00.000Z');

      final sentences = decoded['sentences'] as List<dynamic>;
      expect(sentences.first, <String, Object?>{
        'index': 0,
        'text': 'Câu số 0.',
        'durationMs': 1200,
      });
    });

    test('omits a duration that was never measured', () {
      final out = exporter.render(
        text: text,
        title: 'x',
        format: TextExportFormat.json,
        sentences: <Sentence>[sentence(0)],
      );

      final entry = (jsonDecode(out) as Map<String, dynamic>)['sentences'][0]
          as Map<String, dynamic>;
      expect(entry.containsKey('durationMs'), isFalse,
          reason: 'an unmeasured duration must not be written as 0');
    });

    test('diacritics survive a JSON round trip', () {
      final out = exporter.render(
        text: 'Tôi yêu Tổ quốc, mùa xuân ửng hồng.',
        title: 'x',
        format: TextExportFormat.json,
      );

      expect((jsonDecode(out) as Map<String, dynamic>)['text'],
          'Tôi yêu Tổ quốc, mùa xuân ửng hồng.');
    });
  });

  group('file names', () {
    test('stay Vietnamese, only what a file system cannot carry is removed', () {
      expect(exportFileName('Tài liệu thử', 'txt'), 'tài-liệu-thử.txt');
    });

    test('separators and repeated spaces collapse', () {
      expect(exportFileName(' a / b : c ', 'md'), 'a-b-c.md');
    });

    test('an unusable title falls back to a real name', () {
      expect(exportFileName('///', 'json'), 'van-ban.json');
      expect(exportFileName('   ', 'json'), 'van-ban.json');
    });

    test('a very long title keeps its extension', () {
      final name = exportFileName('a' * 200, 'wav');
      expect(name, endsWith('.wav'));
      expect(name.length, lessThan(80));
    });
  });

  group('title derivation', () {
    test('takes the opening words and marks the cut', () {
      const long = 'Một hai ba bốn năm sáu bảy tám chín mười';
      expect(documentTitleFrom(long), 'Một hai ba bốn năm sáu bảy tám…');
    });

    test('a short text becomes its own title', () {
      expect(documentTitleFrom('Xin chào.'), 'Xin chào.');
    });

    test('empty text still has a name', () {
      expect(documentTitleFrom('   '), 'Văn bản');
    });
  });
}
