import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

import 'pro_video_player.dart';
import 'pro_video_player_controller.dart';
import 'video_player_controls.dart';

/// A builder widget that provides different views based on the player's state.
///
/// This widget simplifies handling Picture-in-Picture (PiP) and fullscreen modes
/// by providing separate builders for each mode.
///
/// ## Control Mode Preservation
///
/// By default, fullscreen and PiP views will use the same [controlsMode] and
/// [controlsBuilder] as the normal view. This ensures a consistent user
/// experience across all modes.
///
/// - **Fullscreen**: Uses the same control mode by default. Override with
///   [fullscreenBuilder] for custom fullscreen UI.
/// - **PiP (Android)**: Uses compact mode by default for the small window.
///   Override with [pipBuilder] for custom PiP UI.
/// - **PiP (iOS)**: True video-only PiP with native controls (play/pause, skip).
///   The main app continues normally.
///
/// ## Platform Differences
///
/// **Android PiP behavior:** When PiP is active on Android, the entire Flutter app
/// is displayed in the small PiP window. The default view shows the video with
/// compact controls (large play/pause button, simple progress bar).
///
/// **iOS PiP behavior:** On iOS, true video-only PiP is used where the video floats
/// independently. The main app continues to show normally, so [pipBuilder] is not
/// called on iOS.
///
/// ## Example
///
/// ```dart
/// // Simple usage - fullscreen and PiP automatically use same controls
/// ProVideoPlayerBuilder(
///   controller: _controller,
///   controlsMode: ControlsMode.flutter,
///   builder: (context, controller, child) {
///     return Scaffold(
///       appBar: AppBar(title: Text('Video')),
///       body: ProVideoPlayer(controller: controller),
///     );
///   },
/// )
///
/// // Custom fullscreen view
/// ProVideoPlayerBuilder(
///   controller: _controller,
///   builder: (context, controller, child) => NormalView(controller),
///   fullscreenBuilder: (context, controller, child) {
///     return Scaffold(
///       backgroundColor: Colors.black,
///       body: Stack(
///         children: [
///           ProVideoPlayer(controller: controller),
///           MyFullscreenOverlay(),
///         ],
///       ),
///     );
///   },
/// )
/// ```
class ProVideoPlayerBuilder extends StatelessWidget {
  /// Creates a video player builder.
  ///
  /// The [controlsMode] and [controlsBuilder] parameters define the control
  /// style that will be used consistently across normal, fullscreen, and PiP
  /// views (unless overridden by custom builders).
  const ProVideoPlayerBuilder({
    required this.controller,
    required this.builder,
    this.controlsMode = ControlsMode.flutter,
    this.controlsBuilder,
    this.fullscreenBuilder,
    this.pipBuilder,
    this.useDefaultFullscreen = true,
    this.useDefaultPip = true,
    this.child,
    super.key,
  });

  /// The video player controller.
  final ProVideoPlayerController controller;

  /// Builds the normal (non-fullscreen, non-PiP) view.
  ///
  /// This is the main UI that is shown when the player is not in
  /// fullscreen or PiP mode.
  final Widget Function(
    BuildContext context,
    ProVideoPlayerController controller,
    Widget? child,
  )
  builder;

  /// The controls mode for the video player.
  ///
  /// This control mode will be used consistently across normal, fullscreen,
  /// and PiP views (unless overridden by custom builders).
  ///
  /// Defaults to [ControlsMode.flutter].
  final ControlsMode controlsMode;

  /// A builder for custom video player controls.
  ///
  /// When provided, this builder is used to render custom Flutter controls
  /// on top of the video in all modes (normal, fullscreen, PiP).
  final VideoPlayerControlsBuilder? controlsBuilder;

  /// Builds the fullscreen view.
  ///
  /// If null and [useDefaultFullscreen] is true, a default fullscreen view
  /// is provided that uses the same [controlsMode] and [controlsBuilder].
  ///
  /// If null and [useDefaultFullscreen] is false, the [builder] is used.
  final Widget Function(
    BuildContext context,
    ProVideoPlayerController controller,
    Widget? child,
  )?
  fullscreenBuilder;

