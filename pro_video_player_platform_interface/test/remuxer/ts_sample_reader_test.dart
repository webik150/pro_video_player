import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/sample_reader.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/ts_sample_reader.dart';

void main() {
  group('TsSampleReader', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('ts_reader_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    group('TsSampleReaderFactory', () {
      test('returns null for non-existent file', () async {
        final result = await TsSampleReaderFactory.inspect('/non/existent/file.ts');
        expect(result, isNull);
      });

      test('returns null for invalid TS file', () async {
        final invalidFile = File('${tempDir.path}/invalid.ts');
        invalidFile.writeAsBytesSync([0x00, 0x01, 0x02, 0x03]);

        final result = await TsSampleReaderFactory.inspect(invalidFile.path);
        expect(result, isNull);
      });

      test('inspects valid TS structure', () async {
        final tsData = _createMinimalTs();
        final tsFile = File('${tempDir.path}/test.ts');
        tsFile.writeAsBytesSync(tsData);

        final result = await TsSampleReaderFactory.inspect(tsFile.path);
        // May or may not find tracks depending on minimal structure
        expect(result, isNotNull);
      });
    });

    group('TsSampleReader.open', () {
      test('returns null for non-existent file', () async {
        final reader = await TsSampleReader.open('/non/existent/file.ts', 1);
        expect(reader, isNull);
      });

      test('returns null for non-existent track', () async {
        final tsData = _createMinimalTs();
        final tsFile = File('${tempDir.path}/test.ts');
        tsFile.writeAsBytesSync(tsData);

        final reader = await TsSampleReader.open(tsFile.path, 999);
        expect(reader, isNull);
      });
    });

    group('TrackCodecInfo', () {
      test('isVideo returns true for video track info', () {
        const info = TrackCodecInfo(trackId: 1, codecFourcc: 'avc1', timescale: 90000, width: 1920, height: 1080);

        expect(info.isVideo, isTrue);
        expect(info.isAudio, isFalse);
      });

      test('isAudio returns true for audio track info', () {
        const info = TrackCodecInfo(
          trackId: 2,
          codecFourcc: 'mp4a',
          timescale: 90000,
          sampleRate: 48000,
          channelCount: 2,
        );

        expect(info.isVideo, isFalse);
        expect(info.isAudio, isTrue);
      });
    });

    group('TS packet structure', () {
      test('sync byte is 0x47', () {
        final packet = _createTsPacket(pid: 0x0000, payload: [0x00]);
        expect(packet[0], equals(0x47));
      });

      test('PID is encoded in bytes 1-2', () {
        final packet = _createTsPacket(pid: 0x1234, payload: [0x00]);
        final pid = ((packet[1] & 0x1F) << 8) | packet[2];
        expect(pid, equals(0x1234));
      });

      test('continuity counter is in byte 3', () {
        final packet = _createTsPacket(pid: 0x0000, payload: [0x00], continuityCounter: 5);
        final cc = packet[3] & 0x0F;
        expect(cc, equals(5));
      });

      test('PUSI flag is in byte 1', () {
        final packet = _createTsPacket(pid: 0x0000, payload: [0x00], pusi: true);
        final pusi = (packet[1] & 0x40) != 0;
        expect(pusi, isTrue);
      });

      test('packet size is 188 bytes', () {
        final packet = _createTsPacket(pid: 0x0000, payload: [0x00]);
        expect(packet.length, equals(188));
      });
    });

    group('Integration with real fixtures', () {
      test('parses H.264 TS file if available', () async {
        final testFile = _getFixturePath('sample_h264.ts');
        if (!File(testFile).existsSync()) {
          markTestSkipped('Test fixture not available');
          return;
        }

        final inspection = await TsSampleReaderFactory.inspect(testFile);
        expect(inspection, isNotNull);
        expect(inspection!.metadata, isNotNull);
      });
    });
  });
}

