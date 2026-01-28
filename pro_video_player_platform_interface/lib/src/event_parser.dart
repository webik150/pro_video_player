/// Utility class for parsing video player events from native platform data.
///
/// This class provides static methods to convert Map-based event data from
/// native platforms into type-safe [VideoPlayerEvent] objects.
///
/// ## Hybrid Event System
///
/// The video player uses a hybrid event system for optimal performance and type safety:
///
/// **High-frequency events** (position updates, buffering, playback state changes) are
/// sent via EventChannel and parsed by this class. EventChannel provides low overhead
/// for streaming events at high rates (10-30 Hz).
///
/// **Low-frequency events** (errors, metadata extraction, completion, PiP actions, cast
/// state, track changes) are sent via Pigeon @FlutterApi callbacks, providing type-safe
/// communication. When FlutterApi is unavailable, these events fall back to EventChannel
/// and are also parsed by this class.
///
/// Platform implementations (iOS, Android, macOS) route events based on frequency:
/// - High-frequency → EventChannel (always)
/// - Low-frequency → Pigeon FlutterApi (preferred) or EventChannel (fallback)
///
/// This ensures the best of both worlds: performance for high-frequency events and
/// type safety for important but infrequent events.
library;

import 'types/types.dart';
import 'video_format_utils.dart';

/// Event parser for converting native event data to typed events.
class EventParser {
  EventParser._();

  /// Parses an event from native code into a [VideoPlayerEvent].
  ///
  /// Returns null if the event type is unknown or the data is malformed.
  static VideoPlayerEvent? parseEvent(Map<dynamic, dynamic> event) {
    final type = event['type'] as String?;
    if (type == null) return null;

    return switch (type) {
      'playbackStateChanged' => PlaybackStateChangedEvent(_parsePlaybackState(event['state'] as String)),
      'positionChanged' => PositionChangedEvent(Duration(milliseconds: event['position'] as int)),
      'bufferedPositionChanged' => BufferedPositionChangedEvent(
        Duration(milliseconds: event['bufferedPosition'] as int),
      ),
      'durationChanged' => DurationChangedEvent(Duration(milliseconds: event['duration'] as int)),
      'playbackCompleted' => const PlaybackCompletedEvent(),
      'error' => ErrorEvent(event['message'] as String, code: event['code'] as String?),
      'videoSizeChanged' => VideoSizeChangedEvent(width: event['width'] as int, height: event['height'] as int),
      'subtitleTracksChanged' => SubtitleTracksChangedEvent(_parseSubtitleTracks(event['tracks'] as List<dynamic>)),
      'selectedSubtitleChanged' => SelectedSubtitleChangedEvent(
        event['track'] != null ? _parseSubtitleTrack(event['track'] as Map<dynamic, dynamic>) : null,
      ),
      'audioTracksChanged' => AudioTracksChangedEvent(_parseAudioTracks(event['tracks'] as List<dynamic>)),
      'selectedAudioChanged' => SelectedAudioChangedEvent(
        event['track'] != null ? _parseAudioTrack(event['track'] as Map<dynamic, dynamic>) : null,
      ),
      'videoQualityTracksChanged' => VideoQualityTracksChangedEvent(
        _parseVideoQualityTracks(event['tracks'] as List<dynamic>? ?? []),
      ),
      'selectedQualityChanged' => SelectedQualityChangedEvent(
        _parseVideoQualityTrack(event['track'] as Map<dynamic, dynamic>),
        isAutoSwitch: event['isAutoSwitch'] as bool? ?? false,
      ),
      'pipStateChanged' => PipStateChangedEvent(isActive: event['isActive'] as bool),
      'fullscreenStateChanged' => FullscreenStateChangedEvent(isFullscreen: event['isFullscreen'] as bool),
      'backgroundPlaybackChanged' => BackgroundPlaybackChangedEvent(isEnabled: event['isEnabled'] as bool),
      'playbackSpeedChanged' => PlaybackSpeedChangedEvent(event['speed'] as double),
      'volumeChanged' => VolumeChangedEvent(event['volume'] as double),
      'metadataChanged' => MetadataChangedEvent(
        title: event['title'] as String?,
        artist: event['artist'] as String?,
        album: event['album'] as String?,
        year: event['year'] as int?,
        genre: event['genre'] as String?,
      ),
      'bufferingStarted' => BufferingStartedEvent(reason: _parseBufferingReason(event['reason'] as String?)),
      'bufferingEnded' => const BufferingEndedEvent(),
      'networkError' => NetworkErrorEvent(
        message: event['message'] as String? ?? 'Network error',
        willRetry: event['willRetry'] as bool? ?? false,
        retryAttempt: event['retryAttempt'] as int? ?? 0,
        maxRetries: event['maxRetries'] as int? ?? 3,
      ),
      'playbackRecovered' => PlaybackRecoveredEvent(retriesUsed: event['retriesUsed'] as int? ?? 0),
      'networkStateChanged' => NetworkStateChangedEvent(isConnected: event['isConnected'] as bool? ?? false),
      'pipActionTriggered' => PipActionTriggeredEvent(action: _parsePipActionType(event['action'] as String?)),
      'pipRestoreUserInterface' => const PipRestoreUserInterfaceEvent(),
      'bandwidthEstimateChanged' => BandwidthEstimateChangedEvent(event['bandwidth'] as int? ?? 0),
      'videoMetadataExtracted' => VideoMetadataExtractedEvent(
        VideoMetadata.fromMap(Map<String, dynamic>.from(event['metadata'] as Map<dynamic, dynamic>)),
      ),
      'castStateChanged' => CastStateChangedEvent(
        state: _parseCastState(event['state'] as String?),
        device: event['device'] != null ? _parseCastDevice(event['device'] as Map<dynamic, dynamic>) : null,
      ),
      'castDevicesChanged' => CastDevicesChangedEvent(_parseCastDevices(event['devices'] as List<dynamic>? ?? [])),
      'chaptersExtracted' => ChaptersExtractedEvent(_parseChapters(event['chapters'] as List<dynamic>? ?? [])),
      'currentChapterChanged' => CurrentChapterChangedEvent(
        event['chapter'] != null ? _parseChapter(event['chapter'] as Map<dynamic, dynamic>) : null,
      ),
      'embeddedSubtitleCue' => EmbeddedSubtitleCueEvent(
        cue: _parseEmbeddedSubtitleCue(event),
        trackId: event['trackId'] as String?,
      ),
      _ => null,
    };
  }

