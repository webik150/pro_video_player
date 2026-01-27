import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';
import 'package:pro_video_player_web/src/abstractions/media_session_interface.dart';
import 'package:pro_video_player_web/src/managers/media_session_manager.dart';

import '../shared/web_test_fixture.dart';

void main() {
  group('MediaSessionManager', () {
    late WebVideoPlayerTestFixture fixture;
    late MediaSessionManager manager;
    late MockMediaSession mockMediaSession;

    setUp(() {
      fixture = WebVideoPlayerTestFixture();
      fixture.setUp();
      mockMediaSession = MockMediaSession();
      manager = MediaSessionManager(
        emitEvent: fixture.emitEvent,
        videoElement: fixture.videoElement,
        mediaSession: mockMediaSession,
      );
    });

    tearDown(() async {
      manager.dispose();
      await fixture.tearDown();
    });

    group('initialization', () {
      test('does not throw when Media Session API is not available', () {
        final unavailableSession = MockMediaSession(available: false);
        final managerWithUnavailableSession = MediaSessionManager(
          emitEvent: fixture.emitEvent,
          videoElement: fixture.videoElement,
          mediaSession: unavailableSession,
        );

        expect(
          () => managerWithUnavailableSession.setupActionHandlers(
            onPlay: () async {},
            onPause: () async {},
            onStop: () async {},
          ),
          returnsNormally,
        );

        managerWithUnavailableSession.dispose();
      });

      test('sets up action handlers when API is available', () {
        var playCallCount = 0;
        var pauseCallCount = 0;
        var stopCallCount = 0;

        manager.setupActionHandlers(
          onPlay: () async => playCallCount++,
          onPause: () async => pauseCallCount++,
          onStop: () async => stopCallCount++,
        );

        expect(mockMediaSession.actionHandlers.containsKey('play'), isTrue);
        expect(mockMediaSession.actionHandlers.containsKey('pause'), isTrue);
        expect(mockMediaSession.actionHandlers.containsKey('stop'), isTrue);
        expect(mockMediaSession.actionHandlers.containsKey('seekforward'), isTrue);
        expect(mockMediaSession.actionHandlers.containsKey('seekbackward'), isTrue);
      });
    });

    group('action handlers', () {
      test('play handler calls onPlay callback', () {
        var callCount = 0;
        manager.setupActionHandlers(onPlay: () async => callCount++, onPause: () async {}, onStop: () async {});

        mockMediaSession.triggerAction('play');

        expect(callCount, 1);
      });

      test('pause handler calls onPause callback', () {
        var callCount = 0;
        manager.setupActionHandlers(onPlay: () async {}, onPause: () async => callCount++, onStop: () async {});

        mockMediaSession.triggerAction('pause');

        expect(callCount, 1);
      });

      test('stop handler calls onStop callback', () {
        var callCount = 0;
        manager.setupActionHandlers(onPlay: () async {}, onPause: () async {}, onStop: () async => callCount++);

        mockMediaSession.triggerAction('stop');

        expect(callCount, 1);
      });

      test('seekforward handler seeks 15 seconds forward', () {
        fixture.videoElement.currentTime = 30.0;

        manager.setupActionHandlers(onPlay: () async {}, onPause: () async {}, onStop: () async {});

        mockMediaSession.triggerAction('seekforward');

        expect(fixture.videoElement.currentTime, 45.0);
      });

      test('seekbackward handler seeks 15 seconds backward', () {
        fixture.videoElement.currentTime = 30.0;
        fixture.videoElement.duration = 100.0;

        manager.setupActionHandlers(onPlay: () async {}, onPause: () async {}, onStop: () async {});

        mockMediaSession.triggerAction('seekbackward');

        expect(fixture.videoElement.currentTime, 15.0);
      });

      test('seekbackward does not seek before 0', () {
        fixture.videoElement.currentTime = 5.0;
        fixture.videoElement.duration = 100.0;

        manager.setupActionHandlers(onPlay: () async {}, onPause: () async {}, onStop: () async {});

        mockMediaSession.triggerAction('seekbackward');

        expect(fixture.videoElement.currentTime, 0.0);
      });
    });

    group('metadata', () {
      test('sets metadata with all fields', () {
        const metadata = MediaMetadata(
          title: 'Test Video',
          artist: 'Test Artist',
          album: 'Test Album',
          artworkUrl: 'https://example.com/artwork.jpg',
        );

        manager.setMetadata(metadata);

        expect(mockMediaSession.metadata, isNotNull);
        expect(mockMediaSession.metadata!['title'], 'Test Video');
        expect(mockMediaSession.metadata!['artist'], 'Test Artist');
        expect(mockMediaSession.metadata!['album'], 'Test Album');
        expect(mockMediaSession.metadata!['artwork'], 'https://example.com/artwork.jpg');
      });

      test('sets metadata with only title', () {
        const metadata = MediaMetadata(title: 'Test Video');

        manager.setMetadata(metadata);

        expect(mockMediaSession.metadata, isNotNull);
        expect(mockMediaSession.metadata!['title'], 'Test Video');
        expect(mockMediaSession.metadata!['artist'], '');
        expect(mockMediaSession.metadata!['album'], '');
        expect(mockMediaSession.metadata!['artwork'], isNull);
      });

      test('handles null values in metadata', () {
        const metadata = MediaMetadata();

        manager.setMetadata(metadata);

        expect(mockMediaSession.metadata, isNotNull);
        expect(mockMediaSession.metadata!['title'], '');
        expect(mockMediaSession.metadata!['artist'], '');
        expect(mockMediaSession.metadata!['album'], '');
        expect(mockMediaSession.metadata!['artwork'], isNull);
      });

      test('does nothing when API is not available', () {
        final unavailableSession = MockMediaSession(available: false);
        final managerWithUnavailableSession = MediaSessionManager(
          emitEvent: fixture.emitEvent,
          videoElement: fixture.videoElement,
          mediaSession: unavailableSession,
        );

        const metadata = MediaMetadata(title: 'Test Video');

        expect(() => managerWithUnavailableSession.setMetadata(metadata), returnsNormally);
        expect(unavailableSession.metadata, isNull);

        managerWithUnavailableSession.dispose();
      });

      test('sets up action handlers when setting metadata', () {
        var playCallCount = 0;

        manager.setupActionHandlers(onPlay: () async => playCallCount++, onPause: () async {}, onStop: () async {});

        const metadata = MediaMetadata(title: 'Test Video');
        manager.setMetadata(metadata);

        // Action handlers should still be set up
        expect(mockMediaSession.actionHandlers.containsKey('play'), isTrue);
        expect(mockMediaSession.actionHandlers.containsKey('pause'), isTrue);
      });
    });

    group('availability', () {
      test('returns true when API is available', () {
        expect(manager.isAvailable, isTrue);
      });

      test('returns false when API is not available', () {
        final unavailableSession = MockMediaSession(available: false);
        final managerWithUnavailableSession = MediaSessionManager(
          emitEvent: fixture.emitEvent,
          videoElement: fixture.videoElement,
          mediaSession: unavailableSession,
        );

        expect(managerWithUnavailableSession.isAvailable, isFalse);

        managerWithUnavailableSession.dispose();
      });
    });

    group('dispose', () {
      test('clears action handlers', () {
        manager.setupActionHandlers(onPlay: () async {}, onPause: () async {}, onStop: () async {});

        expect(mockMediaSession.actionHandlers.isNotEmpty, isTrue);

        manager.dispose();

        expect(mockMediaSession.actionHandlers.isEmpty, isTrue);
      });

      test('clears metadata', () {
        const metadata = MediaMetadata(title: 'Test Video');
        manager.setMetadata(metadata);

        expect(mockMediaSession.metadata, isNotNull);

        manager.dispose();

        expect(mockMediaSession.metadata, isNull);
      });

      test('can be called multiple times safely', () {
        manager.dispose();
        expect(() => manager.dispose(), returnsNormally);
      });
    });
  });
}

/// Mock implementation of MediaSessionInterface for testing.
class MockMediaSession implements MediaSessionInterface {
  MockMediaSession({this.available = true});

  final bool available;
  Map<String, dynamic>? metadata;
  final Map<String, Function> actionHandlers = {};

  @override
  bool get isAvailable => available;

  @override
  void setMetadata({required String title, required String artist, required String album, String? artworkUrl}) {
    if (!available) return;
    metadata = {'title': title, 'artist': artist, 'album': album, 'artwork': artworkUrl};
  }

  @override
  void setActionHandler(String action, void Function() handler) {
    if (!available) return;
    actionHandlers[action] = handler;
  }

  @override
  void clearActionHandlers() {
    actionHandlers.clear();
  }

  @override
  void clearMetadata() {
    metadata = null;
  }

  /// Test helper: Trigger an action handler.
  void triggerAction(String action) {
    final handler = actionHandlers[action];
    if (handler != null) {
      // ignore: avoid_dynamic_calls
      handler();
    }
  }
}
