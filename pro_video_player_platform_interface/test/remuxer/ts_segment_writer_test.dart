import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/sample_reader.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/segment_writer.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/ts_segment_writer.dart';

void main() {
  group('TsSegmentWriter', () {
    late TsSegmentWriter writer;

    setUp(() {
      writer = const TsSegmentWriter();
    });

    group('writeSegment', () {
      test('creates valid TS segment with video only', () {
        final samples = [_createVideoSample(trackId: 1, dts: 0, isKeyframe: true)];

        final segment = writer.writeSegment(samples: samples, videoTrackId: 1, videoCodec: 'avc1');

        // Segment should be multiple of 188 bytes (TS packet size)
        expect(segment.length % 188, equals(0));
        expect(segment.length, greaterThan(0));

        // First packet should be PAT (sync byte + PID 0x0000)
        expect(segment[0], equals(0x47));
        final firstPid = ((segment[1] & 0x1F) << 8) | segment[2];
        expect(firstPid, equals(0x0000));
      });

      test('creates segment with video and audio', () {
        final samples = [
          _createVideoSample(trackId: 1, dts: 0, isKeyframe: true),
          _createAudioSample(trackId: 2, dts: 0),
          _createVideoSample(trackId: 1, dts: 33333, isKeyframe: false),
          _createAudioSample(trackId: 2, dts: 23219),
        ];

        final segment = writer.writeSegment(
          samples: samples,
          videoTrackId: 1,
          videoCodec: 'avc1',
          audioTrackId: 2,
          audioCodec: 'mp4a',
          audioSampleRate: 44100,
          audioChannelCount: 2,
        );

        expect(segment.length % 188, equals(0));
        // Should have at least PAT + PMT + video + audio packets
        expect(segment.length ~/ 188, greaterThanOrEqualTo(4));
      });

      test('starts with PAT packet', () {
        final samples = [_createVideoSample(trackId: 1, dts: 0, isKeyframe: true)];

        final segment = writer.writeSegment(samples: samples, videoTrackId: 1, videoCodec: 'avc1');

        // Check PAT table_id at correct offset
        expect(segment[5], equals(0x00)); // PAT table_id
      });

      test('has PMT as second packet', () {
        final samples = [_createVideoSample(trackId: 1, dts: 0, isKeyframe: true)];

        final segment = writer.writeSegment(samples: samples, videoTrackId: 1, videoCodec: 'avc1');

        // PMT is second packet (starts at byte 188)
        expect(segment[188 + 5], equals(0x02)); // PMT table_id
      });

      test('uses correct stream type for AVC', () {
        final samples = [_createVideoSample(trackId: 1, dts: 0, isKeyframe: true)];

        final segment = writer.writeSegment(samples: samples, videoTrackId: 1, videoCodec: 'avc1');

        // PMT should contain AVC stream type (0x1B)
        final pmtPacket = segment.sublist(188, 376);
        var foundAvc = false;
        for (var i = 0; i < pmtPacket.length - 1; i++) {
          if (pmtPacket[i] == 0x1B) {
            foundAvc = true;
            break;
          }
        }
        expect(foundAvc, isTrue);
      });

      test('uses correct stream type for HEVC', () {
        final samples = [_createVideoSample(trackId: 1, dts: 0, isKeyframe: true)];

        final segment = writer.writeSegment(samples: samples, videoTrackId: 1, videoCodec: 'hvc1');

        // PMT should contain HEVC stream type (0x24)
        final pmtPacket = segment.sublist(188, 376);
        var foundHevc = false;
        for (var i = 0; i < pmtPacket.length - 1; i++) {
          if (pmtPacket[i] == 0x24) {
            foundHevc = true;
            break;
          }
        }
        expect(foundHevc, isTrue);
      });

      test('includes AAC stream in PMT when audio present', () {
        final samples = [
          _createVideoSample(trackId: 1, dts: 0, isKeyframe: true),
          _createAudioSample(trackId: 2, dts: 0),
        ];

        final segment = writer.writeSegment(
          samples: samples,
          videoTrackId: 1,
          videoCodec: 'avc1',
          audioTrackId: 2,
          audioCodec: 'mp4a',
          audioSampleRate: 44100,
          audioChannelCount: 2,
        );

        // PMT should contain AAC stream type (0x0F)
        final pmtPacket = segment.sublist(188, 376);
        var foundAac = false;
        for (var i = 0; i < pmtPacket.length - 1; i++) {
          if (pmtPacket[i] == 0x0F) {
            foundAac = true;
            break;
          }
        }
        expect(foundAac, isTrue);
      });

      test('increments continuity counters across segments', () {
        final samples = [_createVideoSample(trackId: 1, dts: 0, isKeyframe: true)];

        final segment0 = writer.writeSegment(samples: samples, videoTrackId: 1, videoCodec: 'avc1', segmentIndex: 0);

        final segment1 = writer.writeSegment(samples: samples, videoTrackId: 1, videoCodec: 'avc1', segmentIndex: 1);

        // PAT continuity counter should differ between segments
        final cc0 = segment0[3] & 0x0F;
        final cc1 = segment1[3] & 0x0F;
        expect(cc0, isNot(equals(cc1)));
      });

      test('handles empty sample list', () {
        final segment = writer.writeSegment(samples: [], videoTrackId: 1, videoCodec: 'avc1');

        // Should still have PAT and PMT
        expect(segment.length, equals(376)); // 2 packets * 188 bytes
      });

      test('filters samples by track ID', () {
        final samples = [
          _createVideoSample(trackId: 1, dts: 0, isKeyframe: true),
          _createAudioSample(trackId: 2, dts: 0),
          _createVideoSample(trackId: 3, dts: 33333, isKeyframe: false), // Different track
        ];

        final segment = writer.writeSegment(
          samples: samples,
          videoTrackId: 1,
          videoCodec: 'avc1',
          audioTrackId: 2,
          audioCodec: 'mp4a',
        );

        // Track 3 samples should be ignored
        expect(segment.length % 188, equals(0));
      });
    });

    group('segmentStream', () {
      test('yields segments from sample stream', () async {
        final sampleStream = Stream.fromIterable([
          _createVideoSample(trackId: 1, dts: 0, isKeyframe: true),
          _createVideoSample(trackId: 1, dts: 33333, isKeyframe: false),
          _createVideoSample(trackId: 1, dts: 66666, isKeyframe: false),
        ]);

        final segments = await writer
            .segmentStream(
              samples: sampleStream,
              videoTrackId: 1,
              videoCodec: 'avc1',
              config: const SegmentConfig(targetDuration: Duration(seconds: 10)), // Long duration = one segment
            )
            .toList();

        // Should have one segment (no keyframe after target duration)
        expect(segments.length, equals(1));
        expect(segments[0].isInitSegment, isFalse);
        expect(segments[0].index, equals(1));
      });

      test('splits segments at keyframes after target duration', () async {
        // Create samples with keyframes at 0 and 6 seconds (microseconds)
        final sampleStream = Stream.fromIterable([
          _createVideoSample(trackId: 1, dts: 0, isKeyframe: true),
          _createVideoSample(trackId: 1, dts: 3000000, isKeyframe: false),
          _createVideoSample(trackId: 1, dts: 6000000, isKeyframe: true), // New segment here
          _createVideoSample(trackId: 1, dts: 9000000, isKeyframe: false),
        ]);

        final segments = await writer
            .segmentStream(
              samples: sampleStream,
              videoTrackId: 1,
              videoCodec: 'avc1',
              config: const SegmentConfig(targetDuration: Duration(seconds: 5)),
            )
            .toList();

        expect(segments.length, equals(2));
        expect(segments[0].index, equals(1));
        expect(segments[1].index, equals(2));
      });

      test('includes audio samples in segments', () async {
        final sampleStream = Stream.fromIterable([
          _createVideoSample(trackId: 1, dts: 0, isKeyframe: true),
          _createAudioSample(trackId: 2, dts: 0),
          _createVideoSample(trackId: 1, dts: 33333, isKeyframe: false),
          _createAudioSample(trackId: 2, dts: 23219),
        ]);

        final segments = await writer
            .segmentStream(
              samples: sampleStream,
              videoTrackId: 1,
              videoCodec: 'avc1',
              audioTrackId: 2,
              audioCodec: 'mp4a',
              audioSampleRate: 44100,
              audioChannelCount: 2,
            )
            .toList();

        expect(segments.length, equals(1));
        // Segment should be larger due to audio
        expect(segments[0].data.length, greaterThan(376)); // More than just PAT+PMT
      });

      test('calculates segment duration correctly', () async {
        // 3 seconds of video at 30fps (33333 microseconds per frame)
        final samples = <MediaSample>[];
        for (var i = 0; i < 90; i++) {
          // 90 frames = 3 seconds
          samples.add(_createVideoSample(trackId: 1, dts: i * 33333, isKeyframe: i == 0, duration: 33333));
        }

        final segments = await writer
            .segmentStream(
              samples: Stream.fromIterable(samples),
              videoTrackId: 1,
              videoCodec: 'avc1',
              config: const SegmentConfig(targetDuration: Duration(seconds: 10)),
            )
            .toList();

        expect(segments.length, equals(1));
        // Duration should be approximately 3 seconds
        expect(segments[0].duration, closeTo(3.0, 0.1));
      });

      test('calculates segment start time correctly', () async {
        final sampleStream = Stream.fromIterable([
          _createVideoSample(trackId: 1, dts: 0, isKeyframe: true),
          _createVideoSample(trackId: 1, dts: 3000000, isKeyframe: false),
          _createVideoSample(trackId: 1, dts: 6000000, isKeyframe: true),
          _createVideoSample(trackId: 1, dts: 9000000, isKeyframe: false),
        ]);

        final segments = await writer
            .segmentStream(
              samples: sampleStream,
              videoTrackId: 1,
              videoCodec: 'avc1',
              config: const SegmentConfig(targetDuration: Duration(seconds: 5)),
            )
            .toList();

        expect(segments[0].startTime, closeTo(0.0, 0.001));
        expect(segments[1].startTime, closeTo(6.0, 0.001));
      });

      test('handles empty stream', () async {
        final segments = await writer
            .segmentStream(samples: const Stream.empty(), videoTrackId: 1, videoCodec: 'avc1')
            .toList();

        expect(segments, isEmpty);
      });

      test('respects alignToKeyframes config', () async {
        // Create samples where non-keyframe reaches target duration first
        final sampleStream = Stream.fromIterable([
          _createVideoSample(trackId: 1, dts: 0, isKeyframe: true),
          _createVideoSample(trackId: 1, dts: 7000000, isKeyframe: false), // After target
          _createVideoSample(trackId: 1, dts: 8000000, isKeyframe: true), // Keyframe after target
          _createVideoSample(trackId: 1, dts: 10000000, isKeyframe: false),
        ]);

        final segmentsAligned = await writer
            .segmentStream(
              samples: sampleStream,
              videoTrackId: 1,
              videoCodec: 'avc1',
              config: const SegmentConfig(targetDuration: Duration(seconds: 6), alignToKeyframes: true),
            )
            .toList();

        // With alignToKeyframes=true, should split at keyframe (8 seconds)
        expect(segmentsAligned.length, equals(2));
      });
    });
  });
}

