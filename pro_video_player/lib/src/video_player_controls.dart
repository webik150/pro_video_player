import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

import 'controls/compact_layout.dart';
import 'controls/controls_enums.dart';
import 'controls/desktop_video_controls.dart';
import 'controls/dialogs/keyboard_shortcuts_dialog.dart';
import 'controls/fullscreen_page.dart';
import 'controls/mobile_video_controls.dart';
import 'controls/seek_preview.dart';
import 'controls/wrappers/desktop_controls_wrapper.dart';
import 'controls/wrappers/gesture_controls_wrapper.dart';
import 'controls/wrappers/simple_tap_wrapper.dart';
import 'pro_video_player_controller.dart';
import 'subtitle_overlay.dart';
import 'video_controls_config.dart';
import 'video_controls_controller.dart';
import 'video_player_theme.dart';

export 'controls/controls_enums.dart';

/// A cross-platform Flutter widget that provides intuitive video controls.
///
/// This widget provides a feature-rich video player interface with:
/// - Gesture controls (double-tap to seek, swipe for volume/brightness)
/// - Auto-hiding overlay controls
/// - Play/pause, seek slider, and time display
/// - Fullscreen toggle (optional)
/// - Volume and brightness controls
/// - Buffering indicator
/// - Themeable appearance
///
/// ## Example
///
/// Basic usage with default theme:
///
/// ```dart
/// ProVideoPlayer(
///   controller: _controller,
///   controlsBuilder: (context, controller) => VideoPlayerControls(
///     controller: controller,
///   ),
/// )
/// ```
///
/// With custom theme:
///
/// ```dart
/// VideoPlayerThemeData(
///   theme: VideoPlayerTheme.light(),
///   child: ProVideoPlayer(
///     controller: _controller,
///     controlsBuilder: (context, controller) => VideoPlayerControls(
///       controller: controller,
///     ),
///   ),
/// )
/// ```
class VideoPlayerControls extends StatefulWidget {
  /// Creates video player controls with an intuitive interface.
  ///
  /// The [controller] must be initialized before the widget is built.
  ///
  /// The [theme] parameter allows customization of colors and styles. If not
  /// provided, uses the theme from [VideoPlayerThemeData] or a default theme.
  const VideoPlayerControls({
    required this.controller,
    super.key,
    this.theme,
    this.subtitleStyle,
    this.renderSubtitlesInternally = true,
    this.buttonsConfig = const ButtonsConfig(),
    this.gestureConfig = const GestureConfig(),
    this.behaviorConfig = const ControlsBehaviorConfig(),
    this.playbackOptionsConfig = const PlaybackOptionsConfig(),
    this.fullscreenConfig = const FullscreenConfig(),
    this.compactMode = CompactMode.auto,
    // 250x180 threshold accommodates narrow screens like Z Fold 3 front display (~260dp)
    this.compactThreshold = const Size(250, 180),
    this.playerToolbarActions,
    this.maxPlayerToolbarActions,
    this.autoOverflowActions = true,
    this.onDismiss,
    this.onControlsControllerCreated,
    this.onSeekBarFocusNodeCreated,
    this.forceMobileLayout =
        false, // Test-only: force mobile layout even on desktop
    this.testIsPipAvailable,
    this.testIsBackgroundPlaybackSupported,
    this.testIsCastingSupported,
  });

  /// The video player controller.
  final ProVideoPlayerController controller;

  /// Optional theme override. If null, uses theme from [VideoPlayerThemeData].
  final VideoPlayerTheme? theme;

  /// Optional subtitle style configuration.
  ///
  /// Controls the appearance of subtitles rendered by [SubtitleOverlay],
  /// including text color, font size, background color, stroke/outline,
  /// position (top/middle/bottom), and text alignment (left/center/right).
  ///
  /// If null, uses default subtitle styling from [SubtitleStyle].
  ///
  /// See [SubtitleStyle] for available customization options.
  final SubtitleStyle? subtitleStyle;

  /// Whether to render subtitles within this controls widget.
  ///
  /// When `false`, subtitles are rendered at the parent widget level
  /// (ProVideoPlayer), allowing them to appear independently of controls.
  /// This is used internally to support subtitle rendering across all layout modes.
  ///
  /// When `true`, subtitles are rendered as part of the controls overlay stack.
  ///
  /// Defaults to `true` for backwards compatibility.
  final bool renderSubtitlesInternally;

