import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:text_to_voice/core/logging/app_log.dart';

void main() {
  setUp(AppLog.clear);

  group('level filtering', () {
    test('debug level records everything', () {
      AppLog.level = LogLevel.debug;
      AppLog.debug('a');
      AppLog.info('b');
      AppLog.warning('c');
      AppLog.error('d');
      expect(AppLog.entries, hasLength(4));
    });

    test('raising the level drops quieter entries', () {
      AppLog.level = LogLevel.warning;
      AppLog.debug('dropped');
      AppLog.info('dropped');
      AppLog.warning('kept');
      AppLog.error('kept');

      expect(AppLog.entries, hasLength(2));
      expect(AppLog.entries.map((e) => e.message), ['kept', 'kept']);
    });
  });

  group('ring buffer', () {
    test('never grows past the capacity', () {
      AppLog.level = LogLevel.debug;
      for (var i = 0; i < AppLog.capacity + 5; i++) {
        AppLog.info('entry $i');
      }

      expect(AppLog.entries, hasLength(AppLog.capacity));
      expect(AppLog.entries.first.message, 'entry 5',
          reason: 'oldest entries must be evicted first');
      expect(AppLog.entries.last.message, 'entry ${AppLog.capacity + 4}');
    });

    test('entries expose level, time and structured data', () {
      AppLog.info('import.started', data: {'file': 'a.pdf'});
      final entry = AppLog.entries.single;

      expect(entry.level, LogLevel.info);
      expect(entry.at, isNotNull);
      expect(entry.data['file'], 'a.pdf');
      expect(entry.toString(), contains('import.started'));
    });
  });

  group('privacy: never log document content', () {
    const secret = 'Hợp đồng bí mật giữa hai bên, số tài khoản 0123456789.';

    test('textDigest describes text without revealing it', () {
      final digest = AppLog.textDigest(secret);

      expect(digest, startsWith('len='));
      expect(digest, contains('lines=1'));
      expect(digest, contains('hash='));
      for (final word in ['Hợp', 'đồng', 'bí', 'mật', '0123456789']) {
        expect(digest.contains(word), isFalse,
            reason: 'digest leaked "$word"');
      }
    });

    test('digests are stable for the same text and differ for different text',
        () {
      expect(AppLog.textDigest(secret), AppLog.textDigest(secret));
      expect(AppLog.textDigest(secret), isNot(AppLog.textDigest('$secret ')));
    });

    test('empty and null text are handled', () {
      expect(AppLog.textDigest(null), 'len=0');
      expect(AppLog.textDigest(''), 'len=0');
      expect(AppLog.textDigest('\n\n'), contains('lines=3'));
    });
  });

  group('debug console visibility', () {
    // Errors already print; the gap this closes is *stage timings*: info
    // entries like `vieneu.model.ready ms` only lived in the ring buffer, so
    // logcat never showed where a slow synthesis spent its time.
    test('info and warning are printed; debug stays buffered only', () {
      AppLog.level = LogLevel.debug;
      final printed = <String>[];

      runZoned(
        () {
          AppLog.debug('quiet-debug');
          AppLog.info('tts.stage.worker', data: {'ms': 30500});
          AppLog.warning('a-warning');
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => printed.add(line),
        ),
      );

      expect(printed, hasLength(2), reason: 'debug stays out of the console');
      expect(printed[0], contains('[info] tts.stage.worker'));
      expect(printed[0], contains('ms: 30500'));
      expect(printed[1], contains('[warning] a-warning'));
    });
  });
}
