import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

import '../pro_video_player_controller.dart';
import '../video_player_theme.dart';
import '../video_toolbar_manager.dart';
import 'buttons/audio_button.dart';
import 'buttons/background_playback_button.dart';
import 'buttons/casting_button.dart';
import 'buttons/chapters_button.dart';
import 'buttons/fullscreen_button.dart';
import 'buttons/orientation_lock_button.dart';
import 'buttons/pip_button.dart';
import 'buttons/quality_button.dart';
import 'buttons/repeat_mode_button.dart';
import 'buttons/scaling_mode_button.dart';
import 'buttons/shuffle_button.dart';
import 'buttons/speed_button.dart';
import 'buttons/subtitle_button.dart';
import 'controls_enums.dart';

/// A player toolbar that displays action buttons with automatic overflow handling.
///
/// The toolbar adapts to available width by moving actions to an overflow menu
/// when space is constrained. Non-overflowable actions (like casting) are always
/// kept visible.
///
/// Example:
/// ```dart
/// PlayerToolbar(
///   controller: controller,
///   theme: theme,
///   // ... configuration parameters
/// )
/// ```
class PlayerToolbar extends StatelessWidget {
  /// Creates a player toolbar.
  const PlayerToolbar({
    required this.controller,
    required this.theme,
    required this.controlsState,
    required this.showSubtitleButton,
    required this.showAudioButton,
    required this.showQualityButton,
    required this.showSpeedButton,
    required this.showScalingModeButton,
    required this.showBackgroundPlaybackButton,
    required this.showPipButton,
    required this.showOrientationLockButton,
    required this.showFullscreenButton,
    required this.playerToolbarActions,
    required this.maxPlayerToolbarActions,
    required this.autoOverflowActions,
    required this.onDismiss,
    required this.isDesktopPlatform,
    required this.onShowQualityPicker,
    required this.onShowSubtitlePicker,
    required this.onShowAudioPicker,
    required this.onShowChaptersPicker,
    required this.onShowSpeedPicker,
    required this.onShowScalingModePicker,
    required this.onShowOrientationLockPicker,
    required this.onFullscreenEnter,
    required this.onFullscreenExit,
    this.focusNode,
    super.key,
  });

  /// The video player controller.
  final ProVideoPlayerController controller;

  /// The theme for styling the toolbar.
  final VideoPlayerTheme theme;

  /// The controls state (for isPipAvailable, etc.).
  final dynamic controlsState; // VideoControlsState

  /// Whether to show the subtitle button.
  final bool showSubtitleButton;

  /// Whether to show the audio track button.
  final bool showAudioButton;

  /// Whether to show the quality button.
  final bool showQualityButton;

  /// Whether to show the speed button.
  final bool showSpeedButton;

  /// Whether to show the scaling mode button.
  final bool showScalingModeButton;

  /// Whether to show the background playback button.
  final bool showBackgroundPlaybackButton;

  /// Whether to show the PiP button.
  final bool showPipButton;

  /// Whether to show the orientation lock button.
  final bool showOrientationLockButton;

  /// Whether to show the fullscreen button.
  final bool showFullscreenButton;

  /// Custom toolbar actions configuration.
  final List<PlayerToolbarAction>? playerToolbarActions;

  /// Maximum number of actions before overflow.
  final int? maxPlayerToolbarActions;

  /// Whether to automatically overflow actions.
  final bool autoOverflowActions;

  /// Callback for dismiss button in fullscreen-only mode.
  final VoidCallback? onDismiss;

  /// Whether the current platform is desktop.
  final bool isDesktopPlatform;

  /// Callback to show quality picker.
  final void Function(BuildContext context, VideoPlayerTheme theme)
  onShowQualityPicker;

  /// Callback to show subtitle picker.
  final void Function(BuildContext context, VideoPlayerTheme theme)
  onShowSubtitlePicker;

  /// Callback to show audio picker.
  final void Function(BuildContext context, VideoPlayerTheme theme)
  onShowAudioPicker;

