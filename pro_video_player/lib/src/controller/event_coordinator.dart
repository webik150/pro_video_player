import 'dart:async';

import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

import 'error_recovery_manager.dart';
import 'playback_manager.dart';
import 'playlist_manager.dart';
import 'track_manager.dart';

// Alias for cleaner code
typedef _Logger = ProVideoPlayerLogger;

/// Coordinates event handling between the platform and the controller.
///
/// This coordinator handles:
/// - Subscribing to platform events
/// - Routing events to appropriate managers
/// - Updating controller state based on events
/// - Coordinating cross-manager interactions
class EventCoordinator {
  /// Creates an event coordinator with dependency injection via callbacks.
  EventCoordinator({
    required this.getValue,
    required this.setValue,
    required this.getPlayerId,
    required this.getOptions,
    required this.isDisposed,
    required this.isRetrying,
    required this.setRetrying,
    required this.platform,
    required this.playbackManager,
    required this.trackManager,
    required this.errorRecoveryManager,
    required this.playlistManager,
    required this.onSeekTo,
    required this.onPlay,
  });

  /// Gets the current video player value.
  final VideoPlayerValue Function() getValue;

  /// Updates the video player value.
  final void Function(VideoPlayerValue) setValue;

  /// Gets the player ID (null if not initialized).
  final int? Function() getPlayerId;

  /// Gets the video player options.
  final VideoPlayerOptions Function() getOptions;

  /// Whether the controller is disposed.
  final bool Function() isDisposed;

  /// Whether the controller is currently retrying playback.
  final bool Function() isRetrying;

  /// Sets the retrying flag.
  final void Function({required bool isRetrying}) setRetrying;

  /// Platform implementation for event streaming.
  final ProVideoPlayerPlatform platform;

  /// Playback manager for state synchronization.
  final PlaybackManager playbackManager;

  /// Track manager for subtitle auto-selection.
  final TrackManager trackManager;

  /// Error recovery manager for error handling.
  final ErrorRecoveryManager errorRecoveryManager;

  /// Playlist manager for playlist progression.
  final PlaylistManager playlistManager;

  /// Callback to seek to a specific position.
  final Future<void> Function(Duration) onSeekTo;

  /// Callback to start playback.
  final Future<void> Function() onPlay;

  StreamSubscription<VideoPlayerEvent>? _eventSubscription;
  bool _isSubscribed = false;

  /// Subscribes to platform events.
  ///
  /// This method is idempotent - calling it multiple times is safe.
  /// Subscription happens lazily to avoid test hanging issues.
  void subscribeToEvents() {
    if (_isSubscribed) return;

    final playerId = getPlayerId();
    if (playerId == null) return;

    _eventSubscription = platform.events(playerId).listen(_handleEvent);
    _isSubscribed = true;
  }

  /// Ensures events are subscribed. Call this before operations that need platform events.
  void ensureSubscribed() {
    subscribeToEvents();
  }

