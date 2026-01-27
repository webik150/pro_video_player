import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';
import 'package:web/web.dart' as web;

import 'src/battery_interop.dart' as battery_interop;
import 'src/verbose_logging.dart';
import 'src/web_video_player.dart';

/// The web implementation of [ProVideoPlayerPlatform].
///
/// This class uses HTML5 VideoElement for video playback on web.
class ProVideoPlayerWeb extends ProVideoPlayerPlatform {
  /// Constructs a ProVideoPlayerWeb.
  ProVideoPlayerWeb();

  /// Registers this class as the default instance of [ProVideoPlayerPlatform].
  static void registerWith(Registrar registrar) {
    ProVideoPlayerPlatform.instance = ProVideoPlayerWeb();
  }

  final Map<int, WebVideoPlayer> _players = {};
  int _nextPlayerId = 0;

  // Battery updates stream controller
  StreamController<BatteryInfo>? _batteryUpdatesController;
  void Function()? _batteryCleanup;

  @override
  Future<int> create({required VideoSource source, VideoPlayerOptions options = const VideoPlayerOptions()}) async {
    verboseLog('create() called with source: ${source.runtimeType}', tag: 'Plugin');
    final playerId = _nextPlayerId++;
    final player = WebVideoPlayer(playerId, source, options);
    _players[playerId] = player;
    await player.initialize();
    verboseLog('Player created with ID: $playerId', tag: 'Plugin');
    return playerId;
  }

  @override
  Future<void> dispose(int playerId) async {
    verboseLog('dispose() called for playerId: $playerId', tag: 'Plugin');
    final player = _players.remove(playerId);
    player?.dispose();
  }

  @override
  Future<void> play(int playerId) async {
    verboseLog('play() called for playerId: $playerId', tag: 'Plugin');
    final player = _getPlayer(playerId);
    await player.play();
  }

  @override
  Future<void> pause(int playerId) async {
    verboseLog('pause() called for playerId: $playerId', tag: 'Plugin');
    await _getPlayer(playerId).pause();
  }

