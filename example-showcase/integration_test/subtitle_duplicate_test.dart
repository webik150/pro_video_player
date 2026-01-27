import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pro_video_player/pro_video_player.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

/// Tests to detect duplicate subtitle rendering.
///
/// Duplicate subtitles occur when BOTH:
/// 1. Native player (AVPlayer/ExoPlayer) renders subtitles
/// 2. Flutter's SubtitleOverlay also renders subtitles
///
/// In Flutter render mode, native rendering should be disabled.
/// This test verifies that subtitle cues are received by Flutter
/// and checks the state to ensure native rendering is disabled.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Subtitle Duplicate Detection - Shaka Angel One HLS', () {
    late ProVideoPlayerController controller;
    final receivedCues = <String>[];

    setUp(() {
      controller = ProVideoPlayerController();
      receivedCues.clear();
    });

    tearDown(() async {
      await controller.dispose();
    });

    testWidgets('Flutter mode: should receive cues without native rendering', (tester) async {
      const shakaUrl = 'https://storage.googleapis.com/shaka-demo-assets/angel-one-hls/hls.m3u8';

      debugPrint('');
      debugPrint('╔══════════════════════════════════════════════════════════════╗');
      debugPrint('║  SUBTITLE DUPLICATE DETECTION TEST                           ║');
      debugPrint('║  Video: Shaka Angel One HLS (has DEFAULT=YES English subs)   ║');
      debugPrint('║  Mode: SubtitleRenderMode.flutter                            ║');
      debugPrint('╚══════════════════════════════════════════════════════════════╝');
      debugPrint('');

      // Listen for value changes to capture embedded cues
      void listener() {
        final cue = controller.value.currentEmbeddedCue;
        if (cue != null && cue.text.isNotEmpty && !receivedCues.contains(cue.text)) {
          receivedCues.add(cue.text);
          final preview = cue.text.length > 50 ? '${cue.text.substring(0, 50)}...' : cue.text;
          debugPrint('📝 Received cue: "$preview"');
        }
      }

      controller.addListener(listener);

      await controller.initialize(
        source: const VideoSource.network(shakaUrl),
        options: const VideoPlayerOptions(
          autoPlay: true,
          showSubtitlesByDefault: true,
          preferredSubtitleLanguage: 'en',
          subtitleRenderMode: SubtitleRenderMode.flutter,
        ),
      );

      debugPrint('✓ Player initialized');

      // Wait for track discovery
      await tester.pump(const Duration(seconds: 3));

      final subtitleTracks = controller.value.subtitleTracks;
      final selectedTrack = controller.value.selectedSubtitleTrack;
      final renderMode = controller.value.currentSubtitleRenderMode;

      debugPrint('');
      debugPrint('═══ STATE AFTER INITIALIZATION ═══');
      debugPrint('Render mode: $renderMode');
      debugPrint('Subtitle tracks found: ${subtitleTracks.length}');
      debugPrint('Selected track: ${selectedTrack?.label ?? "none"} (${selectedTrack?.language ?? "?"})');

      // Verify tracks were discovered
      expect(subtitleTracks, isNotEmpty, reason: 'Should discover subtitle tracks from HLS manifest');

      // Verify render mode
      expect(renderMode, equals(SubtitleRenderMode.flutter), reason: 'Render mode should be flutter');

      // Seek to a position where subtitles should appear (Angel One has subs early)
      await controller.seekTo(const Duration(seconds: 30));
      debugPrint('Seeked to 30 seconds');

      // Wait for subtitle cues to be extracted and received
      debugPrint('Waiting for subtitle cues...');
      await tester.pump(const Duration(seconds: 8));

      // Also pump in smaller intervals to process events
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      debugPrint('');
      debugPrint('═══ SUBTITLE CUE ANALYSIS ═══');
      debugPrint('Total unique cues received: ${receivedCues.length}');

      final embeddedCues = controller.value.embeddedSubtitleCues;
      debugPrint('Embedded cues in value: ${embeddedCues?.length ?? 0}');

      if (receivedCues.isNotEmpty) {
        debugPrint('');
        debugPrint('First few cues received:');
        for (var i = 0; i < receivedCues.length.clamp(0, 5); i++) {
          final cue = receivedCues[i];
          final preview = cue.length > 60 ? '${cue.substring(0, 60)}...' : cue;
          debugPrint('  ${i + 1}. "$preview"');
        }
      }

      debugPrint('');
      debugPrint('═══ DUPLICATE CHECK ═══');

      // In Flutter render mode:
      // - Flutter SHOULD receive cues (for SubtitleOverlay to render)
      // - Native player SHOULD NOT render subtitles
      //
      // We can verify Flutter is receiving cues.
      // Native rendering can't be directly checked in Dart,
      // but if appliesMediaSelectionCriteriaAutomatically is false
      // and we deselect native tracks, native shouldn't render.

      final hasFlutterCues = receivedCues.isNotEmpty || (embeddedCues?.isNotEmpty ?? false);

      if (hasFlutterCues) {
        debugPrint('✓ Flutter IS receiving subtitle cues');
        debugPrint('  → SubtitleOverlay will render these');
      } else {
        debugPrint('✗ Flutter is NOT receiving subtitle cues');
        debugPrint('  → This could mean HLS extraction failed');
      }

      // Check if a track is selected (this is expected - we select for metadata)
      // but native rendering should be disabled via appliesMediaSelectionCriteriaAutomatically
      if (selectedTrack != null) {
        debugPrint('');
        debugPrint('ℹ️  A subtitle track IS selected: ${selectedTrack.label}');
        debugPrint('   This is expected - we select the track for Flutter to know which one to extract.');
        debugPrint('   Native rendering should be disabled via appliesMediaSelectionCriteriaAutomatically=false');
      }

      debugPrint('');
      debugPrint('═══ CONCLUSION ═══');
      if (hasFlutterCues && renderMode == SubtitleRenderMode.flutter) {
        debugPrint('✓ Flutter subtitle rendering is active');
        debugPrint('✓ If you see duplicates, native player is incorrectly rendering too');
        debugPrint('  → Check appliesMediaSelectionCriteriaAutomatically on iOS');
        debugPrint('  → Check subtitleView.visibility on Android');
      } else if (!hasFlutterCues) {
        debugPrint('✗ No Flutter cues received - HLS subtitle extraction may have failed');
      }

      debugPrint('');
      debugPrint('══════════════════════════════════════════════════════════════');

      controller.removeListener(listener);

      // The test passes if Flutter is receiving cues in flutter mode
      // Visual inspection is still needed to confirm no native duplicates
      expect(hasFlutterCues, isTrue, reason: 'Flutter should receive subtitle cues in flutter render mode');
    });

    testWidgets('Verify HLS subtitle extraction works', (tester) async {
      const shakaUrl = 'https://storage.googleapis.com/shaka-demo-assets/angel-one-hls/hls.m3u8';

      debugPrint('');
      debugPrint('╔══════════════════════════════════════════════════════════════╗');
      debugPrint('║  HLS SUBTITLE EXTRACTION TEST                                ║');
      debugPrint('╚══════════════════════════════════════════════════════════════╝');
      debugPrint('');

      // Use the HlsSubtitleExtractor directly to verify extraction works
      final extractor = HlsSubtitleExtractor();

      debugPrint('Fetching HLS manifest...');
      final tracks = await extractor.listTracks(Uri.parse(shakaUrl));

      debugPrint('Found ${tracks.length} subtitle tracks:');
      for (final track in tracks) {
        debugPrint('  - ${track.name} (${track.language}) ${track.isDefault ? "[DEFAULT]" : ""}');
      }

      expect(tracks, isNotEmpty, reason: 'Should find subtitle tracks in HLS manifest');

      // Find English track
      final englishTrack = tracks.firstWhere((t) => t.language == 'en', orElse: () => tracks.first);

      debugPrint('');
      debugPrint('Extracting cues from: ${englishTrack.name}...');

      final cues = await extractor.extractFromTrack(Uri.parse(shakaUrl), englishTrack);

      debugPrint('Extracted ${cues.length} cues');

      if (cues.isNotEmpty) {
        debugPrint('');
        debugPrint('Sample cues:');
        for (var i = 0; i < cues.length.clamp(0, 5); i++) {
          final cue = cues[i];
          final text = cue.text.length > 50 ? '${cue.text.substring(0, 50)}...' : cue.text;
          debugPrint('  [${cue.start.inSeconds}s - ${cue.end.inSeconds}s] "$text"');
        }
      }

      expect(cues, isNotEmpty, reason: 'Should extract subtitle cues from HLS');

      debugPrint('');
      debugPrint('✓ HLS subtitle extraction is working correctly');
      debugPrint('══════════════════════════════════════════════════════════════');
    });
  });
}
