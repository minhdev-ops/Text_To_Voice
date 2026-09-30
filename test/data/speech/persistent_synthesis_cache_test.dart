import 'dart:io';

import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:text_to_voice/data/database/app_database.dart' show AppDatabase;
import 'package:text_to_voice/data/repository/document_repository.dart';
import 'package:text_to_voice/data/speech/persistent_synthesis_cache.dart';
import 'package:text_to_voice/domain/models/tts.dart';

void main() {
  group('PersistentSynthesisCache', () {
    late AppDatabase database;
    late DocumentRepository repository;
    late PersistentSynthesisCache cache;
    late Directory tempDir;

    /// `getCachedAudio` verifies the file is still on disk, so a cache entry
    /// only round-trips when its audio file actually exists.
    late File audioFile;

    /// The cache's key is opaque — it comes from `TtsOptions.cacheKey`, which
    /// folds voice, speed and format in alongside the normalized text. That is
    /// what keeps SRS §32's "never re-synthesize" rule from serving audio that
    /// was synthesized for different options.
    String keyFor({
      String? voiceId = 'voice1',
      double speed = 1.0,
      SpeechFormat format = SpeechFormat.wav,
      String text = 'xin chào',
    }) =>
        TtsOptions(voiceId: voiceId, speed: speed, format: format)
            .cacheKey(text);

    AudioResult audioFor(
      String path, {
      String? voiceId = 'voice1',
      double speed = 1.0,
      String? textHash,
    }) =>
        AudioResult(
          path: path,
          duration: const Duration(seconds: 5),
          textHash: textHash ?? path,
          sampleRate: 24000,
          channels: 1,
          voiceId: voiceId,
          speed: speed,
        );

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('test_cache_');
      final dbFile = File(p.join(tempDir.path, 'test_cache.db'));
      database = AppDatabase(NativeDatabase(dbFile));
      repository = DocumentRepository(database);
      cache = PersistentSynthesisCache(repository);
      audioFile = File(p.join(tempDir.path, 'audio.wav'))
        ..writeAsStringSync('RIFF-fake-wav');
    });

    tearDown(() async {
      await database.close();
      await tempDir.delete(recursive: true);
    });

    test('cache miss returns null', () async {
      expect(await cache.find(keyFor()), isNull);
    });

    test('save then find round-trips the audio', () async {
      final key = keyFor();
      await cache.save(key, audioFor(audioFile.path, textHash: key));

      final result = await cache.find(key);
      expect(result, isNotNull);
      expect(result!.path, audioFile.path);
      expect(result.textHash, key);
      expect(result.duration, const Duration(seconds: 5));
      expect(result.voiceId, 'voice1');
      expect(result.speed, 1.0);
      expect(result.cacheHit, isTrue);
    });

    test('different voiceId creates separate cache entries', () async {
      final fileA = File(p.join(tempDir.path, 'voice1.wav'))
        ..writeAsStringSync('a');
      final fileB = File(p.join(tempDir.path, 'voice2.wav'))
        ..writeAsStringSync('b');

      final keyA = keyFor(voiceId: 'voice1');
      final keyB = keyFor(voiceId: 'voice2');
      await cache.save(keyA, audioFor(fileA.path, voiceId: 'voice1'));
      await cache.save(keyB, audioFor(fileB.path, voiceId: 'voice2'));

      final first = await cache.find(keyA);
      final second = await cache.find(keyB);
      expect(first, isNotNull);
      expect(first!.path, fileA.path);
      expect(second, isNotNull);
      expect(second!.path, fileB.path);
    });

    test('different speed creates separate cache entries', () async {
      final slowFile = File(p.join(tempDir.path, 'slow.wav'))
        ..writeAsStringSync('slow');
      final fastFile = File(p.join(tempDir.path, 'fast.wav'))
        ..writeAsStringSync('fast');

      final slowKey = keyFor(speed: 0.5);
      final fastKey = keyFor(speed: 2.0);
      await cache.save(slowKey, audioFor(slowFile.path, speed: 0.5));
      await cache.save(fastKey, audioFor(fastFile.path, speed: 2.0));

      final slow = await cache.find(slowKey);
      final fast = await cache.find(fastKey);
      expect(slow, isNotNull);
      expect(slow!.path, slowFile.path);
      expect(slow.speed, 0.5);
      expect(fast, isNotNull);
      expect(fast!.path, fastFile.path);
      expect(fast.speed, 2.0);
    });

    test('different format creates separate cache entries', () async {
      final wavFile = File(p.join(tempDir.path, 'fmt.wav'))
        ..writeAsStringSync('wav');
      final mp3File = File(p.join(tempDir.path, 'fmt.mp3'))
        ..writeAsStringSync('mp3');

      final wavKey = keyFor(format: SpeechFormat.wav);
      final mp3Key = keyFor(format: SpeechFormat.mp3);
      await cache.save(wavKey, audioFor(wavFile.path));
      await cache.save(mp3Key, audioFor(mp3File.path));

      expect(wavKey, isNot(mp3Key));
      final wav = await cache.find(wavKey);
      final mp3 = await cache.find(mp3Key);
      expect(wav, isNotNull);
      expect(wav!.path, wavFile.path);
      expect(mp3, isNotNull);
      expect(mp3!.path, mp3File.path);
    });

    test('cache without voiceId works', () async {
      final file = File(p.join(tempDir.path, 'no_voice.wav'))
        ..writeAsStringSync('nv');
      final key = keyFor(voiceId: null);

      await cache.save(key, audioFor(file.path, voiceId: null));

      final result = await cache.find(key);
      expect(result, isNotNull);
      expect(result!.voiceId, isNull);
      expect(result.path, file.path);
    });

    test('entry whose audio file is gone counts as a miss', () async {
      final key = keyFor();
      await cache.save(key, audioFor(p.join(tempDir.path, 'deleted.wav')));

      expect(await cache.find(key), isNull);
    });

    // Regression: on-device a real sentence key is
    // `null|1.00|wav|<hundreds of characters>`, far past the
    // `tts_audio.textHash` column's 64-character cap — the insert threw
    // InvalidDataException inside `_synthesize`, before playback could start.
    test('a full-sentence key longer than 64 characters round-trips',
        () async {
      const sentence =
          'Thanh niên - Sinh viên khoa Công nghệ Thông tin năm học hai nghìn '
          'không trăm hai mươi bốn - hai nghìn không trăm hai mươi lăm Có thành '
          'tích xuất sắc trong công tác Đoàn - Hội và phong trào';
      final key = keyFor(text: sentence);
      expect(key.length, greaterThan(64));

      await cache.save(key, audioFor(audioFile.path, textHash: key));

      final result = await cache.find(key);
      expect(result, isNotNull);
      expect(result!.path, audioFile.path);
      expect(result.textHash, key);
      expect(result.cacheHit, isTrue);
    });
  });
}
