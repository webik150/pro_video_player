// Copyright 2025 The Pro Video Player Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: sort_constructors_first - Necessary: Pigeon message classes use field-first convention for readability
// ignore_for_file: one_member_abstracts - Necessary: Pigeon @FlutterApi requires abstract class, typedef not supported

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/pigeon_generated/messages.g.dart',
    dartTestOut: 'test/pigeon_generated/test_messages.g.dart',
    dartPackageName: 'pro_video_player_platform_interface',
    kotlinOut:
        '../pro_video_player_android/android/src/main/kotlin/dev/pro_video_player/pro_video_player_android/PigeonMessages.kt',
    kotlinOptions: KotlinOptions(package: 'dev.pro_video_player.pro_video_player_android'),
    swiftOut: '../pro_video_player_ios/ios/Classes/PigeonMessages.swift',
    cppOptions: CppOptions(namespace: 'pro_video_player'),
    cppHeaderOut: '../pro_video_player_windows/windows/pigeon_messages.h',
    cppSourceOut: '../pro_video_player_windows/windows/pigeon_messages.cpp',
    copyrightHeader: 'pigeons/copyright_header.txt',
  ),
)
/// Video source types supported by the platform.
enum VideoSourceType {
  /// Network video source (HTTP/HTTPS URL).
  network,

  /// Local file video source.
  file,

  /// Asset video source (bundled with the app).
  asset,
}

/// Video scaling modes.
enum VideoScalingModeEnum {
  /// Fit the video within the view (letterbox/pillarbox).
  fit,

  /// Fill the entire view (may crop video).
  fill,

  /// Stretch the video to fill the view.
  stretch,
}

/// Subtitle render modes.
enum SubtitleRenderModeEnum {
  /// Auto-select best render mode.
  auto,

  /// Render subtitles natively.
  native,

  /// Render subtitles in Flutter.
  flutter,
}

/// Controls mode.
enum ControlsModeEnum {
  /// Video only, no controls.
  videoOnly,

  /// Native platform controls.
  nativeControls,

  /// Flutter controls.
  flutterControls,

  /// Custom controls.
  customControls,
}

/// Cast state.
enum CastStateEnum {
  /// Not connected to any cast device.
  notConnected,

  /// Connecting to cast device.
  connecting,

  /// Connected to cast device.
  connected,

  /// Disconnecting from cast device.
  disconnecting,
}

/// Cast device type.
enum CastDeviceTypeEnum {
  /// AirPlay device.
  airPlay,

  /// Chromecast device.
  chromecast,

  /// Web Remote Playback device.
  webRemotePlayback,

  /// Unknown device type.
  unknown,
}

/// PiP action type.
enum PipActionTypeEnum {
  /// Play/pause toggle.
  playPause,

  /// Skip to previous.
  skipPrevious,

  /// Skip to next.
  skipNext,

  /// Skip backward.
  skipBackward,

  /// Skip forward.
  skipForward,
}

/// Subtitle format.
enum SubtitleFormatEnum {
  /// SRT format.
  srt,

  /// WebVTT format.
  vtt,

  /// SSA format.
  ssa,

  /// ASS format.
  ass,

  /// TTML format.
  ttml,
}

/// Codec support level.
enum CodecSupportLevelEnum {
  /// Codec is fully supported.
  supported,

  /// Codec is probably supported.
  probablySupported,

  /// Codec is not supported.
  notSupported,

  /// Support status is unknown.
  unknown,
}

// ==================== Message Classes ====================

/// Video source data passed to the platform.
///
/// This represents the video source to be played. Only one of [url], [path],
/// or [assetPath] should be set based on the [type].
class VideoSourceMessage {
  /// The type of video source.
  final VideoSourceType type;

  /// Network URL (for network sources).
  final String? url;

  /// File path (for file sources).
  final String? path;

  /// Asset path (for asset sources).
  final String? assetPath;

