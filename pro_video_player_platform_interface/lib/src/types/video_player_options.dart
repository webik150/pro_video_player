import '../../pro_video_player_platform_interface.dart' show VideoSource;
import 'abr_mode.dart';
import 'buffering_tier.dart';
import 'subtitle_discovery_mode.dart';
import 'subtitle_render_mode.dart';
import 'types.dart' show VideoSource;
import 'video_source.dart' show VideoSource;

/// Video scaling mode that controls how video content is displayed within the player.
///
/// Determines how the video fills the player's viewport when the video's
/// aspect ratio doesn't match the player's aspect ratio.
enum VideoScalingMode {
  /// Fit mode - Maintains aspect ratio, shows letterboxing/pillarboxing.
  ///
  /// The entire video is visible. Black bars (letterboxing or pillarboxing)
  /// appear when the video's aspect ratio doesn't match the player.
  ///
  /// - iOS: Maps to `AVLayerVideoGravity.resizeAspect`
  /// - Android: Maps to `AspectRatioFrameLayout.RESIZE_MODE_FIT`
  /// - Web: Maps to CSS `object-fit: contain`
  fit,

  /// Fill mode - Maintains aspect ratio, crops to fill viewport.
  ///
  /// The video fills the entire player viewport. Parts of the video may be
  /// cropped when the aspect ratios don't match.
  ///
  /// - iOS: Maps to `AVLayerVideoGravity.resizeAspectFill`
  /// - Android: Maps to `AspectRatioFrameLayout.RESIZE_MODE_ZOOM`
  /// - Web: Maps to CSS `object-fit: cover`
  fill,

  /// Stretch mode - Ignores aspect ratio, stretches to fill viewport.
  ///
  /// The video is stretched to completely fill the player viewport,
  /// potentially distorting the image if aspect ratios don't match.
  ///
  /// - iOS: Maps to `AVLayerVideoGravity.resize`
  /// - Android: Maps to `AspectRatioFrameLayout.RESIZE_MODE_FILL`
  /// - Web: Maps to CSS `object-fit: fill`
  stretch,
}

/// Orientation options for fullscreen mode.
enum FullscreenOrientation {
  /// Allow only portrait up orientation.
  portraitUp,

  /// Allow only portrait down orientation (upside down).
  portraitDown,

  /// Allow both portrait orientations.
  portraitBoth,

  /// Allow only landscape left orientation (home button on right).
  landscapeLeft,

  /// Allow only landscape right orientation (home button on left).
  landscapeRight,

  /// Allow both landscape orientations (default for fullscreen video).
  landscapeBoth,

  /// Allow all orientations.
  all,
}

/// Configuration options for the video player.
///
/// All features are configurable by the developer. Features that are disabled
/// will not be available at runtime (e.g., calling `enterPip()` when [allowPip]
/// is false will have no effect).
///
/// Example:
/// ```dart
/// const options = VideoPlayerOptions(
///   autoPlay: true,
///   allowBackgroundPlayback: true,
///   allowPip: true,
///   subtitlesEnabled: true,
///   preferredSubtitleLanguage: 'en',
/// );
/// ```
class VideoPlayerOptions {
  /// Creates video player options.
  ///
  /// All parameters have sensible defaults that can be overridden.
  const VideoPlayerOptions({
    this.autoPlay = false,
    this.looping = false,
    this.volume = 1.0,
    this.playbackSpeed = 1.0,
    this.allowBackgroundPlayback = false,
    this.mixWithOthers = false,
    this.preventScreenSleep = true,
    this.allowPip = true,
    this.autoEnterPipOnBackground = false,
    this.subtitlesEnabled = true,
    this.showSubtitlesByDefault = false,
    this.preferredSubtitleLanguage,
    this.autoDiscoverSubtitles = false,
    this.subtitleDiscoveryMode = SubtitleDiscoveryMode.prefix,
    this.subtitleRenderMode = SubtitleRenderMode.auto,
    this.scalingMode = VideoScalingMode.fit,
    this.fullscreenOrientation = FullscreenOrientation.landscapeBoth,
    this.fullscreenOnly = false,
    this.showFullscreenStatusBar = true,
    this.bufferingTier = BufferingTier.medium,
    this.allowCasting = true,
    this.abrMode = AbrMode.auto,
    this.minBitrate,
    this.maxBitrate,
  });

