import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'pigeon_method_channel_base.dart';
import 'types/types.dart';

/// The interface that implementations of pro_video_player must implement.
///
/// Platform implementations should extend this class rather than implement it
/// as `pro_video_player` does not consider newly added methods to be
/// breaking changes. Extending this class (using `extends`) ensures that the
/// subclass will get the default implementation, while platform implementations
/// that `implements` this interface will be broken by newly added methods.
abstract class ProVideoPlayerPlatform extends PlatformInterface {
  /// Constructs a ProVideoPlayerPlatform.
  ProVideoPlayerPlatform() : super(token: _token);

  static final Object _token = Object();

  static ProVideoPlayerPlatform _instance = _DefaultMethodChannelProVideoPlayer();

  /// The default instance of [ProVideoPlayerPlatform] to use.
  ///
  /// Defaults to a basic [PigeonMethodChannelBase] implementation. Platform-specific
  /// packages (iOS, Android, Web, macOS, etc.) register their own implementations.
  static ProVideoPlayerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ProVideoPlayerPlatform] when
  /// they register themselves.
  static set instance(ProVideoPlayerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Creates a new video player instance and returns its unique ID.
  Future<int> create({required VideoSource source, VideoPlayerOptions options = const VideoPlayerOptions()}) {
    throw UnimplementedError('create() has not been implemented.');
  }

  /// Disposes the video player with the given [playerId].
  Future<void> dispose(int playerId) {
    throw UnimplementedError('dispose() has not been implemented.');
  }

  /// Starts or resumes playback.
  Future<void> play(int playerId) {
    throw UnimplementedError('play() has not been implemented.');
  }

  /// Pauses playback.
  Future<void> pause(int playerId) {
    throw UnimplementedError('pause() has not been implemented.');
  }

  /// Stops playback and resets position to the beginning.
  Future<void> stop(int playerId) {
    throw UnimplementedError('stop() has not been implemented.');
  }

  /// Seeks to the specified [position].
  Future<void> seekTo(int playerId, Duration position) {
    throw UnimplementedError('seekTo() has not been implemented.');
  }

  /// Sets the playback speed.
  ///
  /// [speed] must be greater than 0. Common values:
  /// - 0.5: Half speed
  /// - 1.0: Normal speed
  /// - 1.5: 1.5x speed
  /// - 2.0: Double speed
  Future<void> setPlaybackSpeed(int playerId, double speed) {
    throw UnimplementedError('setPlaybackSpeed() has not been implemented.');
  }

  /// Sets the player volume.
  ///
  /// [volume] must be between 0.0 (muted) and 1.0 (full volume).
  /// This controls the player's volume, not the device volume.
  /// Use [setDeviceVolume] to control the device's media volume.
  Future<void> setVolume(int playerId, double volume) {
    throw UnimplementedError('setVolume() has not been implemented.');
  }

  /// Gets the current device media volume.
  ///
  /// Returns a value between 0.0 (muted) and 1.0 (max volume).
  /// This is the device's media/music stream volume, not the player's internal volume.
  Future<double> getDeviceVolume() {
    throw UnimplementedError('getDeviceVolume() has not been implemented.');
  }

  /// Sets the device media volume.
  ///
  /// [volume] must be between 0.0 (muted) and 1.0 (max volume).
  /// This controls the device's media/music stream volume directly.
  /// The system volume UI may be shown briefly when changing volume.
  Future<void> setDeviceVolume(double volume) {
    throw UnimplementedError('setDeviceVolume() has not been implemented.');
  }

  /// Gets the current screen brightness.
  ///
  /// Returns a value between 0.0 (dimmest) and 1.0 (brightest).
  /// On iOS/Android, this returns the current screen brightness setting.
  /// On other platforms, returns 1.0 as a default.
  Future<double> getScreenBrightness() {
    throw UnimplementedError('getScreenBrightness() has not been implemented.');
  }

  /// Sets the screen brightness.
  ///
  /// [brightness] must be between 0.0 (dimmest) and 1.0 (brightest).
  /// On iOS, this sets UIScreen.main.brightness.
  /// On Android, this sets WindowManager.LayoutParams.screenBrightness.
  /// The change is temporary and will be reset when the app is closed.
  Future<void> setScreenBrightness(double brightness) {
    throw UnimplementedError('setScreenBrightness() has not been implemented.');
  }

  /// Gets the current battery information.
  ///
  /// Returns battery percentage (0-100) and charging state, or `null` if:
  /// - Battery information is not available
  /// - Platform doesn't support battery APIs
  /// - Device doesn't have a battery (e.g., desktop computers)
  ///
  /// Platform support:
  /// - **iOS**: Full support via UIDevice battery APIs
  /// - **Android**: Full support via BatteryManager
  /// - **macOS**: Supported on MacBooks with battery, null on desktops
  /// - **Web**: Supported in browsers with Battery Status API (Chrome, Edge)
  /// - **Windows/Linux**: Not implemented, returns null
  ///
  /// Example:
  /// ```dart
  /// final battery = await ProVideoPlayerPlatform.instance.getBatteryInfo();
  /// if (battery != null) {
  ///   print('Battery: ${battery.percentage}%, Charging: ${battery.isCharging}');
  /// }
  /// ```
  Future<BatteryInfo?> getBatteryInfo() {
    throw UnimplementedError('getBatteryInfo() has not been implemented.');
  }

  /// Stream of battery state changes.
  ///
  /// Emits new [BatteryInfo] when battery percentage or charging state changes.
  /// The stream is empty on platforms that don't support battery monitoring.
  ///
  /// On iOS, emits when battery level changes by 1% or charging state changes.
  /// On Android, emits on battery level or charging state changes.
  /// On macOS, emits periodically when battery state changes.
  /// On Web, emits on battery level or charging state changes (if supported).
  ///
  /// The stream automatically completes when the platform doesn't support
  /// battery monitoring. Check for empty stream or listen with error handling:
  ///
  /// ```dart
  /// ProVideoPlayerPlatform.instance.batteryUpdates.listen(
  ///   (info) => print('Battery: ${info.percentage}%'),
  ///   onError: (_) => print('Battery monitoring not supported'),
  /// );
  /// ```
  Stream<BatteryInfo> get batteryUpdates {
    throw UnimplementedError('batteryUpdates has not been implemented.');
  }

  /// Sets whether the video should loop.
  Future<void> setLooping(int playerId, bool looping) {
    throw UnimplementedError('setLooping() has not been implemented.');
  }

  /// Sets the video scaling mode.
  Future<void> setScalingMode(int playerId, VideoScalingMode mode) {
    throw UnimplementedError('setScalingMode() has not been implemented.');
  }

  /// Selects a subtitle track.
  ///
  /// Pass `null` to disable subtitles.
  Future<void> setSubtitleTrack(int playerId, SubtitleTrack? track) {
    throw UnimplementedError('setSubtitleTrack() has not been implemented.');
  }

  /// Sets the subtitle rendering mode for the player.
  ///
  /// Controls whether subtitles are rendered by the native platform or by Flutter.
  /// This can be changed at runtime without recreating the player.
  ///
  /// The [mode] parameter determines the rendering behavior:
  /// - [SubtitleRenderMode.native]: Platform renders subtitles with native styling
  /// - [SubtitleRenderMode.flutter]: Flutter renders subtitles via SubtitleOverlay
  /// - [SubtitleRenderMode.auto]: Auto-select based on controls mode
  ///
  /// When switching to Flutter rendering, embedded subtitle cues will be streamed
  /// to Flutter. When switching to native rendering, the platform will handle rendering.
  ///
  /// External subtitles are always rendered in Flutter regardless of this setting.
  Future<void> setSubtitleRenderMode(int playerId, SubtitleRenderMode mode) {
    throw UnimplementedError('setSubtitleRenderMode() has not been implemented.');
  }

  /// Sets the subtitle timing offset.
  ///
  /// Adjusts the timing of subtitles by the given [offset]. Positive values delay
  /// subtitles, negative values advance them.
  Future<void> setSubtitleOffset(int playerId, Duration offset) {
    throw UnimplementedError('setSubtitleOffset() has not been implemented.');
  }

  /// Selects an audio track.
  ///
  /// Pass `null` to reset to the default audio track.
  Future<void> setAudioTrack(int playerId, AudioTrack? track) {
    throw UnimplementedError('setAudioTrack() has not been implemented.');
  }

  /// Gets the current playback position.
  Future<Duration> getPosition(int playerId) {
    throw UnimplementedError('getPosition() has not been implemented.');
  }

  /// Gets the total duration of the video.
  Future<Duration> getDuration(int playerId) {
    throw UnimplementedError('getDuration() has not been implemented.');
  }

  /// Enters Picture-in-Picture mode.
  ///
  /// Returns `true` if PiP was entered successfully, `false` if PiP is not
  /// supported or failed to enter.
  Future<bool> enterPip(int playerId, {PipOptions options = const PipOptions()}) {
    throw UnimplementedError('enterPip() has not been implemented.');
  }

  /// Exits Picture-in-Picture mode.
  Future<void> exitPip(int playerId) {
    throw UnimplementedError('exitPip() has not been implemented.');
  }

  /// Returns whether Picture-in-Picture is supported on this device.
  Future<bool> isPipSupported() {
    throw UnimplementedError('isPipSupported() has not been implemented.');
  }

  /// Sets the PiP remote action buttons.
  ///
  /// These actions appear as buttons in the PiP window, allowing users to
  /// control playback without leaving the PiP view.
  ///
  /// **Platform support:**
  /// - **Android**: Full support via `RemoteAction` in `PictureInPictureParams`.
  ///   Actions appear as icon buttons in the PiP window overlay.
  /// - **iOS**: Limited support. iOS 15+ supports `canSkipForward`/`canSkipBackward`
  ///   on `AVPictureInPictureController`. Play/pause is handled automatically.
  /// - **macOS/Web/Windows/Linux**: Not supported.
  ///
  /// Pass `null` or an empty list to clear all custom actions.
  ///
  /// Example:
  /// ```dart
  /// await platform.setPipActions(playerId, [
  ///   PipAction(type: PipActionType.skipBackward, skipInterval: Duration(seconds: 10)),
  ///   PipAction(type: PipActionType.playPause),
  ///   PipAction(type: PipActionType.skipForward, skipInterval: Duration(seconds: 10)),
  /// ]);
  /// ```
  ///
  /// When an action button is tapped, a [PipActionTriggeredEvent] is emitted.
  /// For skip actions, the app is responsible for performing the skip:
  ///
  /// ```dart
  /// controller.events.listen((event) {
  ///   if (event is PipActionTriggeredEvent) {
  ///     switch (event.action) {
  ///       case PipActionType.skipBackward:
  ///         controller.seekBy(Duration(seconds: -10));
  ///         break;
  ///       case PipActionType.skipForward:
  ///         controller.seekBy(Duration(seconds: 10));
  ///         break;
  ///       // playPause is handled automatically by native player
  ///     }
  ///   }
  /// });
  /// ```
  Future<void> setPipActions(int playerId, List<PipAction>? actions) {
    throw UnimplementedError('setPipActions() has not been implemented.');
  }

  /// Enters fullscreen mode.
  ///
  /// Returns `true` if fullscreen was entered successfully.
  Future<bool> enterFullscreen(int playerId) {
    throw UnimplementedError('enterFullscreen() has not been implemented.');
  }

  /// Exits fullscreen mode.
  Future<void> exitFullscreen(int playerId) {
    throw UnimplementedError('exitFullscreen() has not been implemented.');
  }

  /// Returns a stream of events for the player with the given [playerId].
  Stream<VideoPlayerEvent> events(int playerId) {
    throw UnimplementedError('events() has not been implemented.');
  }

  /// Builds the platform-specific video view widget.
  ///
  /// This widget displays the actual video content.
  ///
  /// The [controlsMode] parameter determines how playback controls are displayed:
  /// - [ControlsMode.none]: Video only, no native controls (default)
  /// - [ControlsMode.native]: Show platform-native playback controls
  Widget buildView(int playerId, {ControlsMode controlsMode = ControlsMode.none}) {
    throw UnimplementedError('buildView() has not been implemented.');
  }

  /// Sets the controls mode for the video view.
  ///
  /// This allows changing the controls mode at runtime without recreating the view.
  ///
  /// The [controlsMode] parameter determines how playback controls are displayed:
  /// - [ControlsMode.none]: Video only, no native controls
  /// - [ControlsMode.native]: Show platform-native playback controls
  Future<void> setControlsMode(int playerId, ControlsMode controlsMode) {
    throw UnimplementedError('setControlsMode() has not been implemented.');
  }

  /// Sets verbose logging mode for all platform implementations.
  ///
  /// When enabled, detailed debug logs will be printed to help troubleshoot issues.
  /// This affects both Dart-side and native platform code.
  Future<void> setVerboseLogging({required bool enabled}) {
    throw UnimplementedError('setVerboseLogging() has not been implemented.');
  }

  /// Gets static platform information.
  ///
  /// Returns metadata about the platform (name, player type, additional info)
  /// that doesn't require async capability checks.
  ///
  /// Example:
  /// ```dart
  /// final info = await platform.getPlatformInfo();
  /// print('Running on ${info.platformName} with ${info.nativePlayerType}');
  /// ```
  Future<PlatformInfo> getPlatformInfo() {
    throw UnimplementedError('getPlatformInfo() has not been implemented.');
  }

  /// Checks if Picture-in-Picture mode is supported.
  Future<bool> supportsPictureInPicture() {
    throw UnimplementedError('supportsPictureInPicture() has not been implemented.');
  }

  /// Checks if fullscreen mode is supported.
  Future<bool> supportsFullscreen() {
    throw UnimplementedError('supportsFullscreen() has not been implemented.');
  }

  /// Checks if background playback is supported.
  Future<bool> supportsBackgroundPlayback() {
    throw UnimplementedError('supportsBackgroundPlayback() has not been implemented.');
  }

  /// Checks if any form of casting is supported.
  Future<bool> supportsCasting() {
    throw UnimplementedError('supportsCasting() has not been implemented.');
  }

  /// Checks if AirPlay is supported.
  Future<bool> supportsAirPlay() {
    throw UnimplementedError('supportsAirPlay() has not been implemented.');
  }

  /// Checks if Chromecast is supported.
  Future<bool> supportsChromecast() {
    throw UnimplementedError('supportsChromecast() has not been implemented.');
  }

  /// Checks if Remote Playback API is supported.
  Future<bool> supportsRemotePlayback() {
    throw UnimplementedError('supportsRemotePlayback() has not been implemented.');
  }

  /// Checks if quality selection is supported.
  Future<bool> supportsQualitySelection() {
    throw UnimplementedError('supportsQualitySelection() has not been implemented.');
  }

  /// Checks if playback speed control is supported.
  Future<bool> supportsPlaybackSpeedControl() {
    throw UnimplementedError('supportsPlaybackSpeedControl() has not been implemented.');
  }

  /// Checks if subtitles are supported.
  Future<bool> supportsSubtitles() {
    throw UnimplementedError('supportsSubtitles() has not been implemented.');
  }

  /// Checks if external subtitles are supported.
  Future<bool> supportsExternalSubtitles() {
    throw UnimplementedError('supportsExternalSubtitles() has not been implemented.');
  }

  /// Checks if audio track selection is supported.
  Future<bool> supportsAudioTrackSelection() {
    throw UnimplementedError('supportsAudioTrackSelection() has not been implemented.');
  }

  /// Checks if chapters are supported.
  Future<bool> supportsChapters() {
    throw UnimplementedError('supportsChapters() has not been implemented.');
  }

  /// Checks if video metadata extraction is supported.
  Future<bool> supportsVideoMetadataExtraction() {
    throw UnimplementedError('supportsVideoMetadataExtraction() has not been implemented.');
  }

  /// Checks if network monitoring is supported.
  Future<bool> supportsNetworkMonitoring() {
    throw UnimplementedError('supportsNetworkMonitoring() has not been implemented.');
  }

  /// Checks if bandwidth estimation is supported.
  Future<bool> supportsBandwidthEstimation() {
    throw UnimplementedError('supportsBandwidthEstimation() has not been implemented.');
  }

  /// Checks if adaptive bitrate streaming is supported.
  Future<bool> supportsAdaptiveBitrate() {
    throw UnimplementedError('supportsAdaptiveBitrate() has not been implemented.');
  }

  /// Checks if HLS is supported.
  Future<bool> supportsHLS() {
    throw UnimplementedError('supportsHLS() has not been implemented.');
  }

  /// Checks if DASH is supported.
  Future<bool> supportsDASH() {
    throw UnimplementedError('supportsDASH() has not been implemented.');
  }

  /// Checks if device volume control is supported.
  Future<bool> supportsDeviceVolumeControl() {
    throw UnimplementedError('supportsDeviceVolumeControl() has not been implemented.');
  }

  /// Checks if screen brightness control is supported.
  Future<bool> supportsScreenBrightnessControl() {
    throw UnimplementedError('supportsScreenBrightnessControl() has not been implemented.');
  }

  /// Sets the media metadata for platform media controls.
  ///
  /// This metadata is displayed in:
  /// - iOS/macOS: Control Center and Lock Screen (via MPNowPlayingInfoCenter)
  /// - Android: Media notification and Lock Screen (via MediaSession)
  /// - Web: Browser media controls (via Media Session API)
  ///
  /// The metadata is only shown when background playback is enabled
  /// ([VideoPlayerOptions.allowBackgroundPlayback] is `true`).
  ///
  /// Pass [MediaMetadata.empty] to clear any previously set metadata.
  ///
  /// Example:
  /// ```dart
  /// await platform.setMediaMetadata(playerId, const MediaMetadata(
  ///   title: 'My Video',
  ///   artist: 'Channel Name',
  ///   artworkUrl: 'https://example.com/thumbnail.jpg',
  /// ));
  /// ```
  Future<void> setMediaMetadata(int playerId, MediaMetadata metadata) {
    throw UnimplementedError('setMediaMetadata() has not been implemented.');
  }

  // ==================== Video Quality Selection ====================

  /// Gets the available video quality tracks for adaptive streams.
  ///
  /// Returns a list of available quality options for HLS or DASH streams.
  /// The list always includes [VideoQualityTrack.auto] as the first option.
  ///
  /// For non-adaptive streams (e.g., direct MP4 files), returns a single-element
  /// list containing only [VideoQualityTrack.auto].
  ///
  /// Example:
  /// ```dart
  /// final tracks = await platform.getVideoQualities(playerId);
  /// for (final track in tracks) {
  ///   print('${track.displayLabel}: ${track.resolution}');
  /// }
  /// ```
  Future<List<VideoQualityTrack>> getVideoQualities(int playerId) {
    throw UnimplementedError('getVideoQualities() has not been implemented.');
  }

  /// Sets the video quality for adaptive streams.
  ///
  /// Pass [VideoQualityTrack.auto] to enable automatic quality selection
  /// based on network conditions (ABR - Adaptive Bitrate).
  ///
  /// Pass a specific track from [getVideoQualities] to lock to that quality.
  ///
  /// Returns `true` if the quality was set successfully, `false` if the
  /// track is not available or the stream doesn't support quality selection.
  ///
  /// Example:
  /// ```dart
  /// // Lock to 1080p
  /// final tracks = await platform.getVideoQualities(playerId);
  /// final hd1080 = tracks.firstWhere((t) => t.height == 1080);
  /// await platform.setVideoQuality(playerId, hd1080);
  ///
  /// // Switch back to auto
  /// await platform.setVideoQuality(playerId, VideoQualityTrack.auto);
  /// ```
  Future<bool> setVideoQuality(int playerId, VideoQualityTrack track) {
    throw UnimplementedError('setVideoQuality() has not been implemented.');
  }

  /// Gets the currently selected video quality track.
  ///
  /// Returns [VideoQualityTrack.auto] if automatic quality selection is enabled.
  /// Returns the specific track if a manual selection was made.
  ///
  /// Note: Even when auto is selected, the actual playing quality may differ.
  /// To get the currently playing quality (not the selection), listen to
  /// [SelectedQualityChangedEvent] with `isAutoSwitch: true`.
  Future<VideoQualityTrack> getCurrentVideoQuality(int playerId) {
    throw UnimplementedError('getCurrentVideoQuality() has not been implemented.');
  }

  /// Returns whether video quality selection is supported for the current media.
  ///
  /// Returns `true` for HLS and DASH streams that have multiple quality levels.
  /// Returns `false` for:
  /// - Non-adaptive streams (direct video files)
  /// - Streams with only one quality level
  /// - Platforms that don't support quality selection
  ///
  /// This should be checked before showing quality selection UI to users.
  Future<bool> isQualitySelectionSupported(int playerId) {
    throw UnimplementedError('isQualitySelectionSupported() has not been implemented.');
  }

  // ==================== Background Playback ====================

  /// Sets whether background playback is enabled.
  ///
  /// When enabled, audio continues playing when the app is backgrounded.
  /// The video will pause but audio will continue.
  ///
  /// **Platform requirements:**
  /// - **iOS**: Requires `UIBackgroundModes` with `audio` in Info.plist
  /// - **Android**: Requires foreground service permission (Android 14+)
  /// - **macOS**: Generally works without special configuration
  /// - **Web**: Not supported (returns `false`)
  /// - **Windows/Linux**: Not supported (returns `false`)
  ///
  /// Returns `true` if background playback was successfully enabled/disabled,
  /// `false` if the platform doesn't support it or isn't configured correctly.
  ///
  /// Example:
  /// ```dart
  /// // Enable background playback
  /// final success = await platform.setBackgroundPlayback(playerId, true);
  /// if (!success) {
  ///   print('Background playback not supported or not configured');
  /// }
  /// ```
  Future<bool> setBackgroundPlayback(int playerId, {required bool enabled}) {
    throw UnimplementedError('setBackgroundPlayback() has not been implemented.');
  }

  /// Returns whether background playback is supported on this platform.
  ///
  /// Returns `true` on iOS, Android, and macOS (with proper configuration).
  /// Returns `false` on Web, Windows, and Linux.
  ///
  /// Note: Even if this returns `true`, background playback may still fail
  /// if the platform isn't properly configured (e.g., missing Info.plist entry).
  Future<bool> isBackgroundPlaybackSupported() {
    throw UnimplementedError('isBackgroundPlaybackSupported() has not been implemented.');
  }

  // ==================== Video Metadata ====================

  /// Gets the technical metadata extracted from the current video.
  ///
  /// Returns metadata about the video's encoding, resolution, bitrate, frame
  /// rate, and container format. This information is extracted from the video
  /// after it is loaded.
  ///
  /// Returns `null` if:
  /// - The player is not initialized
  /// - Metadata has not been extracted yet
  /// - The platform doesn't support metadata extraction
  ///
  /// Example:
  /// ```dart
  /// final metadata = await platform.getVideoMetadata(playerId);
  /// if (metadata != null) {
  ///   print('Codec: ${metadata.videoCodec}');
  ///   print('Resolution: ${metadata.resolution}');
  ///   print('Bitrate: ${metadata.videoBitrateInMbps} Mbps');
  /// }
  /// ```
  Future<VideoMetadata?> getVideoMetadata(int playerId) {
    throw UnimplementedError('getVideoMetadata() has not been implemented.');
  }

  /// Extracts video metadata from a source without keeping a player active.
  ///
  /// This is useful for:
  /// - Showing video info (duration, resolution) in file browsers
  /// - Validating video files before playback
  /// - Pre-loading metadata for better UX
  ///
  /// Creates a temporary player internally to extract metadata, then disposes it.
  /// This uses the same native player infrastructure as regular playback.
  ///
  /// The [timeout] parameter specifies the maximum time to wait for metadata
  /// extraction. Defaults to 30 seconds.
  ///
  /// Throws [MetadataExtractionException] if extraction fails (network error,
  /// invalid source, timeout, unsupported format).
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final metadata = await platform.extractMetadata(
  ///     VideoSource.file('/path/to/video.mp4'),
  ///   );
  ///   print('Duration: ${metadata.duration}');
  ///   print('Resolution: ${metadata.resolution}');
  /// } on MetadataExtractionException catch (e) {
  ///   print('Failed: ${e.code} - ${e.message}');
  /// }
  /// ```
  Future<VideoMetadata> extractMetadata(VideoSource source, {Duration timeout = const Duration(seconds: 30)}) async {
    int? playerId;
    StreamSubscription<VideoPlayerEvent>? subscription;

    try {
      // Create a temporary player with minimal options
      playerId = await create(source: source);

      // Wait for metadata extraction event or timeout
      final completer = Completer<VideoMetadata>();

      subscription = events(playerId).listen((event) {
        if (event is VideoMetadataExtractedEvent) {
          if (!completer.isCompleted) {
            completer.complete(event.metadata);
          }
        } else if (event is ErrorEvent) {
          if (!completer.isCompleted) {
            completer.completeError(MetadataExtractionException(event.code ?? 'ERROR', event.message));
          }
        }
      });

      // Also try to fetch metadata directly (in case event was already sent)
      final existingMetadata = await getVideoMetadata(playerId);
      if (existingMetadata != null && existingMetadata.isNotEmpty && !completer.isCompleted) {
        completer.complete(existingMetadata);
      }

      // Wait with timeout
      final metadata = await completer.future.timeout(
        timeout,
        onTimeout: () => throw MetadataExtractionException(
          'TIMEOUT',
          'Metadata extraction timed out after ${timeout.inSeconds} seconds',
        ),
      );

      return metadata;
    } on MetadataExtractionException {
      rethrow;
    } catch (e) {
      throw MetadataExtractionException('EXTRACTION_FAILED', 'Failed to extract metadata: $e');
    } finally {
      // Clean up
      await subscription?.cancel();
      if (playerId != null) {
        await dispose(playerId);
      }
    }
  }

  // ==================== Casting ====================

  /// Returns whether casting is supported on this platform.
  ///
  /// Returns `true` on platforms that support casting:
  /// - **iOS/macOS**: AirPlay support (built-in, no configuration required)
  /// - **Android**: Chromecast support (requires Google Cast SDK)
  /// - **Web**: Remote Playback API support (browser-dependent)
  ///
  /// Returns `false` on platforms without casting support:
  /// - **Windows**: Not supported
  /// - **Linux**: Not supported
  ///
  /// Note: Even if this returns `true`, casting may still fail if:
  /// - No cast devices are available on the network
  /// - The platform isn't properly configured (e.g., Android missing Cast SDK)
  Future<bool> isCastingSupported() {
    throw UnimplementedError('isCastingSupported() has not been implemented.');
  }

  /// Gets the list of currently available cast devices on the network.
  ///
  /// Returns an empty list if:
  /// - Casting is not supported on this platform
  /// - No cast devices are available
  /// - Casting is disabled ([VideoPlayerOptions.allowCasting] is `false`)
  ///
  /// The list is updated automatically when devices appear or disappear,
  /// and [CastDevicesChangedEvent] is emitted when the list changes.
  ///
  /// Example:
  /// ```dart
  /// final devices = await platform.getAvailableCastDevices();
  /// for (final device in devices) {
  ///   print('${device.name} (${device.type})');
  /// }
  /// ```
  Future<List<CastDevice>> getAvailableCastDevices(int playerId) {
    throw UnimplementedError('getAvailableCastDevices() has not been implemented.');
  }

  /// Starts casting to the specified device.
  ///
  /// Returns `true` if casting was started successfully, `false` otherwise.
  ///
  /// Reasons for failure:
  /// - Casting is not supported on this platform
  /// - Casting is disabled ([VideoPlayerOptions.allowCasting] is `false`)
  /// - The device is no longer available
  /// - The connection to the device failed
  ///
  /// When successful, a [CastStateChangedEvent] with [CastState.connecting]
  /// is emitted, followed by [CastState.connected] when the connection is
  /// established.
  ///
  /// If [device] is `null`, the platform will show a device picker dialog
  /// allowing the user to select a device. This is the recommended approach
  /// for most use cases.
  ///
  /// Example:
  /// ```dart
  /// // Show device picker
  /// final success = await platform.startCasting(playerId);
  ///
  /// // Or connect to a specific device
  /// final devices = await platform.getAvailableCastDevices(playerId);
  /// if (devices.isNotEmpty) {
  ///   final success = await platform.startCasting(playerId, device: devices.first);
  ///   if (success) {
  ///     print('Casting to ${devices.first.name}');
  ///   }
  /// }
  /// ```
  Future<bool> startCasting(int playerId, {CastDevice? device}) {
    throw UnimplementedError('startCasting() has not been implemented.');
  }

  /// Stops casting and returns playback to the local device.
  ///
  /// Returns `true` if casting was stopped successfully, `false` if not
  /// currently casting or if the operation failed.
  ///
  /// When successful, a [CastStateChangedEvent] with [CastState.disconnecting]
  /// is emitted, followed by [CastState.notConnected] when the disconnection
  /// is complete.
  ///
  /// Example:
  /// ```dart
  /// final success = await platform.stopCasting(playerId);
  /// ```
  Future<bool> stopCasting(int playerId) {
    throw UnimplementedError('stopCasting() has not been implemented.');
  }

  /// Gets the current casting state.
  ///
  /// Returns [CastState.notConnected] if:
  /// - No casting session is active
  /// - Casting is not supported
  /// - Casting is disabled
  Future<CastState> getCastState(int playerId) {
    throw UnimplementedError('getCastState() has not been implemented.');
  }

  /// Gets the currently connected cast device, if any.
  ///
  /// Returns `null` if:
  /// - No casting session is active
  /// - Casting is not supported
  /// - Casting is disabled
  Future<CastDevice?> getCurrentCastDevice(int playerId) {
    throw UnimplementedError('getCurrentCastDevice() has not been implemented.');
  }

  // ==================== External Subtitles ====================

  /// Adds an external subtitle track from a [SubtitleSource].
  ///
  /// This allows loading subtitle files (SRT, VTT, ASS, SSA, TTML) from various
  /// sources and adding them as a selectable subtitle track.
  ///
  /// Supported source types:
  /// - [SubtitleSource.network] — HTTP/HTTPS URLs
  /// - [SubtitleSource.file] — Local file paths
  /// - [SubtitleSource.asset] — Flutter assets
  /// - [SubtitleSource.from] — Auto-detect from string
  ///
  /// The subtitle format is auto-detected from the file extension if not
  /// provided in the source. Throws [ArgumentError] if format cannot be detected.
  ///
  /// **Platform-specific rendering behavior:**
  /// - **Android/Web**: External subtitles are automatically converted to WebVTT
  ///   and can be rendered natively when [SubtitleRenderMode.native] is active.
  /// - **iOS/macOS**: External subtitles always use Flutter rendering, regardless
  ///   of the subtitle render mode setting. This is intentional - AVPlayer doesn't
  ///   support adding subtitle tracks programmatically. The returned [ExternalSubtitleTrack]
  ///   includes parsed `cues` for Flutter overlay rendering.
  /// - **All platforms**: Embedded subtitles (already in the video) use native
  ///   rendering when [SubtitleRenderMode.native] is active.
  ///
  /// Returns the created [ExternalSubtitleTrack] if successful, or `null` if
  /// the subtitle could not be loaded (e.g., network error, file not found, parse error).
  ///
  /// Example:
  /// ```dart
  /// // From URL
  /// final track = await platform.addExternalSubtitle(
  ///   playerId,
  ///   SubtitleSource.network(
  ///     'https://example.com/subtitles.srt',
  ///     label: 'English',
  ///     language: 'en',
  ///   ),
  /// );
  ///
  /// // From local file
  /// final track = await platform.addExternalSubtitle(
  ///   playerId,
  ///   SubtitleSource.file('/path/to/subtitles.vtt', label: 'Spanish'),
  /// );
  ///
  /// // Auto-detect source type
  /// final track = await platform.addExternalSubtitle(
  ///   playerId,
  ///   SubtitleSource.from('https://example.com/subs.vtt'),
  /// );
  ///
  /// if (track != null) {
  ///   await platform.setSubtitleTrack(playerId, track);
  /// }
  /// ```
  Future<ExternalSubtitleTrack?> addExternalSubtitle(int playerId, SubtitleSource source) {
    throw UnimplementedError('addExternalSubtitle() has not been implemented.');
  }

  /// Removes an external subtitle track.
  ///
  /// Returns `true` if the track was removed successfully, `false` if the track
  /// was not found or could not be removed.
  ///
  /// If the removed track is currently selected, subtitles will be disabled.
  Future<bool> removeExternalSubtitle(int playerId, String trackId) {
    throw UnimplementedError('removeExternalSubtitle() has not been implemented.');
  }

  /// Gets all external subtitle tracks that have been added.
  ///
  /// Returns an empty list if no external subtitles have been added.
  /// This does not include embedded subtitle tracks from the video file.
  Future<List<ExternalSubtitleTrack>> getExternalSubtitles(int playerId) {
    throw UnimplementedError('getExternalSubtitles() has not been implemented.');
  }

  // ==================== Window Fullscreen ====================

  /// Sets the application window to fullscreen mode.
  ///
  /// This controls the native window fullscreen state on desktop platforms.
  /// On mobile platforms, this has no effect (use [enterFullscreen] instead).
  ///
  /// When [fullscreen] is `true`, the window enters native fullscreen mode
  /// (maximized, hiding menu bar and dock on macOS).
  /// When `false`, the window returns to its normal state.
  ///
  /// **Platform support:**
  /// - **macOS**: Toggles `NSWindow.toggleFullScreen()`
  /// - **Windows/Linux**: Toggles native window fullscreen (not yet implemented)
  /// - **iOS/Android/Web**: No effect (returns immediately)
  ///
  /// This is intended for use with Flutter controls mode, where the fullscreen
  /// route is pushed via Flutter navigation but the window should also be
  /// maximized for a true fullscreen experience.
  Future<void> setWindowFullscreen({required bool fullscreen}) async {
    // Default implementation does nothing (mobile/web platforms)
  }

  // ==================== Codec Compatibility ====================

  /// Checks if a specific codec is supported on the current platform.
  ///
  /// This performs a pre-flight check to determine whether the platform can
  /// play a video/audio codec before attempting playback.
  ///
  /// **Platform implementations:**
  /// - **Web**: Uses `MediaSource.isTypeSupported()` and `canPlayType()`
  /// - **iOS/macOS**: Uses `AVURLAsset.isPlayableExtendedMIMEType()`
  /// - **Android**: Uses `MediaCodecList.findDecoderForFormat()`
  ///
  /// Returns a [CodecCompatibility] with:
  /// - [CodecSupportLevel.supported] - Confirmed playable
  /// - [CodecSupportLevel.probablySupported] - Likely playable (e.g., "probably" from canPlayType)
  /// - [CodecSupportLevel.notSupported] - Cannot play
  /// - [CodecSupportLevel.unknown] - Unable to determine
  ///
  /// Example:
  /// ```dart
  /// final codec = CodecInfo(fourcc: 'avc1', name: 'H.264', codecString: 'avc1.64001F');
  /// final result = await platform.checkCodecSupport(codec);
  /// if (!result.isPlayable) {
  ///   print('Cannot play ${codec.name}: ${result.message}');
  ///   print('Try: ${result.alternativeCodecs.join(", ")}');
  /// }
  /// ```
  Future<CodecCompatibility> checkCodecSupport(CodecInfo codec) {
    throw UnimplementedError('checkCodecSupport() has not been implemented.');
  }

  /// Checks if multiple codecs are supported on the current platform.
  ///
  /// More efficient than calling [checkCodecSupport] multiple times as it
  /// batches the platform calls.
  ///
  /// Returns a list of [CodecCompatibility] results in the same order as
  /// the input codecs.
  ///
  /// Example:
  /// ```dart
  /// final codecs = [
  ///   CodecInfo(fourcc: 'avc1', name: 'H.264'),
  ///   CodecInfo(fourcc: 'hvc1', name: 'HEVC'),
  ///   CodecInfo(fourcc: 'av01', name: 'AV1'),
  /// ];
  /// final results = await platform.checkCodecsSupport(codecs);
  /// final unsupported = results.where((r) => !r.isPlayable);
  /// ```
  Future<List<CodecCompatibility>> checkCodecsSupport(List<CodecInfo> codecs) {
    throw UnimplementedError('checkCodecsSupport() has not been implemented.');
  }

  /// Gets a list of commonly supported codec names on the current platform.
  ///
  /// Returns a list of codec names (e.g., ["H.264", "HEVC", "AAC", "Opus"])
  /// that the platform is known to support.
  ///
  /// This is useful for:
  /// - Showing users what formats their device supports
  /// - Pre-filtering content before detailed codec checks
  /// - Providing quick codec support overview
  ///
  /// Note: This returns commonly supported codecs, not an exhaustive list.
  /// For accurate codec support checking, use [checkCodecSupport].
  Future<List<String>> getSupportedCodecs() {
    throw UnimplementedError('getSupportedCodecs() has not been implemented.');
  }
}

/// Private default implementation using [PigeonMethodChannelBase].
///
/// This is used as a fallback when no platform-specific implementation is registered.
/// In practice, this should never be used in production as platform packages
/// (iOS, Android, Web, macOS, etc.) register their own implementations.
class _DefaultMethodChannelProVideoPlayer extends PigeonMethodChannelBase {
  _DefaultMethodChannelProVideoPlayer() : super('dev.pro_video_player/methods');

  @override
  Widget buildView(int playerId, {ControlsMode controlsMode = ControlsMode.none}) =>
      const Center(child: Text('No platform implementation registered'));
}