  /// HTTP headers (for network sources).
  final Map<String?, String?>? headers;

  VideoSourceMessage({required this.type, this.url, this.path, this.assetPath, this.headers});
}

/// Video player options for initialization.
class VideoPlayerOptionsMessage {
  /// Whether to start playing automatically after initialization.
  final bool autoPlay;

  /// Whether to loop the video.
  final bool looping;

  /// Initial volume (0.0 to 1.0).
  final double volume;

  /// Initial playback speed.
  final double playbackSpeed;

  /// Start position in milliseconds.
  final int? startPosition;

  /// Whether to enable Picture-in-Picture mode.
  final bool? enablePip;

  /// Whether to enable background playback.
  final bool? enableBackgroundPlayback;

  /// Preferred audio language code.
  final String? preferredAudioLanguage;

  /// Preferred subtitle language code.
  final String? preferredSubtitleLanguage;

  /// Maximum bitrate in bits per second.
  final int? maxBitrate;

  /// Minimum bitrate in bits per second.
  final int? minBitrate;

  /// Preferred audio rendition name.
  final String? preferredAudioRendition;

  /// Whether to allow background playback (deprecated, use enableBackgroundPlayback).
  final bool allowBackgroundPlayback;

  /// Whether to mix audio with other apps.
  final bool mixWithOthers;

  /// Whether to allow Picture-in-Picture mode (deprecated, use enablePip).
  final bool allowPip;

  /// Whether to auto-enter PiP when app goes to background.
  final bool autoEnterPipOnBackground;

  /// The subtitle render mode for embedded subtitles.
  final SubtitleRenderModeEnum? subtitleRenderMode;

  /// Whether subtitles are enabled.
  final bool? subtitlesEnabled;

  /// Whether to show subtitles by default when available.
  final bool? showSubtitlesByDefault;

  VideoPlayerOptionsMessage({
    required this.autoPlay,
    required this.looping,
    required this.volume,
    required this.playbackSpeed,
    required this.allowBackgroundPlayback,
    required this.mixWithOthers,
    required this.allowPip,
    required this.autoEnterPipOnBackground,
    this.startPosition,
    this.enablePip,
    this.enableBackgroundPlayback,
    this.preferredAudioLanguage,
    this.preferredSubtitleLanguage,
    this.maxBitrate,
    this.minBitrate,
    this.preferredAudioRendition,
    this.subtitleRenderMode,
    this.subtitlesEnabled,
    this.showSubtitlesByDefault,
  });
}

/// Platform information returned by the platform.
///
/// Contains static platform metadata that doesn't require async checks.
class PlatformInfoMessage {
  /// Platform name (e.g., "iOS", "Android", "Web").
  final String platformName;

  /// Native player type (e.g., "AVPlayer", "ExoPlayer", "HTML5").
  final String nativePlayerType;

  /// Additional platform-specific information as key-value pairs.
  ///
  /// May include:
  /// - OS version
  /// - SDK version
  /// - Browser user agent
  /// - Hardware capabilities
  final Map<String?, Object?>? additionalInfo;

  PlatformInfoMessage({required this.platformName, required this.nativePlayerType, this.additionalInfo});
}

/// Battery information.
class BatteryInfoMessage {
  /// Battery percentage (0-100).
  final int percentage;

  /// Whether the device is charging.
  final bool isCharging;

  BatteryInfoMessage({required this.percentage, required this.isCharging});
}

/// Subtitle track information.
class SubtitleTrackMessage {
  /// Track ID.
  final String id;

  /// Track label.
  final String? label;

  /// Track language code.
  final String? language;

  /// Subtitle format.
  final SubtitleFormatEnum? format;

  /// Whether this is the default track.
  final bool? isDefault;

  SubtitleTrackMessage({required this.id, this.label, this.language, this.format, this.isDefault});
}

/// Audio track information.
class AudioTrackMessage {
  /// Track ID.
  final String id;