  // ============================================
  // Playback Options
  // ============================================

  /// Whether to start playback automatically when initialized.
  ///
  /// Defaults to `false`.
  final bool autoPlay;

  /// Whether to loop the video when it completes.
  ///
  /// Defaults to `false`.
  final bool looping;

  /// Initial volume (0.0 to 1.0).
  ///
  /// Defaults to `1.0` (full volume).
  final double volume;

  /// Initial playback speed (1.0 = normal speed).
  ///
  /// Common values: 0.5 (half speed), 1.0 (normal), 1.5, 2.0 (double speed).
  /// Defaults to `1.0`.
  final double playbackSpeed;

  // ============================================
  // Background Playback Options
  // ============================================

  /// Whether to allow audio playback when the app is in the background.
  ///
  /// When enabled on iOS, configures the audio session for background playback.
  /// On Android, this requires a foreground service (not yet implemented).
  ///
  /// Defaults to `false`.
  final bool allowBackgroundPlayback;

  /// Whether to mix audio with other apps (iOS specific).
  ///
  /// If `false`, the player will stop other audio when playing.
  /// If `true`, audio from this player will mix with other apps.
  ///
  /// Defaults to `false`.
  final bool mixWithOthers;

  /// Whether to prevent the screen from sleeping during video playback.
  ///
  /// When `true`, the screen will stay on while video is actively playing.
  /// When the video is paused, stopped, or completes, the screen sleep prevention
  /// is automatically disabled to conserve battery.
  ///
  /// ## Platform Behavior
  ///
  /// - **iOS**: Uses `UIApplication.shared.isIdleTimerDisabled`
  /// - **macOS**: Uses `NSProcessInfo.processInfo.beginActivity(options: .idleDisplaySleepDisabled)`
  /// - **Android**: Uses `WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON`
  /// - **Web**: Uses Screen Wake Lock API (`navigator.wakeLock.request('screen')`)
  ///
  /// ## Automatic Behavior
  ///
  /// The wake lock is automatically managed based on playback state:
  /// - Enabled when video starts playing
  /// - Kept enabled during buffering
  /// - Disabled when paused, stopped, or playback completes
  /// - In background playback mode (audio-only), screen can sleep
  /// - In PiP mode, screen stays on
  ///
  /// This matches the behavior of standard video players like YouTube, Netflix, and VLC.
  ///
  /// Defaults to `true`.
  final bool preventScreenSleep;

  // ============================================
  // Picture-in-Picture Options
  // ============================================

  /// Whether Picture-in-Picture (PiP) is allowed for this player.
  ///
  /// When `false`, calls to `enterPip()` will have no effect and return `false`.
  /// This allows developers to disable PiP on specific screens or for certain
  /// content types.
  ///
  /// ## Platform Setup Required
  ///
  /// **Android:** Add `android:supportsPictureInPicture="true"` to your
  /// `MainActivity` in `AndroidManifest.xml`. On Android, when PiP is active,
  /// the entire app is shown in the small PiP window. Your app should respond
  /// to `value.isPipActive` to show only the video player.
  ///
  /// **iOS:** Add "Audio, AirPlay, and Picture in Picture" to your app's
  /// Background Modes capability (or add `UIBackgroundModes` with `audio` to
  /// `Info.plist`). iOS uses true video-only PiP where the video floats in a
  /// system-controlled window independently from the app.
  ///
  /// Defaults to `true`.
  final bool allowPip;

