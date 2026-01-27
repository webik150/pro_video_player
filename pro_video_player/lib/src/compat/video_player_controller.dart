/// VideoPlayerController for video_player API compatibility.
///
/// This class provides the exact video_player API signature for compatibility.
/// Import via `package:pro_video_player/video_player_compat.dart` for drop-in replacement.
library;

import 'dart:async' show unawaited;
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart' as platform;

import '../pro_video_player_controller.dart' as pro;
import 'caption.dart';
import 'closed_caption_file.dart';
import 'compat_annotation.dart';
import 'duration_range.dart';
import 'enums.dart';
import 'video_player_options_compat.dart';
import 'video_player_value.dart';

/// A controller for a video player.
///
/// [video_player compatibility] This class matches the video_player API exactly.
/// It wraps [pro.ProVideoPlayerController] internally while exposing the
/// exact video_player API signature.
///
/// ## Usage
///
/// ```dart
/// // Create controller
/// final controller = VideoPlayerController.networkUrl(
///   Uri.parse('https://example.com/video.mp4'),
/// );
///
/// // Initialize
/// await controller.initialize();
///
/// // Control playback
/// await controller.play();
/// await controller.pause();
/// await controller.seekTo(Duration(seconds: 30));
///
/// // Dispose when done
/// await controller.dispose();
/// ```
///
/// ## Migration from video_player
///
/// Simply change your import:
/// ```dart
/// // Before
/// import 'package:video_player/video_player.dart';
///
/// // After
/// import 'package:pro_video_player/video_player_compat.dart';
/// ```
@videoPlayerCompat
class VideoPlayerController extends ValueNotifier<VideoPlayerValue> {
  /// Creates a video player controller for a network video using a URL.
  ///
  /// [video_player compatibility] This constructor matches video_player exactly.
  @videoPlayerCompat
  VideoPlayerController.networkUrl(
    Uri url, {
    VideoFormat? formatHint,
    Future<ClosedCaptionFile>? closedCaptionFile,
    VideoPlayerOptions? videoPlayerOptions,
    Map<String, String> httpHeaders = const <String, String>{},
    // ignore: avoid_unused_constructor_parameters
    VideoViewType viewType = VideoViewType.textureView,
  }) : _dataSource = url.toString(),
       _dataSourceType = DataSourceType.network,
       _formatHint = formatHint,
       _closedCaptionFile = closedCaptionFile,
       _httpHeaders = httpHeaders,
       _videoPlayerOptions = videoPlayerOptions,
       _package = null,
       super(const VideoPlayerValue.uninitialized()) {
    _proController = pro.ProVideoPlayerController.network(
      url.toString(),
      httpHeaders: httpHeaders.isEmpty ? null : httpHeaders,
      videoPlayerOptions: _convertOptions(videoPlayerOptions),
    );
  }

  /// Creates a video player controller for a network video using a string URL.
  ///
  /// [video_player compatibility] This constructor matches video_player exactly.
  /// This constructor is deprecated in video_player, prefer `networkUrl`.
  @Deprecated('Use VideoPlayerController.networkUrl instead')
  @videoPlayerCompat
  VideoPlayerController.network(
    String dataSource, {
    VideoFormat? formatHint,
    Future<ClosedCaptionFile>? closedCaptionFile,
    VideoPlayerOptions? videoPlayerOptions,
    Map<String, String> httpHeaders = const <String, String>{},
    // ignore: avoid_unused_constructor_parameters
    VideoViewType viewType = VideoViewType.textureView,
  }) : _dataSource = dataSource,
       _dataSourceType = DataSourceType.network,
       _formatHint = formatHint,
       _closedCaptionFile = closedCaptionFile,
       _httpHeaders = httpHeaders,
       _videoPlayerOptions = videoPlayerOptions,
       _package = null,
       super(const VideoPlayerValue.uninitialized()) {
    _proController = pro.ProVideoPlayerController.network(
      dataSource,
      httpHeaders: httpHeaders.isEmpty ? null : httpHeaders,
      videoPlayerOptions: _convertOptions(videoPlayerOptions),
    );
  }

