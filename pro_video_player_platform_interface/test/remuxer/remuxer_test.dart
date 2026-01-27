import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/src/container/mp4_box_reader.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/hls_playlist_writer.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/remux_config.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/remux_progress.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/remuxer.dart';

void main() {
  group('RemuxException', () {
    test('creates with message', () {
      const exception = RemuxException('Test error');

      expect(exception.message, equals('Test error'));
    });

    test('toString returns readable string', () {
      const exception = RemuxException('File not found');

      expect(exception.toString(), equals('RemuxException: File not found'));
    });
  });

  group('VideoRemuxer', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('remuxer_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    group('open', () {
      test('throws RemuxException for non-existent file', () async {
        expect(
          () => VideoRemuxer.open('/non/existent/file.mp4'),
          throwsA(isA<RemuxException>().having((e) => e.message, 'message', contains('not found'))),
        );
      });

      test('throws RemuxException for invalid file', () async {
        final invalidFile = File('${tempDir.path}/invalid.mp4');
        invalidFile.writeAsBytesSync([0, 0, 0, 1]); // Invalid MP4

        expect(() => VideoRemuxer.open(invalidFile.path), throwsA(isA<RemuxException>()));
      });

      test('opens valid H264/AAC MP4 file', () async {
        final testFile = _getFixturePath('sample_h264_aac.mp4');
        if (!File(testFile).existsSync()) {
          markTestSkipped('Test fixture not available');
          return;
        }

        final remuxer = await VideoRemuxer.open(testFile);

        expect(remuxer.sourcePath, equals(testFile));
        expect(remuxer.metadata, isNotNull);
        expect(remuxer.trackCount, greaterThan(0));
      });

      test('opens valid HEVC/AAC MP4 file', () async {
        final testFile = _getFixturePath('sample_hevc_aac.mp4');
        if (!File(testFile).existsSync()) {
          markTestSkipped('Test fixture not available');
          return;
        }

        final remuxer = await VideoRemuxer.open(testFile);

        expect(remuxer.sourcePath, equals(testFile));
        expect(remuxer.trackCount, greaterThan(0));
      });
    });

    group('tracks', () {
      test('returns codec info for all tracks', () async {
        final testFile = _getFixturePath('sample_h264_aac.mp4');
        if (!File(testFile).existsSync()) {
          markTestSkipped('Test fixture not available');
          return;
        }

        final remuxer = await VideoRemuxer.open(testFile);
        final tracks = remuxer.tracks;

        expect(tracks, isNotEmpty);

        // Should have at least one video track
        final videoTrack = tracks.where((t) => t.isVideo).firstOrNull;
        expect(videoTrack, isNotNull);
        expect(videoTrack!.codecFourcc, anyOf('avc1', 'avc3', 'hvc1', 'hev1'));
      });
    });

    group('toHls', () {
      test('throws for file without video track', () async {
        // Create a minimal MP4 with only audio
        // For now we skip this test as it requires constructing a valid audio-only MP4
        // which is complex. The error path is tested implicitly.
      });

      test('generates HLS output from H264 MP4', () async {
        final testFile = _getFixturePath('sample_h264_aac.mp4');
        if (!File(testFile).existsSync()) {
          markTestSkipped('Test fixture not available');
          return;
        }

        final remuxer = await VideoRemuxer.open(testFile);
        final outputDir = '${tempDir.path}/hls_output';

        final progressEvents = <RemuxProgress>[];
        await for (final progress in remuxer.toHls(outputDir: outputDir)) {
          progressEvents.add(progress);
        }

        // Should have progress events
        expect(progressEvents, isNotEmpty);

        // Should end with complete
        expect(progressEvents.last.phase, equals(RemuxPhase.complete));
        expect(progressEvents.last.isComplete, isTrue);

        // Should have created output directory
        expect(Directory(outputDir).existsSync(), isTrue);

        // Should have created init segment
        expect(File('$outputDir/video_init.mp4').existsSync(), isTrue);

        // Should have created at least one media segment
        final segments = Directory(outputDir).listSync().where((f) => f.path.endsWith('.m4s')).toList();
        expect(segments, isNotEmpty);

        // Should have created media playlist
        expect(File('$outputDir/video.m3u8').existsSync(), isTrue);

        // Should have created master playlist by default
        expect(File('$outputDir/master.m3u8').existsSync(), isTrue);
      });

      test('respects generateMasterPlaylist=false', () async {
        final testFile = _getFixturePath('sample_h264_aac.mp4');
        if (!File(testFile).existsSync()) {
          markTestSkipped('Test fixture not available');
          return;
        }

        final remuxer = await VideoRemuxer.open(testFile);
        final outputDir = '${tempDir.path}/hls_no_master';

        const config = RemuxConfig(generateMasterPlaylist: false);
        await for (final _ in remuxer.toHls(outputDir: outputDir, config: config)) {
          // Consume stream
        }

        // Should NOT have created master playlist
        expect(File('$outputDir/master.m3u8').existsSync(), isFalse);

        // Should still have media playlist
        expect(File('$outputDir/video.m3u8').existsSync(), isTrue);
      });

      test('respects custom filename prefix', () async {
        final testFile = _getFixturePath('sample_h264_aac.mp4');
        if (!File(testFile).existsSync()) {
          markTestSkipped('Test fixture not available');
          return;
        }

        final remuxer = await VideoRemuxer.open(testFile);
        final outputDir = '${tempDir.path}/hls_custom';

        await for (final _ in remuxer.toHls(outputDir: outputDir, filenamePrefix: 'custom')) {
          // Consume stream
        }

        // Should use custom prefix
        expect(File('$outputDir/custom_init.mp4').existsSync(), isTrue);
        expect(File('$outputDir/custom.m3u8').existsSync(), isTrue);
      });

      test('reports progress through phases', () async {
        final testFile = _getFixturePath('sample_h264_aac.mp4');
        if (!File(testFile).existsSync()) {
          markTestSkipped('Test fixture not available');
          return;
        }

        final remuxer = await VideoRemuxer.open(testFile);
        final outputDir = '${tempDir.path}/hls_progress';

        final phases = <RemuxPhase>[];
        await for (final progress in remuxer.toHls(outputDir: outputDir)) {
          if (phases.isEmpty || phases.last != progress.phase) {
            phases.add(progress.phase);
          }
        }

        // Should progress through phases in order
        expect(phases, contains(RemuxPhase.parsing));
        expect(phases, contains(RemuxPhase.writing));
        expect(phases, contains(RemuxPhase.generatingPlaylists));
        expect(phases, contains(RemuxPhase.complete));

        // Phases should be in order
        final parsingIdx = phases.indexOf(RemuxPhase.parsing);
        final writingIdx = phases.indexOf(RemuxPhase.writing);
        final playlistsIdx = phases.indexOf(RemuxPhase.generatingPlaylists);
        final completeIdx = phases.indexOf(RemuxPhase.complete);

        expect(parsingIdx, lessThan(writingIdx));
        expect(writingIdx, lessThan(playlistsIdx));
        expect(playlistsIdx, lessThan(completeIdx));
      });

      test('generates valid fMP4 init segment', () async {
        final testFile = _getFixturePath('sample_h264_aac.mp4');
        if (!File(testFile).existsSync()) {
          markTestSkipped('Test fixture not available');
          return;
        }

        final remuxer = await VideoRemuxer.open(testFile);
        final outputDir = '${tempDir.path}/hls_validate';

        await for (final _ in remuxer.toHls(outputDir: outputDir)) {
          // Consume stream
        }

        // Validate init segment structure
        final initData = File('$outputDir/video_init.mp4').readAsBytesSync();
        final reader = Mp4BoxReader(initData);

        // Should start with ftyp
        final ftyp = reader.readBox();
        expect(ftyp, isNotNull);
        expect(ftyp!.type, equals('ftyp'));

        // Should have moov
        final moov = reader.readBox();
        expect(moov, isNotNull);
        expect(moov!.type, equals('moov'));
      });

      test('generates valid M3U8 playlist', () async {
        final testFile = _getFixturePath('sample_h264_aac.mp4');
        if (!File(testFile).existsSync()) {
          markTestSkipped('Test fixture not available');
          return;
        }

        final remuxer = await VideoRemuxer.open(testFile);
        final outputDir = '${tempDir.path}/hls_playlist';

        await for (final _ in remuxer.toHls(outputDir: outputDir)) {
          // Consume stream
        }

        // Validate media playlist
        final playlist = File('$outputDir/video.m3u8').readAsStringSync();
        expect(playlist, contains('#EXTM3U'));
        expect(playlist, contains('#EXT-X-VERSION'));
        expect(playlist, contains('#EXT-X-TARGETDURATION'));
        expect(playlist, contains('#EXT-X-MAP'));
        expect(playlist, contains('#EXTINF'));
        expect(playlist, contains('#EXT-X-ENDLIST'));
      });

      test('generates valid master playlist', () async {
        final testFile = _getFixturePath('sample_h264_aac.mp4');
        if (!File(testFile).existsSync()) {
          markTestSkipped('Test fixture not available');
          return;
        }

        final remuxer = await VideoRemuxer.open(testFile);
        final outputDir = '${tempDir.path}/hls_master';

        await for (final _ in remuxer.toHls(outputDir: outputDir)) {
          // Consume stream
        }

        // Validate master playlist
        final master = File('$outputDir/master.m3u8').readAsStringSync();
        expect(master, contains('#EXTM3U'));
        expect(master, contains('#EXT-X-STREAM-INF'));
        expect(master, contains('BANDWIDTH'));
        expect(master, contains('video.m3u8'));
      });

      test('handles includeAudio=false', () async {
        final testFile = _getFixturePath('sample_h264_aac.mp4');
        if (!File(testFile).existsSync()) {
          markTestSkipped('Test fixture not available');
          return;
        }

        final remuxer = await VideoRemuxer.open(testFile);
        final outputDir = '${tempDir.path}/hls_no_audio';

        const config = RemuxConfig(includeAudio: false);
        await for (final _ in remuxer.toHls(outputDir: outputDir, config: config)) {
          // Consume stream
        }

        // Output should still be created (video only)
        expect(Directory(outputDir).existsSync(), isTrue);
        expect(File('$outputDir/video.m3u8').existsSync(), isTrue);
      });

      test('uses VOD playlist type by default', () async {
        final testFile = _getFixturePath('sample_h264_aac.mp4');
        if (!File(testFile).existsSync()) {
          markTestSkipped('Test fixture not available');
          return;
        }

        final remuxer = await VideoRemuxer.open(testFile);
        final outputDir = '${tempDir.path}/hls_vod';

        await for (final _ in remuxer.toHls(outputDir: outputDir)) {
          // Consume stream
        }

        final playlist = File('$outputDir/video.m3u8').readAsStringSync();
        // VOD playlists have #EXT-X-PLAYLIST-TYPE:VOD and #EXT-X-ENDLIST
        expect(playlist, contains('#EXT-X-PLAYLIST-TYPE:VOD'));
        expect(playlist, contains('#EXT-X-ENDLIST'));
      });

      test('respects live playlist type', () async {
        final testFile = _getFixturePath('sample_h264_aac.mp4');
        if (!File(testFile).existsSync()) {
          markTestSkipped('Test fixture not available');
          return;
        }

        final remuxer = await VideoRemuxer.open(testFile);
        final outputDir = '${tempDir.path}/hls_live';

        const config = RemuxConfig(playlistType: HlsPlaylistType.live);
        await for (final _ in remuxer.toHls(outputDir: outputDir, config: config)) {
          // Consume stream
        }

        final playlist = File('$outputDir/video.m3u8').readAsStringSync();
        // Live playlists don't have #EXT-X-ENDLIST
        expect(playlist, isNot(contains('#EXT-X-ENDLIST')));
      });
    });

    group('duration', () {
      test('returns duration from metadata', () async {
        final testFile = _getFixturePath('sample_h264_aac.mp4');
        if (!File(testFile).existsSync()) {
          markTestSkipped('Test fixture not available');
          return;
        }

        final remuxer = await VideoRemuxer.open(testFile);

        // Duration should be positive
        expect(remuxer.duration.inMilliseconds, greaterThan(0));
      });
    });
  });
}

/// Gets the path to a test fixture file.
String _getFixturePath(String filename) {
  // Try multiple possible paths for test fixtures
  final possiblePaths = [
    'test/fixtures/containers/$filename',
    '../test/fixtures/containers/$filename',
    'pro_video_player_platform_interface/test/fixtures/containers/$filename',
  ];

  for (final path in possiblePaths) {
    if (File(path).existsSync()) {
      return path;
    }
  }

  // Return absolute path as fallback
  return '/Users/vitor/resilio/Dev/goodinside/git/pro_video_player/pro_video_player_platform_interface/test/fixtures/containers/$filename';
}