  /// Whether to automatically enter PiP when the app goes to background.
  ///
  /// Only takes effect if [allowPip] is `true`.
  ///
  /// ## Platform Setup Required
  ///
  /// Same platform setup as [allowPip] is required for this feature to work.
  /// See [allowPip] documentation for details.
  ///
  /// Defaults to `false`.
  final bool autoEnterPipOnBackground;

  // ============================================
  // Subtitle Options
  // ============================================

  /// Whether subtitles/closed captions are enabled.
  ///
  /// When `false`, subtitle tracks will not be loaded and `setSubtitleTrack()`
  /// will have no effect. This can improve performance for content where
  /// subtitles are not needed.
  ///
  /// Defaults to `true`.
  final bool subtitlesEnabled;

  /// Whether to show subtitles by default when available.
  ///
  /// When `true` and subtitles are available, the player will automatically
  /// select a subtitle track (preferring [preferredSubtitleLanguage] if set,
  /// otherwise the default track).
  ///
  /// Only takes effect if [subtitlesEnabled] is `true`.
  ///
  /// Defaults to `false`.
  final bool showSubtitlesByDefault;

  /// Preferred language for subtitle auto-selection.
  ///
  /// Use ISO 639-1 language codes (e.g., 'en', 'es', 'pt', 'fr').
  /// When [showSubtitlesByDefault] is `true`, the player will prefer
  /// subtitle tracks matching this language.
  ///
  /// If no matching track is found, falls back to the default track.
  final String? preferredSubtitleLanguage;

  /// Whether to auto-discover subtitle files when playing local video files.
  ///
  /// When `true` and the video source is a local file ([VideoSource.file]),
  /// the player will search for matching subtitle files in:
  /// - The same directory as the video file
  /// - Common subdirectories: `Subs/`, `Subtitles/`, `subs/`, `subtitles/`
  ///
  /// Matching is controlled by [subtitleDiscoveryMode]. Discovered subtitles
  /// are automatically added as external subtitle tracks.
  ///
  /// Only takes effect if [subtitlesEnabled] is `true`.
  ///
  /// Defaults to `false`.
  final bool autoDiscoverSubtitles;

  /// The matching mode for subtitle auto-discovery.
  ///
  /// Controls how strictly subtitle filenames must match the video filename:
  /// - [SubtitleDiscoveryMode.strict] - Exact base name match
  /// - [SubtitleDiscoveryMode.prefix] - Subtitle starts with video name (recommended)
  /// - [SubtitleDiscoveryMode.fuzzy] - First 2-3 tokens must match
  ///
  /// Only takes effect if [autoDiscoverSubtitles] is `true`.
  ///
  /// Defaults to [SubtitleDiscoveryMode.prefix].
  final SubtitleDiscoveryMode subtitleDiscoveryMode;