  /// Creates a video player controller for a local file.
  ///
  /// [video_player compatibility] This constructor matches video_player exactly.
  @videoPlayerCompat
  VideoPlayerController.file(
    File file, {
    Future<ClosedCaptionFile>? closedCaptionFile,
    VideoPlayerOptions? videoPlayerOptions,
    Map<String, String> httpHeaders = const <String, String>{},
    // ignore: avoid_unused_constructor_parameters
    VideoViewType viewType = VideoViewType.textureView,
  }) : _dataSource = file.path,
       _dataSourceType = DataSourceType.file,
       _formatHint = null,
       _closedCaptionFile = closedCaptionFile,
       _httpHeaders = httpHeaders,
       _videoPlayerOptions = videoPlayerOptions,
       _package = null,
       super(const VideoPlayerValue.uninitialized()) {
    _proController = pro.ProVideoPlayerController.file(file, videoPlayerOptions: _convertOptions(videoPlayerOptions));
  }

  /// Creates a video player controller for an asset.
  ///
  /// [video_player compatibility] This constructor matches video_player exactly.
  @videoPlayerCompat
  VideoPlayerController.asset(
    String dataSource, {
    String? package,
    Future<ClosedCaptionFile>? closedCaptionFile,
    VideoPlayerOptions? videoPlayerOptions,
    // ignore: avoid_unused_constructor_parameters
    VideoViewType viewType = VideoViewType.textureView,
  }) : _dataSource = dataSource,
       _dataSourceType = DataSourceType.asset,
       _formatHint = null,
       _closedCaptionFile = closedCaptionFile,
       _httpHeaders = const <String, String>{},
       _videoPlayerOptions = videoPlayerOptions,
       _package = package,
       super(const VideoPlayerValue.uninitialized()) {
    _proController = pro.ProVideoPlayerController.asset(
      dataSource,
      package: package,
      videoPlayerOptions: _convertOptions(videoPlayerOptions),
    );
  }

  /// Creates a video player controller for an Android content URI.
  ///
  /// [video_player compatibility] This constructor matches video_player exactly.
  @videoPlayerCompat
  VideoPlayerController.contentUri(
    Uri contentUri, {
    Future<ClosedCaptionFile>? closedCaptionFile,
    VideoPlayerOptions? videoPlayerOptions,
    // ignore: avoid_unused_constructor_parameters
    VideoViewType viewType = VideoViewType.textureView,
  }) : _dataSource = contentUri.toString(),
       _dataSourceType = DataSourceType.contentUri,
       _formatHint = null,
       _closedCaptionFile = closedCaptionFile,
       _httpHeaders = const <String, String>{},
       _videoPlayerOptions = videoPlayerOptions,
       _package = null,
       super(const VideoPlayerValue.uninitialized()) {
    // For content URIs, use file constructor with the URI path
    _proController = pro.ProVideoPlayerController.file(
      File(contentUri.toString()),
      videoPlayerOptions: _convertOptions(videoPlayerOptions),
    );
  }

  /// Internal pro_video_player controller.
  late final pro.ProVideoPlayerController _proController;

  /// Stored closed caption file for caption auto-update.
  Future<ClosedCaptionFile>? _closedCaptionFile;

  /// Parsed captions for position-based lookup.
  List<Caption>? _parsedCaptions;

  /// Current caption index for efficient lookup.
  int _currentCaptionIndex = -1;

  // Store constructor parameters for later access
  final String? _dataSource;
  final DataSourceType _dataSourceType;
  final VideoFormat? _formatHint;
  final Map<String, String> _httpHeaders;
  final VideoPlayerOptions? _videoPlayerOptions;
  final String? _package;

  /// Converts compatibility options to pro_video_player options.
  platform.VideoPlayerOptions? _convertOptions(VideoPlayerOptions? options) {
    if (options == null) return null;
    return platform.VideoPlayerOptions(
      mixWithOthers: options.mixWithOthers,
      allowBackgroundPlayback: options.allowBackgroundPlayback,
    );
  }

