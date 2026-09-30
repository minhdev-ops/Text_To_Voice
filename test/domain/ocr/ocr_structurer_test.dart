import 'package:flutter_test/flutter_test.dart';
import 'package:text_to_voice/domain/models/document_block.dart' show BlockType;
import 'package:text_to_voice/domain/models/ocr.dart' show OcrLine;
import 'package:text_to_voice/domain/ocr/ocr_structurer.dart';

import '../../support/fake_ocr_engine.dart' show FakeOcrEngine;

/// A line of body text at a normalized position.
OcrLine body(
  String text, {
  required double top,
  double left = 0.1,
  double width = 0.8,
  double height = 0.02,
  double? confidence,
}) =>
    FakeOcrEngine.line(
      text,
      top: top,
      left: left,
      width: width,
      height: height,
      confidence: confidence,
    );

void main() {
  group('ordering', () {
    test('a single column is read top to bottom', () {
      final structurer = OcrStructurer();
      // Deliberately handed over out of order: OCR engines do not guarantee
      // reading order just because the caller drew the lines that way.
      final blocks = structurer.structure(<OcrLine>[
        body('Dòng ba', top: 0.144),
        body('Dòng một', top: 0.100),
        body('Dòng hai', top: 0.122),
      ]);

      expect(blocks, hasLength(1));
      expect(blocks.single.content, 'Dòng một Dòng hai Dòng ba');
    });

    test('a two-column page is read column by column, not interleaved', () {
      final structurer = OcrStructurer();
      final lines = <OcrLine>[
        // Left column.
        FakeOcrEngine.line('Trái một', top: 0.10, left: 0.08, width: 0.36),
        FakeOcrEngine.line('Trái hai', top: 0.16, left: 0.08, width: 0.36),
        FakeOcrEngine.line('Trái ba', top: 0.22, left: 0.08, width: 0.36),
        FakeOcrEngine.line('Trái bốn', top: 0.70, left: 0.08, width: 0.36),
        // Right column.
        FakeOcrEngine.line('Phải một', top: 0.10, left: 0.56, width: 0.36),
        FakeOcrEngine.line('Phải hai', top: 0.16, left: 0.56, width: 0.36),
        FakeOcrEngine.line('Phải ba', top: 0.22, left: 0.56, width: 0.36),
        FakeOcrEngine.line('Phải bốn', top: 0.70, left: 0.56, width: 0.36),
      ];

      final blocks = structurer.structure(lines);
      final text = blocks.map((b) => b.content).join(' ');

      // Every left-column line must come before every right-column line.
      expect(text.indexOf('Trái bốn'), lessThan(text.indexOf('Phải một')));
    });

    test('a normal single-column page is not mistaken for two columns', () {
      final structurer = OcrStructurer();
      // Ordinary prose: one short centred heading leaves a blank band on both
      // sides of it, which is exactly what fools a naive gutter test.
      final lines = <OcrLine>[
        FakeOcrEngine.line('CHƯƠNG MỘT',
            top: 0.06, left: 0.35, width: 0.3, height: 0.03),
        body('Một câu văn dài bình thường ở cột duy nhất.', top: 0.12),
        body('Một câu văn dài bình thường ở cột duy nhất.', top: 0.16),
        body('Một câu văn dài bình thường ở cột duy nhất.', top: 0.20),
        body('Một câu văn dài bình thường ở cột duy nhất.', top: 0.24),
        body('Một câu văn dài bình thường ở cột duy nhất.', top: 0.28),
      ];

      final blocks = structurer.structure(lines);
      // The heading stays first and the prose keeps its order: a false gutter
      // would have moved every line after it into a "second column".
      expect(blocks.first.content, 'CHƯƠNG MỘT');
      expect(blocks.first.isHeading, isTrue);
      expect(blocks[1].content,
          contains('Một câu văn dài bình thường ở cột duy nhất.'));
      expect(blocks, hasLength(2));
    });

    test('lines without geometry become one block, and say why', () {
      final structurer = OcrStructurer();
      final blocks = structurer.structure(<OcrLine>[
        const OcrLine(text: 'Không có toạ độ một'),
        const OcrLine(text: 'Không có toạ độ hai'),
      ]);

      expect(blocks, hasLength(1));
      expect(blocks.single.type, BlockType.paragraph);
      expect(blocks.single.content, 'Không có toạ độ một\nKhông có toạ độ hai');
      expect(blocks.single.metadata['structure'], 'no_geometry');
    });

    test('blank lines are dropped rather than becoming empty blocks', () {
      final structurer = OcrStructurer();
      final blocks = structurer.structure(<OcrLine>[
        body('Câu thật', top: 0.1),
        body('   ', top: 0.12),
        body('', top: 0.14),
      ]);
      expect(blocks, hasLength(1));
      expect(blocks.single.content, 'Câu thật');
    });

    test('no lines at all gives no blocks', () {
      expect(OcrStructurer().structure(const <OcrLine>[]), isEmpty);
    });
  });

  group('paragraph grouping', () {
    test('a wide vertical gap starts a new paragraph', () {
      final structurer = OcrStructurer();
      final blocks = structurer.structure(<OcrLine>[
        body('Đoạn một dòng đầu', top: 0.10, width: 0.8),
        body('Đoạn một dòng hai', top: 0.13, width: 0.8),
        // Gap of 0.06 with a 0.02 line height is three line-heights.
        body('Đoạn hai dòng đầu', top: 0.19, width: 0.8),
      ]);

      expect(blocks, hasLength(2));
      expect(blocks[0].content, 'Đoạn một dòng đầu Đoạn một dòng hai');
      expect(blocks[1].content, 'Đoạn hai dòng đầu');
    });

    test('evenly spaced lines stay in one paragraph', () {
      final structurer = OcrStructurer();
      final blocks = structurer.structure(<OcrLine>[
        for (var i = 0; i < 5; i++)
          body('Dòng $i của cùng một đoạn văn.', top: 0.10 + i * 0.022),
      ]);
      expect(blocks, hasLength(1));
    });

    test('a line that ends short of the margin ends the paragraph', () {
      final structurer = OcrStructurer();
      final blocks = structurer.structure(<OcrLine>[
        body('Dòng đầy đủ tới hết lề phải của trang giấy này', top: 0.10),
        // Ends early: the classic last line of a paragraph.
        FakeOcrEngine.line('Dòng ngắn', top: 0.122, left: 0.1, width: 0.3),
        // The next line is indented, which only means a new paragraph if the
        // previous one ended short.
        FakeOcrEngine.line('Dòng thụt lề mở đoạn mới', top: 0.144,
            left: 0.16, width: 0.74),
      ]);

      expect(blocks, hasLength(2));
      expect(blocks[0].content, contains('Dòng ngắn'));
      expect(blocks[1].content, 'Dòng thụt lề mở đoạn mới');
    });

    test('an indent alone does not start a paragraph', () {
      final structurer = OcrStructurer();
      final blocks = structurer.structure(<OcrLine>[
        // Full-measure line: nothing ended short before the indented one, so the
        // indent is a hanging quote, not a new paragraph.
        FakeOcrEngine.line('Dòng chạy hết cả lề phải của trang giấy này đây',
            top: 0.10, left: 0.10, width: 0.80),
        FakeOcrEngine.line('Dòng thụt vào nhưng vẫn cùng đoạn văn bản',
            top: 0.122, left: 0.18, width: 0.72),
      ]);

      expect(blocks, hasLength(1));
    });

    test('a size change starts a new block even with no gap', () {
      final structurer = OcrStructurer();
      final blocks = structurer.structure(<OcrLine>[
        // Four body lines so the page median really is the body size: with two
        // lines the median is the heading and nothing looks bigger than it.
        for (var i = 0; i < 4; i++)
          body('Văn bản thường ở đây.', top: 0.10 + i * 0.021, height: 0.018),
        body('TIÊU ĐỀ LỚN HƠN', top: 0.20, height: 0.030, width: 0.4),
      ]);
      expect(blocks, hasLength(2));
      expect(blocks[1].type, BlockType.heading);
    });
  });

  group('classification', () {
    test('the first large short block is the title', () {
      final structurer = OcrStructurer();
      final blocks = structurer.structure(<OcrLine>[
        body('BÁO CÁO THƯỜNG NIÊN 2026', top: 0.06, height: 0.04, width: 0.8),
        for (var i = 0; i < 4; i++)
          body('Nội dung của báo cáo được trình bày ở đây.', top: 0.16 + i * 0.022),
      ]);

      expect(blocks.first.type, BlockType.title);
      expect(blocks.first.level, 1);
      expect(blocks.last.type, BlockType.paragraph);
    });

    test('a large short block in the middle is a heading, not a title', () {
      final structurer = OcrStructurer();
      final blocks = structurer.structure(<OcrLine>[
        for (var i = 0; i < 3; i++)
          body('Mở đầu của tài liệu.', top: 0.06 + i * 0.022),
        body('PHẦN HAI', top: 0.24, height: 0.03, width: 0.3),
        body('Nội dung phần hai.', top: 0.30),
      ]);

      final heading = blocks.firstWhere((b) => b.isHeading);
      expect(heading.type, BlockType.heading);
      expect(heading.content, 'PHẦN HAI');
    });

    test('a long large block is prose that happens to be set large', () {
      final structurer = OcrStructurer();
      final long = 'Đây là một câu rất dài ${'và tiếp tục ' * 12}cho tới khi vượt '
          'qua giới hạn ký tự của một tiêu đề.';
      final blocks = structurer.structure(<OcrLine>[
        body(long, top: 0.06, height: 0.04, width: 0.8),
      ]);
      expect(blocks.single.type, BlockType.paragraph);
    });

    test('a bulleted run becomes a list with its markers stripped', () {
      final structurer = OcrStructurer();
      final blocks = structurer.structure(<OcrLine>[
        body('- Mục thứ nhất', top: 0.10),
        body('- Mục thứ hai', top: 0.122),
        body('1. Mục thứ ba', top: 0.144),
      ]);

      expect(blocks.single.type, BlockType.list);
      expect(blocks.single.content.split('\n'), <String>[
        '• Mục thứ nhất',
        '• Mục thứ hai',
        '• Mục thứ ba',
      ]);
    });

    test('small text in the bottom zone is a footnote and is skipped', () {
      final structurer = OcrStructurer();
      final blocks = structurer.structure(<OcrLine>[
        for (var i = 0; i < 6; i++)
          body('Nội dung chính của trang tài liệu.', top: 0.10 + i * 0.022),
        body('1. Chú thích nhỏ ở chân trang.', top: 0.91, height: 0.014),
      ]);

      final footnote = blocks.last;
      expect(footnote.type, BlockType.footnote);
      expect(footnote.isSkippedInReadAloud, isTrue);
    });

    test('a table is recognized and its cells are separated', () {
      final structurer = OcrStructurer();
      final blocks = structurer.structure(<OcrLine>[
        body('Bảng 1: Doanh thu', top: 0.10),
        body('Tháng     Doanh thu     Ghi chú', top: 0.13),
        body('Một       100            tốt', top: 0.15),
        body('Hai       200            khá', top: 0.17),
      ]);

      final table = blocks.firstWhere((b) => b.type == BlockType.table);
      expect(table.content.split('\n').first, 'Tháng | Doanh thu | Ghi chú');
      expect(table.content.split('\n').last, 'Hai | 200 | khá');
    });

    test('a paragraph confidence is the weakest line, not the average', () {
      final structurer = OcrStructurer();
      final blocks = structurer.structure(<OcrLine>[
        body('Dòng chắc chắn', top: 0.10, confidence: 0.99),
        body('Dòng đọc sai', top: 0.122, confidence: 0.4),
        body('Dòng chắc chắn', top: 0.144, confidence: 0.98),
      ]);

      expect(blocks.single.confidence, 0.4);
      expect(blocks.single.isLowConfidence, isTrue);
    });

    test('a page with no confidence anywhere reports none, not zero', () {
      final structurer = OcrStructurer();
      final blocks = structurer.structure(<OcrLine>[
        body('Không có điểm tin cậy', top: 0.10),
      ]);
      expect(blocks.single.confidence, isNull);
      expect(blocks.single.isLowConfidence, isFalse);
    });

    test('block positions cover the whole paragraph', () {
      final structurer = OcrStructurer();
      final blocks = structurer.structure(<OcrLine>[
        FakeOcrEngine.line('Dòng trên', top: 0.10, left: 0.10, width: 0.80, height: 0.02),
        FakeOcrEngine.line('Dòng dưới', top: 0.13, left: 0.20, width: 0.60, height: 0.02),
      ]);

      final position = blocks.single.position!;
      expect(position.left, closeTo(0.10, 1e-9));
      expect(position.top, closeTo(0.10, 1e-9));
      // Union of the two boxes: [0.10, 0.90] wide, [0.10, 0.15] tall.
      expect(position.width, closeTo(0.80, 1e-9));
      expect(position.height, closeTo(0.05, 1e-9));
    });
  });

  group('running headers, footers and page numbers', () {
    test('a line repeated at the top of several pages is skipped', () {
      final structurer = OcrStructurer();

      List<OcrLine> page(String number) => <OcrLine>[
            body('Sách Giáo Khoa Vật Lý', top: 0.02, height: 0.02),
            for (var i = 0; i < 4; i++)
              body('Nội dung trang $number dòng $i.', top: 0.12 + i * 0.022),
            body(number, top: 0.97, height: 0.02),
          ];

      final first = structurer.structure(page('1'), pageNumber: 1);
      // On page one the header is just content: a one-page document's title
      // lives in the same place, and deleting it would be a real bug.
      expect(first.first.isSkippedInReadAloud, isFalse);

      final second = structurer.structure(page('2'), pageNumber: 2);
      final header = second.firstWhere((b) => b.content == 'Sách Giáo Khoa Vật Lý');
      expect(header.isSkippedInReadAloud, isTrue,
          reason: 'a header that repeats across pages is furniture');

      // Page numbers differ only in digits, so they must still be recognized as
      // the same repeating line.
      final footer = second.last;
      expect(footer.isSkippedInReadAloud, isTrue);
    });

    test('a long line in the margin is body text, not furniture', () {
      final structurer = OcrStructurer();
      final long = 'Một câu dài nằm sát lề trên nhưng rõ ràng là văn bản thường '
          'chứ không phải đầu trang chạy.';
      structurer.structure(<OcrLine>[body(long, top: 0.02, height: 0.02)],
          pageNumber: 1);
      final blocks = structurer.structure(
          <OcrLine>[body(long, top: 0.02, height: 0.02)], pageNumber: 2);

      expect(blocks.single.isSkippedInReadAloud, isFalse);
    });

    test('reset() forgets the previous document', () {
      final structurer = OcrStructurer();
      final header = <OcrLine>[body('Đầu trang', top: 0.02, height: 0.02)];

      structurer.structure(header, pageNumber: 1);
      expect(structurer.structure(header, pageNumber: 2).single.isSkippedInReadAloud,
          isTrue);

      structurer.reset();
      expect(structurer.structure(header, pageNumber: 1).single.isSkippedInReadAloud,
          isFalse);
    });
  });

  group('order numbering', () {
    test('startOrder makes a multi-page job gapless', () {
      final structurer = OcrStructurer();
      final first = structurer.structure(
        <OcrLine>[body('Trang một', top: 0.1)],
        pageNumber: 1,
      );
      final second = structurer.structure(
        <OcrLine>[body('Trang hai', top: 0.1)],
        pageNumber: 2,
        startOrder: first.length,
      );

      expect(first.single.order, 0);
      expect(second.single.order, 1);
      expect(second.single.position!.pageNumber, 2);
    });
  });
}
