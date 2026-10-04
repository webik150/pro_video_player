import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

import 'pro_video_player_controller.dart';
import 'subtitle_overlay.dart';
import 'video_player_controls.dart';

/// A callback for building custom video player controls.
///
/// The [context] is the build context and [controller] is the video player
/// controller that can be used to control playback.
typedef VideoPlayerControlsBuilder =
    Widget Function(BuildContext context, ProVideoPlayerController controller);

/// A widget that displays a video player.
///
/// Requires an initialized [ProVideoPlayerController].
///
/// ## Layout Modes
///
/// The widget supports different control modes via [controlsMode]:
///
/// - **Flutter controls** ([ControlsMode.flutter], default): Shows the built-in
///   [VideoPlayerControls] widget with gesture support, progress bar, and
///   control buttons.
///
/// - **Native controls** ([ControlsMode.native]): Shows platform-native
///   playback controls (iOS: AVPlayerViewController, Android: ExoPlayer PlayerView).
///
/// - **No controls** ([ControlsMode.none]): Shows video only without any
///   controls overlay. Use this when providing external controls.
///
/// - **Custom controls**: Provide a [controlsBuilder] to render custom
///   Flutter controls on top of the video. When [controlsBuilder] is provided,
///   it overrides [controlsMode] (except for [ControlsMode.native]).
///
/// ## Example
///
/// ```dart
/// // With built-in Flutter controls (default)
/// ProVideoPlayer(
///   controller: _controller,
/// )
///
/// // With native platform controls
/// ProVideoPlayer(
///   controller: _controller,
///   controlsMode: ControlsMode.native,
/// )
///
/// // Video only (no controls)
/// ProVideoPlayer(
///   controller: _controller,
///   controlsMode: ControlsMode.none,
/// )
///
/// // With custom controls
/// ProVideoPlayer(
///   controller: _controller,
///   controlsBuilder: (context, controller) => MyCustomControls(controller),
/// )
/// ```
class ProVideoPlayer extends StatefulWidget {
  /// Creates a video player widget.
  ///
  /// The [controller] must be initialized before the widget is built.
  ///
  /// Use [controlsMode] to select between no controls ([ControlsMode.none])
  /// or native platform controls ([ControlsMode.native]).
  ///
  /// Alternatively, provide a [controlsBuilder] to render custom Flutter
  /// controls on top of the video. When [controlsBuilder] is provided,
  /// [controlsMode] is ignored.
  const ProVideoPlayer({
    required this.controller,
    super.key,
    this.aspectRatio,
    this.fillBounds = false,
    this.placeholder,
    this.controlsMode = ControlsMode.flutter,
    this.controlsBuilder,
    this.subtitleStyle,
  });

  /// The controller for this video player.
  final ProVideoPlayerController controller;

  /// The aspect ratio to use when displaying the video.
  ///
  /// If null, uses the video's natural aspect ratio when available,
  /// otherwise defaults to 16:9.
  final double? aspectRatio;

  /// Whether to fill the available bounds instead of constraining the player
  /// to its aspect ratio.
  ///
  /// Defaults to `false`, preserving the video's aspect ratio.
  final bool fillBounds;

  /// A widget to display while the video is loading or if there's an error.
  final Widget? placeholder;

  /// The controls mode for the video player.
  ///
  /// Determines how playback controls are displayed:
  /// - [ControlsMode.flutter]: Built-in Flutter controls (default)
  /// - [ControlsMode.native]: Platform-native playback controls
  /// - [ControlsMode.none]: No controls - video only
  ///
  /// This is ignored when [controlsBuilder] is provided (except for native).
  final ControlsMode controlsMode;

  /// A builder for custom video player controls.
  ///
  /// When provided, this builder is used to render custom Flutter controls
  /// on top of the video, overriding [controlsMode] (except for native).
  ///
  /// The builder receives the [BuildContext] and [ProVideoPlayerController]
  /// to build controls that can interact with the player.
  ///
  /// Example:
  /// ```dart
  /// ProVideoPlayer(
  ///   controller: _controller,
  ///   controlsBuilder: (context, controller) => Positioned.fill(
  ///     child: GestureDetector(
  ///       onTap: () => controller.togglePlayPause(),
  ///       child: Icon(
  ///         controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
  ///       ),
  ///     ),
  ///   ),
  /// )
  /// ```
  final VideoPlayerControlsBuilder? controlsBuilder;

  /// Optional subtitle style configuration.
  ///
  /// Controls the appearance of subtitles when using Flutter controls mode.
  /// This is passed to [VideoPlayerControls] which renders subtitles using
  /// the subtitle overlay widget.
  ///
  /// Has no effect when using native controls, as native platforms render
  /// subtitles using their own styling.
  ///
  /// See [SubtitleStyle] for available customization options.
  final SubtitleStyle? subtitleStyle;

  @override
  State<ProVideoPlayer> createState() => _ProVideoPlayerState();
}

class _ProVideoPlayerState extends State<ProVideoPlayer> {
  /// Computes the effective native controls mode for the platform view.
  ControlsMode get _effectiveNativeControlsMode {
    final useNativeControls =
        widget.controlsMode == ControlsMode.native &&
        widget.controlsBuilder == null;
    return useNativeControls ? ControlsMode.native : ControlsMode.none;
  }