  /// Track label.
  final String? label;

  /// Track language code.
  final String? language;

  /// Number of audio channels.
  final int? channelCount;

  /// Whether this is the default track.
  final bool? isDefault;

  AudioTrackMessage({required this.id, this.label, this.language, this.channelCount, this.isDefault});
}

/// Video quality track information.
class VideoQualityTrackMessage {
  /// Track ID.
  final String id;

  /// Track label.
  final String? label;

  /// Bitrate in bits per second.
  final int? bitrate;

  /// Video width in pixels.
  final int? width;

  /// Video height in pixels.
  final int? height;

  /// Video codec.
  final String? codec;

  /// Whether this is the default track.
  final bool? isDefault;

  VideoQualityTrackMessage({
    required this.id,
    this.label,
    this.bitrate,
    this.width,
    this.height,
    this.codec,
    this.isDefault,
  });
}

/// Picture-in-picture options.
class PipOptionsMessage {
  /// Aspect ratio (width / height).
  final double? aspectRatio;

  /// Auto-enter PiP when app goes to background.
  final bool autoEnterOnBackground;

  PipOptionsMessage({required this.autoEnterOnBackground, this.aspectRatio});
}

/// Picture-in-picture action.
class PipActionMessage {
  /// Action type.
  final PipActionTypeEnum type;

  /// Action title.
  final String? title;

  /// Icon name.
  final String? iconName;

  /// Optional skip interval in milliseconds.
  final int? skipIntervalMs;

  PipActionMessage({required this.type, this.title, this.iconName, this.skipIntervalMs});
}

/// Cast device information.
class CastDeviceMessage {
  /// Device ID.
  final String id;

  /// Device name.
  final String name;

  /// Device type.
  final CastDeviceTypeEnum type;

  CastDeviceMessage({required this.id, required this.name, required this.type});
}

/// Video metadata.
class VideoMetadataMessage {
  /// Duration in milliseconds.
  final int? duration;

  /// Video width in pixels.
  final int? width;

  /// Video height in pixels.
  final int? height;

  /// Video codec.
  final String? videoCodec;

  /// Audio codec.
  final String? audioCodec;

  /// Bitrate in bits per second.
  final int? bitrate;

  /// Frame rate.
  final double? frameRate;

  VideoMetadataMessage({
    this.duration,
    this.width,
    this.height,
    this.videoCodec,
    this.audioCodec,
    this.bitrate,
    this.frameRate,
  });
}

/// Media metadata for platform controls.
class MediaMetadataMessage {
  /// Media title.
  final String? title;

  /// Media artist/author.
  final String? artist;

  /// Album name.
  final String? album;

  /// Artwork URL.
  final String? artworkUrl;

  /// Duration in milliseconds.
  final int? duration;

  MediaMetadataMessage({this.title, this.artist, this.album, this.artworkUrl, this.duration});
}

/// Subtitle source information.
class SubtitleSourceMessage {
  /// Source type (network, file, asset).
  final VideoSourceType type;

  /// Path or URL.
  final String path;

  /// Subtitle format.
  final SubtitleFormatEnum? format;

  /// Track label.
  final String? label;

  /// Language code.
  final String? language;

  /// Whether this is the default subtitle.
  final bool isDefault;

  /// WebVTT content (for in-memory subtitles).
  final String? webvttContent;

  SubtitleSourceMessage({
    required this.type,
    required this.path,
    required this.isDefault,
    this.format,
    this.label,
    this.language,
    this.webvttContent,
  });
}

/// External subtitle track information.
class ExternalSubtitleTrackMessage {
  /// Track ID.
  final String id;

  /// Track label.
  final String label;

  /// Track language code.
  final String? language;

  /// Whether this is the default track.
  final bool isDefault;

  /// Source path or URL.
  final String path;

  /// Source type.
  final String sourceType;

