import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';
import 'package:pro_video_player_web/src/managers/casting_manager.dart';
import 'package:pro_video_player_web/src/web_player_helpers.dart' as helpers;

import '../shared/mock_js_interop.dart';
import '../shared/web_test_fixture.dart';

void main() {
  group('CastingManager', () {
    late WebVideoPlayerTestFixture fixture;
    late CastingManager manager;
    late MockRemotePlayback mockRemote;

    setUp(() {
      fixture = WebVideoPlayerTestFixture();
      fixture.setUp();
      mockRemote = MockRemotePlayback();
      fixture.videoElement.mockRemotePlayback = mockRemote;

      manager = CastingManager(emitEvent: fixture.emitEvent, videoElement: fixture.videoElement, allowCasting: true);
    });

    tearDown(() async {
      manager.dispose();
      await fixture.tearDown();
    });

    group('initialization', () {
      test('sets up remote playback listeners when allowed', () {
        manager.initialize();

        expect(mockRemote.hasListener('connecting'), isTrue);
        expect(mockRemote.hasListener('connect'), isTrue);
        expect(mockRemote.hasListener('disconnect'), isTrue);
      });

      test('does not set up listeners when casting not allowed', () {
        final restrictedManager = CastingManager(
          emitEvent: fixture.emitEvent,
          videoElement: fixture.videoElement,
          allowCasting: false,
        );

        restrictedManager.initialize();

        expect(mockRemote.hasListener('connecting'), isFalse);
        restrictedManager.dispose();
      });

      test('handles missing remote playback gracefully', () {
        fixture.videoElement.mockRemotePlayback = null;

        expect(() => manager.initialize(), returnsNormally);
        expect(manager.isSupported(), isFalse);
      });
    });

    group('support detection', () {
      test('returns true when remote playback available', () {
        manager.initialize();
        expect(manager.isSupported(), isTrue);
      });

      test('returns false when remote playback not available', () {
        fixture.videoElement.mockRemotePlayback = null;
        manager.initialize();
        expect(manager.isSupported(), isFalse);
      });

      test('returns false when casting not allowed', () {
        final restrictedManager = CastingManager(
          emitEvent: fixture.emitEvent,
          videoElement: fixture.videoElement,
          allowCasting: false,
        );
        restrictedManager.initialize();
        expect(restrictedManager.isSupported(), isFalse);
        restrictedManager.dispose();
      });
    });

    group('state transitions', () {
      setUp(() {
        manager.initialize();
        fixture.clearEmittedEvents();
      });

      test('emits connecting state on connecting event', () async {
        mockRemote.triggerEvent('connecting');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final event = fixture.verifyEventEmitted<CastStateChangedEvent>();
        expect(event.state, CastState.connecting);
        expect(manager.getState(), CastState.connecting);
      });

      test('emits connected state and device on connect event', () async {
        mockRemote.triggerEvent('connect');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final event = fixture.verifyEventEmitted<CastStateChangedEvent>();
        expect(event.state, CastState.connected);
        expect(event.device, isNotNull);
        expect(event.device!.id, 'web-remote-device');
        expect(event.device!.name, 'Remote Device');
        expect(event.device!.type, CastDeviceType.webRemotePlayback);
        expect(manager.getState(), CastState.connected);
        expect(manager.getCurrentDevice(), isNotNull);
      });

      test('emits disconnected state on disconnect event', () async {
        mockRemote.triggerEvent('connect');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        fixture.clearEmittedEvents();

        mockRemote.triggerEvent('disconnect');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final event = fixture.verifyEventEmitted<CastStateChangedEvent>();
        expect(event.state, CastState.notConnected);
        expect(manager.getState(), CastState.notConnected);
        expect(manager.getCurrentDevice(), isNull);
      });
    });

    group('casting operations', () {
      setUp(() {
        manager.initialize();
      });

      test('starts casting by showing prompt', () async {
        var promptCalled = false;
        mockRemote.onPrompt = () => promptCalled = true;

        final success = await manager.startCasting();

        expect(success, isTrue);
        expect(promptCalled, isTrue);
      });

      test('returns false when starting cast fails', () async {
        mockRemote.onPrompt = () => throw Exception('Prompt failed');

        final success = await manager.startCasting();

        expect(success, isFalse);
      });

      test('returns false when starting cast without support', () async {
        fixture.videoElement.mockRemotePlayback = null;

        final success = await manager.startCasting();

        expect(success, isFalse);
      });

      test('stops casting by reloading video', () async {
        mockRemote.mockState = 'connected';
        fixture.videoElement.currentTime = 45.0;
        fixture.videoElement.paused = false;

        fixture.clearEmittedEvents();
        final success = await manager.stopCasting(
          currentSource: const VideoSource.network('https://example.com/video.mp4'),
          getSourceUrl: helpers.getSourceUrl,
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(success, isTrue);
        expect(fixture.videoElement.src, 'https://example.com/video.mp4');

        // Should emit disconnecting and/or notConnected events
        final events = fixture.getEmittedEvents<CastStateChangedEvent>();
        expect(events, isNotEmpty);
        expect(events.last.state, CastState.notConnected);
      });

      test('stops casting reloads video source', () async {
        mockRemote.mockState = 'connected';
        fixture.videoElement.currentTime = 30.5;
        fixture.videoElement.paused = true;

        await manager.stopCasting(
          currentSource: const VideoSource.network('https://example.com/video.mp4'),
          getSourceUrl: helpers.getSourceUrl,
        );

        // Verify video was reloaded with correct source
        expect(fixture.videoElement.src, 'https://example.com/video.mp4');
      });

      test('returns false when stopping cast while disconnected', () async {
        mockRemote.mockState = 'disconnected';

        final success = await manager.stopCasting(
          currentSource: const VideoSource.network('https://example.com/video.mp4'),
          getSourceUrl: helpers.getSourceUrl,
        );

        expect(success, isFalse);
      });

      test('returns false when stopping cast without support', () async {
        fixture.videoElement.mockRemotePlayback = null;

        final success = await manager.stopCasting(
          currentSource: const VideoSource.network('https://example.com/video.mp4'),
          getSourceUrl: helpers.getSourceUrl,
        );

        expect(success, isFalse);
      });
    });

    group('device enumeration', () {
      test('returns empty list for available devices', () {
        manager.initialize();
        expect(manager.getAvailableDevices(), isEmpty);
      });
    });

    group('disposal', () {
      test('resets state on dispose', () {
        manager.initialize();
        mockRemote.triggerEvent('connect');

        manager.dispose();

        expect(manager.getState(), CastState.notConnected);
        expect(manager.getCurrentDevice(), isNull);
      });

      test('can be called multiple times safely', () {
        manager.dispose();
        expect(() => manager.dispose(), returnsNormally);
      });
    });
  });
}
