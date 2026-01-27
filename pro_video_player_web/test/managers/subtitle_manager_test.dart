import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';
import 'package:pro_video_player_web/src/managers/dash_manager.dart';
import 'package:pro_video_player_web/src/managers/hls_manager.dart';
import 'package:pro_video_player_web/src/managers/subtitle_manager.dart';

import '../shared/mock_js_interop.dart';
import '../shared/web_test_fixture.dart';

void main() {
  group('SubtitleManager', () {
    late WebVideoPlayerTestFixture fixture;
    late SubtitleManager manager;

    setUp(() {
      fixture = WebVideoPlayerTestFixture();
      fixture.setUp();
      manager = SubtitleManager(emitEvent: fixture.emitEvent, videoElement: fixture.videoElement);
    });

    tearDown(() async {
      manager.dispose();
      await fixture.tearDown();
    });

    group('HLS subtitle coordination', () {
      late HlsManager hlsManager;
      late MockHlsPlayer mockHlsPlayer;

      setUp(() async {
        mockHlsPlayer = MockHlsPlayer();
        hlsManager = HlsManager(emitEvent: fixture.emitEvent, videoElement: fixture.videoElement);

        await hlsManager.initialize(sourceUrl: 'https://example.com/playlist.m3u8', hlsPlayer: mockHlsPlayer);

        manager.hlsManager = hlsManager;
      });

      tearDown(() {
        hlsManager.dispose();
      });

      test('sets HLS subtitle track', () {
        mockHlsPlayer.subtitleTrack = -1; // None

        const track = SubtitleTrack(id: '2', label: 'English', language: 'en');
        final success = manager.setSubtitleTrack(track);

        expect(success, isTrue);
        expect(mockHlsPlayer.subtitleTrack, 2);
      });

      test('disables HLS subtitles when track is null', () {
        mockHlsPlayer.subtitleTrack = 1;

        final success = manager.setSubtitleTrack(null);

        expect(success, isTrue);
        expect(mockHlsPlayer.subtitleTrack, -1);
      });
    });

    group('DASH subtitle coordination', () {
      late DashManager dashManager;
      late MockDashPlayer mockDashPlayer;

      setUp(() async {
        mockDashPlayer = MockDashPlayer();
        dashManager = DashManager(emitEvent: fixture.emitEvent, videoElement: fixture.videoElement);

        await dashManager.initialize(sourceUrl: 'https://example.com/manifest.mpd', dashPlayer: mockDashPlayer);

        manager.dashManager = dashManager;
      });

      tearDown(() {
        dashManager.dispose();
      });

      test('sets DASH text track', () {
        mockDashPlayer.textTracks = [
          MockDashTextTrack(index: 0, lang: 'en', label: 'English'),
          MockDashTextTrack(index: 1, lang: 'es', label: 'Spanish'),
        ];

        const track = SubtitleTrack(id: '1', label: 'Spanish', language: 'es');
        final success = manager.setSubtitleTrack(track);

        expect(success, isTrue);
        expect(mockDashPlayer.currentTextTrack, 1);
      });

      test('disables DASH text track when track is null', () {
        mockDashPlayer.currentTextTrack = 0;
        mockDashPlayer.textTrackVisible = true;

        final success = manager.setSubtitleTrack(null);

        expect(success, isTrue);
        expect(mockDashPlayer.textTrackVisible, isFalse);
      });
    });

    group('native TextTrack coordination', () {
      test('sets native text track mode', () {
        fixture.videoElement.mockTextTracks = [
          MockTextTrack(id: '0', label: 'English', language: 'en'),
          MockTextTrack(id: '1', label: 'Spanish', language: 'es'),
        ];

        const track = SubtitleTrack(id: '1', label: 'Spanish', language: 'es');
        final success = manager.setSubtitleTrack(track);

        expect(success, isTrue);
        expect(fixture.videoElement.mockTextTracks[0].mode, 'disabled');
        expect(fixture.videoElement.mockTextTracks[1].mode, 'showing');
      });

      test('disables all native text tracks when track is null', () {
        fixture.videoElement.mockTextTracks = [
          MockTextTrack(id: '0', label: 'English', language: 'en', mode: 'showing'),
        ];

        final success = manager.setSubtitleTrack(null);

        expect(success, isTrue);
        expect(fixture.videoElement.mockTextTracks[0].mode, 'disabled');
      });

      test('notifies native text tracks', () async {
        fixture.videoElement.mockTextTracks = [
          MockTextTrack(id: '0', label: 'English', language: 'en'),
          MockTextTrack(id: '1', label: 'Spanish', language: 'es'),
        ];

        fixture.clearEmittedEvents();
        await manager.notifyNativeTextTracks();

        final event = fixture.verifyEventEmitted<SubtitleTracksChangedEvent>();
        expect(event.tracks.length, 2);
        expect(event.tracks[0].language, 'en');
        expect(event.tracks[1].language, 'es');
      });
    });

    group('source priority', () {
      test('prefers HLS over DASH when both available', () async {
        final hlsManager = HlsManager(emitEvent: fixture.emitEvent, videoElement: fixture.videoElement);
        final dashManager = DashManager(emitEvent: fixture.emitEvent, videoElement: fixture.videoElement);

        final mockHlsPlayer = MockHlsPlayer();
        final mockDashPlayer = MockDashPlayer();

        await hlsManager.initialize(sourceUrl: 'https://example.com/playlist.m3u8', hlsPlayer: mockHlsPlayer);
        await dashManager.initialize(sourceUrl: 'https://example.com/manifest.mpd', dashPlayer: mockDashPlayer);

        manager.hlsManager = hlsManager;
        manager.dashManager = dashManager;

        const track = SubtitleTrack(id: '1', label: 'Spanish', language: 'es');
        final success = manager.setSubtitleTrack(track);

        expect(success, isTrue);
        expect(mockHlsPlayer.subtitleTrack, 1); // HLS was used
        expect(mockDashPlayer.currentTextTrack, 0); // DASH was not used

        hlsManager.dispose();
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
