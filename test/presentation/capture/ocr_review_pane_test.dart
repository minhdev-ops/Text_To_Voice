import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:text_to_voice/core/theme/app_theme.dart';
import 'package:text_to_voice/domain/imaging/document_scanner.dart';
import 'package:text_to_voice/domain/models/ocr.dart' show OcrLine;
import 'package:text_to_voice/domain/ocr/ocr_structurer.dart';
import 'package:text_to_voice/presentation/capture/capture_providers.dart';
import 'package:text_to_voice/presentation/capture/ocr_review_pane.dart';

import '../../support/fake_ocr_engine.dart' show FakeOcrEngine;
import '../../support/image_fixtures.dart';

/// A page with two recognized lines, one of them uncertain.
///
/// Built through the real scanner and structurer rather than hand-assembled, so
/// the pane is tested against the shapes the app actually produces — a
/// hand-built `ScanOutcome` would keep passing after the scanner's output changed.
CapturedPage buildPage({bool withConfidence = true}) {
  final bytes = pngBytes(syntheticCapture(
    width: 600,
    height: 800,
    pageInset: 0.1,
    textLines: 6,
  ));
  final outcome = scanSynchronously(ScanRequest(bytes: bytes))!;

  final lines = <OcrLine>[
    FakeOcrEngine.line('Dòng thứ nhất rõ ràng',
        top: 0.10, left: 0.10, width: 0.80, height: 0.03,
        confidence: withConfidence ? 0.98 : null),
    FakeOcrEngine.line('Dòng thứ hai mờ',
        top: 0.14, left: 0.10, width: 0.80, height: 0.03,
        confidence: withConfidence ? 0.42 : null),
  ];

  final sections = OcrStructurer().sections(lines, pageNumber: 1);

  return CapturedPage(
    index: 0,
    originalBytes: bytes,
    scan: outcome,
    sections: sections,
    text: 'Dòng thứ nhất rõ ràng\nDòng thứ hai mờ',
  );
}

Widget wrap({
  required CapturedPage page,
  required Size size,
  ReviewSelection? selection,
  bool editing = false,
  bool showOriginal = false,
  ValueChanged<ReviewSelection>? onLineSelected,
  ValueChanged<String>? onTextChanged,
}) {
  return MaterialApp(
    // The real theme, not the Material default: `theme.semanticColors` is an
    // extension this app installs, and a bare theme is missing it by design.
    theme: AppTheme.light(),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: OcrReviewPane(
            page: page,
            selectedLine: selection,
            editing: editing,
            showOriginal: showOriginal,
            imageFraction: 0.4,
            onLineSelected: onLineSelected ?? (_) {},
            onImageFractionChanged: (_) {},
            onTextChanged: onTextChanged ?? (_) {},
          ),
        ),
      ),
    ),
  );
}

