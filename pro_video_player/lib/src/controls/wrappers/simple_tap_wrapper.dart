import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyRepeatEvent, LogicalKeyboardKey;

import '../../pro_video_player_controller.dart';
import '../../video_controls_controller.dart';

/// Simple tap wrapper for showing/hiding controls.
///
/// This wrapper provides basic tap-to-show/hide functionality:
/// - Tap to toggle controls visibility
/// - Respects casting state (always show during casting)
/// - Used when gestures are disabled or in compact mode
class SimpleTapWrapper extends StatelessWidget {
  /// Creates a simple tap wrapper.
  const SimpleTapWrapper({
    required this.child,
    required this.controller,
    required this.controlsController,
    super.key,
  });

  /// The controls content to wrap.
  final Widget child;

  /// The video player controller.
  final ProVideoPlayerController controller;

  /// The controls controller.
  final VideoControlsController controlsController;

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
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onTap: () {
      final isCasting = controller.value.isCasting;
      if (isCasting) {
        if (!controlsController.controlsState.visible) {
          controlsController.showControls();
        }
        return;
      }

      controlsController.toggleControlsVisibility();

      if (controlsController.controlsState.visible) {
        controlsController.resetHideTimer();
      }
    },
    child: Focus(onKeyEvent: _handleKeyEvent, child: child),
  );
}