  /// Converts pro_video_player value to compatibility value.
  VideoPlayerValue _convertValue(platform.VideoPlayerValue proValue) {
    // Get the current caption based on position
    final caption = _getCaptionAtPosition(proValue.position);

    // Convert buffered ranges
    final buffered = proValue.buffered.map((range) => DurationRange(range.start, range.end)).toList();

    return VideoPlayerValue(
      duration: proValue.duration,
      size: proValue.size != null ? Size(proValue.size!.width.toDouble(), proValue.size!.height.toDouble()) : Size.zero,
      position: proValue.position,
      caption: caption,
      captionOffset: proValue.subtitleOffset,
      buffered: buffered,
      isInitialized: proValue.isInitialized,
      isPlaying: proValue.isPlaying,
      isLooping: proValue.isLooping,
      isBuffering: proValue.isBuffering,
      volume: proValue.volume,
      playbackSpeed: proValue.playbackSpeed,
      errorDescription: proValue.errorMessage,
    );
  }

  /// Gets the caption at the given position.
  Caption _getCaptionAtPosition(Duration position) {
    final captions = _parsedCaptions;
    if (captions == null || captions.isEmpty) {
      return Caption.none;
    }

    // Optimized: Start search from current index
    final startIndex = _currentCaptionIndex >= 0 ? _currentCaptionIndex : 0;

    // Check if current caption is still valid
    if (_currentCaptionIndex >= 0 && _currentCaptionIndex < captions.length) {
      final current = captions[_currentCaptionIndex];
      if (position >= current.start && position < current.end) {
        return current;
      }
    }

    // Search forward first (most common case during playback)
    for (var i = startIndex; i < captions.length; i++) {
      final caption = captions[i];
      if (position >= caption.start && position < caption.end) {
        _currentCaptionIndex = i;
        return caption;
      }
      // If we've passed this caption's start time, keep going
      if (position < caption.start) break;
    }

    // Search backward (in case of seek backward)
    for (var i = startIndex - 1; i >= 0; i--) {
      final caption = captions[i];
      if (position >= caption.start && position < caption.end) {
        _currentCaptionIndex = i;
        return caption;
      }
    }

    _currentCaptionIndex = -1;
    return Caption.none;
  }

  // ==================== Properties ====================

  /// The data source URL or path.
  ///
  /// [video_player compatibility] This property matches video_player exactly.
  @videoPlayerCompat
  String get dataSource => _dataSource ?? '';

  /// The type of data source.
  ///
  /// [video_player compatibility] This property matches video_player exactly.
  @videoPlayerCompat
  DataSourceType get dataSourceType => _dataSourceType;

  /// The format hint for the video.
  ///
  /// [video_player compatibility] This property matches video_player exactly.
  @videoPlayerCompat
  VideoFormat? get formatHint => _formatHint;

  /// HTTP headers for network requests.
  ///
  /// [video_player compatibility] This property matches video_player exactly.
  @videoPlayerCompat
  Map<String, String> get httpHeaders => _httpHeaders;

  /// The video player options.
  ///
  /// [video_player compatibility] This property matches video_player exactly.
  @videoPlayerCompat
  VideoPlayerOptions? get videoPlayerOptions => _videoPlayerOptions;

  /// The package name for asset videos.
  ///
  /// [video_player compatibility] This property matches video_player exactly.
  @videoPlayerCompat
  String? get package => _package;

  /// The closed caption file, if any.
  ///
  /// [video_player compatibility] This property matches video_player exactly.
  @videoPlayerCompat
  Future<ClosedCaptionFile>? get closedCaptionFile => _closedCaptionFile;

  /// The unique ID of this player instance.
  ///
  /// [video_player compatibility] This property matches video_player exactly.
  @videoPlayerCompat
  int get playerId => _proController.playerId ?? -1;

  /// The current playback position.
  ///
  /// [video_player compatibility] This property matches video_player exactly.
  /// Returns a Future for API compatibility.
  @videoPlayerCompat
  Future<Duration?> get position async => value.position;

