import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';
import 'package:pro_video_player_web/src/managers/audio_track_manager.dart';
import 'package:pro_video_player_web/src/managers/dash_manager.dart';
import 'package:pro_video_player_web/src/managers/hls_manager.dart';

import '../shared/mock_js_interop.dart';
import '../shared/web_test_fixture.dart';

void main() {
  group('AudioTrackManager', () {
    late WebVideoPlayerTestFixture fixture;
    late AudioTrackManager manager;

    setUp(() {
      fixture = WebVideoPlayerTestFixture();
      fixture.setUp();
      manager = AudioTrackManager(emitEvent: fixture.emitEvent, videoElement: fixture.videoElement);
    });

    tearDown(() async {
      manager.dispose();
      await fixture.tearDown();
    });

    group('native HTML5 audio tracks', () {
      test('notifies native audio tracks on initialization', () async {
        // Mock audio tracks on video element
        fixture.videoElement.mockAudioTracks = [
          MockAudioTrack(id: '0', label: 'English', language: 'en', enabled: true),
          MockAudioTrack(id: '1', label: 'Spanish', language: 'es'),
        ];

        fixture.clearEmittedEvents();
        await manager.notifyNativeAudioTracks();

        final event = fixture.verifyEventEmitted<AudioTracksChangedEvent>();
        expect(event.tracks.length, 2);
        expect(event.tracks[0].language, 'en');
        expect(event.tracks[1].language, 'es');
      });

      test('handles empty audio track list', () async {
        fixture.videoElement.mockAudioTracks = [];

        fixture.clearEmittedEvents();
        await manager.notifyNativeAudioTracks();

        // Should not emit event when no tracks
        expect(fixture.emittedEvents.whereType<AudioTracksChangedEvent>().isEmpty, isTrue);
      });

      test('sets native audio track', () {
        fixture.videoElement.mockAudioTracks = [
          MockAudioTrack(id: '0', label: 'English', language: 'en', enabled: true),
          MockAudioTrack(id: '1', label: 'Spanish', language: 'es'),
        ];

        const track = AudioTrack(id: '1', label: 'Spanish', language: 'es');
        final success = manager.setNativeAudioTrack(track);

        expect(success, isTrue);
        expect(fixture.videoElement.mockAudioTracks[0].enabled, isFalse);
        expect(fixture.videoElement.mockAudioTracks[1].enabled, isTrue);
      });

      test('handles missing native audio tracks', () {
        fixture.videoElement.mockAudioTracks = [];

        const track = AudioTrack(id: '0', label: 'English', language: 'en');
        final success = manager.setNativeAudioTrack(track);

        expect(success, isFalse);
      });
    });

    group('HLS audio track selection', () {
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

      test('sets HLS audio track', () {
        mockHlsPlayer.audioTrack = -1; // Default

        const track = AudioTrack(id: '2', label: 'French', language: 'fr');
        final success = manager.setAudioTrack(track);

        expect(success, isTrue);
        expect(mockHlsPlayer.audioTrack, 2);
      });

      test('rejects invalid HLS audio track', () {
        const track = AudioTrack(id: 'invalid', label: 'Invalid');
        final success = manager.setAudioTrack(track);

        expect(success, isFalse);
      });
    });

    group('DASH audio track selection', () {
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

      test('sets DASH audio track', () {
        mockDashPlayer.audioTracks = [
          MockDashAudioTrack(index: 0, lang: 'en', label: 'English'),
          MockDashAudioTrack(index: 1, lang: 'es', label: 'Spanish'),
        ];

        const track = AudioTrack(id: '1', label: 'Spanish', language: 'es');
        final success = manager.setAudioTrack(track);

        expect(success, isTrue);
        expect(mockDashPlayer.currentAudioTrack, 1);
      });

      test('rejects invalid DASH audio track', () {
        const track = AudioTrack(id: 'invalid', label: 'Invalid');
        final success = manager.setAudioTrack(track);

        expect(success, isFalse);
      });
    });

    group('source coordination', () {
      test('prefers HLS over DASH when both available', () async {
        final hlsManager = HlsManager(emitEvent: fixture.emitEvent, videoElement: fixture.videoElement);
        final dashManager = DashManager(emitEvent: fixture.emitEvent, videoElement: fixture.videoElement);

        final mockHlsPlayer = MockHlsPlayer();
        final mockDashPlayer = MockDashPlayer();

        await hlsManager.initialize(sourceUrl: 'https://example.com/playlist.m3u8', hlsPlayer: mockHlsPlayer);
        await dashManager.initialize(sourceUrl: 'https://example.com/manifest.mpd', dashPlayer: mockDashPlayer);

        manager.hlsManager = hlsManager;
        manager.dashManager = dashManager;

        const track = AudioTrack(id: '1', label: 'Spanish', language: 'es');
        final success = manager.setAudioTrack(track);

        expect(success, isTrue);
        expect(mockHlsPlayer.audioTrack, 1); // HLS was used
        expect(mockDashPlayer.currentAudioTrack, 0); // DASH was not used

        hlsManager.dispose();
        dashManager.dispose();
      });

      test('falls back to DASH when HLS not available', () async {
        final dashManager = DashManager(emitEvent: fixture.emitEvent, videoElement: fixture.videoElement);

        final mockDashPlayer = MockDashPlayer();

        await dashManager.initialize(sourceUrl: 'https://example.com/manifest.mpd', dashPlayer: mockDashPlayer);

        manager.dashManager = dashManager;

        const track = AudioTrack(id: '1', label: 'Spanish', language: 'es');
        final success = manager.setAudioTrack(track);

        expect(success, isTrue);
        expect(mockDashPlayer.currentAudioTrack, 1);

        dashManager.dispose();
      });

      test('falls back to native when HLS and DASH not available', () {
        fixture.videoElement.mockAudioTracks = [
          MockAudioTrack(id: '0', label: 'English', language: 'en', enabled: true),
          MockAudioTrack(id: '1', label: 'Spanish', language: 'es'),
        ];

        const track = AudioTrack(id: '1', label: 'Spanish', language: 'es');
        final success = manager.setAudioTrack(track);

        expect(success, isTrue);
        expect(fixture.videoElement.mockAudioTracks[1].enabled, isTrue);
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
