import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

import '../pro_video_player_controller.dart';
import '../video_controls_config.dart';
import '../video_player_theme.dart';
import 'dialogs/keyboard_shortcuts_dialog.dart';
import 'video_controls_utils.dart';

/// Callback for showing a dialog picker.
typedef ShowDialogCallback = void Function({required BuildContext context, required VideoPlayerTheme theme});

/// Callback for fullscreen enter/exit actions.
typedef FullscreenCallback = void Function();

/// Builds and handles the video player context menu.
///
/// This class encapsulates context menu construction and action handling,
/// making it easier to test and maintain separately from UI state management.
///
/// On desktop platforms, the toolbar is minimal by design and users access
/// all features via the right-click context menu. This builder ensures all
/// toolbar options are available in the context menu when [isMinimalMode] is true.
class ContextMenuBuilder {
  /// Creates a context menu builder.
  ContextMenuBuilder({
    required ProVideoPlayerController videoController,
    required ButtonsConfig buttonsConfig,
    required bool isMinimalMode,
    required bool? isPipAvailable,
    required bool? isBackgroundPlaybackSupported,
    required ShowDialogCallback onShowSubtitlePicker,
    required ShowDialogCallback onShowAudioPicker,
    required ShowDialogCallback onShowQualityPicker,
    required ShowDialogCallback onShowChaptersPicker,
    required ShowDialogCallback onShowSpeedPicker,
    required ShowDialogCallback onShowScalingModePicker,
    required VoidCallback onResetHideTimer,
  }) : _videoController = videoController,
       _buttonsConfig = buttonsConfig,
       _isMinimalMode = isMinimalMode,
       _isPipAvailable = isPipAvailable,
       _isBackgroundPlaybackSupported = isBackgroundPlaybackSupported,
       _onShowSubtitlePicker = onShowSubtitlePicker,
       _onShowAudioPicker = onShowAudioPicker,
       _onShowQualityPicker = onShowQualityPicker,
       _onShowChaptersPicker = onShowChaptersPicker,
       _onShowSpeedPicker = onShowSpeedPicker,
       _onShowScalingModePicker = onShowScalingModePicker,
       _onResetHideTimer = onResetHideTimer;

  final ProVideoPlayerController _videoController;
  final ButtonsConfig _buttonsConfig;
  final bool _isMinimalMode;
  final bool? _isPipAvailable;
  final bool? _isBackgroundPlaybackSupported;
  final ShowDialogCallback _onShowSubtitlePicker;
  final ShowDialogCallback _onShowAudioPicker;
  final ShowDialogCallback _onShowQualityPicker;
  final ShowDialogCallback _onShowChaptersPicker;
  final ShowDialogCallback _onShowSpeedPicker;
  final ShowDialogCallback _onShowScalingModePicker;
  final VoidCallback _onResetHideTimer;

  /// Shows context menu at the given position.
  Future<void> show({
    required BuildContext context,
    required Offset position,
    required VideoPlayerTheme theme,
    required FullscreenCallback onEnterFullscreen,
    required FullscreenCallback onExitFullscreen,
  }) async {
    final value = _videoController.value;
    final items = buildMenuItems(value, theme);

    final selectedValue = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: items,
    );

    if (selectedValue == null || !context.mounted) return;

