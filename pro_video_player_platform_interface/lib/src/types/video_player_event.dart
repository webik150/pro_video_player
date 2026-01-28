import 'audio_track.dart';
import 'cast_device.dart';
import 'cast_state.dart';
import 'chapter.dart';
import 'pip_action.dart';
import 'playback_state.dart';
import 'subtitle_cue.dart';
import 'subtitle_track.dart';
import 'video_metadata.dart';
import 'video_player_error.dart';
import 'video_quality_track.dart';

/// Events emitted by the video player.
sealed class VideoPlayerEvent {
  const VideoPlayerEvent();
}

/// Emitted when the playback state changes.
final class PlaybackStateChangedEvent extends VideoPlayerEvent {
  /// Creates a playback state changed event.
  const PlaybackStateChangedEvent(this.state);

  /// The new playback state.
  final PlaybackState state;

  @override
  String toString() => 'PlaybackStateChangedEvent(state: $state)';
}

/// Emitted when the playback position changes.
final class PositionChangedEvent extends VideoPlayerEvent {
  /// Creates a position changed event.
  const PositionChangedEvent(this.position);

  /// The current playback position.
  final Duration position;

  @override
  String toString() => 'PositionChangedEvent(position: $position)';
}

/// Emitted when the buffered position changes.
final class BufferedPositionChangedEvent extends VideoPlayerEvent {
  /// Creates a buffered position changed event.
  const BufferedPositionChangedEvent(this.bufferedPosition);

  /// The current buffered position.
  final Duration bufferedPosition;

  @override
  String toString() => 'BufferedPositionChangedEvent(bufferedPosition: $bufferedPosition)';
}

/// Emitted when the video duration becomes available.
final class DurationChangedEvent extends VideoPlayerEvent {
  /// Creates a duration changed event.
  const DurationChangedEvent(this.duration);

  /// The total duration of the video.
  final Duration duration;

  @override
  String toString() => 'DurationChangedEvent(duration: $duration)';
}

/// Emitted when video playback completes.
final class PlaybackCompletedEvent extends VideoPlayerEvent {
  /// Creates a playback completed event.
  const PlaybackCompletedEvent();

  @override
  String toString() => 'PlaybackCompletedEvent()';
}

/// Emitted when an error occurs.
final class ErrorEvent extends VideoPlayerEvent {
  /// Creates an error event with a simple message and optional code.
  ///
  /// For richer error information, use [ErrorEvent.withError] instead.
  ErrorEvent(this.message, {this.code}) : error = VideoPlayerError.fromCode(message: message, code: code);

  /// Creates an error event with a full [VideoPlayerError] object.
  ///
  /// This constructor provides access to error classification, severity,
  /// and recovery suggestions.
  ErrorEvent.withError(this.error) : message = error.message, code = error.code;

  /// The error message.
  final String message;

  /// Optional error code for programmatic error handling.
  final String? code;

  /// The full error object with classification and recovery information.
  ///
  /// Use this to access:
  /// - [VideoPlayerError.category] - The type of error (network, codec, etc.)
  /// - [VideoPlayerError.severity] - Whether the error is recoverable
  /// - [VideoPlayerError.suggestedRecovery] - Recommended recovery strategy
  /// - [VideoPlayerError.canRetry] - Whether retry attempts remain
  final VideoPlayerError error;

  @override
  String toString() => 'ErrorEvent(message: $message, code: $code, category: ${error.category})';
}

/// Emitted when the video size becomes available.
final class VideoSizeChangedEvent extends VideoPlayerEvent {
  /// Creates a video size changed event.
  const VideoSizeChangedEvent({required this.width, required this.height});

  /// The video width in pixels.
  final int width;

  /// The video height in pixels.
  final int height;

  @override
  String toString() => 'VideoSizeChangedEvent(width: $width, height: $height)';
}

/// Emitted when available subtitle tracks change.
final class SubtitleTracksChangedEvent extends VideoPlayerEvent {
  /// Creates a subtitle tracks changed event.
  const SubtitleTracksChangedEvent(this.tracks);

  /// The list of available subtitle tracks.
  final List<SubtitleTrack> tracks;

  @override
  String toString() => 'SubtitleTracksChangedEvent(tracks: $tracks)';
}

