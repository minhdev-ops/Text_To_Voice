// Smoke test for the Phase 0 shell: the app boots, the four destinations are
// all reachable through the bottom bar, and an unknown route degrades to a
// screen that says what it could not find.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:text_to_voice/app.dart';
import 'package:text_to_voice/core/router/app_router.dart';
import 'package:text_to_voice/core/theme/app_theme.dart';
import 'package:text_to_voice/data/providers.dart'
    show appDocumentsDirectoryProvider;

void main() {
  // Mirrors main(): VietDocApp is a ConsumerWidget, so the scope is part of
  // the composition root rather than something the widget creates itself.
  // The one substitution is path_provider, which has no platform channel in
  // tests — everything above it (repository, database, screens) stays real.
  //
  // The directory is created in setUp: real dart:io never completes inside
  // the fake-async zone a testWidgets body runs in.
  late Directory docsDir;

  setUp(() async {
    docsDir = await Directory.systemTemp.createTemp('widget_test_');
  });

  tearDown(() async {
    await docsDir.delete(recursive: true);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDocumentsDirectoryProvider.overrideWith((ref) async => docsDir),
        ],
        child: const VietDocApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Unmounts the app, then lets the disposal-time timers fire.
  ///
  /// Drift closes query streams with a `Timer.run` (see drift's
  /// `StreamQueryStore.markAsClosed`), scheduled when the last listener — the
  /// riverpod StreamProvider — unsubscribes during unmount. flutter_test checks
  /// for pending timers after the body, but its own cleanup pump does not elapse
  /// fake time, so that timer must be flushed here instead.
  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets('app boots into the Library tab', (tester) async {
    await pumpApp(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Thư viện'), findsWidgets);

    await disposeApp(tester);
  });

  testWidgets('bottom bar reaches all four destinations', (tester) async {
    await pumpApp(tester);

    // 'Thư viện' is already selected; visit the other three and come back.
    for (final label in const ['Đọc', 'Mô hình', 'Cài đặt', 'Thư viện']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(find.text(label).last, findsWidgets, reason: '$label not reached');
    }

    expect(RoutePaths.all, hasLength(4));
    expect(
      RoutePaths.all.toSet(),
      hasLength(4),
      reason: 'destination paths must be unique',
    );

    await disposeApp(tester);
  });

  testWidgets('unknown route names the path it could not find', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const RouteNotFoundScreen(attempted: '/khong-ton-tai'),
      ),
    );

    expect(find.textContaining('/khong-ton-tai'), findsOneWidget);
    expect(find.text('Về Thư viện'), findsOneWidget);
  });

  testWidgets('read aloud tab tells the truth about the missing model',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Đọc').last);
    await tester.pumpAndSettle();

    // The app ships without a Vietnamese checkpoint (SRS §47: per-checkpoint
    // licenses), so the tab names that state and offers the real next step
    // rather than a button that produces nothing. Typing does not change it.
    expect(find.text('Chưa có model đọc tiếng Việt'), findsOneWidget);
    expect(find.text('Mở Models'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Xin chào Việt Nam');
    await tester.pumpAndSettle();
    expect(find.text('Sẽ đọc 1 câu, theo từng câu một.'), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Đọc thành tiếng'),
    );
    expect(button.onPressed, isNull, reason: 'nothing can read it yet');

    await disposeApp(tester);
  });
}
