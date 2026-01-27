import 'audio_track.dart';
import 'caption.dart';
import 'cast_device.dart';
import 'cast_state.dart';
import 'chapter.dart';
import 'duration_range.dart';
import 'playback_state.dart';
import 'playlist.dart';
import 'playlist_mode.dart';
import 'subtitle_cue.dart';
import 'subtitle_render_mode.dart';
import 'subtitle_track.dart';
import 'video_metadata.dart';
import 'video_player_error.dart';
import 'video_player_event.dart';
import 'video_player_options.dart';
import 'video_quality_track.dart';

/// Represents the current state/value of a video player.
class VideoPlayerValue {
  /// Creates a video player value.
  const VideoPlayerValue({
    this.playbackState = PlaybackState.uninitialized,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.playbackSpeed = 1.0,
    this.volume = 1.0,
    this.isLooping = false,
    this.isPipActive = false,
    this.isFullscreen = false,
    this.size,
    this.subtitleTracks = const [],
    this.selectedSubtitleTrack,
    this.audioTracks = const [],
    this.selectedAudioTrack,
    this.qualityTracks = const [],
    this.selectedQualityTrack,
    this.errorMessage,
    this.error,
    this.title,
    this.playlist,
    this.playlistIndex,
    this.playlistRepeatMode = PlaylistRepeatMode.none,
    this.isShuffled = false,
    this.isNetworkBuffering = false,
    this.bufferingReason,
    this.networkRetryCount = 0,
    this.isRecoveringFromError = false,
    this.isBackgroundPlaybackEnabled = false,
    this.estimatedBandwidth,
    this.videoMetadata,
    this.castState = CastState.notConnected,
    this.currentCastDevice,
    this.availableCastDevices = const [],
    this.subtitleOffset = Duration.zero,
    this.currentSubtitleRenderMode = SubtitleRenderMode.auto,
    this.lockedOrientation,
    this.chapters = const [],
    this.currentChapter,
    this.currentEmbeddedCue,
    this.embeddedSubtitleCues,
  });

  /// The current playback state.
  final PlaybackState playbackState;

  /// The current playback position.
  final Duration position;

  /// The total duration of the video.
  final Duration duration;

  /// The current buffered position.
  final Duration bufferedPosition;

  /// The current playback speed (1.0 = normal speed).
  final double playbackSpeed;

  /// The current volume (0.0 to 1.0).
  final double volume;

  /// Whether the video is set to loop.
  final bool isLooping;

  /// Whether Picture-in-Picture mode is active.
  final bool isPipActive;

  /// Whether fullscreen mode is active.
  final bool isFullscreen;

  /// The size of the video in pixels.
  final ({int width, int height})? size;

  /// Available subtitle tracks.
  final List<SubtitleTrack> subtitleTracks;

  /// The currently selected subtitle track.
  final SubtitleTrack? selectedSubtitleTrack;

  /// Available audio tracks.
  final List<AudioTrack> audioTracks;

  /// The currently selected audio track.
  final AudioTrack? selectedAudioTrack;

  /// Available video quality tracks (for adaptive streams like HLS/DASH).
  ///
  /// This list is populated when playing adaptive streaming content that
  /// offers multiple quality levels. For non-adaptive content, this will
  /// be empty.
  final List<VideoQualityTrack> qualityTracks;

  /// The currently selected video quality track.
  ///
  /// If `null`, automatic quality selection (ABR) is active.
  /// Use [VideoQualityTrack.auto] to explicitly request automatic selection.
  final VideoQualityTrack? selectedQualityTrack;

  /// Error message if [playbackState] is [PlaybackState.error].
  final String? errorMessage;

  /// Detailed error information if [playbackState] is [PlaybackState.error].
  ///
  /// This provides richer error information than [errorMessage], including:
  /// - [VideoPlayerError.category] - The type of error
  /// - [VideoPlayerError.severity] - Whether the error is recoverable
  /// - [VideoPlayerError.suggestedRecovery] - Recommended recovery strategy
  /// - [VideoPlayerError.canRetry] - Whether retry attempts remain
  final VideoPlayerError? error;

  /// The title of the video from metadata, if available.
  final String? title;

  /// The current playlist, if playing from a playlist.
  final Playlist? playlist;

