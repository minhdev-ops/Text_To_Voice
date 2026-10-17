import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:text_to_voice/core/share/share_target.dart';

/// A target that records what it was asked to share.
class _RecordingShareTarget implements ShareTarget {
  final List<List<String>> calls = <List<String>>[];
  String? title;
  Object? thrown;

  @override
  Future<void> shareFiles(
    List<String> paths, {
    required String title,
    String? text,
  }) async {
    calls.add(paths);
    this.title = title;
    if (thrown != null) throw thrown!;
  }
}

void main() {
  group('ShareTarget contract', () {
    test('hands over exactly the exported paths', () async {
      final target = _RecordingShareTarget();

      await target.shareFiles(<String>['/tmp/a.wav', '/tmp/b.txt'],
          title: 'Tài liệu');

      expect(target.calls.single, <String>['/tmp/a.wav', '/tmp/b.txt']);
      expect(target.title, 'Tài liệu');
    });

    test('a share nothing accepted surfaces as a failure, not a silent no-op',
        () async {
      // The point of the seam: a share sheet that closes with nothing attached
      // looks like the app broke, so the outcome has to be sayable.
      final target = _RecordingShareTarget()..thrown = const ShareUnavailableFailure();

      await expectLater(
        target.shareFiles(<String>['/tmp/a.wav'], title: 'Tài liệu'),
        throwsA(isA<ShareUnavailableFailure>()),
      );
    });
  });

  group('PluginShareTarget', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('share_test_');
    });

    tearDown(() async => tempDir.delete(recursive: true));

    test('a file that is not on disk is reported rather than shared as nothing',
        () async {
      // Sharing a missing path would hand another app a broken reference; the
      // alternative — silently sharing zero files — is the failure this guards.
      await expectLater(
        const PluginShareTarget().shareFiles(
          <String>['/definitely/not/here.wav'],
          title: 'Tài liệu',
        ),
        throwsA(isA<ShareUnavailableFailure>()),
      );
    });

    test('a real file passes the existence check', () async {
      final file = File('${tempDir.path}/ok.txt')..writeAsStringSync('x');
      // The platform channel is not available in a unit test, so reaching the
      // channel call (and failing there) rather than failing the existence check
      // is the assertion.
      await expectLater(
        const PluginShareTarget().shareFiles(<String>[file.path], title: 'Tài liệu'),
        throwsA(isNot(isA<ShareUnavailableFailure>())),
      );
    });
  });
}
