import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player/pro_video_player.dart';
import 'package:pro_video_player/src/controls/context_menu_builder.dart';

import '../../shared/test_constants.dart';
import '../../shared/test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VideoPlayerTestFixture fixture;

  setUpAll(registerVideoPlayerFallbackValues);

  setUp(() {
    fixture = VideoPlayerTestFixture()..setUp();
  });

  tearDown(() async {
    await fixture.tearDown();
  });

  /// Helper to extract menu item values from PopupMenuEntry list.
  List<String> getMenuItemValues(List<PopupMenuEntry<String>> items) {
    final values = <String>[];
    for (final item in items) {
      if (item is PopupMenuItem<String>) {
        if (item.value != null) {
          values.add(item.value!);
        }
      }
    }
    return values;
  }

  /// Helper to extract menu item text labels from PopupMenuEntry list.
  List<String> getMenuItemLabels(List<PopupMenuEntry<String>> items) {
    final labels = <String>[];
    for (final item in items) {
      if (item is PopupMenuItem<String>) {
        final row = item.child;
        if (row is Row) {
          for (final child in row.children) {
            if (child is Text) {
              labels.add(child.data ?? '');
            }
          }
        }
      }
    }
    return labels;
  }

  group('ContextMenuBuilder - Desktop Menu Parity', () {
    // This test ensures all toolbar options are available in the context menu
    // when minimalToolbarOnDesktop is true. This is critical because on desktop
    // the toolbar is hidden by design and users access all features via right-click.
    test('includes all toolbar options when in minimal mode', () async {
      final controller = ProVideoPlayerController();
      await controller.initialize(source: const VideoSource.network(TestMedia.networkUrl));

      // Set up video state with all features available
      controller.value = controller.value.copyWith(
        subtitleTracks: [const SubtitleTrack(id: '1', label: 'English')],
        audioTracks: [
          const AudioTrack(id: '0', label: 'Default'),
          const AudioTrack(id: '1', label: 'Commentary'),
        ],
        qualityTracks: [
          const VideoQualityTrack(id: '0', width: 1920, height: 1080, bitrate: 5000000),
          const VideoQualityTrack(id: '1', width: 1280, height: 720, bitrate: 2500000),
        ],
        chapters: [const Chapter(id: '1', title: 'Chapter 1', startTime: Duration.zero)],
        playlist: Playlist(items: [const VideoSource.network(TestMedia.networkUrl)]),
      );

      // Create context menu builder with all features enabled
      final builder = ContextMenuBuilder(
        videoController: controller,
        buttonsConfig: const ButtonsConfig(),
        isMinimalMode: true, // Desktop minimal mode - all options should be in context menu
        isPipAvailable: true,
        isBackgroundPlaybackSupported: true,
        onShowSubtitlePicker: ({required context, required theme}) {},
        onShowAudioPicker: ({required context, required theme}) {},
        onShowQualityPicker: ({required context, required theme}) {},
        onShowChaptersPicker: ({required context, required theme}) {},
        onShowSpeedPicker: ({required context, required theme}) {},
        onShowScalingModePicker: ({required context, required theme}) {},
        onResetHideTimer: () {},
      );

      // Build menu items directly
      final items = builder.buildMenuItems(controller.value, VideoPlayerTheme.light());
      final values = getMenuItemValues(items);

      // Expected menu item values that MUST be present when all features are available
      // and isMinimalMode is true (desktop mode).
      // Note: Play/Pause and Mute are intentionally excluded from the context menu
      // because they are accessible via keyboard shortcuts and click gestures.
      final expectedValues = [
        'subtitles',
        'audio',
        'quality',
        'chapters',
        'speed',
        'scaling_mode',
        'background_playback',
        'pip',
        'fullscreen',
        'playlist_previous',
        'playlist_next',
        'shuffle',
        'repeat',
        'keyboard_shortcuts',
      ];

      for (final expected in expectedValues) {
        expect(
          values.contains(expected),
          isTrue,
          reason:
              'Context menu should include "$expected" for desktop toolbar parity. '
              'Found values: $values',
        );
      }
    });

    test('speed option shows current playback speed', () async {
      final controller = ProVideoPlayerController();
      await controller.initialize(source: const VideoSource.network(TestMedia.networkUrl));
      controller.value = controller.value.copyWith(playbackSpeed: 1.5);

      final builder = ContextMenuBuilder(
        videoController: controller,
        buttonsConfig: const ButtonsConfig(),
        isMinimalMode: true,
        isPipAvailable: false,
        isBackgroundPlaybackSupported: false,
        onShowSubtitlePicker: ({required context, required theme}) {},
        onShowAudioPicker: ({required context, required theme}) {},
        onShowQualityPicker: ({required context, required theme}) {},
        onShowChaptersPicker: ({required context, required theme}) {},
        onShowSpeedPicker: ({required context, required theme}) {},
        onShowScalingModePicker: ({required context, required theme}) {},
        onResetHideTimer: () {},
      );

      final items = builder.buildMenuItems(controller.value, VideoPlayerTheme.light());
      final labels = getMenuItemLabels(items);

      expect(labels.contains('Speed (1.5x)'), isTrue, reason: 'Should show current speed. Labels: $labels');
    });

    test('scaling mode option is present in minimal mode', () async {
      final controller = ProVideoPlayerController();
      await controller.initialize(source: const VideoSource.network(TestMedia.networkUrl));

      final builder = ContextMenuBuilder(
        videoController: controller,
        buttonsConfig: const ButtonsConfig(),
        isMinimalMode: true,
        isPipAvailable: false,
        isBackgroundPlaybackSupported: false,
        onShowSubtitlePicker: ({required context, required theme}) {},
        onShowAudioPicker: ({required context, required theme}) {},
        onShowQualityPicker: ({required context, required theme}) {},
        onShowChaptersPicker: ({required context, required theme}) {},
        onShowSpeedPicker: ({required context, required theme}) {},
        onShowScalingModePicker: ({required context, required theme}) {},
        onResetHideTimer: () {},
      );

      final items = builder.buildMenuItems(controller.value, VideoPlayerTheme.light());
      final values = getMenuItemValues(items);

      expect(values.contains('scaling_mode'), isTrue, reason: 'Should include scaling mode. Values: $values');
    });

    test('background playback shows enabled state', () async {
      final controller = ProVideoPlayerController();
      await controller.initialize(source: const VideoSource.network(TestMedia.networkUrl));
      controller.value = controller.value.copyWith(isBackgroundPlaybackEnabled: true);

      final builder = ContextMenuBuilder(
        videoController: controller,
        buttonsConfig: const ButtonsConfig(),
        isMinimalMode: true,
        isPipAvailable: false,
        isBackgroundPlaybackSupported: true,
        onShowSubtitlePicker: ({required context, required theme}) {},
        onShowAudioPicker: ({required context, required theme}) {},
        onShowQualityPicker: ({required context, required theme}) {},
        onShowChaptersPicker: ({required context, required theme}) {},
        onShowSpeedPicker: ({required context, required theme}) {},
        onShowScalingModePicker: ({required context, required theme}) {},
        onResetHideTimer: () {},
      );

      final items = builder.buildMenuItems(controller.value, VideoPlayerTheme.light());
      final labels = getMenuItemLabels(items);

      expect(labels.contains('Background Playback (On)'), isTrue, reason: 'Should show enabled state. Labels: $labels');
    });

    test('does not show background playback when not supported', () async {
      final controller = ProVideoPlayerController();
      await controller.initialize(source: const VideoSource.network(TestMedia.networkUrl));

      final builder = ContextMenuBuilder(
        videoController: controller,
        buttonsConfig: const ButtonsConfig(),
        isMinimalMode: true,
        isPipAvailable: false,
        isBackgroundPlaybackSupported: false, // Not supported
        onShowSubtitlePicker: ({required context, required theme}) {},
        onShowAudioPicker: ({required context, required theme}) {},
        onShowQualityPicker: ({required context, required theme}) {},
        onShowChaptersPicker: ({required context, required theme}) {},
        onShowSpeedPicker: ({required context, required theme}) {},
        onShowScalingModePicker: ({required context, required theme}) {},
        onResetHideTimer: () {},
      );

      final items = builder.buildMenuItems(controller.value, VideoPlayerTheme.light());
      final values = getMenuItemValues(items);

      expect(values.contains('background_playback'), isFalse, reason: 'Should not include background playback');
    });

    test('does not show track options when not in minimal mode', () async {
      final controller = ProVideoPlayerController();
      await controller.initialize(source: const VideoSource.network(TestMedia.networkUrl));
      controller.value = controller.value.copyWith(
        subtitleTracks: [const SubtitleTrack(id: '1', label: 'English')],
        audioTracks: [
          const AudioTrack(id: '0', label: 'Default'),
          const AudioTrack(id: '1', label: 'Commentary'),
        ],
      );

      final builder = ContextMenuBuilder(
        videoController: controller,
        buttonsConfig: const ButtonsConfig(),
        isMinimalMode: false, // Not minimal mode - tracks should NOT be in context menu
        isPipAvailable: true,
        isBackgroundPlaybackSupported: true,
        onShowSubtitlePicker: ({required context, required theme}) {},
        onShowAudioPicker: ({required context, required theme}) {},
        onShowQualityPicker: ({required context, required theme}) {},
        onShowChaptersPicker: ({required context, required theme}) {},
        onShowSpeedPicker: ({required context, required theme}) {},
        onShowScalingModePicker: ({required context, required theme}) {},
        onResetHideTimer: () {},
      );

      final items = builder.buildMenuItems(controller.value, VideoPlayerTheme.light());
      final values = getMenuItemValues(items);

      // These should NOT appear when not in minimal mode
      expect(values.contains('subtitles'), isFalse, reason: 'Subtitles should not be in non-minimal mode');
      expect(values.contains('audio'), isFalse, reason: 'Audio should not be in non-minimal mode');
      expect(values.contains('background_playback'), isFalse, reason: 'BG playback should not be in non-minimal mode');
      expect(values.contains('scaling_mode'), isFalse, reason: 'Scaling mode should not be in non-minimal mode');

      // Speed and keyboard shortcuts should still appear
      expect(values.contains('speed'), isTrue, reason: 'Speed should always appear');
      expect(values.contains('keyboard_shortcuts'), isTrue, reason: 'Keyboard shortcuts should always appear');
    });

    test('does not include play/pause or mute options', () async {
      final controller = ProVideoPlayerController();
      await controller.initialize(source: const VideoSource.network(TestMedia.networkUrl));

      final builder = ContextMenuBuilder(
        videoController: controller,
        buttonsConfig: const ButtonsConfig(),
        isMinimalMode: true,
        isPipAvailable: false,
        isBackgroundPlaybackSupported: false,
        onShowSubtitlePicker: ({required context, required theme}) {},
        onShowAudioPicker: ({required context, required theme}) {},
        onShowQualityPicker: ({required context, required theme}) {},
        onShowChaptersPicker: ({required context, required theme}) {},
        onShowSpeedPicker: ({required context, required theme}) {},
        onShowScalingModePicker: ({required context, required theme}) {},
        onResetHideTimer: () {},
      );

      final items = builder.buildMenuItems(controller.value, VideoPlayerTheme.light());
      final values = getMenuItemValues(items);

      // Play/pause and mute should NOT be in context menu (available via gestures/keyboard)
      expect(values.contains('play_pause'), isFalse, reason: 'Play/pause accessible via tap/keyboard');
      expect(values.contains('mute'), isFalse, reason: 'Mute accessible via volume control');
    });
  });
}
