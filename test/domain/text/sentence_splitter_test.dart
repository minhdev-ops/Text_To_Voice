import 'package:flutter_test/flutter_test.dart';

import 'package:text_to_voice/domain/text/sentence_splitter.dart';

void main() {
  const split = SentenceSplitter();

  group('terminators', () {
    test('splits on . ! ? and …', () {
      expect(split.split('Một. Hai! Ba? Bốn…'), <String>[
        'Một.',
        'Hai!',
        'Ba?',
        'Bốn…',
      ]);
    });

    test('keeps the terminator with the sentence it closes', () {
      expect(split.split('Xong việc. Nghỉ thôi.'), <String>[
        'Xong việc.',
        'Nghỉ thôi.',
      ]);
    });

    test('runs of terminators are one boundary', () {
      expect(split.split('Thật sao?! Đúng vậy.'), <String>[
        'Thật sao?!',
        'Đúng vậy.',
      ]);
    });

    test('closing quotes and brackets stay with the sentence', () {
      expect(split.split('Anh ấy nói: "Tôi về." Rồi đi.'), <String>[
        'Anh ấy nói: "Tôi về."',
        'Rồi đi.',
      ]);
      expect(split.split('(Xong.) Đi tiếp.'), <String>['(Xong.)', 'Đi tiếp.']);
    });

    test('text without a terminator is a single sentence', () {
      expect(split.split('Xin chào'), <String>['Xin chào']);
    });

    test('a lone terminator is itself a sentence', () {
      expect(split.split('Một. . Hai.'), <String>['Một.', '.', 'Hai.']);
    });
  });

  group('dots that do not end a sentence', () {
    test('titles and abbreviations do not split', () {
      // The whole point of the masking pass: two sentences, not four.
      expect(
        split.split('TS. Nguyễn Văn A tốt nghiệp năm 2019. Ông nhận bằng năm 2020.'),
        <String>[
          'TS. Nguyễn Văn A tốt nghiệp năm 2019.',
          'Ông nhận bằng năm 2020.',
        ],
      );
      expect(split.split('Gồm táo, lê, v.v. Rất ngon.'), <String>[
        'Gồm táo, lê, v.v.',
        'Rất ngon.',
      ]);
    });

    test('a middle initial followed by a name does not split', () {
      expect(split.split('H. Nguyễn là tác giả. Ông sinh năm 1990.'), <String>[
        'H. Nguyễn là tác giả.',
        'Ông sinh năm 1990.',
      ]);
    });

    test('a dot between digits is a decimal', () {
      expect(split.split('Giá trị là 3.14 và vẫn tăng.'), <String>[
        'Giá trị là 3.14 và vẫn tăng.',
      ]);
    });

    test('a URL or email does not split, and its sentence still ends', () {
      expect(split.split('Xem https://example.com để biết.'), <String>[
        'Xem https://example.com để biết.',
      ]);
      expect(split.split('Gửi tới a.b@example.com nhé.'), <String>[
        'Gửi tới a.b@example.com nhé.',
      ]);
      // A terminator after a URL is still a terminator: two sentences.
      expect(split.split('Xem tại https://example.com. Rồi quay lại.'), <String>[
        'Xem tại https://example.com.',
        'Rồi quay lại.',
      ]);
    });
  });

  group('whitespace and paragraphs', () {
    test('blank or whitespace-only input yields nothing', () {
      expect(split.split(''), isEmpty);
      expect(split.split('   \n\n  '), isEmpty);
    });

    test('a paragraph break is a hard boundary without punctuation', () {
      expect(split.split('Đoạn một\n\nĐoạn hai'), <String>[
        'Đoạn một',
        'Đoạn hai',
      ]);
    });

    test('a line break inside a paragraph is just a wrap', () {
      expect(split.split('Dòng một\nDòng hai.'), <String>['Dòng một Dòng hai.']);
    });

    test('no entry is empty or padded', () {
      final sentences = split.split('  Một.  \n\n   Hai.  ');
      expect(sentences, <String>['Một.', 'Hai.']);
      for (final s in sentences) {
        expect(s, s.trim());
        expect(s, isNotEmpty);
      }
    });
  });

  group('Vietnamese text integrity', () {
    test('diacritics survive splitting', () {
      expect(
        split.split('Tôi yêu Tổ quốc. Mùa xuân ửng hồng.'),
        <String>['Tôi yêu Tổ quốc.', 'Mùa xuân ửng hồng.'],
      );
    });

    test('splitting a normalized document loses nothing', () {
      const source = 'Đoạn một câu đầu. Câu thứ hai.\n\nĐoạn hai câu ba!';
      final joined = split.split(source).join(' ');
      expect(joined, contains('Đoạn một câu đầu.'));
      expect(joined, contains('Câu thứ hai.'));
      expect(joined, contains('Đoạn hai câu ba!'));
    });
  });
}