  @override
  void didUpdateWidget(ProVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // When controls mode changes, notify native to update the view
    final oldNativeMode =
        oldWidget.controlsMode == ControlsMode.native &&
            oldWidget.controlsBuilder == null
        ? ControlsMode.native
        : ControlsMode.none;
    final newNativeMode = _effectiveNativeControlsMode;

    if (oldNativeMode != newNativeMode && widget.controller.playerId != null) {
      unawaited(
        ProVideoPlayerPlatform.instance.setControlsMode(
          widget.controller.playerId!,
          newNativeMode,
        ),
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<VideoPlayerValue>(
    valueListenable: widget.controller,
    builder: (context, value, child) {
      if (!widget.controller.isInitialized) {
        // Show loading indicator by default while player initializes
        final placeholder =
            widget.placeholder ??
            const ColoredBox(
              color: Colors.black,
              child: Center(child: CircularProgressIndicator()),
            );
        return widget.fillBounds
            ? SizedBox.expand(child: placeholder)
            : AspectRatio(
                aspectRatio: widget.aspectRatio ?? 16 / 9,
                child: placeholder,
              );
      }

      // Use widget aspectRatio if provided, otherwise use video aspectRatio (fallback to 16:9 if unknown)
      final calculatedAspectRatio = value.aspectRatio != 0.0
          ? value.aspectRatio
          : 16 / 9;
      final videoAspectRatio = widget.aspectRatio ?? calculatedAspectRatio;

      final videoView = _buildVideoView(context);
      return widget.fillBounds
          ? SizedBox.expand(child: videoView)
          : AspectRatio(aspectRatio: videoAspectRatio, child: videoView);
    },
  );

  Widget _buildVideoView(BuildContext context) {
    final playerId = widget.controller.playerId;
    if (playerId == null) {
      return widget.placeholder ?? const SizedBox.shrink();
    }

    // Determine effective controls mode for native view
    // - native mode: use native controls
    // - flutter/none/custom: no native controls (we overlay Flutter controls or nothing)
    final nativeControlsMode = _effectiveNativeControlsMode;
    final videoView = ProVideoPlayerPlatform.instance.buildView(
      playerId,
      controlsMode: nativeControlsMode,
    );

    // Determine if we should show Flutter subtitle overlay
    final shouldShowSubtitleOverlay = _shouldShowFlutterSubtitles();

    // Native controls mode: video + optional subtitle overlay on top
    if (nativeControlsMode == ControlsMode.native) {
      if (shouldShowSubtitleOverlay) {
        return Stack(
          children: [
            videoView,
            SubtitleOverlay(
              controller: widget.controller,
              style: widget.subtitleStyle,
            ),
          ],
        );
      }
      return videoView;
    }

    // No controls mode (without custom builder): video only
    // Don't add SubtitleOverlay here - ControlsMode.none is typically used
    // alongside a separate VideoPlayerControls widget that handles subtitles.
    // Adding one here would cause duplicates. Users who want subtitles without
    // controls can add SubtitleOverlay manually or use a custom controlsBuilder.
    if (widget.controlsMode == ControlsMode.none &&
        widget.controlsBuilder == null) {
      return videoView;
    }

    // Flutter controls mode or custom builder: video + optional subtitle overlay + controls
    final hasCustomBuilder = widget.controlsBuilder != null;
    final controls =
        widget.controlsBuilder?.call(context, widget.controller) ??
        VideoPlayerControls(
          controller: widget.controller,
          subtitleStyle: widget.subtitleStyle,
          renderSubtitlesInternally: !shouldShowSubtitleOverlay,
        );

    // When using a custom builder, don't add SubtitleOverlay here - the custom
    // builder is responsible for subtitles (e.g., via VideoPlayerControls with
    // its own SubtitleOverlay). Adding one here would cause duplicates.
    final showOverlayAtThisLevel =
        shouldShowSubtitleOverlay && !hasCustomBuilder;

    return KeyedSubtree(
      key: ValueKey(playerId),
      child: Stack(
        fit: StackFit.expand,
        children: [
          videoView,
          if (showOverlayAtThisLevel)
            SubtitleOverlay(
              controller: widget.controller,
              style: widget.subtitleStyle,
            ),
          controls,
        ],
      ),
    );
  }

  /// Determines if Flutter should render subtitles based on current mode.
  bool _shouldShowFlutterSubtitles() {
    final renderMode = widget.controller.value.currentSubtitleRenderMode;
    final options = widget.controller.options;

    // Subtitles must be enabled
    if (!options.subtitlesEnabled) {
      return false;
    }

    // If mode is explicitly set, use it
    if (renderMode == SubtitleRenderMode.flutter) return true;
    if (renderMode == SubtitleRenderMode.native) return false;

    // Auto mode: default to Flutter subtitle rendering for customizable
    // styling and cross-platform consistency. Users can opt-in to native
    // rendering via setSubtitleRenderMode(SubtitleRenderMode.native).
    return true;
  }
}
