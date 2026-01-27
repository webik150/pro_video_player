import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/remux_progress.dart';

void main() {
  group('RemuxPhase', () {
    test('has all expected phases', () {
      expect(RemuxPhase.values, contains(RemuxPhase.parsing));
      expect(RemuxPhase.values, contains(RemuxPhase.reading));
      expect(RemuxPhase.values, contains(RemuxPhase.writing));
      expect(RemuxPhase.values, contains(RemuxPhase.generatingPlaylists));
      expect(RemuxPhase.values, contains(RemuxPhase.complete));
    });
  });

  group('RemuxProgress', () {
    test('creates with required fields', () {
      const progress = RemuxProgress(phase: RemuxPhase.writing, progress: 0.5);

      expect(progress.phase, equals(RemuxPhase.writing));
      expect(progress.progress, equals(0.5));
      expect(progress.currentSegment, isNull);
      expect(progress.totalSegments, isNull);
      expect(progress.bytesProcessed, equals(0));
      expect(progress.totalBytes, isNull);
      expect(progress.message, isNull);
    });

    test('creates with all fields', () {
      const progress = RemuxProgress(
        phase: RemuxPhase.writing,
        progress: 0.75,
        currentSegment: 5,
        totalSegments: 10,
        bytesProcessed: 1024,
        totalBytes: 2048,
        message: 'Processing...',
      );

      expect(progress.currentSegment, equals(5));
      expect(progress.totalSegments, equals(10));
      expect(progress.bytesProcessed, equals(1024));
      expect(progress.totalBytes, equals(2048));
      expect(progress.message, equals('Processing...'));
    });

    group('factory constructors', () {
      test('parsing creates parsing phase progress', () {
        const progress = RemuxProgress.parsing(progress: 0.25, message: 'Parsing...');

        expect(progress.phase, equals(RemuxPhase.parsing));
        expect(progress.progress, equals(0.25));
        expect(progress.message, equals('Parsing...'));
        expect(progress.currentSegment, isNull);
        expect(progress.bytesProcessed, equals(0));
      });

      test('parsing defaults progress to 0', () {
        const progress = RemuxProgress.parsing();

        expect(progress.phase, equals(RemuxPhase.parsing));
        expect(progress.progress, equals(0.0));
      });

      test('reading creates reading phase progress', () {
        const progress = RemuxProgress.reading(
          progress: 0.5,
          bytesProcessed: 1000,
          totalBytes: 2000,
          message: 'Reading samples...',
        );

        expect(progress.phase, equals(RemuxPhase.reading));
        expect(progress.progress, equals(0.5));
        expect(progress.bytesProcessed, equals(1000));
        expect(progress.totalBytes, equals(2000));
        expect(progress.message, equals('Reading samples...'));
      });

      test('writing creates writing phase progress', () {
        const progress = RemuxProgress.writing(
          progress: 0.6,
          currentSegment: 3,
          totalSegments: 5,
          message: 'Writing segment...',
        );

        expect(progress.phase, equals(RemuxPhase.writing));
        expect(progress.progress, equals(0.6));
        expect(progress.currentSegment, equals(3));
        expect(progress.totalSegments, equals(5));
        expect(progress.message, equals('Writing segment...'));
      });

      test('writing without totalSegments', () {
        const progress = RemuxProgress.writing(progress: 0.4, currentSegment: 2);

        expect(progress.currentSegment, equals(2));
        expect(progress.totalSegments, isNull);
      });

      test('generatingPlaylists creates playlist phase progress', () {
        const progress = RemuxProgress.generatingPlaylists(message: 'Generating...');

        expect(progress.phase, equals(RemuxPhase.generatingPlaylists));
        expect(progress.progress, equals(0.95));
        expect(progress.message, equals('Generating...'));
      });

      test('complete creates complete phase progress', () {
        const progress = RemuxProgress.complete(message: 'Done!');

        expect(progress.phase, equals(RemuxPhase.complete));
        expect(progress.progress, equals(1.0));
        expect(progress.message, equals('Done!'));
        expect(progress.isComplete, isTrue);
      });
    });

    test('progressPercent returns integer percentage', () {
      const progress25 = RemuxProgress(phase: RemuxPhase.parsing, progress: 0.25);
      const progress50 = RemuxProgress(phase: RemuxPhase.reading, progress: 0.5);
      const progress100 = RemuxProgress(phase: RemuxPhase.complete, progress: 1);

      expect(progress25.progressPercent, equals(25));
      expect(progress50.progressPercent, equals(50));
      expect(progress100.progressPercent, equals(100));
    });

    test('progressPercent rounds correctly', () {
      const progress = RemuxProgress(phase: RemuxPhase.writing, progress: 0.333);

      expect(progress.progressPercent, equals(33));
    });

    test('isComplete returns true only for complete phase', () {
      const parsing = RemuxProgress.parsing();
      const reading = RemuxProgress.reading(progress: 0.5, bytesProcessed: 100);
      const writing = RemuxProgress.writing(progress: 0.7, currentSegment: 3);
      const playlists = RemuxProgress.generatingPlaylists();
      const complete = RemuxProgress.complete();

      expect(parsing.isComplete, isFalse);
      expect(reading.isComplete, isFalse);
      expect(writing.isComplete, isFalse);
      expect(playlists.isComplete, isFalse);
      expect(complete.isComplete, isTrue);
    });

    test('reading without totalBytes', () {
      const progress = RemuxProgress.reading(progress: 0.5, bytesProcessed: 1000);

      expect(progress.totalBytes, isNull);
      expect(progress.bytesProcessed, equals(1000));
    });

    test('toString returns readable string', () {
      const progress = RemuxProgress.writing(progress: 0.6, currentSegment: 3, totalSegments: 5);

      final str = progress.toString();
      expect(str, contains('RemuxProgress'));
      expect(str, contains('writing'));
      expect(str, contains('60%'));
      expect(str, contains('segment: 3/5'));
    });

    test('toString without segment info', () {
      const progress = RemuxProgress.parsing(progress: 0.1);

      final str = progress.toString();
      expect(str, contains('parsing'));
      expect(str, contains('10%'));
      expect(str, isNot(contains('segment:')));
    });

    test('toString with segment but no total', () {
      const progress = RemuxProgress.writing(progress: 0.5, currentSegment: 2);

      final str = progress.toString();
      expect(str, contains('segment: 2'));
      expect(str, isNot(contains('/')));
    });
  });

  group('RemuxResult', () {
    test('success creates successful result', () {
      const result = RemuxResult.success(
        outputDirectory: '/output',
        masterPlaylistPath: '/output/master.m3u8',
        mediaPlaylistPaths: ['/output/video.m3u8'],
        segmentPaths: ['/output/seg_1.m4s', '/output/seg_2.m4s'],
        initSegmentPath: '/output/init.mp4',
        totalDuration: Duration(seconds: 60),
        segmentCount: 10,
      );

      expect(result.isSuccess, isTrue);
      expect(result.outputDirectory, equals('/output'));
      expect(result.masterPlaylistPath, equals('/output/master.m3u8'));
      expect(result.mediaPlaylistPaths, hasLength(1));
      expect(result.segmentPaths, hasLength(2));
      expect(result.initSegmentPath, equals('/output/init.mp4'));
      expect(result.totalDuration, equals(const Duration(seconds: 60)));
      expect(result.segmentCount, equals(10));
      expect(result.error, isNull);
    });

    test('failure creates failed result', () {
      const result = RemuxResult.failure(error: 'File not found');

      expect(result.isSuccess, isFalse);
      expect(result.error, equals('File not found'));
      expect(result.outputDirectory, isNull);
      expect(result.masterPlaylistPath, isNull);
      expect(result.mediaPlaylistPaths, isEmpty);
      expect(result.segmentPaths, isEmpty);
      expect(result.initSegmentPath, isNull);
      expect(result.totalDuration, equals(Duration.zero));
      expect(result.segmentCount, equals(0));
    });

    test('success toString returns readable string', () {
      const result = RemuxResult.success(
        outputDirectory: '/output',
        masterPlaylistPath: '/output/master.m3u8',
        mediaPlaylistPaths: [],
        segmentPaths: [],
        initSegmentPath: '/output/init.mp4',
        totalDuration: Duration(seconds: 120),
        segmentCount: 20,
      );

      final str = result.toString();
      expect(str, contains('RemuxResult.success'));
      expect(str, contains('segments: 20'));
      expect(str, contains('duration:'));
    });

    test('failure toString returns readable string', () {
      const result = RemuxResult.failure(error: 'Invalid format');

      final str = result.toString();
      expect(str, contains('RemuxResult.failure'));
      expect(str, contains('Invalid format'));
    });
  });
}
