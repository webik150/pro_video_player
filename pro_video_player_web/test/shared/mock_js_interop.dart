import 'dart:async';

import 'package:pro_video_player_web/src/abstractions/dash_player_interface.dart';
import 'package:pro_video_player_web/src/abstractions/hls_player_interface.dart';
import 'package:pro_video_player_web/src/abstractions/video_element_interface.dart';

/// Mock HTMLVideoElement for testing without actual DOM.
///
/// Simulates the behavior of a real HTML5 video element with properties
/// and methods that can be controlled in tests.
class MockHTMLVideoElement implements VideoElementInterface {
  /// Current video source URL.
  String _src = '';

  @override
  String get src => _src;

  @override
  set src(Object? value) => _src = value! as String;

  /// Current playback position in seconds.
  @override
  double currentTime = 0;

  /// Total duration in seconds.
  @override
  double duration = 0;

  /// Whether video is paused.
  @override
  bool paused = true;

  /// Whether video has ended.
  @override
  bool ended = false;

  /// Current volume (0.0 to 1.0).
  double _volume = 1;

  @override
  double get volume => _volume;

  @override
  set volume(Object? value) => _volume = value! as double;

  /// Current playback rate (speed).
  double _playbackRate = 1;

  @override
  double get playbackRate => _playbackRate;

  @override
  set playbackRate(Object? value) => _playbackRate = value! as double;

  /// Whether video is muted.
  bool _muted = false;

  @override
  bool get muted => _muted;

  @override
  set muted(Object? value) => _muted = value! as bool;

  /// Whether video should loop.
  bool _loop = false;

  @override
  bool get loop => _loop;

  @override
  set loop(Object? value) => _loop = value! as bool;

  /// Video width in pixels.
  @override
  double videoWidth = 1920;

  /// Video height in pixels.
  @override
  double videoHeight = 1080;

  /// Ready state (0-4, where 4 = HAVE_ENOUGH_DATA).
  @override
  int readyState = 4;

  /// Network state (0-3).
  @override
  int networkState = 2; // NETWORK_LOADING

  /// Preload setting.
  String _preload = 'auto';

  @override
  String get preload => _preload;

  @override
  set preload(Object? value) => _preload = value! as String;

  /// Video controls visibility.
  bool _controls = false;

  @override
  bool get controls => _controls;

  @override
  set controls(Object? value) => _controls = value! as bool;

  /// Mock audio tracks (for testing audio track selection).
  @override
  List<MockAudioTrack> mockAudioTracks = [];

  /// Mock text tracks (for testing subtitle selection).
  @override
  List<MockTextTrack> mockTextTracks = [];

  /// Mock remote playback (for testing casting).
  MockRemotePlayback? mockRemotePlayback;

  @override
  RemotePlaybackInterface? get remotePlayback => mockRemotePlayback;

  /// Map of event listeners.
  final Map<String, List<Function>> _eventListeners = {};

  @override
  void addEventListener(String event, void Function(Object? event) callback) {
    _eventListeners.putIfAbsent(event, () => []).add(callback);
  }

  /// Adds an event listener (legacy overload for tests).
  void addEventListenerLegacy(String event, Function handler) {
    _eventListeners.putIfAbsent(event, () => []).add(handler);
  }

  /// Removes an event listener.
  void removeEventListener(String event, Function handler) {
    _eventListeners[event]?.remove(handler);
  }

  /// Checks if an event has listeners.
  bool hasListener(String event) => _eventListeners[event]?.isNotEmpty ?? false;

  /// Triggers an event with optional data.
  void triggerEvent(String event, [Map<String, dynamic>? data]) {
    final handlers = _eventListeners[event] ?? [];
    final eventData = data ?? {}; // Always pass at least empty object
    for (final handler in handlers) {
      // ignore: avoid_dynamic_calls
      handler(eventData);
    }
  }

  /// Simulates play() method.
  @override
  Future<void> play() async {
    paused = false;
    ended = false;
    triggerEvent('play');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    triggerEvent('playing');
  }

  /// Mock buffered time ranges.
  @override
  MockTimeRanges get buffered => MockTimeRanges();

  /// Simulates pause() method.
  @override
  void pause() {
    paused = true;
    triggerEvent('pause');
  }

  /// Simulates load() method.
  @override
  void load() {
    readyState = 0;
    triggerEvent('loadstart');
    Future.delayed(const Duration(milliseconds: 50), () {
      readyState = 4;
      triggerEvent('loadedmetadata');
      triggerEvent('canplay');
    });
  }
}

/// Mock TimeRanges for buffered property.
class MockTimeRanges {
  int get length => 0;
  num start(int index) => 0;
  num end(int index) => 0;
}

/// Mock HLS.js player for testing.
class MockHlsPlayer implements HlsPlayerInterface {
  /// Whether player is attached to media element.
  bool isAttached = false;

