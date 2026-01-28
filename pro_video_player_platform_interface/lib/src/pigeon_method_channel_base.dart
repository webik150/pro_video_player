import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show protected;

import 'pigeon_generated/messages.g.dart';
import 'pro_video_player_logger.dart';
import 'pro_video_player_platform.dart';
import 'types/types.dart';

/// Base class for platform implementations using Pigeon-generated type-safe APIs.
///
/// This class provides complete type-safe platform channel communication using
/// Pigeon-generated code for all platform methods and events.
///
/// Implements [ProVideoPlayerFlutterApi] to receive type-safe callbacks from native platforms.
abstract class PigeonMethodChannelBase extends ProVideoPlayerPlatform implements ProVideoPlayerFlutterApi {
  /// Creates a [PigeonMethodChannelBase] with the given [channelPrefix].
  PigeonMethodChannelBase(this.channelPrefix)
    : _hostApi = ProVideoPlayerHostApi(),
      _eventStreamControllers = {},
      _batteryStreamController = StreamController<BatteryInfo>.broadcast();

  /// Whether the FlutterApi has been set up.
  bool _isFlutterApiSetUp = false;

  /// Ensures the FlutterApi is set up before use.
  ///
  /// This is called lazily to avoid accessing the binding before it's initialized.
  void _ensureFlutterApiSetUp() {
    if (!_isFlutterApiSetUp) {
      ProVideoPlayerFlutterApi.setUp(this);
      _isFlutterApiSetUp = true;
    }
  }

  /// The channel prefix used for method and event channels.
  final String channelPrefix;

  /// The Pigeon-generated host API for type-safe communication.
  final ProVideoPlayerHostApi _hostApi;

  /// Event stream controllers for each player.
  final Map<int, StreamController<VideoPlayerEvent>> _eventStreamControllers;

  /// Battery updates stream controller.
  final StreamController<BatteryInfo> _batteryStreamController;

  // ==================== Core Player Methods ====================

  @override
  Future<int> create({required VideoSource source, VideoPlayerOptions options = const VideoPlayerOptions()}) async {
    // Ensure FlutterApi is set up before creating a player
    _ensureFlutterApiSetUp();

    final sourceMessage = _convertVideoSource(source);
    final optionsMessage = _convertOptions(options);

    final playerId = await _hostApi.create(sourceMessage, optionsMessage);

    // Create event stream controller immediately to avoid race condition
    // where native sends events (like track discovery) before Dart subscribes.
    // Without this, events sent during initialization would be dropped.
    _eventStreamControllers[playerId] = StreamController<VideoPlayerEvent>.broadcast();

    return playerId;
  }

  @override
  Future<void> dispose(int playerId) async {
    await _hostApi.dispose(playerId);
    // Clean up event stream controller
    await _eventStreamControllers[playerId]?.close();
    _eventStreamControllers.remove(playerId);
  }

  @override
  Future<void> play(int playerId) async {
    await _hostApi.play(playerId);
  }

  @override
  Future<void> pause(int playerId) async {
    await _hostApi.pause(playerId);
  }

