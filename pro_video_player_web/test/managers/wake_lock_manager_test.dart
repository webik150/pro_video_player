import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_web/src/abstractions/wake_lock_interface.dart';
import 'package:pro_video_player_web/src/managers/wake_lock_manager.dart';

import '../shared/web_test_fixture.dart';

void main() {
  group('WakeLockManager', () {
    late WebVideoPlayerTestFixture fixture;
    late WakeLockManager manager;
    late MockWakeLock mockWakeLock;

    setUp(() {
      fixture = WebVideoPlayerTestFixture();
      fixture.setUp();
      mockWakeLock = MockWakeLock();
      manager = WakeLockManager(
        emitEvent: fixture.emitEvent,
        videoElement: fixture.videoElement,
        wakeLock: mockWakeLock,
      );
    });

    tearDown(() async {
      manager.dispose();
      await fixture.tearDown();
    });

    group('initialization', () {
      test('starts with wake lock disabled', () {
        expect(manager.isActive, isFalse);
        expect(mockWakeLock.isLocked, isFalse);
      });

      test('respects initial preventScreenSleep setting', () {
        final managerWithSleepDisabled = WakeLockManager(
          emitEvent: fixture.emitEvent,
          videoElement: fixture.videoElement,
          wakeLock: mockWakeLock,
          preventScreenSleep: false,
        );

        expect(managerWithSleepDisabled.preventScreenSleep, isFalse);

        managerWithSleepDisabled.dispose();
      });

      test('defaults to preventScreenSleep enabled', () {
        expect(manager.preventScreenSleep, isTrue);
      });
    });

    group('wake lock acquisition', () {
      test('acquires wake lock when playing', () async {
        await manager.updateState(isPlaying: true, isPipActive: false, isInBackground: false);

        expect(mockWakeLock.isLocked, isTrue);
        expect(manager.isActive, isTrue);
      });

      test('does not acquire wake lock when paused', () async {
        await manager.updateState(isPlaying: false, isPipActive: false, isInBackground: false);

        expect(mockWakeLock.isLocked, isFalse);
        expect(manager.isActive, isFalse);
      });

      test('does not acquire wake lock when in background (not PiP)', () async {
        await manager.updateState(isPlaying: true, isPipActive: false, isInBackground: true);

        expect(mockWakeLock.isLocked, isFalse);
        expect(manager.isActive, isFalse);
      });

      test('acquires wake lock when playing in PiP (even if backgrounded)', () async {
        await manager.updateState(isPlaying: true, isPipActive: true, isInBackground: true);

        expect(mockWakeLock.isLocked, isTrue);
        expect(manager.isActive, isTrue);
      });

      test('does not re-acquire if already active', () async {
        await manager.updateState(isPlaying: true, isPipActive: false, isInBackground: false);

        expect(mockWakeLock.requestCount, 1);

        await manager.updateState(isPlaying: true, isPipActive: false, isInBackground: false);

        expect(mockWakeLock.requestCount, 1); // Should not request again
      });

      test('does not acquire when preventScreenSleep is false', () async {
        final managerWithSleepDisabled = WakeLockManager(
          emitEvent: fixture.emitEvent,
          videoElement: fixture.videoElement,
          wakeLock: mockWakeLock,
          preventScreenSleep: false,
        );

        await managerWithSleepDisabled.updateState(isPlaying: true, isPipActive: false, isInBackground: false);

        expect(mockWakeLock.isLocked, isFalse);
        expect(managerWithSleepDisabled.isActive, isFalse);

        managerWithSleepDisabled.dispose();
      });
    });

    group('wake lock release', () {
      test('releases wake lock when stopping playback', () async {
        await manager.updateState(isPlaying: true, isPipActive: false, isInBackground: false);
        expect(mockWakeLock.isLocked, isTrue);

        await manager.updateState(isPlaying: false, isPipActive: false, isInBackground: false);

        expect(mockWakeLock.isLocked, isFalse);
        expect(manager.isActive, isFalse);
      });

      test('releases wake lock when going to background (not in PiP)', () async {
        await manager.updateState(isPlaying: true, isPipActive: false, isInBackground: false);
        expect(mockWakeLock.isLocked, isTrue);

        await manager.updateState(isPlaying: true, isPipActive: false, isInBackground: true);

        expect(mockWakeLock.isLocked, isFalse);
        expect(manager.isActive, isFalse);
      });

      test('keeps wake lock when going to background in PiP', () async {
        await manager.updateState(isPlaying: true, isPipActive: false, isInBackground: false);
        expect(mockWakeLock.isLocked, isTrue);

        await manager.updateState(isPlaying: true, isPipActive: true, isInBackground: true);

        expect(mockWakeLock.isLocked, isTrue);
        expect(manager.isActive, isTrue);
      });

      test('releases wake lock when exiting PiP in background', () async {
        await manager.updateState(isPlaying: true, isPipActive: true, isInBackground: true);
        expect(mockWakeLock.isLocked, isTrue);

        await manager.updateState(isPlaying: true, isPipActive: false, isInBackground: true);

        expect(mockWakeLock.isLocked, isFalse);
        expect(manager.isActive, isFalse);
      });

      test('does not release if not active', () async {
        await manager.updateState(isPlaying: false, isPipActive: false, isInBackground: false);
        expect(mockWakeLock.releaseCount, 0);

        await manager.updateState(isPlaying: false, isPipActive: false, isInBackground: true);

        expect(mockWakeLock.releaseCount, 0); // Should not try to release
      });
    });

    group('state transitions', () {
      test('handles play -> pause -> play cycle', () async {
        await manager.updateState(isPlaying: true, isPipActive: false, isInBackground: false);
        expect(mockWakeLock.isLocked, isTrue);

        await manager.updateState(isPlaying: false, isPipActive: false, isInBackground: false);
        expect(mockWakeLock.isLocked, isFalse);

        await manager.updateState(isPlaying: true, isPipActive: false, isInBackground: false);
        expect(mockWakeLock.isLocked, isTrue);
      });

      test('handles foreground -> background -> foreground cycle', () async {
        await manager.updateState(isPlaying: true, isPipActive: false, isInBackground: false);
        expect(mockWakeLock.isLocked, isTrue);

        await manager.updateState(isPlaying: true, isPipActive: false, isInBackground: true);
        expect(mockWakeLock.isLocked, isFalse);

        await manager.updateState(isPlaying: true, isPipActive: false, isInBackground: false);
        expect(mockWakeLock.isLocked, isTrue);
      });

      test('handles enter PiP -> exit PiP in background', () async {
        await manager.updateState(isPlaying: true, isPipActive: false, isInBackground: true);
        expect(mockWakeLock.isLocked, isFalse);

        await manager.updateState(isPlaying: true, isPipActive: true, isInBackground: true);
        expect(mockWakeLock.isLocked, isTrue);

        await manager.updateState(isPlaying: true, isPipActive: false, isInBackground: true);
        expect(mockWakeLock.isLocked, isFalse);
      });
    });

    group('API availability', () {
      test('handles wake lock API not available', () async {
        final unavailableWakeLock = MockWakeLock(available: false);
        final managerWithUnavailableApi = WakeLockManager(
          emitEvent: fixture.emitEvent,
          videoElement: fixture.videoElement,
          wakeLock: unavailableWakeLock,
        );

        await managerWithUnavailableApi.updateState(isPlaying: true, isPipActive: false, isInBackground: false);

        expect(unavailableWakeLock.isLocked, isFalse);
        expect(managerWithUnavailableApi.isActive, isFalse);

        managerWithUnavailableApi.dispose();
      });

      test('returns availability status', () {
        expect(manager.isAvailable, isTrue);

        final unavailableWakeLock = MockWakeLock(available: false);
        final managerWithUnavailableApi = WakeLockManager(
          emitEvent: fixture.emitEvent,
          videoElement: fixture.videoElement,
          wakeLock: unavailableWakeLock,
        );

        expect(managerWithUnavailableApi.isAvailable, isFalse);

        managerWithUnavailableApi.dispose();
      });
    });

    group('configuration', () {
      test('can update preventScreenSleep setting', () async {
        await manager.updateState(isPlaying: true, isPipActive: false, isInBackground: false);
        expect(mockWakeLock.isLocked, isTrue);

        await manager.setPreventScreenSleep(false);

        expect(manager.preventScreenSleep, isFalse);
        expect(mockWakeLock.isLocked, isFalse); // Should release
      });

      test('re-acquires when preventScreenSleep re-enabled', () async {
        await manager.updateState(isPlaying: true, isPipActive: false, isInBackground: false);
        expect(mockWakeLock.isLocked, isTrue);

        await manager.setPreventScreenSleep(false);
        expect(mockWakeLock.isLocked, isFalse);

        await manager.setPreventScreenSleep(true);

        expect(mockWakeLock.isLocked, isTrue);
      });
    });

    group('dispose', () {
      test('releases wake lock on dispose', () async {
        await manager.updateState(isPlaying: true, isPipActive: false, isInBackground: false);
        expect(mockWakeLock.isLocked, isTrue);

        manager.dispose();

        expect(mockWakeLock.isLocked, isFalse);
      });

      test('can be called multiple times safely', () {
        manager.dispose();
        expect(() => manager.dispose(), returnsNormally);
      });

      test('does not release if not active', () {
        expect(mockWakeLock.releaseCount, 0);

        manager.dispose();

        expect(mockWakeLock.releaseCount, 0);
      });
    });
  });
}

/// Mock implementation of WakeLockInterface for testing.
class MockWakeLock implements WakeLockInterface {
  MockWakeLock({this.available = true});

  final bool available;
  bool _isLocked = false;
  int requestCount = 0;
  int releaseCount = 0;

  /// Whether a wake lock is currently active.
  bool get isLocked => _isLocked;

  @override
  bool get isAvailable => available;

  @override
  Future<bool> request() async {
    if (!available) return false;
    requestCount++;
    _isLocked = true;
    return true;
  }

  @override
  Future<void> release() async {
    if (!_isLocked) return;
    releaseCount++;
    _isLocked = false;
  }
}
