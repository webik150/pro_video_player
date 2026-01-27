import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';
import 'package:web/web.dart' as web;

import 'coordinators/disposal_coordinator.dart';
import 'coordinators/initialization_coordinator.dart';
import 'dash_interop.dart';
import 'hls_interop.dart';
import 'managers/audio_track_manager.dart';
import 'managers/casting_manager.dart';
import 'managers/dash_manager.dart';
import 'managers/event_listener_manager.dart';
import 'managers/hls_manager.dart';
import 'managers/metadata_manager.dart';
import 'managers/playback_control_manager.dart';
import 'managers/quality_manager.dart';
import 'managers/subtitle_manager.dart';
import 'managers/video_source_manager.dart';
import 'managers/wake_lock_manager.dart';
import 'media_session_interop.dart' as media_session;
import 'verbose_logging.dart';
import 'web_player_helpers.dart' as helpers;

/// Web video player implementation using HTML5 VideoElement.
///
/// This player uses a manager-based architecture for maintainability:
/// - 13 specialized managers handle specific concerns (HLS, DASH, subtitles, etc.)
/// - 2 coordinators manage initialization and disposal
/// - This class acts as a facade, delegating operations to managers
///
/// For HLS sources on non-Safari browsers, this player automatically loads
/// and uses HLS.js for playback, enabling quality selection, audio track
/// selection, and adaptive bitrate streaming.
///
/// For DASH sources (MPD), this player automatically loads and uses dash.js
/// for playback, enabling quality selection, audio track selection, and
/// adaptive bitrate streaming.
class WebVideoPlayer {
  /// Creates a new web video player.
  WebVideoPlayer(this.playerId, this.source, this.options);

  /// The unique player ID.
  final int playerId;

  /// The video source.
  final VideoSource source;

  /// Player options.
  final VideoPlayerOptions options;

  late final web.HTMLVideoElement _videoElement;

  /// The view type for platform view registration.
  late final String viewType;

  final StreamController<VideoPlayerEvent> _eventController = StreamController<VideoPlayerEvent>.broadcast();
  bool _isDisposed = false;

  /// Manager instances (created by WebInitializationCoordinator).
  late final Map<Type, dynamic> _managers;

  // Track if using HLS.js or dash.js (needed for some operations)
  bool _isUsingHlsJs = false;
  bool _isUsingDashJs = false;

  // External subtitle storage (web-specific, not yet in manager)
  final Map<String, ExternalSubtitleTrack> _externalSubtitles = {};
  final Map<String, web.HTMLTrackElement> _externalTrackElements = {};
  int _nextExternalSubtitleId = 0;

  // Track selection state flags
  bool _hasManuallySelectedSubtitle = false;
  bool _isInitialSubtitleSelection = true;

  /// Stream of player events.
  Stream<VideoPlayerEvent> get events => _eventController.stream;

  /// Safely adds an event to the stream, ignoring if disposed.
  void _emitEvent(VideoPlayerEvent event) {
    if (!_isDisposed) {
      _eventController.add(event);
    }
  }