  /// The current index in the playlist.
  final int? playlistIndex;

  /// The playlist repeat mode.
  final PlaylistRepeatMode playlistRepeatMode;

  /// Whether the playlist is shuffled.
  final bool isShuffled;

  // ==================== Network Resilience State ====================

  /// Whether the player is currently buffering due to network conditions.
  ///
  /// This is `true` when the player has stalled playback and is waiting
  /// for more data to be buffered from the network.
  final bool isNetworkBuffering;

  /// The reason for the current buffering, if [isNetworkBuffering] is `true`.
  final BufferingReason? bufferingReason;

  /// The number of network retry attempts that have been made.
  ///
  /// This is reset to 0 when playback recovers successfully.
  final int networkRetryCount;

  /// Whether the player is currently attempting to recover from an error.
  ///
  /// This is `true` when automatic retry is in progress.
  final bool isRecoveringFromError;

  /// Whether background playback is currently enabled.
  ///
  /// When `true`, audio continues playing when the app is backgrounded.
  /// This requires platform-specific setup:
  /// - iOS: `UIBackgroundModes` with `audio` in Info.plist
  /// - Android: Foreground service permission
  /// - macOS: Background playback is enabled by default
  ///
  /// Use `ProVideoPlayerController.setBackgroundPlayback` to toggle this.
  final bool isBackgroundPlaybackEnabled;

  /// Estimated network bandwidth in bits per second.
  ///
  /// This value is estimated by the native player based on recent network
  /// performance during adaptive streaming playback. It can be used to:
  /// - Display network quality indicators to users
  /// - Make decisions about quality selection
  /// - Optimize prefetching strategies
  ///
  /// Returns `null` if:
  /// - The video is not from a network source
  /// - The player hasn't received enough data to estimate bandwidth
  /// - The platform doesn't support bandwidth estimation
  ///
  /// ## Platform Behavior
  ///
  /// - **Android (ExoPlayer):** Uses `BandwidthMeter` for continuous estimation
  /// - **iOS/macOS (AVPlayer):** Uses `accessLog` predicted throughput
  /// - **Web:** Not supported (returns `null`)
  ///
  /// Updates are sent via `BandwidthEstimateChangedEvent` and can be throttled
  /// to reduce event frequency (typically updated every few seconds).
  final int? estimatedBandwidth;

  /// Technical metadata extracted from the video (codec, resolution, bitrate, etc.).
  ///
  /// This is populated after the video is loaded and metadata is extracted.
  /// May be `null` if metadata hasn't been extracted yet or if the platform
  /// doesn't support metadata extraction.
  ///
  /// See [VideoMetadata] for available fields.
  final VideoMetadata? videoMetadata;

  // ==================== Casting State ====================

  /// The current casting connection state.
  ///
  /// Indicates whether the player is connected to a cast device, connecting,
  /// disconnecting, or not connected.
  ///
  /// ## Platform Support
  ///
  /// - **iOS/macOS**: AirPlay (built-in, no configuration required)
  /// - **Android**: Chromecast (requires Google Cast SDK setup)
  /// - **Web**: Remote Playback API (browser-dependent)
  /// - **Windows/Linux**: Not supported
  ///
  /// Listen to [CastStateChangedEvent] via the events stream for state changes.
  final CastState castState;

  /// The currently connected cast device, if any.
  ///
  /// This is `null` when [castState] is [CastState.notConnected].
  /// Contains device information (name, type, ID) when connected or connecting.
  final CastDevice? currentCastDevice;

  /// List of available cast devices on the network.
  ///
  /// This list is updated automatically as devices appear or disappear.
  /// Listen to [CastDevicesChangedEvent] via the events stream for updates.
  ///
  /// Note: On some platforms (e.g., web), this list may be empty even when
  /// casting is supported, as device discovery happens during the casting
  /// prompt rather than continuously.
  final List<CastDevice> availableCastDevices;

  /// Timing offset for subtitle synchronization.
  ///
  /// A positive value delays subtitles (shows them later), while a negative
  /// value shows subtitles earlier. This is useful for fixing subtitle sync
  /// issues where subtitles appear too early or too late.
  ///
  /// Example:
  /// - `Duration(seconds: 2)` — Subtitles appear 2 seconds later
  /// - `Duration(seconds: -1)` — Subtitles appear 1 second earlier
  ///
  /// Default is [Duration.zero] (no offset).
  final Duration subtitleOffset;