  /// Configuration for button visibility in controls.
  final ButtonsConfig buttonsConfig;

  /// Configuration for gesture controls.
  final GestureConfig gestureConfig;

  /// Configuration for controls behavior (auto-hide, keyboard shortcuts, etc.).
  final ControlsBehaviorConfig behaviorConfig;

  /// Configuration for playback options (speed, scaling mode, live scrubbing).
  final PlaybackOptionsConfig playbackOptionsConfig;

  /// Configuration for fullscreen behavior.
  final FullscreenConfig fullscreenConfig;

  /// Controls when compact mode is enabled.
  ///
  /// Compact mode shows a simplified UI with only essential controls:
  /// - Center play/pause button
  /// - Simple progress bar (no time display)
  /// - No player toolbar buttons
  /// - Gestures are disabled (except tap to play/pause)
  ///
  /// Defaults to [CompactMode.auto], which enables compact mode when
  /// the player size falls below [compactThreshold].
  final CompactMode compactMode;

  /// Size threshold for automatic compact mode.
  ///
  /// When [compactMode] is [CompactMode.auto], compact mode is enabled
  /// if either the width or height falls below this threshold.
  ///
  /// Defaults to 250x180 pixels, which accommodates narrow screens like
  /// the Samsung Z Fold front display (~260dp wide).
  final Size compactThreshold;

  /// Specifies which actions to show in the player toolbar and their order.
  ///
  /// When provided, only the specified actions will be shown, in the order
  /// they appear in this list. Actions that don't meet their visibility
  /// conditions (e.g., subtitles without tracks) are automatically hidden.
  ///
  /// When `null` (default), all applicable actions are shown in the default
  /// order based on the `show*` properties (e.g., [showSpeedButton]).
  ///
  /// Example:
  /// ```dart
  /// VideoPlayerControls(
  ///   controller: controller,
  ///   playerToolbarActions: [
  ///     PlayerToolbarAction.subtitles,
  ///     PlayerToolbarAction.speed,
  ///     PlayerToolbarAction.fullscreen,
  ///   ],
  /// )
  /// ```
  final List<PlayerToolbarAction>? playerToolbarActions;

  /// Maximum number of actions to show directly in the player toolbar.
  ///
  /// When the number of visible actions exceeds this limit, the remaining
  /// actions are moved to an overflow menu (⋮ button).
  ///
  /// When `null` (default), the toolbar uses [autoOverflowActions] to determine
  /// whether to automatically calculate the maximum based on available width.
  ///
  /// Example:
  /// ```dart
  /// VideoPlayerControls(
  ///   controller: controller,
  ///   playerToolbarActions: [
  ///     PlayerToolbarAction.subtitles,
  ///     PlayerToolbarAction.audio,
  ///     PlayerToolbarAction.quality,
  ///     PlayerToolbarAction.speed,
  ///     PlayerToolbarAction.fullscreen,
  ///   ],
  ///   maxPlayerToolbarActions: 3, // First 3 visible, rest in overflow
  /// )
  /// ```
  final int? maxPlayerToolbarActions;

  /// Whether to automatically move toolbar actions to overflow when they don't fit.
  ///
  /// When `true` (default), the toolbar measures available width and automatically
  /// moves actions that don't fit into an overflow menu (⋮ button).
  ///
  /// When `false`, all actions are shown directly (may cause overflow on narrow screens).
  ///
  /// This is ignored when [maxPlayerToolbarActions] is explicitly set.
  final bool autoOverflowActions;

  /// Callback invoked when the dismiss button is tapped in fullscreen-only mode.
  ///
  /// When [VideoPlayerOptions.fullscreenOnly] is `true` and this callback is
  /// provided, a close button (X) appears in the top-left corner of the player.
  /// Tapping this button invokes the callback, allowing the app to navigate
  /// away from the player screen.
  ///
  /// This is useful for dedicated video player apps that need a way to dismiss
  /// the player while keeping the fullscreen-only behavior (no exit-to-windowed).
  final VoidCallback? onDismiss;