  @override
  Future<void> stop(int playerId) async {
    verboseLog('stop() called for playerId: $playerId', tag: 'Plugin');
    await _getPlayer(playerId).stop();
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    verboseLog('seekTo() called for playerId: $playerId, position: $position', tag: 'Plugin');
    if (position.isNegative) {
      throw ArgumentError('Position must be non-negative');
    }
    _getPlayer(playerId).seekTo(position);
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {
    if (speed <= 0.0 || speed > 10.0) {
      throw ArgumentError('Playback speed must be between 0.0 (exclusive) and 10.0');
    }
    _getPlayer(playerId).setPlaybackSpeed(speed);
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {
    if (volume < 0.0 || volume > 1.0) {
      throw ArgumentError('Volume must be between 0.0 and 1.0');
    }
    _getPlayer(playerId).setVolume(volume);
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async => _getPlayer(playerId).looping = looping;

  @override
  Future<void> setScalingMode(int playerId, VideoScalingMode mode) async => _getPlayer(playerId).setScalingMode(mode);

  @override
  Future<void> setSubtitleRenderMode(int playerId, SubtitleRenderMode mode) async =>
      _getPlayer(playerId).setSubtitleRenderMode(mode.name);

  @override
  Future<void> setSubtitleTrack(int playerId, SubtitleTrack? track) async =>
      _getPlayer(playerId).setSubtitleTrack(track);

  @override
  Future<void> setAudioTrack(int playerId, AudioTrack? track) async => _getPlayer(playerId).setAudioTrack(track);

  @override
  Future<Duration> getPosition(int playerId) async {
    final player = _getPlayer(playerId);
    return player.getPosition();
  }

  @override
  Future<Duration> getDuration(int playerId) async {
    final player = _getPlayer(playerId);
    return player.getDuration();
  }

  @override
  Future<bool> enterPip(int playerId, {PipOptions options = const PipOptions()}) async {
    final player = _getPlayer(playerId);
    return player.enterPip();
  }

  @override
  Future<void> exitPip(int playerId) async {
    final player = _getPlayer(playerId);
    await player.exitPip();
  }

  @override
  Future<bool> isPipSupported() async => WebVideoPlayer.isPipSupported();

  @override
  Future<bool> enterFullscreen(int playerId) async {
    final player = _getPlayer(playerId);
    return player.enterFullscreen();
  }

  @override
  Future<void> exitFullscreen(int playerId) async {
    final player = _getPlayer(playerId);
    await player.exitFullscreen();
  }

  @override
  Stream<VideoPlayerEvent> events(int playerId) {
    final player = _players[playerId];
    if (player == null) {
      throw StateError('Player $playerId has not been created');
    }
    return player.events;
  }

  @override
  Widget buildView(int playerId, {ControlsMode controlsMode = ControlsMode.none}) {
    final player = _getPlayer(playerId);
    return HtmlElementView(viewType: player.viewType);
  }

  @override
  Future<void> setVerboseLogging({required bool enabled}) async {
    isVerboseLoggingEnabled = enabled;
    verboseLog('Verbose logging ${enabled ? "enabled" : "disabled"}', tag: 'Plugin');
  }

  @override
  Future<PlatformInfo> getPlatformInfo() async {
    verboseLog('Getting platform info', tag: 'Plugin');

    final supportsPip = _checkPictureInPictureSupport();
    final supportsFullscreen = _checkFullscreenSupport();
    final supportsRemotePlayback = _checkRemotePlaybackSupport();
    final supportsMediaSession = _checkMediaSessionSupport();

    return PlatformInfo(
      platformName: 'Web',
      nativePlayerType: 'HTML5',
      additionalInfo: {
        'userAgent': web.window.navigator.userAgent,
        'pipAvailable': supportsPip,
        'fullscreenAvailable': supportsFullscreen,
        'remotePlaybackAvailable': supportsRemotePlayback,
        'mediaSessionAvailable': supportsMediaSession,
      },
    );
  }

  @override
  Future<bool> supportsPictureInPicture() async => _checkPictureInPictureSupport();

  @override
  Future<bool> supportsFullscreen() async => _checkFullscreenSupport();

  @override
  Future<bool> supportsBackgroundPlayback() async => false; // Web doesn't support background playback

  @override
  Future<bool> supportsCasting() async => _checkRemotePlaybackSupport(); // Remote Playback API for casting

  @override
  Future<bool> supportsAirPlay() async => false; // AirPlay is iOS/macOS only

  @override
  Future<bool> supportsChromecast() async => false; // Chromecast is Android only (web uses Remote Playback API)

  @override
  Future<bool> supportsRemotePlayback() async => _checkRemotePlaybackSupport(); // Browser Remote Playback API

  @override
  Future<bool> supportsQualitySelection() async => true; // Web supports quality selection with HLS/DASH libraries

  @override
  Future<bool> supportsPlaybackSpeedControl() async => true; // HTML5 video supports playback rate

  @override
  Future<bool> supportsSubtitles() async => true; // HTML5 video has TextTrack support

  @override
  Future<bool> supportsExternalSubtitles() async => true; // Can add TextTrack programmatically

  @override
  Future<bool> supportsAudioTrackSelection() async => true; // HTML5 video has AudioTrack support

  @override
  Future<bool> supportsChapters() async => false; // Limited chapter support on web

  @override
  Future<bool> supportsVideoMetadataExtraction() async => true; // Can extract metadata from video element

  @override
  Future<bool> supportsNetworkMonitoring() async => true; // Navigator.connection API

  @override
  Future<bool> supportsBandwidthEstimation() async => false; // Limited bandwidth estimation on web

  @override
  Future<bool> supportsAdaptiveBitrate() async => true; // HLS.js and dash.js support ABR

  @override
  Future<bool> supportsHLS() async => true; // HLS.js library support

  @override
  Future<bool> supportsDASH() async => true; // dash.js library support

  @override
  Future<bool> supportsDeviceVolumeControl() async => false; // Web cannot control device volume

  @override
  Future<bool> supportsScreenBrightnessControl() async => false; // Web cannot control screen brightness

  bool _checkPictureInPictureSupport() {
    try {
      // Check if document.pictureInPictureEnabled exists
      return web.document.pictureInPictureEnabled;
    } catch (e) {
      return false;
    }
  }

  bool _checkFullscreenSupport() {
    try {
      // Check if document.fullscreenEnabled exists
      return web.document.fullscreenEnabled;
    } catch (e) {
      return false;
    }
  }

  bool _checkRemotePlaybackSupport() {
    try {
      // Check if HTMLVideoElement has remote property
      // Note: Remote property may not be available in all browsers
      // We'll do a basic check by trying to create a video element
      final video = web.document.createElement('video') as web.HTMLVideoElement;
      // If we can create the video element, we assume basic support
      // Full remote playback API support is browser-dependent
      return video.readyState >= 0; // Basic check that video element works
    } catch (e) {
      return false;
    }
  }

  bool _checkMediaSessionSupport() {
    try {
      // Check if navigator.mediaSession exists
      // MediaSession is available on most modern browsers
      // MediaSession is a non-nullable type in the web package, so if we can access it, it exists
      web.window.navigator.mediaSession;
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> setMediaMetadata(int playerId, MediaMetadata metadata) async {
    verboseLog('setMediaMetadata() called for playerId: $playerId', tag: 'Plugin');
    _getPlayer(playerId).setMediaMetadata(metadata);
  }

  @override
  Future<List<VideoQualityTrack>> getVideoQualities(int playerId) async => _getPlayer(playerId).getVideoQualities();

  @override
  Future<bool> setVideoQuality(int playerId, VideoQualityTrack track) async =>
      _getPlayer(playerId).setVideoQuality(track);

  @override
  Future<VideoQualityTrack> getCurrentVideoQuality(int playerId) async => _getPlayer(playerId).getCurrentVideoQuality();

  @override
  Future<bool> isQualitySelectionSupported(int playerId) async => _getPlayer(playerId).isQualitySelectionSupported();

  @override
  Future<bool> setBackgroundPlayback(int playerId, {required bool enabled}) async =>
      // Web doesn't have a concept of background playback like mobile platforms
      // Browsers handle audio playback in background tabs automatically
      false;

  @override
  Future<bool> isBackgroundPlaybackSupported() async =>
      // Background playback isn't configurable on web in the same way
      // Browsers may pause video in background tabs based on their own policies
      false;

  @override
  Future<VideoMetadata?> getVideoMetadata(int playerId) async => _getPlayer(playerId).getVideoMetadata();

  @override
  Future<ExternalSubtitleTrack?> addExternalSubtitle(int playerId, SubtitleSource source) async {
    verboseLog('addExternalSubtitle() called for playerId: $playerId, source: ${source.path}', tag: 'Plugin');
    return _getPlayer(playerId).addExternalSubtitle(source);
  }

  @override
  Future<bool> removeExternalSubtitle(int playerId, String trackId) async {
    verboseLog('removeExternalSubtitle() called for playerId: $playerId, trackId: $trackId', tag: 'Plugin');
    return _getPlayer(playerId).removeExternalSubtitle(trackId);
  }

  @override
  Future<List<ExternalSubtitleTrack>> getExternalSubtitles(int playerId) async =>
      _getPlayer(playerId).getExternalSubtitles();

  @override
  Future<BatteryInfo?> getBatteryInfo() async {
    verboseLog('getBatteryInfo() called', tag: 'Plugin');
    final batteryData = await battery_interop.getBatteryInfo(web.window.navigator);
    if (batteryData == null) return null;
    return BatteryInfo(percentage: batteryData['percentage'] as int, isCharging: batteryData['isCharging'] as bool);
  }

  @override
  Stream<BatteryInfo> get batteryUpdates {
    _batteryUpdatesController ??= StreamController<BatteryInfo>.broadcast(
      onListen: () async {
        verboseLog('Battery updates stream listener added', tag: 'Plugin');
        // Send initial battery state
        final initialBattery = await getBatteryInfo();
        if (initialBattery != null) {
          _batteryUpdatesController?.add(initialBattery);
        }

        // Set up battery event listeners
        _batteryCleanup = await battery_interop.setupBatteryListeners(web.window.navigator, (batteryData) {
          final batteryInfo = BatteryInfo(
            percentage: batteryData['percentage'] as int,
            isCharging: batteryData['isCharging'] as bool,
          );
          _batteryUpdatesController?.add(batteryInfo);
        });
      },
      onCancel: () {
        verboseLog('Battery updates stream listener cancelled', tag: 'Plugin');
        _batteryCleanup?.call();
        _batteryCleanup = null;
      },
    );
    return _batteryUpdatesController!.stream;
  }

  @override
  Future<bool> isCastingSupported() async {
    // Check if any player can support casting (they all use the same API)
    // Or check the browser's general support
    if (_players.isEmpty) {
      // No players yet, but we can still check if Remote Playback API exists
      // This is a best-effort check - actual support is checked per-player
      return true; // Assume supported, will be validated when player is created
    }
    return _players.values.first.isCastingSupported();
  }

  @override
  Future<List<CastDevice>> getAvailableCastDevices(int playerId) async {
    verboseLog('getAvailableCastDevices() called for playerId: $playerId', tag: 'Plugin');
    return _getPlayer(playerId).getAvailableCastDevices();
  }

  @override
  Future<bool> startCasting(int playerId, {CastDevice? device}) async {
    verboseLog(
      'startCasting() called for playerId: $playerId, device: ${device?.name ?? 'show picker'}',
      tag: 'Plugin',
    );
    return _getPlayer(playerId).startCasting(device: device);
  }

  @override
  Future<bool> stopCasting(int playerId) async {
    verboseLog('stopCasting() called for playerId: $playerId', tag: 'Plugin');
    return _getPlayer(playerId).stopCasting();
  }

  @override
  Future<CastState> getCastState(int playerId) async {
    verboseLog('getCastState() called for playerId: $playerId', tag: 'Plugin');
    return _getPlayer(playerId).getCastState();
  }

  @override
  Future<CastDevice?> getCurrentCastDevice(int playerId) async {
    verboseLog('getCurrentCastDevice() called for playerId: $playerId', tag: 'Plugin');
    return _getPlayer(playerId).getCurrentCastDevice();
  }

  WebVideoPlayer _getPlayer(int playerId) {
    final player = _players[playerId];
    if (player == null) {
      throw StateError('Player $playerId has not been created');
    }
    return player;
  }

  // ==================== Codec Compatibility ====================

  @override
  Future<CodecCompatibility> checkCodecSupport(CodecInfo codec) async {
    verboseLog('checkCodecSupport() called for codec: ${codec.name} (${codec.fourcc})', tag: 'Plugin');

    // Build MIME type for checking
    final mimeType = _buildMimeType(codec);
    if (mimeType == null) {
      return CodecCompatibility(
        codec: codec,
        supportLevel: CodecSupportLevel.unknown,
        message: 'Unable to determine MIME type for codec ${codec.fourcc}',
      );
    }

    // Check using MediaSource.isTypeSupported first (more reliable)
    final mediaSourceSupported = _checkMediaSourceSupport(mimeType);

    // Also check using canPlayType for broader coverage
    final canPlayResult = _checkCanPlayType(mimeType);

    // Determine support level
    final CodecSupportLevel supportLevel;
    String? message;

    if (mediaSourceSupported) {
      supportLevel = CodecSupportLevel.supported;
      message = 'MediaSource.isTypeSupported returned true';
    } else if (canPlayResult == 'probably') {
      supportLevel = CodecSupportLevel.supported;
      message = 'canPlayType returned "probably"';
    } else if (canPlayResult == 'maybe') {
      supportLevel = CodecSupportLevel.probablySupported;
      message = 'canPlayType returned "maybe" - support not guaranteed';
    } else {
      supportLevel = CodecSupportLevel.notSupported;
      message = 'Codec not supported on this browser';
    }

    // Suggest alternatives for unsupported codecs
    final alternatives = supportLevel == CodecSupportLevel.notSupported ? _suggestAlternatives(codec) : <String>[];

    return CodecCompatibility(
      codec: codec.copyWith(mimeType: mimeType),
      supportLevel: supportLevel,
      message: message,
      alternativeCodecs: alternatives,
    );
  }

  @override
  Future<List<CodecCompatibility>> checkCodecsSupport(List<CodecInfo> codecs) async {
    verboseLog('checkCodecsSupport() called for ${codecs.length} codecs', tag: 'Plugin');

    final results = <CodecCompatibility>[];
    for (final codec in codecs) {
      results.add(await checkCodecSupport(codec));
    }
    return results;
  }

  @override
  Future<List<String>> getSupportedCodecs() async {
    verboseLog('getSupportedCodecs() called', tag: 'Plugin');

    // Return list of commonly supported codecs on modern browsers
    final supportedCodecs = <String>[];

    // Check common video codecs
    final videoCodecs = [
      ('H.264', 'video/mp4; codecs="avc1.42E01E"'),
      ('H.264 High', 'video/mp4; codecs="avc1.640028"'),
      ('VP8', 'video/webm; codecs="vp8"'),
      ('VP9', 'video/webm; codecs="vp09.00.10.08"'),
      ('AV1', 'video/mp4; codecs="av01.0.05M.08"'),
      ('HEVC', 'video/mp4; codecs="hvc1.1.6.L93.B0"'),
    ];

    // Check common audio codecs
    final audioCodecs = [
      ('AAC', 'audio/mp4; codecs="mp4a.40.2"'),
      ('MP3', 'audio/mpeg'),
      ('Opus', 'audio/webm; codecs="opus"'),
      ('Vorbis', 'audio/webm; codecs="vorbis"'),
      ('FLAC', 'audio/flac'),
      ('AC-3', 'audio/mp4; codecs="ac-3"'),
      ('E-AC-3', 'audio/mp4; codecs="ec-3"'),
    ];

    for (final (name, mimeType) in videoCodecs) {
      if (_checkMediaSourceSupport(mimeType) || _checkCanPlayType(mimeType) != '') {
        supportedCodecs.add(name);
      }
    }

    for (final (name, mimeType) in audioCodecs) {
      if (_checkMediaSourceSupport(mimeType) || _checkCanPlayType(mimeType) != '') {
        supportedCodecs.add(name);
      }
    }

    verboseLog('Supported codecs: ${supportedCodecs.join(", ")}', tag: 'Plugin');
    return supportedCodecs;
  }

  /// Builds a MIME type string for codec compatibility checking.
  String? _buildMimeType(CodecInfo codec) {
    // If codec already has a mimeType, use it
    if (codec.mimeType != null && codec.mimeType!.isNotEmpty) {
      return codec.mimeType;
    }

    // Try to build MIME type from fourcc and codecString
    final fourcc = codec.fourcc.toLowerCase();

    // Video codecs
    if (codec.isVideoCodec) {
      final codecString = codec.codecString ?? fourcc;
      return switch (fourcc) {
        'avc1' || 'avc3' => 'video/mp4; codecs="$codecString"',
        'hvc1' || 'hev1' => 'video/mp4; codecs="$codecString"',
        'vp08' => 'video/webm; codecs="vp8"',
        'vp09' => 'video/webm; codecs="${codec.codecString ?? "vp09.00.10.08"}"',
        'av01' => 'video/mp4; codecs="${codec.codecString ?? "av01.0.05M.08"}"',
        'mp4v' => 'video/mp4; codecs="mp4v.20.3"',
        _ => 'video/mp4; codecs="$codecString"',
      };
    }

    // Audio codecs
    if (codec.isAudioCodec) {
      final codecString = codec.codecString ?? fourcc;
      return switch (fourcc) {
        'mp4a' => 'audio/mp4; codecs="${codec.codecString ?? "mp4a.40.2"}"',
        'ac-3' => 'audio/mp4; codecs="ac-3"',
        'ec-3' => 'audio/mp4; codecs="ec-3"',
        'opus' => 'audio/webm; codecs="opus"',
        'flac' => 'audio/flac',
        'alac' => 'audio/mp4; codecs="alac"',
        'mp3 ' || '.mp3' => 'audio/mpeg',
        _ => 'audio/mp4; codecs="$codecString"',
      };
    }

    // Subtitle codecs - generally supported if browser supports video
    if (codec.isSubtitleCodec) {
      return 'text/vtt'; // VTT is universally supported
    }

    return null;
  }

  /// Checks MediaSource.isTypeSupported for the given MIME type.
  bool _checkMediaSourceSupport(String mimeType) {
    try {
      return web.MediaSource.isTypeSupported(mimeType);
    } catch (e) {
      verboseLog('MediaSource.isTypeSupported check failed: $e', tag: 'Plugin');
      return false;
    }
  }

  /// Checks canPlayType on a video element for the given MIME type.
  String _checkCanPlayType(String mimeType) {
    try {
      final video = web.document.createElement('video') as web.HTMLVideoElement;
      final result = video.canPlayType(mimeType);
      return result;
    } catch (e) {
      verboseLog('canPlayType check failed: $e', tag: 'Plugin');
      return '';
    }
  }

  /// Suggests alternative codecs when a codec is not supported.
  List<String> _suggestAlternatives(CodecInfo codec) {
    final fourcc = codec.fourcc.toLowerCase();

    // Suggest alternatives based on codec type
    if (codec.isVideoCodec) {
      return switch (fourcc) {
        'hvc1' || 'hev1' => ['H.264', 'VP9'], // HEVC → H.264 or VP9
        'av01' => ['H.264', 'VP9', 'HEVC'], // AV1 → H.264, VP9, or HEVC
        'vp09' => ['H.264', 'VP8'], // VP9 → H.264 or VP8
        'vp08' => ['H.264'], // VP8 → H.264
        _ => ['H.264'], // Default to H.264
      };
    }

    if (codec.isAudioCodec) {
      return switch (fourcc) {
        'ac-3' || 'ec-3' => ['AAC', 'Opus'], // AC-3/E-AC-3 → AAC or Opus
        'alac' => ['AAC', 'FLAC'], // ALAC → AAC or FLAC
        'opus' => ['AAC', 'Vorbis'], // Opus → AAC or Vorbis
        _ => ['AAC'], // Default to AAC
      };
    }

    return [];
  }
}