/// Emitted when the selected subtitle track changes.
final class SelectedSubtitleChangedEvent extends VideoPlayerEvent {
  /// Creates a selected subtitle changed event.
  const SelectedSubtitleChangedEvent(this.track);

  /// The currently selected subtitle track, or null if subtitles are disabled.
  final SubtitleTrack? track;

  @override
  String toString() => 'SelectedSubtitleChangedEvent(track: $track)';
}

/// Emitted when available audio tracks change.
final class AudioTracksChangedEvent extends VideoPlayerEvent {
  /// Creates an audio tracks changed event.
  const AudioTracksChangedEvent(this.tracks);

  /// The list of available audio tracks.
  final List<AudioTrack> tracks;

  @override
  String toString() => 'AudioTracksChangedEvent(tracks: $tracks)';
}

/// Emitted when the selected audio track changes.
final class SelectedAudioChangedEvent extends VideoPlayerEvent {
  /// Creates a selected audio changed event.
  const SelectedAudioChangedEvent(this.track);

  /// The currently selected audio track.
  final AudioTrack? track;

  @override
  String toString() => 'SelectedAudioChangedEvent(track: $track)';
}

/// Emitted when available video quality tracks change.
///
/// This event is sent when the player detects available quality options,
/// typically after loading an HLS or DASH adaptive stream.
final class VideoQualityTracksChangedEvent extends VideoPlayerEvent {
  /// Creates a video quality tracks changed event.
  const VideoQualityTracksChangedEvent(this.tracks);

  /// The list of available video quality tracks.
  ///
  /// Always includes [VideoQualityTrack.auto] as the first option.
  final List<VideoQualityTrack> tracks;

  @override
  String toString() => 'VideoQualityTracksChangedEvent(tracks: ${tracks.length} available)';
}

/// Emitted when the selected video quality changes.
///
/// This can occur due to:
/// - User manually selecting a quality
/// - Automatic quality switching by the player (when in auto mode)
final class SelectedQualityChangedEvent extends VideoPlayerEvent {
  /// Creates a selected quality changed event.
  const SelectedQualityChangedEvent(this.track, {this.isAutoSwitch = false});

  /// The currently selected quality track.
  ///
  /// Will be [VideoQualityTrack.auto] when automatic quality selection is enabled.
  final VideoQualityTrack track;

  /// Whether this change was triggered by automatic bitrate switching.
  ///
  /// When `true`, the player automatically switched quality based on
  /// network conditions. When `false`, the user manually selected this quality.
  final bool isAutoSwitch;

  @override
  String toString() => 'SelectedQualityChangedEvent(track: $track, isAutoSwitch: $isAutoSwitch)';
}

/// Emitted when Picture-in-Picture state changes.
final class PipStateChangedEvent extends VideoPlayerEvent {
  /// Creates a PiP state changed event.
  const PipStateChangedEvent({required this.isActive});

  /// Whether Picture-in-Picture mode is currently active.
  final bool isActive;

  @override
  String toString() => 'PipStateChangedEvent(isActive: $isActive)';
}

/// Emitted when a PiP remote action button is triggered.
///
/// This event is fired when the user taps an action button in the PiP window.
/// The app can respond to this event to perform the corresponding action.
///
/// Note: Play/pause actions are typically handled automatically by the native
/// player. This event is primarily useful for skip actions or custom actions.
final class PipActionTriggeredEvent extends VideoPlayerEvent {
  /// Creates a PiP action triggered event.
  const PipActionTriggeredEvent({required this.action});

  /// The action that was triggered.
  final PipActionType action;

  @override
  String toString() => 'PipActionTriggeredEvent(action: $action)';
}

/// Emitted when the user requests to restore the app from PiP mode.
///
/// This event is fired when the user taps the "expand" or "return to app"
/// button in the PiP window. On iOS, this corresponds to the
/// `restoreUserInterfaceForPictureInPictureStop` delegate callback.
///
/// The app should respond to this event by restoring its UI and making
/// the video player visible again.
final class PipRestoreUserInterfaceEvent extends VideoPlayerEvent {
  /// Creates a PiP restore user interface event.
  const PipRestoreUserInterfaceEvent();

  @override
  String toString() => 'PipRestoreUserInterfaceEvent()';
}