  /// Initializes the video player.
  Future<void> initialize() async {
    viewType = 'pro_video_player_web_$playerId';

    _videoElement = web.HTMLVideoElement()
      ..style.width = '100%'
      ..style.height = '100%';

    // Set video scaling mode
    final objectFit = helpers.getObjectFitFromScalingMode(options.scalingMode);
    _videoElement.style.setProperty('object-fit', objectFit);

    // Set preload behavior based on buffering tier
    _videoElement.preload = helpers.getPreloadFromBufferingTier(options.bufferingTier);

    // Set initial options
    _videoElement.loop = options.looping;
    _videoElement.volume = options.volume;
    _videoElement.playbackRate = options.playbackSpeed;
    _videoElement.controls = false; // We'll manage controls separately

    // Set muted and autoplay attributes when autoPlay is requested
    // Note: Autoplay may not work in all contexts due to browser restrictions,
    // even with muted audio. For reliable playback in tests, call play() explicitly.
    if (options.autoPlay) {
      _videoElement.muted = true; // Mute for autoplay
      _videoElement.autoplay = true; // Set autoplay attribute
    }

    // Register platform view
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) => _videoElement);

    // Create all managers using initialization coordinator
    _managers = WebInitializationCoordinator.createManagers(
      emitEvent: _emitEvent,
      videoElement: _videoElement,
      options: options,
      source: source,
    );

    // Set up video source (determines HLS.js vs dash.js vs native)
    await _setupVideoSource();

    // Wire metadata callback to trigger subtitle auto-selection
    _getEventListenerManager().onMetadataLoaded = _handleMetadataLoaded;

    // Auto-play if requested
    if (options.autoPlay) {
      await play();
    }
  }

  /// Sets up the video source, using HLS.js or dash.js if needed.
  Future<void> _setupVideoSource() async {
    final sourceManager = _getVideoSourceManager();
    final hlsManager = _getHlsManager();
    final dashManager = _getDashManager();

    final sourceUrl = sourceManager.getSourceUrl(source);
    final isHls = sourceManager.isHlsSource(sourceUrl);
    final isDash = sourceManager.isDashSource(sourceUrl);

    if (isDash) {
      // Load dash.js for DASH/MPD sources
      verboseLog('DASH source detected, loading dash.js...', tag: 'WebVideoPlayer');
      final loaded = await loadDashJs();

      if (loaded && isDashJsSupported) {
        final dashPlayer = DashPlayer.create();
        if (dashPlayer != null) {
          _isUsingDashJs = true;
          await dashManager.initialize(
            sourceUrl: sourceUrl,
            dashPlayer: dashPlayer,
            autoPlay: options.autoPlay,
            abrMode: options.abrMode,
            minBitrate: options.minBitrate,
            maxBitrate: options.maxBitrate,
          );
          return;
        }
        verboseLog('Failed to create DASH player', tag: 'WebVideoPlayer');
      } else {
        verboseLog('dash.js not available, DASH playback may not work', tag: 'WebVideoPlayer');
      }
    } else if (isHls && !isNativeHlsSupported) {
      // Load HLS.js for non-Safari browsers
      verboseLog('HLS source detected, loading HLS.js...', tag: 'WebVideoPlayer');
      final loaded = await loadHlsJs();

      if (loaded && isHlsJsSupported) {
        final config = <String, dynamic>{
          'enableWorker': true,
          'lowLatencyMode': false,
          'startPosition': -1,
          'abrMaxWithRealBitrate': true,
        };

        if (options.abrMode == AbrMode.manual) {
          config['startLevel'] = 0;
        }

        final hlsPlayer = HlsPlayer.create(config: config);
        if (hlsPlayer != null) {
          _isUsingHlsJs = true;
          await hlsManager.initialize(sourceUrl: sourceUrl, hlsPlayer: hlsPlayer, maxBitrate: options.maxBitrate);
          return;
        }
        verboseLog('Failed to create HLS player', tag: 'WebVideoPlayer');
      } else {
        verboseLog('HLS.js not available, falling back to native', tag: 'WebVideoPlayer');
      }
    }

    // Native playback (Safari for HLS, or regular video files)
    sourceManager.setNativeSource(sourceUrl);
  }

  /// Handles metadata loaded event to trigger subtitle auto-selection.
  void _handleMetadataLoaded() {
    final metadataManager = _getMetadataManager();

    // Emit video size event
    _emitEvent(VideoSizeChangedEvent(width: _videoElement.videoWidth, height: _videoElement.videoHeight));

    // Extract and send video metadata
    final metadata = metadataManager.extractMetadata(source);
    if (metadata != null) {
      _emitEvent(VideoMetadataExtractedEvent(metadata));
    }

    // For non-HLS or native HLS playback, notify about tracks
    if (!_isUsingHlsJs && !_isUsingDashJs) {
      _notifySubtitleTracks();
      _notifyAudioTracks();
    }

    // Auto-select subtitle if configured
    if (options.showSubtitlesByDefault && _isInitialSubtitleSelection && !_hasManuallySelectedSubtitle) {
      _autoSelectSubtitle();
      _isInitialSubtitleSelection = false;
    }
  }

  // MARK: - Manager Getters

  PlaybackControlManager _getPlaybackManager() => _managers[PlaybackControlManager] as PlaybackControlManager;
  VideoSourceManager _getVideoSourceManager() => _managers[VideoSourceManager] as VideoSourceManager;
  EventListenerManager _getEventListenerManager() => _managers[EventListenerManager] as EventListenerManager;
  HlsManager _getHlsManager() => _managers[HlsManager] as HlsManager;
  DashManager _getDashManager() => _managers[DashManager] as DashManager;
  QualityManager _getQualityManager() => _managers[QualityManager] as QualityManager;
  AudioTrackManager _getAudioTrackManager() => _managers[AudioTrackManager] as AudioTrackManager;
  SubtitleManager _getSubtitleManager() => _managers[SubtitleManager] as SubtitleManager;
  CastingManager _getCastingManager() => _managers[CastingManager] as CastingManager;
  WakeLockManager _getWakeLockManager() => _managers[WakeLockManager] as WakeLockManager;
  MetadataManager _getMetadataManager() => _managers[MetadataManager] as MetadataManager;

  // MARK: - Playback Controls

  /// Starts playback.
  Future<void> play() async {
    await _getPlaybackManager().play();
    await _getWakeLockManager().updateWakeLock();
  }

  /// Pauses playback.
  Future<void> pause() async {
    _getPlaybackManager().pause();
    await _getWakeLockManager().updateWakeLock();
  }

  /// Stops playback and resets position.
  Future<void> stop() async {
    _getPlaybackManager().stop();
    await _getWakeLockManager().updateWakeLock();
  }

  /// Seeks to the specified position.
  void seekTo(Duration position) {
    _getPlaybackManager().seekTo(position);
  }

  /// Sets the playback speed.
  void setPlaybackSpeed(double speed) {
    _getPlaybackManager().setPlaybackSpeed(speed);
  }

  /// Sets the volume.
  void setVolume(double volume) {
    _getPlaybackManager().setVolume(volume);
  }

  /// Whether the video should loop.
  bool get looping => _getPlaybackManager().looping;

  /// Sets whether the video should loop.
  set looping(bool value) {
    _getPlaybackManager().looping = value;
  }

  /// Sets the video scaling mode.
  void setScalingMode(VideoScalingMode mode) {
    final objectFit = helpers.getObjectFitFromScalingMode(mode);
    _videoElement.style.setProperty('object-fit', objectFit);
  }

  /// Gets the current playback position.
  Duration getPosition() => _getPlaybackManager().getPosition();

  /// Gets the video duration.
  Duration getDuration() => _getPlaybackManager().getDuration();

  // MARK: - Quality Selection

  /// Gets the available video qualities.
  List<VideoQualityTrack> getVideoQualities() => _getQualityManager().getAvailableQualities();

  /// Sets the video quality.
  ///
  /// Returns true if the quality was set successfully.
  bool setVideoQuality(VideoQualityTrack track) => _getQualityManager().setQuality(track);

  /// Gets the current video quality.
  VideoQualityTrack getCurrentVideoQuality() => _getQualityManager().getCurrentQuality();

  /// Checks if quality selection is supported.
  bool isQualitySelectionSupported() => _getQualityManager().isQualitySelectionSupported();

  // MARK: - Audio Track Selection

  /// Sets the active audio track.
  void setAudioTrack(AudioTrack? track) {
    final success = _getAudioTrackManager().setAudioTrack(track);
    if (success) {
      _emitEvent(SelectedAudioChangedEvent(track));
    }
  }

  // MARK: - Subtitle Track Selection

  /// Sets the active subtitle track.
  void setSubtitleTrack(SubtitleTrack? track) {
    _hasManuallySelectedSubtitle = true;

    // Handle external subtitle tracks specially
    if (track != null && track.id.startsWith('ext_')) {
      _handleExternalSubtitleSelection(track);
      _emitEvent(SelectedSubtitleChangedEvent(track));
      return;
    }

    // Delegate to subtitle manager for embedded tracks
    final success = _getSubtitleManager().setSubtitleTrack(track);
    if (success) {
      _emitEvent(SelectedSubtitleChangedEvent(track));
    }

    // Hide external tracks when selecting embedded track
    _hideAllExternalSubtitles();
  }

  /// Handles selection of external subtitle track.
  void _handleExternalSubtitleSelection(SubtitleTrack track) {
    final subtitleManager = _getSubtitleManager();

    // Disable embedded subtitles
    subtitleManager.setSubtitleTrack(null);

    // Show the selected external track, hide others
    for (final entry in _externalTrackElements.entries) {
      entry.value.track.mode = entry.key == track.id ? 'showing' : 'hidden';
    }
  }

  /// Hides all external subtitle tracks.
  void _hideAllExternalSubtitles() {
    for (final element in _externalTrackElements.values) {
      element.track.mode = 'hidden';
    }
  }

  /// Sets the subtitle rendering mode (native or flutter).
  ///
  /// - native: Browser's TextTrack API renders subtitles
  /// - flutter: Subtitle text is extracted and streamed to Flutter for rendering
  /// - auto: Defaults to Flutter rendering
  void setSubtitleRenderMode(String mode) {
    _getSubtitleManager().setRenderMode(mode);
  }

  /// Notifies Flutter about available subtitle tracks.
  void _notifySubtitleTracks() {
    final subtitleManager = _getSubtitleManager();
    final tracks = subtitleManager.getNativeSubtitleTracks();

    if (tracks.isNotEmpty) {
      _emitEvent(SubtitleTracksChangedEvent(tracks));
    }

    // Set up cue change listeners if in flutter render mode (auto defaults to flutter)
    final renderMode = options.subtitleRenderMode;
    if (renderMode == SubtitleRenderMode.flutter || renderMode == SubtitleRenderMode.auto) {
      subtitleManager.setRenderMode('flutter');
    }
  }

  /// Notifies Flutter about available audio tracks.
  void _notifyAudioTracks() {
    final audioManager = _getAudioTrackManager();
    final tracks = audioManager.getNativeAudioTracks();

    if (tracks.isNotEmpty) {
      _emitEvent(AudioTracksChangedEvent(tracks));
    }
  }

  /// Auto-selects a subtitle track based on preferred language.
  void _autoSelectSubtitle() {
    final subtitleManager = _getSubtitleManager();
    final preferredLanguage = options.preferredSubtitleLanguage;

    SubtitleTrack? selectedTrack;

    if (_isUsingHlsJs) {
      selectedTrack = subtitleManager.autoSelectHlsSubtitle(preferredLanguage);
    } else {
      selectedTrack = subtitleManager.autoSelectNativeSubtitle(preferredLanguage);
    }

    if (selectedTrack != null) {
      _emitEvent(SelectedSubtitleChangedEvent(selectedTrack));
    }
  }

  // MARK: - Casting

  /// Checks if casting is currently supported.
  bool isCastingSupported() => _getCastingManager().isCastingSupported();

  /// Gets the list of available cast devices.
  List<CastDevice> getAvailableCastDevices() => _getCastingManager().getAvailableCastDevices();

  /// Starts casting by prompting the user to select a device.
  Future<bool> startCasting({CastDevice? device}) async => _getCastingManager().startCasting(device: device);

  /// Stops casting and returns playback to the local device.
  Future<bool> stopCasting() async =>
      _getCastingManager().stopCasting(currentSource: source, getSourceUrl: helpers.getSourceUrl);

  /// Gets the current cast state.
  CastState getCastState() => _getCastingManager().getCastState();

  /// Gets the current cast device, or null if not casting.
  CastDevice? getCurrentCastDevice() => _getCastingManager().getCurrentCastDevice();

  // MARK: - Picture-in-Picture

  /// Checks if Picture-in-Picture is supported in the current browser.
  /// Note: Firefox may throw an error, so we need to handle that.
  static bool isPipSupported() {
    try {
      return web.document.pictureInPictureEnabled;
    } catch (e) {
      return false;
    }
  }

  /// Enters Picture-in-Picture mode.
  Future<bool> enterPip() async {
    if (!isPipSupported()) {
      return false;
    }
    try {
      await _videoElement.requestPictureInPicture().toDart;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Exits Picture-in-Picture mode.
  Future<void> exitPip() async {
    if (web.document.pictureInPictureElement != null) {
      try {
        await web.document.exitPictureInPicture().toDart;
      } catch (_) {
        // Ignore errors when exiting PiP
      }
    }
  }

  // MARK: - Fullscreen

  /// Enters fullscreen mode.
  Future<bool> enterFullscreen() async {
    try {
      await _videoElement.requestFullscreen().toDart;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Exits fullscreen mode.
  Future<void> exitFullscreen() async {
    try {
      await web.document.exitFullscreen().toDart;
    } catch (_) {
      // Ignore errors when exiting fullscreen
    }
  }

  // MARK: - Media Session

  /// Sets media metadata for browser media controls (Media Session API).
  void setMediaMetadata(MediaMetadata metadata) {
    final navigator = web.window.navigator;
    if (!media_session.hasMediaSession(navigator)) {
      verboseLog('Media Session API not available', tag: 'WebVideoPlayer');
      return;
    }

    try {
      final mediaSession = media_session.getMediaSession(navigator);
      if (mediaSession == null) return;

      final jsMetadata = media_session.createMediaMetadata(
        title: metadata.title ?? '',
        artist: metadata.artist ?? '',
        album: metadata.album ?? '',
        artwork: metadata.artworkUrl,
      );

      media_session.setMediaSessionMetadata(mediaSession, jsMetadata);
      verboseLog('Media metadata set: ${metadata.title}', tag: 'WebVideoPlayer');
    } catch (e) {
      verboseLog('Failed to set media metadata: $e', tag: 'WebVideoPlayer');
    }
  }

  // MARK: - Video Metadata

  /// Gets video metadata (codec, resolution, bitrate, etc.).
  ///
  /// Returns null if metadata is not available yet.
  VideoMetadata? getVideoMetadata() => _getMetadataManager().extractMetadata(source);

  // MARK: - External Subtitles

  /// Adds an external subtitle track from a URL.
  ///
  /// For web, browsers natively support VTT format. Other formats (SRT, SSA, TTML)
  /// are converted to VTT on load if possible, but browser support may vary.
  ///
  /// Returns the created [ExternalSubtitleTrack] on success, or null on failure.
  Future<ExternalSubtitleTrack?> addExternalSubtitle(SubtitleSource source) async {
    try {
      // Generate unique ID
      final trackId = 'ext_${_nextExternalSubtitleId++}';

      var subtitleUrl = source.path;
      final format = source.format;
      final label = source.label;
      final language = source.language;
      final isDefault = source.isDefault;

      // Detect format from URL if not provided
      final detectedFormat = format ?? helpers.detectSubtitleFormat(subtitleUrl);

      // Create label from URL if not provided
      final trackLabel = label ?? helpers.labelFromUrl(subtitleUrl);

      // If format is not WebVTT, load and convert to WebVTT, then create a blob URL
      if (detectedFormat != null && detectedFormat != SubtitleFormat.vtt) {
        try {
          verboseLog('Converting ${detectedFormat.name} to WebVTT for browser compatibility', tag: 'WebVideoPlayer');

          // Use SubtitleLoader to load and convert to WebVTT
          final loader = SubtitleLoader();
          final webvttContent = await loader.loadAndConvertToWebVTT(source);
          loader.dispose();

          // Create a Blob from the WebVTT content
          final blob = web.Blob(<JSAny>[webvttContent.toJS].toJS, web.BlobPropertyBag(type: 'text/vtt'));

          // Create a blob URL
          subtitleUrl = web.URL.createObjectURL(blob);

          verboseLog('Created blob URL for converted WebVTT subtitle', tag: 'WebVideoPlayer');
        } catch (e) {
          verboseLog('Failed to convert subtitle to WebVTT: $e, using original URL', tag: 'WebVideoPlayer');
        }
      }

      // Create the track element
      final trackElement = web.HTMLTrackElement()
        ..kind = 'subtitles'
        ..src = subtitleUrl
        ..label = trackLabel
        ..srclang = language ?? '';

      // Set as default if requested
      if (isDefault) {
        trackElement.default_ = true;
      }

      // Add to video element
      _videoElement.appendChild(trackElement);

      // Store the track
      final track = ExternalSubtitleTrack(
        id: trackId,
        label: trackLabel,
        language: language,
        isDefault: isDefault,
        path: source.path,
        sourceType: source.sourceType,
        format: detectedFormat ?? SubtitleFormat.vtt,
      );

      _externalSubtitles[trackId] = track;
      _externalTrackElements[trackId] = trackElement;

      verboseLog('Added external subtitle: $trackId ($trackLabel)', tag: 'WebVideoPlayer');

      // Notify about updated subtitle tracks
      _notifySubtitleTracksWithExternal();

      return track;
    } catch (e) {
      verboseLog('Failed to add external subtitle: $e', tag: 'WebVideoPlayer');
      return null;
    }
  }

  /// Removes an external subtitle track.
  ///
  /// Returns true if the track was removed successfully.
  bool removeExternalSubtitle(String trackId) {
    final track = _externalSubtitles.remove(trackId);
    final element = _externalTrackElements.remove(trackId);

    if (track == null || element == null) {
      return false;
    }

    // Remove from video element
    _videoElement.removeChild(element);

    verboseLog('Removed external subtitle: $trackId', tag: 'WebVideoPlayer');

    // Notify about updated subtitle tracks
    _notifySubtitleTracksWithExternal();

    return true;
  }

  /// Gets all external subtitle tracks.
  List<ExternalSubtitleTrack> getExternalSubtitles() => _externalSubtitles.values.toList();

  /// Notifies about subtitle tracks including external ones.
  void _notifySubtitleTracksWithExternal() {
    final allTracks = <SubtitleTrack>[];

    // Add embedded tracks
    final subtitleManager = _getSubtitleManager();
    if (_isUsingHlsJs) {
      allTracks.addAll(subtitleManager.getHlsSubtitleTracks());
    } else if (_isUsingDashJs) {
      allTracks.addAll(subtitleManager.getDashSubtitleTracks());
    } else {
      allTracks.addAll(subtitleManager.getNativeSubtitleTracks());
    }

    // Add external tracks
    allTracks.addAll(_externalSubtitles.values);

    _emitEvent(SubtitleTracksChangedEvent(allTracks));
  }

  // MARK: - Disposal

  /// Disposes of the player and releases resources.
  void dispose() {
    _isDisposed = true;

    // Dispose all managers in correct order
    WebDisposalCoordinator.disposeAll(_managers);

    // Clean up video element
    _videoElement
      ..pause()
      ..src = ''
      ..load();

    // Close event stream
    unawaited(_eventController.close());
  }
}
