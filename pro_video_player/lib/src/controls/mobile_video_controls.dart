import 'package:flutter/material.dart';

import '../pro_video_player_controller.dart';
import '../video_player_theme.dart';
import 'bottom_controls_bar.dart';
import 'controls_enums.dart';
import 'player_toolbar.dart';

/// Mobile video controls layout.
///
/// This widget implements the mobile-optimized control layout with:
/// - Top gradient overlay with player toolbar
/// - Center play/pause button
/// - Bottom gradient overlay with playback controls
/// - Fullscreen padding for status bars and home indicators
///
/// Example:
/// ```dart
/// MobileVideoControls(
///   controller: controller,
///   theme: theme,
///   controlsState: controlsState,
///   // ... configuration parameters
/// )
/// ```
class MobileVideoControls extends StatelessWidget {
  /// Creates mobile video controls.
  const MobileVideoControls({
    required this.controller,
    required this.theme,
    required this.controlsState,
    required this.gestureSeekPosition,
    required this.showSkipButtons,
    required this.skipDuration,
    required this.liveScrubbingMode,
    required this.showSeekBarHoverPreview,
    required this.showSubtitleButton,
    required this.showAudioButton,
    required this.showQualityButton,
    required this.showSpeedButton,
    required this.showScalingModeButton,
    required this.showBackgroundPlaybackButton,
    required this.showPipButton,
    required this.showOrientationLockButton,
    required this.showFullscreenButton,
    required this.playerToolbarActions,
    required this.maxPlayerToolbarActions,
    required this.autoOverflowActions,
    required this.onDismiss,
    required this.isDesktopPlatform,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onToggleTimeDisplay,
    required this.onShowQualityPicker,
    required this.onShowSubtitlePicker,
    required this.onShowAudioPicker,
    required this.onShowChaptersPicker,
    required this.onShowSpeedPicker,
    required this.onShowScalingModePicker,
    required this.onShowOrientationLockPicker,
    required this.onFullscreenEnter,
    required this.onFullscreenExit,
    required this.centerControls,
    super.key,
  });

  /// The video player controller.
  final ProVideoPlayerController controller;

  /// The theme for styling.
  final VideoPlayerTheme theme;

  /// The controls state.
  final dynamic controlsState; // VideoControlsState

  /// The current seek position during gesture seeking.
  final Duration? gestureSeekPosition;

  /// Whether to show skip forward/backward buttons.
  final bool showSkipButtons;

  /// Duration for skip buttons.
  final Duration skipDuration;

  /// Live scrubbing mode.
  final LiveScrubbingMode liveScrubbingMode;

  /// Whether to enable seek bar hover preview.
  final bool showSeekBarHoverPreview;

  /// Whether to show subtitle button.
  final bool showSubtitleButton;

  /// Whether to show audio button.
  final bool showAudioButton;

  /// Whether to show quality button.
  final bool showQualityButton;

  /// Whether to show speed button.
  final bool showSpeedButton;

  /// Whether to show scaling mode button.
  final bool showScalingModeButton;

  /// Whether to show background playback button.
  final bool showBackgroundPlaybackButton;

  /// Whether to show PiP button.
  final bool showPipButton;

  /// Whether to show orientation lock button.
  final bool showOrientationLockButton;

  /// Whether to show fullscreen button.
  final bool showFullscreenButton;

  /// Custom toolbar actions.
  final List<PlayerToolbarAction>? playerToolbarActions;

  /// Maximum toolbar actions before overflow.
  final int? maxPlayerToolbarActions;

  /// Whether to automatically overflow actions.
  final bool autoOverflowActions;

  /// Callback for dismiss button.
  final VoidCallback? onDismiss;

  /// Whether the current platform is desktop.
  final bool isDesktopPlatform;

  /// Callback when dragging starts.
  final VoidCallback onDragStart;

  /// Callback when dragging ends.
  final VoidCallback onDragEnd;

  /// Callback to toggle time display.
  final VoidCallback onToggleTimeDisplay;

  /// Callback to show quality picker.
  final void Function(BuildContext context, VideoPlayerTheme theme) onShowQualityPicker;