  /// Subtitle format.
  final SubtitleFormatEnum format;

  ExternalSubtitleTrackMessage({
    required this.id,
    required this.label,
    required this.isDefault,
    required this.path,
    required this.sourceType,
    required this.format,
    this.language,
  });
}

/// Codec information for compatibility checking.
class CodecInfoMessage {
  /// Four character code (e.g., "avc1", "hvc1", "mp4a").
  final String fourcc;

  /// Human-readable codec name (e.g., "H.264", "HEVC", "AAC").
  final String name;

  /// Full codec string including profile and level.
  final String? codecString;

  /// MIME type for the codec (e.g., "video/mp4", "audio/mp4").
  final String? mimeType;

  CodecInfoMessage({required this.fourcc, required this.name, this.codecString, this.mimeType});
}

/// Result of checking codec compatibility.
class CodecCompatibilityMessage {
  /// The codec that was checked.
  final CodecInfoMessage codec;

  /// The level of support for this codec.
  final CodecSupportLevelEnum supportLevel;

  /// Human-readable message about the support status.
  final String? message;

  /// Minimum OS version required for this codec.
  final String? minimumOsVersion;

  /// Alternative codecs that are supported.
  final List<String?>? alternativeCodecs;

  CodecCompatibilityMessage({
    required this.codec,
    required this.supportLevel,
    this.message,
    this.minimumOsVersion,
    this.alternativeCodecs,
  });
}

/// Host API for video player platform methods.
///
/// This API is implemented on the native platform (iOS, Android, etc.)
/// and called from Dart.
@HostApi()
abstract class ProVideoPlayerHostApi {
  /// Creates a new video player instance with the given source and options.
  ///
  /// Returns the player ID that should be used for all subsequent operations.
  @async
  int create(VideoSourceMessage source, VideoPlayerOptionsMessage options);

  /// Disposes a video player instance.
  @async
  void dispose(int playerId);

  /// Starts playback.
  @async
  void play(int playerId);

  /// Pauses playback.
  @async
  void pause(int playerId);

  /// Stops playback.
  @async
  void stop(int playerId);

  /// Seeks to the specified position.
  ///
  /// [positionMs] is the position in milliseconds.
  @async
  void seekTo(int playerId, int positionMs);

  /// Sets the playback speed.
  @async
  void setPlaybackSpeed(int playerId, double speed);

  /// Sets the volume (0.0 to 1.0).
  @async
  void setVolume(int playerId, double volume);

  /// Gets the current playback position in milliseconds.
  @async
  int getPosition(int playerId);

  /// Gets the video duration in milliseconds.
  @async
  int getDuration(int playerId);

  /// Gets static platform information.
  @async
  PlatformInfoMessage getPlatformInfo();

  /// Enables or disables verbose logging.
  @async
  void setVerboseLogging(bool enabled);

  // ==================== Platform Capabilities ====================

  /// Checks if Picture-in-Picture mode is supported.
  @async
  bool supportsPictureInPicture();

  /// Checks if fullscreen mode is supported.
  @async
  bool supportsFullscreen();

  /// Checks if background playback is supported.
  @async
  bool supportsBackgroundPlayback();

  /// Checks if any form of casting is supported.
  @async
  bool supportsCasting();

  /// Checks if AirPlay is supported.
  @async
  bool supportsAirPlay();

  /// Checks if Chromecast is supported.
  @async
  bool supportsChromecast();

  /// Checks if Remote Playback API is supported.
  @async
  bool supportsRemotePlayback();

  /// Checks if quality selection is supported.
  @async
  bool supportsQualitySelection();

  /// Checks if playback speed control is supported.
  @async
  bool supportsPlaybackSpeedControl();

  /// Checks if subtitles are supported.
  @async
  bool supportsSubtitles();

  /// Checks if external subtitles are supported.
  @async
  bool supportsExternalSubtitles();

