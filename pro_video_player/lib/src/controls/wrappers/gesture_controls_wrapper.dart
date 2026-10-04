import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyRepeatEvent, LogicalKeyboardKey;

import '../../pro_video_player_controller.dart';
import '../../video_controls_controller.dart';
import '../../video_player_gesture_detector.dart';

/// Mobile controls wrapper with full gesture detection.
///
/// This wrapper provides mobile-specific gesture interactions:
/// - Double-tap to seek
/// - Vertical swipe on left: Brightness control
/// - Vertical swipe on right: Volume control
/// - Horizontal swipe: Seek
/// - Two-finger vertical swipe: Playback speed
/// - Tap to show/hide controls
class GestureControlsWrapper extends StatelessWidget {
  /// Creates a gesture controls wrapper.
  const GestureControlsWrapper({
    required this.child,
    required this.controller,
    required this.controlsController,
    required this.skipDuration,
    required this.seekSecondsPerInch,
    required this.enableDoubleTapSeek,
    required this.enableVolumeGesture,
    required this.enableBrightnessGesture,
    required this.enableSeekGesture,
    required this.enablePlaybackSpeedGesture,
    required this.autoHide,
    required this.autoHideDuration,
    required this.onBrightnessChanged,
    super.key,
  });

  /// The controls content to wrap.
  final Widget child;

  /// The video player controller.
  final ProVideoPlayerController controller;

  /// The controls controller.
  final VideoControlsController controlsController;

  /// Duration to skip when double-tapping.
  final Duration skipDuration;

  /// Seconds to seek per inch of horizontal swipe.
  final double seekSecondsPerInch;

  /// Whether to enable double-tap to seek gestures.
  final bool enableDoubleTapSeek;

  /// Whether to enable volume control gestures.
  final bool enableVolumeGesture;

  /// Whether to enable brightness control gestures.
  final bool enableBrightnessGesture;

  /// Whether to enable seek gestures.
  final bool enableSeekGesture;

  /// Whether to enable playback speed gestures.
  final bool enablePlaybackSpeedGesture;

  /// Whether to automatically hide controls.
  final bool autoHide;

  /// Duration before controls are hidden.
  final Duration autoHideDuration;

  /// Callback when brightness is changed.
  final ValueChanged<double>? onBrightnessChanged;

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
        (event.logicalKey == LogicalKeyboardKey.arrowUp ||
            event.logicalKey == LogicalKeyboardKey.arrowDown ||
            event.logicalKey == LogicalKeyboardKey.arrowLeft ||
            event.logicalKey == LogicalKeyboardKey.arrowRight)) {
      controlsController
        ..showControls()
        ..resetHideTimer();
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => VideoPlayerGestureDetector(
    controller: controller,
    seekDuration: skipDuration,
    seekSecondsPerInch: seekSecondsPerInch,
    enableDoubleTapSeek: enableDoubleTapSeek,
    enableVolumeGesture: enableVolumeGesture,
    enableBrightnessGesture: enableBrightnessGesture,
    enableSeekGesture: enableSeekGesture,
    enablePlaybackSpeedGesture: enablePlaybackSpeedGesture,
    autoHideControls: autoHide,
    autoHideDelay: autoHideDuration,
    onControlsVisibilityChanged: (visible, {instantly = false}) {
      final isCasting = controller.value.isCasting;
      if (isCasting && !visible) return;

      if (visible) {
        controlsController.showControls();
      } else {
        controlsController.hideControls(instantly: instantly);
      }

      if (visible) {
        controlsController.resetHideTimer();
      }
    },
    onBrightnessChanged: onBrightnessChanged,
    onSeekGestureUpdate: (position) {
      controlsController.gestureSeekPositionValue = position;
    },
    child: Focus(onKeyEvent: _handleKeyEvent, child: child),
  );
}
