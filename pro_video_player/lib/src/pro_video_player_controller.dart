import 'dart:io';
import 'dart:typed_data';

import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

import 'controller/controller_base.dart';
import 'controller/controller_services.dart';
import 'controller/initialization_coordinator.dart';
import 'controller/mixins/casting_mixin.dart';
import 'controller/mixins/compatibility_mixin.dart';
import 'controller/mixins/configuration_mixin.dart';
import 'controller/mixins/device_controls_mixin.dart';
import 'controller/mixins/error_recovery_mixin.dart';
import 'controller/mixins/fullscreen_mixin.dart';
import 'controller/mixins/metadata_mixin.dart';
import 'controller/mixins/pip_mixin.dart';
import 'controller/mixins/platform_capabilities_mixin.dart';
import 'controller/mixins/playback_mixin.dart';
import 'controller/mixins/playlist_mixin.dart';
import 'controller/mixins/tracks_mixin.dart';

// Alias for cleaner code
typedef _Logger = ProVideoPlayerLogger;

/// Controller for a video player instance.
///
/// Create a controller using named constructors (`network`, `file`, `asset`),
/// then call [initialize] to load the video. Use [play], [pause], [seekTo],
/// etc. to control playback.
///
/// Remember to call [dispose] when done to release resources.
///
/// Example (video_player compatible style):
/// ```dart
/// final controller = ProVideoPlayerController.network(
///   'https://example.com/video.mp4',
/// );
/// await controller.initialize();
/// await controller.play();
/// // ...
/// await controller.dispose();
/// ```
///
/// Advanced example (custom source):
/// ```dart
/// final controller = ProVideoPlayerController();
/// await controller.initialize(
///   source: VideoSource.network('https://example.com/video.mp4'),
///   options: VideoPlayerOptions(autoPlay: true),
/// );
/// ```
class ProVideoPlayerController extends ProVideoPlayerControllerBase
    with
        PlaybackMixin,
        TracksMixin,
        PipMixin,
        FullscreenMixin,
        CastingMixin,
        PlaylistMixin,
        PlatformCapabilitiesMixin,
        CompatibilityMixin,
        ConfigurationMixin,
        MetadataMixin,
        DeviceControlsMixin,
        ErrorRecoveryMixin {
  /// Creates a new video player controller.
  ///
  /// For compatibility with the video_player library, prefer using named
  /// constructors: `network`, `file`, or `asset`.
  ///
  /// Optionally pass [errorRecoveryOptions] to configure automatic error
  /// recovery behavior. By default, automatic retry is enabled for network
  /// and timeout errors.
  ProVideoPlayerController({ErrorRecoveryOptions errorRecoveryOptions = ErrorRecoveryOptions.defaultOptions})
    : _errorRecoveryOptions = errorRecoveryOptions,
      _initialSource = null,
      _initialOptions = null;

  /// Creates a video player controller for a network video.
  ///
  /// This constructor is compatible with Flutter's video_player library.
  ///
  /// The [dataSource] is the URL of the video. Optional [httpHeaders] can be
  /// provided for authenticated content. Optional [videoPlayerOptions] can be
  /// provided to configure player behavior.
  ///
  /// Call [initialize] after construction to load the video.
  ProVideoPlayerController.network(
    String dataSource, {
    Map<String, String>? httpHeaders,
    VideoPlayerOptions? videoPlayerOptions,
    ErrorRecoveryOptions errorRecoveryOptions = ErrorRecoveryOptions.defaultOptions,
  }) : _errorRecoveryOptions = errorRecoveryOptions,
       _initialSource = VideoSource.network(dataSource, headers: httpHeaders),
       _initialOptions = videoPlayerOptions;

  /// Creates a video player controller for a local file.
  ///
  /// This constructor is compatible with Flutter's video_player library.
  ///
  /// The [file] is the local video file. Optional [videoPlayerOptions] can be
  /// provided to configure player behavior.
  ///
  /// Call [initialize] after construction to load the video.
  ProVideoPlayerController.file(
    File file, {
    VideoPlayerOptions? videoPlayerOptions,
    ErrorRecoveryOptions errorRecoveryOptions = ErrorRecoveryOptions.defaultOptions,
  }) : _errorRecoveryOptions = errorRecoveryOptions,
       _initialSource = VideoSource.file(file.path),
       _initialOptions = videoPlayerOptions;

  /// Creates a video player controller for an asset video.
  ///
  /// This constructor is compatible with Flutter's video_player library.
  ///
  /// The [dataSource] is the asset path (e.g., 'assets/video.mp4'). Optional
  /// [package] can be specified for assets from packages. Optional
  /// [videoPlayerOptions] can be provided to configure player behavior.
  ///
  /// Call [initialize] after construction to load the video.
  ProVideoPlayerController.asset(
    String dataSource, {
    String? package,
    VideoPlayerOptions? videoPlayerOptions,
    ErrorRecoveryOptions errorRecoveryOptions = ErrorRecoveryOptions.defaultOptions,
  }) : _errorRecoveryOptions = errorRecoveryOptions,
       _initialSource = VideoSource.asset(package != null ? 'packages/$package/$dataSource' : dataSource),
       _initialOptions = videoPlayerOptions;

  int? _playerId;
  VideoSource? _source;
  VideoPlayerOptions _options = const VideoPlayerOptions();
  final ErrorRecoveryOptions _errorRecoveryOptions;
  final VideoSource? _initialSource;
  final VideoPlayerOptions? _initialOptions;
  late ControllerServices _services;
  bool _isDisposed = false;
  bool _isRetrying = false;

  // ==================== Static Methods ====================

  /// Extracts video metadata from a source without initializing a full player.
  ///
  /// This is useful for:
  /// - Showing video info (duration, resolution) in file browsers
  /// - Validating video files before playback
  /// - Pre-loading metadata for better UX
  ///
  /// Uses lightweight platform-specific APIs:
  /// - **iOS/macOS**: `AVURLAsset.loadValuesAsynchronously`
  /// - **Android**: `MediaMetadataRetriever` for local files, temporary ExoPlayer for network
  /// - **Web**: Temporary video element with `loadedmetadata` event
  ///
  /// The [timeout] parameter specifies the maximum time to wait for metadata
  /// extraction. Defaults to 30 seconds. For local files, timeout may not apply.
  ///
  /// Throws [MetadataExtractionException] if extraction fails (network error,
  /// invalid source, timeout, unsupported format).
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final metadata = await ProVideoPlayerController.extractMetadata(
  ///     VideoSource.file('/path/to/video.mp4'),
  ///   );
  ///   print('Duration: ${metadata.duration}');
  ///   print('Resolution: ${metadata.resolution}');
  ///   print('Codec: ${metadata.videoCodec}');
  /// } on MetadataExtractionException catch (e) {
  ///   print('Failed: ${e.code} - ${e.message}');
  /// }
  /// ```
  static Future<VideoMetadata> extractMetadata(VideoSource source, {Duration timeout = const Duration(seconds: 30)}) =>
      ProVideoPlayerPlatform.instance.extractMetadata(source, timeout: timeout);

  /// Extracts embedded artwork/thumbnail from video container metadata.
  ///
  /// Returns the image bytes (JPEG/PNG) if embedded artwork exists in the
  /// video container, null otherwise. Does not decode video frames - only
  /// reads pre-existing artwork stored in the container metadata.
  ///
  /// This is useful for:
  /// - Displaying video thumbnails in file browsers
  /// - Showing album art for music videos
  /// - Preview images for movie files from iTunes
  ///
  /// Common sources of embedded artwork:
  /// - iTunes movies (MP4/M4V with cover art)
  /// - MKV files with cover attachments
  /// - Music videos with album art
  ///
  /// Note: This only returns embedded artwork. Most videos (especially
  /// user-recorded or streaming content) do not have embedded artwork.
  ///
  /// Example:
  /// ```dart
  /// final artwork = await ProVideoPlayerController.extractEmbeddedArtwork(
  ///   VideoSource.file('/path/to/movie.m4v'),
  /// );
  /// if (artwork != null) {
  ///   // Display as image
  ///   Image.memory(artwork);
  /// }
  /// ```
  static Future<Uint8List?> extractEmbeddedArtwork(VideoSource source) =>
      ProVideoPlayerPlatform.instance.extractEmbeddedArtwork(source);

  /// Extracts a video frame at the specified position as an image.
  ///
  /// Returns the image bytes (JPEG) of the video frame at [position].
  /// If [position] is Duration.zero, extracts the first available frame.
  ///
  /// Optional parameters:
  /// - [maxWidth]: Maximum width of the output image (maintains aspect ratio)
  /// - [maxHeight]: Maximum height of the output image (maintains aspect ratio)
  /// - [quality]: JPEG quality (0-100, default 80)
  static Future<Uint8List?> extractVideoFrame(
    VideoSource source, {
    Duration position = Duration.zero,
    int? maxWidth,
    int? maxHeight,
    int? quality,
  }) => ProVideoPlayerPlatform.instance.extractVideoFrame(
    source,
    position: position,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    quality: quality,
  );

  /// Extracts a thumbnail from a video source.
  ///
  /// This method first tries to extract embedded artwork from the video
  /// container metadata. If no embedded artwork is found, it falls back to
  /// extracting a video frame at the specified position.
  ///
  /// This is the recommended method for getting video thumbnails as it:
  /// 1. Returns high-quality embedded artwork when available (iTunes movies, etc.)
  /// 2. Falls back to frame extraction for videos without embedded artwork
  ///
  /// Parameters:
  /// - [source]: The video source to extract thumbnail from
  /// - [position]: Position for frame extraction fallback (default: first frame)
  /// - [maxWidth]: Maximum width of the output image
  /// - [maxHeight]: Maximum height of the output image
  /// - [quality]: JPEG quality for frame extraction (0-100, default 80)
  ///
  /// Example:
  /// ```dart
  /// final thumbnail = await ProVideoPlayerController.extractThumbnail(
  ///   VideoSource.file('/path/to/video.mp4'),
  ///   maxWidth: 320,
  ///   maxHeight: 180,
  /// );
  /// if (thumbnail != null) {
  ///   Image.memory(thumbnail);
  /// }
  /// ```
  static Future<Uint8List?> extractThumbnail(
    VideoSource source, {
    Duration position = Duration.zero,
    int? maxWidth,
    int? maxHeight,
    int? quality,
  }) => ProVideoPlayerPlatform.instance.extractThumbnail(
    source,
    position: position,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    quality: quality,
  );

  /// Extracts a content-based fingerprint for video deduplication.
  ///
  /// This method reads 8KB samples from 3 positions in the video file
  /// (beginning, middle, and end) and computes a SHA-256 hash of the combined
  /// samples. This fingerprint can distinguish trimmed or edited versions of
  /// the same video that would have identical metadata.
  ///
  /// Returns a [ContentFingerprint] containing:
  /// - [ContentFingerprint.fingerprint]: The SHA-256 hash as a hex string
  /// - [ContentFingerprint.fileSize]: The file size in bytes
  ///
  /// For comprehensive deduplication, combine this with [VideoMetadata.metadataFingerprint]:
  /// ```dart
  /// final metadata = await ProVideoPlayerController.extractMetadata(source);
  /// final content = await ProVideoPlayerController.extractContentFingerprint(source);
  /// final combined = '${metadata.metadataFingerprint}-${content.fingerprint}';
  /// ```
  ///
  /// Platform implementations:
  /// - **Local files**: Direct file reads with 8KB at start, middle, and end
  /// - **Network URLs**: HTTP Range requests (may not be supported by all servers)
  /// - **Assets**: AssetManager reads
  ///
  /// Throws [ContentFingerprintException] if extraction fails (e.g., file not found,
  /// network error, or server doesn't support Range requests).
  static Future<ContentFingerprint> extractContentFingerprint(VideoSource source) =>
      ProVideoPlayerPlatform.instance.extractContentFingerprint(source);

  // ==================== Base Class Overrides ====================

  @override
  ControllerServices get services => _services;

  @override
  VideoSource? get sourceInternal => _source;

  @override
  int? get playerId => _playerId;

  @override
  VideoPlayerOptions get options => _options;

  @override
  bool get isDisposed => _isDisposed;

  @override
  bool get isRetryingInternal => _isRetrying;

  @override
  set isRetryingInternal(bool value) => _isRetrying = value;

  @override
  void ensureInitializedInternal() => _ensureInitialized();

  @override
  ErrorRecoveryOptions get errorRecoveryOptions => _errorRecoveryOptions;

  // ==================== Public Properties ====================

  /// The current video source, or null if not initialized.
  VideoSource? get source => _source;

  /// Whether the player has been initialized.
  bool get isInitialized => _playerId != null && value.isInitialized;

  // ==================== Initialization ====================

  /// Initializes the video player with the given [source].
  ///
  /// For controllers created with named constructors (`network`, `file`,
  /// `asset`), the source is optional and will use the source provided in
  /// the constructor.
  ///
  /// Must be called before any other methods.
  /// Throws [StateError] if already initialized, disposed, or if no source
  /// is provided and none was set in the constructor.
  Future<void> initialize({VideoSource? source, VideoPlayerOptions? options}) async {
    if (_isDisposed) {
      throw StateError('Cannot initialize a disposed controller');
    }
    if (_playerId != null) {
      throw StateError('Controller is already initialized');
    }

    // Use constructor source/options if not explicitly provided
    final effectiveSource = source ?? _initialSource;
    final effectiveOptions = options ?? _initialOptions ?? const VideoPlayerOptions();

    if (effectiveSource == null) {
      throw StateError(
        'No source provided. Either pass a source to initialize() or use a '
        'named constructor (network, file, asset).',
      );
    }

    _Logger.log(
      'Initializing player with source: ${effectiveSource.runtimeType}, autoPlay: ${effectiveOptions.autoPlay}',
      tag: 'Controller',
    );

    // Create initialization coordinator
    final coordinator = InitializationCoordinator(
      getValue: () => value,
      setValue: (v) => value = v,
      getPlayerId: () => _playerId,
      getOptions: () => _options,
      isDisposed: () => _isDisposed,
      isRetrying: () => _isRetrying,
      setRetrying: ({required isRetrying}) => _isRetrying = isRetrying,
      platform: platform,
      errorRecoveryOptions: _errorRecoveryOptions,
      ensureInitialized: _ensureInitialized,
      onRetry: _performRetryPlayback,
      onPlay: play,
      onSeekTo: seekTo,
    );

    // Delegate to coordinator for full initialization
    final result = await coordinator.initializeWithSource(
      source: effectiveSource,
      options: effectiveOptions,
      setSource: (s) => _source = s,
      getSource: () => _source,
      setOptions: (o) => _options = o,
      setPlayerId: (id) => _playerId = id,
    );

    // Handle result
    if (result.isPlaylist) {
      // Loaded a playlist - delegate to playlist initialization
      return initializeWithPlaylist(playlist: result.playlist!, options: result.options!);
    }

    // Complete initialization - store services
    _services = result.services!;

    // Subscribe to platform events
    _services.eventCoordinator.subscribeToEvents();

    // Auto-play if requested (after managers are stored)
    if (result.autoPlay) {
      _Logger.log('Auto-playing video', tag: 'Controller');
      value = value.copyWith(playbackState: PlaybackState.playing);
      await play();
    }
  }

  /// Initializes the player with a playlist.
  ///
  /// The playlist will start playing from [Playlist.initialIndex].
  Future<void> initializeWithPlaylist({
    required Playlist playlist,
    VideoPlayerOptions options = const VideoPlayerOptions(),
  }) async {
    if (_isDisposed) throw StateError('Cannot perform operation on disposed controller');
    _Logger.log('Initializing with playlist (${playlist.length} items)', tag: 'Controller');

    _options = options;

    // Initialize all managers using the service container
    _services = ControllerServices.create(
      platform: platform,
      errorRecoveryOptions: _errorRecoveryOptions,
      getValue: () => value,
      setValue: (v) => value = v,
      getPlayerId: () => _playerId,
      getOptions: () => _options,
      isDisposed: () => _isDisposed,
      isRetrying: () => _isRetrying,
      setRetrying: ({required isRetrying}) => _isRetrying = isRetrying,
      setPlayerId: (id) => _playerId = id,
      setSource: (s) => _source = s,
      getSource: () => _source,
      ensureInitialized: _ensureInitialized,
      onRetry: _performRetryPlayback,
      onPlay: play,
      onSeekTo: seekTo,
    );

    // Subscribe to events and initialize playlist
    _services.eventCoordinator.subscribeToEvents();
    await _services.playlistManager.initializeWithPlaylist(playlist: playlist, options: options);
  }

  // ==================== Error Recovery ====================

  @override
  Future<void> reinitialize() async {
    if (_isDisposed) {
      throw StateError('Cannot reinitialize a disposed controller');
    }
    if (_source == null) {
      throw StateError('Cannot reinitialize: no source available');
    }

    _Logger.log('Reinitializing player', tag: 'Controller');

    // Clean up existing player
    _services.errorRecovery.cancelRetryTimer();
    if (_playerId != null) {
      await _services.eventCoordinator.dispose();
    }

    if (_playerId != null) {
      try {
        await platform.dispose(_playerId!);
      } catch (e) {
        _Logger.error('Error disposing player during reinitialize', tag: 'Controller', error: e);
      }
      _playerId = null;
    }

    // Reset state
    value = const VideoPlayerValue();

    // Reinitialize with original source and options
    await initialize(source: _source, options: _options);
  }

  // ==================== Private Methods ====================

  void _ensureInitialized() {
    if (_isDisposed) {
      throw StateError('Controller has been disposed');
    }
    if (_playerId == null) {
      throw StateError('Controller has not been initialized');
    }
  }

  /// Performs the actual playback retry - called by ErrorRecoveryManager.
  Future<void> _performRetryPlayback() async {
    if (_isDisposed || _playerId == null) return;
    if (_isRetrying) return; // Prevent concurrent retries

    _isRetrying = true;
    _Logger.log('Attempting network recovery (retry ${value.networkRetryCount})', tag: 'Controller');

    try {
      // Seek to current position to trigger a reload
      final currentPosition = value.position;
      await platform.seekTo(_playerId!, currentPosition);

      // Try to resume playback
      await platform.play(_playerId!);
    } catch (e) {
      _Logger.log('Retry attempt failed: $e', tag: 'Controller');
      // The native layer will send another NetworkErrorEvent if it fails
    } finally {
      _isRetrying = false;
    }
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    // Only dispose if initialized (managers exist)
    if (_playerId != null) {
      // Dispose all managers
      await _services.dispose();

      // Dispose platform player
      await platform.dispose(_playerId!);
    }

    _playerId = null;
    value = value.copyWith(playbackState: PlaybackState.disposed);
    super.dispose();
  }
}
