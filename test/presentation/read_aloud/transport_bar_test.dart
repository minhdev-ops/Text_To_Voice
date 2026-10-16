import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:text_to_voice/core/theme/app_theme.dart';
import 'package:text_to_voice/presentation/read_aloud/transport_bar.dart';

void main() {
  // The bar is a fixed Row: play controls, sentence counter, speed chip, voice
  // name and the time label. On a narrow phone a long voice name plus a long
  // time label ("12:34 / 1:23:45") used to push the row past the right edge —
  // the yellow overflow stripes the reader saw the moment playback started.
  testWidgets(
    'a long voice name and a long time label do not overflow the bar',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TransportBar(
              ruler: const SizedBox(height: 48),
              isPlaying: true,
              onPlayPause: () {},
              onPrevious: () {},
              onNext: () {},
              onSpeedTap: () {},
              onVoiceTap: () {},
              speedLabel: '1.0×',
              voiceLabel: 'Người Kể Chuyện Hải Đăng',
              sentenceLabel: 'Câu 123/456',
              timeLabel: '12:34 / 1:23:45',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );
}