  static PipActionType _parsePipActionType(String? action) => switch (action) {
    'playPause' => PipActionType.playPause,
    'skipPrevious' => PipActionType.skipPrevious,
    'skipNext' => PipActionType.skipNext,
    'skipBackward' => PipActionType.skipBackward,
    'skipForward' => PipActionType.skipForward,
    _ => PipActionType.playPause,
  };

  static BufferingReason _parseBufferingReason(String? reason) => switch (reason) {
    'initial' => BufferingReason.initial,
    'seeking' => BufferingReason.seeking,
    'insufficientBandwidth' => BufferingReason.insufficientBandwidth,
    'networkUnstable' => BufferingReason.networkUnstable,
    _ => BufferingReason.unknown,
  };

  static PlaybackState _parsePlaybackState(String state) => switch (state) {
    'uninitialized' => PlaybackState.uninitialized,
    'initializing' => PlaybackState.initializing,
    'ready' => PlaybackState.ready,
    'playing' => PlaybackState.playing,
    'paused' => PlaybackState.paused,
    'completed' => PlaybackState.completed,
    'buffering' => PlaybackState.buffering,
    'error' => PlaybackState.error,
    'disposed' => PlaybackState.disposed,
    _ => PlaybackState.uninitialized,
  };

  static List<SubtitleTrack> _parseSubtitleTracks(List<dynamic> tracks) =>
      tracks.map((t) => _parseSubtitleTrack(t as Map<dynamic, dynamic>)).toList();

