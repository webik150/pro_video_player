/// A Flutter plugin for video playback using native video players.
///
/// This library provides a comprehensive multi-platform video player with advanced
/// features including subtitles, multiple audio/subtitle tracks, Picture-in-Picture,
/// background playback, fullscreen, casting (AirPlay/Chromecast), adaptive streaming
/// (HLS/DASH), playlists, and customizable controls. Uses native video players on
/// each platform (AVPlayer on iOS, ExoPlayer on Android, etc.) for optimal performance
///
/// ## Getting Started
///
/// 1. Create a controller:
/// ```dart
/// final controller = ProVideoPlayerController();
/// ```
///
/// 2. Initialize with a video source:
/// ```dart
/// await controller.initialize(
///   source: VideoSource.network('https://example.com/video.mp4'),
/// );
/// ```
///
/// 3. Display the video:
/// ```dart
/// ProVideoPlayer(controller: controller)
/// ```
///
/// 4. Control playback:
/// ```dart
/// await controller.play();
/// await controller.pause();
/// await controller.seekTo(Duration(seconds: 30));
/// ```
///
/// 5. Dispose when done:
/// ```dart
/// await controller.dispose();
/// ```
library pro_video_player;

export 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart'
    show
        AbrMode,
        AssetVideoSource,
        AudioTrack,
        AudioTracksChangedEvent,
        BackgroundPlaybackChangedEvent,
        BandwidthEstimateChangedEvent,
        BufferedPositionChangedEvent,
        BufferingEndedEvent,
        BufferingStartedEvent,
        BufferingTier,
        Caption,
        CastDevice,
        CastDevicesChangedEvent,
        CastState,
        CastStateChangedEvent,
        Chapter,
        ChaptersExtractedEvent,
        ClosedCaptionFile,
        ContentFingerprint,
        ContentFingerprintException,
        ControlsMode,
        CurrentChapterChangedEvent,
        DataSourceType,
        DurationChangedEvent,
        EmbeddedSubtitleCueEvent,
        ErrorEvent,
        ErrorRecoveryOptions,
        ExternalSubtitleTrack,
        FileVideoSource,
        FullscreenOrientation,
        FullscreenStateChangedEvent,
        MediaMetadata,
        MetadataChangedEvent,
        NetworkErrorEvent,
        NetworkStateChangedEvent,
        NetworkVideoSource,
        PipAction,
        PipActionTriggeredEvent,
        PipActionType,
        PipActions,
        PipOptions,
        PipRestoreUserInterfaceEvent,
        PipStateChangedEvent,
        PlaybackCompletedEvent,
        PlaybackRecoveredEvent,
        PlaybackSpeedChangedEvent,
        PlaybackState,
        PlaybackStateChangedEvent,
        Playlist,
        PlaylistEndedEvent,
        PlaylistRepeatMode,
        PlaylistTrackChangedEvent,
        PlaylistVideoSource,
        PositionChangedEvent,
        ProVideoPlayerLogger,
        SelectedAudioChangedEvent,
        SelectedQualityChangedEvent,
        SelectedSubtitleChangedEvent,
        SubtitleCue,
        SubtitleFormat,
        SubtitleParser,
        SubtitlePosition,
        SubtitleRenderMode,
        SubtitleSource,
        SubtitleStyle,
        SubtitleTextAlignment,
        SubtitleTrack,
        SubtitleTracksChangedEvent,
        VideoMetadata,
        VideoMetadataExtractedEvent,
        VideoPlayerError,
        VideoPlayerEvent,
        VideoPlayerOptions,
        VideoPlayerValue,
        VideoQualityTrack,
        VideoQualityTracksChangedEvent,
        VideoScalingMode,
        VideoSizeChangedEvent,
        VideoSource,
        VolumeChangedEvent;

export 'src/cast_button.dart';
export 'src/controls/bottom_controls_bar.dart';
export 'src/controls/controls_configuration.dart';
export 'src/controls/controls_state_callbacks.dart';
export 'src/controls/desktop_video_controls.dart';
export 'src/controls/fullscreen_status_bar.dart';
export 'src/controls/keyboard_overlay.dart';
export 'src/controls/mobile_video_controls.dart';
export 'src/controls/player_toolbar.dart';
export 'src/controls/progress_bar.dart';
export 'src/controls/seek_preview.dart';
export 'src/controls/seek_preview_progress_bar.dart';
export 'src/controls/toolbar_callbacks.dart';
export 'src/controls/video_controls_utils.dart';
export 'src/controls/wrappers/desktop_controls_wrapper.dart';
export 'src/controls/wrappers/gesture_controls_wrapper.dart';
export 'src/controls/wrappers/simple_tap_wrapper.dart';
export 'src/pro_video_player.dart';
export 'src/pro_video_player_builder.dart';
export 'src/pro_video_player_controller.dart';
export 'src/subtitle_overlay.dart';
export 'src/video_controls_config.dart';
export 'src/video_controls_controller.dart';
export 'src/video_controls_state.dart' show KeyboardOverlayType, VideoControlsState;
export 'src/video_player_controls.dart' show CompactMode, LiveScrubbingMode, PlayerToolbarAction, VideoPlayerControls;
export 'src/video_player_gesture_detector.dart';
export 'src/video_player_theme.dart';
export 'src/video_toolbar_manager.dart' show ToolbarConfig, ToolbarState, VideoToolbarManager;