/// Emitted when fullscreen state changes.
final class FullscreenStateChangedEvent extends VideoPlayerEvent {
  /// Creates a fullscreen state changed event.
  const FullscreenStateChangedEvent({required this.isFullscreen});

  /// Whether fullscreen mode is currently active.
  final bool isFullscreen;

  @override
  String toString() => 'FullscreenStateChangedEvent(isFullscreen: $isFullscreen)';
}

/// Emitted when background playback state changes.
///
/// This is sent when background playback is enabled or disabled at runtime.
final class BackgroundPlaybackChangedEvent extends VideoPlayerEvent {
  /// Creates a background playback changed event.
  const BackgroundPlaybackChangedEvent({required this.isEnabled});

  /// Whether background playback is currently enabled.
  final bool isEnabled;

  @override
  String toString() => 'BackgroundPlaybackChangedEvent(isEnabled: $isEnabled)';
}

/// Emitted when the estimated network bandwidth changes.
///
/// This event is sent periodically during playback when the native player
/// updates its bandwidth estimate. The frequency of updates depends on the
/// platform and network conditions.
///
/// The [bandwidth] value represents the estimated bits per second that can
/// be downloaded from the current network connection.
///
/// ## Platform Behavior
///
/// - **Android (ExoPlayer):** Updated via `BandwidthMeter` callbacks
/// - **iOS/macOS (AVPlayer):** Updated from `accessLog` events
/// - **Web:** Not supported (event not emitted)
final class BandwidthEstimateChangedEvent extends VideoPlayerEvent {
  /// Creates a bandwidth estimate changed event.
  const BandwidthEstimateChangedEvent(this.bandwidth);

  /// The estimated bandwidth in bits per second.
  ///
  /// For example:
  /// - 1,000,000 = ~1 Mbps (good for 480p)
  /// - 5,000,000 = ~5 Mbps (good for 720p)
  /// - 10,000,000 = ~10 Mbps (good for 1080p)
  /// - 25,000,000 = ~25 Mbps (good for 4K)
  final int bandwidth;

  @override
  String toString() => 'BandwidthEstimateChangedEvent(bandwidth: $bandwidth)';
}

/// Emitted when playback speed changes.
final class PlaybackSpeedChangedEvent extends VideoPlayerEvent {
  /// Creates a playback speed changed event.
  const PlaybackSpeedChangedEvent(this.speed);

  /// The new playback speed (1.0 is normal speed).
  final double speed;

  @override
  String toString() => 'PlaybackSpeedChangedEvent(speed: $speed)';
}

/// Emitted when volume changes.
final class VolumeChangedEvent extends VideoPlayerEvent {
  /// Creates a volume changed event.
  const VolumeChangedEvent(this.volume);

  /// The new volume level (0.0 to 1.0).
  final double volume;

  @override
  String toString() => 'VolumeChangedEvent(volume: $volume)';
}

/// Emitted when video metadata changes.
///
/// This event contains descriptive metadata extracted from the video container,
/// such as title, artist, album, year, and genre. Not all fields will be
/// available for all videos - they depend on what metadata is embedded in the
/// video file.
final class MetadataChangedEvent extends VideoPlayerEvent {
  /// Creates a metadata changed event.
  const MetadataChangedEvent({this.title, this.artist, this.album, this.year, this.genre});

  /// The title of the video, if available.
  final String? title;

  /// The artist or creator of the video.
  final String? artist;

  /// The album or collection name.
  final String? album;

  /// The release year of the video.
  final int? year;

  /// The genre of the video content.
  final String? genre;

  @override
  String toString() =>
      'MetadataChangedEvent(title: $title, artist: $artist, album: $album, year: $year, genre: $genre)';
}

/// Emitted when technical video metadata is extracted from the loaded video.
///
/// This event is sent after the video is loaded and the native player has
/// extracted technical information about the video (codec, resolution, bitrate,
/// frame rate, etc.).
///
/// Example:
/// ```dart
/// controller.events.listen((event) {
///   if (event is VideoMetadataExtractedEvent) {
///     print('Video codec: ${event.metadata.videoCodec}');
///     print('Resolution: ${event.metadata.resolution}');
///   }
/// });
/// ```
final class VideoMetadataExtractedEvent extends VideoPlayerEvent {
  /// Creates a video metadata extracted event.
  const VideoMetadataExtractedEvent(this.metadata);

  /// The extracted video metadata.
  final VideoMetadata metadata;