  /// Checks if audio track selection is supported.
  @async
  bool supportsAudioTrackSelection();

  /// Checks if chapters are supported.
  @async
  bool supportsChapters();

  /// Checks if video metadata extraction is supported.
  @async
  bool supportsVideoMetadataExtraction();

  /// Checks if network monitoring is supported.
  @async
  bool supportsNetworkMonitoring();

  /// Checks if bandwidth estimation is supported.
  @async
  bool supportsBandwidthEstimation();

  /// Checks if adaptive bitrate streaming is supported.
  @async
  bool supportsAdaptiveBitrate();

  /// Checks if HLS is supported.
  @async
  bool supportsHLS();

  /// Checks if DASH is supported.
  @async
  bool supportsDASH();

  /// Checks if device volume control is supported.
  @async
  bool supportsDeviceVolumeControl();

  /// Checks if screen brightness control is supported.
  @async
  bool supportsScreenBrightnessControl();

  // ==================== Device Controls ====================

  /// Gets the device volume (0.0 to 1.0).
  @async
  double getDeviceVolume();

  /// Sets the device volume (0.0 to 1.0).
  @async
  void setDeviceVolume(double volume);

  /// Gets the screen brightness (0.0 to 1.0).
  @async
  double getScreenBrightness();

  /// Sets the screen brightness (0.0 to 1.0).
  @async
  void setScreenBrightness(double brightness);

  /// Gets the current battery info.
  @async
  BatteryInfoMessage? getBatteryInfo();

  // ==================== Player Configuration ====================

  /// Sets whether the video should loop.
  @async
  void setLooping(int playerId, bool looping);

  /// Sets the video scaling mode.
  @async
  void setScalingMode(int playerId, VideoScalingModeEnum mode);

  /// Sets the controls mode.
  @async
  void setControlsMode(int playerId, ControlsModeEnum mode);

  // ==================== Subtitle Management ====================

  /// Sets the active subtitle track.
  @async
  void setSubtitleTrack(int playerId, SubtitleTrackMessage? track);

  /// Sets the subtitle render mode.
  @async
  void setSubtitleRenderMode(int playerId, SubtitleRenderModeEnum mode);

  /// Adds an external subtitle file.
  @async
  ExternalSubtitleTrackMessage? addExternalSubtitle(int playerId, SubtitleSourceMessage source);

  /// Removes an external subtitle track.
  @async
  bool removeExternalSubtitle(int playerId, String trackId);

  /// Gets all external subtitle tracks.
  @async
  List<ExternalSubtitleTrackMessage?> getExternalSubtitles(int playerId);

  // ==================== Audio Management ====================

  /// Sets the active audio track.
  @async
  void setAudioTrack(int playerId, AudioTrackMessage? track);

  // ==================== Picture-in-Picture ====================

  /// Enters picture-in-picture mode.
  @async
  bool enterPip(int playerId, PipOptionsMessage options);

  /// Exits picture-in-picture mode.
  @async
  void exitPip(int playerId);

  /// Checks if PiP is supported on this platform.
  @async
  bool isPipSupported();

  /// Sets the actions available in PiP mode.
  @async
  void setPipActions(int playerId, List<PipActionMessage?> actions);

  // ==================== Fullscreen ====================

  /// Enters fullscreen mode.
  @async
  bool enterFullscreen(int playerId);

  /// Exits fullscreen mode.
  @async
  void exitFullscreen(int playerId);

  /// Sets window fullscreen state (desktop platforms).
  @async
  void setWindowFullscreen(bool fullscreen);

  // ==================== Background Playback ====================

  /// Enables or disables background playback.
  @async
  bool setBackgroundPlayback(int playerId, bool enabled);

  /// Checks if background playback is supported.
  @async
  bool isBackgroundPlaybackSupported();

  // ==================== Quality Selection ====================

