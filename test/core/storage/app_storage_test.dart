import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:text_to_voice/core/storage/app_storage.dart';

/// Points path_provider at this test's temp directory so `initialize()` runs
/// for real without touching the (unmocked) platform channel.
class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  group('AppStorage', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('app_storage_test_');
      PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
      await AppStorage().initialize();
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('initialize creates all directories', () async {
      expect(AppStorage().base, isA<Directory>());
      expect(AppStorage().modelsDir, isA<Directory>());
      expect(AppStorage().exportsDir, isA<Directory>());
      expect(AppStorage().tempDir, isA<Directory>());

      for (final name in const ['documents', 'audio', 'models', 'exports', 'temp']) {
        expect(Directory(p.join(tempDir.path, name)).existsSync(), isTrue,
            reason: '$name should exist after initialize');
      }
    });

    test('documentDir creates correct path', () {
      const docId = 'test-doc-123';
      final dir = AppStorage().documentDir(docId);
      expect(dir.path, endsWith(p.join('documents', docId)));
    });

    test('documentPagesDir creates correct path', () {
      const docId = 'test-doc-123';
      final dir = AppStorage().documentPagesDir(docId);
      expect(dir.path, endsWith(p.join('documents', docId, 'pages')));
    });

    test('documentImagesDir creates correct path', () {
      const docId = 'test-doc-123';
      final dir = AppStorage().documentImagesDir(docId);
      expect(dir.path, endsWith(p.join('documents', docId, 'images')));
    });

    test('audioDir creates correct path', () {
      const docId = 'test-doc-123';
      final dir = AppStorage().audioDir(docId);
      expect(dir.path, endsWith(p.join('audio', docId)));
    });

    test('modelDir creates correct path', () {
      const modelId = 'model-123';
      final dir = AppStorage().modelDir(modelId);
      expect(dir.path, endsWith(p.join('models', modelId)));
    });

    test('tempFilePath creates unique paths', () {
      final path1 = AppStorage().tempFilePath('prefix', 'wav');
      final path2 = AppStorage().tempFilePath('prefix', 'wav');
      expect(path1, isNot(equals(path2)));
      expect(path1, contains('prefix_'));
      expect(path1, endsWith('.wav'));
    });

    test('tempSubDir creates unique directories', () {
      final dir1 = AppStorage().tempSubDir('prefix');
      final dir2 = AppStorage().tempSubDir('prefix');
      expect(dir1.path, isNot(equals(dir2.path)));
      expect(dir1.path, contains('prefix_'));
    });
  });
}