  // ==================== Methods ====================

  /// Initializes the video player.
  ///
  /// [video_player compatibility] This method matches video_player exactly.
  @videoPlayerCompat
  Future<void> initialize() async {
    await _proController.initialize();

    // Set up listener to sync values (this handles position updates for caption sync)
    _proController.addListener(_onProValueChanged);

    // Load captions if provided
    if (_closedCaptionFile != null) {
      try {
        final captionFile = await _closedCaptionFile!;
        _parsedCaptions = captionFile.captions;
      } catch (e) {
        // Ignore caption loading errors, just continue without captions
        _parsedCaptions = null;
      }
    }

    // Initial value sync
    _onProValueChanged();
  }

  /// Called when the pro controller value changes.
  void _onProValueChanged() {
    value = _convertValue(_proController.value);
  }

  /// Starts or resumes video playback.
  ///
  /// [video_player compatibility] This method matches video_player exactly.
  @videoPlayerCompat
  Future<void> play() => _proController.play();

  /// Pauses video playback.
  ///
  /// [video_player compatibility] This method matches video_player exactly.
  @videoPlayerCompat
  Future<void> pause() => _proController.pause();

  /// Seeks to the specified position.
  ///
  /// [video_player compatibility] This method matches video_player exactly.
  @videoPlayerCompat
  Future<void> seekTo(Duration position) => _proController.seekTo(position);

  /// Sets the volume level.
  ///
  /// [video_player compatibility] This method matches video_player exactly.
  @videoPlayerCompat
  Future<void> setVolume(double volume) => _proController.setVolume(volume);

  /// Sets the playback speed.
  ///
  /// [video_player compatibility] This method matches video_player exactly.
  @videoPlayerCompat
  Future<void> setPlaybackSpeed(double speed) => _proController.setPlaybackSpeed(speed);

  /// Sets whether the video should loop.
  ///
  /// [video_player compatibility] This method matches video_player exactly.
  @videoPlayerCompat
  Future<void> setLooping(bool looping) => _proController.setLooping(looping);

  /// Sets the closed caption file.
  ///
  /// [video_player compatibility] This method matches video_player exactly.
  @videoPlayerCompat
  Future<void> setClosedCaptionFile(Future<ClosedCaptionFile>? closedCaptionFile) async {
    _closedCaptionFile = closedCaptionFile;
    _currentCaptionIndex = -1;

    if (closedCaptionFile == null) {
      _parsedCaptions = null;
      _onProValueChanged();
      return;
    }

    try {
      final captionFile = await closedCaptionFile;
      _parsedCaptions = captionFile.captions;
      _onProValueChanged();
    } catch (e) {
      _parsedCaptions = null;
      _onProValueChanged();
    }
  }

  /// Sets the caption offset.
  ///
  /// [video_player compatibility] This method matches video_player exactly.
  @videoPlayerCompat
  void setCaptionOffset(Duration offset) {
    unawaited(_proController.setCaptionOffset(offset));
  }

  /// Disposes of the controller and releases resources.
  ///
  /// [video_player compatibility] This method matches video_player exactly.
  @override
  @videoPlayerCompat
  Future<void> dispose() async {
    _proController.removeListener(_onProValueChanged);
    await _proController.dispose();
    super.dispose();
  }

  // ==================== Advanced Access ====================

  /// Access to the underlying [pro.ProVideoPlayerController].
  ///
  /// Use this to access advanced pro_video_player features not available
  /// in the video_player compatibility API, such as:
  /// - Picture-in-Picture
  /// - Casting
  /// - Chapter navigation
  /// - Multiple audio/subtitle tracks
  /// - Adaptive streaming controls
  ///
  /// Example:
  /// ```dart
  /// // Enable PiP
  /// await controller.proController.enterPictureInPicture();
  ///
  /// // Select audio track
  /// await controller.proController.setAudioTrack(audioTrack);
  /// ```
  pro.ProVideoPlayerController get proController => _proController;
}
