import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

import 'casting_manager.dart';
import 'configuration_manager.dart';
import 'device_controls_manager.dart';
import 'error_recovery_manager.dart';
import 'event_coordinator.dart';
import 'fullscreen_manager.dart';
import 'metadata_manager.dart';
import 'pip_manager.dart';
import 'playback_manager.dart';
import 'playlist_manager.dart';
import 'subtitle_manager.dart';
import 'track_manager.dart';

/// Dependency injection container for all controller services.
///
/// Encapsulates all 12 manager instances and their complex dependency wiring,
/// providing a clean interface for ProVideoPlayerController.
///
/// This container is created during controller initialization and handles:
/// - Manager instantiation in correct dependency order
/// - Cross-manager dependency wiring (MetadataManager → PlaybackManager)
/// - Circular dependency resolution (PlaylistManager ↔ EventCoordinator)
/// - Lifecycle management (dispose)
///
/// Example usage:
/// ```dart
/// final services = ControllerServices.create(
///   platform: platform,
///   errorRecoveryOptions: options,
///   getValue: () => value,
///   setValue: (v) => value = v,
///   // ... other callbacks
/// );
///
/// // Access managers through services
/// await services.playbackManager.play();
/// await services.trackManager.setSubtitleTrack(track);
///
/// // Dispose all managers
/// services.dispose();
/// ```
class ControllerServices {
  ControllerServices._({
    required this.errorRecovery,
    required this.trackManager,
    required this.playbackManager,
    required this.metadataManager,
    required this.pipManager,
    required this.fullscreenManager,
    required this.castingManager,
    required this.deviceControlsManager,
    required this.subtitleManager,
    required this.configurationManager,
    required this.playlistManager,
    required this.eventCoordinator,
  });

  /// Error recovery manager instance.
  final ErrorRecoveryManager errorRecovery;

  /// Track manager instance.
  final TrackManager trackManager;

  /// Playback manager instance.
  final PlaybackManager playbackManager;

  /// Metadata manager instance.
  final MetadataManager metadataManager;

  /// PiP manager instance.
  final PipManager pipManager;

  /// Fullscreen manager instance.
  final FullscreenManager fullscreenManager;

  /// Casting manager instance.
  final CastingManager castingManager;

  /// Device controls manager instance.
  final DeviceControlsManager deviceControlsManager;

  /// Subtitle manager instance.
  final SubtitleManager subtitleManager;

  /// Configuration manager instance.
  final ConfigurationManager configurationManager;

  /// Playlist manager instance.
  final PlaylistManager playlistManager;

  /// Event coordinator instance.
  final EventCoordinator eventCoordinator;

