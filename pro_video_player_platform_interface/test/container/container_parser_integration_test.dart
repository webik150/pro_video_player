@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/src/container/container_parser.dart';
import 'package:pro_video_player_platform_interface/src/types/container_track_type.dart';

/// Integration tests with real MP4 files from example-showcase assets.
void main() {
  group('ContainerParser integration', () {
    late File sampleMp4;
    late File sampleWithChapters;

    setUpAll(() {
      // Find project root and sample files
      final projectRoot = _findProjectRoot();
      sampleMp4 = File('$projectRoot/example-showcase/assets/videos/sample.mp4');
      sampleWithChapters = File('$projectRoot/example-showcase/assets/videos/sample_with_chapters.mp4');
    });

    group('sample.mp4', () {
      test('detects mp4 format', () {
        if (!sampleMp4.existsSync()) {
          markTestSkipped('sample.mp4 not found');
          return;
        }

        final bytes = sampleMp4.readAsBytesSync();
        final format = ContainerParser.detectFormat(bytes);

        expect(format, isNotNull);
        expect(['mp4', 'mov', 'm4v'].contains(format), isTrue, reason: 'Expected MP4-family format, got: $format');
      });

      test('parses metadata successfully', () {
        if (!sampleMp4.existsSync()) {
          markTestSkipped('sample.mp4 not found');
          return;
        }

        final bytes = sampleMp4.readAsBytesSync();
        final metadata = ContainerParser.parse(bytes);

        expect(metadata, isNotNull, reason: 'Failed to parse sample.mp4');
        expect(metadata!.format, isNotEmpty);
        expect(metadata.duration.inMilliseconds, greaterThan(0));
      });

      test('extracts video track', () {
        if (!sampleMp4.existsSync()) {
          markTestSkipped('sample.mp4 not found');
          return;
        }

        final bytes = sampleMp4.readAsBytesSync();
        final metadata = ContainerParser.parse(bytes);

        expect(metadata, isNotNull);
        expect(metadata!.videoTracks, isNotEmpty, reason: 'No video tracks found');

        final videoTrack = metadata.videoTracks.first;
        expect(videoTrack.type, equals(ContainerTrackType.video));
        expect(videoTrack.codec.fourcc, isNotEmpty);
        expect(videoTrack.codec.isVideoCodec, isTrue);
        expect(videoTrack.videoInfo, isNotNull);
        expect(videoTrack.videoInfo!.width, greaterThan(0));
        expect(videoTrack.videoInfo!.height, greaterThan(0));
      });

      test('extracts multiple audio tracks', () {
        if (!sampleMp4.existsSync()) {
          markTestSkipped('sample.mp4 not found');
          return;
        }

        final bytes = sampleMp4.readAsBytesSync();
        final metadata = ContainerParser.parse(bytes);

        expect(metadata, isNotNull);
        // sample.mp4 has 1 video + 2 audio tracks
        expect(metadata!.audioTracks.length, equals(2), reason: 'sample.mp4 should have 2 audio tracks');
        expect(metadata.primaryAudioTrack, isNotNull);
        expect(metadata.primaryAudioTrack!.codec.fourcc, equals('mp4a'));
      });

      test('extracts compatible brands', () {
        if (!sampleMp4.existsSync()) {
          markTestSkipped('sample.mp4 not found');
          return;
        }

        final bytes = sampleMp4.readAsBytesSync();
        final metadata = ContainerParser.parse(bytes);

        expect(metadata, isNotNull);
        expect(metadata!.compatibleBrands, isNotEmpty);
      });
    });

    group('sample_with_chapters.mp4', () {
      test('parses multi-track file with video and audio', () {
        if (!sampleWithChapters.existsSync()) {
          markTestSkipped('sample_with_chapters.mp4 not found');
          return;
        }

        final bytes = sampleWithChapters.readAsBytesSync();
        final metadata = ContainerParser.parse(bytes);

        expect(metadata, isNotNull, reason: 'Failed to parse sample_with_chapters.mp4');
        expect(metadata!.tracks.length, greaterThanOrEqualTo(2));
        expect(metadata.videoTracks, isNotEmpty);
        expect(metadata.audioTracks, isNotEmpty);
      });

      test('extracts H.264 video track correctly', () {
        if (!sampleWithChapters.existsSync()) {
          markTestSkipped('sample_with_chapters.mp4 not found');
          return;
        }

        final bytes = sampleWithChapters.readAsBytesSync();
        final metadata = ContainerParser.parse(bytes);

        expect(metadata, isNotNull);
        final video = metadata!.primaryVideoTrack;
        expect(video, isNotNull);
        expect(video!.codec.fourcc, equals('avc1'));
        expect(video.codec.name, equals('H.264'));
        expect(video.videoInfo?.width, equals(480));
        expect(video.videoInfo?.height, equals(270));
      });

      test('extracts AAC audio track correctly', () {
        if (!sampleWithChapters.existsSync()) {
          markTestSkipped('sample_with_chapters.mp4 not found');
          return;
        }

        final bytes = sampleWithChapters.readAsBytesSync();
        final metadata = ContainerParser.parse(bytes);

        expect(metadata, isNotNull);
        final audio = metadata!.primaryAudioTrack;
        expect(audio, isNotNull);
        expect(audio!.codec.fourcc, equals('mp4a'));
        expect(audio.codec.name, equals('AAC'));
        expect(audio.audioInfo?.sampleRate, equals(44100));
        expect(audio.audioInfo?.channelCount, equals(2));
      });

      test('extracts duration correctly (~15 seconds)', () {
        if (!sampleWithChapters.existsSync()) {
          markTestSkipped('sample_with_chapters.mp4 not found');
          return;
        }

        final bytes = sampleWithChapters.readAsBytesSync();
        final metadata = ContainerParser.parse(bytes);

        expect(metadata, isNotNull);
        // Duration should be approximately 15 seconds
        expect(metadata!.duration.inSeconds, closeTo(15, 1));
      });
    });
  });
}

/// Finds the project root directory by looking for CLAUDE.md.
String _findProjectRoot() {
  var dir = Directory.current;

  while (dir.path != dir.parent.path) {
    if (File('${dir.path}/CLAUDE.md').existsSync()) {
      return dir.path;
    }
    dir = dir.parent;
  }

  // Fallback: use relative path from test location
  return '../../..';
}