  /// The current subtitle rendering mode (resolved from auto if applicable).
  ///
  /// This reflects the actual rendering mode being used by the player:
  /// - [SubtitleRenderMode.native] — Platform renders subtitles
  /// - [SubtitleRenderMode.flutter] — Flutter renders subtitles via SubtitleOverlay
  /// - [SubtitleRenderMode.auto] — Initial/unresolved state
  ///
  /// When [VideoPlayerOptions.subtitleRenderMode] is set to `auto`, this value
  /// will be resolved to either `native` or `flutter` based on the current
  /// controls mode. Use `controller.setSubtitleRenderMode()` to change the mode
  /// at runtime.
  ///
  /// Default is [SubtitleRenderMode.auto].
  final SubtitleRenderMode currentSubtitleRenderMode;

  /// The currently locked screen orientation, if any.
  ///
  /// When not `null`, the screen is locked to the specified orientation(s).
  /// When `null`, the orientation follows the default behavior based on
  /// [VideoPlayerOptions.fullscreenOrientation].
  ///
  /// This is typically used in fullscreen mode to allow users to lock the
  /// screen to landscape or portrait orientation.
  ///
  /// See [FullscreenOrientation] for available orientation options.
  final FullscreenOrientation? lockedOrientation;

  // ==================== Chapter Navigation ====================

  /// Available chapters in the video.
  ///
  /// Chapters are time-marked sections with titles, commonly used for
  /// navigation (e.g., "Introduction", "Chapter 1: Setup", etc.).
  ///
  /// This list is populated when chapter metadata is extracted from the video.
  /// May be empty if the video has no embedded chapters.
  ///
  /// Chapters are sorted by [Chapter.startTime] in ascending order.
  final List<Chapter> chapters;

  /// The chapter at the current playback position.
  ///
  /// This is automatically updated as playback progresses through the video.
  /// May be `null` if:
  /// - The video has no chapters
  /// - The playback position is before the first chapter
  final Chapter? currentChapter;

  // ==================== Embedded Subtitle Rendering ====================

  /// The current embedded subtitle cue being rendered in Flutter.
  ///
  /// This is only populated when `VideoPlayerOptions.renderEmbeddedSubtitlesInFlutter`
  /// is `true`. The native player extracts subtitle text and streams it to Flutter
  /// for custom rendering via `SubtitleOverlay`.
  ///
  /// When `null`, no embedded subtitle is currently active (either the video has
  /// no subtitles, subtitles are disabled, or there's no text at the current position).
  ///
  /// ## Platform Behavior
  ///
  /// - **Android**: Extracted via ExoPlayer's `Player.Listener.onCues()` callback
  /// - **iOS/macOS**: Extracted via `AVPlayerItemLegibleOutput` with
  ///   `suppressesPlayerRendering = true`
  /// - **Web**: Extracted via TextTrack `cuechange` events with mode='hidden'
  ///
  /// See [EmbeddedSubtitleCueEvent] for the event that updates this value.
  final SubtitleCue? currentEmbeddedCue;

  /// Extracted cues for embedded subtitles when using Flutter render mode.
  ///
  /// When [currentSubtitleRenderMode] is [SubtitleRenderMode.flutter] and an
  /// embedded subtitle track is selected, this contains the extracted cues
  /// from the HLS/DASH stream. The subtitle overlay widget uses these cues
  /// to render subtitles with Flutter instead of relying on native rendering.
  ///
  /// This is `null` when:
  /// - No embedded subtitle track is selected
  /// - Using native render mode
  /// - Cues haven't been extracted yet
  final List<SubtitleCue>? embeddedSubtitleCues;

  /// Whether the video has chapter information available.
  bool get hasChapters => chapters.isNotEmpty;

  /// Whether the orientation is currently locked.
  bool get isOrientationLocked => lockedOrientation != null;

  /// Whether the player is currently casting.
  bool get isCasting => castState == CastState.connected;