  /// Callback to show subtitle picker.
  final void Function(BuildContext context, VideoPlayerTheme theme) onShowSubtitlePicker;

  /// Callback to show audio picker.
  final void Function(BuildContext context, VideoPlayerTheme theme) onShowAudioPicker;

  /// Callback to show chapters picker.
  final void Function(BuildContext context, VideoPlayerTheme theme) onShowChaptersPicker;

  /// Callback to show speed picker.
  final void Function(BuildContext context, VideoPlayerTheme theme) onShowSpeedPicker;

  /// Callback to show scaling mode picker.
  final void Function(VideoPlayerTheme theme) onShowScalingModePicker;

  /// Callback to show orientation lock picker.
  final void Function(VideoPlayerTheme theme) onShowOrientationLockPicker;

  /// Callback to enter fullscreen.
  final VoidCallback onFullscreenEnter;

  /// Callback to exit fullscreen.
  final VoidCallback onFullscreenExit;

  /// Center controls widget (play button, etc.).
  final Widget centerControls;

  @override
  Widget build(BuildContext context) {
    // Mobile layout: gradient overlays at top and bottom, clear center
    // Use actual safe area insets in fullscreen mode to accommodate notches, status bars, home indicators
    final isFullscreen = controller.value.isFullscreen;
    final padding = MediaQuery.of(context).padding;
    final topPadding = isFullscreen ? padding.top : 0.0;
    final bottomPadding = isFullscreen ? padding.bottom : 0.0;
    final leftPadding = isFullscreen ? padding.left : 0.0;
    final rightPadding = isFullscreen ? padding.right : 0.0;

    // Use ClipRect to handle sub-pixel overflow that can occur on certain screen sizes
    return ClipRect(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top area with gradient (black at top fading to transparent)
          Flexible(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(top: topPadding, left: leftPadding, right: rightPadding),
                child: PlayerToolbar(
                  controller: controller,
                  theme: theme,
                  controlsState: controlsState,
                  showSubtitleButton: showSubtitleButton,
                  showAudioButton: showAudioButton,
                  showQualityButton: showQualityButton,
                  showSpeedButton: showSpeedButton,
                  showScalingModeButton: showScalingModeButton,
                  showBackgroundPlaybackButton: showBackgroundPlaybackButton,
                  showPipButton: showPipButton,
                  showOrientationLockButton: showOrientationLockButton,
                  showFullscreenButton: showFullscreenButton,
                  playerToolbarActions: playerToolbarActions,
                  maxPlayerToolbarActions: maxPlayerToolbarActions,
                  autoOverflowActions: autoOverflowActions,
                  onDismiss: onDismiss,
                  isDesktopPlatform: isDesktopPlatform,
                  onShowQualityPicker: onShowQualityPicker,
                  onShowSubtitlePicker: onShowSubtitlePicker,
                  onShowAudioPicker: onShowAudioPicker,
                  onShowChaptersPicker: onShowChaptersPicker,
                  onShowSpeedPicker: onShowSpeedPicker,
                  onShowScalingModePicker: onShowScalingModePicker,
                  onShowOrientationLockPicker: onShowOrientationLockPicker,
                  onFullscreenEnter: onFullscreenEnter,
                  onFullscreenExit: onFullscreenExit,
                ),
              ),
            ),
          ),
          // Center controls - no background, video visible
          centerControls,
          // Bottom area with gradient (transparent at top fading to black)
          // Not flexible - needs minimum height for playback controls
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomPadding, left: leftPadding, right: rightPadding),
              child: BottomControlsBar(
                controller: controller,
                theme: theme,
                isFullscreen: isFullscreen,
                showRemainingTime: (controlsState as dynamic).showRemainingTime as bool,
                gestureSeekPosition: gestureSeekPosition,
                showSkipButtons: showSkipButtons,
                skipDuration: skipDuration,
                liveScrubbingMode: liveScrubbingMode,
                enableSeekBarHoverPreview: showSeekBarHoverPreview,
                onDragStart: onDragStart,
                onDragEnd: onDragEnd,
                onToggleTimeDisplay: onToggleTimeDisplay,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
