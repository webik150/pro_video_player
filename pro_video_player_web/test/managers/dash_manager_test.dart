import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';
import 'package:pro_video_player_web/src/managers/dash_manager.dart';

import '../shared/mock_js_interop.dart';
import '../shared/web_test_fixture.dart';

void main() {
  group('DashManager', () {
    late WebVideoPlayerTestFixture fixture;
    late DashManager manager;
    late MockDashPlayer mockDashPlayer;

    setUp(() {
      fixture = WebVideoPlayerTestFixture();
      fixture.setUp();
      mockDashPlayer = MockDashPlayer();
      manager = DashManager(emitEvent: fixture.emitEvent, videoElement: fixture.videoElement);
    });

    tearDown(() async {
      manager.dispose();
      await fixture.tearDown();
    });

    group('initialization', () {
      test('starts with no DASH player', () {
        expect(manager.isInitialized, isFalse);
        expect(manager.isActive, isFalse);
      });

      test('initializes with DASH player', () async {
        await manager.initialize(sourceUrl: 'https://example.com/manifest.mpd', dashPlayer: mockDashPlayer);

        expect(manager.isInitialized, isTrue);
        expect(manager.isActive, isTrue);
        expect(mockDashPlayer.isInitialized, isTrue);
        expect(mockDashPlayer.sourceUrl, 'https://example.com/manifest.mpd');
      });

      test('sets up event handlers on initialization', () async {
        await manager.initialize(sourceUrl: 'https://example.com/manifest.mpd', dashPlayer: mockDashPlayer);

        // Event handlers should be registered
        expect(mockDashPlayer.hasEventHandler('streamInitialized'), isTrue);
        expect(mockDashPlayer.hasEventHandler('qualityChangeRendered'), isTrue);
        expect(mockDashPlayer.hasEventHandler('textTracksAdded'), isTrue);
        expect(mockDashPlayer.hasEventHandler('audioTracksAdded'), isTrue);
        expect(mockDashPlayer.hasEventHandler('error'), isTrue);
      });
    });

    group('stream initialized', () {
      test('updates quality levels when stream initialized', () async {
        mockDashPlayer.bitrateInfos = [
          MockDashBitrateInfo(height: 360, width: 640, bitrate: 800000, qualityIndex: 0),
          MockDashBitrateInfo(height: 720, width: 1280, bitrate: 2500000, qualityIndex: 1),
          MockDashBitrateInfo(height: 1080, width: 1920, bitrate: 5000000, qualityIndex: 2),
        ];

        await manager.initialize(sourceUrl: 'https://example.com/manifest.mpd', dashPlayer: mockDashPlayer);

        fixture.clearEmittedEvents();
        mockDashPlayer.triggerEvent('streamInitialized');
        await Future<void>.delayed(Duration.zero);

        final qualities = manager.getAvailableQualities();
        expect(qualities.length, 4); // 3 levels + auto
        expect(qualities[0].isAuto, isTrue);
        expect(qualities[1].height, 360);
        expect(qualities[2].height, 720);
        expect(qualities[3].height, 1080);
      });

      test('emits quality tracks changed event when stream initialized', () async {
        mockDashPlayer.bitrateInfos = [
          MockDashBitrateInfo(height: 720, width: 1280, bitrate: 2500000, qualityIndex: 0),
        ];

        await manager.initialize(sourceUrl: 'https://example.com/manifest.mpd', dashPlayer: mockDashPlayer);

        fixture.clearEmittedEvents();
        mockDashPlayer.triggerEvent('streamInitialized');
        await Future<void>.delayed(Duration.zero);

        final event = fixture.verifyEventEmitted<VideoQualityTracksChangedEvent>();
        expect(event, isNotNull);
        expect(event.tracks.length, 2); // auto + 1 quality
      });
    });

    group('quality selection', () {
      setUp(() async {
        mockDashPlayer.bitrateInfos = [
          MockDashBitrateInfo(height: 360, width: 640, bitrate: 800000, qualityIndex: 0),
          MockDashBitrateInfo(height: 720, width: 1280, bitrate: 2500000, qualityIndex: 1),
          MockDashBitrateInfo(height: 1080, width: 1920, bitrate: 5000000, qualityIndex: 2),
        ];

        await manager.initialize(sourceUrl: 'https://example.com/manifest.mpd', dashPlayer: mockDashPlayer);

        mockDashPlayer.triggerEvent('streamInitialized');
        await Future<void>.delayed(Duration.zero);
      });

      test('sets quality to auto', () {
        final success = manager.setQuality(VideoQualityTrack.auto);

        expect(success, isTrue);
        expect(mockDashPlayer.abrEnabled, isTrue);
        expect(manager.getCurrentQuality().isAuto, isTrue);
      });

      test('sets quality to specific level', () {
        final qualities = manager.getAvailableQualities();
        final q720 = qualities.firstWhere((q) => q.height == 720);

        final success = manager.setQuality(q720);

        expect(success, isTrue);
        expect(mockDashPlayer.abrEnabled, isFalse);
        expect(mockDashPlayer.currentQuality, 1); // Second level (0-indexed)
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
        mockDashPlayer.currentQuality = 2; // 1080p
        mockDashPlayer.abrEnabled = false;

        final current = manager.getCurrentQuality();

        expect(current.height, 1080);
      });

      test('returns auto when ABR is enabled', () {
        mockDashPlayer.abrEnabled = true;

        final current = manager.getCurrentQuality();

        expect(current.isAuto, isTrue);
      });
    });

    group('quality change rendered', () {
      test('emits quality changed event when quality changes', () async {
        mockDashPlayer.bitrateInfos = [
          MockDashBitrateInfo(height: 720, width: 1280, bitrate: 2500000, qualityIndex: 0),
        ];

        await manager.initialize(sourceUrl: 'https://example.com/manifest.mpd', dashPlayer: mockDashPlayer);

        mockDashPlayer.triggerEvent('streamInitialized');
        await Future<void>.delayed(Duration.zero);

        fixture.clearEmittedEvents();
        mockDashPlayer.currentQuality = 0;
        mockDashPlayer.abrEnabled = false;
        mockDashPlayer.triggerEvent('qualityChangeRendered');
        await Future<void>.delayed(Duration.zero);

        final event = fixture.verifyEventEmitted<SelectedQualityChangedEvent>();
        expect(event.track.height, 720);
      });
    });

    group('error handling', () {
      test('handles DASH error event', () async {
        await manager.initialize(sourceUrl: 'https://example.com/manifest.mpd', dashPlayer: mockDashPlayer);

        fixture.clearEmittedEvents();
        mockDashPlayer.triggerEvent('error', {
          'error': {'code': 'MANIFEST_LOADER_PARSING_FAILURE', 'message': 'Failed to parse manifest'},
        });
        await Future<void>.delayed(Duration.zero);

        // Should emit error event
        final events = fixture.emittedEvents.whereType<ErrorEvent>();
        expect(events.isNotEmpty, isTrue);
      });
    });

    group('recovery', () {
      test('calls reset and attachSource on recovery', () async {
        await manager.initialize(sourceUrl: 'https://example.com/manifest.mpd', dashPlayer: mockDashPlayer);

        var resetCalled = false;
        var attachSourceCalled = false;
        mockDashPlayer.onReset = () => resetCalled = true;
        mockDashPlayer.onAttachSource = () => attachSourceCalled = true;

        await manager.recover();

        expect(resetCalled, isTrue);
        expect(attachSourceCalled, isTrue);
      });
    });

    group('disposal', () {
      test('resets DASH player on dispose', () async {
        await manager.initialize(sourceUrl: 'https://example.com/manifest.mpd', dashPlayer: mockDashPlayer);

        expect(mockDashPlayer.isInitialized, isTrue);

        manager.dispose();

        expect(manager.isActive, isFalse);
        expect(manager.isInitialized, isFalse);
      });

      test('can be called multiple times safely', () async {
        await manager.initialize(sourceUrl: 'https://example.com/manifest.mpd', dashPlayer: mockDashPlayer);

        manager.dispose();
        expect(() => manager.dispose(), returnsNormally);
      });

      test('handles dispose when not initialized', () {
        expect(() => manager.dispose(), returnsNormally);
      });
    });

    group('track updates', () {
      test('notifies when audio tracks added', () async {
        await manager.initialize(sourceUrl: 'https://example.com/manifest.mpd', dashPlayer: mockDashPlayer);

        mockDashPlayer.audioTracks = [
          MockDashAudioTrack(index: 0, lang: 'en', label: 'English'),
          MockDashAudioTrack(index: 1, lang: 'es', label: 'Spanish'),
        ];

        fixture.clearEmittedEvents();
        mockDashPlayer.triggerEvent('audioTracksAdded');
        await Future<void>.delayed(Duration.zero);

        final event = fixture.verifyEventEmitted<AudioTracksChangedEvent>();
        expect(event.tracks.length, 2);
        expect(event.tracks[0].language, 'en');
        expect(event.tracks[1].language, 'es');
      });

      test('notifies when text tracks added', () async {
        await manager.initialize(sourceUrl: 'https://example.com/manifest.mpd', dashPlayer: mockDashPlayer);

        mockDashPlayer.textTracks = [MockDashTextTrack(index: 0, lang: 'en', label: 'English')];

        fixture.clearEmittedEvents();
        mockDashPlayer.triggerEvent('textTracksAdded');
        await Future<void>.delayed(Duration.zero);

        final event = fixture.verifyEventEmitted<SubtitleTracksChangedEvent>();
        expect(event.tracks.length, 1);
        expect(event.tracks[0].language, 'en');
      });
    });

    group('throughput tracking', () {
      test('returns average throughput in bps', () async {
        mockDashPlayer.averageThroughputKbps = 5000; // 5 Mbps

        await manager.initialize(sourceUrl: 'https://example.com/manifest.mpd', dashPlayer: mockDashPlayer);

        final throughput = manager.getAverageThroughput();

        expect(throughput, 5000000); // Converted to bps
      });

      test('returns 0 when player not initialized', () {
        final throughput = manager.getAverageThroughput();

        expect(throughput, 0);
      });
    });
  });
}