  /// Current source URL.
  String? sourceUrl;

  /// Available quality levels.
  List<MockHlsLevel> _levels = [];

  /// Setter for levels (used in tests).
  set levels(List<MockHlsLevel> value) => _levels = value;

  /// Current quality level index (-1 = auto).
  int _currentLevel = -1;

  /// Maximum bitrate in bits per second (0 = unlimited).
  int maxBitrate = 0;

  /// Available audio tracks.
  List<MockHlsAudioTrack> _audioTracks = [];

  /// Setter for audioTracks (used in tests).
  set audioTracks(List<MockHlsAudioTrack> value) => _audioTracks = value;

  /// Available subtitle tracks.
  List<MockHlsSubtitleTrack> _subtitleTracks = [];

  /// Setter for subtitleTracks (used in tests).
  set subtitleTracks(List<MockHlsSubtitleTrack> value) => _subtitleTracks = value;

  /// Current audio track index.
  int _audioTrack = -1;

  /// Current subtitle track index.
  int _subtitleTrack = -1;

  /// Event listeners.
  final Map<String, List<Function>> _eventListeners = {};

  /// Callback for startLoad() - used in tests.
  void Function()? onStartLoad;

  @override
  void attachMedia(Object video) {
    isAttached = true;
  }

  @override
  void detachMedia() {
    isAttached = false;
  }

  @override
  void loadSource(String url) {
    sourceUrl = url;
    Future<void>.delayed(const Duration(milliseconds: 50), () {
      triggerEvent('manifestParsed');
    });
  }

  @override
  void startLoad([int startPosition = -1]) {
    onStartLoad?.call();
  }

  @override
  void stopLoad() {}

  @override
  int get currentLevel => _currentLevel;

  @override
  set currentLevel(int level) => _currentLevel = level;

  @override
  int get nextLevel => _currentLevel;

  @override
  set nextLevel(int level) => _currentLevel = level;

  @override
  int get autoLevelCapping => -1;

  @override
  set autoLevelCapping(int level) {}

  @override
  bool get autoLevelEnabled => _currentLevel == -1;

  @override
  List<MockHlsLevel> get levels => _levels;

  @override
  int get audioTrack => _audioTrack;

  @override
  set audioTrack(int index) => _audioTrack = index;

  @override
  List<MockHlsAudioTrack> get audioTracks => _audioTracks;

  @override
  int get subtitleTrack => _subtitleTrack;

  @override
  set subtitleTrack(int index) => _subtitleTrack = index;

  @override
  List<MockHlsSubtitleTrack> get subtitleTracks => _subtitleTracks;

  @override
  double get bandwidthEstimate => 0;

  @override
  void on(String event, void Function(String event, Object? data) callback) {
    _eventListeners.putIfAbsent(event, () => []).add(callback);
  }

  /// Removes an event listener.
  void off(String event, Function? handler) {
    if (handler != null) {
      _eventListeners[event]?.remove(handler);
    } else {
      _eventListeners.remove(event);
    }
  }

  /// Checks if an event has listeners.
  bool hasEventHandler(String event) => _eventListeners.containsKey(event) && _eventListeners[event]!.isNotEmpty;

  /// Triggers an event.
  void triggerEvent(String event, [Object? data]) {
    final handlers = _eventListeners[event] ?? [];
    for (final handler in handlers) {
      if (data != null) {
        (handler as void Function(String, Object?))(event, data);
      } else {
        (handler as void Function(String, Object?))(event, null);
      }
    }
  }

  @override
  void offAll() {
    _eventListeners.clear();
  }

  @override
  void destroy() {
    isAttached = false;
    sourceUrl = null;
    _eventListeners.clear();
  }

  @override
  void recoverMediaError() {}

  @override
  void swapAudioCodec() {}
}

/// Mock HLS quality level.
class MockHlsLevel implements HlsLevelInterface {
  MockHlsLevel({required this.height, required this.bitrate, int? width, this.name, this.codecs, this.index = 0})
    : width = width ?? 0;

  @override
  final int index;

  @override
  final int height;

  @override
  final int bitrate;

  @override
  final int width;

  @override
  final String? name;

  @override
  final String? codecs;

  @override
  String get label => '${height}p';
}

/// Mock HLS audio track.
class MockHlsAudioTrack implements HlsAudioTrackInterface {
  MockHlsAudioTrack({required this.id, required this.name, this.lang, this.index = 0, this.isDefault = false});

  @override
  final int index;

  @override
  final int? id;

  @override
  final String? name;

  @override
  final String? lang;

  @override
  final bool isDefault;

  @override
  String get label => name ?? 'Audio ${index + 1}';
}

