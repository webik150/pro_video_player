import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

void main() {
  group('EmbeddedSubtitleReader', () {
    group('open', () {
      test('returns null for non-existent file', () async {
        final reader = await EmbeddedSubtitleReader.open('/non/existent/file.mp4', trackId: 1);
        expect(reader, isNull);
      });

      test('returns null for invalid track ID', () async {
        // Even if the file existed, an invalid track ID should return null
        final reader = await EmbeddedSubtitleReader.open('/non/existent/file.mp4', trackId: 999);
        expect(reader, isNull);
      });
    });
  });

  group('listEmbeddedSubtitleTracks', () {
    test('returns empty list for non-existent file', () async {
      final tracks = await listEmbeddedSubtitleTracks('/non/existent/file.mp4');
      expect(tracks, isEmpty);
    });
  });

  group('Mp4SampleTableParser', () {
    test('parseForTrack returns null for empty data', () {
      final result = Mp4SampleTableParser.parseForTrack(Uint8List(0), 1);
      expect(result, isNull);
    });

    test('parseForTrack returns null for invalid MP4 data', () {
      // Invalid data that doesn't contain moov box
      final invalidData = Uint8List.fromList([0, 0, 0, 16, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6F, 0x6D, 0, 0, 0, 0]);
      final result = Mp4SampleTableParser.parseForTrack(invalidData, 1);
      expect(result, isNull);
    });

    test('parseForTrack returns null for data with only ftyp box', () {
      final data = _buildMp4Box('ftyp', Uint8List.fromList([0x69, 0x73, 0x6F, 0x6D, 0, 0, 0, 0]));
      final result = Mp4SampleTableParser.parseForTrack(data, 1);
      expect(result, isNull);
    });

    test('parseForTrack returns null when box size is too small', () {
      // Box with size < 8
      final data = Uint8List.fromList([0, 0, 0, 4, 0x6D, 0x6F, 0x6F, 0x76]);
      final result = Mp4SampleTableParser.parseForTrack(data, 1);
      expect(result, isNull);
    });

    test('parseForTrack returns null when moov has no trak', () {
      final moovContent = Uint8List(0);
      final moov = _buildMp4Box('moov', moovContent);
      final result = Mp4SampleTableParser.parseForTrack(moov, 1);
      expect(result, isNull);
    });

    test('parseForTrack returns null when trak has no mdia', () {
      final tkhd = _buildTkhdBox(trackId: 1);
      final trak = _buildMp4Box('trak', tkhd);
      final moov = _buildMp4Box('moov', trak);

      final result = Mp4SampleTableParser.parseForTrack(moov, 1);
      expect(result, isNull);
    });

    test('parseForTrack returns null when track ID does not match', () {
      final tkhd = _buildTkhdBox(trackId: 2);
      final trak = _buildMp4Box('trak', tkhd);
      final moov = _buildMp4Box('moov', trak);

      final result = Mp4SampleTableParser.parseForTrack(moov, 1);
      expect(result, isNull);
    });

    test('parseForTrack handles version 1 tkhd', () {
      final tkhd = _buildTkhdBox(trackId: 1, version: 1);
      final trak = _buildMp4Box('trak', tkhd);
      final moov = _buildMp4Box('moov', trak);

      // Will return null because no stbl, but should not crash
      final result = Mp4SampleTableParser.parseForTrack(moov, 1);
      expect(result, isNull);
    });

    test('parseForTrack parses minimal valid sample table', () {
      final mp4 = _buildMinimalMp4WithSampleTable(trackId: 1);
      final result = Mp4SampleTableParser.parseForTrack(mp4, 1);

      expect(result, isNotNull);
      expect(result!.sampleCount, greaterThan(0));
      expect(result.timescale, greaterThan(0));
    });

    test('parseForTrack handles stts with multiple entries', () {
      final mp4 = _buildMinimalMp4WithSampleTable(trackId: 1, sampleCount: 10);
      final result = Mp4SampleTableParser.parseForTrack(mp4, 1);

      expect(result, isNotNull);
      expect(result!.sampleCount, equals(10));
    });

    test('parseForTrack handles uniform sample size (stsz)', () {
      final mp4 = _buildMinimalMp4WithSampleTable(trackId: 1, uniformSampleSize: 100);
      final result = Mp4SampleTableParser.parseForTrack(mp4, 1);

      expect(result, isNotNull);
      expect(result!.sampleSizes.every((s) => s == 100), isTrue);
    });

    test('parseForTrack returns null when stts is missing', () {
      final stbl = _buildMp4Box('stbl', Uint8List(0));
      final minf = _buildMp4Box('minf', stbl);
      final mdhd = _buildMdhdBox(timescale: 1000);
      final mdia = _buildMp4Box('mdia', _concat([mdhd, minf]));
      final tkhd = _buildTkhdBox(trackId: 1);
      final trak = _buildMp4Box('trak', _concat([tkhd, mdia]));
      final moov = _buildMp4Box('moov', trak);

      final result = Mp4SampleTableParser.parseForTrack(moov, 1);
      expect(result, isNull);
    });
  });

  group('DecodedSubtitleSample', () {
    test('creates with required parameters', () {
      const sample = DecodedSubtitleSample(
        startTime: Duration(seconds: 1),
        endTime: Duration(seconds: 5),
        text: 'Hello world',
      );

      expect(sample.startTime, equals(const Duration(seconds: 1)));
      expect(sample.endTime, equals(const Duration(seconds: 5)));
      expect(sample.text, equals('Hello world'));
      expect(sample.styledSpans, isNull);
    });

    test('creates with styled spans', () {
      final sample = DecodedSubtitleSample(
        startTime: Duration.zero,
        endTime: const Duration(seconds: 3),
        text: 'Styled text',
        styledSpans: [
          StyledTextSpan.plain('Styled '),
          const StyledTextSpan(text: 'text', style: SubtitleTextStyle(isBold: true)),
        ],
      );

      expect(sample.styledSpans, isNotNull);
      expect(sample.styledSpans!.length, equals(2));
    });
  });

  group('SubtitleSampleDecoder factory', () {
    test('returns Tx3gDecoder for tx3g codec', () {
      final decoder = SubtitleSampleDecoder.forCodec('tx3g');
      expect(decoder, isA<Tx3gDecoder>());
    });

    test('returns StppDecoder for stpp codec', () {
      final decoder = SubtitleSampleDecoder.forCodec('stpp');
      expect(decoder, isA<StppDecoder>());
    });

    test('returns WvttDecoder for wvtt codec', () {
      final decoder = SubtitleSampleDecoder.forCodec('wvtt');
      expect(decoder, isA<WvttDecoder>());
    });

    test('returns MkvSrtDecoder for s_text/utf8 codec', () {
      final decoder = SubtitleSampleDecoder.forCodec('s_text/utf8');
      expect(decoder, isA<MkvSrtDecoder>());
    });

    test('returns MkvAssDecoder for s_text/ass codec', () {
      final decoder = SubtitleSampleDecoder.forCodec('s_text/ass');
      expect(decoder, isA<MkvAssDecoder>());
    });

    test('returns MkvVttDecoder for s_text/webvtt codec', () {
      final decoder = SubtitleSampleDecoder.forCodec('s_text/webvtt');
      expect(decoder, isA<MkvVttDecoder>());
    });

    test('returns null for unsupported codec', () {
      final decoder = SubtitleSampleDecoder.forCodec('unknown');
      expect(decoder, isNull);
    });

    test('returns null for image-based codecs', () {
      expect(SubtitleSampleDecoder.forCodec('s_hdmv/pgs'), isNull);
      expect(SubtitleSampleDecoder.forCodec('s_vobsub'), isNull);
    });
  });
}