  /// Handles events from the platform.
  Future<void> _handleEvent(VideoPlayerEvent event) async {
    if (isDisposed()) return;

    switch (event) {
      case PlaybackStateChangedEvent(:final state):
        // Skip redundant state updates (native confirming what we already set optimistically)
        if (state == getValue().playbackState) {
          return;
        }
        // Use playback manager to handle state synchronization
        if (!playbackManager.handlePlaybackStateChanged(state)) {
          return; // Stale event, ignore
        }
        setValue(getValue().copyWith(playbackState: state));

      case PositionChangedEvent(:final position):
        // Use playback manager to handle position synchronization
        if (playbackManager.handlePositionChanged(position)) {
          setValue(getValue().copyWith(position: position));
          // Update current chapter if chapters are available
          if (getValue().chapters.isNotEmpty) {
            _updateCurrentChapter();
          }
        }

      case BufferedPositionChangedEvent(:final bufferedPosition):
        setValue(getValue().copyWith(bufferedPosition: bufferedPosition));

      case DurationChangedEvent(:final duration):
        setValue(getValue().copyWith(duration: duration));

      case PlaybackCompletedEvent():
        setValue(getValue().copyWith(playbackState: PlaybackState.completed));
        // Handle playlist progression
        final value = getValue();
        if (value.playlist != null && value.playlistRepeatMode == PlaylistRepeatMode.one) {
          // Repeat current track
          await onSeekTo(Duration.zero);
          await onPlay();
        } else if (value.playlist != null) {
          // Try to move to next track
          await playlistManager.handlePlaybackCompleted();
          // If handlePlaybackCompleted returns false, playlist has ended naturally
        }

      case ErrorEvent(:final message, :final error):
        setValue(getValue().copyWith(playbackState: PlaybackState.error, errorMessage: message, error: error));
        // Schedule auto-retry if enabled and error is recoverable
        errorRecoveryManager.scheduleAutoRetry(error);

      case VideoSizeChangedEvent(:final width, :final height):
        setValue(getValue().copyWith(size: (width: width, height: height)));

      case SubtitleTracksChangedEvent(:final tracks):
        // Only update if subtitles are enabled
        _Logger.log(
          'SubtitleTracksChangedEvent received: ${tracks.length} tracks, subtitlesEnabled=${getOptions().subtitlesEnabled}',
          tag: 'Controller',
        );
        if (getOptions().subtitlesEnabled) {
          setValue(getValue().copyWith(subtitleTracks: tracks));
          _Logger.log('SubtitleTracksChangedEvent: updated value with ${tracks.length} tracks', tag: 'Controller');
          // Auto-select subtitle if configured
          final value = getValue();
          if (getOptions().showSubtitlesByDefault && tracks.isNotEmpty && value.selectedSubtitleTrack == null) {
            trackManager.autoSelectSubtitle(tracks);
          }
        }

      case SelectedSubtitleChangedEvent(:final track):
        if (getOptions().subtitlesEnabled) {
          setValue(getValue().copyWith(selectedSubtitleTrack: track, clearSelectedSubtitle: track == null));
          // Extract embedded subtitles for Flutter rendering when track is selected
          // This handles both user selection and native auto-selection
          if (track != null) {
            trackManager.extractEmbeddedSubtitlesIfNeeded(track);
          }
        }

      case PipStateChangedEvent(:final isActive):
        setValue(getValue().copyWith(isPipActive: isActive));

      case PipActionTriggeredEvent(:final action):
        // PiP action events are handled via the events stream
        // Apps can listen to this event to perform custom actions
        _Logger.log('PiP action triggered: $action', tag: 'Controller');

      case PipRestoreUserInterfaceEvent():
        // User requested to return from PiP to the app
        // This is exposed via events stream for the app to handle UI restoration
        _Logger.log('PiP restore user interface requested', tag: 'Controller');

      case FullscreenStateChangedEvent(:final isFullscreen):
        setValue(getValue().copyWith(isFullscreen: isFullscreen));

      case BackgroundPlaybackChangedEvent(:final isEnabled):
        setValue(getValue().copyWith(isBackgroundPlaybackEnabled: isEnabled));

      case BandwidthEstimateChangedEvent(:final bandwidth):
        setValue(getValue().copyWith(estimatedBandwidth: bandwidth));

      case PlaybackSpeedChangedEvent(:final speed):
        setValue(getValue().copyWith(playbackSpeed: speed));

      case VolumeChangedEvent(:final volume):
        setValue(getValue().copyWith(volume: volume));

      case AudioTracksChangedEvent(:final tracks):
        _Logger.log('AudioTracksChangedEvent received: ${tracks.length} tracks', tag: 'Controller');
        setValue(getValue().copyWith(audioTracks: tracks));
        _Logger.log('AudioTracksChangedEvent: updated value with ${tracks.length} tracks', tag: 'Controller');

      case SelectedAudioChangedEvent(:final track):
        setValue(getValue().copyWith(selectedAudioTrack: track, clearSelectedAudio: track == null));

      case VideoQualityTracksChangedEvent(:final tracks):
        setValue(getValue().copyWith(qualityTracks: tracks));

      case SelectedQualityChangedEvent(:final track):
        setValue(getValue().copyWith(selectedQualityTrack: track, clearSelectedQuality: track.isAuto));

      case MetadataChangedEvent(:final title):
        setValue(getValue().copyWith(title: title));

      case PlaylistTrackChangedEvent(:final index):
        // Platform implementation changed track - update state
        setValue(getValue().copyWith(playlistIndex: index));

      case PlaylistEndedEvent():
        // Playlist ended - no action needed, state already updated
        break;

      // Network resilience events
      case BufferingStartedEvent(:final reason):
        _Logger.log('Buffering started: $reason', tag: 'Controller');
        setValue(
          getValue().copyWith(
            isNetworkBuffering: true,
            bufferingReason: reason,
            playbackState: PlaybackState.buffering,
          ),
        );

      case BufferingEndedEvent():
        _Logger.log('Buffering ended', tag: 'Controller');
        errorRecoveryManager.cancelRetryTimer();
        setRetrying(isRetrying: false);
        setValue(getValue().copyWith(isNetworkBuffering: false, clearBufferingReason: true));

      case NetworkErrorEvent(:final message):
        _Logger.log('Network error: $message', tag: 'Controller');
        errorRecoveryManager.handleNetworkError(message);

      case PlaybackRecoveredEvent(:final retriesUsed):
        _Logger.log('Playback recovered after $retriesUsed retries', tag: 'Controller');
        errorRecoveryManager.cancelRetryTimer();
        setRetrying(isRetrying: false);
        setValue(
          getValue().copyWith(
            networkRetryCount: 0,
            isRecoveringFromError: false,
            isNetworkBuffering: false,
            clearBufferingReason: true,
          ),
        );

      case NetworkStateChangedEvent(:final isConnected):
        _Logger.log('Network state changed: connected=$isConnected', tag: 'Controller');
        errorRecoveryManager.handleNetworkStateChange(isConnected: isConnected);

      case VideoMetadataExtractedEvent(:final metadata):
        setValue(getValue().copyWith(videoMetadata: metadata));

      case CastStateChangedEvent(:final state, :final device):
        setValue(
          getValue().copyWith(castState: state, currentCastDevice: device, clearCurrentCastDevice: device == null),
        );

      case CastDevicesChangedEvent(:final devices):
        setValue(getValue().copyWith(availableCastDevices: devices));

      // Chapter events
      case ChaptersExtractedEvent(:final chapters):
        setValue(getValue().copyWith(chapters: chapters));
        // Update current chapter based on current position
        _updateCurrentChapter();

      case CurrentChapterChangedEvent(:final chapter):
        setValue(getValue().copyWith(currentChapter: chapter, clearCurrentChapter: chapter == null));

      case EmbeddedSubtitleCueEvent(:final cue):
        setValue(getValue().copyWith(currentEmbeddedCue: cue, clearCurrentEmbeddedCue: cue == null));
    }
  }

  /// Updates the current chapter based on the current playback position.
  void _updateCurrentChapter() {
    final value = getValue();
    if (value.chapters.isEmpty) return;

    final position = value.position;
    Chapter? activeChapter;

    // Find the chapter that contains the current position
    for (final chapter in value.chapters) {
      if (chapter.isActiveAt(position)) {
        activeChapter = chapter;
        break;
      }
    }

    // Only update if chapter changed
    if (activeChapter != value.currentChapter) {
      setValue(getValue().copyWith(currentChapter: activeChapter, clearCurrentChapter: activeChapter == null));
    }
  }

  /// Disposes the event coordinator and cancels subscriptions.
  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    _eventSubscription = null;
  }
}