/// Mock HLS subtitle track.
class MockHlsSubtitleTrack implements HlsSubtitleTrackInterface {
  MockHlsSubtitleTrack({
    required this.id,
    required this.name,
    this.lang,
    this.index = 0,
    this.isDefault = false,
    this.forced = false,
  });

  @override
  final int index;

  @override
  final int? id;

  @override
  final String? name;

  @override
  final String? lang;

  @override
  final bool isDefault;

  @override
  final bool forced;

  @override
  String get label => name ?? 'Subtitle ${index + 1}';
}

/// Mock DASH.js MediaPlayer for testing.
class MockDashPlayer implements DashPlayerInterface {
  /// Whether player is initialized.
  bool isInitialized = false;

  /// Current source URL.
  String? sourceUrl;

  /// Available bitrate infos.
  List<MockDashBitrateInfo> bitrateInfos = [];

  /// Current quality index.
  int currentQuality = 0;

  /// ABR enabled state.
  bool abrEnabled = true;

  /// Available audio tracks.
  List<MockDashAudioTrack> _audioTracks = [];

  /// Setter for audioTracks (used in tests).
  set audioTracks(List<MockDashAudioTrack> value) => _audioTracks = value;

  /// Current audio track index.
  int currentAudioTrack = 0;

  /// Available text tracks.
  List<MockDashTextTrack> _textTracks = [];

  /// Setter for textTracks (used in tests).
  set textTracks(List<MockDashTextTrack> value) => _textTracks = value;

  /// Current text track index.
  int currentTextTrack = 0;

  /// Text track visibility.
  bool textTrackVisible = false;

  /// Average throughput in kbps (dash.js uses kbps).
  double averageThroughputKbps = 0;

  /// Event listeners.
  final Map<String, List<Function>> _eventListeners = {};

  /// Callback for reset() - used in tests.
  void Function()? onReset;

  /// Callback for attachSource() - used in tests.
  void Function()? onAttachSource;

  @override
  void initialize({required Object view, required String url, bool autoPlay = false}) {
    isInitialized = true;
    sourceUrl = url;
  }

  @override
  void attachView(Object view) {}

  @override
  void attachSource(String url) {
    sourceUrl = url;
    onAttachSource?.call();
  }

  /// Sets the source URL (for testing).
  void setSource(String url) {
    sourceUrl = url;
    Future<void>.delayed(const Duration(milliseconds: 50), () {
      triggerEvent('streamInitialized');
    });
  }

  @override
  List<MockDashBitrateInfo> getVideoBitrateInfoList() => bitrateInfos;

  @override
  List<MockDashBitrateInfo> getAudioBitrateInfoList() => bitrateInfos;

  @override
  void setQualityFor(String type, int quality) {
    currentQuality = quality;
  }

  @override
  int getQualityFor(String type) => currentQuality;

  @override
  void setAutoSwitchQualityFor(String type, {required bool enabled}) {
    abrEnabled = enabled;
  }

  @override
  bool getAutoSwitchQualityFor(String type) => abrEnabled;

  /// Sets ABR (Adaptive Bitrate) enabled state (for testing).
  void setABREnabled(bool enabled) {
    abrEnabled = enabled;
  }

  /// Sets minimum bitrate in bps (for testing).
  void setMinBitrate(int bitrate) {}

  /// Sets maximum bitrate in bps (for testing).
  void setMaxBitrate(int bitrate) {}

  @override
  List<MockDashAudioTrack> getAudioTracks() => _audioTracks;

  @override
  List<MockDashTextTrack> getTextTracks() => _textTracks;

  @override
  void setAudioTrack(int index) {
    currentAudioTrack = index;
  }

  @override
  void setTextTrack(int index) {
    currentTextTrack = index;
  }

  @override
  void setTextTrackVisibility({required bool visible}) {
    textTrackVisible = visible;
  }

  @override
  double getAverageThroughput() => averageThroughputKbps;

  @override
  void updateSettings(Map<String, dynamic> settings) {
    if (settings.containsKey('streaming')) {
      final streaming = settings['streaming'] as Map<String, dynamic>;
      if (streaming.containsKey('abr')) {
        final abr = streaming['abr'] as Map<String, dynamic>;
        if (abr.containsKey('autoSwitchBitrate')) {
          final autoSwitch = abr['autoSwitchBitrate'] as Map<String, dynamic>;
          abrEnabled = autoSwitch['video'] as bool? ?? true;
        }
      }
    }
  }

  @override
  void on(String event, void Function(Object? data) callback) {
    _eventListeners.putIfAbsent(event, () => []).add(callback);
  }

  /// Removes an event listener.
  void off(String event, Function? handler) {
    if (handler != null) {
      _eventListeners[event]?.remove(handler);
    } else {
      _eventListeners.remove(event);
    }
  }

  /// Checks if an event has listeners.
  bool hasEventHandler(String event) => _eventListeners.containsKey(event) && _eventListeners[event]!.isNotEmpty;