  @override
  String toString() => 'VideoMetadataExtractedEvent(metadata: $metadata)';
}

/// Emitted when the playlist track changes.
final class PlaylistTrackChangedEvent extends VideoPlayerEvent {
  /// Creates a playlist track changed event.
  const PlaylistTrackChangedEvent(this.index);

  /// The index of the new track in the playlist.
  final int index;

  @override
  String toString() => 'PlaylistTrackChangedEvent(index: $index)';
}

/// Emitted when the playlist ends.
final class PlaylistEndedEvent extends VideoPlayerEvent {
  /// Creates a playlist ended event.
  const PlaylistEndedEvent();

  @override
  String toString() => 'PlaylistEndedEvent()';
}

// ==================== Chapter Events ====================

/// Emitted when chapter information is extracted from the video.
///
/// Chapters are time-marked sections of a video with titles, commonly used
/// for navigation (e.g., "Introduction", "Chapter 1: Setup", etc.).
///
/// Chapters can be extracted from:
/// - MP4 chapter atoms
/// - MKV chapter markers
/// - HLS/DASH manifest metadata
/// - External chapter files (VTT with kind="chapters")
///
/// Example:
/// ```dart
/// controller.events.listen((event) {
///   if (event is ChaptersExtractedEvent) {
///     print('Found ${event.chapters.length} chapters');
///     for (final chapter in event.chapters) {
///       print('${chapter.title} at ${chapter.formattedStartTime}');
///     }
///   }
/// });
/// ```
final class ChaptersExtractedEvent extends VideoPlayerEvent {
  /// Creates a chapters extracted event.
  const ChaptersExtractedEvent(this.chapters);

  /// The list of chapters found in the video.
  ///
  /// Chapters are sorted by [Chapter.startTime] in ascending order.
  /// May be empty if no chapters are found.
  final List<Chapter> chapters;

  @override
  String toString() => 'ChaptersExtractedEvent(chapters: ${chapters.length})';
}

/// Emitted when the current chapter changes during playback.
///
/// This event is fired when the playback position crosses a chapter boundary.
/// Use this to update UI elements that display the current chapter.
///
/// Example:
/// ```dart
/// controller.events.listen((event) {
///   if (event is CurrentChapterChangedEvent) {
///     if (event.chapter != null) {
///       print('Now playing: ${event.chapter!.title}');
///     }
///   }
/// });
/// ```
final class CurrentChapterChangedEvent extends VideoPlayerEvent {
  /// Creates a current chapter changed event.
  const CurrentChapterChangedEvent(this.chapter);

  /// The chapter at the current playback position.
  ///
  /// May be `null` if:
  /// - The video has no chapters
  /// - The playback position is before the first chapter
  final Chapter? chapter;

  @override
  String toString() => 'CurrentChapterChangedEvent(chapter: ${chapter?.title})';
}

// ==================== Network Resilience Events ====================

/// Emitted when the player starts buffering due to network conditions.
///
/// This event indicates that playback has stalled and the player is waiting
/// for more data to be buffered. The [reason] provides context about why
/// buffering started.
final class BufferingStartedEvent extends VideoPlayerEvent {
  /// Creates a buffering started event.
  const BufferingStartedEvent({this.reason = BufferingReason.unknown});

  /// The reason why buffering started.
  final BufferingReason reason;

  @override
  String toString() => 'BufferingStartedEvent(reason: $reason)';
}

/// Emitted when the player finishes buffering and is ready to continue playback.
///
/// After this event, playback should resume automatically if it was playing
/// before buffering started.
final class BufferingEndedEvent extends VideoPlayerEvent {
  /// Creates a buffering ended event.
  const BufferingEndedEvent();

  @override
  String toString() => 'BufferingEndedEvent()';
}

/// Emitted when a network error is detected.
///
/// This event provides details about the network issue and whether the player
/// will attempt automatic recovery.
final class NetworkErrorEvent extends VideoPlayerEvent {
  /// Creates a network error event.
  const NetworkErrorEvent({required this.message, this.willRetry = false, this.retryAttempt = 0, this.maxRetries = 3});

  /// A description of the network error.
  final String message;

  /// Whether the player will automatically retry.
  final bool willRetry;

  /// The current retry attempt number (1-based).
  final int retryAttempt;