// Helper functions for building MP4 box structures

/// Builds an MP4 box with given type and content.
Uint8List _buildMp4Box(String type, Uint8List content) {
  assert(type.length == 4);
  final size = 8 + content.length;
  final data = Uint8List(size);

  // Size (4 bytes, big-endian)
  data[0] = (size >> 24) & 0xFF;
  data[1] = (size >> 16) & 0xFF;
  data[2] = (size >> 8) & 0xFF;
  data[3] = size & 0xFF;

  // Type (4 bytes)
  for (var i = 0; i < 4; i++) {
    data[4 + i] = type.codeUnitAt(i);
  }

  // Content
  data.setRange(8, size, content);
  return data;
}

/// Builds a tkhd (track header) box.
Uint8List _buildTkhdBox({required int trackId, int version = 0}) {
  final List<int> bytes = [];

  // Version and flags
  bytes.add(version);
  bytes.addAll([0, 0, 1]); // flags

  if (version == 1) {
    // 64-bit times
    bytes.addAll(List.filled(16, 0)); // creation_time + modification_time
    // Track ID (32-bit)
    bytes.addAll(_uint32(trackId));
    bytes.addAll(List.filled(4, 0)); // reserved
    bytes.addAll(List.filled(8, 0)); // duration (64-bit)
  } else {
    // 32-bit times
    bytes.addAll(List.filled(8, 0)); // creation_time + modification_time
    // Track ID (32-bit)
    bytes.addAll(_uint32(trackId));
    bytes.addAll(List.filled(4, 0)); // reserved
    bytes.addAll(List.filled(4, 0)); // duration (32-bit)
  }

  // Remaining tkhd fields (92 bytes of other data)
  bytes.addAll(List.filled(60, 0));

  return _buildMp4Box('tkhd', Uint8List.fromList(bytes));
}

