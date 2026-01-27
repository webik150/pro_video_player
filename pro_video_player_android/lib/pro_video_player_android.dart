import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

/// The Android implementation of [ProVideoPlayerPlatform].
///
/// This class uses ExoPlayer for video playback on Android.
///
/// Events are delivered through a hybrid system:
/// - High-frequency events (position, buffering, state) come via EventChannel
/// - Low-frequency events (tracks, errors, metadata) come via Pigeon @FlutterApi
///
/// Both event sources are forwarded to the base class's event stream, ensuring
/// all events are received by the controller regardless of which mechanism
/// delivers them.
class ProVideoPlayerAndroid extends PigeonMethodChannelBase {
  /// Constructs a ProVideoPlayerAndroid.
  ProVideoPlayerAndroid() : super('pro_video_player_android');

  /// Registers this class as the default instance of [ProVideoPlayerPlatform].
  static void registerWith() {
    ProVideoPlayerPlatform.instance = ProVideoPlayerAndroid();
  }

  // EventChannel instances (one per player) - cleaned up on dispose
  final Map<int, EventChannel> _eventChannels = {};
  // EventChannel subscriptions (one per player) - cancelled on dispose
  final Map<int, StreamSubscription<dynamic>> _eventSubscriptions = {};

  // Note: We do NOT override events() - the base class's Pigeon-based stream
  // is used. EventChannel events are forwarded to that stream via addEventChannelEvent().

  @override
  Future<int> create({required VideoSource source, VideoPlayerOptions options = const VideoPlayerOptions()}) async {
    final playerId = await super.create(source: source, options: options);
    _setupEventChannel(playerId);
    return playerId;
  }

  @override
  Future<void> dispose(int playerId) async {
    await _eventSubscriptions[playerId]?.cancel();
    _eventSubscriptions.remove(playerId);
    _eventChannels.remove(playerId);
    await super.dispose(playerId);
  }

  /// Sets up the event channel for a player.
  ///
  /// EventChannel events are forwarded to the base class's Pigeon-based event stream,
  /// ensuring both high-frequency (EventChannel) and low-frequency (Pigeon) events
  /// are delivered to the controller through a single unified stream.
  void _setupEventChannel(int playerId) {
    final eventChannel = EventChannel('dev.pro_video_player.$channelPrefix/events/$playerId');
    _eventChannels[playerId] = eventChannel;

    // Forward EventChannel events to the base class's stream
    _eventSubscriptions[playerId] = eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map<dynamic, dynamic>) {
          final parsed = EventParser.parseEvent(event);
          if (parsed != null) {
            // Forward to base class's Pigeon-based event stream
            addEventChannelEvent(playerId, parsed);
          }
        }
      },
      onError: (Object error) {
        addEventChannelEvent(playerId, ErrorEvent(error.toString()));
      },
    );
  }

  @override
  Widget buildView(int playerId, {ControlsMode controlsMode = ControlsMode.none}) =>
      // Use PlatformViewLink with Hybrid Composition to avoid race condition crashes
      // in Flutter's Virtual Display platform view implementation.
      // See: https://github.com/flutter/flutter/issues/103630
      PlatformViewLink(
        viewType: 'dev.pro_video_player.android/video_view',
        surfaceFactory: (context, controller) => AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        ),
        onCreatePlatformView: (params) {
          final controller = PlatformViewsService.initSurfaceAndroidView(
            id: params.id,
            viewType: 'dev.pro_video_player.android/video_view',
            layoutDirection: TextDirection.ltr,
            creationParams: {'playerId': playerId, 'controlsMode': controlsMode.name},
            creationParamsCodec: const StandardMessageCodec(),
            onFocus: () => params.onFocusChanged(true),
          )..addOnPlatformViewCreatedListener(params.onPlatformViewCreated);
          unawaited(controller.create());
          return controller;
        },
      );
}
