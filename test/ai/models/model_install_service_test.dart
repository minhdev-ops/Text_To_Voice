import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:text_to_voice/ai/models/model_download_service.dart';
import 'package:text_to_voice/ai/models/model_install_service.dart';
import 'package:text_to_voice/ai/models/vieneu_model_manifest.dart';
import 'package:text_to_voice/core/result/result.dart';

/// The install path is where a corrupt model becomes a *silent* wrong answer, so
/// the tests here are about the invariants rather than the mechanics: nothing is
/// committed unverified, a cancel leaves no trace, and a size/hash mismatch is
/// reported as `corrupt` (FR-20's `Tải lại`) rather than as "not installed".
///
/// A fake HTTP client keeps this a unit test; the real endpoints are exercised
/// by the desktop end-to-end run.
void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('vieneu_install_test');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  ModelFileSpec spec(String path, List<int> bytes, {String? sha}) => ModelFileSpec(
        relativePath: path,
        url: 'https://example.test/$path',
        sizeBytes: bytes.length,
        sha256: sha ?? sha256.convert(bytes).toString(),
      );

  MockClient serving(Map<String, List<int>> files) => MockClient((request) async {
        final body = files[request.url.path.replaceFirst('/', '')];
        if (body == null) return http.Response('not found', 404);
        return http.Response.bytes(body, 200);
      });

  group('download', () {
    test('writes the file, verifies it, and reports progress', () async {
      final bytes = utf8.encode('hello model');
      final service = ModelDownloadService(
        client: serving(<String, List<int>>{'a.bin': bytes}),
      );
      final progress = <int>[];

      final result = await service.download(
        spec('a.bin', bytes),
        root: root,
        onProgress: (received, total) => progress.add(received),
      );

      expect(result.valueOrNull, isNotNull);
      expect(File('${root.path}/a.bin').readAsBytesSync(), bytes);
      expect(progress, isNotEmpty);
      expect(progress.last, bytes.length);
      // No partial file survives a success.
      expect(File('${root.path}/a.bin.part').existsSync(), isFalse);
    });

    test('a wrong hash commits nothing and leaves no .part', () async {
      final bytes = utf8.encode('hello model');
      final service = ModelDownloadService(
        client: serving(<String, List<int>>{'a.bin': bytes}),
      );

      final result = await service.download(
        spec('a.bin', bytes, sha: 'f' * 64),
        root: root,
      );

      expect(result.failureOrNull, isA<CorruptModelFailure>());
      expect(File('${root.path}/a.bin').existsSync(), isFalse);
      expect(File('${root.path}/a.bin.part').existsSync(), isFalse);
    });

    test('a truncated stream is caught by the size check', () async {
      final bytes = utf8.encode('hello model');
      final service = ModelDownloadService(
        client: serving(<String, List<int>>{'a.bin': bytes}),
      );
      final wrongSize = ModelFileSpec(
        relativePath: 'a.bin',
        url: 'https://example.test/a.bin',
        sizeBytes: bytes.length + 100,
        sha256: sha256.convert(bytes).toString(),
      );

      final result = await service.download(wrongSize, root: root);
      expect(result.failureOrNull, isA<CorruptModelFailure>());
      expect(File('${root.path}/a.bin').existsSync(), isFalse);
    });

    test('a cancel removes the partial file and reports a cancel', () async {
      final bytes = utf8.encode('hello model');
      final service = ModelDownloadService(
        client: serving(<String, List<int>>{'a.bin': bytes}),
      );

      final result = await service.download(
        spec('a.bin', bytes),
        root: root,
        shouldCancel: () async => true,
      );

      expect(result.failureOrNull, isA<CancelledFailure>());
      expect(File('${root.path}/a.bin').existsSync(), isFalse);
      expect(File('${root.path}/a.bin.part').existsSync(), isFalse);
    });

    test('a 404 is a storage failure naming the file', () async {
      final service = ModelDownloadService(
        client: serving(<String, List<int>>{}),
      );
      final result = await service.download(
        spec('missing.bin', <int>[1, 2, 3]),
        root: root,
      );
      expect(result.failureOrNull, isA<StorageFailure>());
      expect(result.failureOrNull!.message, contains('missing.bin'));
    });
  });

  group('install state machine', () {
    ModelInstallService serviceFor(List<ModelFileSpec> files) => ModelInstallService(
          root: root,
          files: files,
          platform: 'linux',
          downloads: ModelDownloadService(
            client: serving(<String, List<int>>{
              for (final file in files)
                file.relativePath: utf8.encode('payload-${file.relativePath}'),
            }),
          ),
        );

    // Both mock clients below serve `payload-<relativePath>`, so the spec bytes
    // (and therefore the expected size and hash) must be built the same way —
    // otherwise every install fails its own integrity check.
    List<ModelFileSpec> smallFiles() {
      final first = utf8.encode('payload-vieneu-v3-turbo-int8/part-one.bin');
      final second = utf8.encode('payload-codec-nano/part-two.bin');
      return <ModelFileSpec>[
        spec('vieneu-v3-turbo-int8/part-one.bin', first),
        spec('codec-nano/part-two.bin', second),
      ];
    }

    test('a fresh directory audits as notInstalled, not corrupt', () async {
      final state = await serviceFor(smallFiles()).audit();
      expect(state.stage, ModelInstallStage.notInstalled);
      expect(state.totalBytes, greaterThan(0));
      expect(state.failure, isNull);
    });

    test('a full install ends installed and reports monotonic progress', () async {
      final service = serviceFor(smallFiles());
      final stages = <ModelInstallState>[];
      final finalState = await service.install(onState: stages.add);

      expect(finalState.stage, ModelInstallStage.installed);
      expect(finalState.installedBytes, service.totalBytes);
      expect(stages.first.stage, ModelInstallStage.downloading);
      expect(stages.last.stage, ModelInstallStage.installed);
      // Progress must never go backwards: the bar is the only feedback during a
      // 280 MB download.
      var previous = -1;
      for (final state in stages) {
        expect(state.receivedBytes, greaterThanOrEqualTo(previous));
        previous = state.receivedBytes;
      }
      expect((await service.audit()).stage, ModelInstallStage.installed);
    });

    test('a partial install audits as corrupt, with the missing count', () async {
      final files = smallFiles();
      final service = serviceFor(files);
      await service.install();
      File('${root.path}/${files.last.relativePath}').deleteSync();

      final state = await service.audit();
      expect(state.stage, ModelInstallStage.corrupt);
      expect(state.failure!.message, contains('thiếu'));
    });

    test('a leftover .part file audits as corrupt, not as a fresh install',
        () async {
      final service = serviceFor(smallFiles());
      final stale = File('${root.path}/vieneu-v3-turbo-int8/big.onnx.part')
        ..createSync(recursive: true)
        ..writeAsStringSync('half a download');

      final state = await service.audit();
      expect(state.stage, ModelInstallStage.corrupt);
      expect(stale.existsSync(), isTrue, reason: 'audit does not delete things');

      await service.delete();
      expect(stale.existsSync(), isFalse);
    });

    test('re-installing skips files that are already correct', () async {
      final files = smallFiles();
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        final path = request.url.path.replaceFirst('/', '');
        return http.Response.bytes(utf8.encode('payload-$path'), 200);
      });
      final service = ModelInstallService(
        root: root,
        files: files,
        platform: 'linux',
        downloads: ModelDownloadService(client: client),
      );

      await service.install();
      expect(requests, files.length);
      await service.install();
      expect(requests, files.length, reason: 'a second install re-downloads nothing');
    });

    test('a cancelled install reports notInstalled and leaves no file', () async {
      final service = serviceFor(smallFiles());
      final stages = <ModelInstallState>[];
      service.cancel();
      final finalState = await service.install(onState: stages.add);

      expect(finalState.stage, ModelInstallStage.notInstalled);
      expect(finalState.failure, isNull, reason: 'a cancel is not an error');
      expect(Directory('${root.path}/vieneu-v3-turbo-int8').existsSync(), isFalse);
    });

    test('verify catches a file whose bytes changed under the same size',
        () async {
      final files = smallFiles();
      final service = serviceFor(files);
      await service.install();

      // Same length, different content: only the hash can see this, and a model
      // that silently changed is the case hashing exists for.
      final target = File('${root.path}/${files.first.relativePath}');
      final bytes = target.readAsBytesSync();
      bytes[0] = bytes[0] ^ 0xFF;
      target.writeAsBytesSync(bytes);

      final state = await service.verify();
      expect(state.stage, ModelInstallStage.corrupt);
      expect(state.failure!.detail, contains('hash mismatch'));
    });

    test('delete removes every file and the now-empty component directory',
        () async {
      final service = serviceFor(smallFiles());
      await service.install();
      expect(File('${root.path}/${service.files.first.relativePath}').existsSync(), isTrue);

      final state = await service.delete();
      expect(state.stage, ModelInstallStage.notInstalled);
      expect(File('${root.path}/${service.files.first.relativePath}').existsSync(), isFalse);
      expect(Directory('${root.path}/vieneu-v3-turbo-int8').existsSync(), isFalse);
    });
  });
}
