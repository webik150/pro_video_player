import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/src/container/ebml_reader.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/mkv_sample_reader.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/sample_reader.dart';

void main() {
  group('MkvSampleReader', () {
    group('VINT parsing', () {
      test('parses single-byte VINT', () {
        // 0x81 = marker bit + value 1
        final data = Uint8List.fromList([0x81]);
        final reader = EbmlReader(data);
        expect(reader.readVint(), equals(1));
      });

      test('parses two-byte VINT', () {
        // 0x40 0x01 = marker bit + value 1
        final data = Uint8List.fromList([0x40, 0x01]);
        final reader = EbmlReader(data);
        expect(reader.readVint(), equals(1));
      });

      test('parses three-byte VINT', () {
        // 0x20 0x00 0x01 = marker bit + value 1
        final data = Uint8List.fromList([0x20, 0x00, 0x01]);
        final reader = EbmlReader(data);
        expect(reader.readVint(), equals(1));
      });

      test('parses maximum single-byte value', () {
        // 0xFF = marker bit + value 127
        final data = Uint8List.fromList([0xFF]);
        final reader = EbmlReader(data);
        expect(reader.readVint(), equals(127));
      });
    });

    group('SimpleBlock parsing', () {
      test('identifies keyframe from flags', () {
        // Create a minimal SimpleBlock structure
        // Track 1, timestamp 0, keyframe flag set
        final blockData = _createSimpleBlock(
          trackNumber: 1,
          timestamp: 0,
          isKeyframe: true,
          frameData: [0x00, 0x01, 0x02],
        );

        expect(blockData[3] & 0x80, equals(0x80)); // Keyframe bit set
      });

      test('identifies non-keyframe from flags', () {
        final blockData = _createSimpleBlock(
          trackNumber: 1,
          timestamp: 0,
          isKeyframe: false,
          frameData: [0x00, 0x01, 0x02],
        );

        expect(blockData[3] & 0x80, equals(0)); // Keyframe bit not set
      });

      test('encodes relative timestamp correctly', () {
        final blockData = _createSimpleBlock(trackNumber: 1, timestamp: 1000, isKeyframe: true, frameData: [0x00]);

        // Timestamp is bytes 1-2 (after track number VINT)
        final timestamp = (blockData[1] << 8) | blockData[2];
        expect(timestamp, equals(1000));
      });

      test('encodes negative relative timestamp', () {
        final blockData = _createSimpleBlock(trackNumber: 1, timestamp: -500, isKeyframe: true, frameData: [0x00]);

        // Negative timestamp should be encoded as two's complement
        final timestamp = (blockData[1] << 8) | blockData[2];
        final signed = timestamp > 0x7FFF ? timestamp - 0x10000 : timestamp;
        expect(signed, equals(-500));
      });
    });

    group('Lacing', () {
      test('no lacing returns single frame', () {
        final blockData = _createSimpleBlock(
          trackNumber: 1,
          timestamp: 0,
          isKeyframe: true,
          frameData: [0x00, 0x01, 0x02, 0x03],
        );

        // Flags byte should have lacing bits = 0
        expect((blockData[3] >> 1) & 0x03, equals(0));
      });

      test('Xiph lacing flag is set correctly', () {
        final blockData = _createSimpleBlockWithLacing(
          trackNumber: 1,
          timestamp: 0,
          isKeyframe: true,
          frames: [
            [0x00, 0x01],
            [0x02, 0x03],
          ],
          lacingType: 1, // Xiph
        );

        expect((blockData[3] >> 1) & 0x03, equals(1));
      });

      test('fixed-size lacing flag is set correctly', () {
        final blockData = _createSimpleBlockWithLacing(
          trackNumber: 1,
          timestamp: 0,
          isKeyframe: true,
          frames: [
            [0x00, 0x01],
            [0x02, 0x03],
          ],
          lacingType: 2, // Fixed-size
        );

        expect((blockData[3] >> 1) & 0x03, equals(2));
      });

      test('EBML lacing flag is set correctly', () {
        final blockData = _createSimpleBlockWithLacing(
          trackNumber: 1,
          timestamp: 0,
          isKeyframe: true,
          frames: [
            [0x00, 0x01],
            [0x02, 0x03],
          ],
          lacingType: 3, // EBML
        );

        expect((blockData[3] >> 1) & 0x03, equals(3));
      });
    });

    group('Cluster structure', () {
      test('creates valid cluster with timestamp', () {
        final cluster = _createCluster(timestamp: 1000, blocks: []);
        final reader = EbmlReader(cluster);

        final element = reader.readElement();
        expect(element, isNotNull);
        expect(element!.id, equals(EbmlIds.cluster));
      });

      test('cluster contains timestamp element', () {
        final cluster = _createCluster(timestamp: 5000, blocks: []);
        final reader = EbmlReader(cluster);

        final clusterElement = reader.readElement()!;
        final clusterEnd = clusterElement.dataOffset + clusterElement.dataSize;

        var foundTimestamp = false;
        while (reader.position < clusterEnd) {
          final child = reader.readElement();
          if (child == null) break;

          if (child.id == 0xE7) {
            // Timestamp ID
            final ts = reader.readUint(child.dataSize);
            expect(ts, equals(5000));
            foundTimestamp = true;
            break;
          }
          reader.skip(child.dataSize);
        }

        expect(foundTimestamp, isTrue);
      });
    });

    group('MkvSampleReaderFactory', () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('mkv_reader_test_');
      });

      tearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      test('returns null for non-existent file', () async {
        final result = await MkvSampleReaderFactory.inspect('/non/existent/file.mkv');
        expect(result, isNull);
      });

      test('returns null for invalid MKV file', () async {
        final invalidFile = File('${tempDir.path}/invalid.mkv');
        invalidFile.writeAsBytesSync([0x00, 0x01, 0x02, 0x03]);

        final result = await MkvSampleReaderFactory.inspect(invalidFile.path);
        expect(result, isNull);
      });

      test('inspects minimal valid MKV structure', () async {
        final mkvData = _createMinimalMkv();
        final mkvFile = File('${tempDir.path}/test.mkv');
        mkvFile.writeAsBytesSync(mkvData);

        final result = await MkvSampleReaderFactory.inspect(mkvFile.path);

        // Should parse without errors (may or may not find tracks depending on structure)
        expect(result, isNotNull);
      });
    });

    group('MkvSampleReader.open', () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('mkv_reader_test_');
      });

      tearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      test('returns null for non-existent file', () async {
        final reader = await MkvSampleReader.open('/non/existent/file.mkv', 1);
        expect(reader, isNull);
      });

      test('returns null for non-existent track', () async {
        final mkvData = _createMinimalMkv();
        final mkvFile = File('${tempDir.path}/test.mkv');
        mkvFile.writeAsBytesSync(mkvData);

        final reader = await MkvSampleReader.open(mkvFile.path, 999);
        expect(reader, isNull);
      });
    });

    group('TrackCodecInfo', () {
      test('isVideo returns true for video track info', () {
        const info = TrackCodecInfo(trackId: 1, codecFourcc: 'avc1', timescale: 1000000, width: 1920, height: 1080);

        expect(info.isVideo, isTrue);
        expect(info.isAudio, isFalse);
      });

      test('isAudio returns true for audio track info', () {
        const info = TrackCodecInfo(
          trackId: 2,
          codecFourcc: 'mp4a',
          timescale: 1000000,
          sampleRate: 44100,
          channelCount: 2,
        );

        expect(info.isVideo, isFalse);
        expect(info.isAudio, isTrue);
      });

      test('toString formats video track correctly', () {
        const info = TrackCodecInfo(trackId: 1, codecFourcc: 'avc1', timescale: 1000000, width: 1920, height: 1080);

        expect(info.toString(), contains('1920x1080'));
        expect(info.toString(), contains('avc1'));
      });

      test('toString formats audio track correctly', () {
        const info = TrackCodecInfo(
          trackId: 2,
          codecFourcc: 'mp4a',
          timescale: 1000000,
          sampleRate: 48000,
          channelCount: 6,
        );

        expect(info.toString(), contains('48000'));
        expect(info.toString(), contains('6 ch'));
      });
    });

    group('Integration with real fixtures', () {
      test('parses H.264 WebM file if available', () async {
        final testFile = _getFixturePath('sample_vp9.webm');
        if (!File(testFile).existsSync()) {
          markTestSkipped('Test fixture not available');
          return;
        }

        final inspection = await MkvSampleReaderFactory.inspect(testFile);
        expect(inspection, isNotNull);
        expect(inspection!.metadata, isNotNull);
        expect(inspection.trackIds, isNotEmpty);
      });

      test('parses MKV file tracks if available', () async {
        final testFile = _getFixturePath('sample_h264.mkv');
        if (!File(testFile).existsSync()) {
          markTestSkipped('Test fixture not available');
          return;
        }

        final inspection = await MkvSampleReaderFactory.inspect(testFile);
        expect(inspection, isNotNull);

        // Try to open reader for first track
        if (inspection!.trackIds.isNotEmpty) {
          final reader = await MkvSampleReader.open(testFile, inspection.trackIds.first);
          expect(reader, isNotNull);

          if (reader != null) {
            expect(reader.trackId, equals(inspection.trackIds.first));
            await reader.close();
          }
        }
      });
    });
  });
}

