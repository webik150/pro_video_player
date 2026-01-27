import 'package:flutter/widgets.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

import 'controls/controls_enums.dart';

/// Configuration for button visibility in video player controls.
///
/// Groups all button visibility flags into a single configuration object
/// to simplify constructor parameters and improve maintainability.
///
/// Example:
/// ```dart
/// final config = ButtonsConfig(
///   showFullscreenButton: true,
///   showPipButton: true,
///   showSubtitleButton: true,
/// );
/// ```
class ButtonsConfig {
  /// Creates a button visibility configuration.
  const ButtonsConfig({
    this.showFullscreenButton = true,
    this.showPipButton = true,
    this.showBackgroundPlaybackButton = true,
    this.showSubtitleButton = true,
    this.showAudioButton = true,
    this.showQualityButton = true,
    this.showSpeedButton = true,
    this.showScalingModeButton = true,
    this.showOrientationLockButton = true,
    this.showSkipButtons = true,
  });

  /// Whether to show the fullscreen button.
  final bool showFullscreenButton;

  /// Whether to show the Picture-in-Picture button.
  final bool showPipButton;

  /// Whether to show the background playback toggle button.
  final bool showBackgroundPlaybackButton;

  /// Whether to show the subtitle selection button.
  final bool showSubtitleButton;

  /// Whether to show the audio track selection button.
  final bool showAudioButton;

  /// Whether to show the video quality selection button.
  final bool showQualityButton;

  /// Whether to show the playback speed button.
  final bool showSpeedButton;

  /// Whether to show the scaling mode button.
  final bool showScalingModeButton;

  /// Whether to show the orientation lock button in fullscreen mode.
  final bool showOrientationLockButton;

  /// Whether to show skip forward/backward buttons.
  final bool showSkipButtons;

  /// Creates a copy of this config with the given fields replaced.
  ButtonsConfig copyWith({
    bool? showFullscreenButton,
    bool? showPipButton,
    bool? showBackgroundPlaybackButton,
    bool? showSubtitleButton,
    bool? showAudioButton,
    bool? showQualityButton,
    bool? showSpeedButton,
    bool? showScalingModeButton,
    bool? showOrientationLockButton,
    bool? showSkipButtons,
  }) => ButtonsConfig(
    showFullscreenButton: showFullscreenButton ?? this.showFullscreenButton,
    showPipButton: showPipButton ?? this.showPipButton,
    showBackgroundPlaybackButton: showBackgroundPlaybackButton ?? this.showBackgroundPlaybackButton,
    showSubtitleButton: showSubtitleButton ?? this.showSubtitleButton,
    showAudioButton: showAudioButton ?? this.showAudioButton,
    showQualityButton: showQualityButton ?? this.showQualityButton,
    showSpeedButton: showSpeedButton ?? this.showSpeedButton,
    showScalingModeButton: showScalingModeButton ?? this.showScalingModeButton,
    showOrientationLockButton: showOrientationLockButton ?? this.showOrientationLockButton,
    showSkipButtons: showSkipButtons ?? this.showSkipButtons,
  );
}

/// Configuration for gesture controls in video player.
///
/// Groups all gesture-related settings into a single configuration object
/// to simplify constructor parameters and improve maintainability.
///
/// Example:
/// ```dart
/// final config = GestureConfig(
///   enableDoubleTapSeek: true,
///   enableVolumeGesture: true,
///   skipDuration: Duration(seconds: 10),
/// );
/// ```
class GestureConfig {
  /// Creates a gesture configuration.
  const GestureConfig({
    this.enableGestures = true,
    this.enableDoubleTapSeek = true,
    this.enableVolumeGesture = true,
    this.enableBrightnessGesture = true,
    this.enableSeekGesture = true,
    this.enablePlaybackSpeedGesture = true,
    this.skipDuration = const Duration(seconds: 10),
    this.seekSecondsPerInch = 20.0,
    this.onBrightnessChanged,
  });

  /// Whether to enable gesture controls.
  final bool enableGestures;

  /// Whether to enable double-tap to seek gestures.
  final bool enableDoubleTapSeek;

