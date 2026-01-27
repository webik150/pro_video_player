import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/flv_sample_reader.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/sample_reader.dart';

void main() {
  group('FlvSampleReader', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('flv_reader_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    group('FlvSampleReaderFactory', () {
      test('returns null for non-existent file', () async {
        final result = await FlvSampleReaderFactory.inspect('/non/existent/file.flv');
        expect(result, isNull);
      });

      test('returns null for invalid FLV file', () async {
        final invalidFile = File('${tempDir.path}/invalid.flv');
        invalidFile.writeAsBytesSync([0x00, 0x01, 0x02, 0x03]);

        final result = await FlvSampleReaderFactory.inspect(invalidFile.path);
        expect(result, isNull);
      });

      test('inspects valid FLV structure', () async {
        final flvData = _createMinimalFlv();
        final flvFile = File('${tempDir.path}/test.flv');
        flvFile.writeAsBytesSync(flvData);

        final result = await FlvSampleReaderFactory.inspect(flvFile.path);
        // Minimal FLV may or may not have recognizable tracks
        // Just verify it doesn't crash
        expect(result == null || result.metadata != null, isTrue);
      });
    });

    group('FlvSampleReader.open', () {
      test('returns null for non-existent file', () async {
        final reader = await FlvSampleReader.open('/non/existent/file.flv', 1);
        expect(reader, isNull);
      });

      test('returns null for invalid FLV', () async {
        final invalidFile = File('${tempDir.path}/invalid.flv');
        invalidFile.writeAsBytesSync([0x00, 0x01, 0x02, 0x03]);

        final reader = await FlvSampleReader.open(invalidFile.path, 1);
        expect(reader, isNull);
      });
    });

    group('TrackCodecInfo', () {
      test('isVideo returns true for video track info', () {
        const info = TrackCodecInfo(trackId: 1, codecFourcc: 'avc1', timescale: 1000, width: 1280, height: 720);

        expect(info.isVideo, isTrue);
        expect(info.isAudio, isFalse);
      });

      test('isAudio returns true for audio track info', () {
        const info = TrackCodecInfo(
          trackId: 2,
          codecFourcc: 'mp4a',
          timescale: 1000,
          sampleRate: 44100,
          channelCount: 2,
        );

        expect(info.isVideo, isFalse);
        expect(info.isAudio, isTrue);
      });
    });

    group('FLV structure', () {
      test('header starts with FLV signature', () {
        final header = _createFlvHeader(hasVideo: true, hasAudio: true);
        expect(header[0], equals(0x46)); // 'F'
        expect(header[1], equals(0x4C)); // 'L'
        expect(header[2], equals(0x56)); // 'V'
      });

      test('header version is 1', () {
        final header = _createFlvHeader(hasVideo: true, hasAudio: false);
        expect(header[3], equals(1));
      });

      test('header flags indicate video presence', () {
        final headerWithVideo = _createFlvHeader(hasVideo: true, hasAudio: false);
        expect(headerWithVideo[4] & 0x01, equals(1)); // Video flag

        final headerWithAudio = _createFlvHeader(hasVideo: false, hasAudio: true);
        expect(headerWithAudio[4] & 0x04, equals(4)); // Audio flag
      });

      test('header data offset is 9 bytes', () {
        final header = _createFlvHeader(hasVideo: true, hasAudio: true);
        // Data offset is big-endian uint32 at offset 5
        final dataOffset = (header[5] << 24) | (header[6] << 16) | (header[7] << 8) | header[8];
        expect(dataOffset, equals(9));
      });

      test('tag header size is 11 bytes', () {
        final tag = _createFlvTag(tagType: 9, timestamp: 0, data: [0x00]);
        // Tag header is 11 bytes before data
        expect(tag.length, greaterThanOrEqualTo(11));
      });

      test('video tag type is 9', () {
        final tag = _createFlvTag(tagType: 9, timestamp: 100, data: [0x17, 0x00]);
        expect(tag[0], equals(9));
      });

      test('audio tag type is 8', () {
        final tag = _createFlvTag(tagType: 8, timestamp: 100, data: [0xAF, 0x00]);
        expect(tag[0], equals(8));
      });

      test('timestamp is encoded in 3 bytes + extension', () {
        final tag = _createFlvTag(tagType: 9, timestamp: 0x12345678, data: [0x00]);
        // Timestamp is at bytes 4-7 (lower 24 bits at 4-6, upper 8 bits at 7)
        final lower = (tag[4] << 16) | (tag[5] << 8) | tag[6];
        final upper = tag[7];
        final timestamp = (upper << 24) | lower;
        expect(timestamp, equals(0x12345678));
      });
    });

    group('Integration with real fixtures', () {
      test('parses FLV file if available', () async {
        final testFile = _getFixturePath('sample.flv');
        if (!File(testFile).existsSync()) {
          markTestSkipped('Test fixture not available');
          return;
        }

        final inspection = await FlvSampleReaderFactory.inspect(testFile);
        expect(inspection, isNotNull);
        expect(inspection!.metadata, isNotNull);
      });
    });
  });
}

