import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';
import 'package:pro_video_player_web/src/managers/dash_manager.dart';
import 'package:pro_video_player_web/src/managers/hls_manager.dart';
import 'package:pro_video_player_web/src/managers/quality_manager.dart';

import '../shared/mock_js_interop.dart';
import '../shared/web_test_fixture.dart';

void main() {
  group('QualityManager', () {
    late WebVideoPlayerTestFixture fixture;
    late QualityManager manager;

    setUp(() {
      fixture = WebVideoPlayerTestFixture();
      fixture.setUp();
      manager = QualityManager(emitEvent: fixture.emitEvent, videoElement: fixture.videoElement);
    });

    tearDown(() async {
      manager.dispose();
      await fixture.tearDown();
    });

    group('no adaptive streaming', () {
      test('returns auto-only when no HLS or DASH', () {
        final qualities = manager.getAvailableQualities();

        expect(qualities.length, 1);
        expect(qualities[0].isAuto, isTrue);
      });

      test('returns auto as current quality when no HLS or DASH', () {
        final current = manager.getCurrentQuality();

        expect(current.isAuto, isTrue);
      });

      test('setQuality returns false when no HLS or DASH', () {
        const quality = VideoQualityTrack(id: '1', label: '720p', width: 1280, height: 720, bitrate: 2500000);

        final success = manager.setQuality(quality);

        expect(success, isFalse);
      });
    });

    group('HLS quality selection', () {
      late HlsManager hlsManager;
      late MockHlsPlayer mockHlsPlayer;

      setUp(() async {
        mockHlsPlayer = MockHlsPlayer();
        mockHlsPlayer.levels = [
          MockHlsLevel(height: 360, bitrate: 800000),
          MockHlsLevel(height: 720, bitrate: 2500000),
          MockHlsLevel(height: 1080, bitrate: 5000000),
        ];

        hlsManager = HlsManager(emitEvent: fixture.emitEvent, videoElement: fixture.videoElement);

        await hlsManager.initialize(sourceUrl: 'https://example.com/playlist.m3u8', hlsPlayer: mockHlsPlayer);

        mockHlsPlayer.triggerEvent('manifestParsed');
        await Future<void>.delayed(Duration.zero);

        manager.hlsManager = hlsManager;
      });

      tearDown(() {
        hlsManager.dispose();
      });

      test('returns HLS qualities', () {
        final qualities = manager.getAvailableQualities();

        expect(qualities.length, 4); // auto + 3 levels
        expect(qualities[0].isAuto, isTrue);
        expect(qualities[1].height, 360);
        expect(qualities[2].height, 720);
        expect(qualities[3].height, 1080);
      });

      test('sets HLS quality', () {
        final qualities = manager.getAvailableQualities();
        final q720 = qualities.firstWhere((q) => q.height == 720);

        final success = manager.setQuality(q720);

        expect(success, isTrue);
        expect(mockHlsPlayer.currentLevel, 1);
      });

      test('gets current HLS quality', () {
        mockHlsPlayer.currentLevel = 2; // 1080p

        final current = manager.getCurrentQuality();

        expect(current.height, 1080);
      });

      test('returns auto when HLS in auto mode', () {
        mockHlsPlayer.currentLevel = -1;

        final current = manager.getCurrentQuality();

        expect(current.isAuto, isTrue);
      });
    });

    group('DASH quality selection', () {
      late DashManager dashManager;
      late MockDashPlayer mockDashPlayer;

      setUp(() async {
        mockDashPlayer = MockDashPlayer();
        mockDashPlayer.bitrateInfos = [
          MockDashBitrateInfo(height: 360, width: 640, bitrate: 800000, qualityIndex: 0),
          MockDashBitrateInfo(height: 720, width: 1280, bitrate: 2500000, qualityIndex: 1),
          MockDashBitrateInfo(height: 1080, width: 1920, bitrate: 5000000, qualityIndex: 2),
        ];

        dashManager = DashManager(emitEvent: fixture.emitEvent, videoElement: fixture.videoElement);

        await dashManager.initialize(sourceUrl: 'https://example.com/manifest.mpd', dashPlayer: mockDashPlayer);

        mockDashPlayer.triggerEvent('streamInitialized');
        await Future<void>.delayed(Duration.zero);

        manager.dashManager = dashManager;
      });

      tearDown(() {
        dashManager.dispose();
      });

      test('returns DASH qualities', () {
        final qualities = manager.getAvailableQualities();

        expect(qualities.length, 4); // auto + 3 levels
        expect(qualities[0].isAuto, isTrue);
        expect(qualities[1].height, 360);
        expect(qualities[2].height, 720);
        expect(qualities[3].height, 1080);
      });

      test('sets DASH quality', () {
        final qualities = manager.getAvailableQualities();
        final q720 = qualities.firstWhere((q) => q.height == 720);

        final success = manager.setQuality(q720);

        expect(success, isTrue);
        expect(mockDashPlayer.currentQuality, 1);
      });

      test('gets current DASH quality', () {
        mockDashPlayer.currentQuality = 2; // 1080p
        mockDashPlayer.abrEnabled = false;

        final current = manager.getCurrentQuality();

        expect(current.height, 1080);
      });

      test('returns auto when DASH ABR enabled', () {
        mockDashPlayer.abrEnabled = true;

        final current = manager.getCurrentQuality();

        expect(current.isAuto, isTrue);
      });
    });

    group('source coordination', () {
      test('prefers HLS over DASH when both available', () async {
        final hlsManager = HlsManager(emitEvent: fixture.emitEvent, videoElement: fixture.videoElement);
        final dashManager = DashManager(emitEvent: fixture.emitEvent, videoElement: fixture.videoElement);

        final mockHlsPlayer = MockHlsPlayer();
        final mockDashPlayer = MockDashPlayer();

        mockHlsPlayer.levels = [MockHlsLevel(height: 720, bitrate: 2500000)];
        mockDashPlayer.bitrateInfos = [
          MockDashBitrateInfo(height: 1080, width: 1920, bitrate: 5000000, qualityIndex: 0),
        ];

        await hlsManager.initialize(sourceUrl: 'https://example.com/playlist.m3u8', hlsPlayer: mockHlsPlayer);
        await dashManager.initialize(sourceUrl: 'https://example.com/manifest.mpd', dashPlayer: mockDashPlayer);

        mockHlsPlayer.triggerEvent('manifestParsed');
        mockDashPlayer.triggerEvent('streamInitialized');
        await Future<void>.delayed(Duration.zero);

        manager.hlsManager = hlsManager;
        manager.dashManager = dashManager;

        final qualities = manager.getAvailableQualities();

        // Should return HLS qualities (2 total: auto + 720p)
        expect(qualities.length, 2);
        expect(qualities[1].height, 720);

        hlsManager.dispose();
        dashManager.dispose();
      });

      test('falls back to DASH when HLS not available', () async {
        final dashManager = DashManager(emitEvent: fixture.emitEvent, videoElement: fixture.videoElement);

        final mockDashPlayer = MockDashPlayer();
        mockDashPlayer.bitrateInfos = [
          MockDashBitrateInfo(height: 1080, width: 1920, bitrate: 5000000, qualityIndex: 0),
        ];

        await dashManager.initialize(sourceUrl: 'https://example.com/manifest.mpd', dashPlayer: mockDashPlayer);

        mockDashPlayer.triggerEvent('streamInitialized');
        await Future<void>.delayed(Duration.zero);

        manager.dashManager = dashManager;

        final qualities = manager.getAvailableQualities();

        // Should return DASH qualities (2 total: auto + 1080p)
        expect(qualities.length, 2);
        expect(qualities[1].height, 1080);

        dashManager.dispose();
      });
    });

    group('disposal', () {
      test('clears manager references on dispose', () async {
        final hlsManager = HlsManager(emitEvent: fixture.emitEvent, videoElement: fixture.videoElement);

        final mockHlsPlayer = MockHlsPlayer();

        await hlsManager.initialize(sourceUrl: 'https://example.com/playlist.m3u8', hlsPlayer: mockHlsPlayer);

        manager.hlsManager = hlsManager;
        expect(manager.hasHlsManager, isTrue);

        manager.dispose();
        expect(manager.hasHlsManager, isFalse);

        hlsManager.dispose();
      });

      test('can be called multiple times safely', () {
        manager.dispose();
        expect(() => manager.dispose(), returnsNormally);
      });
    });
  });
}
