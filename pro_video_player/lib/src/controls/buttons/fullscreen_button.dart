import 'package:flutter/material.dart';

import '../../video_player_theme.dart';

/// A button that toggles fullscreen mode.
///
/// This button displays different icons based on the fullscreen state:
/// - Not fullscreen: Shows fullscreen icon, calls [onEnter] when pressed
/// - In fullscreen: Shows fullscreen_exit icon, calls [onExit] when pressed
///
/// Example:
/// ```dart
/// FullscreenButton(
///   theme: VideoPlayerTheme.light(),
///   isFullscreen: controller.value.isFullscreen,
///   onEnter: () => enterFullscreen(),
///   onExit: () => exitFullscreen(),
/// )
/// ```
class FullscreenButton extends StatelessWidget {
  /// Creates a fullscreen toggle button.
  ///
  /// The [theme] defines the visual appearance.
  /// The [isFullscreen] determines which icon and callback to use.
  /// The [onEnter] callback is called when entering fullscreen.
  /// The [onExit] callback is called when exiting fullscreen.
  const FullscreenButton({
    required this.theme,
    required this.isFullscreen,
    required this.onEnter,
    required this.onExit,
    this.focusNode,
    super.key,
  });

  /// The theme for styling the button.
  final VideoPlayerTheme theme;

  /// Whether the player is currently in fullscreen mode.
  final bool isFullscreen;

  /// Called when the button is tapped to enter fullscreen.
  final VoidCallback onEnter;

  /// Called when the button is tapped to exit fullscreen.
  final VoidCallback onExit;

  /// Optional focus node for directional TV-remote navigation.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => IconButton(
    focusNode: focusNode,
    icon: Icon(isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
    color: theme.primaryColor,
    iconSize: theme.iconSize,
    tooltip: isFullscreen ? 'Exit fullscreen' : 'Fullscreen',
    onPressed: isFullscreen ? onExit : onEnter,
  );
}