/// Gives the test window real room.
///
/// A `SizedBox` cannot be wider than its parent, so a "900 dp" pane inside the
/// default 800×600 test window silently lays out at 800 and takes the stacked
/// branch — the test would then be asserting the wrong layout for the wrong
/// reason, and pass again if the breakpoint changed.
void useSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('compact width stacks the panes with a draggable divider',
      (tester) async {
    useSize(tester, const Size(400, 800));

    await tester.pumpWidget(wrap(page: buildPage(), size: const Size(400, 800)));

    expect(find.byType(VerticalDivider), findsNothing);
    expect(find.text('Dòng thứ nhất rõ ràng'), findsOneWidget);
    expect(find.text('Dòng thứ hai mờ'), findsOneWidget);
  });

  testWidgets('expanded width puts the image and the text side by side',
      (tester) async {
    useSize(tester, const Size(900, 700));
    await tester.pumpWidget(
      wrap(page: buildPage(), size: const Size(900, 700)),
    );

    expect(find.byType(VerticalDivider), findsOneWidget);
  });

  testWidgets('tapping a line reports exactly which line was tapped',
      (tester) async {
    useSize(tester, const Size(900, 700));
    ReviewSelection? selected;
    await tester.pumpWidget(wrap(
      page: buildPage(),
      size: const Size(900, 700),
      onLineSelected: (value) => selected = value,
    ));

    await tester.tap(find.text('Dòng thứ hai mờ'));
    expect(selected, const ReviewSelection(section: 0, line: 1));
  });

  testWidgets('a low-confidence line is underlined with a warning hairline',
      (tester) async {
    await tester.pumpWidget(
      wrap(page: buildPage(), size: const Size(500, 700)),
    );

    final container = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('Dòng thứ hai mờ'),
            matching: find.byType(Container),
          )
          .first,
    );
    final border = container.decoration! as BoxDecoration;
    // A `warning` hairline, not a filled block: the reviewer has to be able to
    // read the text they are judging.
    expect(border.border, isNotNull);
    expect(border.color, isNull);
  });

  testWidgets('a confident line carries no warning hairline', (tester) async {
    await tester.pumpWidget(
      wrap(page: buildPage(), size: const Size(500, 700)),
    );

    final container = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('Dòng thứ nhất rõ ràng'),
            matching: find.byType(Container),
          )
          .first,
    );
    final border = (container.decoration! as BoxDecoration).border! as Border;
    expect(border.bottom.color, Colors.transparent);
  });

  testWidgets('a selection paints the source-region outline', (tester) async {
    useSize(tester, const Size(900, 700));
    await tester.pumpWidget(wrap(
      page: buildPage(),
      size: const Size(900, 700),
      selection: const ReviewSelection(section: 0, line: 0),
    ));

    final outline = find.descendant(
      of: find.byType(Stack),
      matching: find.byType(CustomPaint),
    );
    expect(outline, findsWidgets);
    final painters = tester
        .widgetList<CustomPaint>(outline)
        .map((widget) => widget.painter)
        .whereType<CustomPainter>()
        .map((painter) => painter.runtimeType.toString());
    expect(painters, contains('_SelectionOutlinePainter'));
  });

  testWidgets('nothing selected means nothing painted', (tester) async {
    useSize(tester, const Size(900, 700));
    await tester.pumpWidget(
      wrap(page: buildPage(), size: const Size(900, 700)),
    );

    final painters = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<CustomPainter>()
        .map((painter) => painter.runtimeType.toString());
    expect(painters, isNot(contains('_SelectionOutlinePainter')));
  });

  testWidgets('showing the original says the outline is unavailable',
      (tester) async {
    useSize(tester, const Size(900, 700));
    await tester.pumpWidget(wrap(
      page: buildPage(),
      size: const Size(900, 700),
      selection: const ReviewSelection(section: 0, line: 0),
      showOriginal: true,
    ));

    expect(
      find.textContaining('Vị trí dòng chỉ hiển thị trên bản đã xử lý'),
      findsOneWidget,
    );
    final painters = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<CustomPainter>()
        .map((painter) => painter.runtimeType.toString());
    expect(painters, isNot(contains('_SelectionOutlinePainter')));
  });

  testWidgets('editing mode types into one controller that survives rebuilds',
      (tester) async {
    final typed = <String>[];
    await tester.pumpWidget(wrap(
      page: buildPage(),
      size: const Size(500, 700),
      editing: true,
      onTextChanged: typed.add,
    ));

    final field = find.byType(TextField);
    expect(field, findsOneWidget);

    await tester.enterText(field, 'Chữ đã sửa');
    // The listener received the whole string: a fresh controller per build would
    // have reset the field and reported only the last keystroke.
    expect(typed.last, 'Chữ đã sửa');
  });

  testWidgets('a page with no blocks explains the state instead of going blank',
      (tester) async {
    final page = CapturedPage(
      index: 0,
      originalBytes: pngBytes(syntheticCapture(width: 200, height: 260)),
      textPending: true,
    );

    await tester.pumpWidget(wrap(page: page, size: const Size(500, 700)));

    expect(find.textContaining('chưa nhận dạng được chữ'), findsOneWidget);
  });

  testWidgets('a footnote is visibly marked as skipped in read-aloud',
      (tester) async {
    final page = buildPage();
    final withFootnote = CapturedPage(
      index: 0,
      originalBytes: page.originalBytes,
      scan: page.scan,
      sections: OcrStructurer().sections(<OcrLine>[
        FakeOcrEngine.line('Nội dung chính của trang.',
            top: 0.10, left: 0.10, width: 0.80, height: 0.03),
        FakeOcrEngine.line('1. Chú thích ở chân trang.',
            top: 0.92, left: 0.10, width: 0.80, height: 0.02),
      ]),
    );

    await tester.pumpWidget(
      wrap(page: withFootnote, size: const Size(500, 700)),
    );

    expect(find.text('Chú thích — không đọc thành tiếng'), findsOneWidget);
  });
}