  /// Whether to enable volume control gestures (vertical swipe on right).
  final bool enableVolumeGesture;

  /// Whether to enable brightness control gestures (vertical swipe on left).
  final bool enableBrightnessGesture;

  /// Whether to enable seek gestures (horizontal swipe).
  final bool enableSeekGesture;

  /// Whether to enable playback speed gestures (two-finger vertical swipe).
  final bool enablePlaybackSpeedGesture;

  /// Duration to skip when skip buttons are tapped or double-tap gesture is used.
  final Duration skipDuration;

  /// How many seconds to seek per inch of horizontal swipe gesture.
  ///
  /// This controls the sensitivity of the horizontal swipe seek gesture
  /// based on physical distance, ensuring consistent behavior across
  /// devices with different screen densities.
  final double seekSecondsPerInch;

  /// Callback when brightness is changed via gesture.
  final ValueChanged<double>? onBrightnessChanged;

  /// Creates a copy of this config with the given fields replaced.
  GestureConfig copyWith({
    bool? enableGestures,
    bool? enableDoubleTapSeek,
    bool? enableVolumeGesture,
    bool? enableBrightnessGesture,
    bool? enableSeekGesture,
    bool? enablePlaybackSpeedGesture,
    Duration? skipDuration,
    double? seekSecondsPerInch,
    ValueChanged<double>? onBrightnessChanged,
  }) => GestureConfig(
    enableGestures: enableGestures ?? this.enableGestures,
    enableDoubleTapSeek: enableDoubleTapSeek ?? this.enableDoubleTapSeek,
    enableVolumeGesture: enableVolumeGesture ?? this.enableVolumeGesture,
    enableBrightnessGesture: enableBrightnessGesture ?? this.enableBrightnessGesture,
    enableSeekGesture: enableSeekGesture ?? this.enableSeekGesture,
    enablePlaybackSpeedGesture: enablePlaybackSpeedGesture ?? this.enablePlaybackSpeedGesture,
    skipDuration: skipDuration ?? this.skipDuration,
    seekSecondsPerInch: seekSecondsPerInch ?? this.seekSecondsPerInch,
    onBrightnessChanged: onBrightnessChanged ?? this.onBrightnessChanged,
  );
}

/// Configuration for controls behavior (auto-hide, keyboard shortcuts, etc.).
///
/// Groups behavior-related settings for video player controls into a single
/// configuration object to simplify constructor parameters.
///
/// Example:
/// ```dart
/// final config = ControlsBehaviorConfig(
///   autoHide: true,
///   autoHideDuration: Duration(seconds: 3),
///   enableKeyboardShortcuts: true,
/// );
/// ```
class ControlsBehaviorConfig {
  /// Creates a controls behavior configuration.
  const ControlsBehaviorConfig({
    this.autoHide = true,
    this.autoHideDuration = const Duration(seconds: 2),
    this.enableKeyboardShortcuts = true,
    this.keyboardSeekDuration = const Duration(seconds: 5),
    this.enableContextMenu = true,
    this.minimalToolbarOnDesktop = true,
    this.enableSeekBarHoverPreview = true,
  });

  /// Whether to automatically hide controls when playing.
  final bool autoHide;

  /// Duration before controls are hidden when [autoHide] is enabled.
  final Duration autoHideDuration;

  /// Whether to enable keyboard shortcuts on desktop platforms.
  final bool enableKeyboardShortcuts;

  /// Duration to seek when using keyboard arrow keys.
  final Duration keyboardSeekDuration;

  /// Whether to enable right-click context menu.
  final bool enableContextMenu;

  /// Whether to use minimal toolbar on desktop platforms.
  final bool minimalToolbarOnDesktop;

  /// Whether to enable seek bar hover preview on desktop.
  final bool enableSeekBarHoverPreview;

