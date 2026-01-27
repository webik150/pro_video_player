import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';
import 'package:pro_video_player_web/src/managers/video_source_manager.dart';

import '../shared/web_test_fixture.dart';

void main() {
  group('VideoSourceManager', () {
    late WebVideoPlayerTestFixture fixture;
    late VideoSourceManager manager;

    setUp(() {
      fixture = WebVideoPlayerTestFixture();
      fixture.setUp();

      manager = VideoSourceManager(emitEvent: fixture.emitEvent, videoElement: fixture.videoElement);
    });

    tearDown(() async {
      manager.dispose();
      await fixture.tearDown();
    });

    group('source type detection', () {
      test('detects HLS source', () {
        expect(manager.isHlsSource('https://example.com/video.m3u8'), isTrue);
        expect(manager.isHlsSource('https://example.com/video.m3u8?token=abc'), isTrue);
      });

      test('detects DASH source', () {
        expect(manager.isDashSource('https://example.com/video.mpd'), isTrue);
        expect(manager.isDashSource('https://example.com/video.mpd?token=abc'), isTrue);
      });

      test('detects regular video source', () {
        expect(manager.isHlsSource('https://example.com/video.mp4'), isFalse);
        expect(manager.isDashSource('https://example.com/video.mp4'), isFalse);
      });
    });

    group('source URL extraction', () {
      test('extracts network source URL', () {
        const source = VideoSource.network('https://example.com/video.mp4');
        expect(manager.getSourceUrl(source), 'https://example.com/video.mp4');
      });

      test('extracts file source path', () {
        const source = VideoSource.file('/path/to/video.mp4');
        expect(manager.getSourceUrl(source), '/path/to/video.mp4');
      });

      test('extracts asset source path', () {
        const source = VideoSource.asset('videos/intro.mp4');
        expect(manager.getSourceUrl(source), 'assets/videos/intro.mp4');
      });
    });

    group('native source setup', () {
      test('sets native source directly', () {
        manager.setNativeSource('https://example.com/video.mp4');
        expect(fixture.videoElement.src, 'https://example.com/video.mp4');
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
