import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_web/src/managers/playback_control_manager.dart';

import '../shared/web_test_fixture.dart';

void main() {
  group('PlaybackControlManager', () {
    late WebVideoPlayerTestFixture fixture;
    late PlaybackControlManager manager;

    setUp(() {
      fixture = WebVideoPlayerTestFixture();
      fixture.setUp();

      manager = PlaybackControlManager(emitEvent: fixture.emitEvent, videoElement: fixture.videoElement);
    });

    tearDown(() async {
      manager.dispose();
      await fixture.tearDown();
    });

    group('playback controls', () {
      test('starts playback', () async {
        fixture.videoElement.paused = true;

        await manager.play();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(fixture.videoElement.paused, isFalse);
      });

      test('pauses playback', () async {
        fixture.videoElement.paused = false;

        manager.pause();

        expect(fixture.videoElement.paused, isTrue);
      });

      test('stops playback and resets position', () async {
        fixture.videoElement.paused = false;
        fixture.videoElement.currentTime = 50.0;

        manager.stop();

        expect(fixture.videoElement.paused, isTrue);
        expect(fixture.videoElement.currentTime, 0.0);
      });
    });

    group('seeking', () {
      test('seeks to position', () {
        manager.seekTo(const Duration(seconds: 30));

        expect(fixture.videoElement.currentTime, 30.0);
      });

      test('rejects negative position', () {
        expect(() => manager.seekTo(const Duration(seconds: -5)), throwsArgumentError);
      });
    });

    group('volume control', () {
      test('sets volume', () {
        manager.setVolume(0.7);

        expect(fixture.videoElement.volume, 0.7);
      });

      test('clamps volume to 0.0-1.0 range', () {
        manager.setVolume(1.5);
        expect(fixture.videoElement.volume, 1.0);

        manager.setVolume(-0.5);
        expect(fixture.videoElement.volume, 0.0);
      });
    });

    group('playback speed', () {
      test('sets playback speed', () {
        manager.setPlaybackSpeed(1.5);

        expect(fixture.videoElement.playbackRate, 1.5);
      });

      test('rejects speed <= 0', () {
        expect(() => manager.setPlaybackSpeed(0), throwsArgumentError);

        expect(() => manager.setPlaybackSpeed(-1), throwsArgumentError);
      });

      test('rejects speed > 10', () {
        expect(() => manager.setPlaybackSpeed(11), throwsArgumentError);
      });
    });

    group('looping', () {
      test('gets looping state', () {
        fixture.videoElement.loop = true;
        expect(manager.looping, isTrue);

        fixture.videoElement.loop = false;
        expect(manager.looping, isFalse);
      });

      test('sets looping state', () {
        manager.looping = true;
        expect(fixture.videoElement.loop, isTrue);

        manager.looping = false;
        expect(fixture.videoElement.loop, isFalse);
      });
    });

    group('state queries', () {
      test('gets duration', () {
        fixture.videoElement.duration = 120.5;

        final duration = manager.getDuration();

        expect(duration, const Duration(milliseconds: 120500));
      });

      test('gets position', () {
        fixture.videoElement.currentTime = 45.25;

        final position = manager.getPosition();

        expect(position, const Duration(milliseconds: 45250));
      });

      test('handles infinite duration', () {
        fixture.videoElement.duration = double.infinity;

        final duration = manager.getDuration();

        expect(duration, Duration.zero);
      });

      test('handles NaN duration', () {
        fixture.videoElement.duration = double.nan;

        final duration = manager.getDuration();

        expect(duration, Duration.zero);
      });
    });

    group('disposal', () {
      test('can be disposed', () {
        expect(() => manager.dispose(), returnsNormally);
      });

      test('can be disposed multiple times safely', () {
        manager.dispose();
        expect(() => manager.dispose(), returnsNormally);
      });
    });
  });
}
