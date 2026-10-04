import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

import '../pro_video_player_controller.dart';
import '../video_player_theme.dart';
import 'controls_enums.dart';
import 'progress_bar.dart';
import 'video_controls_utils.dart';

/// Bottom controls bar for mobile video player layout.
///
/// Displays:
/// - Progress bar with buffering indicator
/// - Current time position
/// - Playback controls (play/pause, skip, playlist navigation)
/// - Total duration (tap to toggle remaining time)
///
/// This widget is optimized for mobile/touch interfaces with larger tap targets.
class BottomControlsBar extends StatelessWidget {
  /// Creates a bottom controls bar.
  const BottomControlsBar({
    required this.controller,
    required this.theme,
    required this.isFullscreen,
    required this.showRemainingTime,
    required this.gestureSeekPosition,
    required this.showSkipButtons,
    required this.skipDuration,
    required this.liveScrubbingMode,
    required this.enableSeekBarHoverPreview,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onToggleTimeDisplay,
    this.seekBarFocusNode,
    this.onKeyboardInteraction,
    super.key,
  });

  /// The video player controller.
  final ProVideoPlayerController controller;

  /// The theme for styling the controls.
  final VideoPlayerTheme theme;

  /// Whether the player is in fullscreen mode.
  final bool isFullscreen;

  /// Whether to show remaining time instead of total duration.
  final bool showRemainingTime;

  /// The position to display while gesture seeking (overrides actual position).
  final Duration? gestureSeekPosition;

  /// Whether to show skip forward/backward buttons.
  final bool showSkipButtons;

  /// The duration to skip when skip buttons are pressed.
  final Duration skipDuration;

  /// Live scrubbing mode for the progress bar.
  final LiveScrubbingMode liveScrubbingMode;

  /// Whether to enable hover preview on the seek bar.
  final bool enableSeekBarHoverPreview;

  /// Focus node used for TV-remote navigation to the seek bar.
  final FocusNode? seekBarFocusNode;

  /// Called when keyboard input interacts with the seek bar.
  final VoidCallback? onKeyboardInteraction;

  /// Called when the user starts dragging the progress bar.
  final VoidCallback onDragStart;

  /// Called when the user finishes dragging the progress bar.
  final VoidCallback onDragEnd;

  /// Called when the user taps the time display to toggle between total/remaining.
  final VoidCallback onToggleTimeDisplay;

  Widget _buildPlayPauseButton({
    required bool isPlaying,
    required double iconSize,
  }) => Focus(
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.select) {
        unawaited(controller.togglePlayPause());
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: IconButton(
      autofocus: true,
      icon: Icon(
        isPlaying ? Icons.pause : Icons.play_arrow,
        color: theme.primaryColor,
      ),
      iconSize: iconSize,
      onPressed: controller.togglePlayPause,
    ),
  );

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<VideoPlayerValue>(
    valueListenable: controller,
    builder: (context, value, child) {
      // Use gesture seek position if available, otherwise use actual position
      final position = gestureSeekPosition ?? value.position;
      final duration = value.duration;

      // Reduce padding and spacing when not in fullscreen to fit in tighter spaces
      final padding = isFullscreen
          ? theme.controlsPadding
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
      final verticalSpacing = isFullscreen ? 8.0 : 4.0;
      final iconSize = isFullscreen ? theme.iconSize : (theme.iconSize * 0.85);
      final playIconSize = isFullscreen ? 36.0 : 30.0;
      final fontSize = isFullscreen ? 14.0 : 13.0;

      // Mobile: stacked layout with progress bar on top, controls below
      return Container(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar with buffered indicator
            ProgressBar(
              controller: controller,
              theme: theme,
              liveScrubbingMode: liveScrubbingMode,
              enableSeekBarHoverPreview: enableSeekBarHoverPreview,
              focusNode: seekBarFocusNode,
              onKeyboardInteraction: onKeyboardInteraction,
              onDragStart: onDragStart,
              onDragEnd: onDragEnd,
            ),
            SizedBox(height: verticalSpacing),
            // Control buttons row
            Row(
              children: [
                // Current time on the left
                SizedBox(
                  width: 56,
                  child: Text(
                    formatVideoDuration(position),
                    style: TextStyle(
                      color: theme.secondaryColor,
                      fontSize: fontSize,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
                const Spacer(),
                // Centered playback controls
                if (value.playlist != null) ...[
                  IconButton(
                    icon: Icon(Icons.skip_previous, color: theme.primaryColor),
                    iconSize: iconSize,
                    onPressed: controller.playlistPrevious,
                  ),
                  if (showSkipButtons)
                    IconButton(
                      icon: Icon(
                        VideoControlsUtils.getSkipBackwardIcon(skipDuration),
                        color: theme.primaryColor,
                      ),
                      iconSize: iconSize,
                      onPressed: () => controller.seekBackward(skipDuration),
                    ),
                  _buildPlayPauseButton(
                    isPlaying: value.isPlaying,
                    iconSize: playIconSize,
                  ),
                  if (showSkipButtons)
                    IconButton(
                      icon: Icon(
                        VideoControlsUtils.getSkipForwardIcon(skipDuration),
                        color: theme.primaryColor,
                      ),
                      iconSize: iconSize,
                      onPressed: () => controller.seekForward(skipDuration),
                    ),
                  IconButton(
                    icon: Icon(Icons.skip_next, color: theme.primaryColor),
                    iconSize: iconSize,
                    onPressed: controller.playlistNext,
                  ),
                ] else ...[
                  if (showSkipButtons)
                    IconButton(
                      icon: Icon(
                        VideoControlsUtils.getSkipBackwardIcon(skipDuration),
                        color: theme.primaryColor,
                      ),
                      iconSize: iconSize,
                      onPressed: () => controller.seekBackward(skipDuration),
                    ),
                  _buildPlayPauseButton(
                    isPlaying: value.isPlaying,
                    iconSize: playIconSize,
                  ),
                  if (showSkipButtons)
                    IconButton(
                      icon: Icon(
                        VideoControlsUtils.getSkipForwardIcon(skipDuration),
                        color: theme.primaryColor,
                      ),
                      iconSize: iconSize,
                      onPressed: () => controller.seekForward(skipDuration),
                    ),
                ],
                const Spacer(),
                // Total time on the right (tap to toggle remaining time)
                GestureDetector(
                  onTap: onToggleTimeDisplay,
                  child: SizedBox(
                    width: 56,
                    child: Text(
                      showRemainingTime
                          ? '-${formatVideoDuration(duration - position)}'
                          : formatVideoDuration(duration),
                      style: TextStyle(
                        color: theme.secondaryColor,
                        fontSize: fontSize,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
