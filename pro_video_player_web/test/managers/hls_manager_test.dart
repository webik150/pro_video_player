import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';
import 'package:pro_video_player_web/src/managers/hls_manager.dart';

import '../shared/mock_js_interop.dart';
import '../shared/web_test_fixture.dart';

void main() {
  group('HlsManager', () {
    late WebVideoPlayerTestFixture fixture;
    late HlsManager manager;
    late MockHlsPlayer mockHlsPlayer;

    setUp(() {
      fixture = WebVideoPlayerTestFixture();
      fixture.setUp();
      mockHlsPlayer = MockHlsPlayer();
      manager = HlsManager(emitEvent: fixture.emitEvent, videoElement: fixture.videoElement);
    });

    tearDown(() async {
      manager.dispose();
      await fixture.tearDown();
    });

    group('initialization', () {
      test('starts with no HLS player', () {
        expect(manager.isInitialized, isFalse);
        expect(manager.isActive, isFalse);
      });

      test('initializes with HLS player', () async {
        await manager.initialize(sourceUrl: 'https://example.com/playlist.m3u8', hlsPlayer: mockHlsPlayer);

        expect(manager.isInitialized, isTrue);
        expect(manager.isActive, isTrue);
        expect(mockHlsPlayer.isAttached, isTrue);
        expect(mockHlsPlayer.sourceUrl, 'https://example.com/playlist.m3u8');
      });

      test('sets up event handlers on initialization', () async {
        await manager.initialize(sourceUrl: 'https://example.com/playlist.m3u8', hlsPlayer: mockHlsPlayer);

        // Event handlers should be registered
        expect(mockHlsPlayer.hasEventHandler('manifestParsed'), isTrue);
        expect(mockHlsPlayer.hasEventHandler('levelSwitched'), isTrue);
        expect(mockHlsPlayer.hasEventHandler('error'), isTrue);
      });
    });

    group('manifest parsed', () {
      test('updates quality levels when manifest parsed', () async {
        mockHlsPlayer.levels = [
          MockHlsLevel(height: 360, bitrate: 800000),
          MockHlsLevel(height: 720, bitrate: 2500000),
          MockHlsLevel(height: 1080, bitrate: 5000000),
        ];

        await manager.initialize(sourceUrl: 'https://example.com/playlist.m3u8', hlsPlayer: mockHlsPlayer);

        fixture.clearEmittedEvents();
        mockHlsPlayer.triggerEvent('manifestParsed');
        await Future<void>.delayed(Duration.zero);

        final qualities = manager.getAvailableQualities();
        expect(qualities.length, 4); // 3 levels + auto
        expect(qualities[0].isAuto, isTrue);
        expect(qualities[1].height, 360);
        expect(qualities[2].height, 720);
        expect(qualities[3].height, 1080);
      });

      test('emits quality changed event when manifest parsed', () async {
        mockHlsPlayer.levels = [MockHlsLevel(height: 720, bitrate: 2500000)];

        await manager.initialize(sourceUrl: 'https://example.com/playlist.m3u8', hlsPlayer: mockHlsPlayer);

        fixture.clearEmittedEvents();
        mockHlsPlayer.triggerEvent('manifestParsed');
        await Future<void>.delayed(Duration.zero);

        final event = fixture.verifyEventEmitted<SelectedQualityChangedEvent>();
        expect(event, isNotNull);
      });
    });

    group('quality selection', () {
      setUp(() async {
        mockHlsPlayer.levels = [
          MockHlsLevel(height: 360, bitrate: 800000),
          MockHlsLevel(height: 720, bitrate: 2500000),
          MockHlsLevel(height: 1080, bitrate: 5000000),
        ];

        await manager.initialize(sourceUrl: 'https://example.com/playlist.m3u8', hlsPlayer: mockHlsPlayer);

        mockHlsPlayer.triggerEvent('manifestParsed');
        await Future<void>.delayed(Duration.zero);
      });

      test('sets quality to auto', () {
        final success = manager.setQuality(VideoQualityTrack.auto);

        expect(success, isTrue);
        expect(mockHlsPlayer.currentLevel, -1);
        expect(manager.getCurrentQuality().isAuto, isTrue);
      });

      test('sets quality to specific level', () {
        final qualities = manager.getAvailableQualities();
        final q720 = qualities.firstWhere((q) => q.height == 720);

        final success = manager.setQuality(q720);

        expect(success, isTrue);
        expect(mockHlsPlayer.currentLevel, 1); // Second level (0-indexed)
        expect(manager.getCurrentQuality().height, 720);
      });

      test('rejects invalid quality', () {
        const invalidQuality = VideoQualityTrack(
          id: '999',
          label: 'Invalid',
          width: 9999,
          height: 9999,
          bitrate: 999999,
        );

        final success = manager.setQuality(invalidQuality);

        expect(success, isFalse);
      });

      test('returns current quality', () {
        mockHlsPlayer.currentLevel = 2; // 1080p

        final current = manager.getCurrentQuality();

        expect(current.height, 1080);
      });

      test('returns auto when current level is -1', () {
        mockHlsPlayer.currentLevel = -1;

        final current = manager.getCurrentQuality();

        expect(current.isAuto, isTrue);
      });
    });

    group('level switched', () {
      test('emits quality changed event when level switches', () async {
        mockHlsPlayer.levels = [MockHlsLevel(height: 720, bitrate: 2500000)];

        await manager.initialize(sourceUrl: 'https://example.com/playlist.m3u8', hlsPlayer: mockHlsPlayer);

        mockHlsPlayer.triggerEvent('manifestParsed');
        await Future<void>.delayed(Duration.zero);

        fixture.clearEmittedEvents();
        mockHlsPlayer.currentLevel = 0;
        mockHlsPlayer.triggerEvent('levelSwitched');
        await Future<void>.delayed(Duration.zero);

        final event = fixture.verifyEventEmitted<SelectedQualityChangedEvent>();
        expect(event.track.height, 720);
      });
    });

    group('error handling', () {
      test('handles HLS error event', () async {
        await manager.initialize(sourceUrl: 'https://example.com/playlist.m3u8', hlsPlayer: mockHlsPlayer);

        fixture.clearEmittedEvents();
        mockHlsPlayer.triggerEvent('error', {'fatal': true, 'type': 'networkError'});
        await Future<void>.delayed(Duration.zero);

        // Should emit some error event (exact type depends on implementation)
        expect(fixture.emittedEvents.isNotEmpty, isTrue);
      });
    });

    group('recovery', () {
      test('calls startLoad on recovery', () async {
        await manager.initialize(sourceUrl: 'https://example.com/playlist.m3u8', hlsPlayer: mockHlsPlayer);

        var startLoadCalled = false;
        mockHlsPlayer.onStartLoad = () => startLoadCalled = true;

        await manager.recover();

        expect(startLoadCalled, isTrue);
      });
    });

    group('disposal', () {
      test('destroys HLS player on dispose', () async {
        await manager.initialize(sourceUrl: 'https://example.com/playlist.m3u8', hlsPlayer: mockHlsPlayer);

        expect(mockHlsPlayer.isAttached, isTrue);

        manager.dispose();

        expect(manager.isActive, isFalse);
        expect(manager.isInitialized, isFalse);
      });

      test('can be called multiple times safely', () async {
        await manager.initialize(sourceUrl: 'https://example.com/playlist.m3u8', hlsPlayer: mockHlsPlayer);

        manager.dispose();
        expect(() => manager.dispose(), returnsNormally);
      });

      test('handles dispose when not initialized', () {
        expect(() => manager.dispose(), returnsNormally);
      });
    });

    group('track updates', () {
      test('notifies when audio tracks updated', () async {
        await manager.initialize(sourceUrl: 'https://example.com/playlist.m3u8', hlsPlayer: mockHlsPlayer);

        mockHlsPlayer.audioTracks = [
          MockHlsAudioTrack(id: 0, name: 'English', lang: 'en'),
          MockHlsAudioTrack(id: 1, name: 'Spanish', lang: 'es'),
        ];

        fixture.clearEmittedEvents();
        mockHlsPlayer.triggerEvent('audioTracksUpdated');
        await Future<void>.delayed(Duration.zero);

        final event = fixture.verifyEventEmitted<AudioTracksChangedEvent>();
        expect(event.tracks.length, 2);
        expect(event.tracks[0].language, 'en');
        expect(event.tracks[1].language, 'es');
      });

      test('notifies when subtitle tracks updated', () async {
        await manager.initialize(sourceUrl: 'https://example.com/playlist.m3u8', hlsPlayer: mockHlsPlayer);

        mockHlsPlayer.subtitleTracks = [MockHlsSubtitleTrack(id: 0, name: 'English', lang: 'en')];

        fixture.clearEmittedEvents();
        mockHlsPlayer.triggerEvent('subtitleTracksUpdated');
        await Future<void>.delayed(Duration.zero);

        final event = fixture.verifyEventEmitted<SubtitleTracksChangedEvent>();
        expect(event.tracks.length, 1);
        expect(event.tracks[0].language, 'en');
      });
    });
  });
}