  /// Creates a copy of this config with the given fields replaced.
  ControlsBehaviorConfig copyWith({
    bool? autoHide,
    Duration? autoHideDuration,
    bool? enableKeyboardShortcuts,
    Duration? keyboardSeekDuration,
    bool? enableContextMenu,
    bool? minimalToolbarOnDesktop,
    bool? enableSeekBarHoverPreview,
  }) => ControlsBehaviorConfig(
    autoHide: autoHide ?? this.autoHide,
    autoHideDuration: autoHideDuration ?? this.autoHideDuration,
    enableKeyboardShortcuts: enableKeyboardShortcuts ?? this.enableKeyboardShortcuts,
    keyboardSeekDuration: keyboardSeekDuration ?? this.keyboardSeekDuration,
    enableContextMenu: enableContextMenu ?? this.enableContextMenu,
    minimalToolbarOnDesktop: minimalToolbarOnDesktop ?? this.minimalToolbarOnDesktop,
    enableSeekBarHoverPreview: enableSeekBarHoverPreview ?? this.enableSeekBarHoverPreview,
  );
}

/// Configuration for playback options (speed, scaling, live scrubbing).
///
/// Groups playback-related settings into a single configuration object
/// to simplify constructor parameters.
///
/// Example:
/// ```dart
/// final config = PlaybackOptionsConfig(
///   speedOptions: [0.5, 1.0, 1.5, 2.0],
///   scalingModeOptions: [VideoScalingMode.fit, VideoScalingMode.fill],
///   liveScrubbingMode: LiveScrubbingMode.adaptive,
/// );
/// ```
class PlaybackOptionsConfig {
  /// Creates a playback options configuration.
  const PlaybackOptionsConfig({
    this.speedOptions = const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
    this.scalingModeOptions = const [VideoScalingMode.fit, VideoScalingMode.fill, VideoScalingMode.stretch],
    this.liveScrubbingMode = LiveScrubbingMode.adaptive,
  });

  /// Available playback speed options.
  final List<double> speedOptions;

  /// Available scaling mode options.
  final List<VideoScalingMode> scalingModeOptions;

  /// Controls when live scrubbing is enabled for the seek bar.
  ///
  /// Live scrubbing updates the video position immediately as the user drags
  /// the progress bar, providing real-time feedback.
  final LiveScrubbingMode liveScrubbingMode;

  /// Creates a copy of this config with the given fields replaced.
  PlaybackOptionsConfig copyWith({
    List<double>? speedOptions,
    List<VideoScalingMode>? scalingModeOptions,
    LiveScrubbingMode? liveScrubbingMode,
  }) => PlaybackOptionsConfig(
    speedOptions: speedOptions ?? this.speedOptions,
    scalingModeOptions: scalingModeOptions ?? this.scalingModeOptions,
    liveScrubbingMode: liveScrubbingMode ?? this.liveScrubbingMode,
  );
}

/// Configuration for fullscreen behavior.
///
/// Groups fullscreen-related settings into a single configuration object
/// to simplify constructor parameters.
///
/// Example:
/// ```dart
/// final config = FullscreenConfig(
///   orientation: FullscreenOrientation.landscapeBoth,
///   onEnterFullscreen: () => print('Entered fullscreen'),
///   onExitFullscreen: () => print('Exited fullscreen'),
/// );
/// ```
class FullscreenConfig {
  /// Creates a fullscreen configuration.
  const FullscreenConfig({
    this.orientation = FullscreenOrientation.landscapeBoth,
    this.onEnterFullscreen,
    this.onExitFullscreen,
  });

  /// Preferred screen orientation when entering fullscreen.
  final FullscreenOrientation orientation;

  /// Callback invoked when fullscreen mode is entered.
  final VoidCallback? onEnterFullscreen;

  /// Callback invoked when fullscreen mode is exited.
  final VoidCallback? onExitFullscreen;

  /// Creates a copy of this config with the given fields replaced.
  FullscreenConfig copyWith({
    FullscreenOrientation? orientation,
    VoidCallback? onEnterFullscreen,
    VoidCallback? onExitFullscreen,
  }) => FullscreenConfig(
    orientation: orientation ?? this.orientation,
    onEnterFullscreen: onEnterFullscreen ?? this.onEnterFullscreen,
    onExitFullscreen: onExitFullscreen ?? this.onExitFullscreen,
  );
}