  /// Callback to show chapters picker.
  final void Function(BuildContext context, VideoPlayerTheme theme)
  onShowChaptersPicker;

  /// Callback to show speed picker.
  final void Function(BuildContext context, VideoPlayerTheme theme)
  onShowSpeedPicker;

  /// Callback to show scaling mode picker.
  final void Function(VideoPlayerTheme theme) onShowScalingModePicker;

  /// Callback to show orientation lock picker.
  final void Function(VideoPlayerTheme theme) onShowOrientationLockPicker;

  /// Callback to enter fullscreen.
  final VoidCallback onFullscreenEnter;

  /// Callback to exit fullscreen.
  final VoidCallback onFullscreenExit;

  /// Focus node for returning to the toolbar from the seek bar.
  final FocusNode? focusNode;

  static const double _minTitleWidth = 120;
  static const double _actionButtonWidth = 48;

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: focusNode,
    child: Container(
      padding: theme.controlsPadding,
      child: LayoutBuilder(
        builder: (ctx, constraints) => ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (ctx, value, child) {
            final actions = _getVisibleActions(value);

            // Calculate how many actions can fit
            final (visibleActions, overflowActions) = _calculateToolbarActions(
              actions: actions,
              availableWidth: constraints.maxWidth,
              hasTitle: value.title != null,
            );

            final showDismissButton =
                controller.options.fullscreenOnly && onDismiss != null;

            return Row(
              children: [
                // Dismiss button for fullscreenOnly mode
                if (showDismissButton)
                  IconButton(
                    icon: Icon(Icons.close, color: theme.primaryColor),
                    tooltip: 'Close',
                    onPressed: onDismiss,
                  ),
                if (value.title != null)
                  Expanded(
                    child: Text(
                      value.title!,
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (value.title == null) const Spacer(),
                ...visibleActions.map(
                  (action) => _buildActionWidget(action, value, theme, ctx),
                ),
                if (overflowActions.isNotEmpty)
                  _buildOverflowMenu(overflowActions, value, theme, ctx),
              ],
            );
          },
        ),
      ),
    ),
  );

  /// Calculates which actions should be visible and which should overflow.
  ///
  /// Returns a tuple of (visibleActions, overflowActions).
  (List<PlayerToolbarAction>, List<PlayerToolbarAction>)
  _calculateToolbarActions({
    required List<PlayerToolbarAction> actions,
    required double availableWidth,
    required bool hasTitle,
  }) {
    // If maxPlayerToolbarActions is explicitly set, use that
    if (maxPlayerToolbarActions != null) {
      if (actions.length > maxPlayerToolbarActions!) {
        final visible = actions.take(maxPlayerToolbarActions!).toList();
        final overflow = actions.skip(maxPlayerToolbarActions!).toList();
        // Move any non-overflowable actions from overflow back to visible
        return _ensureNonOverflowableVisible(visible, overflow);
      }
      return (actions, <PlayerToolbarAction>[]);
    }

    // If auto-overflow is disabled, show all actions
    if (!autoOverflowActions) {
      return (actions, <PlayerToolbarAction>[]);
    }

    // Calculate available width for action buttons
    var actionsWidth = availableWidth;
    if (hasTitle) {
      actionsWidth -= _minTitleWidth; // Reserve space for title
    }

    // Calculate how many actions can fit
    // Account for overflow menu button if we'll need it
    final totalActionsWidth = actions.length * _actionButtonWidth;

    if (totalActionsWidth <= actionsWidth) {
      // All actions fit
      return (actions, <PlayerToolbarAction>[]);
    }

    // Need overflow menu - reserve space for it
    final availableForActions =
        actionsWidth - _actionButtonWidth; // Reserve space for overflow button
    final maxVisibleActions = (availableForActions / _actionButtonWidth)
        .floor()
        .clamp(0, actions.length);

    if (maxVisibleActions >= actions.length) {
      return (actions, <PlayerToolbarAction>[]);
    }

    final visible = actions.take(maxVisibleActions).toList();
    final overflow = actions.skip(maxVisibleActions).toList();

    // Ensure non-overflowable actions stay visible
    return _ensureNonOverflowableVisible(visible, overflow);
  }