    _handleSelection(
      selectedValue,
      context: context,
      theme: theme,
      value: value,
      onEnterFullscreen: onEnterFullscreen,
      onExitFullscreen: onExitFullscreen,
    );
    _onResetHideTimer();
  }

  /// Builds the menu items for the context menu.
  ///
  /// This is exposed for testing purposes.
  @visibleForTesting
  List<PopupMenuEntry<String>> buildMenuItems(VideoPlayerValue value, VideoPlayerTheme theme) {
    final currentSpeed = value.playbackSpeed;
    final hasSubtitles = value.subtitleTracks.isNotEmpty;
    final hasAudioTracks = value.audioTracks.length > 1;
    final hasQualityTracks = value.qualityTracks.length > 1;
    final hasChapters = value.chapters.isNotEmpty;
    final hasPlaylist = value.playlist != null;

    return [
      // Track selection options (when in minimal mode and tracks available)
      if (_isMinimalMode && (hasSubtitles || hasAudioTracks || hasQualityTracks || hasChapters)) ...[
        if (hasSubtitles && _buttonsConfig.showSubtitleButton) _buildSubtitlesItem(value),
        if (hasAudioTracks && _buttonsConfig.showAudioButton) _buildAudioTrackItem(),
        if (hasQualityTracks && _buttonsConfig.showQualityButton) _buildQualityItem(),
        if (hasChapters) _buildChaptersItem(),
        const PopupMenuDivider(),
      ],

      // Speed option
      _buildSpeedItem(currentSpeed),

      // Scaling mode (when in minimal mode)
      if (_isMinimalMode && _buttonsConfig.showScalingModeButton) _buildScalingModeItem(),

      // Background playback (when in minimal mode and supported)
      if (_isMinimalMode && (_isBackgroundPlaybackSupported ?? false) && _buttonsConfig.showBackgroundPlaybackButton)
        _buildBackgroundPlaybackItem(value),

      // PiP and Fullscreen
      if (_isMinimalMode && (_isPipAvailable ?? false) && _buttonsConfig.showPipButton ||
          _buttonsConfig.showFullscreenButton) ...[
        const PopupMenuDivider(),
        if (_isMinimalMode && (_isPipAvailable ?? false) && _buttonsConfig.showPipButton) _buildPipItem(value),
        if (_buttonsConfig.showFullscreenButton) _buildFullscreenItem(value),
      ],

      // Playlist controls (when in minimal mode and playlist exists)
      if (_isMinimalMode && hasPlaylist) ...[
        const PopupMenuDivider(),
        _buildPlaylistPreviousItem(),
        _buildPlaylistNextItem(),
        _buildShuffleItem(value, theme),
        _buildRepeatItem(value, theme),
      ],

      // Keyboard shortcuts help
      const PopupMenuDivider(),
      _buildKeyboardShortcutsItem(),
    ];
  }

  PopupMenuItem<String> _buildSubtitlesItem(VideoPlayerValue value) => PopupMenuItem<String>(
    value: 'subtitles',
    child: Row(
      children: [
        const Icon(Icons.closed_caption, size: 20),
        const SizedBox(width: 12),
        Text('Subtitles${value.selectedSubtitleTrack != null ? ' (On)' : ''}'),
        const Spacer(),
        const Icon(Icons.chevron_right, size: 16),
      ],
    ),
  );

  PopupMenuItem<String> _buildAudioTrackItem() => const PopupMenuItem<String>(
    value: 'audio',
    child: Row(
      children: [
        Icon(Icons.audiotrack, size: 20),
        SizedBox(width: 12),
        Text('Audio Track'),
        Spacer(),
        Icon(Icons.chevron_right, size: 16),
      ],
    ),
  );

  PopupMenuItem<String> _buildQualityItem() => const PopupMenuItem<String>(
    value: 'quality',
    child: Row(
      children: [
        Icon(Icons.high_quality, size: 20),
        SizedBox(width: 12),
        Text('Quality'),
        Spacer(),
        Icon(Icons.chevron_right, size: 16),
      ],
    ),
  );

  PopupMenuItem<String> _buildChaptersItem() => const PopupMenuItem<String>(
    value: 'chapters',
    child: Row(
      children: [
        Icon(Icons.list, size: 20),
        SizedBox(width: 12),
        Text('Chapters'),
        Spacer(),
        Icon(Icons.chevron_right, size: 16),
      ],
    ),
  );

  PopupMenuItem<String> _buildSpeedItem(double currentSpeed) => PopupMenuItem<String>(
    value: 'speed',
    child: Row(
      children: [
        const Icon(Icons.speed, size: 20),
        const SizedBox(width: 12),
        Text('Speed (${currentSpeed}x)'),
        const Spacer(),
        const Icon(Icons.chevron_right, size: 16),
      ],
    ),
  );

  PopupMenuItem<String> _buildScalingModeItem() => const PopupMenuItem<String>(
    value: 'scaling_mode',
    child: Row(
      children: [
        Icon(Icons.aspect_ratio, size: 20),
        SizedBox(width: 12),
        Text('Scaling Mode'),
        Spacer(),
        Icon(Icons.chevron_right, size: 16),
      ],
    ),
  );

  PopupMenuItem<String> _buildBackgroundPlaybackItem(VideoPlayerValue value) => PopupMenuItem<String>(
    value: 'background_playback',
    child: Row(
      children: [
        Icon(value.isBackgroundPlaybackEnabled ? Icons.headphones : Icons.headphones_outlined, size: 20),
        const SizedBox(width: 12),
        Text('Background Playback${value.isBackgroundPlaybackEnabled ? ' (On)' : ''}'),
      ],
    ),
  );

  PopupMenuItem<String> _buildPipItem(VideoPlayerValue value) => PopupMenuItem<String>(
    value: 'pip',
    child: Row(
      children: [
        Icon(value.isPipActive ? Icons.picture_in_picture_alt : Icons.picture_in_picture, size: 20),
        const SizedBox(width: 12),
        Text(value.isPipActive ? 'Exit Picture-in-Picture' : 'Picture-in-Picture'),
      ],
    ),
  );

  PopupMenuItem<String> _buildFullscreenItem(VideoPlayerValue value) => PopupMenuItem<String>(
    value: 'fullscreen',
    child: Row(
      children: [
        Icon(value.isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen, size: 20),
        const SizedBox(width: 12),
        Text(value.isFullscreen ? 'Exit Fullscreen' : 'Fullscreen'),
      ],
    ),
  );

  PopupMenuItem<String> _buildPlaylistPreviousItem() => const PopupMenuItem<String>(
    value: 'playlist_previous',
    child: Row(children: [Icon(Icons.skip_previous, size: 20), SizedBox(width: 12), Text('Previous')]),
  );

  PopupMenuItem<String> _buildPlaylistNextItem() => const PopupMenuItem<String>(
    value: 'playlist_next',
    child: Row(children: [Icon(Icons.skip_next, size: 20), SizedBox(width: 12), Text('Next')]),
  );

  PopupMenuItem<String> _buildShuffleItem(VideoPlayerValue value, VideoPlayerTheme theme) => PopupMenuItem<String>(
    value: 'shuffle',
    child: Row(
      children: [
        Icon(Icons.shuffle, size: 20, color: value.isShuffled ? theme.primaryColor : null),
        const SizedBox(width: 12),
        Text('Shuffle${value.isShuffled ? ' (On)' : ''}'),
      ],
    ),
  );

  PopupMenuItem<String> _buildRepeatItem(VideoPlayerValue value, VideoPlayerTheme theme) => PopupMenuItem<String>(
    value: 'repeat',
    child: Row(
      children: [
        Icon(
          value.playlistRepeatMode == PlaylistRepeatMode.one ? Icons.repeat_one : Icons.repeat,
          size: 20,
          color: value.playlistRepeatMode != PlaylistRepeatMode.none ? theme.primaryColor : null,
        ),
        const SizedBox(width: 12),
        Text('Repeat${VideoControlsUtils.getRepeatModeLabel(value.playlistRepeatMode)}'),
      ],
    ),
  );

  PopupMenuItem<String> _buildKeyboardShortcutsItem() => const PopupMenuItem<String>(
    value: 'keyboard_shortcuts',
    child: Row(children: [Icon(Icons.help_outline, size: 20), SizedBox(width: 12), Text('Keyboard Shortcuts')]),
  );

  void _handleSelection(
    String selectedValue, {
    required BuildContext context,
    required VideoPlayerTheme theme,
    required VideoPlayerValue value,
    required FullscreenCallback onEnterFullscreen,
    required FullscreenCallback onExitFullscreen,
  }) {
    switch (selectedValue) {
      case 'subtitles':
        if (context.mounted) _onShowSubtitlePicker(context: context, theme: theme);
      case 'audio':
        if (context.mounted) _onShowAudioPicker(context: context, theme: theme);
      case 'quality':
        if (context.mounted) _onShowQualityPicker(context: context, theme: theme);
      case 'chapters':
        if (context.mounted) _onShowChaptersPicker(context: context, theme: theme);
      case 'speed':
        if (context.mounted) _onShowSpeedPicker(context: context, theme: theme);
      case 'scaling_mode':
        if (context.mounted) _onShowScalingModePicker(context: context, theme: theme);
      case 'background_playback':
        unawaited(_videoController.setBackgroundPlayback(enabled: !value.isBackgroundPlaybackEnabled));
      case 'pip':
        if (value.isPipActive) {
          unawaited(_videoController.exitPip());
        } else {
          unawaited(_videoController.enterPip());
        }
      case 'fullscreen':
        if (value.isFullscreen) {
          onExitFullscreen();
        } else {
          onEnterFullscreen();
        }
      case 'playlist_previous':
        unawaited(_videoController.playlistPrevious());
      case 'playlist_next':
        unawaited(_videoController.playlistNext());
      case 'shuffle':
        _videoController.setPlaylistShuffle(enabled: !value.isShuffled);
      case 'repeat':
        final nextMode = VideoControlsUtils.getNextRepeatMode(value.playlistRepeatMode);
        _videoController.setPlaylistRepeatMode(nextMode);
      case 'keyboard_shortcuts':
        if (context.mounted) {
          KeyboardShortcutsDialog.show(context: context, theme: theme);
        }
    }
  }
}