  /// Builds the Picture-in-Picture view (Android only).
  ///
  /// On Android, when PiP is active, the entire Flutter app is shown in the
  /// small PiP window.
  ///
  /// If null and [useDefaultPip] is true, a default PiP view is provided
  /// with compact controls (large play/pause button, simple progress bar).
  ///
  /// If null and [useDefaultPip] is false, the [builder] is used.
  ///
  /// On iOS, true video-only PiP is used where the video floats independently,
  /// so this builder is not called.
  final Widget Function(
    BuildContext context,
    ProVideoPlayerController controller,
    Widget? child,
  )?
  pipBuilder;

  /// Whether to use the default fullscreen view when [fullscreenBuilder] is null.
  ///
  /// When true (default), a fullscreen view is automatically provided that
  /// shows the video with the same [controlsMode] and [controlsBuilder].
  ///
  /// When false, the [builder] is used for fullscreen mode.
  final bool useDefaultFullscreen;

  /// Whether to use the default PiP view when [pipBuilder] is null (Android only).
  ///
  /// When true (default), a PiP view is automatically provided that shows
  /// the video with compact controls optimized for the small window.
  ///
  /// When false, the [builder] is used for PiP mode.
  final bool useDefaultPip;

  /// An optional child widget to pass to the builders.
  ///
  /// This can be used to optimize rebuilds by keeping widgets that don't
  /// depend on the player state outside the builder function.
  final Widget? child;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        child: child,
        builder: (context, value, child) {
          // Fullscreen mode takes priority
          if (value.isFullscreen) {
            if (fullscreenBuilder != null) {
              return fullscreenBuilder!(context, controller, child);
            }
            if (useDefaultFullscreen) {
              return _buildDefaultFullscreen(context);
            }
          }

          // PiP mode - only on Android
          // On iOS, true video-only PiP is used where the video floats in a
          // system-controlled window, so the main app should continue normally.
          // On Android, the entire Activity goes into PiP mode, so we need to
          // show only the video.
          if (value.isPipActive && _isAndroid) {
            if (pipBuilder != null) {
              return pipBuilder!(context, controller, child);
            }
            if (useDefaultPip) {
              return _buildDefaultPip(context);
            }
          }

          // Normal view
          return builder(context, controller, child);
        },
      );

  /// Builds the default fullscreen view.
  ///
  /// Uses a black background with the video player centered, maintaining
  /// the same control mode as the normal view.
  Widget _buildDefaultFullscreen(BuildContext context) {
    if (controlsMode == ControlsMode.native && controlsBuilder == null) {
      final videoSize = controller.value.size;
      final aspectRatio = videoSize != null
          ? videoSize.width / videoSize.height
          : 16 / 9;

      return ColoredBox(
        color: const Color(0xFF000000),
        child: SafeArea(
          child: Center(
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: ProVideoPlayer(
                controller: controller,
                controlsMode: controlsMode,
              ),
            ),
          ),
        ),
      );
    }

    final videoSize = controller.value.size;
    final aspectRatio = videoSize != null
        ? videoSize.width / videoSize.height
        : 16 / 9;
    final controls =
        controlsBuilder?.call(context, controller) ??
        (controlsMode == ControlsMode.flutter
            ? VideoPlayerControls(controller: controller)
            : null);

    return ColoredBox(
      color: const Color(0xFF000000),
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: ProVideoPlayer(
                  controller: controller,
                  controlsMode: ControlsMode.none,
                ),
              ),
            ),
            if (controls != null) controls,
          ],
        ),
      ),
    );
  }

  /// Builds the default PiP view for Android.
  ///
  /// Shows a minimal view with compact controls optimized for the small
  /// PiP window (large centered play/pause button, simple progress bar).
  Widget _buildDefaultPip(BuildContext context) => ColoredBox(
    color: const Color(0xFF000000),
    child: Center(
      child: ProVideoPlayer(
        controller: controller,
        controlsBuilder: (context, ctrl) => VideoPlayerControls(
          controller: ctrl,
          compactMode: CompactMode.always,
        ),
      ),
    ),
  );

  /// Returns true if running on Android.
  bool get _isAndroid {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }
}