  static SubtitleTrack _parseSubtitleTrack(Map<dynamic, dynamic> track) {
    final language = track['language'] as String?;
    final nativeLabel = track['label'] as String?;

    final label = (nativeLabel != null && nativeLabel.isNotEmpty)
        ? nativeLabel
        : VideoPlayerConstants.getLanguageDisplayName(language);

    return SubtitleTrack(
      id: track['id'] as String,
      label: label,
      language: language,
      isDefault: track['isDefault'] as bool? ?? false,
    );
  }

  static List<AudioTrack> _parseAudioTracks(List<dynamic> tracks) =>
      tracks.map((t) => _parseAudioTrack(t as Map<dynamic, dynamic>)).toList();

  static AudioTrack _parseAudioTrack(Map<dynamic, dynamic> track) {
    final language = track['language'] as String?;
    final nativeLabel = track['label'] as String?;

    final label = (nativeLabel != null && nativeLabel.isNotEmpty)
        ? nativeLabel
        : VideoPlayerConstants.getLanguageDisplayName(language);

    return AudioTrack(
      id: track['id'] as String,
      label: label,
      language: language,
      isDefault: track['isDefault'] as bool? ?? false,
    );
  }

  static List<Chapter> _parseChapters(List<dynamic> chapters) =>
      chapters.map((c) => _parseChapter(c as Map<dynamic, dynamic>)).toList();

  static Chapter _parseChapter(Map<dynamic, dynamic> chapter) => Chapter(
    id: chapter['id'] as String,
    title: chapter['title'] as String,
    startTime: Duration(milliseconds: chapter['startTimeMs'] as int),
    endTime: chapter['endTimeMs'] != null ? Duration(milliseconds: chapter['endTimeMs'] as int) : null,
    thumbnailUrl: chapter['thumbnailUrl'] as String?,
  );

  static SubtitleCue? _parseEmbeddedSubtitleCue(Map<dynamic, dynamic> event) {
    final text = event['text'] as String?;
    if (text == null) return null;

    return SubtitleCue(
      text: text,
      start: Duration(milliseconds: event['startMs'] as int? ?? 0),
      end: Duration(milliseconds: event['endMs'] as int? ?? 0),
    );
  }

  static VideoQualityTrack _parseVideoQualityTrack(Map<dynamic, dynamic> track) {
    final id = track['id'] as String;
    if (id == 'auto') {
      return VideoQualityTrack.auto;
    }

    final height = track['height'] as int? ?? 0;
    final frameRate = track['frameRate'] as double?;
    final nativeLabel = track['label'] as String?;

    final label = (nativeLabel != null && nativeLabel.isNotEmpty)
        ? nativeLabel
        : height > 0
        ? VideoFormatUtils.getQualityLabel(height, frameRate)
        : '';

    return VideoQualityTrack(
      id: id,
      bitrate: track['bitrate'] as int? ?? 0,
      width: track['width'] as int? ?? 0,
      height: height,
      frameRate: frameRate,
      label: label,
      isDefault: track['isDefault'] as bool? ?? false,
    );
  }

  static List<VideoQualityTrack> _parseVideoQualityTracks(List<dynamic> tracks) =>
      tracks.map((t) => _parseVideoQualityTrack(t as Map<dynamic, dynamic>)).toList();

  static CastDevice _parseCastDevice(Map<dynamic, dynamic> device) => CastDevice(
    id: device['id'] as String,
    name: device['name'] as String,
    type: _parseCastDeviceType(device['type'] as String?),
  );

  static List<CastDevice> _parseCastDevices(List<dynamic> devices) =>
      devices.map((d) => _parseCastDevice(d as Map<dynamic, dynamic>)).toList();

  static CastState _parseCastState(String? state) => switch (state) {
    'notConnected' => CastState.notConnected,
    'connecting' => CastState.connecting,
    'connected' => CastState.connected,
    'disconnecting' => CastState.disconnecting,
    _ => CastState.notConnected,
  };

  static CastDeviceType _parseCastDeviceType(String? type) => switch (type) {
    'airPlay' => CastDeviceType.airPlay,
    'chromecast' => CastDeviceType.chromecast,
    'webRemotePlayback' => CastDeviceType.webRemotePlayback,
    _ => CastDeviceType.unknown,
  };
}