  /// Whether the player is currently playing.
  bool get isPlaying => playbackState == PlaybackState.playing;

  /// Whether the player is initialized and ready.
  bool get isInitialized =>
      playbackState != PlaybackState.uninitialized &&
      playbackState != PlaybackState.initializing &&
      playbackState != PlaybackState.disposed;

  /// Whether the player has completed playback.
  bool get isCompleted => playbackState == PlaybackState.completed;

  /// Whether the player is buffering.
  bool get isBuffering => playbackState == PlaybackState.buffering;

  /// Whether the player has an error.
  bool get hasError => playbackState == PlaybackState.error;

  /// The aspect ratio of the video.
  ///
  /// Returns the width divided by height, or 0.0 if size is unknown
  /// or height is zero.
  ///
  /// This property is provided for compatibility with Flutter's video_player library.
  double get aspectRatio {
    if (size == null || size!.height == 0) return 0;
    return size!.width / size!.height;
  }

  /// The buffered ranges of the video.
  ///
  /// Returns a list of buffered time ranges. Currently this returns a single
  /// range from Duration.zero to [bufferedPosition], or an empty list if
  /// nothing is buffered.
  ///
  /// This property is provided for compatibility with Flutter's video_player library.
  List<DurationRange> get buffered {
    if (bufferedPosition == Duration.zero) return const [];
    return [DurationRange(Duration.zero, bufferedPosition)];
  }

  /// The current caption to display.
  ///
  /// Returns [Caption.none] if no subtitle cue is currently active, otherwise
  /// returns a [Caption] constructed from the current [currentEmbeddedCue].
  ///
  /// This property is provided for compatibility with Flutter's video_player library.
  /// For new code, prefer using [currentEmbeddedCue] directly which provides more features.
  Caption get caption {
    final cue = currentEmbeddedCue;
    if (cue == null) return Caption.none;
    return Caption(text: cue.text, start: cue.start, end: cue.end);
  }