  /// Whether to render embedded subtitles using Flutter instead of native.
  ///
  /// **DEPRECATED:** Use [subtitleRenderMode] instead. This boolean flag is
  /// deprecated in favor of the more flexible `SubtitleRenderMode` enum which
  /// supports runtime switching and automatic mode selection.
  ///
  /// Migration:
  /// - `renderEmbeddedSubtitlesInFlutter: true` → `subtitleRenderMode: SubtitleRenderMode.flutter`
  /// - `renderEmbeddedSubtitlesInFlutter: false` → `subtitleRenderMode: SubtitleRenderMode.auto`
  ///
  /// When `true`, embedded subtitle text is extracted from the native player
  /// and streamed to Flutter for rendering via `SubtitleOverlay`. This enables
  /// customizable styling via `SubtitleStyle` for ALL subtitles, not just
  /// external ones.
  ///
  /// When `false` (default), embedded subtitles are rendered by the native
  /// player with platform-default styling. External subtitles loaded via
  /// `addExternalSubtitle()` are always rendered in Flutter.
  ///
  /// ## Platform Behavior
  ///
  /// The rendering mode for subtitles.
  ///
  /// Controls whether subtitles are rendered by the native platform or by Flutter,
  /// and can be changed at runtime via `controller.setSubtitleRenderMode()`.
  ///
  /// - [SubtitleRenderMode.native] - Platform renders subtitles (iOS/Android/Web native styling)
  /// - [SubtitleRenderMode.flutter] - Flutter renders subtitles via `SubtitleOverlay` (custom styling)
  /// - [SubtitleRenderMode.auto] - Defaults to Flutter rendering (default)
  ///
  /// ## Auto Mode Behavior
  ///
  /// When set to `auto` (the default), subtitles are rendered by Flutter's
  /// SubtitleOverlay widget, providing customizable styling and consistent
  /// appearance across all platforms. To use native platform rendering, call:
  /// ```dart
  /// await controller.setSubtitleRenderMode(SubtitleRenderMode.native);
  /// ```
  ///
  /// ## Flutter Rendering Benefits
  ///
  /// When using `SubtitleRenderMode.flutter` or `auto`:
  /// - Subtitles appear independently of layout mode (work with native controls, no controls, etc.)
  /// - Customizable styling via `SubtitleStyle` (font, size, color, position, etc.)
  /// - Consistent appearance across all platforms
  /// - Subtitles always overlay on top of native controls
  ///
  /// ## Platform Behavior
  ///
  /// - **Android**: Uses ExoPlayer's `Player.Listener.onCues()` for Flutter rendering
  /// - **iOS/macOS**: Uses `AVPlayerItemLegibleOutput` with `suppressesPlayerRendering`
  /// - **Web**: Uses TextTrack `cuechange` events with mode='hidden' for Flutter rendering
  ///
  /// External subtitles loaded via `addExternalSubtitle()` are always rendered in
  /// Flutter regardless of this setting.
  ///
  /// Only takes effect if [subtitlesEnabled] is `true`.
  ///
  /// Defaults to [SubtitleRenderMode.auto].
  final SubtitleRenderMode subtitleRenderMode;

  // ============================================
  // Video Display Options
  // ============================================

  /// How the video content is scaled within the player viewport.
  ///
  /// Controls the behavior when the video's aspect ratio doesn't match
  /// the player's aspect ratio:
  ///
  /// - [VideoScalingMode.fit] - Show entire video with letterboxing/pillarboxing (default)
  /// - [VideoScalingMode.fill] - Fill viewport by cropping video
  /// - [VideoScalingMode.stretch] - Stretch video to fill, potentially distorting
  ///
  /// Defaults to [VideoScalingMode.fit].
  final VideoScalingMode scalingMode;

  // ============================================
  // Fullscreen Options
  // ============================================

  /// The orientation(s) allowed when entering fullscreen mode.
  ///
  /// This controls which device orientations are permitted when the player
  /// enters fullscreen mode. Common options:
  /// - [FullscreenOrientation.landscapeBoth] - Default, allows both landscape orientations
  /// - [FullscreenOrientation.all] - Allow any orientation including portrait
  /// - [FullscreenOrientation.landscapeLeft] or [FullscreenOrientation.landscapeRight] - Lock to specific orientation
  ///
  /// Defaults to [FullscreenOrientation.landscapeBoth].
  final FullscreenOrientation fullscreenOrientation;

  /// Whether the player should always be in fullscreen mode.
  ///
  /// When `true`:
  /// - The player automatically enters fullscreen when initialized
  /// - The fullscreen exit button is hidden from the controls
  /// - Calls to `exitFullscreen()` are ignored
  ///
  /// This is useful for dedicated video player apps where video should
  /// always fill the screen.
  ///
  /// Defaults to `false`.
  final bool fullscreenOnly;