  @override
  Future<void> stop(int playerId) async {
    await _hostApi.stop(playerId);
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    ProVideoPlayerLogger.log(
      'seekTo() called for playerId: $playerId, position: $position',
      tag: 'PigeonMethodChannel',
    );
    await _hostApi.seekTo(playerId, position.inMilliseconds);
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {
    ProVideoPlayerLogger.log(
      'setPlaybackSpeed() called for playerId: $playerId, speed: $speed',
      tag: 'PigeonMethodChannel',
    );
    await _hostApi.setPlaybackSpeed(playerId, speed);
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {
    await _hostApi.setVolume(playerId, volume);
  }

  @override
  Future<Duration> getPosition(int playerId) async {
    final positionMs = await _hostApi.getPosition(playerId);
    return Duration(milliseconds: positionMs);
  }

  @override
  Future<Duration> getDuration(int playerId) async {
    final durationMs = await _hostApi.getDuration(playerId);
    return Duration(milliseconds: durationMs);
  }

  @override
  Future<PlatformInfo> getPlatformInfo() async {
    final message = await _hostApi.getPlatformInfo();
    return _convertPlatformInfo(message);
  }

  @override
  Future<void> setVerboseLogging({required bool enabled}) async {
    await _hostApi.setVerboseLogging(enabled);
  }

  // ==================== Platform Capabilities ====================

  @override
  Future<bool> supportsPictureInPicture() async => _hostApi.supportsPictureInPicture();

  @override
  Future<bool> supportsFullscreen() async => _hostApi.supportsFullscreen();

  @override
  Future<bool> supportsBackgroundPlayback() async => _hostApi.supportsBackgroundPlayback();

  @override
  Future<bool> supportsCasting() async => _hostApi.supportsCasting();

  @override
  Future<bool> supportsAirPlay() async => _hostApi.supportsAirPlay();

  @override
  Future<bool> supportsChromecast() async => _hostApi.supportsChromecast();

  @override
  Future<bool> supportsRemotePlayback() async => _hostApi.supportsRemotePlayback();

  @override
  Future<bool> supportsQualitySelection() async => _hostApi.supportsQualitySelection();

  @override
  Future<bool> supportsPlaybackSpeedControl() async => _hostApi.supportsPlaybackSpeedControl();

  @override
  Future<bool> supportsSubtitles() async => _hostApi.supportsSubtitles();

  @override
  Future<bool> supportsExternalSubtitles() async => _hostApi.supportsExternalSubtitles();

  @override
  Future<bool> supportsAudioTrackSelection() async => _hostApi.supportsAudioTrackSelection();

  @override
  Future<bool> supportsChapters() async => _hostApi.supportsChapters();

  @override
  Future<bool> supportsVideoMetadataExtraction() async => _hostApi.supportsVideoMetadataExtraction();

  @override
  Future<bool> supportsNetworkMonitoring() async => _hostApi.supportsNetworkMonitoring();

  @override
  Future<bool> supportsBandwidthEstimation() async => _hostApi.supportsBandwidthEstimation();

  @override
  Future<bool> supportsAdaptiveBitrate() async => _hostApi.supportsAdaptiveBitrate();

  @override
  Future<bool> supportsHLS() async => _hostApi.supportsHLS();

  @override
  Future<bool> supportsDASH() async => _hostApi.supportsDASH();

  @override
  Future<bool> supportsDeviceVolumeControl() async => _hostApi.supportsDeviceVolumeControl();

  @override
  Future<bool> supportsScreenBrightnessControl() async => _hostApi.supportsScreenBrightnessControl();

  // ==================== Device Controls ====================

  @override
  Future<double> getDeviceVolume() async => _hostApi.getDeviceVolume();

  @override
  Future<void> setDeviceVolume(double volume) async => _hostApi.setDeviceVolume(volume);

  @override
  Future<double> getScreenBrightness() async => _hostApi.getScreenBrightness();

  @override
  Future<void> setScreenBrightness(double brightness) async => _hostApi.setScreenBrightness(brightness);

  @override
  Future<BatteryInfo?> getBatteryInfo() async {
    final message = await _hostApi.getBatteryInfo();
    if (message == null) return null;
    return BatteryInfo(percentage: message.percentage, isCharging: message.isCharging);
  }

  @override
  Stream<BatteryInfo> get batteryUpdates => _batteryStreamController.stream;

  // ==================== Player Configuration ====================

  @override
  Future<void> setLooping(int playerId, bool looping) async => _hostApi.setLooping(playerId, looping);

  @override
  Future<void> setScalingMode(int playerId, VideoScalingMode mode) async {
    final pigeonMode = switch (mode) {
      VideoScalingMode.fit => VideoScalingModeEnum.fit,
      VideoScalingMode.fill => VideoScalingModeEnum.fill,
      VideoScalingMode.stretch => VideoScalingModeEnum.stretch,
    };
    await _hostApi.setScalingMode(playerId, pigeonMode);
  }

  @override
  Future<void> setControlsMode(int playerId, ControlsMode controlsMode) async {
    final pigeonMode = switch (controlsMode) {
      ControlsMode.none => ControlsModeEnum.videoOnly,
      ControlsMode.flutter => ControlsModeEnum.flutterControls,
      ControlsMode.native => ControlsModeEnum.nativeControls,
    };
    await _hostApi.setControlsMode(playerId, pigeonMode);
  }

  // ==================== Subtitle Management ====================

  @override
  Future<void> setSubtitleTrack(int playerId, SubtitleTrack? track) async {
    final message = track == null
        ? null
        : SubtitleTrackMessage(id: track.id, label: track.label, language: track.language, isDefault: track.isDefault);
    await _hostApi.setSubtitleTrack(playerId, message);
  }

  @override
  Future<void> setSubtitleRenderMode(int playerId, SubtitleRenderMode mode) async {
    final pigeonMode = switch (mode) {
      SubtitleRenderMode.auto => SubtitleRenderModeEnum.auto,
      SubtitleRenderMode.native => SubtitleRenderModeEnum.native,
      SubtitleRenderMode.flutter => SubtitleRenderModeEnum.flutter,
    };
    await _hostApi.setSubtitleRenderMode(playerId, pigeonMode);
  }

  @override
  Future<ExternalSubtitleTrack?> addExternalSubtitle(int playerId, SubtitleSource source) async {
    final message = SubtitleSourceMessage(
      type: _getSubtitleSourceType(source),
      path: _getSubtitlePath(source),
      format: source.format != null ? _convertSubtitleFormat(source.format!) : SubtitleFormatEnum.srt,
      label: source.label,
      language: source.language,
      isDefault: source.isDefault,
    );
    final result = await _hostApi.addExternalSubtitle(playerId, message);
    if (result == null) return null;
    return ExternalSubtitleTrack(
      id: result.id,
      label: result.label,
      language: result.language,
      isDefault: result.isDefault,
      path: result.path,
      sourceType: result.sourceType,
      format: _convertFromPigeonSubtitleFormat(result.format),
    );
  }

  @override
  Future<bool> removeExternalSubtitle(int playerId, String trackId) async =>
      _hostApi.removeExternalSubtitle(playerId, trackId);

  @override
  Future<List<ExternalSubtitleTrack>> getExternalSubtitles(int playerId) async {
    final messages = await _hostApi.getExternalSubtitles(playerId);
    return messages
        .whereType<ExternalSubtitleTrackMessage>()
        .map(
          (msg) => ExternalSubtitleTrack(
            id: msg.id,
            label: msg.label,
            language: msg.language,
            isDefault: msg.isDefault,
            path: msg.path,
            sourceType: msg.sourceType,
            format: _convertFromPigeonSubtitleFormat(msg.format),
          ),
        )
        .toList();
  }

  // ==================== Audio Management ====================

  @override
  Future<void> setAudioTrack(int playerId, AudioTrack? track) async {
    final message = track == null
        ? null
        : AudioTrackMessage(id: track.id, label: track.label, language: track.language, isDefault: track.isDefault);
    await _hostApi.setAudioTrack(playerId, message);
  }

  // ==================== Picture-in-Picture ====================

  @override
  Future<bool> enterPip(int playerId, {PipOptions options = const PipOptions()}) async {
    final message = PipOptionsMessage(
      aspectRatio: options.aspectRatio,
      autoEnterOnBackground: options.autoEnterOnBackground,
    );
    return _hostApi.enterPip(playerId, message);
  }

  @override
  Future<void> exitPip(int playerId) async => _hostApi.exitPip(playerId);

  @override
  Future<bool> isPipSupported() async {
    final result = await _hostApi.isPipSupported();
    return result;
  }

  @override
  Future<void> setPipActions(int playerId, List<PipAction>? actions) async {
    final messages =
        actions?.map((action) {
          final type = switch (action.type) {
            PipActionType.playPause => PipActionTypeEnum.playPause,
            PipActionType.skipPrevious => PipActionTypeEnum.skipPrevious,
            PipActionType.skipNext => PipActionTypeEnum.skipNext,
            PipActionType.skipBackward => PipActionTypeEnum.skipBackward,
            PipActionType.skipForward => PipActionTypeEnum.skipForward,
          };
          final skipInterval = (action.type == PipActionType.skipBackward || action.type == PipActionType.skipForward)
              ? action.skipInterval.inMilliseconds
              : null;
          return PipActionMessage(type: type, skipIntervalMs: skipInterval);
        }).toList() ??
        [];
    await _hostApi.setPipActions(playerId, messages);
  }

  // ==================== Fullscreen ====================

  @override
  Future<bool> enterFullscreen(int playerId) async => _hostApi.enterFullscreen(playerId);

  @override
  Future<void> exitFullscreen(int playerId) async => _hostApi.exitFullscreen(playerId);

  @override
  Future<void> setWindowFullscreen({required bool fullscreen}) async => _hostApi.setWindowFullscreen(fullscreen);

  // ==================== Background Playback ====================

  @override
  Future<bool> setBackgroundPlayback(int playerId, {required bool enabled}) async =>
      _hostApi.setBackgroundPlayback(playerId, enabled);

  @override
  Future<bool> isBackgroundPlaybackSupported() async => _hostApi.isBackgroundPlaybackSupported();

  // ==================== Quality Selection ====================

  @override
  Future<List<VideoQualityTrack>> getVideoQualities(int playerId) async {
    final messages = await _hostApi.getVideoQualities(playerId);
    return messages
        .whereType<VideoQualityTrackMessage>()
        .map(
          (msg) => VideoQualityTrack(
            id: msg.id,
            bitrate: msg.bitrate ?? 0,
            width: msg.width ?? 0,
            height: msg.height ?? 0,
            label: msg.label ?? '',
            isDefault: msg.isDefault ?? false,
          ),
        )
        .toList();
  }

  @override
  Future<bool> setVideoQuality(int playerId, VideoQualityTrack track) async {
    final message = VideoQualityTrackMessage(
      id: track.id,
      bitrate: track.bitrate,
      width: track.width,
      height: track.height,
      // frameRate field removed from Pigeon schema
      label: track.label.isEmpty ? null : track.label,
      isDefault: track.isDefault,
    );
    return _hostApi.setVideoQuality(playerId, message);
  }

  @override
  Future<VideoQualityTrack> getCurrentVideoQuality(int playerId) async {
    final message = await _hostApi.getCurrentVideoQuality(playerId);
    return VideoQualityTrack(
      id: message.id,
      bitrate: message.bitrate ?? 0,
      width: message.width ?? 0,
      height: message.height ?? 0,
      label: message.label ?? '',
      isDefault: message.isDefault ?? false,
    );
  }

  @override
  Future<bool> isQualitySelectionSupported(int playerId) async => _hostApi.isQualitySelectionSupported(playerId);

  // ==================== Video Metadata ====================

  @override
  Future<VideoMetadata?> getVideoMetadata(int playerId) async {
    final message = await _hostApi.getVideoMetadata(playerId);
    if (message == null) return null;
    return VideoMetadata(
      width: message.width,
      height: message.height,
      duration: message.duration != null ? Duration(milliseconds: message.duration!) : null,
      videoCodec: message.videoCodec,
      audioCodec: message.audioCodec,
      videoBitrate: message.bitrate,
      frameRate: message.frameRate,
    );
  }

  @override
  Future<void> setMediaMetadata(int playerId, MediaMetadata metadata) async {
    final message = MediaMetadataMessage(
      title: metadata.title,
      artist: metadata.artist,
      album: metadata.album,
      artworkUrl: metadata.artworkUrl,
    );
    await _hostApi.setMediaMetadata(playerId, message);
  }

  @override
  Future<Uint8List?> extractEmbeddedArtwork(VideoSource source) async {
    final sourceMessage = _convertVideoSource(source);
    return _hostApi.extractEmbeddedArtwork(sourceMessage);
  }

  @override
  Future<Uint8List?> extractVideoFrame(
    VideoSource source, {
    Duration position = Duration.zero,
    int? maxWidth,
    int? maxHeight,
    int? quality,
  }) async {
    final sourceMessage = _convertVideoSource(source);
    return _hostApi.extractVideoFrame(sourceMessage, position.inMilliseconds, maxWidth, maxHeight, quality);
  }

  // ==================== Casting ====================

  @override
  Future<bool> isCastingSupported() async => _hostApi.isCastingSupported();

  @override
  Future<List<CastDevice>> getAvailableCastDevices(int playerId) async {
    final messages = await _hostApi.getAvailableCastDevices(playerId);
    return messages.whereType<CastDeviceMessage>().map((msg) {
      final type = switch (msg.type) {
        CastDeviceTypeEnum.airPlay => CastDeviceType.airPlay,
        CastDeviceTypeEnum.chromecast => CastDeviceType.chromecast,
        CastDeviceTypeEnum.webRemotePlayback => CastDeviceType.webRemotePlayback,
        CastDeviceTypeEnum.unknown => CastDeviceType.unknown,
      };
      return CastDevice(id: msg.id, name: msg.name, type: type);
    }).toList();
  }

  @override
  Future<bool> startCasting(int playerId, {CastDevice? device}) async {
    final message = device == null
        ? null
        : CastDeviceMessage(
            id: device.id,
            name: device.name,
            type: switch (device.type) {
              CastDeviceType.airPlay => CastDeviceTypeEnum.airPlay,
              CastDeviceType.chromecast => CastDeviceTypeEnum.chromecast,
              CastDeviceType.webRemotePlayback => CastDeviceTypeEnum.webRemotePlayback,
              CastDeviceType.unknown => CastDeviceTypeEnum.unknown,
            },
          );
    return _hostApi.startCasting(playerId, message);
  }

  @override
  Future<bool> stopCasting(int playerId) async => _hostApi.stopCasting(playerId);

  @override
  Future<CastState> getCastState(int playerId) async {
    final state = await _hostApi.getCastState(playerId);
    return switch (state) {
      CastStateEnum.notConnected => CastState.notConnected,
      CastStateEnum.connecting => CastState.connecting,
      CastStateEnum.connected => CastState.connected,
      CastStateEnum.disconnecting => CastState.disconnecting,
    };
  }

  @override
  Future<CastDevice?> getCurrentCastDevice(int playerId) async {
    final message = await _hostApi.getCurrentCastDevice(playerId);
    if (message == null) return null;
    final type = switch (message.type) {
      CastDeviceTypeEnum.airPlay => CastDeviceType.airPlay,
      CastDeviceTypeEnum.chromecast => CastDeviceType.chromecast,
      CastDeviceTypeEnum.webRemotePlayback => CastDeviceType.webRemotePlayback,
      CastDeviceTypeEnum.unknown => CastDeviceType.unknown,
    };
    return CastDevice(id: message.id, name: message.name, type: type);
  }

  // ==================== Events ====================

  @override
  Stream<VideoPlayerEvent> events(int playerId) {
    _eventStreamControllers[playerId] ??= StreamController<VideoPlayerEvent>.broadcast();
    return _eventStreamControllers[playerId]!.stream;
  }

  /// Adds an event to the stream for the given player.
  void _addEvent(int playerId, VideoPlayerEvent event) {
    _eventStreamControllers[playerId]?.add(event);
  }

  /// Adds an event from EventChannel to the unified event stream.
  ///
  /// Platform implementations should call this method to forward EventChannel
  /// events to the same stream that receives Pigeon events, ensuring all events
  /// are delivered through a single unified stream.
  @protected
  void addEventChannelEvent(int playerId, VideoPlayerEvent event) {
    _addEvent(playerId, event);
  }

  // ==================== ProVideoPlayerFlutterApi Implementation ====================
  // Low-frequency events received from native platforms via Pigeon @FlutterApi

  @override
  void onEvent(int playerId, VideoPlayerEventMessage event) {
    // Legacy method - kept for EventChannel compatibility
    // High-frequency events (position, buffering, state) use EventChannel
  }

  @override
  void onError(int playerId, String errorCode, String errorMessage) {
    _addEvent(playerId, ErrorEvent(errorMessage, code: errorCode));
  }

  @override
  void onMetadataExtracted(int playerId, VideoMetadataMessage metadata) {
    final videoMetadata = VideoMetadata(
      duration: metadata.duration != null ? Duration(milliseconds: metadata.duration!) : null,
      width: metadata.width,
      height: metadata.height,
      videoCodec: metadata.videoCodec,
      audioCodec: metadata.audioCodec,
      videoBitrate: metadata.bitrate,
      frameRate: metadata.frameRate,
    );
    _addEvent(playerId, VideoMetadataExtractedEvent(videoMetadata));
  }

  @override
  void onPlaybackCompleted(int playerId) {
    _addEvent(playerId, const PlaybackCompletedEvent());
  }

  @override
  void onPipActionTriggered(int playerId, String action) {
    // Convert string action to PipActionType enum
    final actionType = switch (action) {
      'playPause' => PipActionType.playPause,
      'skipPrevious' => PipActionType.skipPrevious,
      'skipNext' => PipActionType.skipNext,
      'skipBackward' => PipActionType.skipBackward,
      'skipForward' => PipActionType.skipForward,
      _ => PipActionType.playPause, // Default fallback
    };
    _addEvent(playerId, PipActionTriggeredEvent(action: actionType));
  }

  @override
  void onCastStateChanged(int playerId, CastStateEnum state, CastDeviceMessage? device) {
    final castState = switch (state) {
      CastStateEnum.notConnected => CastState.notConnected,
      CastStateEnum.connecting => CastState.connecting,
      CastStateEnum.connected => CastState.connected,
      CastStateEnum.disconnecting => CastState.disconnecting,
    };

    CastDevice? castDevice;
    if (device != null) {
      final type = switch (device.type) {
        CastDeviceTypeEnum.airPlay => CastDeviceType.airPlay,
        CastDeviceTypeEnum.chromecast => CastDeviceType.chromecast,
        CastDeviceTypeEnum.webRemotePlayback => CastDeviceType.webRemotePlayback,
        CastDeviceTypeEnum.unknown => CastDeviceType.unknown,
      };
      castDevice = CastDevice(id: device.id, name: device.name, type: type);
    }

    _addEvent(playerId, CastStateChangedEvent(state: castState, device: castDevice));
  }

  @override
  void onSubtitleTracksChanged(int playerId, List<SubtitleTrackMessage?> tracks) {
    ProVideoPlayerLogger.log(
      'onSubtitleTracksChanged: playerId=$playerId, tracks=${tracks.length}',
      tag: 'PigeonCallback',
    );
    final subtitleTracks = tracks
        .whereType<SubtitleTrackMessage>()
        .map(
          (t) => SubtitleTrack(
            id: t.id,
            label: t.label ?? '', // SubtitleTrack requires non-null label
            language: t.language,
            isDefault: t.isDefault ?? false,
          ),
        )
        .toList();
    ProVideoPlayerLogger.log(
      'onSubtitleTracksChanged: emitting event with ${subtitleTracks.length} tracks',
      tag: 'PigeonCallback',
    );
    _addEvent(playerId, SubtitleTracksChangedEvent(subtitleTracks));
  }

  @override
  void onAudioTracksChanged(int playerId, List<AudioTrackMessage?> tracks) {
    ProVideoPlayerLogger.log(
      'onAudioTracksChanged: playerId=$playerId, tracks=${tracks.length}',
      tag: 'PigeonCallback',
    );
    final audioTracks = tracks
        .whereType<AudioTrackMessage>()
        .map(
          (t) => AudioTrack(
            id: t.id,
            label: t.label ?? '', // AudioTrack requires non-null label
            language: t.language,
            isDefault: t.isDefault ?? false,
          ),
        )
        .toList();
    ProVideoPlayerLogger.log(
      'onAudioTracksChanged: emitting event with ${audioTracks.length} tracks',
      tag: 'PigeonCallback',
    );
    _addEvent(playerId, AudioTracksChangedEvent(audioTracks));
  }

  @override
  void onBatteryInfoChanged(BatteryInfoMessage batteryInfo) {
    final battery = BatteryInfo(percentage: batteryInfo.percentage, isCharging: batteryInfo.isCharging);
    _batteryStreamController.add(battery);
  }

  // ==================== Conversion Helpers ====================

  /// Converts a [VideoSource] to a Pigeon [VideoSourceMessage].
  VideoSourceMessage _convertVideoSource(VideoSource source) => switch (source) {
    NetworkVideoSource(:final url, :final headers) => VideoSourceMessage(
      type: VideoSourceType.network,
      url: url,
      headers: headers?.map((k, v) => MapEntry(k as String?, v as String?)),
    ),
    FileVideoSource(:final path) => VideoSourceMessage(type: VideoSourceType.file, path: path),
    AssetVideoSource(:final assetPath) => VideoSourceMessage(type: VideoSourceType.asset, assetPath: assetPath),
    PlaylistVideoSource() => throw StateError(
      'PlaylistVideoSource should be converted to NetworkVideoSource or Playlist before encoding',
    ),
  };

  /// Converts [VideoPlayerOptions] to a Pigeon [VideoPlayerOptionsMessage].
  VideoPlayerOptionsMessage _convertOptions(VideoPlayerOptions options) => VideoPlayerOptionsMessage(
    autoPlay: options.autoPlay,
    looping: options.looping,
    volume: options.volume,
    playbackSpeed: options.playbackSpeed,
    allowBackgroundPlayback: options.allowBackgroundPlayback,
    mixWithOthers: options.mixWithOthers,
    allowPip: options.allowPip,
    autoEnterPipOnBackground: options.autoEnterPipOnBackground,
    subtitleRenderMode: switch (options.subtitleRenderMode) {
      SubtitleRenderMode.auto => SubtitleRenderModeEnum.auto,
      SubtitleRenderMode.native => SubtitleRenderModeEnum.native,
      SubtitleRenderMode.flutter => SubtitleRenderModeEnum.flutter,
    },
    subtitlesEnabled: options.subtitlesEnabled,
    showSubtitlesByDefault: options.showSubtitlesByDefault,
    preferredSubtitleLanguage: options.preferredSubtitleLanguage,
  );

  /// Converts a Pigeon [PlatformInfoMessage] to [PlatformInfo].
  PlatformInfo _convertPlatformInfo(PlatformInfoMessage message) => PlatformInfo(
    platformName: message.platformName,
    nativePlayerType: message.nativePlayerType,
    additionalInfo: message.additionalInfo?.cast<String, dynamic>(),
  );

  VideoSourceType _getSubtitleSourceType(SubtitleSource source) => switch (source) {
    NetworkSubtitleSource() => VideoSourceType.network,
    FileSubtitleSource() => VideoSourceType.file,
    AssetSubtitleSource() => VideoSourceType.asset,
  };

  String _getSubtitlePath(SubtitleSource source) => switch (source) {
    NetworkSubtitleSource(:final url) => url,
    FileSubtitleSource(:final path) => path,
    AssetSubtitleSource(:final assetPath) => assetPath,
  };

  SubtitleFormatEnum _convertSubtitleFormat(SubtitleFormat format) => switch (format) {
    SubtitleFormat.srt => SubtitleFormatEnum.srt,
    SubtitleFormat.vtt => SubtitleFormatEnum.vtt,
    SubtitleFormat.ssa => SubtitleFormatEnum.ssa,
    SubtitleFormat.ass => SubtitleFormatEnum.ass,
    SubtitleFormat.ttml => SubtitleFormatEnum.ttml,
  };

  SubtitleFormat _convertFromPigeonSubtitleFormat(SubtitleFormatEnum format) => switch (format) {
    SubtitleFormatEnum.srt => SubtitleFormat.srt,
    SubtitleFormatEnum.vtt => SubtitleFormat.vtt,
    SubtitleFormatEnum.ssa => SubtitleFormat.ssa,
    SubtitleFormatEnum.ass => SubtitleFormat.ass,
    SubtitleFormatEnum.ttml => SubtitleFormat.ttml,
  };

  // ==================== Codec Compatibility ====================

  @override
  Future<CodecCompatibility> checkCodecSupport(CodecInfo codec) async {
    final message = CodecInfoMessage(
      fourcc: codec.fourcc,
      name: codec.name,
      codecString: codec.codecString,
      mimeType: codec.mimeType,
    );
    final result = await _hostApi.checkCodecSupport(message);
    return _convertCodecCompatibility(result);
  }

  @override
  Future<List<CodecCompatibility>> checkCodecsSupport(List<CodecInfo> codecs) async {
    final messages = codecs
        .map(
          (codec) => CodecInfoMessage(
            fourcc: codec.fourcc,
            name: codec.name,
            codecString: codec.codecString,
            mimeType: codec.mimeType,
          ),
        )
        .toList();
    final results = await _hostApi.checkCodecsSupport(messages);
    return results.whereType<CodecCompatibilityMessage>().map(_convertCodecCompatibility).toList();
  }

  @override
  Future<List<String>> getSupportedCodecs() async {
    final results = await _hostApi.getSupportedCodecs();
    return results.whereType<String>().toList();
  }

  CodecCompatibility _convertCodecCompatibility(CodecCompatibilityMessage message) {
    final codec = CodecInfo(
      fourcc: message.codec.fourcc,
      name: message.codec.name,
      codecString: message.codec.codecString,
      mimeType: message.codec.mimeType,
    );
    final supportLevel = switch (message.supportLevel) {
      CodecSupportLevelEnum.supported => CodecSupportLevel.supported,
      CodecSupportLevelEnum.probablySupported => CodecSupportLevel.probablySupported,
      CodecSupportLevelEnum.notSupported => CodecSupportLevel.notSupported,
      CodecSupportLevelEnum.unknown => CodecSupportLevel.unknown,
    };
    return CodecCompatibility(
      codec: codec,
      supportLevel: supportLevel,
      message: message.message,
      minimumOsVersion: message.minimumOsVersion,
      alternativeCodecs: message.alternativeCodecs?.whereType<String>().toList() ?? const [],
    );
  }
}
