import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as ja;

import 'package:text_to_voice/core/audio/just_audio_output.dart';
import 'package:text_to_voice/core/logging/app_log.dart';

/// Completes every call, records the order, and can stall or fail on demand.
class FakePlayer extends ja.AudioPlayer {
  FakePlayer()
      : super(
          handleInterruptions: false,
          androidApplyAudioAttributes: false,
          handleAudioSessionActivation: false,
        );

  final List<String> calls = <String>[];
  Duration fileDelay = Duration.zero;
  bool failPlay = false;

  @override
  Future<Duration?> setFilePath(
    String filePath, {
    Duration? initialPosition,
    bool preload = true,
    dynamic tag,
  }) async {
    calls.add('setFilePath');
    if (fileDelay > Duration.zero) {
      await Future<void>.delayed(fileDelay);
    }
    return const Duration(seconds: 1);
  }

  @override
  Future<void> setVolume(double volume) async {
    calls.add('setVolume');
  }

  @override
  Future<void> play() async {
    calls.add('play');
    if (failPlay) throw StateError('player exploded');
  }
}

/// Runs [body] in a zone that records every `print`, then drains microtasks
/// so callbacks attached to already-completed futures have run.
Future<List<String>> capturePrints(Future<void> Function() body) async {
  final printed = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => printed.add(line),
    ),
  );
  await Future<void>.delayed(Duration.zero);
  return printed;
}

void main() {
  setUp(AppLog.clear);

  test('play logs every stage it passes through', () async {
    final player = FakePlayer();
    final output = JustAudioOutput(player: player);

    final printed =
        await capturePrints(() => output.play('/tmp/vieneu_abc.wav'));

    expect(player.calls, <String>['setFilePath', 'setVolume', 'play']);
    final log = printed.join('\n');
    expect(log, contains('audio.play.begin'));
    expect(log, contains('audio.stage'));
    expect(log, contains('stage: setFilePath'));
    expect(log, contains('stage: setVolume'));
    expect(log, contains('audio.play.dispatched'));
    expect(log, contains('audio.play.started'));
  });

  test('a stalled stage warns at the watchdog and still finishes', () async {
    final player = FakePlayer()..fileDelay = const Duration(milliseconds: 150);
    final output = JustAudioOutput(
      player: player,
      watchdogAfter: const Duration(milliseconds: 50),
    );

    final printed = await capturePrints(() => output.play('/tmp/x.wav'));

    final log = printed.join('\n');
    // The warning fires while the stage is pending; the stage's own log
    // follows once it finally returns. Both, in that order, prove the stall.
    expect(log, contains('audio.stage.slow'));
    expect(log, contains('stage: setFilePath'));
    expect(log.indexOf('audio.stage.slow'), lessThan(log.indexOf('stage: setFilePath')));
    // The call itself is untouched: it runs to completion past the warning.
    expect(player.calls, contains('play'));
    expect(log, contains('audio.play.dispatched'));
  });

  test('a failing play is logged as an error, not swallowed', () async {
    final player = FakePlayer()..failPlay = true;
    final output = JustAudioOutput(player: player);

    final printed = await capturePrints(() => output.play('/tmp/x.wav'));

    final log = printed.join('\n');
    expect(log, contains('audio.play.dispatched'));
    expect(log, contains('[error] audio.play.failed'));
  });
}
