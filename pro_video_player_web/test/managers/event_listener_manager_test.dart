import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';
import 'package:pro_video_player_web/src/managers/event_listener_manager.dart';

import '../shared/web_test_fixture.dart';

void main() {
  group('EventListenerManager', () {
    late WebVideoPlayerTestFixture fixture;
    late EventListenerManager manager;

    setUp(() {
      fixture = WebVideoPlayerTestFixture();
      fixture.setUp();

      manager = EventListenerManager(
        emitEvent: fixture.emitEvent,
        videoElement: fixture.videoElement,
        onMetadataLoaded: () {},
        getDuration: () => const Duration(seconds: 100),
        getPosition: () => const Duration(seconds: 10),
      );
    });

    tearDown(() async {
      manager.dispose();
      await fixture.tearDown();
    });

    group('initialization', () {
      test('sets up video element event listeners', () {
        manager.initialize();

        // Verify key event listeners are registered
        expect(fixture.videoElement.hasListener('loadedmetadata'), isTrue);
        expect(fixture.videoElement.hasListener('play'), isTrue);
        expect(fixture.videoElement.hasListener('pause'), isTrue);
        expect(fixture.videoElement.hasListener('ended'), isTrue);
      });

      test('can be initialized multiple times safely', () {
        manager.initialize();
        expect(() => manager.initialize(), returnsNormally);
      });
    });

    group('playback state events', () {
      setUp(() {
        manager.initialize();
        fixture.clearEmittedEvents();
      });

      test('emits ready state on loadedmetadata', () async {
        fixture.videoElement.duration = 100.0;
        fixture.videoElement.videoWidth = 1920;
        fixture.videoElement.videoHeight = 1080;

        fixture.videoElement.triggerEvent('loadedmetadata');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final events = fixture.getEmittedEvents();
        expect(events, isNotEmpty);

        final stateEvent = events.whereType<PlaybackStateChangedEvent>().first;
        expect(stateEvent.state, PlaybackState.ready);
      });

      test('emits playing state on play', () async {
        fixture.videoElement.triggerEvent('play');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final event = fixture.verifyEventEmitted<PlaybackStateChangedEvent>();
        expect(event.state, PlaybackState.playing);
      });

      test('emits paused state on pause', () async {
        fixture.videoElement.triggerEvent('pause');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final event = fixture.verifyEventEmitted<PlaybackStateChangedEvent>();
        expect(event.state, PlaybackState.paused);
      });

      test('emits completed state on ended', () async {
        fixture.videoElement.triggerEvent('ended');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final events = fixture.getEmittedEvents();
        final completedEvents = events.whereType<PlaybackCompletedEvent>();
        final stateEvents = events.whereType<PlaybackStateChangedEvent>();

        expect(completedEvents, isNotEmpty);
        expect(stateEvents.any((e) => e.state == PlaybackState.completed), isTrue);
      });

      test('emits buffering state on waiting', () async {
        fixture.videoElement.triggerEvent('waiting');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final event = fixture.verifyEventEmitted<PlaybackStateChangedEvent>();
        expect(event.state, PlaybackState.buffering);
      });
    });

    group('position tracking', () {
      setUp(() {
        manager.initialize();
        fixture.clearEmittedEvents();
      });

      test('emits position changed events on timeupdate', () async {
        fixture.videoElement.currentTime = 10.5;

        fixture.videoElement.triggerEvent('timeupdate');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Position events should be emitted
        final events = fixture.getEmittedEvents<PositionChangedEvent>();
        expect(events, isNotEmpty);
      });

      test('deduplicates position events within 100ms', () async {
        manager.initialize();
        fixture.clearEmittedEvents();

        // Trigger multiple timeupdate events with small changes
        fixture.videoElement.currentTime = 10.0;
        fixture.videoElement.triggerEvent('timeupdate');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        fixture.clearEmittedEvents();

        // Small change (< 100ms) should not emit new event
        fixture.videoElement.currentTime = 10.05; // 50ms change
        fixture.videoElement.triggerEvent('timeupdate');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final events = fixture.getEmittedEvents<PositionChangedEvent>();
        expect(events, isEmpty);
      });
    });

    group('volume and speed events', () {
      setUp(() {
        manager.initialize();
        fixture.clearEmittedEvents();
      });

      test('emits volume changed on volumechange', () async {
        fixture.videoElement.volume = 0.7;

        fixture.videoElement.triggerEvent('volumechange');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final event = fixture.verifyEventEmitted<VolumeChangedEvent>();
        expect(event.volume, 0.7);
      });

      test('emits playback speed changed on ratechange', () async {
        fixture.videoElement.playbackRate = 1.5;

        fixture.videoElement.triggerEvent('ratechange');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final event = fixture.verifyEventEmitted<PlaybackSpeedChangedEvent>();
        expect(event.speed, 1.5);
      });
    });

    group('disposal', () {
      test('can be disposed', () {
        manager.initialize();
        expect(() => manager.dispose(), returnsNormally);
      });

      test('can be disposed multiple times safely', () {
        manager.dispose();
        expect(() => manager.dispose(), returnsNormally);
      });
    });
  });
}