  /// Gets available video quality tracks.
  @async
  List<VideoQualityTrackMessage?> getVideoQualities(int playerId);

  /// Sets the video quality track.
  @async
  bool setVideoQuality(int playerId, VideoQualityTrackMessage track);

  /// Gets the current video quality track.
  @async
  VideoQualityTrackMessage getCurrentVideoQuality(int playerId);

  /// Checks if quality selection is supported.
  @async
  bool isQualitySelectionSupported(int playerId);

  // ==================== Video Metadata ====================

  /// Gets video metadata.
  @async
  VideoMetadataMessage? getVideoMetadata(int playerId);

  /// Sets media metadata for platform controls.
  @async
  void setMediaMetadata(int playerId, MediaMetadataMessage metadata);

  // ==================== Casting ====================

  /// Checks if casting is supported on this platform.
  @async
  bool isCastingSupported();

  /// Gets available cast devices.
  @async
  List<CastDeviceMessage?> getAvailableCastDevices(int playerId);

  /// Starts casting to a device.
  @async
  bool startCasting(int playerId, CastDeviceMessage? device);

  /// Stops casting.
  @async
  bool stopCasting(int playerId);

  /// Gets the current cast state.
  @async
  CastStateEnum getCastState(int playerId);

  /// Gets the current cast device.
  @async
  CastDeviceMessage? getCurrentCastDevice(int playerId);

  // ==================== Codec Compatibility ====================

  /// Checks if a specific codec is supported on this platform.
  ///
  /// Uses platform-specific APIs:
  /// - Web: MediaSource.isTypeSupported() / HTMLMediaElement.canPlayType()
  /// - iOS/macOS: AVURLAsset.isPlayableExtendedMIMEType()
  /// - Android: MediaCodecList.findDecoderForFormat()
  ///
  /// The [codec] parameter should include the fourcc and optionally
  /// the full codec string for more accurate checking.
  @async
  CodecCompatibilityMessage checkCodecSupport(CodecInfoMessage codec);

  /// Checks if multiple codecs are supported on this platform.
  ///
  /// More efficient than calling [checkCodecSupport] multiple times
  /// as it may batch platform API calls.
  @async
  List<CodecCompatibilityMessage?> checkCodecsSupport(List<CodecInfoMessage?> codecs);

  /// Gets a list of codecs that are guaranteed to be supported.
  ///
  /// Returns the platform's baseline supported codecs:
  /// - Common video codecs (H.264, potentially HEVC)
  /// - Common audio codecs (AAC, MP3)
  ///
  /// This can be used to suggest transcoding options when
  /// a file contains unsupported codecs.
  @async
  List<String?> getSupportedCodecs();

  // ==================== Metadata Extraction ====================

  /// Extracts embedded artwork/thumbnail from video container metadata.
  ///
  /// Returns the image bytes (JPEG/PNG) if embedded artwork exists in the
  /// video container, null otherwise. Does not decode video frames - only
  /// reads pre-existing artwork stored in the container metadata.
  ///
  /// Platform implementations:
  /// - Android: MediaMetadataRetriever.getEmbeddedPicture()
  /// - iOS/macOS: AVAsset.metadata with AVMetadataCommonKeyArtwork
  /// - Web: Returns null (no API for this)
  ///
  /// Common sources of embedded artwork:
  /// - iTunes movies (MP4/M4V with cover art)
  /// - MKV files with cover attachments
  /// - Music videos with album art
  @async
  Uint8List? extractEmbeddedArtwork(VideoSourceMessage source);

