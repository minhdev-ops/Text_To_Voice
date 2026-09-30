import 'package:flutter_test/flutter_test.dart';

import 'package:text_to_voice/domain/text/text_normalizer.dart';

void main() {
  const n = TextNormalizer();

  group('whitespace', () {
    test('empty input stays empty', () {
      expect(n.normalize(''), '');
      expect(n.normalize('   '), '');
    });

    test('collapses runs of spaces and trims each line', () {
      expect(n.normalize('Xin   chào \n  Việt Nam '), 'Xin chào\nViệt Nam');
    });

    test('keeps paragraph breaks but collapses extra blank lines', () {
      expect(
        n.normalize('Đoạn một.\n\n\n\n\nĐoạn hai.'),
        'Đoạn một.\n\nĐoạn hai.',
      );
    });

    test('converts CRLF and tabs', () {
      expect(n.normalize('a\r\nb\tc'), 'a\nb c');
    });
  });

  group('percent and currency', () {
    test('percent expands before numbers are read', () {
      expect(n.normalize('50%'), 'năm mươi phần trăm');
      expect(n.normalize('xấp xỉ 7 %'), 'xấp xỉ bảy phần trăm');
    });

    test('currency expands', () {
      expect(n.normalize('100₫'), 'một trăm đồng');
      expect(n.normalize('50000 VND'), 'năm mươi nghìn đồng');
    });
  });

  group('numbers', () {
    test('reads simple integers', () {
      expect(n.normalize('0'), 'không');
      expect(n.normalize('7'), 'bảy');
      expect(n.normalize('10'), 'mười');
      expect(n.normalize('15'), 'mười lăm');
      expect(n.normalize('21'), 'hai mươi mốt');
      expect(n.normalize('45'), 'bốn mươi lăm');
      expect(n.normalize('100'), 'một trăm');
      expect(n.normalize('105'), 'một trăm lẻ năm');
      expect(n.normalize('150'), 'một trăm năm mươi');
    });

    test('reads grouped thousands', () {
      expect(n.normalize('1.000'), 'một nghìn');
      expect(n.normalize('1.234'), 'một nghìn hai trăm ba mươi bốn');
      expect(n.normalize('1.234.567'),
          'một triệu hai trăm ba mươi bốn nghìn năm trăm sáu mươi bảy');
      expect(n.normalize('2026'), 'hai nghìn không trăm hai mươi sáu');
    });

    test('pads a short group that follows a higher one', () {
      expect(n.normalize('1.005'), 'một nghìn lẻ năm');
      expect(n.normalize('1.000.005'), 'một triệu lẻ năm');
      // A tens/units pair keeps its hundreds place named instead of `lẻ`.
      expect(n.normalize('1.026'), 'một nghìn không trăm hai mươi sáu');
      expect(n.normalize('2.000.075'), 'hai triệu không trăm bảy mươi lăm');
    });

    test('reads millions and billions', () {
      expect(n.normalize('1000000'), 'một triệu');
      expect(n.normalize('2500000'), 'hai triệu năm trăm nghìn');
      expect(n.normalize('1000000000'), 'một tỷ');
    });

    test('comma and dot are the Vietnamese decimal separator', () {
      expect(n.normalize('3,14'), 'ba phẩy một bốn');
      expect(n.normalize('0,5'), 'không phẩy năm');
      expect(n.normalize('3.14'), 'ba phẩy một bốn');
    });

    test('mixed thousands and decimals', () {
      expect(n.normalize('1.234,56'),
          'một nghìn hai trăm ba mươi bốn phẩy năm sáu');
    });

    test('a malformed grouping is not stitched into a wrong integer', () {
      // `1234.567` is not valid thousands grouping; it must not become 1234567.
      final out = n.normalize('1234.567');
      expect(out.contains('1234567'), isFalse);
      expect(out, isNotEmpty);
    });

    test('very long digit runs fall back to reading digit by digit', () {
      final out = n.normalize('12345678901234567890');
      expect(out, isNot(contains('12345678901234567890')));
      expect(out.split(' '), everyElement(isNotEmpty));
      // No integer was parsed out of it.
      expect(out.contains('nghìn'), isFalse);
    });

    test('digits inside words are still read', () {
      expect(n.normalize('COVID-19'), 'COVID-mười chín');
    });
  });

  group('does not alter prose', () {
    test('plain text passes through unchanged', () {
      const input = 'Xin chào Việt Nam. Đây là ứng dụng đọc tài liệu.';
      expect(n.normalize(input), input);
    });

    test('Vietnamese diacritics survive', () {
      const input = 'Tôi yêu Tổ quốc, mùa xuân ửng hồng.';
      expect(n.normalize(input), input);
    });
  });
}
