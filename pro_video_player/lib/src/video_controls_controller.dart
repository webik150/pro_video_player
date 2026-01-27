import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show ChangeNotifier, ValueNotifier, kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyEvent, SystemChrome, SystemUiMode;

import 'controls/context_menu_builder.dart';
import 'controls/dialogs/audio_picker_dialog.dart';
import 'controls/dialogs/chapters_picker_dialog.dart';
import 'controls/dialogs/orientation_lock_picker_dialog.dart';
import 'controls/dialogs/quality_picker_dialog.dart';
import 'controls/dialogs/scaling_mode_picker_dialog.dart';
import 'controls/dialogs/speed_picker_dialog.dart';
import 'controls/dialogs/subtitle_picker_dialog.dart';
import 'controls/keyboard_shortcut_handler.dart';
import 'pro_video_player_controller.dart';
import 'video_controls_config.dart';
import 'video_controls_state.dart';
import 'video_player_theme.dart';
import 'video_toolbar_manager.dart';

/// Controller for managing video player controls state and behavior.
///
/// This class handles all state management, event handling, and business logic
/// for video player controls, separating concerns from the presentation layer.
///
/// The controller manages:
/// - Controls visibility and auto-hide behavior
/// - Keyboard shortcuts and mouse interactions
/// - Fullscreen transitions
/// - Platform-specific features (PiP, background playback, casting)
/// - Drag/seek state during user interactions
class VideoControlsController extends ChangeNotifier {
  /// Creates a video controls controller.
  VideoControlsController({
    required ProVideoPlayerController videoController,
    this.buttonsConfig = const ButtonsConfig(),
    this.gestureConfig = const GestureConfig(),
    this.behaviorConfig = const ControlsBehaviorConfig(),
    this.playbackOptionsConfig = const PlaybackOptionsConfig(),
    this.fullscreenConfig = const FullscreenConfig(),
    this.onShowKeyboardShortcuts,
    this.enablePipCheck = true,
    this.enableBackgroundCheck = true,
    this.enableCastingCheck = true,
    bool? testIsPipAvailable,
    bool? testIsBackgroundPlaybackSupported,
    bool? testIsCastingSupported,
  }) : _videoController = videoController {
    _videoController.addListener(_onPlayerValueChanged);
    _resetHideTimer();

    // Initialize keyboard handler
    _keyboardHandler = KeyboardShortcutHandler(
      videoController: _videoController,
      keyboardSeekDuration: behaviorConfig.keyboardSeekDuration,
      onShowOverlay: _showKeyboardOverlay,
      onResetHideTimer: _resetHideTimer,
      onShowKeyboardShortcuts: onShowKeyboardShortcuts,
    );

    // Initialize capability checks
    _initializeCapabilityChecks(
      testIsPipAvailable: testIsPipAvailable,
      testIsBackgroundPlaybackSupported: testIsBackgroundPlaybackSupported,
      testIsCastingSupported: testIsCastingSupported,
    );
  }

  void _initializeCapabilityChecks({
    bool? testIsPipAvailable,
    bool? testIsBackgroundPlaybackSupported,
    bool? testIsCastingSupported,
  }) {
    // Use test values if provided (test-only path)
    if (testIsPipAvailable != null) {
      _controlsState.setIsPipAvailable(available: testIsPipAvailable);
    } else if (enablePipCheck) {
      if (_cachedPipSupported != null) {
        _controlsState.setIsPipAvailable(available: _cachedPipSupported!);
      } else {
        unawaited(_checkPipAvailability());
      }
    }

    if (testIsBackgroundPlaybackSupported != null) {
      _controlsState.setIsBackgroundPlaybackSupported(supported: testIsBackgroundPlaybackSupported);
    } else if (enableBackgroundCheck) {
      if (_cachedBackgroundPlaybackSupported != null) {
        _controlsState.setIsBackgroundPlaybackSupported(supported: _cachedBackgroundPlaybackSupported!);
      } else {
        unawaited(_checkBackgroundPlaybackSupport());
      }
    }

    if (testIsCastingSupported != null) {
      _controlsState.setIsCastingSupported(supported: testIsCastingSupported);
    } else if (enableCastingCheck) {
      if (_cachedCastingSupported != null) {
        _controlsState.setIsCastingSupported(supported: _cachedCastingSupported!);
      } else {
        unawaited(_checkCastingSupport());
      }
    }
  }

  final ProVideoPlayerController _videoController;
  late final KeyboardShortcutHandler _keyboardHandler;

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