var _sampleCounter = 0;

MediaSample _createVideoSample({
  required int trackId,
  required int dts,
  required bool isKeyframe,
  int duration = 33333,
}) {
  // Create some fake NAL unit data (AVC length-prefixed format)
  final nalData = Uint8List.fromList([
    0x00, 0x00, 0x00, 0x05, // Length = 5
    isKeyframe ? 0x65 : 0x41, // NAL type (IDR or non-IDR)
    0x01, 0x02, 0x03, 0x04, // Slice data
  ]);

  return MediaSample(
    trackId: trackId,
    sampleIndex: _sampleCounter++,
    data: nalData,
    decodeTimestamp: dts,
    compositionTimestamp: dts, // CTS = DTS for simplicity
    duration: duration,
    isKeyframe: isKeyframe,
  );
}

MediaSample _createAudioSample({
  required int trackId,
  required int dts,
  int duration = 23219, // ~1024 samples at 44100 Hz
}) {
  // Create some fake AAC frame data
  final aacData = Uint8List.fromList([
    0x21, 0x10, 0x04, 0x60, 0x8C, 0x1C, // Minimal AAC frame
  ]);

  return MediaSample(
    trackId: trackId,
    sampleIndex: _sampleCounter++,
    data: aacData,
    decodeTimestamp: dts,
    compositionTimestamp: dts,
    duration: duration,
    isKeyframe: true, // Audio frames are always random access
  );
}