/// Creates a minimal TS packet.
Uint8List _createTsPacket({
  required int pid,
  required List<int> payload,
  bool pusi = false,
  int continuityCounter = 0,
}) {
  final packet = Uint8List(188);

  // Sync byte
  packet[0] = 0x47;

  // PID (13 bits) + PUSI flag
  packet[1] = (pusi ? 0x40 : 0x00) | ((pid >> 8) & 0x1F);
  packet[2] = pid & 0xFF;

  // Adaptation field control (01 = payload only) + continuity counter
  packet[3] = 0x10 | (continuityCounter & 0x0F);

  // Payload
  for (var i = 0; i < payload.length && i + 4 < 188; i++) {
    packet[4 + i] = payload[i];
  }

  // Fill rest with 0xFF
  for (var i = 4 + payload.length; i < 188; i++) {
    packet[i] = 0xFF;
  }

  return packet;
}

/// Creates a minimal valid TS structure with PAT and PMT.
Uint8List _createMinimalTs() {
  final buffer = BytesBuilder();

  // PAT packet (PID 0x0000)
  final pat = _createPatPacket(pmtPid: 0x1000, programNumber: 1);
  buffer.add(pat);

  // PMT packet (PID 0x1000)
  final pmt = _createPmtPacket(
    videoPid: 0x0100,
    videoStreamType: 0x1B, // H.264
  );
  buffer.add(pmt);

  return buffer.toBytes();
}

/// Creates a PAT packet.
Uint8List _createPatPacket({required int pmtPid, required int programNumber}) {
  final packet = Uint8List(188);

  // Header
  packet[0] = 0x47;
  packet[1] = 0x40; // PUSI
  packet[2] = 0x00; // PID = 0
  packet[3] = 0x10; // Payload only

  // Pointer field
  packet[4] = 0x00;

  // PAT table
  packet[5] = 0x00; // table_id
  packet[6] = 0x80 | ((13 >> 8) & 0x0F); // section_syntax_indicator + section_length
  packet[7] = 13 & 0xFF;
  packet[8] = 0x00; // transport_stream_id
  packet[9] = 0x01;
  packet[10] = 0xC1; // version + current_next
  packet[11] = 0x00; // section_number
  packet[12] = 0x00; // last_section_number

  // Program entry
  packet[13] = (programNumber >> 8) & 0xFF;
  packet[14] = programNumber & 0xFF;
  packet[15] = 0xE0 | ((pmtPid >> 8) & 0x1F);
  packet[16] = pmtPid & 0xFF;

  // CRC32 (simplified - just fill with 0xFF)
  packet[17] = 0xFF;
  packet[18] = 0xFF;
  packet[19] = 0xFF;
  packet[20] = 0xFF;

  // Fill rest with 0xFF
  for (var i = 21; i < 188; i++) {
    packet[i] = 0xFF;
  }

  return packet;
}

/// Creates a PMT packet.
Uint8List _createPmtPacket({required int videoPid, required int videoStreamType}) {
  final packet = Uint8List(188);

  // Header
  packet[0] = 0x47;
  packet[1] = 0x50; // PUSI + PID high bits
  packet[2] = 0x00; // PID = 0x1000
  packet[3] = 0x10;

  // Pointer field
  packet[4] = 0x00;

  // PMT table
  packet[5] = 0x02; // table_id = PMT
  packet[6] = 0x80 | ((18 >> 8) & 0x0F);
  packet[7] = 18 & 0xFF;
  packet[8] = 0x00; // program_number
  packet[9] = 0x01;
  packet[10] = 0xC1;
  packet[11] = 0x00;
  packet[12] = 0x00;
  packet[13] = 0xE0 | ((videoPid >> 8) & 0x1F); // PCR PID
  packet[14] = videoPid & 0xFF;
  packet[15] = 0xF0; // program_info_length
  packet[16] = 0x00;

  // Stream entry
  packet[17] = videoStreamType;
  packet[18] = 0xE0 | ((videoPid >> 8) & 0x1F);
  packet[19] = videoPid & 0xFF;
  packet[20] = 0xF0;
  packet[21] = 0x00;

  // CRC32
  for (var i = 22; i < 26; i++) {
    packet[i] = 0xFF;
  }

  // Fill rest
  for (var i = 26; i < 188; i++) {
    packet[i] = 0xFF;
  }

  return packet;
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