  /// Triggers an event.
  void triggerEvent(String event, [Object? data]) {
    final handlers = _eventListeners[event] ?? [];
    for (final handler in handlers) {
      (handler as void Function(Object?))(data);
    }
  }

  @override
  void offAll() {
    _eventListeners.clear();
  }

  @override
  void reset() {
    onReset?.call();
    isInitialized = false;
    sourceUrl = null;
    _eventListeners.clear();
  }

  @override
  void destroy() {
    offAll();
    reset();
  }
}

/// Mock DASH bitrate info.
class MockDashBitrateInfo implements DashBitrateInfoInterface {
  MockDashBitrateInfo({required this.bitrate, required this.width, required this.height, int? qualityIndex})
    : index = qualityIndex ?? 0;

  @override
  final int index;

  @override
  final int bitrate;

  @override
  final int width;

  @override
  final int height;

  @override
  String? get mediaType => 'video';

  @override
  String get label => '${height}p';
}

/// Mock DASH audio track.
class MockDashAudioTrack implements DashAudioTrackInterface {
  MockDashAudioTrack({required this.index, required String lang, required String label, this.isDefault = false})
    : lang = lang,
      _label = label;

  @override
  final int index;

  @override
  String? get id => index.toString();

  @override
  final String? lang;

  final String _label;

  @override
  String get label => _label;

  @override
  List<String>? get roles => null;

  @override
  final bool isDefault;
}

/// Mock DASH text track.
class MockDashTextTrack implements DashTextTrackInterface {
  MockDashTextTrack({required this.index, required String lang, required String label, this.isDefault = false})
    : lang = lang,
      _label = label;

  @override
  final int index;

  @override
  String? get id => index.toString();

  @override
  final String? lang;

  final String _label;

  @override
  String get label => _label;

  @override
  List<String>? get roles => null;

  @override
  final bool isDefault;
}

/// Mock HTML5 audio track.
class MockAudioTrack {
  MockAudioTrack({required this.id, required this.label, this.language, this.enabled = false});

  final String id;
  final String label;
  final String? language;
  bool enabled;
}

/// Mock HTML5 text track.
class MockTextTrack {
  MockTextTrack({required this.id, required this.label, this.language, this.mode = 'disabled'});

  final String id;
  final String label;
  final String? language;
  String mode; // 'disabled', 'hidden', 'showing'
}

/// Mock Wake Lock Sentinel.
class MockWakeLockSentinel {
  bool _released = false;
  final StreamController<void> _releaseController = StreamController<void>.broadcast();

  /// Whether the wake lock has been released.
  bool get released => _released;

  /// Stream that emits when wake lock is released.
  Stream<void> get onrelease => _releaseController.stream;

  /// Releases the wake lock.
  Future<void> release() async {
    if (_released) return;
    _released = true;
    _releaseController.add(null);
  }

  /// Disposes the controller.
  void dispose() {
    unawaited(_releaseController.close());
  }
}

/// Mock Wake Lock API.
class MockWakeLock {
  MockWakeLockSentinel? _currentSentinel;

  /// Requests a wake lock.
  Future<MockWakeLockSentinel> request(String type) async {
    final sentinel = MockWakeLockSentinel();
    _currentSentinel = sentinel;
    return sentinel;
  }

  /// Gets the current wake lock sentinel.
  MockWakeLockSentinel? get currentSentinel => _currentSentinel;

  /// Clears the current sentinel.
  void clear() {
    _currentSentinel = null;
  }
}

/// Mock Remote Playback API for testing casting.
class MockRemotePlayback implements RemotePlaybackInterface {
  /// Current state ('disconnected', 'connecting', 'connected').
  String _state = 'disconnected';

  @override
  String? get state => _state;

  /// Setter for state (used in tests).
  // ignore: avoid_setters_without_getters
  set mockState(String value) => _state = value;

  /// Event listeners.
  final Map<String, List<Function>> _eventListeners = {};

  /// Callback for prompt() - used in tests.
  void Function()? onPrompt;

  @override
  void addEventListener(String event, void Function(Object? event) callback) {
    _eventListeners.putIfAbsent(event, () => []).add(callback);
  }

  /// Removes an event listener.
  void removeEventListener(String event, Function handler) {
    _eventListeners[event]?.remove(handler);
  }

  /// Checks if an event has listeners.
  bool hasListener(String event) => _eventListeners[event]?.isNotEmpty ?? false;

  /// Triggers an event with a dummy event object.
  void triggerEvent(String event) {
    final handlers = _eventListeners[event] ?? [];
    for (final handler in handlers) {
      (handler as void Function(Object?))(<String, dynamic>{}); // Pass dummy event object
    }
  }

  /// Shows the device picker prompt.
  @override
  Future<void> prompt() async {
    onPrompt?.call();
  }
}
