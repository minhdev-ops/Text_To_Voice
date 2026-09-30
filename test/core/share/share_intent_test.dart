import 'dart:async' show StreamController;

import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:text_to_voice/core/share/share_intent.dart';
import 'package:text_to_voice/data/database/app_database.dart' show AppDatabase;
import 'package:text_to_voice/data/providers.dart' show documentRepositoryProvider;
import 'package:text_to_voice/data/repository/document_repository.dart';
import 'package:text_to_voice/presentation/library/library_screen.dart';

/// Stands in for the plugin Phase 3 will install.
class _FakeShareIntentSource implements ShareIntentSource {
  _FakeShareIntentSource();

  final StreamController<SharedFile> controller =
      StreamController<SharedFile>.broadcast();

  @override
  bool get isSupported => true;

  @override
  Stream<SharedFile> get sharedFiles => controller.stream;

  void dispose() => controller.close();
}

void main() {
  group('Phase 0 stub is honest about being a stub', () {
    test('reports unsupported instead of pretending to work', () {
      const source = UnsupportedShareIntentSource();

      expect(source.isSupported, isFalse);
      expect(source.sharedFiles, emitsDone);
    });

    test('the default provider hands out the stub', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(shareIntentSourceProvider),
          isA<UnsupportedShareIntentSource>());
    });

    test('the derived stream settles to a value instead of hanging in loading',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Riverpod starts a StreamProvider only once something listens, which is
      // exactly how Library consumes it. Reading `.future` alone stays lazy.
      container.listen(sharedFilesProvider, (_, _) {});

      await expectLater(
        container.read(sharedFilesProvider.future),
        completion(isNull),
      );
    });
  });

  group('Library surfaces an arrival', () {
    /// The Library reads the repository; without a database it renders its
    /// error state instead of the share banner.
    DocumentRepository memoryRepository() {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      return DocumentRepository(db);
    }

    testWidgets('shows the file name when a shared file arrives',
        (tester) async {
      final source = _FakeShareIntentSource();
      addTearDown(source.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shareIntentSourceProvider.overrideWithValue(source),
            documentRepositoryProvider
                .overrideWithValue(memoryRepository()),
          ],
          child: const MaterialApp(home: LibraryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      source.controller.add(const SharedFile(
        name: 'sach.pdf',
        path: '/tmp/sach.pdf',
        mimeType: 'application/pdf',
        size: 2048,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Đã nhận "sach.pdf".'), findsOneWidget);

      // The banner is a SnackBar with an auto-hide timer; let it fire so the
      // test doesn't end with a pending timer.
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await _disposeTree(tester);
    });

    testWidgets('shows nothing when no file has arrived yet', (tester) async {
      final source = _FakeShareIntentSource();
      addTearDown(source.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shareIntentSourceProvider.overrideWithValue(source),
            documentRepositoryProvider
                .overrideWithValue(memoryRepository()),
          ],
          child: const MaterialApp(home: LibraryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Đã nhận'), findsNothing);
      expect(find.text('Thư viện'), findsWidgets);

      await _disposeTree(tester);
    });
  });
}

/// Unmounts the tree, then lets disposal-time timers fire.
///
/// Drift closes query streams with a `Timer.run` (drift's
/// `StreamQueryStore.markAsClosed`) when the last listener unsubscribes during
/// unmount. flutter_test checks for pending timers after the body, but its own
/// cleanup pump does not elapse fake time — so flush the timer here.
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}