  /// Whether to show the status bar at the top of fullscreen mode.
  ///
  /// When `true`, a persistent status bar is displayed at the top of the
  /// fullscreen video player with:
  /// - Left side: Current video position and total duration (e.g., "12:34 / 1:23:45")
  /// - Right side: System time in 12-hour format (e.g., "2:30 PM") and battery level with charging indicator (when available)
  ///
  /// The status bar uses small, unobtrusive text (11px) and automatically hides
  /// when the system status bar is visible (not in true fullscreen mode). It does
  /// not auto-hide with the playback controls, providing persistent contextual
  /// information during fullscreen playback.
  ///
  /// ## Platform Behavior
  ///
  /// Battery information availability varies by platform:
  /// - **iOS**: Full support via UIDevice battery APIs
  /// - **Android**: Full support via BatteryManager
  /// - **macOS**: Supported on MacBooks with battery (null on desktops)
  /// - **Web**: Supported in browsers with Battery Status API (Chrome, Edge)
  /// - **Windows/Linux**: Not currently implemented, battery section hidden
  ///
  /// When battery information is unavailable, the status bar gracefully
  /// degrades by hiding only the battery section while continuing to show
  /// time and video position.
  ///
  /// Defaults to `true`.
  final bool showFullscreenStatusBar;

  // ============================================
  // Buffering Options
  // ============================================

  /// The buffering tier that controls how much content is buffered ahead.
  ///
  /// Different tiers provide different trade-offs between memory usage,
  /// startup time, and playback smoothness:
  ///
  /// - [BufferingTier.min] - Minimal buffering, lowest memory footprint
  /// - [BufferingTier.low] - Light buffering for quick startup
  /// - [BufferingTier.medium] - Balanced buffering (default)
  /// - [BufferingTier.high] - Heavy buffering for unreliable networks
  /// - [BufferingTier.max] - Maximum buffering for extreme conditions
  ///
  /// See [BufferingTier] documentation for platform-specific behavior.
  ///
  /// Defaults to [BufferingTier.medium].
  final BufferingTier bufferingTier;

  // ============================================
  // Casting Options
  // ============================================

  /// Whether casting to external devices is allowed for this player.
  ///
  /// When `true`, the player will enable casting functionality and allow
  /// users to cast video to external devices such as:
  /// - **iOS/macOS**: AirPlay-enabled devices (Apple TV, smart TVs, speakers)
  /// - **Android**: Chromecast devices and Cast-enabled TVs
  /// - **Web**: Devices supporting the Remote Playback API
  ///
  /// When `false`, casting controls will be hidden and calls to casting-related
  /// methods will have no effect. This allows developers to disable casting on
  /// specific screens or for certain content types.
  ///
  /// ## Platform Setup Required
  ///
  /// **iOS/macOS:** Casting via AirPlay works out of the box on devices that
  /// support it. No special configuration needed.
  ///
  /// **Android:** To use Chromecast, add the Google Cast SDK dependency to
  /// your app's `build.gradle` and configure the Cast receiver app ID.
  ///
  /// **Web:** Casting uses the browser's built-in Remote Playback API.
  /// No special setup required.
  ///
  /// Defaults to `true`.
  final bool allowCasting;

  // ============================================
  // Adaptive Bitrate (ABR) Options
  // ============================================

  /// The adaptive bitrate selection mode for streaming content.
  ///
  /// Controls whether the player automatically adjusts video quality based
  /// on network conditions or allows manual quality selection only.
  ///
  /// - [AbrMode.auto]: Player automatically switches quality (default)
  /// - [AbrMode.manual]: No auto-switching; use `setVideoQuality()` to change
  ///
  /// ## Platform-Specific Behavior
  ///
  /// - **Android**: Full support for both modes via ExoPlayer
  /// - **iOS/macOS**: [AbrMode.manual] sets preferences but AVPlayer may still
  ///   adjust quality in extreme network conditions
  /// - **Web**: Full support via HLS.js/dash.js
  ///
  /// See [AbrMode] documentation for more details.
  ///
  /// Defaults to [AbrMode.auto].
  final AbrMode abrMode;

