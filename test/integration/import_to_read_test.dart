// The user's path, end to end with the real database and the real router:
// a document is imported (text in the DB), the library lists it, and opening it
// must put that text on the reading surface.
//
// Everything here is real except three things, each named where it is stubbed:
// the audio device, the TTS model, and the app's storage directory.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:text_to_voice/app.dart';
import 'package:text_to_voice/core/router/app_router.dart';
import 'package:text_to_voice/core/storage/app_storage.dart';
import 'package:text_to_voice/data/providers.dart';
import 'package:text_to_voice/domain/models/document.dart';
import 'package:text_to_voice/presentation/read_aloud/read_aloud_providers.dart';

import '../support/fake_audio_output.dart';
import '../support/fake_tts_engine.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  late Directory tempDir;

  const documentId = 'doc-import-1';
  const text = 'Câu một của tài liệu.\n\nCâu hai của tài liệu.';

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('import_flow_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    await appStorage.initialize();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  /// Lets the frame after an interaction settle.
  ///
  /// Not `pumpAndSettle`: opening a document starts reading, and a playing
  /// transport animates forever, so settling never happens. Fixed pumps are the
  /// honest way to wait for a load to finish here.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// The router the running app actually uses. `VietDocApp` builds its own, so
  /// navigating a router this test created would drive nothing at all. Looked up
  /// from the bottom bar, which is below the router and never off-screen —
  /// `find` skips offstage widgets, and a shell branch that is not the current
  /// tab is exactly that.
  GoRouter appRouter(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(NavigationBar)));

  /// Unmounts the app, then lets the disposal-time timers fire.
  ///
  /// Drift closes query streams with a `Timer.run`, scheduled when the last
  /// listener unsubscribes during unmount; flutter_test checks for pending timers
  /// after the body and does not elapse fake time for them on its own.
  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  /// Pumps the real app shell. The TTS model and the audio device are the only
  /// substitutions; the repository, database and screens are the real ones.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDocumentsDirectoryProvider.overrideWith((ref) async => tempDir),
          ttsEngineProvider.overrideWithValue(
            FakeTtsEngine(directory: tempDir),
          ),
          audioOutputProvider.overrideWithValue(FakeAudioOutput()),
        ],
        child: const VietDocApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Writes an imported document exactly as the library does after extraction.
  Future<void> seedImportedDocument(WidgetTester tester) async {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(VietDocApp)),
    );
    await container.read(documentRepositoryProvider).createDocument(
          id: documentId,
          name: 'banan',
          source: DocumentSource.textFile,
          mimeType: 'text/plain',
          fileSize: 64,
          extractedText: text,
          status: DocumentStatus.ready,
        );
  }

  testWidgets('an imported document is listed and opens with its text',
      (tester) async {
    await pumpApp(tester);
    await seedImportedDocument(tester);
    await tester.pumpAndSettle();

    // The row is there, and it is not stuck in the queue.
    expect(find.text('banan'), findsOneWidget);
    expect(find.text('Sẵn sàng'), findsOneWidget);

    // Open it the way a user does: tap the row.
    await tester.tap(find.text('banan'));
    await settle(tester);

    expect(
      find.textContaining('Câu một của tài liệu.'),
      findsWidgets,
      reason: 'the imported text must reach the reading surface',
    );

    await disposeApp(tester);
  });

  testWidgets('a freshly imported document shows text, not "chưa có văn bản"',
      (tester) async {
    await pumpApp(tester);
    await seedImportedDocument(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('banan'));
    await settle(tester);

    expect(find.text('Chưa có văn bản để đọc.'), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('opening a second document replaces the first', (tester) async {
    await pumpApp(tester);
    await seedImportedDocument(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(VietDocApp)),
    );
    final repo = container.read(documentRepositoryProvider);
    await repo.createDocument(
      id: 'doc-import-2',
      name: 'thu hai',
      source: DocumentSource.textFile,
      mimeType: 'text/plain',
      fileSize: 32,
      extractedText: 'Nội dung tài liệu thứ hai.',
      status: DocumentStatus.ready,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('banan'));
    await settle(tester);
    expect(find.textContaining('Câu một của tài liệu.'), findsWidgets);

    // Back to the library, then the other document. The read-aloud tab keeps its
    // state in an indexed stack, so this is the case that used to be ignored.
    appRouter(tester).go(RoutePaths.library);
    await tester.pumpAndSettle();
    await tester.tap(find.text('thu hai'));
    await settle(tester);

    expect(
      find.textContaining('Nội dung tài liệu thứ hai.'),
      findsWidgets,
      reason: 'the second document must replace the first on the surface',
    );

    await disposeApp(tester);
  });
}