  /// Callback invoked after the controls controller has been created.
  ///
  /// This lets surrounding widgets coordinate controls visibility with
  /// interactions that live outside the controls focus subtree.
  final ValueChanged<VideoControlsController>? onControlsControllerCreated;

  /// Callback invoked after the seek bar focus node has been created.
  final ValueChanged<FocusNode>? onSeekBarFocusNodeCreated;

  /// Force mobile layout even on desktop platforms.
  ///
  /// This is primarily for testing to avoid desktop-specific gesture wrappers.
  /// Defaults to `false`.
  final bool forceMobileLayout;

  /// Test-only: Directly inject PiP availability instead of checking asynchronously.
  ///
  /// When provided, bypasses async PiP check for testing.
  /// This is not @visibleForTesting because it's passed to VideoControlsController.
  final bool? testIsPipAvailable;

  /// Test-only: Directly inject background playback support instead of checking asynchronously.
  ///
  /// When provided, bypasses async background check for testing.
  /// This is not @visibleForTesting because it's passed to VideoControlsController.
  final bool? testIsBackgroundPlaybackSupported;

  /// Test-only: Directly inject casting support instead of checking asynchronously.
  ///
  /// When provided, bypasses async casting check for testing.
  /// This is not @visibleForTesting because it's passed to VideoControlsController.
  final bool? testIsCastingSupported;

  @override
  State<VideoPlayerControls> createState() => _VideoPlayerControlsState();
}

class _VideoPlayerControlsState extends State<VideoPlayerControls> {
  late final VideoControlsController _controlsController;
  late final FocusNode _seekBarFocusNode;
  late final FocusNode _toolbarFocusNode;