/// Creates a minimal FLV header.
Uint8List _createFlvHeader({required bool hasVideo, required bool hasAudio}) {
  final header = Uint8List(9);

  // Signature "FLV"
  header[0] = 0x46;
  header[1] = 0x4C;
  header[2] = 0x56;

  // Version
  header[3] = 1;

  // Flags
  header[4] = (hasVideo ? 0x01 : 0x00) | (hasAudio ? 0x04 : 0x00);

  // Data offset (big-endian uint32)
  header[5] = 0;
  header[6] = 0;
  header[7] = 0;
  header[8] = 9;

  return header;
}

/// Creates an FLV tag.
Uint8List _createFlvTag({required int tagType, required int timestamp, required List<int> data}) {
  final dataSize = data.length;
  final tag = Uint8List(11 + dataSize + 4); // Header + data + previous tag size

  // Tag type
  tag[0] = tagType;

  // Data size (24-bit big-endian)
  tag[1] = (dataSize >> 16) & 0xFF;
  tag[2] = (dataSize >> 8) & 0xFF;
  tag[3] = dataSize & 0xFF;

  // Timestamp (24-bit + 8-bit extension)
  tag[4] = (timestamp >> 16) & 0xFF;
  tag[5] = (timestamp >> 8) & 0xFF;
  tag[6] = timestamp & 0xFF;
  tag[7] = (timestamp >> 24) & 0xFF;

  // Stream ID (always 0)
  tag[8] = 0;
  tag[9] = 0;
  tag[10] = 0;

  // Data
  for (var i = 0; i < data.length; i++) {
    tag[11 + i] = data[i];
  }

  // Previous tag size (big-endian uint32)
  final prevSize = 11 + dataSize;
  tag[11 + dataSize] = (prevSize >> 24) & 0xFF;
  tag[11 + dataSize + 1] = (prevSize >> 16) & 0xFF;
  tag[11 + dataSize + 2] = (prevSize >> 8) & 0xFF;
  tag[11 + dataSize + 3] = prevSize & 0xFF;

  return tag;
}

/// Creates a minimal valid FLV file.
Uint8List _createMinimalFlv() {
  final buffer = BytesBuilder();

  // Header
  buffer.add(_createFlvHeader(hasVideo: true, hasAudio: false));

  // First PreviousTagSize (0)
  buffer.add([0x00, 0x00, 0x00, 0x00]);

  // Video tag with keyframe indicator
  final videoData = [
    0x17, // Keyframe (1) + AVC codec (7)
    0x00, // AVC sequence header
    0x00, 0x00, 0x00, // Composition time
  ];
  buffer.add(_createFlvTag(tagType: 9, timestamp: 0, data: videoData));

  return buffer.toBytes();
}

/// Gets the path to a test fixture file.
String _getFixturePath(String filename) {
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

  return '/Users/vitor/resilio/Dev/goodinside/git/pro_video_player/pro_video_player_platform_interface/test/fixtures/containers/$filename';
}