  /// The maximum number of retry attempts.
  final int maxRetries;

  @override
  String toString() =>
      'NetworkErrorEvent(message: $message, willRetry: $willRetry, retryAttempt: $retryAttempt/$maxRetries)';
}

/// Emitted when playback is successfully recovered after a network error.
///
/// This indicates that automatic retry was successful and playback has resumed.
final class PlaybackRecoveredEvent extends VideoPlayerEvent {
  /// Creates a playback recovered event.
  const PlaybackRecoveredEvent({this.retriesUsed = 0});

  /// The number of retry attempts used before recovery.
  final int retriesUsed;

  @override
  String toString() => 'PlaybackRecoveredEvent(retriesUsed: $retriesUsed)';
}

/// Reasons why buffering may have started.
enum BufferingReason {
  /// Initial buffering when starting playback.
  initial,

  /// Buffering due to seeking to a new position.
  seeking,

  /// Buffering due to network bandwidth being insufficient.
  insufficientBandwidth,

  /// Buffering due to network connection being lost or unstable.
  networkUnstable,

  /// Reason is unknown or not specified.
  unknown,
}

/// Emitted when network connectivity state changes.
///
/// This event is used to trigger retry attempts when network is restored.
final class NetworkStateChangedEvent extends VideoPlayerEvent {
  /// Creates a network state changed event.
  const NetworkStateChangedEvent({required this.isConnected});

  /// Whether the device currently has network connectivity.
  final bool isConnected;

  @override
  String toString() => 'NetworkStateChangedEvent(isConnected: $isConnected)';
}

// ==================== Casting Events ====================

/// Emitted when the casting state changes.
///
/// This event is fired when the connection to a cast device changes state,
/// such as when connecting, connected, or disconnecting.
final class CastStateChangedEvent extends VideoPlayerEvent {
  /// Creates a cast state changed event.
  const CastStateChangedEvent({required this.state, this.device});

  /// The new casting state.
  final CastState state;

  /// The cast device involved in this state change, if any.
  ///
  /// This is `null` when [state] is [CastState.notConnected].
  final CastDevice? device;

  @override
  String toString() => 'CastStateChangedEvent(state: $state, device: $device)';
}

/// Emitted when the list of available cast devices changes.
///
/// This event is fired when cast devices become available or unavailable
/// on the network. For example, when an AirPlay TV is turned on/off, or
/// when a Chromecast is discovered/lost.
final class CastDevicesChangedEvent extends VideoPlayerEvent {
  /// Creates a cast devices changed event.
  const CastDevicesChangedEvent(this.devices);

  /// The current list of available cast devices.
  final List<CastDevice> devices;

  @override
  String toString() => 'CastDevicesChangedEvent(${devices.length} devices available)';
}

// ==================== Embedded Subtitle Events ====================

/// Emitted when embedded subtitle text is extracted from the native player.
///
/// This event is used when `VideoPlayerOptions.renderEmbeddedSubtitlesInFlutter`
/// is enabled. Instead of the native player rendering subtitles, the text is
/// extracted and sent to Flutter for rendering via `SubtitleOverlay`.
///
/// The [cue] contains the subtitle text and timing information. When [cue] is
/// `null`, it indicates that the current subtitle should be hidden (no active
/// cue at the current position).
///
/// Example:
/// ```dart
/// controller.events.listen((event) {
///   if (event is EmbeddedSubtitleCueEvent) {
///     if (event.cue != null) {
///       print('Subtitle: ${event.cue!.text}');
///     } else {
///       print('Subtitle hidden');
///     }
///   }
/// });
/// ```
final class EmbeddedSubtitleCueEvent extends VideoPlayerEvent {
  /// Creates an embedded subtitle cue event.
  const EmbeddedSubtitleCueEvent({required this.cue, this.trackId});

  /// The current subtitle cue to display, or `null` to hide subtitles.
  ///
  /// When the playback position moves past the current cue's end time,
  /// this will be `null` until the next cue becomes active.
  final SubtitleCue? cue;

  /// The ID of the subtitle track this cue belongs to.
  ///
  /// This can be used to match cues to their source track when multiple
  /// subtitle tracks are available.
  final String? trackId;

  @override
  String toString() => 'EmbeddedSubtitleCueEvent(cue: $cue, trackId: $trackId)';
}