  /// Ensures that non-overflowable actions (like casting) stay in the visible list.
  (List<PlayerToolbarAction>, List<PlayerToolbarAction>)
  _ensureNonOverflowableVisible(
    List<PlayerToolbarAction> visible,
    List<PlayerToolbarAction> overflow,
  ) {
    final mutableVisible = visible.toList();
    final mutableOverflow = overflow.toList();

    // Find non-overflowable actions in the overflow list
    final nonOverflowableInOverflow = mutableOverflow
        .where(VideoToolbarManager.isNonOverflowableAction)
        .toList();

    for (final action in nonOverflowableInOverflow) {
      // Remove from overflow
      mutableOverflow.remove(action);

      // Find a visible action that CAN be moved to overflow (from the end)
      for (var i = mutableVisible.length - 1; i >= 0; i--) {
        if (!VideoToolbarManager.isNonOverflowableAction(mutableVisible[i])) {
          // Move this action to overflow
          final displaced = mutableVisible.removeAt(i);
          mutableOverflow.insert(0, displaced);
          break;
        }
      }

      // Add the non-overflowable action to visible
      mutableVisible.add(action);
    }

    return (mutableVisible, mutableOverflow);
  }

  /// Returns the list of visible actions based on the configuration.
  List<PlayerToolbarAction> _getVisibleActions(VideoPlayerValue value) {
    // If playerToolbarActions is specified, use that list filtered by visibility
    if (playerToolbarActions != null) {
      return playerToolbarActions!
          .where((action) => _isActionVisible(action, value))
          .toList();
    }

    // Default behavior: build list using VideoToolbarManager
    return VideoToolbarManager.getDefaultToolbarActions(
      config: ToolbarConfig(
        showSubtitleButton: showSubtitleButton,
        showAudioButton: showAudioButton,
        showQualityButton: showQualityButton,
        showSpeedButton: showSpeedButton,
        showScalingModeButton: showScalingModeButton,
        showBackgroundPlaybackButton: showBackgroundPlaybackButton,
        showPipButton: showPipButton && controller.options.allowPip,
        showOrientationLockButton: showOrientationLockButton,
        showFullscreenButton: showFullscreenButton,
        fullscreenOnly: controller.options.fullscreenOnly,
      ),
      state: ToolbarState(
        hasPlaylist: value.playlist != null,
        hasSubtitleTracks: value.subtitleTracks.isNotEmpty,
        audioTrackCount: value.audioTracks.length,
        qualityTrackCount: value.qualityTracks.length,
        hasChapters: value.hasChapters,
        isCasting: value.isCasting,
        isBackgroundPlaybackSupported:
            (controlsState as dynamic).isBackgroundPlaybackSupported as bool?,
        isPipAvailable: (controlsState as dynamic).isPipAvailable as bool?,
        isCastingSupported:
            (controlsState as dynamic).isCastingSupported as bool?,
        isFullscreen: value.isFullscreen,
        isDesktopPlatform: isDesktopPlatform,
      ),
    );
  }

  /// Checks if an action should be visible based on its conditions.
  bool _isActionVisible(PlayerToolbarAction action, VideoPlayerValue value) =>
      VideoToolbarManager.shouldShowAction(
        action,
        config: ToolbarConfig(
          showSubtitleButton: showSubtitleButton,
          showAudioButton: showAudioButton,
          showQualityButton: showQualityButton,
          showSpeedButton: showSpeedButton,
          showScalingModeButton: showScalingModeButton,
          showBackgroundPlaybackButton: showBackgroundPlaybackButton,
          showPipButton: showPipButton && controller.options.allowPip,
          showOrientationLockButton: showOrientationLockButton,
          showFullscreenButton: showFullscreenButton,
          fullscreenOnly: controller.options.fullscreenOnly,
        ),
        state: ToolbarState(
          hasPlaylist: value.playlist != null,
          hasSubtitleTracks: value.subtitleTracks.isNotEmpty,
          audioTrackCount: value.audioTracks.length,
          qualityTrackCount: value.qualityTracks.length,
          hasChapters: value.hasChapters,
          isCasting: value.isCasting,
          isBackgroundPlaybackSupported:
              (controlsState as dynamic).isBackgroundPlaybackSupported as bool,
          isPipAvailable: (controlsState as dynamic).isPipAvailable as bool,
          isCastingSupported:
              (controlsState as dynamic).isCastingSupported as bool,
          isFullscreen: value.isFullscreen,
          isDesktopPlatform: isDesktopPlatform,
        ),
      );