  /// Callback invoked when the user presses the "?" key to show keyboard shortcuts.
  final VoidCallback? onShowKeyboardShortcuts;

  /// Whether to check PiP availability asynchronously.
  @visibleForTesting
  final bool enablePipCheck;

  /// Whether to check background playback support asynchronously.
  @visibleForTesting
  final bool enableBackgroundCheck;

  /// Whether to check casting support asynchronously.
  @visibleForTesting
  final bool enableCastingCheck;

  // State
  late final VideoControlsState _controlsState = VideoControlsState();
  final FocusNode _focusNode = FocusNode();

  // Notifiers for reactive UI
  final ValueNotifier<Duration?> _dragStartPosition = ValueNotifier(null);
  final ValueNotifier<Duration?> _gestureSeekPosition = ValueNotifier(null);

  // Track whether video was playing before dragging started
  bool _wasPlayingBeforeDrag = false;

  /// The video player controller.
  ProVideoPlayerController get videoController => _videoController;

  /// The controls state.
  VideoControlsState get controlsState => _controlsState;

  /// Focus node for keyboard shortcuts.
  FocusNode get focusNode => _focusNode;

  /// Current drag start position notifier.
  ValueNotifier<Duration?> get dragStartPosition => _dragStartPosition;

  /// Current drag start position value.
  Duration? get dragStartPositionValue => _dragStartPosition.value;

  /// Current gesture seek position notifier.
  ValueNotifier<Duration?> get gestureSeekPosition => _gestureSeekPosition;

  /// Current gesture seek position value.
  Duration? get gestureSeekPositionValue => _gestureSeekPosition.value;

  /// Whether the current platform is desktop (macOS, Windows, Linux, or web).
  bool get isDesktopPlatform {
    if (kIsWeb) return true;
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }

  /// Whether the volume button should be shown.
  bool get shouldShowVolumeButton =>
      VideoToolbarManager.shouldShowVolumeButton(isWeb: kIsWeb, isMacOS: !kIsWeb && Platform.isMacOS);

  // Static cache for capability checks (platform-level, doesn't change)
  static bool? _cachedPipSupported;
  static bool? _cachedBackgroundPlaybackSupported;
  static bool? _cachedCastingSupported;

  // ==================== Capability Checks ====================

  Future<void> _checkPipAvailability() async {
    if (!buttonsConfig.showPipButton) return;

    if (_cachedPipSupported != null) {
      _controlsState.setIsPipAvailable(available: _cachedPipSupported!);
      return;
    }

    final available = await _videoController.isPipAvailable();
    _cachedPipSupported = available;
    _controlsState.setIsPipAvailable(available: available);
  }

  Future<void> _checkBackgroundPlaybackSupport() async {
    if (!buttonsConfig.showBackgroundPlaybackButton) return;

    if (_cachedBackgroundPlaybackSupported != null) {
      _controlsState.setIsBackgroundPlaybackSupported(supported: _cachedBackgroundPlaybackSupported!);
      return;
    }

    final supported = await _videoController.isBackgroundPlaybackSupported();
    _cachedBackgroundPlaybackSupported = supported;
    _controlsState.setIsBackgroundPlaybackSupported(supported: supported);
  }

  Future<void> _checkCastingSupport() async {
    if (_cachedCastingSupported != null) {
      _controlsState.setIsCastingSupported(supported: _cachedCastingSupported!);
      return;
    }

    final supported = await _videoController.isCastingSupported();
    _cachedCastingSupported = supported;
    _controlsState.setIsCastingSupported(supported: supported);
  }

  // ==================== Player Event Handling ====================

  void _onPlayerValueChanged() {
    final isPlaying = _videoController.value.isPlaying;
    final isCasting = _videoController.value.isCasting;
    final isFullscreen = _videoController.value.isFullscreen;
    final isPipActive = _videoController.value.isPipActive;

    var stateChanged = false;

    // During casting, always ensure controls are visible
    if (isCasting && !_controlsState.visible) {
      _controlsState.showControls();
      notifyListeners();
      return;
    }

    // Reset hide timer when play/pause state changes
    if (_controlsState.lastIsPlaying != isPlaying) {
      _controlsState.lastIsPlaying = isPlaying;
      _resetHideTimer();
    }

    // Notify listeners when fullscreen state changes
    if (_controlsState.lastIsFullscreen != isFullscreen) {
      _controlsState.lastIsFullscreen = isFullscreen;
      stateChanged = true;
    }

    // Notify listeners when PiP state changes
    if (_controlsState.lastIsPipActive != isPipActive) {
      _controlsState.lastIsPipActive = isPipActive;
      stateChanged = true;
    }

    if (stateChanged) {
      notifyListeners();
    }
  }

