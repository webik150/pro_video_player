import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pro_video_player/pro_video_player.dart';

/// Test that mimics exactly what the Stream Selection screen does.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Stream Selection Screen Track Detection', () {
    late ProVideoPlayerController controller;

    setUp(() {
      controller = ProVideoPlayerController();
    });

    tearDown(() async {
      await controller.dispose();
    });

    testWidgets('Shaka Angel One HLS shows audio and subtitle tracks', (tester) async {
      // This is EXACTLY how Stream Selection screen initializes
      const shakaUrl = 'https://storage.googleapis.com/shaka-demo-assets/angel-one-hls/hls.m3u8';

      await controller.initialize(
        source: const VideoSource.network(shakaUrl),
        options: const VideoPlayerOptions(
          autoPlay: true,
          showSubtitlesByDefault: true,
          preferredSubtitleLanguage: 'en',
        ),
      );

      // Wait for track discovery (same as Stream Selection would need)
      await tester.pump(const Duration(seconds: 5));

      // Check what tracks we have
      final audioTracks = controller.value.audioTracks;
      final subtitleTracks = controller.value.subtitleTracks;

      debugPrint('=== TRACK DETECTION RESULTS ===');
      debugPrint('Audio tracks: ${audioTracks.length}');
      for (final track in audioTracks) {
        debugPrint('  - ${track.id}: ${track.label} (${track.language})');
      }
      debugPrint('Subtitle tracks: ${subtitleTracks.length}');
      for (final track in subtitleTracks) {
        debugPrint('  - ${track.id}: ${track.label} (${track.language})');
      }
      debugPrint('================================');

      // Verify tracks are detected
      expect(audioTracks, isNotEmpty, reason: 'Shaka Angel One should have audio tracks');
      expect(subtitleTracks, isNotEmpty, reason: 'Shaka Angel One should have subtitle tracks');

      // Shaka Angel One has 6 audio tracks and 4 subtitle tracks
      expect(audioTracks.length, greaterThanOrEqualTo(1), reason: 'Expected at least 1 audio track');
      expect(subtitleTracks.length, greaterThanOrEqualTo(1), reason: 'Expected at least 1 subtitle track');
    });

    // Note: Sintel HLS removed because it doesn't have multiple audio/subtitle tracks.
    // The Shaka Angel One test above validates track detection works correctly.
  });
}