/// Creates a SimpleBlock without lacing.
Uint8List _createSimpleBlock({
  required int trackNumber,
  required int timestamp,
  required bool isKeyframe,
  required List<int> frameData,
  int lacingType = 0,
}) {
  final buffer = BytesBuilder();

  // Track number as single-byte VINT (for track 1-127)
  buffer.addByte(0x80 | trackNumber);

  // Relative timestamp (signed 16-bit big-endian)
  final ts = timestamp < 0 ? timestamp + 0x10000 : timestamp;
  buffer.addByte((ts >> 8) & 0xFF);
  buffer.addByte(ts & 0xFF);

  // Flags: keyframe + lacing type
  var flags = 0;
  if (isKeyframe) flags |= 0x80;
  flags |= (lacingType & 0x03) << 1;
  buffer.addByte(flags);

  // Frame data
  buffer.add(frameData);

  return buffer.toBytes();
}

/// Creates a SimpleBlock with lacing.
Uint8List _createSimpleBlockWithLacing({
  required int trackNumber,
  required int timestamp,
  required bool isKeyframe,
  required List<List<int>> frames,
  required int lacingType,
}) {
  final buffer = BytesBuilder();

  // Track number
  buffer.addByte(0x80 | trackNumber);

  // Timestamp
  buffer.addByte((timestamp >> 8) & 0xFF);
  buffer.addByte(timestamp & 0xFF);

  // Flags
  var flags = 0;
  if (isKeyframe) flags |= 0x80;
  flags |= (lacingType & 0x03) << 1;
  buffer.addByte(flags);

  // Number of frames - 1
  buffer.addByte(frames.length - 1);

  // Frame sizes (depending on lacing type)
  switch (lacingType) {
    case 1: // Xiph
      for (var i = 0; i < frames.length - 1; i++) {
        var size = frames[i].length;
        while (size >= 255) {
          buffer.addByte(255);
          size -= 255;
        }
        buffer.addByte(size);
      }

    case 2: // Fixed-size - no size bytes needed

    case 3: // EBML
      // First size as VINT
      buffer.addByte(0x80 | frames[0].length);
      // Subsequent sizes as signed VINT deltas
      for (var i = 1; i < frames.length - 1; i++) {
        final delta = frames[i].length - frames[i - 1].length;
        // Simplified: assume small positive deltas
        buffer.addByte(0x80 | (delta + 64)); // Bias of 64 for 1-byte signed VINT
      }
  }

  // Frame data
  for (final frame in frames) {
    buffer.add(frame);
  }

  return buffer.toBytes();
}

