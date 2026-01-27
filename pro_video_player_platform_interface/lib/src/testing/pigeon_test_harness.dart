import 'package:flutter_test/flutter_test.dart';

import '../pigeon_generated/messages.g.dart';

/// A test harness for Pigeon-based pro video player implementations.
///
/// This class provides mock setup for Pigeon-generated platform APIs,
/// allowing tests to intercept and verify calls to native platform code.
///
/// Usage:
/// ```dart
/// late PigeonTestHarness harness;
///
/// setUp(() {
///   harness = PigeonTestHarness()..setUp();
/// });
///
/// tearDown(() {
///   harness.tearDown();
/// });
/// ```
class PigeonTestHarness {
  /// Log of all Pigeon API calls made.
  final List<PigeonCall> log = [];

  /// Custom response handlers for specific methods.
  final Map<String, dynamic Function(List<Object?>)> _customResponses = {};

  /// Sets up mock handlers for Pigeon API calls.
  ///
  /// Call this in [setUp] before running tests.
  void setUp() {
    // Set up handler for each Pigeon method
    _setupHandler('create', _handleCreate);
    _setupHandler('dispose', _handleDispose);
    _setupHandler('play', _handlePlay);
    _setupHandler('pause', _handlePause);
    _setupHandler('stop', _handleStop);
    _setupHandler('seekTo', _handleSeekTo);
    _setupHandler('setPlaybackSpeed', _handleSetPlaybackSpeed);
    _setupHandler('setVolume', _handleSetVolume);
    _setupHandler('setLooping', _handleSetLooping);
    _setupHandler('setSubtitleTrack', _handleSetSubtitleTrack);
    _setupHandler('setAudioTrack', _handleSetAudioTrack);
    _setupHandler('setQualityTrack', _handleSetQualityTrack);
    _setupHandler('addExternalSubtitle', _handleAddExternalSubtitle);
    _setupHandler('getPosition', _handleGetPosition);
    _setupHandler('getDuration', _handleGetDuration);
    _setupHandler('enterPip', _handleEnterPip);
    _setupHandler('exitPip', _handleExitPip);
    _setupHandler('isPipSupported', _handleIsPipSupported);
    _setupHandler('enterFullscreen', _handleEnterFullscreen);
    _setupHandler('exitFullscreen', _handleExitFullscreen);
    _setupHandler('getPlatformInfo', _handleGetPlatformInfo);

    // Individual capability handlers
    _setupHandler('supportsPictureInPicture', (_) => true);
    _setupHandler('supportsFullscreen', (_) => true);
    _setupHandler('supportsBackgroundPlayback', (_) => true);
    _setupHandler('supportsCasting', (_) => false);
    _setupHandler('supportsAirPlay', (_) => false);
    _setupHandler('supportsChromecast', (_) => false);
    _setupHandler('supportsRemotePlayback', (_) => false);
    _setupHandler('supportsQualitySelection', (_) => true);
    _setupHandler('supportsPlaybackSpeedControl', (_) => true);
    _setupHandler('supportsSubtitles', (_) => true);
    _setupHandler('supportsExternalSubtitles', (_) => true);
    _setupHandler('supportsAudioTrackSelection', (_) => true);
    _setupHandler('supportsChapters', (_) => false);
    _setupHandler('supportsVideoMetadataExtraction', (_) => true);
    _setupHandler('supportsNetworkMonitoring', (_) => true);
    _setupHandler('supportsBandwidthEstimation', (_) => true);
    _setupHandler('supportsAdaptiveBitrate', (_) => true);
    _setupHandler('supportsHLS', (_) => true);
    _setupHandler('supportsDASH', (_) => false);
    _setupHandler('supportsDeviceVolumeControl', (_) => true);
    _setupHandler('supportsScreenBrightnessControl', (_) => true);
  }

