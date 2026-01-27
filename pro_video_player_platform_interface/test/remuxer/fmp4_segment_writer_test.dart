import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/src/container/mp4_box_reader.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/fmp4_segment_writer.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/sample_reader.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/segment_writer.dart';

void main() {
  group('MediaSegment', () {
    test('creates with all fields', () {
      final segment = MediaSegment(
        data: Uint8List.fromList([1, 2, 3]),
        index: 1,
        startTime: 0,
        duration: 6,
        isInitSegment: false,
      );

      expect(segment.data.length, equals(3));
      expect(segment.index, equals(1));
      expect(segment.startTime, equals(0.0));
      expect(segment.duration, equals(6.0));
      expect(segment.isInitSegment, isFalse);
      expect(segment.size, equals(3));
    });

    test('toString returns readable string', () {
      final segment = MediaSegment(data: Uint8List(100), index: 2, startTime: 6, duration: 5.5, isInitSegment: false);

      final str = segment.toString();
      expect(str, contains('MediaSegment'));
      expect(str, contains('index: 2'));
      expect(str, contains('6.000s'));
    });
  });

  group('SegmentConfig', () {
    test('has default values', () {
      const config = SegmentConfig();

      expect(config.targetDuration, equals(const Duration(seconds: 6)));
      expect(config.alignToKeyframes, isTrue);
    });

    test('accepts custom values', () {
      const config = SegmentConfig(targetDuration: Duration(seconds: 10), alignToKeyframes: false);

      expect(config.targetDuration, equals(const Duration(seconds: 10)));
      expect(config.alignToKeyframes, isFalse);
    });
  });

  group('Fmp4SegmentWriter', () {
    late Fmp4SegmentWriter writer;

    setUp(() {
      writer = const Fmp4SegmentWriter();
    });

    group('writeInitSegment', () {
      test('creates valid ftyp + moov structure', () {
        const track = TrackCodecInfo(trackId: 1, codecFourcc: 'avc1', timescale: 90000, width: 1920, height: 1080);

        final bytes = writer.writeInitSegment([track]);
        expect(bytes.length, greaterThan(0));

        // Parse and verify structure
        final reader = Mp4BoxReader(bytes);

        // First box should be ftyp
        final ftyp = reader.readBox();
        expect(ftyp, isNotNull);
        expect(ftyp!.type, equals('ftyp'));

        // Second box should be moov
        final moov = reader.readBox();
        expect(moov, isNotNull);
        expect(moov!.type, equals('moov'));
      });

      test('creates valid ftyp with correct brands', () {
        const track = TrackCodecInfo(trackId: 1, codecFourcc: 'avc1', timescale: 90000, width: 1920, height: 1080);

        final bytes = writer.writeInitSegment([track]);
        final reader = Mp4BoxReader(bytes);
        final ftyp = reader.readBox()!;

        reader.enterBox(ftyp);
        expect(reader.readFourCC(), equals('isom'));
      });

      test('creates moov with mvhd', () {
        const track = TrackCodecInfo(trackId: 1, codecFourcc: 'avc1', timescale: 90000, width: 1920, height: 1080);

        final bytes = writer.writeInitSegment([track]);
        final reader = Mp4BoxReader(bytes);
        reader.readBox(); // skip ftyp
        final moov = reader.readBox()!;

        final mvhd = reader.findChildBox(moov, 'mvhd');
        expect(mvhd, isNotNull);
      });

      test('creates moov with trak for each track', () {
        final tracks = [
          const TrackCodecInfo(trackId: 1, codecFourcc: 'avc1', timescale: 90000, width: 1920, height: 1080),
          const TrackCodecInfo(trackId: 2, codecFourcc: 'mp4a', timescale: 44100, sampleRate: 44100, channelCount: 2),
        ];

        final bytes = writer.writeInitSegment(tracks);
        final reader = Mp4BoxReader(bytes);
        reader.readBox(); // skip ftyp
        final moov = reader.readBox()!;

        // Count trak boxes
        var trakCount = 0;
        reader.seek(moov.dataOffset);
        while (reader.position < moov.endOffset && reader.hasRemaining(8)) {
          final box = reader.readChildBox(moov);
          if (box == null) break;
          if (box.type == 'trak') trakCount++;
        }

        expect(trakCount, equals(2));
      });

      test('creates moov with mvex for fragmentation', () {
        const track = TrackCodecInfo(trackId: 1, codecFourcc: 'avc1', timescale: 90000, width: 1920, height: 1080);

        final bytes = writer.writeInitSegment([track]);
        final reader = Mp4BoxReader(bytes);
        reader.readBox(); // skip ftyp
        final moov = reader.readBox()!;

        final mvex = reader.findChildBox(moov, 'mvex');
        expect(mvex, isNotNull);
      });

      test('creates mvex with trex for each track', () {
        final tracks = [
          const TrackCodecInfo(trackId: 1, codecFourcc: 'avc1', timescale: 90000, width: 1920, height: 1080),
          const TrackCodecInfo(trackId: 2, codecFourcc: 'mp4a', timescale: 44100, sampleRate: 44100, channelCount: 2),
        ];

        final bytes = writer.writeInitSegment(tracks);
        final reader = Mp4BoxReader(bytes);
        reader.readBox(); // skip ftyp
        final moov = reader.readBox()!;
        final mvex = reader.findChildBox(moov, 'mvex')!;

        // Count trex boxes
        var trexCount = 0;
        reader.seek(mvex.dataOffset);
        while (reader.position < mvex.endOffset && reader.hasRemaining(8)) {
          final box = reader.readChildBox(mvex);
          if (box == null) break;
          if (box.type == 'trex') trexCount++;
        }

        expect(trexCount, equals(2));
      });

      test('creates video track with correct structure', () {
        const track = TrackCodecInfo(trackId: 1, codecFourcc: 'avc1', timescale: 90000, width: 1920, height: 1080);

        final bytes = writer.writeInitSegment([track]);
        final reader = Mp4BoxReader(bytes);
        reader.readBox(); // skip ftyp
        final moov = reader.readBox()!;
        final trak = reader.findChildBox(moov, 'trak')!;

        // Should have tkhd
        final tkhd = reader.findChildBox(trak, 'tkhd');
        expect(tkhd, isNotNull);

        // Should have mdia
        final mdia = reader.findChildBox(trak, 'mdia');
        expect(mdia, isNotNull);

        // mdia should have mdhd, hdlr, minf
        final mdhd = reader.findChildBox(mdia!, 'mdhd');
        expect(mdhd, isNotNull);

        final hdlr = reader.findChildBox(mdia, 'hdlr');
        expect(hdlr, isNotNull);

        final minf = reader.findChildBox(mdia, 'minf');
        expect(minf, isNotNull);
      });

      test('creates audio track with smhd', () {
        const track = TrackCodecInfo(
          trackId: 1,
          codecFourcc: 'mp4a',
          timescale: 44100,
          sampleRate: 44100,
          channelCount: 2,
        );

        final bytes = writer.writeInitSegment([track]);
        final reader = Mp4BoxReader(bytes);
        reader.readBox(); // skip ftyp
        final moov = reader.readBox()!;
        final trak = reader.findChildBox(moov, 'trak')!;
        final mdia = reader.findChildBox(trak, 'mdia')!;
        final minf = reader.findChildBox(mdia, 'minf')!;

        // Audio should have smhd, not vmhd
        final smhd = reader.findChildBox(minf, 'smhd');
        expect(smhd, isNotNull);
      });

      test('creates video track with vmhd', () {
        const track = TrackCodecInfo(trackId: 1, codecFourcc: 'avc1', timescale: 90000, width: 1920, height: 1080);

        final bytes = writer.writeInitSegment([track]);
        final reader = Mp4BoxReader(bytes);
        reader.readBox(); // skip ftyp
        final moov = reader.readBox()!;
        final trak = reader.findChildBox(moov, 'trak')!;
        final mdia = reader.findChildBox(trak, 'mdia')!;
        final minf = reader.findChildBox(mdia, 'minf')!;

        // Video should have vmhd
        final vmhd = reader.findChildBox(minf, 'vmhd');
        expect(vmhd, isNotNull);
      });

      test('includes codec private data in stsd', () {
        final codecPrivate = Uint8List.fromList([
          // avcC box header
          0x00, 0x00, 0x00, 0x20, // size = 32
          0x61, 0x76, 0x63, 0x43, // 'avcC'
          // avcC content (simplified)
          0x01, 0x64, 0x00, 0x1F, // version, profile, compat, level
          0xFF, 0xE1, 0x00, 0x10, // NALU length size, SPS count, SPS size
          // ... rest of codec config
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        ]);

        final track = TrackCodecInfo(
          trackId: 1,
          codecFourcc: 'avc1',
          timescale: 90000,
          width: 1920,
          height: 1080,
          codecPrivateData: codecPrivate,
        );

        final bytes = writer.writeInitSegment([track]);
        expect(bytes.length, greaterThan(codecPrivate.length));
      });

      test('handles empty track list', () {
        final bytes = writer.writeInitSegment([]);

        // Should still create valid ftyp + moov
        final reader = Mp4BoxReader(bytes);
        final ftyp = reader.readBox();
        expect(ftyp, isNotNull);
        final moov = reader.readBox();
        expect(moov, isNotNull);
      });
    });

    group('writeMediaSegment', () {
      test('creates valid moof + mdat structure', () {
        final samples = [
          MediaSample(
            data: Uint8List.fromList(List.generate(100, (i) => i)),
            trackId: 1,
            sampleIndex: 0,
            decodeTimestamp: 0,
            compositionTimestamp: 0,
            duration: 3000,
            isKeyframe: true,
          ),
        ];

        final bytes = writer.writeMediaSegment(
          samples: samples,
          sequenceNumber: 1,
          baseDecodeTime: 0,
          timescale: 90000,
        );

        final reader = Mp4BoxReader(bytes);
        final moof = reader.readBox();
        expect(moof, isNotNull);
        expect(moof!.type, equals('moof'));

        final mdat = reader.readBox();
        expect(mdat, isNotNull);
        expect(mdat!.type, equals('mdat'));
      });

      test('moof contains mfhd with sequence number', () {
        final samples = [
          MediaSample(
            data: Uint8List(100),
            trackId: 1,
            sampleIndex: 0,
            decodeTimestamp: 0,
            compositionTimestamp: 0,
            duration: 3000,
            isKeyframe: true,
          ),
        ];

        final bytes = writer.writeMediaSegment(
          samples: samples,
          sequenceNumber: 5,
          baseDecodeTime: 0,
          timescale: 90000,
        );

        final reader = Mp4BoxReader(bytes);
        final moof = reader.readBox()!;
        final mfhd = reader.findChildBox(moof, 'mfhd')!;

        reader.enterBox(mfhd);
        reader.skip(4); // version + flags
        expect(reader.readUint32(), equals(5));
      });

      test('moof contains traf for each track', () {
        final samples = [
          MediaSample(
            data: Uint8List(100),
            trackId: 1,
            sampleIndex: 0,
            decodeTimestamp: 0,
            compositionTimestamp: 0,
            duration: 3000,
            isKeyframe: true,
          ),
          MediaSample(
            data: Uint8List(50),
            trackId: 2,
            sampleIndex: 0,
            decodeTimestamp: 0,
            compositionTimestamp: 0,
            duration: 1024,
            isKeyframe: true,
          ),
        ];

        final bytes = writer.writeMediaSegment(
          samples: samples,
          sequenceNumber: 1,
          baseDecodeTime: 0,
          timescale: 90000,
        );

        final reader = Mp4BoxReader(bytes);
        final moof = reader.readBox()!;

        // Count traf boxes
        var trafCount = 0;
        reader.seek(moof.dataOffset);
        while (reader.position < moof.endOffset && reader.hasRemaining(8)) {
          final box = reader.readChildBox(moof);
          if (box == null) break;
          if (box.type == 'traf') trafCount++;
        }

        expect(trafCount, equals(2));
      });

      test('traf contains tfhd, tfdt, trun', () {
        final samples = [
          MediaSample(
            data: Uint8List(100),
            trackId: 1,
            sampleIndex: 0,
            decodeTimestamp: 0,
            compositionTimestamp: 0,
            duration: 3000,
            isKeyframe: true,
          ),
        ];

        final bytes = writer.writeMediaSegment(
          samples: samples,
          sequenceNumber: 1,
          baseDecodeTime: 0,
          timescale: 90000,
        );

        final reader = Mp4BoxReader(bytes);
        final moof = reader.readBox()!;
        final traf = reader.findChildBox(moof, 'traf')!;

        final tfhd = reader.findChildBox(traf, 'tfhd');
        expect(tfhd, isNotNull);

        final tfdt = reader.findChildBox(traf, 'tfdt');
        expect(tfdt, isNotNull);

        final trun = reader.findChildBox(traf, 'trun');
        expect(trun, isNotNull);
      });

      test('tfdt contains base decode time', () {
        final samples = [
          MediaSample(
            data: Uint8List(100),
            trackId: 1,
            sampleIndex: 0,
            decodeTimestamp: 90000,
            compositionTimestamp: 90000,
            duration: 3000,
            isKeyframe: true,
          ),
        ];

        final bytes = writer.writeMediaSegment(
          samples: samples,
          sequenceNumber: 1,
          baseDecodeTime: 90000,
          timescale: 90000,
        );

        final reader = Mp4BoxReader(bytes);
        final moof = reader.readBox()!;
        final traf = reader.findChildBox(moof, 'traf')!;
        final tfdt = reader.findChildBox(traf, 'tfdt')!;

        reader.enterBox(tfdt);
        reader.skip(4); // version + flags
        expect(reader.readUint32(), equals(90000));
      });

      test('trun contains sample count', () {
        final samples = [
          MediaSample(
            data: Uint8List(100),
            trackId: 1,
            sampleIndex: 0,
            decodeTimestamp: 0,
            compositionTimestamp: 0,
            duration: 3000,
            isKeyframe: true,
          ),
          MediaSample(
            data: Uint8List(200),
            trackId: 1,
            sampleIndex: 1,
            decodeTimestamp: 3000,
            compositionTimestamp: 6000,
            duration: 3000,
            isKeyframe: false,
          ),
        ];

        final bytes = writer.writeMediaSegment(
          samples: samples,
          sequenceNumber: 1,
          baseDecodeTime: 0,
          timescale: 90000,
        );

        final reader = Mp4BoxReader(bytes);
        final moof = reader.readBox()!;
        final traf = reader.findChildBox(moof, 'traf')!;
        final trun = reader.findChildBox(traf, 'trun')!;

        reader.enterBox(trun);
        reader.skip(4); // version + flags
        expect(reader.readUint32(), equals(2));
      });

      test('mdat contains sample data', () {
        final sampleData = Uint8List.fromList(List.generate(100, (i) => i));
        final samples = [
          MediaSample(
            data: sampleData,
            trackId: 1,
            sampleIndex: 0,
            decodeTimestamp: 0,
            compositionTimestamp: 0,
            duration: 3000,
            isKeyframe: true,
          ),
        ];

        final bytes = writer.writeMediaSegment(
          samples: samples,
          sequenceNumber: 1,
          baseDecodeTime: 0,
          timescale: 90000,
        );

        final reader = Mp4BoxReader(bytes);
        reader.readBox(); // skip moof
        final mdat = reader.readBox()!;

        // mdat data should contain sample data
        reader.enterBox(mdat);
        final mdatData = reader.readBytes(mdat.dataSize);
        expect(mdatData, equals(sampleData));
      });

      test('returns empty bytes for empty samples', () {
        final bytes = writer.writeMediaSegment(samples: [], sequenceNumber: 1, baseDecodeTime: 0, timescale: 90000);

        expect(bytes.length, equals(0));
      });

      test('multiple samples are concatenated in mdat', () {
        final samples = [
          MediaSample(
            data: Uint8List.fromList([1, 2, 3]),
            trackId: 1,
            sampleIndex: 0,
            decodeTimestamp: 0,
            compositionTimestamp: 0,
            duration: 3000,
            isKeyframe: true,
          ),
          MediaSample(
            data: Uint8List.fromList([4, 5, 6]),
            trackId: 1,
            sampleIndex: 1,
            decodeTimestamp: 3000,
            compositionTimestamp: 3000,
            duration: 3000,
            isKeyframe: false,
          ),
        ];

        final bytes = writer.writeMediaSegment(
          samples: samples,
          sequenceNumber: 1,
          baseDecodeTime: 0,
          timescale: 90000,
        );

        final reader = Mp4BoxReader(bytes);
        reader.readBox(); // skip moof
        final mdat = reader.readBox()!;

        reader.enterBox(mdat);
        final mdatData = reader.readBytes(mdat.dataSize);
        expect(mdatData, equals([1, 2, 3, 4, 5, 6]));
      });
    });

    group('segmentStream', () {
      test('yields init segment first', () async {
        final tracks = [
          const TrackCodecInfo(trackId: 1, codecFourcc: 'avc1', timescale: 90000, width: 1920, height: 1080),
        ];

        const sampleStream = Stream<MediaSample>.empty();
        const config = SegmentConfig();

        final segments = await writer.segmentStream(samples: sampleStream, tracks: tracks, config: config).toList();

        expect(segments.length, equals(1));
        expect(segments[0].isInitSegment, isTrue);
        expect(segments[0].index, equals(0));
      });

      test('yields media segments after init', () async {
        final tracks = [
          const TrackCodecInfo(trackId: 1, codecFourcc: 'avc1', timescale: 1000, width: 1920, height: 1080),
        ];

        // Create samples for ~12 seconds (2 segments with 6s default)
        final samples = List.generate(
          12,
          (i) => MediaSample(
            data: Uint8List(100),
            trackId: 1,
            sampleIndex: i,
            decodeTimestamp: i * 1000,
            compositionTimestamp: i * 1000,
            duration: 1000,
            isKeyframe: i % 6 == 0, // Keyframe every 6 samples
          ),
        );

        final sampleStream = Stream.fromIterable(samples);
        const config = SegmentConfig();

        final segments = await writer.segmentStream(samples: sampleStream, tracks: tracks, config: config).toList();

        // Should have init + 2 media segments
        expect(segments.length, equals(3));
        expect(segments[0].isInitSegment, isTrue);
        expect(segments[1].isInitSegment, isFalse);
        expect(segments[2].isInitSegment, isFalse);
      });

      test('segment index starts at 1 for media segments', () async {
        final tracks = [
          const TrackCodecInfo(trackId: 1, codecFourcc: 'avc1', timescale: 1000, width: 1920, height: 1080),
        ];

        final samples = List.generate(
          12,
          (i) => MediaSample(
            data: Uint8List(100),
            trackId: 1,
            sampleIndex: i,
            decodeTimestamp: i * 1000,
            compositionTimestamp: i * 1000,
            duration: 1000,
            isKeyframe: i % 6 == 0,
          ),
        );

        final sampleStream = Stream.fromIterable(samples);
        const config = SegmentConfig();

        final segments = await writer.segmentStream(samples: sampleStream, tracks: tracks, config: config).toList();

        expect(segments[0].index, equals(0)); // init
        expect(segments[1].index, equals(1)); // first media
        expect(segments[2].index, equals(2)); // second media
      });

      test('respects keyframe alignment', () async {
        final tracks = [
          const TrackCodecInfo(trackId: 1, codecFourcc: 'avc1', timescale: 1000, width: 1920, height: 1080),
        ];

        // Keyframes at 0, 8, 16
        final samples = List.generate(
          20,
          (i) => MediaSample(
            data: Uint8List(100),
            trackId: 1,
            sampleIndex: i,
            decodeTimestamp: i * 1000,
            compositionTimestamp: i * 1000,
            duration: 1000,
            isKeyframe: i % 8 == 0,
          ),
        );

        final sampleStream = Stream.fromIterable(samples);
        const config = SegmentConfig();

        final segments = await writer.segmentStream(samples: sampleStream, tracks: tracks, config: config).toList();

        // With keyframes at 0, 8, 16 and target 6s, segments should break at keyframes
        // Segment 1: samples 0-7 (keyframe at 0, next at 8)
        // Segment 2: samples 8-15 (keyframe at 8, next at 16)
        // Segment 3: samples 16-19 (remaining)
        expect(segments.length, equals(4)); // init + 3 media
      });

      test('ignores keyframe alignment when disabled', () async {
        final tracks = [
          const TrackCodecInfo(trackId: 1, codecFourcc: 'avc1', timescale: 1000, width: 1920, height: 1080),
        ];

        // Keyframes only at start
        final samples = List.generate(
          12,
          (i) => MediaSample(
            data: Uint8List(100),
            trackId: 1,
            sampleIndex: i,
            decodeTimestamp: i * 1000,
            compositionTimestamp: i * 1000,
            duration: 1000,
            isKeyframe: i == 0, // Only first sample is keyframe
          ),
        );

        final sampleStream = Stream.fromIterable(samples);
        const config = SegmentConfig(alignToKeyframes: false);

        final segments = await writer.segmentStream(samples: sampleStream, tracks: tracks, config: config).toList();

        // Should still create 2 segments despite no keyframes
        expect(segments.length, equals(3)); // init + 2 media
      });

      test('reports correct segment duration', () async {
        final tracks = [
          const TrackCodecInfo(trackId: 1, codecFourcc: 'avc1', timescale: 1000, width: 1920, height: 1080),
        ];

        final samples = List.generate(
          10,
          (i) => MediaSample(
            data: Uint8List(100),
            trackId: 1,
            sampleIndex: i,
            decodeTimestamp: i * 1000,
            compositionTimestamp: i * 1000,
            duration: 1000,
            isKeyframe: i == 0 || i == 6,
          ),
        );

        final sampleStream = Stream.fromIterable(samples);
        const config = SegmentConfig();

        final segments = await writer.segmentStream(samples: sampleStream, tracks: tracks, config: config).toList();

        // First media segment should be 6 seconds
        expect(segments[1].duration, closeTo(6.0, 0.01));
        // Second media segment should be 4 seconds
        expect(segments[2].duration, closeTo(4.0, 0.01));
      });

      test('reports correct segment start time', () async {
        final tracks = [
          const TrackCodecInfo(trackId: 1, codecFourcc: 'avc1', timescale: 1000, width: 1920, height: 1080),
        ];

        final samples = List.generate(
          12,
          (i) => MediaSample(
            data: Uint8List(100),
            trackId: 1,
            sampleIndex: i,
            decodeTimestamp: i * 1000,
            compositionTimestamp: i * 1000,
            duration: 1000,
            isKeyframe: i == 0 || i == 6,
          ),
        );

        final sampleStream = Stream.fromIterable(samples);
        const config = SegmentConfig();

        final segments = await writer.segmentStream(samples: sampleStream, tracks: tracks, config: config).toList();

        expect(segments[0].startTime, equals(0.0)); // init
        expect(segments[1].startTime, equals(0.0)); // first media
        expect(segments[2].startTime, closeTo(6.0, 0.01)); // second media
      });
    });

    group('sample flags', () {
      test('keyframes have correct flags', () {
        final samples = [
          MediaSample(
            data: Uint8List(100),
            trackId: 1,
            sampleIndex: 0,
            decodeTimestamp: 0,
            compositionTimestamp: 0,
            duration: 3000,
            isKeyframe: true,
          ),
        ];

        final bytes = writer.writeMediaSegment(
          samples: samples,
          sequenceNumber: 1,
          baseDecodeTime: 0,
          timescale: 90000,
        );

        // Parse trun flags
        final reader = Mp4BoxReader(bytes);
        final moof = reader.readBox()!;
        final traf = reader.findChildBox(moof, 'traf')!;
        final trun = reader.findChildBox(traf, 'trun')!;

        reader.enterBox(trun);
        final versionAndFlags = reader.readUint32();
        final flags = versionAndFlags & 0xFFFFFF;

        // Should have sample flags present (0x400)
        expect(flags & 0x400, equals(0x400));
      });
    });
  });
}