  /// Extracts a video frame at the specified position as an image.
  ///
  /// Returns the image bytes (JPEG) of the video frame at [positionMs].
  /// If [positionMs] is 0, extracts the first available frame.
  ///
  /// Platform implementations:
  /// - Android: MediaMetadataRetriever.getFrameAtTime()
  /// - iOS/macOS: AVAssetImageGenerator.generateCGImagesAsynchronously()
  /// - Web: Draw video to canvas, export as JPEG
  ///
  /// Optional parameters:
  /// - [maxWidth]: Maximum width of the output image (maintains aspect ratio)
  /// - [maxHeight]: Maximum height of the output image (maintains aspect ratio)
  /// - [quality]: JPEG quality (0-100, default 80)
  @async
  Uint8List? extractVideoFrame(VideoSourceMessage source, int positionMs, int? maxWidth, int? maxHeight, int? quality);
}

/// Playback state enumeration.
enum PlaybackStateEnum {
  /// Player is uninitialized.
  uninitialized,

  /// Player is initializing.
  initializing,

  /// Player is ready to play.
  ready,

  /// Player is playing.
  playing,

  /// Player is paused.
  paused,

  /// Playback has completed.
  completed,

  /// Player is buffering.
  buffering,

  /// Player encountered an error.
  error,

  /// Player has been disposed.
  disposed,
}

/// Video player event data sent from the platform to Dart.
///
/// This is a base class for all events. Specific event types will include
/// additional fields.
class VideoPlayerEventMessage {
  /// The type of event.
  final String type;

  /// Playback state (for playbackStateChanged events).
  final PlaybackStateEnum? state;

  /// Position in milliseconds (for positionChanged events).
  final int? positionMs;

  /// Buffered position in milliseconds (for bufferedPositionChanged events).
  final int? bufferedPositionMs;

  /// Duration in milliseconds (for durationChanged events).
  final int? durationMs;

  /// Error message (for error events).
  final String? errorMessage;

  /// Error code (for error events).
  final String? errorCode;

  /// Video width (for videoSizeChanged events).
  final int? width;

  /// Video height (for videoSizeChanged events).
  final int? height;

  VideoPlayerEventMessage({
    required this.type,
    this.state,
    this.positionMs,
    this.bufferedPositionMs,
    this.durationMs,
    this.errorMessage,
    this.errorCode,
    this.width,
    this.height,
  });
}

/// Flutter API for callbacks from the platform to Dart.
///
/// This API is implemented in Dart and called from the native platform
/// to send events.
///
/// HYBRID EVENT SYSTEM:
/// - High-frequency events (position, buffering, state) use EventChannel
/// - Low-frequency events (errors, metadata, completion) use @FlutterApi for type safety
@FlutterApi()
abstract class ProVideoPlayerFlutterApi {
  /// Called when a video player event occurs (deprecated - kept for EventChannel compatibility).
  ///
  /// High-frequency events still use EventChannel:
  /// - positionChanged, bufferedPositionChanged
  /// - playbackStateChanged, durationChanged
  /// - videoSizeChanged, bufferingStarted, bufferingEnded
  void onEvent(int playerId, VideoPlayerEventMessage event);

  // ==================== Low-Frequency Events (Type-Safe) ====================

  /// Called when an error occurs during playback.
  void onError(int playerId, String errorCode, String errorMessage);

  /// Called when video metadata is extracted.
  void onMetadataExtracted(int playerId, VideoMetadataMessage metadata);

  /// Called when playback completes.
  void onPlaybackCompleted(int playerId);

  /// Called when a PiP action is triggered by the user.
  void onPipActionTriggered(int playerId, String action);

  /// Called when cast state changes.
  void onCastStateChanged(int playerId, CastStateEnum state, CastDeviceMessage? device);

  /// Called when subtitle tracks change.
  void onSubtitleTracksChanged(int playerId, List<SubtitleTrackMessage?> tracks);

  /// Called when audio tracks change.
  void onAudioTracksChanged(int playerId, List<AudioTrackMessage?> tracks);

  /// Called when battery information changes.
  ///
  /// Emitted when the device's battery level or charging state changes.
  /// Platform availability varies (see getBatteryInfo documentation).
  void onBatteryInfoChanged(BatteryInfoMessage batteryInfo);
}