  /// Minimum allowed video bitrate in bits per second.
  ///
  /// When set, the player will not select quality levels below this bitrate
  /// (subject to availability). This ensures a minimum quality floor.
  ///
  /// Common values:
  /// - 200000 (200 kbps) - Very low quality, mobile data saving
  /// - 500000 (500 kbps) - Low quality
  /// - 1000000 (1 Mbps) - SD quality minimum
  /// - 2500000 (2.5 Mbps) - HD quality minimum
  ///
  /// ## Platform Support
  ///
  /// - **Android**: Fully supported via ExoPlayer TrackSelectionParameters
  /// - **iOS/macOS**: Not supported (AVPlayer only supports max bitrate)
  /// - **Web**: Supported via HLS.js/dash.js configuration
  ///
  /// Defaults to `null` (no minimum limit).
  final int? minBitrate;

  /// Maximum allowed video bitrate in bits per second.
  ///
  /// When set, the player will not select quality levels above this bitrate.
  /// Useful for limiting data usage or ensuring smooth playback on slower
  /// connections.
  ///
  /// Common values:
  /// - 1500000 (1.5 Mbps) - SD quality cap
  /// - 5000000 (5 Mbps) - HD quality cap
  /// - 8000000 (8 Mbps) - Full HD quality cap
  /// - 25000000 (25 Mbps) - 4K quality cap
  ///
  /// ## Platform Support
  ///
  /// - **Android**: Fully supported via ExoPlayer TrackSelectionParameters
  /// - **iOS/macOS**: Supported via `preferredPeakBitRate`
  /// - **Web**: Supported via HLS.js level capping / dash.js configuration
  ///
  /// Defaults to `null` (no maximum limit).
  final int? maxBitrate;

