import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:text_to_voice/core/theme/app_theme.dart';
import 'package:text_to_voice/domain/models/reading.dart';
import 'package:text_to_voice/presentation/read_aloud/sentence_block.dart';

void main() {
  Sentence sentence(SentenceStatus status) => Sentence(
        index: 0,
        text: 'Câu thử.',
        blockId: 'b0',
        status: status,
      );

  Future<void> pumpBlock(WidgetTester tester, Sentence s) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SentenceBlock(sentence: s, isCurrent: true),
          ),
        ),
      );

  testWidgets('a synthesizing sentence says it is preparing, visibly',
      (tester) async {
    await pumpBlock(tester, sentence(SentenceStatus.synthesizing));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Đang chuẩn bị câu…'), findsOneWidget);
  });

  testWidgets('a ready sentence carries no preparation indicator',
      (tester) async {
    await pumpBlock(tester, sentence(SentenceStatus.ready));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Đang chuẩn bị câu…'), findsNothing);
  });

  testWidgets('a playing sentence carries no preparation indicator',
      (tester) async {
    await pumpBlock(tester, sentence(SentenceStatus.playing));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Đang chuẩn bị câu…'), findsNothing);
  });
}