  /// Builds the widget for a specific action.
  Widget _buildActionWidget(
    PlayerToolbarAction action,
    VideoPlayerValue value,
    VideoPlayerTheme theme,
    BuildContext context,
  ) {
    switch (action) {
      case PlayerToolbarAction.shuffle:
        return ShuffleButton(
          theme: theme,
          isShuffled: value.isShuffled,
          onPressed: () =>
              controller.setPlaylistShuffle(enabled: !value.isShuffled),
        );
      case PlayerToolbarAction.repeatMode:
        return RepeatModeButton(
          theme: theme,
          repeatMode: value.playlistRepeatMode,
          onPressed: () {
            final nextMode = switch (value.playlistRepeatMode) {
              PlaylistRepeatMode.none => PlaylistRepeatMode.all,
              PlaylistRepeatMode.all => PlaylistRepeatMode.one,
              PlaylistRepeatMode.one => PlaylistRepeatMode.none,
            };
            controller.setPlaylistRepeatMode(nextMode);
          },
        );
      case PlayerToolbarAction.subtitles:
        final hasSelectedSubtitle = value.selectedSubtitleTrack != null;
        return SubtitleButton(
          theme: theme,
          hasSelectedSubtitle: hasSelectedSubtitle,
          onPressed: () => onShowSubtitlePicker(context, theme),
        );
      case PlayerToolbarAction.audio:
        return AudioButton(
          theme: theme,
          onPressed: () => onShowAudioPicker(context, theme),
        );
      case PlayerToolbarAction.chapters:
        final currentChapter = value.currentChapter;
        return ChaptersButton(
          theme: theme,
          currentChapterTitle: currentChapter?.title,
          onPressed: () => onShowChaptersPicker(context, theme),
        );
      case PlayerToolbarAction.quality:
        final selectedQuality = value.selectedQualityTrack;
        final label =
            (selectedQuality?.isAuto ?? true) || selectedQuality == null
            ? 'Auto'
            : selectedQuality.displayLabel
                  .split(' ')
                  .first; // e.g., "1080p" from "1080p (5.0 Mbps)"
        return QualityButton(
          theme: theme,
          qualityLabel: label,
          onPressed: () => onShowQualityPicker(context, theme),
        );
      case PlayerToolbarAction.speed:
        return SpeedButton(
          theme: theme,
          speed: value.playbackSpeed,
          onPressed: () => onShowSpeedPicker(context, theme),
        );
      case PlayerToolbarAction.scalingMode:
        return ScalingModeButton(
          theme: theme,
          onPressed: () => onShowScalingModePicker(theme),
        );
      case PlayerToolbarAction.backgroundPlayback:
        final isEnabled = value.isBackgroundPlaybackEnabled;
        return BackgroundPlaybackButton(
          theme: theme,
          isEnabled: isEnabled,
          onPressed: () =>
              unawaited(controller.setBackgroundPlayback(enabled: !isEnabled)),
        );
      case PlayerToolbarAction.pip:
        return PipButton(
          theme: theme,
          onPressed: () => unawaited(controller.enterPip()),
        );
      case PlayerToolbarAction.casting:
        return CastingButton(theme: theme, isCasting: value.isCasting);
      case PlayerToolbarAction.orientationLock:
        return OrientationLockButton(
          theme: theme,
          lockedOrientation: value.lockedOrientation,
          onPressed: () => onShowOrientationLockPicker(theme),
        );
      case PlayerToolbarAction.fullscreen:
        final isFullscreen = value.isFullscreen;
        return FullscreenButton(
          theme: theme,
          isFullscreen: isFullscreen,
          onEnter: onFullscreenEnter,
          onExit: onFullscreenExit,
        );
    }
  }