  /// Creates a copy of this options with the given fields replaced.
  VideoPlayerOptions copyWith({
    bool? autoPlay,
    bool? looping,
    double? volume,
    double? playbackSpeed,
    bool? allowBackgroundPlayback,
    bool? mixWithOthers,
    bool? preventScreenSleep,
    bool? allowPip,
    bool? autoEnterPipOnBackground,
    bool? subtitlesEnabled,
    bool? showSubtitlesByDefault,
    String? preferredSubtitleLanguage,
    bool? autoDiscoverSubtitles,
    SubtitleDiscoveryMode? subtitleDiscoveryMode,
    SubtitleRenderMode? subtitleRenderMode,
    VideoScalingMode? scalingMode,
    FullscreenOrientation? fullscreenOrientation,
    bool? fullscreenOnly,
    bool? showFullscreenStatusBar,
    BufferingTier? bufferingTier,
    bool? allowCasting,
    AbrMode? abrMode,
    int? minBitrate,
    int? maxBitrate,
  }) => VideoPlayerOptions(
    autoPlay: autoPlay ?? this.autoPlay,
    looping: looping ?? this.looping,
    volume: volume ?? this.volume,
    playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    allowBackgroundPlayback: allowBackgroundPlayback ?? this.allowBackgroundPlayback,
    mixWithOthers: mixWithOthers ?? this.mixWithOthers,
    preventScreenSleep: preventScreenSleep ?? this.preventScreenSleep,
    allowPip: allowPip ?? this.allowPip,
    autoEnterPipOnBackground: autoEnterPipOnBackground ?? this.autoEnterPipOnBackground,
    subtitlesEnabled: subtitlesEnabled ?? this.subtitlesEnabled,
    showSubtitlesByDefault: showSubtitlesByDefault ?? this.showSubtitlesByDefault,
    preferredSubtitleLanguage: preferredSubtitleLanguage ?? this.preferredSubtitleLanguage,
    autoDiscoverSubtitles: autoDiscoverSubtitles ?? this.autoDiscoverSubtitles,
    subtitleDiscoveryMode: subtitleDiscoveryMode ?? this.subtitleDiscoveryMode,
    subtitleRenderMode: subtitleRenderMode ?? this.subtitleRenderMode,
    scalingMode: scalingMode ?? this.scalingMode,
    fullscreenOrientation: fullscreenOrientation ?? this.fullscreenOrientation,
    fullscreenOnly: fullscreenOnly ?? this.fullscreenOnly,
    showFullscreenStatusBar: showFullscreenStatusBar ?? this.showFullscreenStatusBar,
    bufferingTier: bufferingTier ?? this.bufferingTier,
    allowCasting: allowCasting ?? this.allowCasting,
    abrMode: abrMode ?? this.abrMode,
    minBitrate: minBitrate ?? this.minBitrate,
    maxBitrate: maxBitrate ?? this.maxBitrate,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! VideoPlayerOptions) return false;
    return autoPlay == other.autoPlay &&
        looping == other.looping &&
        volume == other.volume &&
        playbackSpeed == other.playbackSpeed &&
        allowBackgroundPlayback == other.allowBackgroundPlayback &&
        mixWithOthers == other.mixWithOthers &&
        preventScreenSleep == other.preventScreenSleep &&
        allowPip == other.allowPip &&
        autoEnterPipOnBackground == other.autoEnterPipOnBackground &&
        subtitlesEnabled == other.subtitlesEnabled &&
        showSubtitlesByDefault == other.showSubtitlesByDefault &&
        preferredSubtitleLanguage == other.preferredSubtitleLanguage &&
        autoDiscoverSubtitles == other.autoDiscoverSubtitles &&
        subtitleDiscoveryMode == other.subtitleDiscoveryMode &&
        subtitleRenderMode == other.subtitleRenderMode &&
        scalingMode == other.scalingMode &&
        fullscreenOrientation == other.fullscreenOrientation &&
        fullscreenOnly == other.fullscreenOnly &&
        showFullscreenStatusBar == other.showFullscreenStatusBar &&
        bufferingTier == other.bufferingTier &&
        allowCasting == other.allowCasting &&
        abrMode == other.abrMode &&
        minBitrate == other.minBitrate &&
        maxBitrate == other.maxBitrate;
  }

  @override
  int get hashCode => Object.hashAll([
    autoPlay,
    looping,
    volume,
    playbackSpeed,
    allowBackgroundPlayback,
    mixWithOthers,
    preventScreenSleep,
    allowPip,
    autoEnterPipOnBackground,
    subtitlesEnabled,
    showSubtitlesByDefault,
    preferredSubtitleLanguage,
    autoDiscoverSubtitles,
    subtitleDiscoveryMode,
    subtitleRenderMode,
    scalingMode,
    fullscreenOrientation,
    fullscreenOnly,
    showFullscreenStatusBar,
    bufferingTier,
    allowCasting,
    abrMode,
    minBitrate,
    maxBitrate,
  ]);

  @override
  String toString() =>
      'VideoPlayerOptions('
      'autoPlay: $autoPlay, '
      'looping: $looping, '
      'volume: $volume, '
      'playbackSpeed: $playbackSpeed, '
      'allowBackgroundPlayback: $allowBackgroundPlayback, '
      'mixWithOthers: $mixWithOthers, '
      'preventScreenSleep: $preventScreenSleep, '
      'allowPip: $allowPip, '
      'autoEnterPipOnBackground: $autoEnterPipOnBackground, '
      'subtitlesEnabled: $subtitlesEnabled, '
      'showSubtitlesByDefault: $showSubtitlesByDefault, '
      'preferredSubtitleLanguage: $preferredSubtitleLanguage, '
      'autoDiscoverSubtitles: $autoDiscoverSubtitles, '
      'subtitleDiscoveryMode: $subtitleDiscoveryMode, '
      'subtitleRenderMode: $subtitleRenderMode, '
      'scalingMode: $scalingMode, '
      'fullscreenOrientation: $fullscreenOrientation, '
      'fullscreenOnly: $fullscreenOnly, '
      'showFullscreenStatusBar: $showFullscreenStatusBar, '
      'bufferingTier: $bufferingTier, '
      'allowCasting: $allowCasting, '
      'abrMode: $abrMode, '
      'minBitrate: $minBitrate, '
      'maxBitrate: $maxBitrate'
      ')';
}