/// Builds an mdhd (media header) box.
Uint8List _buildMdhdBox({required int timescale, int version = 0}) {
  final List<int> bytes = [];

  // Version and flags
  bytes.add(version);
  bytes.addAll([0, 0, 0]); // flags

  if (version == 1) {
    // 64-bit times
    bytes.addAll(List.filled(16, 0)); // creation_time + modification_time
    bytes.addAll(_uint32(timescale));
    bytes.addAll(List.filled(8, 0)); // duration (64-bit)
  } else {
    // 32-bit times
    bytes.addAll(List.filled(8, 0)); // creation_time + modification_time
    bytes.addAll(_uint32(timescale));
    bytes.addAll(List.filled(4, 0)); // duration (32-bit)
  }

  // Language and pre_defined
  bytes.addAll(List.filled(4, 0));

  return _buildMp4Box('mdhd', Uint8List.fromList(bytes));
}

/// Builds an stts (decoding time to sample) box.
Uint8List _buildSttsBox({required int sampleCount, int sampleDelta = 1000}) {
  final List<int> bytes = [];

  // Version and flags
  bytes.addAll([0, 0, 0, 0]);

  // Entry count
  bytes.addAll(_uint32(1));

  // Entry: sample_count, sample_delta
  bytes.addAll(_uint32(sampleCount));
  bytes.addAll(_uint32(sampleDelta));

  return _buildMp4Box('stts', Uint8List.fromList(bytes));
}

/// Builds an stsz (sample size) box.
Uint8List _buildStszBox({required int sampleCount, int uniformSize = 0}) {
  final List<int> bytes = [];

  // Version and flags
  bytes.addAll([0, 0, 0, 0]);

  // Uniform sample size
  bytes.addAll(_uint32(uniformSize));

  // Sample count
  bytes.addAll(_uint32(sampleCount));

  // Individual sizes (only if uniform_size is 0)
  if (uniformSize == 0) {
    for (var i = 0; i < sampleCount; i++) {
      bytes.addAll(_uint32(100 + i)); // Variable sizes
    }
  }

  return _buildMp4Box('stsz', Uint8List.fromList(bytes));
}

/// Builds an stsc (sample to chunk) box.
Uint8List _buildStscBox({required int sampleCount}) {
  final List<int> bytes = [];

  // Version and flags
  bytes.addAll([0, 0, 0, 0]);

  // Entry count
  bytes.addAll(_uint32(1));

  // Entry: first_chunk, samples_per_chunk, sample_description_index
  bytes.addAll(_uint32(1)); // first_chunk
  bytes.addAll(_uint32(sampleCount)); // samples_per_chunk
  bytes.addAll(_uint32(1)); // sample_description_index

  return _buildMp4Box('stsc', Uint8List.fromList(bytes));
}

/// Builds an stco (chunk offset) box.
Uint8List _buildStcoBox({required int chunkCount}) {
  final List<int> bytes = [];

  // Version and flags
  bytes.addAll([0, 0, 0, 0]);

  // Entry count
  bytes.addAll(_uint32(chunkCount));

  // Chunk offsets
  for (var i = 0; i < chunkCount; i++) {
    bytes.addAll(_uint32(1000 + i * 1000)); // Arbitrary offsets
  }

  return _buildMp4Box('stco', Uint8List.fromList(bytes));
}

/// Builds a minimal MP4 with a sample table for testing.
Uint8List _buildMinimalMp4WithSampleTable({
  required int trackId,
  int sampleCount = 5,
  int timescale = 1000,
  int? uniformSampleSize,
}) {
  // Build stbl (sample table)
  final stts = _buildSttsBox(sampleCount: sampleCount);
  final stsz = _buildStszBox(sampleCount: sampleCount, uniformSize: uniformSampleSize ?? 0);
  final stsc = _buildStscBox(sampleCount: sampleCount);
  final stco = _buildStcoBox(chunkCount: 1);
  final stbl = _buildMp4Box('stbl', _concat([stts, stsz, stsc, stco]));

  // Build minf (media information)
  final minf = _buildMp4Box('minf', stbl);

  // Build mdia (media)
  final mdhd = _buildMdhdBox(timescale: timescale);
  final mdia = _buildMp4Box('mdia', _concat([mdhd, minf]));

  // Build trak (track)
  final tkhd = _buildTkhdBox(trackId: trackId);
  final trak = _buildMp4Box('trak', _concat([tkhd, mdia]));

  // Build moov (movie)
  final moov = _buildMp4Box('moov', trak);

  return moov;
}

/// Concatenates multiple Uint8List into one.
Uint8List _concat(List<Uint8List> lists) {
  final totalLength = lists.fold<int>(0, (sum, list) => sum + list.length);
  final result = Uint8List(totalLength);
  var offset = 0;
  for (final list in lists) {
    result.setRange(offset, offset + list.length, list);
    offset += list.length;
  }
  return result;
}

/// Converts an int to big-endian 32-bit bytes.
List<int> _uint32(int value) => [(value >> 24) & 0xFF, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF];