  /// Creates a copy of this value with the given fields replaced.
  VideoPlayerValue copyWith({
    PlaybackState? playbackState,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    double? playbackSpeed,
    double? volume,
    bool? isLooping,
    bool? isPipActive,
    bool? isFullscreen,
    ({int width, int height})? size,
    List<SubtitleTrack>? subtitleTracks,
    SubtitleTrack? selectedSubtitleTrack,
    List<AudioTrack>? audioTracks,
    AudioTrack? selectedAudioTrack,
    List<VideoQualityTrack>? qualityTracks,
    VideoQualityTrack? selectedQualityTrack,
    String? errorMessage,
    VideoPlayerError? error,
    String? title,
    Playlist? playlist,
    int? playlistIndex,
    PlaylistRepeatMode? playlistRepeatMode,
    bool? isShuffled,
    bool? isNetworkBuffering,
    BufferingReason? bufferingReason,
    int? networkRetryCount,
    bool? isRecoveringFromError,
    bool? isBackgroundPlaybackEnabled,
    int? estimatedBandwidth,
    VideoMetadata? videoMetadata,
    CastState? castState,
    CastDevice? currentCastDevice,
    List<CastDevice>? availableCastDevices,
    Duration? subtitleOffset,
    SubtitleRenderMode? currentSubtitleRenderMode,
    FullscreenOrientation? lockedOrientation,
    List<Chapter>? chapters,
    Chapter? currentChapter,
    SubtitleCue? currentEmbeddedCue,
    List<SubtitleCue>? embeddedSubtitleCues,
    bool clearError = false,
    bool clearLockedOrientation = false,
    bool clearCurrentChapter = false,
    bool clearEmbeddedSubtitleCues = false,
    bool clearSelectedSubtitle = false,
    bool clearSelectedAudio = false,
    bool clearSelectedQuality = false,
    bool clearSize = false,
    bool clearTitle = false,
    bool clearPlaylist = false,
    bool clearBufferingReason = false,
    bool clearVideoMetadata = false,
    bool clearCurrentCastDevice = false,
    bool clearCurrentEmbeddedCue = false,
  }) => VideoPlayerValue(
    playbackState: playbackState ?? this.playbackState,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    bufferedPosition: bufferedPosition ?? this.bufferedPosition,
    playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    volume: volume ?? this.volume,
    isLooping: isLooping ?? this.isLooping,
    isPipActive: isPipActive ?? this.isPipActive,
    isFullscreen: isFullscreen ?? this.isFullscreen,
    size: clearSize ? null : (size ?? this.size),
    subtitleTracks: subtitleTracks ?? this.subtitleTracks,
    selectedSubtitleTrack: clearSelectedSubtitle ? null : (selectedSubtitleTrack ?? this.selectedSubtitleTrack),
    audioTracks: audioTracks ?? this.audioTracks,
    selectedAudioTrack: clearSelectedAudio ? null : (selectedAudioTrack ?? this.selectedAudioTrack),
    qualityTracks: qualityTracks ?? this.qualityTracks,
    selectedQualityTrack: clearSelectedQuality ? null : (selectedQualityTrack ?? this.selectedQualityTrack),
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    error: clearError ? null : (error ?? this.error),
    title: clearTitle ? null : (title ?? this.title),
    playlist: clearPlaylist ? null : (playlist ?? this.playlist),
    playlistIndex: clearPlaylist ? null : (playlistIndex ?? this.playlistIndex),
    playlistRepeatMode: playlistRepeatMode ?? this.playlistRepeatMode,
    isShuffled: isShuffled ?? this.isShuffled,
    isNetworkBuffering: isNetworkBuffering ?? this.isNetworkBuffering,
    bufferingReason: clearBufferingReason ? null : (bufferingReason ?? this.bufferingReason),
    networkRetryCount: networkRetryCount ?? this.networkRetryCount,
    isRecoveringFromError: isRecoveringFromError ?? this.isRecoveringFromError,
    isBackgroundPlaybackEnabled: isBackgroundPlaybackEnabled ?? this.isBackgroundPlaybackEnabled,
    estimatedBandwidth: estimatedBandwidth ?? this.estimatedBandwidth,
    videoMetadata: clearVideoMetadata ? null : (videoMetadata ?? this.videoMetadata),
    castState: castState ?? this.castState,
    currentCastDevice: clearCurrentCastDevice ? null : (currentCastDevice ?? this.currentCastDevice),
    availableCastDevices: availableCastDevices ?? this.availableCastDevices,
    subtitleOffset: subtitleOffset ?? this.subtitleOffset,
    currentSubtitleRenderMode: currentSubtitleRenderMode ?? this.currentSubtitleRenderMode,
    lockedOrientation: clearLockedOrientation ? null : (lockedOrientation ?? this.lockedOrientation),
    chapters: chapters ?? this.chapters,
    currentChapter: clearCurrentChapter ? null : (currentChapter ?? this.currentChapter),
    currentEmbeddedCue: clearCurrentEmbeddedCue ? null : (currentEmbeddedCue ?? this.currentEmbeddedCue),
    embeddedSubtitleCues: clearEmbeddedSubtitleCues ? null : (embeddedSubtitleCues ?? this.embeddedSubtitleCues),
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! VideoPlayerValue) return false;
    return playbackState == other.playbackState &&
        position == other.position &&
        duration == other.duration &&
        bufferedPosition == other.bufferedPosition &&
        playbackSpeed == other.playbackSpeed &&
        volume == other.volume &&
        isLooping == other.isLooping &&
        isPipActive == other.isPipActive &&
        isFullscreen == other.isFullscreen &&
        size == other.size &&
        _listEquals(subtitleTracks, other.subtitleTracks) &&
        selectedSubtitleTrack == other.selectedSubtitleTrack &&
        _listEquals(audioTracks, other.audioTracks) &&
        selectedAudioTrack == other.selectedAudioTrack &&
        _listEquals(qualityTracks, other.qualityTracks) &&
        selectedQualityTrack == other.selectedQualityTrack &&
        errorMessage == other.errorMessage &&
        error == other.error &&
        title == other.title &&
        playlist == other.playlist &&
        playlistIndex == other.playlistIndex &&
        playlistRepeatMode == other.playlistRepeatMode &&
        isShuffled == other.isShuffled &&
        isNetworkBuffering == other.isNetworkBuffering &&
        bufferingReason == other.bufferingReason &&
        networkRetryCount == other.networkRetryCount &&
        isRecoveringFromError == other.isRecoveringFromError &&
        isBackgroundPlaybackEnabled == other.isBackgroundPlaybackEnabled &&
        estimatedBandwidth == other.estimatedBandwidth &&
        videoMetadata == other.videoMetadata &&
        castState == other.castState &&
        currentCastDevice == other.currentCastDevice &&
        _listEquals(availableCastDevices, other.availableCastDevices) &&
        subtitleOffset == other.subtitleOffset &&
        currentSubtitleRenderMode == other.currentSubtitleRenderMode &&
        lockedOrientation == other.lockedOrientation &&
        _listEquals(chapters, other.chapters) &&
        currentChapter == other.currentChapter &&
        currentEmbeddedCue == other.currentEmbeddedCue &&
        _listEquals(embeddedSubtitleCues ?? [], other.embeddedSubtitleCues ?? []);
  }

  @override
  int get hashCode => Object.hash(
    playbackState,
    position,
    duration,
    bufferedPosition,
    playbackSpeed,
    volume,
    isLooping,
    isPipActive,
    isFullscreen,
    size,
    Object.hashAll(subtitleTracks),
    selectedSubtitleTrack,
    Object.hashAll(audioTracks),
    selectedAudioTrack,
    Object.hashAll(qualityTracks),
    selectedQualityTrack,
    errorMessage,
    error,
    Object.hash(
      title,
      playlist,
      playlistIndex,
      playlistRepeatMode,
      isShuffled,
      isNetworkBuffering,
      bufferingReason,
      networkRetryCount,
      isRecoveringFromError,
      isBackgroundPlaybackEnabled,
      estimatedBandwidth,
      videoMetadata,
      castState,
      currentCastDevice,
      Object.hash(
        Object.hashAll(availableCastDevices),
        subtitleOffset,
        currentSubtitleRenderMode,
        lockedOrientation,
        Object.hashAll(chapters),
        currentChapter,
        currentEmbeddedCue,
        Object.hashAll(embeddedSubtitleCues ?? []),
      ),
    ),
  );

  @override
  String toString() =>
      'VideoPlayerValue('
      'playbackState: $playbackState, '
      'position: $position, '
      'duration: $duration, '
      'bufferedPosition: $bufferedPosition, '
      'playbackSpeed: $playbackSpeed, '
      'volume: $volume, '
      'isLooping: $isLooping, '
      'isPipActive: $isPipActive, '
      'isFullscreen: $isFullscreen, '
      'size: $size, '
      'subtitleTracks: $subtitleTracks, '
      'selectedSubtitleTrack: $selectedSubtitleTrack, '
      'audioTracks: $audioTracks, '
      'selectedAudioTrack: $selectedAudioTrack, '
      'qualityTracks: $qualityTracks, '
      'selectedQualityTrack: $selectedQualityTrack, '
      'errorMessage: $errorMessage, '
      'error: $error, '
      'title: $title, '
      'playlist: $playlist, '
      'playlistIndex: $playlistIndex, '
      'playlistRepeatMode: $playlistRepeatMode, '
      'isShuffled: $isShuffled, '
      'isNetworkBuffering: $isNetworkBuffering, '
      'bufferingReason: $bufferingReason, '
      'networkRetryCount: $networkRetryCount, '
      'isRecoveringFromError: $isRecoveringFromError, '
      'isBackgroundPlaybackEnabled: $isBackgroundPlaybackEnabled, '
      'estimatedBandwidth: $estimatedBandwidth, '
      'videoMetadata: $videoMetadata, '
      'castState: $castState, '
      'currentCastDevice: $currentCastDevice, '
      'availableCastDevices: $availableCastDevices, '
      'subtitleOffset: $subtitleOffset, '
      'lockedOrientation: $lockedOrientation, '
      'chapters: ${chapters.length}, '
      'currentChapter: ${currentChapter?.title}, '
      'currentEmbeddedCue: ${currentEmbeddedCue != null ? (currentEmbeddedCue!.text.length > 30 ? '${currentEmbeddedCue!.text.substring(0, 30)}...' : currentEmbeddedCue!.text) : null}, '
      'embeddedSubtitleCues: ${embeddedSubtitleCues?.length ?? 0}'
      ')';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