  // ==================== Hide Timer Management ====================

  void _resetHideTimer() {
    _controlsState.cancelHideTimer();
    final isCasting = _videoController.value.isCasting;

    // During casting, always show controls (no auto-hide)
    if (isCasting) {
      if (!_controlsState.visible) {
        _controlsState.showControls();
        notifyListeners();
      }
      return;
    }

    // When mouse is hovering over controls area (desktop), keep controls visible
    if (_controlsState.isMouseOverControls) {
      if (!_controlsState.visible) {
        _controlsState.showControls();
        notifyListeners();
      }
      return;
    }

    if (behaviorConfig.autoHide && _videoController.value.isPlaying && !_controlsState.isDragging) {
      _controlsState.startHideTimer(behaviorConfig.autoHideDuration, () {
        if (_videoController.value.isPlaying &&
            !_videoController.value.isCasting &&
            !_controlsState.isMouseOverControls &&
            !_controlsState.isDragging) {
          _controlsState.hideControls();
          notifyListeners();
        }
      });
    } else if (!_videoController.value.isPlaying) {
      if (!_controlsState.visible) {
        _controlsState.showControls();
        notifyListeners();
      }
    }
  }

  /// Resets the auto-hide timer (called from UI on user interaction).
  void resetHideTimer() => _resetHideTimer();

  // ==================== Controls Visibility ====================

  /// Shows controls.
  void showControls() {
    _controlsState
      ..showControls()
      ..setFullyVisible(fullyVisible: true);
    notifyListeners();
  }

  /// Hides controls.
  void hideControls({bool instantly = false}) {
    _controlsState.hideControls(instantly: instantly);
    notifyListeners();
  }

  /// Toggles controls visibility.
  void toggleControlsVisibility() {
    _controlsState.toggleVisibility();
    if (_controlsState.visible) {
      _controlsState.setFullyVisible(fullyVisible: true);
    }
    notifyListeners();
  }

  /// Handles mouse hover on desktop platforms.
  void onMouseHover() {
    if (!_controlsState.visible) {
      _controlsState
        ..showControls()
        ..setFullyVisible(fullyVisible: true);
      notifyListeners();
    }
    _resetHideTimer();
  }

  /// Sets mouse over controls state.
  void setMouseOverControls({required bool isOver}) {
    _controlsState.setMouseOverControls(isOver: isOver);
    notifyListeners();
  }

  // ==================== Keyboard Overlay ====================

  /// Shows keyboard overlay for feedback (public API for external components).
  void showKeyboardOverlay(KeyboardOverlayType type, double value) {
    _showKeyboardOverlay(type, value);
  }

  void _showKeyboardOverlay(KeyboardOverlayType type, double value) {
    _controlsState.showKeyboardOverlay(type, value, const Duration(milliseconds: 800), () {
      _controlsState.hideKeyboardOverlay();
    });
    notifyListeners();
  }

  // ==================== Drag State ====================

  /// Starts dragging.
  void startDragging() {
    _controlsState.startDragging();
    _dragStartPosition.value = _videoController.value.position;

    _wasPlayingBeforeDrag = _videoController.value.isPlaying;
    if (_wasPlayingBeforeDrag) {
      unawaited(_videoController.pause());
    }

    notifyListeners();
  }

  /// Ends dragging.
  void endDragging() {
    _controlsState.endDragging();
    _dragStartPosition.value = null;

    if (_wasPlayingBeforeDrag) {
      unawaited(_videoController.play());
      _wasPlayingBeforeDrag = false;
    }

    notifyListeners();
  }

  /// Toggles time display format.
  void toggleTimeDisplay() {
    _controlsState.toggleTimeDisplay();
    notifyListeners();
  }

  /// Sets gesture seek position.
  set gestureSeekPositionValue(Duration? position) {
    _gestureSeekPosition.value = position;
  }

  /// Sets drag start position.
  set dragStartPositionValue(Duration? position) {
    _dragStartPosition.value = position;
  }

  // ==================== Keyboard Handling ====================

