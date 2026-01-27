import 'dart:async';

import '../abstractions/video_element_interface.dart';
import '../abstractions/wake_lock_interface.dart';
import '../manager_callbacks.dart';
import '../verbose_logging.dart';

/// Manages screen wake lock state machine.
///
/// This manager handles the Screen Wake Lock API to prevent the screen from
/// turning off while video is playing. It implements smart wake lock management
/// based on three factors:
/// - **Playback state**: Video must be playing
/// - **Background state**: App must be in foreground (unless in PiP)
/// - **PiP state**: PiP mode allows wake lock even when backgrounded
///
/// Wake lock is enabled when: `isPlaying AND (NOT isInBackground OR isPipActive)`
/// Wake lock is disabled when: `NOT isPlaying OR (isInBackground AND NOT isPipActive)`
///
/// The manager also respects the `preventScreenSleep` configuration option,
/// which can be used to disable wake lock functionality entirely.
///
/// Browser support:
/// - Chrome/Edge 84+
/// - Safari 16.4+
/// - Firefox: Not supported (as of 2025)
class WakeLockManager with WebManagerCallbacks {
  /// Creates a wake lock manager.
  WakeLockManager({
    required this.emitEvent,
    required this.videoElement,
    required WakeLockInterface wakeLock,
    bool preventScreenSleep = true,
  }) : _wakeLock = wakeLock,
       _preventScreenSleep = preventScreenSleep;

  @override
  final EventEmitter emitEvent;

  @override
  final VideoElementInterface videoElement;

  /// The Wake Lock API wrapper.
  final WakeLockInterface _wakeLock;

  /// Whether screen sleep prevention is enabled.
  bool _preventScreenSleep;

  /// Whether a wake lock is currently active.
  bool _isActive = false;

  /// Current state for smart wake lock management.
  bool _isPlaying = false;
  bool _isPipActive = false;
  bool _isInBackground = false;

  /// Whether screen sleep prevention is enabled.
  bool get preventScreenSleep => _preventScreenSleep;

  /// Whether the Wake Lock API is available.
  bool get isAvailable => _wakeLock.isAvailable;

  /// Whether a wake lock is currently active.
  bool get isActive => _isActive;

  /// Updates the wake lock state based on playback, PiP, and background state.
  ///
  /// The wake lock will be acquired when the video is playing and either:
  /// - The app is in the foreground, OR
  /// - The video is in Picture-in-Picture mode
  ///
  /// The wake lock will be released when:
  /// - The video is paused, OR
  /// - The app is in the background AND not in PiP mode
  Future<void> updateState({required bool isPlaying, required bool isPipActive, required bool isInBackground}) async {
    _isPlaying = isPlaying;
    _isPipActive = isPipActive;
    _isInBackground = isInBackground;

    if (!_preventScreenSleep) {
      // If screen sleep prevention is disabled, ensure wake lock is released
      if (_isActive) {
        await _releaseWakeLock();
      }
      return;
    }

    // Determine if wake lock should be active
    final shouldKeepAwake = _isPlaying && (!_isInBackground || _isPipActive);

    if (shouldKeepAwake && !_isActive) {
      await _acquireWakeLock();
    } else if (!shouldKeepAwake && _isActive) {
      await _releaseWakeLock();
    }
  }

  /// Sets the screen sleep prevention preference.
  ///
  /// If set to false, any active wake lock will be released immediately.
  /// If set to true, the wake lock will be re-acquired if playback conditions
  /// are met (playing and not backgrounded).
  Future<void> setPreventScreenSleep(bool prevent) async {
    _preventScreenSleep = prevent;

    // Update state to apply the new setting
    await updateState(isPlaying: _isPlaying, isPipActive: _isPipActive, isInBackground: _isInBackground);
  }

  /// Acquires a wake lock.
  Future<void> _acquireWakeLock() async {
    if (_isActive) return; // Already active

    try {
      final success = await _wakeLock.request();
      if (success) {
        _isActive = true;
        verboseLog('Screen wake lock acquired', tag: 'WakeLockManager');
      }
    } catch (e) {
      verboseLog('Failed to acquire wake lock: $e', tag: 'WakeLockManager');
    }
  }

  /// Releases the wake lock.
  Future<void> _releaseWakeLock() async {
    if (!_isActive) return; // Not active

    try {
      await _wakeLock.release();
      _isActive = false;
      verboseLog('Screen wake lock released', tag: 'WakeLockManager');
    } catch (e) {
      verboseLog('Failed to release wake lock: $e', tag: 'WakeLockManager');
    }
  }

  /// Updates wake lock state based on current playback conditions.
  ///
  /// This method re-evaluates wake lock state using the current internal state.
  Future<void> updateWakeLock() async {
    await updateState(isPlaying: _isPlaying, isPipActive: _isPipActive, isInBackground: _isInBackground);
  }

  /// Disposes the manager and cleans up resources.
  ///
  /// Releases any active wake lock.
  void dispose() {
    if (_isActive) {
      unawaited(_wakeLock.release());
      _isActive = false;
      verboseLog('Wake lock released on dispose', tag: 'WakeLockManager');
    }
  }
}
