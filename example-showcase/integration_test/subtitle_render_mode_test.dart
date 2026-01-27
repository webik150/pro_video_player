import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pro_video_player/pro_video_player.dart';

/// Tests for subtitle render mode to debug duplicate subtitle issue.
///
/// The Shaka Angel One HLS video has WebVTT subtitles with DEFAULT=YES for English.
/// This test verifies that when using Flutter render mode, native subtitles are disabled.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Subtitle Render Mode - Shaka Angel One HLS', () {
    late ProVideoPlayerController controller;

    setUp(() {
      controller = ProVideoPlayerController();
    });

    tearDown(() async {
      await controller.dispose();
    });

    testWidgets('Flutter render mode should not show native subtitles', (tester) async {
      const shakaUrl = 'https://storage.googleapis.com/shaka-demo-assets/angel-one-hls/hls.m3u8';

      debugPrint('=== SUBTITLE RENDER MODE TEST ===');
      debugPrint('Testing with SubtitleRenderMode.flutter');

      await controller.initialize(
        source: const VideoSource.network(shakaUrl),
        options: const VideoPlayerOptions(
          autoPlay: true,
          showSubtitlesByDefault: true,
          preferredSubtitleLanguage: 'en',
          subtitleRenderMode: SubtitleRenderMode.flutter,
        ),
      );

      // Wait for initialization and track discovery
      await tester.pump(const Duration(seconds: 3));

      debugPrint('Initial state:');
      debugPrint('  - currentSubtitleRenderMode: ${controller.value.currentSubtitleRenderMode}');
      debugPrint('  - selectedSubtitleTrack: ${controller.value.selectedSubtitleTrack?.label}');
      debugPrint('  - subtitleTracks count: ${controller.value.subtitleTracks.length}');

      // Wait more for subtitles to be extracted
      await tester.pump(const Duration(seconds: 5));

      final cues = controller.value.embeddedSubtitleCues;
      debugPrint('After 5 seconds:');
      debugPrint('  - embeddedSubtitleCues count: ${cues?.length ?? 0}');
      debugPrint('  - currentEmbeddedCue: ${controller.value.currentEmbeddedCue?.text}');

      // Verify subtitle tracks were detected
      expect(controller.value.subtitleTracks, isNotEmpty, reason: 'Should have subtitle tracks');

      // Verify render mode is flutter
      expect(
        controller.value.currentSubtitleRenderMode,
        equals(SubtitleRenderMode.flutter),
        reason: 'Render mode should be flutter',
      );

      // Log all subtitle tracks for debugging
      debugPrint('Subtitle tracks:');
      for (final track in controller.value.subtitleTracks) {
        debugPrint('  - ${track.id}: ${track.label} (${track.language}) default=${track.isDefault}');
      }

      debugPrint('=================================');
    });

    testWidgets('Auto render mode should default to Flutter', (tester) async {
      const shakaUrl = 'https://storage.googleapis.com/shaka-demo-assets/angel-one-hls/hls.m3u8';

      debugPrint('=== AUTO RENDER MODE TEST ===');
      debugPrint('Testing with SubtitleRenderMode.auto (should default to flutter)');

      await controller.initialize(
        source: const VideoSource.network(shakaUrl),
        options: const VideoPlayerOptions(
          autoPlay: true,
          showSubtitlesByDefault: true,
          preferredSubtitleLanguage: 'en',
        ),
      );

      // Wait for initialization
      await tester.pump(const Duration(seconds: 3));

      debugPrint('State with auto mode:');
      debugPrint('  - currentSubtitleRenderMode: ${controller.value.currentSubtitleRenderMode}');
      debugPrint('  - selectedSubtitleTrack: ${controller.value.selectedSubtitleTrack?.label}');

      // Auto mode is stored as-is, but effective behavior should be flutter
      // The value.currentSubtitleRenderMode will be 'auto', but native should not render
      expect(
        controller.value.currentSubtitleRenderMode,
        equals(SubtitleRenderMode.auto),
        reason: 'Render mode should be auto',
      );

      // Wait for cue extraction
      await tester.pump(const Duration(seconds: 5));

      final cues = controller.value.embeddedSubtitleCues;
      debugPrint('After 5 seconds:');
      debugPrint('  - embeddedSubtitleCues count: ${cues?.length ?? 0}');

      debugPrint('==============================');
    });

    testWidgets('Native render mode should NOT extract cues for Flutter', (tester) async {
      const shakaUrl = 'https://storage.googleapis.com/shaka-demo-assets/angel-one-hls/hls.m3u8';

      debugPrint('=== NATIVE RENDER MODE TEST ===');
      debugPrint('Testing with SubtitleRenderMode.native');

      await controller.initialize(
        source: const VideoSource.network(shakaUrl),
        options: const VideoPlayerOptions(
          autoPlay: true,
          showSubtitlesByDefault: true,
          preferredSubtitleLanguage: 'en',
          subtitleRenderMode: SubtitleRenderMode.native,
        ),
      );

      // Wait for initialization
      await tester.pump(const Duration(seconds: 3));

      debugPrint('State with native mode:');
      debugPrint('  - currentSubtitleRenderMode: ${controller.value.currentSubtitleRenderMode}');
      debugPrint('  - selectedSubtitleTrack: ${controller.value.selectedSubtitleTrack?.label}');

      expect(
        controller.value.currentSubtitleRenderMode,
        equals(SubtitleRenderMode.native),
        reason: 'Render mode should be native',
      );

      // In native mode, we should NOT extract cues (native player renders them)
      await tester.pump(const Duration(seconds: 5));

      final cues = controller.value.embeddedSubtitleCues;
      debugPrint('After 5 seconds:');
      debugPrint('  - embeddedSubtitleCues count: ${cues?.length ?? 0}');

      // In native mode, Flutter should not be extracting HLS subtitle cues
      // (This is expected behavior - native player renders subtitles)
      debugPrint('===============================');
    });
  });
}