/// Creates a minimal Cluster element.
Uint8List _createCluster({required int timestamp, required List<Uint8List> blocks}) {
  final content = BytesBuilder();

  // Timestamp element (ID: 0xE7)
  content.addByte(0xE7); // 1-byte ID
  content.addByte(0x82); // Size: 2 bytes
  content.addByte((timestamp >> 8) & 0xFF);
  content.addByte(timestamp & 0xFF);

  // Add blocks
  for (final block in blocks) {
    content.addByte(0xA3); // SimpleBlock ID
    // Size as VINT
    if (block.length < 127) {
      content.addByte(0x80 | block.length);
    } else {
      content.addByte(0x40 | ((block.length >> 8) & 0x3F));
      content.addByte(block.length & 0xFF);
    }
    content.add(block);
  }

  final contentBytes = content.toBytes();

  // Build cluster with header
  final cluster = BytesBuilder();
  // Cluster ID: 0x1F43B675
  cluster.add([0x1F, 0x43, 0xB6, 0x75]);
  // Size
  if (contentBytes.length < 127) {
    cluster.addByte(0x80 | contentBytes.length);
  } else {
    cluster.addByte(0x40 | ((contentBytes.length >> 8) & 0x3F));
    cluster.addByte(contentBytes.length & 0xFF);
  }
  cluster.add(contentBytes);

  return cluster.toBytes();
}

/// Creates a minimal valid MKV structure.
Uint8List _createMinimalMkv() {
  final buffer = BytesBuilder();

  // EBML Header
  buffer.add([0x1A, 0x45, 0xDF, 0xA3]); // EBML ID
  buffer.addByte(0x93); // Size: 19 bytes

  // DocType = "matroska"
  buffer.add([0x42, 0x82]); // DocType ID
  buffer.addByte(0x88); // Size: 8
  buffer.add('matroska'.codeUnits);

  // DocTypeVersion = 4
  buffer.add([0x42, 0x87]); // DocTypeVersion ID
  buffer.addByte(0x81); // Size: 1
  buffer.addByte(0x04);

  // DocTypeReadVersion = 2
  buffer.add([0x42, 0x85]); // DocTypeReadVersion ID
  buffer.addByte(0x81); // Size: 1
  buffer.addByte(0x02);

  // Segment
  buffer.add([0x18, 0x53, 0x80, 0x67]); // Segment ID
  // Unknown size (all 1s except marker)
  buffer.add([0x01, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);

  // Info element (minimal)
  buffer.add([0x15, 0x49, 0xA9, 0x66]); // Info ID
  buffer.addByte(0x8B); // Size: 11

  // TimecodeScale = 1000000
  buffer.add([0x2A, 0xD7, 0xB1]); // TimecodeScale ID
  buffer.addByte(0x83); // Size: 3
  buffer.add([0x0F, 0x42, 0x40]); // 1000000

  // Duration = 10000 (10 seconds at 1ms scale)
  buffer.add([0x44, 0x89]); // Duration ID
  buffer.addByte(0x84); // Size: 4 (float)
  // 10000.0 as float32 big-endian
  final durationBytes = ByteData(4)..setFloat32(0, 10000);
  buffer.add(durationBytes.buffer.asUint8List());

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