  /// Handles keyboard events for video player shortcuts.
  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!behaviorConfig.enableKeyboardShortcuts) {
      return KeyEventResult.ignored;
    }
    return _keyboardHandler.handleKeyEvent(event);
  }

  // ==================== Context Menu ====================

  /// Shows context menu at the given position.
  Future<void> showContextMenu({
    required BuildContext context,
    required Offset position,
    required VideoPlayerTheme theme,
    required VoidCallback onEnterFullscreenCallback,
    required VoidCallback onExitFullscreenCallback,
  }) async {
    if (!behaviorConfig.enableContextMenu || !isDesktopPlatform) return;

    _controlsState.lastContextMenuPosition = position;

    final contextMenuBuilder = ContextMenuBuilder(
      videoController: _videoController,
      buttonsConfig: buttonsConfig,
      isMinimalMode: behaviorConfig.minimalToolbarOnDesktop,
      isPipAvailable: _controlsState.isPipAvailable,
      isBackgroundPlaybackSupported: _controlsState.isBackgroundPlaybackSupported,
      onShowSubtitlePicker: showSubtitlePicker,
      onShowAudioPicker: showAudioPicker,
      onShowQualityPicker: showQualityPicker,
      onShowChaptersPicker: showChaptersPicker,
      onShowSpeedPicker: showSpeedPicker,
      onShowScalingModePicker: showScalingModePicker,
      onResetHideTimer: _resetHideTimer,
    );

    await contextMenuBuilder.show(
      context: context,
      position: position,
      theme: theme,
      onEnterFullscreen: onEnterFullscreenCallback,
      onExitFullscreen: onExitFullscreenCallback,
    );
  }

  // ==================== System UI ====================

  /// Updates system UI visibility for fullscreen mode.
  Future<void> updateSystemUiForFullscreen() async {
    if (!_videoController.value.isFullscreen) return;
    if (kIsWeb || isDesktopPlatform) return;

    if (_controlsState.visible) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);
    }
  }

  // ==================== Dialog Methods ====================

  /// Shows orientation lock picker dialog.
  void showOrientationLockPicker({required BuildContext context, required VideoPlayerTheme theme}) {
    OrientationLockPickerDialog.show(context: context, controller: _videoController, theme: theme);
  }

  /// Shows quality picker dialog.
  void showQualityPicker({required BuildContext context, required VideoPlayerTheme theme}) {
    QualityPickerDialog.show(
      context: context,
      controller: _videoController,
      theme: theme,
      lastContextMenuPosition: _controlsState.lastContextMenuPosition,
      onDismiss: _resetHideTimer,
    );
  }

  /// Shows audio picker dialog.
  void showAudioPicker({required BuildContext context, required VideoPlayerTheme theme}) {
    AudioPickerDialog.show(
      context: context,
      controller: _videoController,
      theme: theme,
      lastContextMenuPosition: _controlsState.lastContextMenuPosition,
      onDismiss: _resetHideTimer,
    );
  }

  /// Shows chapters picker dialog.
  void showChaptersPicker({required BuildContext context, required VideoPlayerTheme theme}) {
    ChaptersPickerDialog.show(context: context, controller: _videoController, theme: theme);
  }

  /// Shows scaling mode picker dialog.
  void showScalingModePicker({required BuildContext context, required VideoPlayerTheme theme}) {
    ScalingModePickerDialog.show(
      context: context,
      controller: _videoController,
      theme: theme,
      scalingModeOptions: playbackOptionsConfig.scalingModeOptions,
      onDismiss: _resetHideTimer,
    );
  }

  /// Shows subtitle picker dialog.
  void showSubtitlePicker({required BuildContext context, required VideoPlayerTheme theme}) {
    SubtitlePickerDialog.show(
      context: context,
      controller: _videoController,
      theme: theme,
      lastContextMenuPosition: _controlsState.lastContextMenuPosition,
      onDismiss: _resetHideTimer,
    );
  }

  /// Shows speed picker dialog.
  void showSpeedPicker({required BuildContext context, required VideoPlayerTheme theme}) {
    SpeedPickerDialog.show(
      context: context,
      controller: _videoController,
      theme: theme,
      speedOptions: playbackOptionsConfig.speedOptions,
      lastContextMenuPosition: _controlsState.lastContextMenuPosition,
      onDismiss: _resetHideTimer,
    );
  }

  @override
  void dispose() {
    _videoController.removeListener(_onPlayerValueChanged);
    _controlsState.dispose();
    _focusNode.dispose();
    _dragStartPosition.dispose();
    _gestureSeekPosition.dispose();
    super.dispose();
  }
}
