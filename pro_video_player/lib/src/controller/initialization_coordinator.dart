import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

import 'controller_services.dart';

// Alias for cleaner code
typedef _Logger = ProVideoPlayerLogger;

/// Coordinates the initialization of all manager instances.
///
/// This class encapsulates the creation and wiring of all specialized managers,
/// ensuring they're initialized with the correct dependencies and in the right order.
class InitializationCoordinator {
  /// Creates an initialization coordinator.
  InitializationCoordinator({
    required this.getValue,
    required this.setValue,
    required this.getPlayerId,
    required this.getOptions,
    required this.isDisposed,
    required this.isRetrying,
    required this.setRetrying,
    required this.platform,
    required this.errorRecoveryOptions,
    required this.ensureInitialized,
    required this.onRetry,
    required this.onPlay,
    required this.onSeekTo,
  });

  /// Callback to get current player value.
  final VideoPlayerValue Function() getValue;

  /// Callback to update player value.
  final void Function(VideoPlayerValue) setValue;

  /// Callback to get current player ID.
  final int? Function() getPlayerId;

  /// Callback to get current player options.
  final VideoPlayerOptions Function() getOptions;

  /// Callback to check if controller is disposed.
  final bool Function() isDisposed;

  /// Callback to check if controller is retrying.
  final bool Function() isRetrying;

  /// Callback to set retrying state.
  final void Function({required bool isRetrying}) setRetrying;

  /// Platform instance for making platform calls.
  final ProVideoPlayerPlatform platform;

  /// Error recovery options.
  final ErrorRecoveryOptions errorRecoveryOptions;

  /// Callback to ensure controller is initialized.
  final void Function() ensureInitialized;

  /// Callback to retry playback.
  final Future<void> Function() onRetry;

  /// Callback to start playback.
  final Future<void> Function() onPlay;

  /// Callback to seek to a position.
  final Future<void> Function(Duration) onSeekTo;

  /// Handles the complete initialization flow including source handling.
  ///
  /// This method orchestrates the entire initialization process:
  /// - Handles playlist sources (loading and converting)
  /// - Creates the platform player
  /// - Initializes all managers
  /// - Subscribes to events
  /// - Handles auto-play and auto-subtitle discovery
  Future<InitializationResult> initializeWithSource({
    required VideoSource source,
    required VideoPlayerOptions options,
    required void Function(VideoSource) setSource,
    required VideoSource? Function() getSource,
    required void Function(VideoPlayerOptions) setOptions,
    required void Function(int?) setPlayerId,
  }) async {
    // Handle playlist video sources
    if (source is PlaylistVideoSource) {
      _Logger.log('Loading playlist from URL: ${source.url}', tag: 'InitCoordinator');

      try {
        final loader = PlaylistLoader();
        final result = await loader.loadAndConvert(source);

        if (result is Playlist) {
          // It's a multi-video playlist - return for playlist initialization
          _Logger.log('Playlist loaded with ${result.length} items', tag: 'InitCoordinator');
          return InitializationResult.playlist(result, options);
        } else if (result is VideoSource) {
          // It's an HLS adaptive stream, treat as single video
          _Logger.log('Detected HLS adaptive stream, treating as single video', tag: 'InitCoordinator');
          source = result;
        } else {
          throw Exception('Invalid playlist result type');
        }
      } catch (e) {
        _Logger.error('Failed to load playlist', tag: 'InitCoordinator', error: e);
        rethrow;
      }
    }

    // Store source and options
    setSource(source);
    setOptions(options);

    // Update state to initializing
    setValue(getValue().copyWith(playbackState: PlaybackState.initializing, clearError: true));

    try {
      // Create platform player
      final playerId = await platform.create(source: source, options: options);
      _Logger.log('Player created with ID: $playerId', tag: 'InitCoordinator');
      setPlayerId(playerId);

      // Notify that player is created (allows UI to show player view)
      setValue(getValue().copyWith(playbackState: PlaybackState.buffering));

      // Initialize all managers using the service container
      final services = ControllerServices.create(
        platform: platform,
        errorRecoveryOptions: errorRecoveryOptions,
        getValue: getValue,
        setValue: setValue,
        getPlayerId: getPlayerId,
        getOptions: getOptions,
        isDisposed: isDisposed,
        isRetrying: isRetrying,
        setRetrying: setRetrying,
        setPlayerId: setPlayerId,
        setSource: setSource,
        getSource: getSource,
        ensureInitialized: ensureInitialized,
        onRetry: onRetry,
        onPlay: onPlay,
        onSeekTo: onSeekTo,
      );

      // Don't subscribe to events here - subscription happens lazily when needed
      // This prevents test hanging issues with ValueListenableBuilder widgets

      // Update state to ready
      setValue(
        getValue().copyWith(
          playbackState: PlaybackState.ready,
          playbackSpeed: options.playbackSpeed,
          volume: options.volume,
          isLooping: options.looping,
          currentSubtitleRenderMode: options.subtitleRenderMode,
        ),
      );

      _Logger.log('Player initialized successfully', tag: 'InitCoordinator');

      // Auto-discover subtitles for local file sources
      if (options.autoDiscoverSubtitles && options.subtitlesEnabled && source is FileVideoSource) {
        await services.subtitleManager.discoverAndAddSubtitles(source.path, options.subtitleDiscoveryMode);
      }

      return InitializationResult.complete(services, autoPlay: options.autoPlay);
    } catch (e) {
      _Logger.error('Failed to initialize player', tag: 'InitCoordinator', error: e);
      setValue(getValue().copyWith(playbackState: PlaybackState.error, errorMessage: e.toString()));
      rethrow;
    }
  }
}

/// Result of initialization, indicating whether it completed or needs playlist handling.
class InitializationResult {
  const InitializationResult._({this.services, this.playlist, this.options, this.autoPlay = false});

  /// Initialization completed successfully.
  factory InitializationResult.complete(ControllerServices services, {bool autoPlay = false}) =>
      InitializationResult._(services: services, autoPlay: autoPlay);

  /// Loaded a playlist that needs playlist-specific initialization.
  factory InitializationResult.playlist(Playlist playlist, VideoPlayerOptions options) =>
      InitializationResult._(playlist: playlist, options: options);

  /// Service container instance (null if this is a playlist result).
  final ControllerServices? services;

  /// Playlist instance (null if this is a complete result).
  final Playlist? playlist;

  /// Video player options (null if this is a complete result).
  final VideoPlayerOptions? options;

  /// Whether auto-play is enabled.
  final bool autoPlay;

  /// Whether this result represents a playlist that needs handling.
  bool get isPlaylist => playlist != null;

  /// Whether this result represents completed initialization.
  bool get isComplete => services != null;
}