  /// Builds the overflow menu button with hidden actions.
  Widget _buildOverflowMenu(
    List<PlayerToolbarAction> actions,
    VideoPlayerValue value,
    VideoPlayerTheme theme,
    BuildContext context,
  ) => PopupMenuButton<PlayerToolbarAction>(
    icon: Icon(Icons.more_vert, color: theme.primaryColor, size: 20),
    color: theme.backgroundColor,
    onSelected: (action) =>
        _handleOverflowAction(action, value, theme, context),
    itemBuilder: (ctx) => actions
        .map(
          (action) => PopupMenuItem<PlayerToolbarAction>(
            value: action,
            child: Row(
              children: [
                Icon(
                  _getActionIcon(action, value),
                  color: theme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  _getActionLabel(action),
                  style: TextStyle(color: theme.primaryColor),
                ),
              ],
            ),
          ),
        )
        .toList(),
  );

  /// Handles an action selected from the overflow menu.
  void _handleOverflowAction(
    PlayerToolbarAction action,
    VideoPlayerValue value,
    VideoPlayerTheme theme,
    BuildContext context,
  ) {
    switch (action) {
      case PlayerToolbarAction.shuffle:
        controller.setPlaylistShuffle(enabled: !value.isShuffled);
      case PlayerToolbarAction.repeatMode:
        final nextMode = switch (value.playlistRepeatMode) {
          PlaylistRepeatMode.none => PlaylistRepeatMode.all,
          PlaylistRepeatMode.all => PlaylistRepeatMode.one,
          PlaylistRepeatMode.one => PlaylistRepeatMode.none,
        };
        controller.setPlaylistRepeatMode(nextMode);
      case PlayerToolbarAction.subtitles:
        onShowSubtitlePicker(context, theme);
      case PlayerToolbarAction.audio:
        onShowAudioPicker(context, theme);
      case PlayerToolbarAction.chapters:
        onShowChaptersPicker(context, theme);
      case PlayerToolbarAction.quality:
        onShowQualityPicker(context, theme);
      case PlayerToolbarAction.speed:
        onShowSpeedPicker(context, theme);
      case PlayerToolbarAction.scalingMode:
        onShowScalingModePicker(theme);
      case PlayerToolbarAction.backgroundPlayback:
        unawaited(
          controller.setBackgroundPlayback(
            enabled: !value.isBackgroundPlaybackEnabled,
          ),
        );
      case PlayerToolbarAction.pip:
        unawaited(controller.enterPip());
      case PlayerToolbarAction.casting:
        if (value.isCasting) {
          unawaited(controller.stopCasting());
        } else {
          unawaited(controller.startCasting());
        }
      case PlayerToolbarAction.orientationLock:
        onShowOrientationLockPicker(theme);
      case PlayerToolbarAction.fullscreen:
        if (value.isFullscreen) {
          onFullscreenExit();
        } else {
          onFullscreenEnter();
        }
    }
  }

  /// Returns the label for an action (used in overflow menu).
  String _getActionLabel(PlayerToolbarAction action) =>
      VideoToolbarManager.getActionLabel(action);

  /// Returns the icon for an action (used in overflow menu).
  IconData _getActionIcon(PlayerToolbarAction action, VideoPlayerValue value) =>
      VideoToolbarManager.getActionIcon(
        action,
        isShuffled: value.isShuffled,
        playlistRepeatMode: value.playlistRepeatMode,
        hasSelectedSubtitle: value.selectedSubtitleTrack != null,
        isBackgroundPlaybackEnabled: value.isBackgroundPlaybackEnabled,
        isCasting: value.isCasting,
        isOrientationLocked: value.isOrientationLocked,
        isFullscreen: value.isFullscreen,
      );
}