  KeyEventResult _handleControlsNavigationKey(FocusNode node, KeyEvent event) {
    if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
        (event.logicalKey == LogicalKeyboardKey.arrowUp ||
            event.logicalKey == LogicalKeyboardKey.arrowDown ||
            event.logicalKey == LogicalKeyboardKey.arrowLeft ||
            event.logicalKey == LogicalKeyboardKey.arrowRight)) {
      _controlsController
        ..showControls()
        ..resetHideTimer();

      if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
          _seekBarFocusNode.canRequestFocus) {
        if (_seekBarFocusNode.hasFocus) {
          FocusScope.of(
            node.context!,
          ).focusInDirection(TraversalDirection.down);
        } else {
          _seekBarFocusNode.requestFocus();
        }
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
          _seekBarFocusNode.hasFocus) {
        if (_toolbarFocusNode.context != null &&
            _toolbarFocusNode.canRequestFocus) {
          _toolbarFocusNode.requestFocus();
        } else {
          FocusScope.of(node.context!).focusInDirection(TraversalDirection.up);
        }
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  void initState() {
    super.initState();

    // Create the controller with all configuration
    _controlsController = VideoControlsController(
      videoController: widget.controller,
      buttonsConfig: widget.buttonsConfig,
      gestureConfig: widget.gestureConfig,
      behaviorConfig: widget.behaviorConfig,
      playbackOptionsConfig: widget.playbackOptionsConfig,
      fullscreenConfig: widget.fullscreenConfig,
      testIsPipAvailable: widget.testIsPipAvailable,
      testIsBackgroundPlaybackSupported:
          widget.testIsBackgroundPlaybackSupported,
      testIsCastingSupported: widget.testIsCastingSupported,
      onShowKeyboardShortcuts: () {
        if (mounted) {
          KeyboardShortcutsDialog.show(
            context: context,
            theme: widget.theme ?? const VideoPlayerTheme(),
          );
        }
      },
    );
    _seekBarFocusNode = FocusNode(debugLabel: 'Video seek bar');
    _toolbarFocusNode = FocusNode(debugLabel: 'Video toolbar');
    widget.onControlsControllerCreated?.call(_controlsController);
    widget.onSeekBarFocusNodeCreated?.call(_seekBarFocusNode);

    // Listen to controller changes to trigger rebuilds
    _controlsController.addListener(_onControllerChanged);

    // Auto-enter fullscreen if fullscreenOnly mode is enabled
    if (widget.controller.options.fullscreenOnly &&
        !widget.controller.value.isFullscreen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _enterFullscreen();
      });
    }
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {
        // Controller state changed, rebuild UI
      });
    }
  }

  @override
  void dispose() {
    _controlsController
      ..removeListener(_onControllerChanged)
      ..dispose();
    _seekBarFocusNode.dispose();
    _toolbarFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(VideoPlayerControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If controller changed, we would need to recreate _controlsController
    // For now, we assume controller doesn't change during widget lifetime
  }

  /// Returns true if running on a desktop platform.
  bool get _isDesktopPlatform => _controlsController.isDesktopPlatform;

  /// Determines if compact mode should be active based on the given constraints.
  bool _isCompactMode(BoxConstraints constraints) {
    switch (widget.compactMode) {
      case CompactMode.never:
        return false;
      case CompactMode.always:
        return true;
      case CompactMode.auto:
        // Check if player is in PiP mode
        if (widget.controller.value.isPipActive) {
          return true;
        }
        // Check if size is below threshold
        return constraints.maxWidth < widget.compactThreshold.width ||
            constraints.maxHeight < widget.compactThreshold.height;
    }
  }

  void _enterFullscreen() {
    if (widget.fullscreenConfig.onEnterFullscreen != null) {
      // Use custom fullscreen handler
      widget.fullscreenConfig.onEnterFullscreen!();
    } else {
      // Default: push fullscreen route
      _pushFullscreenRoute();
    }
  }

  void _exitFullscreen() {
    // Block exit if fullscreenOnly mode is enabled
    if (widget.controller.options.fullscreenOnly) return;

    if (widget.fullscreenConfig.onExitFullscreen != null) {
      // Use custom fullscreen exit handler
      widget.fullscreenConfig.onExitFullscreen!();
    } else {
      // Default: pop fullscreen route and exit fullscreen
      if (_isDesktopPlatform) {
        widget.controller.setFlutterFullscreenState(isFullscreen: false);
        unawaited(
          ProVideoPlayerPlatform.instance.setWindowFullscreen(
            fullscreen: false,
          ),
        );
      } else {
        unawaited(widget.controller.exitFullscreen());
      }
      unawaited(Navigator.of(context).maybePop());
    }
  }

  void _pushFullscreenRoute() {
    unawaited(
      Navigator.of(context).push(
        PageRouteBuilder<void>(
          barrierColor: Colors.black,
          pageBuilder: (context, animation, secondaryAnimation) =>
              FullscreenVideoPage(
                controller: widget.controller,
                theme: widget.theme,
                subtitleStyle: widget.subtitleStyle,
                onDismiss: widget.onDismiss,
                onExitFullscreen: () {
                  if (_isDesktopPlatform) {
                    widget.controller.setFlutterFullscreenState(
                      isFullscreen: false,
                    );
                    unawaited(
                      ProVideoPlayerPlatform.instance.setWindowFullscreen(
                        fullscreen: false,
                      ),
                    );
                  } else {
                    unawaited(widget.controller.exitFullscreen());
                  }
                  unawaited(Navigator.of(context).maybePop());
                },
              ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 200),
          reverseTransitionDuration: const Duration(milliseconds: 200),
        ),
      ),
    );

    // Enter fullscreen
    if (_isDesktopPlatform) {
      widget.controller.setFlutterFullscreenState(isFullscreen: true);
      unawaited(
        ProVideoPlayerPlatform.instance.setWindowFullscreen(fullscreen: true),
      );
    } else {
      unawaited(
        widget.controller.enterFullscreen(
          orientation: widget.fullscreenConfig.orientation,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? VideoPlayerThemeData.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // In PiP mode, hide all Flutter controls
        final isPipActive = widget.controller.value.isPipActive;
        if (isPipActive) {
          if (widget.renderSubtitlesInternally) {
            return SubtitleOverlay(
              controller: widget.controller,
              style: widget.subtitleStyle,
            );
          }
          return const SizedBox.shrink();
        }

        // In fullscreenOnly mode, hide controls until fullscreen is active
        final isFullscreenOnly = widget.controller.options.fullscreenOnly;
        final isFullscreen = widget.controller.value.isFullscreen;
        if (isFullscreenOnly && !isFullscreen) {
          return const ColoredBox(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final isCompact = _isCompactMode(constraints);

        // Build controls content
        final controlsContent = isCompact
            ? CompactLayout(controller: widget.controller, theme: theme)
            : _buildFullControls(theme);

        // Wrap controls in animated opacity overlay
        final controlsOverlay = Positioned.fill(
          child: AnimatedOpacity(
            opacity: _controlsController.controlsState.visible ? 1.0 : 0.0,
            // Hide instantly (no animation) during gestures, normal animation otherwise
            duration: _controlsController.controlsState.hideInstantly
                ? Duration.zero
                : const Duration(milliseconds: 100),
            onEnd: () {
              if (mounted) {
                setState(() {
                  _controlsController.controlsState.setFullyVisible(
                    fullyVisible: _controlsController.controlsState.visible,
                  );
                });
                // Sync system UI visibility
                unawaited(_controlsController.updateSystemUiForFullscreen());
              }
            },
            child: IgnorePointer(
              ignoring: !_controlsController.controlsState.isFullyVisible,
              child: Focus(
                key: const ValueKey('video-controls-navigation-focus'),
                onKeyEvent: _handleControlsNavigationKey,
                child: controlsContent,
              ),
            ),
          ),
        );

        // Build stack with subtitles and controls
        final stackContent = Stack(
          children: [
            const SizedBox.expand(),
            if (widget.renderSubtitlesInternally)
              SubtitleOverlay(
                controller: widget.controller,
                style: widget.subtitleStyle,
              ),
            controlsOverlay,
          ],
        );

        // Wrap with appropriate gesture handler based on platform and settings
        if (_isDesktopPlatform && !widget.forceMobileLayout) {
          return DesktopControlsWrapper(
            controller: widget.controller,
            controlsController: _controlsController,
            theme: theme,
            showFullscreenButton: widget.buttonsConfig.showFullscreenButton,
            onEnterFullscreen: _enterFullscreen,
            onExitFullscreen: _exitFullscreen,
            child: stackContent,
          );
        }

        if (widget.gestureConfig.enableGestures && !isCompact) {
          return GestureControlsWrapper(
            controller: widget.controller,
            controlsController: _controlsController,
            skipDuration: widget.gestureConfig.skipDuration,
            seekSecondsPerInch: widget.gestureConfig.seekSecondsPerInch,
            enableDoubleTapSeek: widget.gestureConfig.enableDoubleTapSeek,
            enableVolumeGesture: widget.gestureConfig.enableVolumeGesture,
            enableBrightnessGesture:
                widget.gestureConfig.enableBrightnessGesture,
            enableSeekGesture: widget.gestureConfig.enableSeekGesture,
            enablePlaybackSpeedGesture:
                widget.gestureConfig.enablePlaybackSpeedGesture,
            autoHide: widget.behaviorConfig.autoHide,
            autoHideDuration: widget.behaviorConfig.autoHideDuration,
            onBrightnessChanged: widget.gestureConfig.onBrightnessChanged,
            child: stackContent,
          );
        }

        return SimpleTapWrapper(
          controller: widget.controller,
          controlsController: _controlsController,
          child: stackContent,
        );
      },
    );
  }

  /// Builds the full controls layout.
  Widget _buildFullControls(VideoPlayerTheme theme) {
    if (_isDesktopPlatform && !widget.forceMobileLayout) {
      return DesktopVideoControls(
        controller: widget.controller,
        theme: theme,
        controlsState: _controlsController.controlsState,
        gestureSeekPosition: _controlsController.gestureSeekPosition.value,
        dragStartPosition: _controlsController.dragStartPosition.value,
        minimalToolbarOnDesktop: widget.behaviorConfig.minimalToolbarOnDesktop,
        shouldShowVolumeButton: _controlsController.shouldShowVolumeButton,
        liveScrubbingMode: widget.playbackOptionsConfig.liveScrubbingMode,
        enableSeekBarHoverPreview:
            widget.behaviorConfig.enableSeekBarHoverPreview,
        showFullscreenButton: widget.buttonsConfig.showFullscreenButton,
        onDragStart: () => setState(_controlsController.startDragging),
        onDragEnd: () => setState(_controlsController.endDragging),
        onToggleTimeDisplay: () =>
            setState(_controlsController.toggleTimeDisplay),
        onMouseEnter: () => setState(
          () => _controlsController.setMouseOverControls(isOver: true),
        ),
        onMouseExit: () => setState(
          () => _controlsController.setMouseOverControls(isOver: false),
        ),
        onResetHideTimer: _controlsController.resetHideTimer,
        onFullscreenEnter: _enterFullscreen,
        onFullscreenExit: _exitFullscreen,
      );
    }

    // Mobile layout
    return MobileVideoControls(
      controller: widget.controller,
      theme: theme,
      controlsState: _controlsController.controlsState,
      gestureSeekPosition: _controlsController.gestureSeekPosition.value,
      showSkipButtons: widget.buttonsConfig.showSkipButtons,
      skipDuration: widget.gestureConfig.skipDuration,
      liveScrubbingMode: widget.playbackOptionsConfig.liveScrubbingMode,
      showSeekBarHoverPreview: widget.behaviorConfig.enableSeekBarHoverPreview,
      seekBarFocusNode: _seekBarFocusNode,
      toolbarFocusNode: _toolbarFocusNode,
      onKeyboardInteraction: () => _controlsController
        ..showControls()
        ..resetHideTimer(),
      showSubtitleButton: widget.buttonsConfig.showSubtitleButton,
      showAudioButton: widget.buttonsConfig.showAudioButton,
      showQualityButton: widget.buttonsConfig.showQualityButton,
      showSpeedButton: widget.buttonsConfig.showSpeedButton,
      showScalingModeButton: widget.buttonsConfig.showScalingModeButton,
      showBackgroundPlaybackButton:
          widget.buttonsConfig.showBackgroundPlaybackButton,
      showPipButton: widget.buttonsConfig.showPipButton,
      showOrientationLockButton: widget.buttonsConfig.showOrientationLockButton,
      showFullscreenButton: widget.buttonsConfig.showFullscreenButton,
      playerToolbarActions: widget.playerToolbarActions,
      maxPlayerToolbarActions: widget.maxPlayerToolbarActions,
      autoOverflowActions: widget.autoOverflowActions,
      onDismiss: widget.onDismiss,
      isDesktopPlatform: _isDesktopPlatform,
      onDragStart: () => setState(_controlsController.startDragging),
      onDragEnd: () => setState(_controlsController.endDragging),
      onToggleTimeDisplay: () =>
          setState(_controlsController.toggleTimeDisplay),
      onShowQualityPicker: (context, theme) =>
          _controlsController.showQualityPicker(context: context, theme: theme),
      onShowSubtitlePicker: (context, theme) => _controlsController
          .showSubtitlePicker(context: context, theme: theme),
      onShowAudioPicker: (context, theme) =>
          _controlsController.showAudioPicker(context: context, theme: theme),
      onShowChaptersPicker: (context, theme) => _controlsController
          .showChaptersPicker(context: context, theme: theme),
      onShowSpeedPicker: (context, theme) =>
          _controlsController.showSpeedPicker(context: context, theme: theme),
      onShowScalingModePicker: (theme) => _controlsController
          .showScalingModePicker(context: context, theme: theme),
      onShowOrientationLockPicker: (theme) => _controlsController
          .showOrientationLockPicker(context: context, theme: theme),
      onFullscreenEnter: _enterFullscreen,
      onFullscreenExit: _exitFullscreen,
      centerControls: _buildCenterControls(theme),
    );
  }

  Widget _buildCenterControls(VideoPlayerTheme theme) => Expanded(
    child: Center(
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: widget.controller,
        builder: (context, value, child) {
          if (_controlsController.controlsState.isDragging &&
              _controlsController.controlsState.dragProgress != null &&
              _controlsController.dragStartPosition.value != null) {
            return SeekPreview(
              dragProgress: _controlsController.controlsState.dragProgress!,
              dragStartPosition: _controlsController.dragStartPosition.value!,
              duration: value.duration,
              theme: theme,
            );
          }
          if (value.playbackState == PlaybackState.buffering) {
            return CircularProgressIndicator(color: theme.primaryColor);
          }
          return const SizedBox.shrink();
        },
      ),
    ),
  );
}
