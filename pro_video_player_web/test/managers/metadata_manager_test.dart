import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';
import 'package:pro_video_player_web/src/managers/metadata_manager.dart';

import '../shared/mock_js_interop.dart';
import '../shared/web_test_fixture.dart';

void main() {
  group('MetadataManager', () {
    late WebVideoPlayerTestFixture fixture;
    late MetadataManager manager;

    setUp(() {
      fixture = WebVideoPlayerTestFixture();
      fixture.setUp();
      manager = MetadataManager(emitEvent: fixture.emitEvent, videoElement: fixture.videoElement);
    });

    tearDown(() async {
      manager.dispose();
      await fixture.tearDown();
    });

    group('basic metadata extraction', () {
      test('extracts width and height from video element', () async {
        fixture.videoElement.videoWidth = 1920;
        fixture.videoElement.videoHeight = 1080;
        fixture.videoElement.readyState = 4;

        await manager.extractAndEmit(sourceUrl: 'https://example.com/video.mp4');
        await Future<void>.delayed(Duration.zero);

        final event = fixture.verifyEventEmitted<VideoMetadataExtractedEvent>();
        expect(event.metadata.width, 1920);
        expect(event.metadata.height, 1080);
      });

      test('extracts duration from video element', () async {
        fixture.videoElement.duration = 120.5;
        fixture.videoElement.readyState = 4;

        await manager.extractAndEmit(sourceUrl: 'https://example.com/video.mp4');
        await Future<void>.delayed(Duration.zero);

        final event = fixture.verifyEventEmitted<VideoMetadataExtractedEvent>();
        expect(event.metadata.duration, const Duration(milliseconds: 120500));
      });

      test('returns null width/height when 0', () async {
        fixture.videoElement.videoWidth = 0;
        fixture.videoElement.videoHeight = 0;
        fixture.videoElement.readyState = 4;

        await manager.extractAndEmit(sourceUrl: 'https://example.com/video.mp4');
        await Future<void>.delayed(Duration.zero);

        final event = fixture.verifyEventEmitted<VideoMetadataExtractedEvent>();
        expect(event.metadata.width, isNull);
        expect(event.metadata.height, isNull);
      });

      test('returns null duration when NaN', () async {
        fixture.videoElement.duration = double.nan;
        fixture.videoElement.readyState = 4;

        await manager.extractAndEmit(sourceUrl: 'https://example.com/video.mp4');
        await Future<void>.delayed(Duration.zero);

        final event = fixture.verifyEventEmitted<VideoMetadataExtractedEvent>();
        expect(event.metadata.duration, isNull);
      });

      test('returns null duration when infinite', () async {
        fixture.videoElement.duration = double.infinity;
        fixture.videoElement.readyState = 4;

        await manager.extractAndEmit(sourceUrl: 'https://example.com/video.mp4');
        await Future<void>.delayed(Duration.zero);

        final event = fixture.verifyEventEmitted<VideoMetadataExtractedEvent>();
        expect(event.metadata.duration, isNull);
      });

      test('does not emit event when metadata not ready', () async {
        fixture.videoElement.readyState = 0; // HAVE_NOTHING
        fixture.clearEmittedEvents();

        await manager.extractAndEmit(sourceUrl: 'https://example.com/video.mp4');
        await Future<void>.delayed(Duration.zero);

        expect(fixture.emittedEvents.whereType<VideoMetadataExtractedEvent>().isEmpty, isTrue);
      });
    });

    group('container format inference', () {
      test('infers MP4 from .mp4 extension', () async {
        fixture.videoElement.readyState = 4;

        await manager.extractAndEmit(sourceUrl: 'https://example.com/video.mp4');
        await Future<void>.delayed(Duration.zero);

        final event = fixture.verifyEventEmitted<VideoMetadataExtractedEvent>();
        expect(event.metadata.containerFormat, 'mp4');
      });

      test('infers WebM from .webm extension', () async {
        fixture.videoElement.readyState = 4;

        await manager.extractAndEmit(sourceUrl: 'https://example.com/video.webm');
        await Future<void>.delayed(Duration.zero);

        final event = fixture.verifyEventEmitted<VideoMetadataExtractedEvent>();
        expect(event.metadata.containerFormat, 'webm');
      });

      test('infers HLS from .m3u8 extension', () async {
        fixture.videoElement.readyState = 4;

        await manager.extractAndEmit(sourceUrl: 'https://example.com/playlist.m3u8');
        await Future<void>.delayed(Duration.zero);

        final event = fixture.verifyEventEmitted<VideoMetadataExtractedEvent>();
        expect(event.metadata.containerFormat, 'hls');
      });

      test('infers DASH from .mpd extension', () async {
        fixture.videoElement.readyState = 4;

        await manager.extractAndEmit(sourceUrl: 'https://example.com/manifest.mpd');
        await Future<void>.delayed(Duration.zero);

        final event = fixture.verifyEventEmitted<VideoMetadataExtractedEvent>();
        expect(event.metadata.containerFormat, 'dash');
      });

      test('handles URLs with query parameters', () async {
        fixture.videoElement.readyState = 4;

        await manager.extractAndEmit(sourceUrl: 'https://example.com/video.mp4?token=abc123');
        await Future<void>.delayed(Duration.zero);

        final event = fixture.verifyEventEmitted<VideoMetadataExtractedEvent>();
        expect(event.metadata.containerFormat, 'mp4');
      });

      test('returns null for unknown extension', () async {
        fixture.videoElement.readyState = 4;

        await manager.extractAndEmit(sourceUrl: 'https://example.com/video.xyz');
        await Future<void>.delayed(Duration.zero);

        final event = fixture.verifyEventEmitted<VideoMetadataExtractedEvent>();
        expect(event.metadata.containerFormat, isNull);
      });
    });

    group('HLS metadata extraction', () {
      test('extracts codec info from HLS.js', () async {
        final hlsPlayer = MockHlsPlayer();
        hlsPlayer.levels = [MockHlsLevel(height: 1080, bitrate: 5000000, width: 1920, name: '1080p')];
        hlsPlayer.currentLevel = 0;

        fixture.videoElement.readyState = 4;

        await manager.extractAndEmit(sourceUrl: 'https://example.com/playlist.m3u8', hlsPlayer: hlsPlayer);
        await Future<void>.delayed(Duration.zero);

        final event = fixture.verifyEventEmitted<VideoMetadataExtractedEvent>();
        expect(event.metadata.videoBitrate, 5000000);
      });

      test('parses video codec from codecs string', () async {
        final hlsPlayer = MockHlsPlayer();
        hlsPlayer.levels = [MockHlsLevel(height: 1080, bitrate: 5000000, codecs: 'avc1.64001f,mp4a.40.2')];
        hlsPlayer.currentLevel = 0;

        fixture.videoElement.readyState = 4;

        await manager.extractAndEmit(sourceUrl: 'https://example.com/playlist.m3u8', hlsPlayer: hlsPlayer);
        await Future<void>.delayed(Duration.zero);

        final event = fixture.verifyEventEmitted<VideoMetadataExtractedEvent>();
        expect(event.metadata.videoCodec, 'avc1.64001f');
        expect(event.metadata.audioCodec, 'mp4a.40.2');
      });

      test('parses HEVC codec', () async {
        final hlsPlayer = MockHlsPlayer();
        hlsPlayer.levels = [MockHlsLevel(height: 1080, bitrate: 5000000, codecs: 'hvc1.1.6.L120.90,mp4a.40.2')];
        hlsPlayer.currentLevel = 0;

        fixture.videoElement.readyState = 4;

        await manager.extractAndEmit(sourceUrl: 'https://example.com/playlist.m3u8', hlsPlayer: hlsPlayer);
        await Future<void>.delayed(Duration.zero);

        final event = fixture.verifyEventEmitted<VideoMetadataExtractedEvent>();
        expect(event.metadata.videoCodec, 'hvc1.1.6.L120.90');
      });

      test('parses VP9 codec', () async {
        final hlsPlayer = MockHlsPlayer();
        hlsPlayer.levels = [MockHlsLevel(height: 1080, bitrate: 5000000, codecs: 'vp09.00.10.08,opus')];
        hlsPlayer.currentLevel = 0;

        fixture.videoElement.readyState = 4;

        await manager.extractAndEmit(sourceUrl: 'https://example.com/playlist.m3u8', hlsPlayer: hlsPlayer);
        await Future<void>.delayed(Duration.zero);

        final event = fixture.verifyEventEmitted<VideoMetadataExtractedEvent>();
        expect(event.metadata.videoCodec, 'vp09.00.10.08');
        expect(event.metadata.audioCodec, 'opus');
      });

      test('handles missing codecs string', () async {
        final hlsPlayer = MockHlsPlayer();
        hlsPlayer.levels = [MockHlsLevel(height: 1080, bitrate: 5000000)];
        hlsPlayer.currentLevel = 0;

        fixture.videoElement.readyState = 4;

        await manager.extractAndEmit(sourceUrl: 'https://example.com/playlist.m3u8', hlsPlayer: hlsPlayer);
        await Future<void>.delayed(Duration.zero);

        final event = fixture.verifyEventEmitted<VideoMetadataExtractedEvent>();
        expect(event.metadata.videoCodec, isNull);
        expect(event.metadata.audioCodec, isNull);
      });

      test('handles HLS auto quality (-1)', () async {
        final hlsPlayer = MockHlsPlayer();
        hlsPlayer.levels = [MockHlsLevel(height: 1080, bitrate: 5000000)];
        hlsPlayer.currentLevel = -1; // Auto

        fixture.videoElement.readyState = 4;

        await manager.extractAndEmit(sourceUrl: 'https://example.com/playlist.m3u8', hlsPlayer: hlsPlayer);
        await Future<void>.delayed(Duration.zero);

        final event = fixture.verifyEventEmitted<VideoMetadataExtractedEvent>();
        // Should not extract codec/bitrate when in auto mode
        expect(event.metadata.videoBitrate, isNull);
      });

      test('handles empty HLS levels', () async {
        final hlsPlayer = MockHlsPlayer();
        hlsPlayer.levels = [];
        hlsPlayer.currentLevel = 0;

        fixture.videoElement.readyState = 4;

        await manager.extractAndEmit(sourceUrl: 'https://example.com/playlist.m3u8', hlsPlayer: hlsPlayer);
        await Future<void>.delayed(Duration.zero);

        final event = fixture.verifyEventEmitted<VideoMetadataExtractedEvent>();
        expect(event.metadata.videoBitrate, isNull);
      });
    });

    group('getMetadata', () {
      test('returns metadata without emitting event', () {
        fixture.videoElement.videoWidth = 1920;
        fixture.videoElement.videoHeight = 1080;
        fixture.videoElement.duration = 120.0;
        fixture.videoElement.readyState = 4;
        fixture.clearEmittedEvents();

        final metadata = manager.getMetadata(sourceUrl: 'https://example.com/video.mp4');

        expect(metadata, isNotNull);
        expect(metadata!.width, 1920);
        expect(metadata.height, 1080);
        expect(metadata.duration, const Duration(seconds: 120));
        expect(fixture.emittedEvents.isEmpty, isTrue); // No event emitted
      });

      test('returns null when metadata not ready', () {
        fixture.videoElement.readyState = 0;

        final metadata = manager.getMetadata(sourceUrl: 'https://example.com/video.mp4');

        expect(metadata, isNull);
      });
    });

    group('dispose', () {
      test('can be called multiple times safely', () {
        manager.dispose();
        expect(() => manager.dispose(), returnsNormally);
      });
    });
  });
}
