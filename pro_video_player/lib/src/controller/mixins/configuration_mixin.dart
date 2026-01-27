import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

import '../controller_base.dart';

/// Mixin providing configuration and settings functionality.
mixin ConfigurationMixin on ProVideoPlayerControllerBase {
  /// Sets whether the video should loop.
  Future<void> setLooping(bool looping) async {
    ensureInitializedInternal();
    return services.configurationManager.setLooping(looping);
  }

  /// Sets the video scaling mode.
  ///
  /// Determines how the video fills the player viewport:
  /// - [VideoScalingMode.fit]: Letterbox mode, shows entire video with black bars
  /// - [VideoScalingMode.fill]: Crop mode, fills viewport while maintaining aspect ratio
  /// - [VideoScalingMode.stretch]: Stretch mode, ignores aspect ratio
  Future<void> setScalingMode(VideoScalingMode mode) async {
    ensureInitializedInternal();
    return services.configurationManager.setScalingMode(mode);
  }

  /// Sets whether background playback is enabled.
  ///
  /// Enables or disables background playback for the current player.
  ///
  /// When enabled, audio continues playing when the app is backgrounded.
  /// The video will pause but audio will continue.
  ///
  /// **Platform behavior:**
  /// - **iOS**: Requires `UIBackgroundModes` with `audio` in Info.plist
  /// - **Android**: Requires foreground service permission (Android 14+)
  /// - **macOS**: Background playback is **always enabled** by default
  /// - **Web/Windows/Linux**: Not supported
  ///
  /// Returns `true` if background playback was successfully enabled/disabled,
  /// `false` if the platform doesn't support it or isn't configured correctly.
  Future<bool> setBackgroundPlayback({required bool enabled}) async {
    ensureInitializedInternal();
    return services.configurationManager.setBackgroundPlayback(enabled: enabled);
  }

  /// Returns whether background playback is supported on this platform.
  ///
  /// **Note:** This method does NOT require the player to be initialized since
  /// it only checks platform capabilities, not player state.
  ///
  /// **Platform support:**
  /// - **iOS**: `true` (requires proper Info.plist configuration)
  /// - **Android**: `true` (requires proper manifest configuration)
  /// - **macOS**: Always `true`
  /// - **Web/Windows/Linux**: `false`
  Future<bool> isBackgroundPlaybackSupported() async => services.configurationManager.isBackgroundPlaybackSupported();

  /// Returns whether background playback is available for this player.
  ///
  /// Returns `true` if the platform supports background playback and it's
  /// currently enabled.
  bool get isBackgroundPlaybackEnabled => value.isBackgroundPlaybackEnabled;
}