  /// Factory method to create services with all dependencies wired.
  ///
  /// Creates all 12 managers in the correct dependency order:
  /// 1. Independent managers (no dependencies on other managers)
  /// 2. Cross-dependent managers (depend on other managers)
  /// 3. Circular dependency managers (depend on each other)
  /// 4. Resolves circular dependencies via late-binding callbacks
  ///
  /// All managers are created with the necessary callbacks to access
  /// controller state and perform controller operations.
  static ControllerServices create({
    required ProVideoPlayerPlatform platform,
    required ErrorRecoveryOptions errorRecoveryOptions,
    required VideoPlayerValue Function() getValue,
    required void Function(VideoPlayerValue) setValue,
    required int? Function() getPlayerId,
    required VideoPlayerOptions Function() getOptions,
    required bool Function() isDisposed,
    required bool Function() isRetrying,
    required void Function({required bool isRetrying}) setRetrying,
    required void Function(int?) setPlayerId,
    required void Function(VideoSource) setSource,
    required VideoSource? Function() getSource,
    required void Function() ensureInitialized,
    required Future<void> Function() onRetry,
    required Future<void> Function() onPlay,
    required Future<void> Function(Duration) onSeekTo,
  }) {
    // Phase 1: Create independent managers
    // These managers have no dependencies on other managers

    final errorRecovery = ErrorRecoveryManager(
      options: errorRecoveryOptions,
      getValue: getValue,
      setValue: setValue,
      isDisposed: isDisposed,
      getPlayerId: getPlayerId,
      platform: platform,
      onRetry: onRetry,
    );

    final trackManager = TrackManager(
      getValue: getValue,
      setValue: setValue,
      getPlayerId: getPlayerId,
      getOptions: getOptions,
      platform: platform,
      ensureInitialized: ensureInitialized,
      getSource: getSource,
    );

    final playbackManager = PlaybackManager(
      getValue: getValue,
      setValue: setValue,
      getPlayerId: getPlayerId,
      platform: platform,
      ensureInitialized: ensureInitialized,
    );

    final pipManager = PipManager(
      getPlayerId: getPlayerId,
      getOptions: getOptions,
      platform: platform,
      ensureInitialized: ensureInitialized,
    );

    final fullscreenManager = FullscreenManager(
      getValue: getValue,
      setValue: setValue,
      getPlayerId: getPlayerId,
      getOptions: getOptions,
      platform: platform,
      ensureInitialized: ensureInitialized,
    );

    final castingManager = CastingManager(
      getPlayerId: getPlayerId,
      getOptions: getOptions,
      platform: platform,
      ensureInitialized: ensureInitialized,
    );

    final deviceControlsManager = DeviceControlsManager(platform: platform, ensureInitialized: ensureInitialized);

    final subtitleManager = SubtitleManager(
      getPlayerId: getPlayerId,
      getOptions: getOptions,
      platform: platform,
      ensureInitialized: ensureInitialized,
    );

    final configurationManager = ConfigurationManager(
      getValue: getValue,
      setValue: setValue,
      getPlayerId: getPlayerId,
      platform: platform,
      ensureInitialized: ensureInitialized,
    );

    // Phase 2: Create managers with cross-manager dependencies
    // MetadataManager depends on PlaybackManager.seekTo

    final metadataManager = MetadataManager(
      getValue: getValue,
      getPlayerId: getPlayerId,
      platform: platform,
      ensureInitialized: ensureInitialized,
      onSeekTo: playbackManager.seekTo,
    );

    // Phase 3: Create managers with circular dependencies
    // PlaylistManager and EventCoordinator depend on each other

    final playlistManager = PlaylistManager(
      getValue: getValue,
      setValue: setValue,
      getOptions: getOptions,
      getPlayerId: getPlayerId,
      setPlayerId: setPlayerId,
      setSource: setSource,
      platform: platform,
      onPlay: onPlay,
    );

    final eventCoordinator = EventCoordinator(
      getValue: getValue,
      setValue: setValue,
      getPlayerId: getPlayerId,
      getOptions: getOptions,
      isDisposed: isDisposed,
      isRetrying: isRetrying,
      setRetrying: setRetrying,
      platform: platform,
      playbackManager: playbackManager,
      trackManager: trackManager,
      errorRecoveryManager: errorRecovery,
      playlistManager: playlistManager,
      onSeekTo: onSeekTo,
      onPlay: onPlay,
    );

    // Phase 4: Resolve circular dependency
    // Wire up the circular dependency via late-binding callback
    playlistManager.eventSubscriptionCallback = eventCoordinator.subscribeToEvents;

    return ControllerServices._(
      errorRecovery: errorRecovery,
      trackManager: trackManager,
      playbackManager: playbackManager,
      metadataManager: metadataManager,
      pipManager: pipManager,
      fullscreenManager: fullscreenManager,
      castingManager: castingManager,
      deviceControlsManager: deviceControlsManager,
      subtitleManager: subtitleManager,
      configurationManager: configurationManager,
      playlistManager: playlistManager,
      eventCoordinator: eventCoordinator,
    );
  }

  /// Disposes all managers that require cleanup.
  ///
  /// Called when the controller is disposed to clean up resources.
  /// Disposes managers in the correct order to avoid issues with
  /// dependencies.
  Future<void> dispose() async {
    await eventCoordinator.dispose();
    errorRecovery.dispose();
    playbackManager.dispose();
    playlistManager.dispose();
  }
}