  /// Clears all mock handlers and resets state.
  ///
  /// Call this in [tearDown] after running tests.
  void tearDown() {
    log.clear();
    _customResponses.clear();

    // Clear all handlers
    final methods = [
      'create',
      'dispose',
      'play',
      'pause',
      'stop',
      'seekTo',
      'setPlaybackSpeed',
      'setVolume',
      'setLooping',
      'setSubtitleTrack',
      'setAudioTrack',
      'setQualityTrack',
      'addExternalSubtitle',
      'getPosition',
      'getDuration',
      'enterPip',
      'exitPip',
      'isPipSupported',
      'enterFullscreen',
      'exitFullscreen',
      'getPlatformInfo',
      'supportsPictureInPicture',
      'supportsFullscreen',
      'supportsBackgroundPlayback',
      'supportsCasting',
      'supportsAirPlay',
      'supportsChromecast',
      'supportsRemotePlayback',
      'supportsQualitySelection',
      'supportsPlaybackSpeedControl',
      'supportsSubtitles',
      'supportsExternalSubtitles',
      'supportsAudioTrackSelection',
      'supportsChapters',
      'supportsVideoMetadataExtraction',
      'supportsNetworkMonitoring',
      'supportsBandwidthEstimation',
      'supportsAdaptiveBitrate',
      'supportsHLS',
      'supportsDASH',
      'supportsDeviceVolumeControl',
      'supportsScreenBrightnessControl',
    ];

    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final method in methods) {
      final channelName = 'dev.flutter.pigeon.pro_video_player_platform_interface.ProVideoPlayerHostApi.$method';
      messenger.setMockMessageHandler(channelName, null);
    }
  }

  /// Sets a custom response for a specific method.
  ///
  /// The handler receives the decoded arguments and should return the result.
  void setCustomResponse(String method, dynamic Function(List<Object?>) handler) {
    _customResponses[method] = handler;
  }

  /// Sets all handlers to return null, simulating platform errors.
  void setNullResponses() {
    _customResponses['*'] = (_) => null;
  }

  /// Gets the last call from the log.
  PigeonCall get lastCall => log.last;

  void _setupHandler(String method, dynamic Function(List<Object?>) defaultHandler) {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final channelName = 'dev.flutter.pigeon.pro_video_player_platform_interface.ProVideoPlayerHostApi.$method';
    // Use the same codec that Pigeon-generated ProVideoPlayerHostApi uses
    const codec = ProVideoPlayerHostApi.pigeonChannelCodec;

    messenger.setMockMessageHandler(channelName, (message) async {
      // Decode arguments (null message means no arguments)
      final List<Object?> args;
      if (message == null) {
        args = [];
      } else {
        final decoded = codec.decodeMessage(message);
        args = (decoded as List<Object?>?) ?? [];
      }

      // Log the call
      log.add(PigeonCall(method: method, arguments: args));

      // Check for custom response
      dynamic result;
      if (_customResponses.containsKey('*')) {
        result = _customResponses['*']!(args);
      } else if (_customResponses.containsKey(method)) {
        result = _customResponses[method]!(args);
      } else {
        result = defaultHandler(args);
      }

      // Encode response in Pigeon format
      return codec.encodeMessage([result]);
    });
  }

  // Default handlers for each method

  dynamic _handleCreate(List<Object?> args) => 1; // Return player ID

  dynamic _handleDispose(List<Object?> args) => null; // void method

  dynamic _handlePlay(List<Object?> args) => null; // void method

  dynamic _handlePause(List<Object?> args) => null; // void method

  dynamic _handleStop(List<Object?> args) => null; // void method

  dynamic _handleSeekTo(List<Object?> args) => null; // void method

  dynamic _handleSetPlaybackSpeed(List<Object?> args) => null; // void method

  dynamic _handleSetVolume(List<Object?> args) => null; // void method

  dynamic _handleSetLooping(List<Object?> args) => null; // void method

  dynamic _handleSetSubtitleTrack(List<Object?> args) => null; // void method

  dynamic _handleSetAudioTrack(List<Object?> args) => null; // void method

  dynamic _handleSetQualityTrack(List<Object?> args) => null; // void method

  dynamic _handleAddExternalSubtitle(List<Object?> args) => null; // void method

  dynamic _handleGetPosition(List<Object?> args) => 30000; // 30 seconds in milliseconds

  dynamic _handleGetDuration(List<Object?> args) => 120000; // 2 minutes in milliseconds

  dynamic _handleEnterPip(List<Object?> args) => true;

  dynamic _handleExitPip(List<Object?> args) => null; // void method

  dynamic _handleIsPipSupported(List<Object?> args) => true;

  dynamic _handleEnterFullscreen(List<Object?> args) => true;

  dynamic _handleExitFullscreen(List<Object?> args) => null; // void method

  dynamic _handleGetPlatformInfo(List<Object?> args) {
    // Return default platform info message
    return PlatformInfoMessage(platformName: 'test', nativePlayerType: 'mock', additionalInfo: {});
  }
}

/// Represents a single Pigeon API call for testing.
class PigeonCall {
  /// Creates a new Pigeon call record.
  const PigeonCall({required this.method, required this.arguments});

  /// The method name that was called.
  final String method;

  /// The arguments passed to the method.
  final List<Object?> arguments;

  /// Gets the source argument (for create calls).
  VideoSourceMessage get source => arguments[0]! as VideoSourceMessage;

  /// Gets the options argument (for create calls).
  VideoPlayerOptionsMessage get options => arguments[1]! as VideoPlayerOptionsMessage;

  /// Gets the player ID argument (for most calls).
  int get playerId => arguments[0]! as int;

  /// Gets the position argument (for seekTo calls).
  int get position => (arguments[1] as int?) ?? 0;

  /// Gets the speed argument (for setPlaybackSpeed calls).
  double get speed => (arguments[1] as double?) ?? 0.0;

  /// Gets the volume argument (for setVolume calls).
  double get volume => (arguments[1] as double?) ?? 0.0;

  /// Gets the looping argument (for setLooping calls).
  bool get looping => (arguments[1] as bool?) ?? false;

  /// Gets the subtitle track argument (for setSubtitleTrack calls).
  SubtitleTrackMessage? get subtitleTrack => arguments[1] as SubtitleTrackMessage?;

  /// Gets the audio track argument (for setAudioTrack calls).
  AudioTrackMessage? get audioTrack => arguments[1] as AudioTrackMessage?;

  /// Gets the quality track argument (for setQualityTrack calls).
  VideoQualityTrackMessage? get qualityTrack => arguments[1] as VideoQualityTrackMessage?;

  /// Gets the PiP options argument (for enterPip calls).
  PipOptionsMessage? get pipOptions {
    if (arguments.length > 1) {
      return arguments[1] as PipOptionsMessage?;
    }
    return null;
  }

  /// Gets the external subtitle argument (for addExternalSubtitle calls).
  ExternalSubtitleTrackMessage? get externalSubtitle => arguments[1] as ExternalSubtitleTrackMessage?;
}
