// Does sound actually come out of the speaker?
//
// Reported symptom: the app writes WAV files but nothing is audible. The files
// were checked on the device and were fine (peak 22–30k of 32767, RMS ~3.4k,
// 48 kHz mono, 94–99% non-zero samples), so the fault sits between a correct
// file and the speaker — which is plugin and device behaviour that no unit test
// can reach.
//
// **Self-contained on purpose.** An earlier version of this probe played a file
// already in the app's storage, which meant it silently depended on the user
// having run a read first — and running it on a device destroyed the state it
// needed. It now writes its own tone, so it answers the same question on a
// freshly installed app with nothing else present.
//
// ⚠ Running this uninstalls the app afterwards: `flutter test integration_test`
// installs a test build under the app's own package and removes it when it
// finishes, taking `/data/data/<package>` with it. On a device with a real
// install, that means lost downloads, documents and history. Use a spare device
// or emulator, or accept the loss deliberately.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:path_provider/path_provider.dart';

import 'package:text_to_voice/core/audio/just_audio_output.dart';

/// A 440 Hz tone, written as 16-bit PCM mono at [sampleRate].
Uint8List _toneWav({required double seconds, int sampleRate = 48000}) {
  final frames = (seconds * sampleRate).round();
  final header = ByteData(44);
  final pcm = ByteData(frames * 2);
  for (var i = 0; i < frames; i++) {
    final value =
        (math.sin(2 * math.pi * 440 * i / sampleRate) * 12000).round();
    pcm.setInt16(i * 2, value, Endian.little);
  }

  void ascii(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      header.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + pcm.lengthInBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little); // PCM header size
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, 1, Endian.little); // mono
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  header.setUint16(32, 2, Endian.little); // block align
  header.setUint16(34, 16, Endian.little); // bits per sample
  ascii(36, 'data');
  header.setUint32(40, pcm.lengthInBytes, Endian.little);

  return Uint8List.fromList(<int>[...header.buffer.asUint8List(), ...pcm.buffer.asUint8List()]);
}

void main() {
  testWidgets('a synthesized sentence actually plays out loud', (tester) async {
    final documents = await getApplicationDocumentsDirectory();
    final tone = File('${documents.path}/probe_tone.wav');
    await tone.writeAsBytes(_toneWav(seconds: 4), flush: true);
    // ignore: avoid_print
    print('PROBE wrote ${tone.path} ${tone.lengthSync()} bytes');

    // A bare player beside the app's, so the two can be compared: if the bare
    // one is silent too, the device or the plugin is at fault, not our code.
    final bare = ja.AudioPlayer();
    bare.errorStream.listen((e) {
      // ignore: avoid_print
      print('PROBE bare error ${e.code}: ${e.message}');
    });
    await bare.setFilePath(tone.path);
    unawaited(bare.play().then((_) {}, onError: (Object e) {
      // ignore: avoid_print
      print('PROBE bare play rejected: $e');
    }));
    await Future<void>.delayed(const Duration(seconds: 2));
    // ignore: avoid_print
    print('PROBE bare playing=${bare.playing} '
        'state=${bare.processingState.name} pos=${bare.position}');
    await bare.dispose();

    // The app's own output — this is what a user actually hears.
    final output = JustAudioOutput();
    final positions = <int>[];
    output.position.listen((p) => positions.add(p.inMilliseconds));

    await output.play(tone.path, volume: 1.0);
    await Future<void>.delayed(const Duration(seconds: 3));

    final furthest = positions.fold<int>(0, math.max);
    // ignore: avoid_print
    print('PROBE app positions=$positions furthest=${furthest}ms');
    await output.dispose();

    expect(furthest,
        greaterThan(500),
        reason: 'the player reported no progress: playback never started');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
