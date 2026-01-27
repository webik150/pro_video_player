import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/src/container/ts_parser.dart';
import 'package:pro_video_player_platform_interface/src/types/container_track_type.dart';

void main() {
  group('TsParser', () {
    group('format detection', () {
      test('detects valid TS by sync byte 0x47', () {
        // Minimal TS packet: sync byte + 187 bytes
        final data = Uint8List(188);
        data[0] = 0x47; // Sync byte
        expect(TsParser.isValidTs(data), isTrue);
      });

      test('detects TS with multiple sync bytes at 188-byte intervals', () {
        final data = Uint8List(188 * 3);
        data[0] = 0x47;
        data[188] = 0x47;
        data[376] = 0x47;
        expect(TsParser.isValidTs(data), isTrue);
      });

      test('rejects data without sync byte', () {
        final data = Uint8List(188);
        data[0] = 0x00;
        expect(TsParser.isValidTs(data), isFalse);
      });

      test('rejects data too short for TS packet', () {
        final data = Uint8List(100);
        data[0] = 0x47;
        expect(TsParser.isValidTs(data), isFalse);
      });

      test('detects 192-byte TS packets (with timestamp)', () {
        final data = Uint8List(192 * 2);
        // 4-byte timestamp prefix, then sync byte
        data[4] = 0x47;
        data[196] = 0x47;
        expect(TsParser.isValidTs(data), isTrue);
      });

      test('detectFormat returns ts for valid data', () {
        final data = Uint8List(188);
        data[0] = 0x47;
        expect(TsParser.detectFormat(data), equals('ts'));
      });

      test('detectFormat returns null for invalid data', () {
        final data = Uint8List(188);
        data[0] = 0x00;
        expect(TsParser.detectFormat(data), isNull);
      });
    });

    group('PAT parsing', () {
      test('extracts PMT PID from PAT', () {
        final data = _createTsWithPat(pmtPid: 0x100);
        final result = TsParser.parse(data);
        expect(result, isNotNull);
        expect(result!.format, equals('ts'));
      });

      test('handles PAT with multiple programs', () {
        final data = _createTsWithPat(pmtPid: 0x100, programCount: 2);
        final result = TsParser.parse(data);
        expect(result, isNotNull);
      });
    });

    group('PMT parsing', () {
      test('extracts video track from PMT', () {
        final data = _createTsWithPatAndPmt(pmtPid: 0x100, streams: [(pid: 0x101, type: TsStreamType.h264)]);
        final result = TsParser.parse(data);

        expect(result, isNotNull);
        expect(result!.tracks.length, equals(1));
        expect(result.tracks[0].type, equals(ContainerTrackType.video));
        expect(result.tracks[0].codec.name, equals('H.264'));
      });

      test('extracts audio track from PMT', () {
        final data = _createTsWithPatAndPmt(pmtPid: 0x100, streams: [(pid: 0x102, type: TsStreamType.aac)]);
        final result = TsParser.parse(data);

        expect(result, isNotNull);
        expect(result!.tracks.length, equals(1));
        expect(result.tracks[0].type, equals(ContainerTrackType.audio));
        expect(result.tracks[0].codec.name, equals('AAC'));
      });

      test('extracts multiple tracks from PMT', () {
        final data = _createTsWithPatAndPmt(
          pmtPid: 0x100,
          streams: [
            (pid: 0x101, type: TsStreamType.h264),
            (pid: 0x102, type: TsStreamType.aac),
            (pid: 0x103, type: TsStreamType.ac3),
          ],
        );
        final result = TsParser.parse(data);

        expect(result, isNotNull);
        expect(result!.tracks.length, equals(3));
        expect(result.tracks[0].type, equals(ContainerTrackType.video));
        expect(result.tracks[1].type, equals(ContainerTrackType.audio));
        expect(result.tracks[2].type, equals(ContainerTrackType.audio));
      });

      test('extracts HEVC video track', () {
        final data = _createTsWithPatAndPmt(pmtPid: 0x100, streams: [(pid: 0x101, type: TsStreamType.hevc)]);
        final result = TsParser.parse(data);

        expect(result, isNotNull);
        expect(result!.tracks[0].codec.name, equals('HEVC'));
        expect(result.tracks[0].codec.fourcc, equals('hvc1'));
      });

      test('extracts MPEG-2 video track', () {
        final data = _createTsWithPatAndPmt(pmtPid: 0x100, streams: [(pid: 0x101, type: TsStreamType.mpeg2Video)]);
        final result = TsParser.parse(data);

        expect(result, isNotNull);
        expect(result!.tracks[0].codec.name, equals('MPEG-2'));
      });

      test('extracts MP3 audio track', () {
        final data = _createTsWithPatAndPmt(pmtPid: 0x100, streams: [(pid: 0x102, type: TsStreamType.mp3)]);
        final result = TsParser.parse(data);

        expect(result, isNotNull);
        expect(result!.tracks[0].codec.name, equals('MP3'));
      });

      test('extracts AC-3 audio track', () {
        final data = _createTsWithPatAndPmt(pmtPid: 0x100, streams: [(pid: 0x102, type: TsStreamType.ac3)]);
        final result = TsParser.parse(data);

        expect(result, isNotNull);
        expect(result!.tracks[0].codec.name, equals('AC-3'));
      });

      test('extracts E-AC-3 audio track', () {
        final data = _createTsWithPatAndPmt(pmtPid: 0x100, streams: [(pid: 0x102, type: TsStreamType.eac3)]);
        final result = TsParser.parse(data);

        expect(result, isNotNull);
        expect(result!.tracks[0].codec.name, equals('E-AC-3'));
      });

      test('extracts subtitle track', () {
        final data = _createTsWithPatAndPmt(pmtPid: 0x100, streams: [(pid: 0x103, type: TsStreamType.dvbSubtitle)]);
        final result = TsParser.parse(data);

        expect(result, isNotNull);
        expect(result!.tracks[0].type, equals(ContainerTrackType.subtitle));
      });
    });

    group('stream type mapping', () {
      test('maps all known video stream types', () {
        expect(TsParser.mapStreamTypeToCodec(TsStreamType.mpeg1Video).name, equals('MPEG-1'));
        expect(TsParser.mapStreamTypeToCodec(TsStreamType.mpeg2Video).name, equals('MPEG-2'));
        expect(TsParser.mapStreamTypeToCodec(TsStreamType.h264).name, equals('H.264'));
        expect(TsParser.mapStreamTypeToCodec(TsStreamType.hevc).name, equals('HEVC'));
        expect(TsParser.mapStreamTypeToCodec(TsStreamType.vp9).name, equals('VP9'));
        expect(TsParser.mapStreamTypeToCodec(TsStreamType.av1).name, equals('AV1'));
      });

      test('maps all known audio stream types', () {
        expect(TsParser.mapStreamTypeToCodec(TsStreamType.mpeg1Audio).name, equals('MP1'));
        expect(TsParser.mapStreamTypeToCodec(TsStreamType.mp3).name, equals('MP3'));
        expect(TsParser.mapStreamTypeToCodec(TsStreamType.aac).name, equals('AAC'));
        expect(TsParser.mapStreamTypeToCodec(TsStreamType.ac3).name, equals('AC-3'));
        expect(TsParser.mapStreamTypeToCodec(TsStreamType.eac3).name, equals('E-AC-3'));
        expect(TsParser.mapStreamTypeToCodec(TsStreamType.dts).name, equals('DTS'));
        expect(TsParser.mapStreamTypeToCodec(TsStreamType.opus).name, equals('Opus'));
      });

      test('maps subtitle stream types', () {
        expect(TsParser.mapStreamTypeToCodec(TsStreamType.dvbSubtitle).name, equals('DVB Subtitle'));
        expect(TsParser.mapStreamTypeToCodec(TsStreamType.teletext).name, equals('Teletext'));
      });

      test('returns unknown for unmapped stream types', () {
        expect(TsParser.mapStreamTypeToCodec(0xFF).name, equals('Unknown'));
      });
    });

    group('track type detection', () {
      test('identifies video stream types', () {
        expect(TsParser.getTrackType(TsStreamType.mpeg1Video), equals(ContainerTrackType.video));
        expect(TsParser.getTrackType(TsStreamType.mpeg2Video), equals(ContainerTrackType.video));
        expect(TsParser.getTrackType(TsStreamType.h264), equals(ContainerTrackType.video));
        expect(TsParser.getTrackType(TsStreamType.hevc), equals(ContainerTrackType.video));
      });

      test('identifies audio stream types', () {
        expect(TsParser.getTrackType(TsStreamType.mpeg1Audio), equals(ContainerTrackType.audio));
        expect(TsParser.getTrackType(TsStreamType.mp3), equals(ContainerTrackType.audio));
        expect(TsParser.getTrackType(TsStreamType.aac), equals(ContainerTrackType.audio));
        expect(TsParser.getTrackType(TsStreamType.ac3), equals(ContainerTrackType.audio));
      });

      test('identifies subtitle stream types', () {
        expect(TsParser.getTrackType(TsStreamType.dvbSubtitle), equals(ContainerTrackType.subtitle));
        expect(TsParser.getTrackType(TsStreamType.teletext), equals(ContainerTrackType.subtitle));
      });
    });

    group('edge cases', () {
      test('returns null for empty data', () {
        expect(TsParser.parse(Uint8List(0)), isNull);
      });

      test('returns null for data without PAT', () {
        // Just a sync byte, no PAT
        final data = Uint8List(188);
        data[0] = 0x47;
        expect(TsParser.parse(data), isNull);
      });

      test('handles TS with only PAT (no PMT)', () {
        final data = _createTsWithPat(pmtPid: 0x100);
        final result = TsParser.parse(data);
        // Should return metadata but with no tracks
        expect(result, isNotNull);
        expect(result!.tracks, isEmpty);
      });

      test('skips null packets (PID 0x1FFF)', () {
        final data = _createTsWithPatAndPmt(
          pmtPid: 0x100,
          streams: [(pid: 0x101, type: TsStreamType.h264)],
          includeNullPackets: true,
        );
        final result = TsParser.parse(data);
        expect(result, isNotNull);
        expect(result!.tracks.length, equals(1));
      });
    });
  });
}

// Test data helpers

/// Creates a TS packet with PAT (Program Association Table)
Uint8List _createTsWithPat({required int pmtPid, int programCount = 1}) {
  final packets = <Uint8List>[];

  // Create PAT packet
  packets.add(_createPatPacket(pmtPid: pmtPid, programCount: programCount));

  return _concatenatePackets(packets);
}

/// Creates TS with both PAT and PMT
Uint8List _createTsWithPatAndPmt({
  required int pmtPid,
  required List<({int pid, int type})> streams,
  bool includeNullPackets = false,
}) {
  final packets = <Uint8List>[];

  // PAT packet
  packets.add(_createPatPacket(pmtPid: pmtPid));

  // Optional null packet
  if (includeNullPackets) {
    packets.add(_createNullPacket());
  }

  // PMT packet
  packets.add(_createPmtPacket(pmtPid: pmtPid, streams: streams));

  return _concatenatePackets(packets);
}

/// Creates a PAT packet
Uint8List _createPatPacket({required int pmtPid, int programCount = 1}) {
  final packet = Uint8List(188);
  var offset = 0;

  // TS header (4 bytes)
  packet[offset++] = 0x47; // Sync byte
  packet[offset++] = 0x40; // PUSI=1, PID high bits = 0
  packet[offset++] = 0x00; // PID low bits = 0 (PAT PID)
  packet[offset++] = 0x10; // No adaptation field, has payload

  // Pointer field (1 byte)
  packet[offset++] = 0x00;

  // PAT section header
  packet[offset++] = 0x00; // Table ID = 0 (PAT)
  final sectionLength = 5 + (programCount * 4) + 4; // header + programs + CRC
  packet[offset++] = 0xB0 | ((sectionLength >> 8) & 0x0F); // Section syntax + length high
  packet[offset++] = sectionLength & 0xFF; // Section length low
  packet[offset++] = 0x00; // Transport stream ID high
  packet[offset++] = 0x01; // Transport stream ID low
  packet[offset++] = 0xC1; // Version=0, current=1
  packet[offset++] = 0x00; // Section number
  packet[offset++] = 0x00; // Last section number

  // Program entries
  for (var i = 0; i < programCount; i++) {
    final programNum = i + 1;
    packet[offset++] = (programNum >> 8) & 0xFF; // Program number high
    packet[offset++] = programNum & 0xFF; // Program number low
    packet[offset++] = 0xE0 | ((pmtPid >> 8) & 0x1F); // Reserved + PMT PID high
    packet[offset++] = pmtPid & 0xFF; // PMT PID low
  }

  // CRC32 (placeholder - not validated in our parser)
  packet[offset++] = 0x00;
  packet[offset++] = 0x00;
  packet[offset++] = 0x00;
  packet[offset++] = 0x00;

  // Fill rest with 0xFF (stuffing)
  for (var i = offset; i < 188; i++) {
    packet[i] = 0xFF;
  }

  return packet;
}

/// Creates a PMT packet
Uint8List _createPmtPacket({required int pmtPid, required List<({int pid, int type})> streams}) {
  final packet = Uint8List(188);
  var offset = 0;

  // TS header (4 bytes)
  packet[offset++] = 0x47; // Sync byte
  packet[offset++] = 0x40 | ((pmtPid >> 8) & 0x1F); // PUSI=1, PID high bits
  packet[offset++] = pmtPid & 0xFF; // PID low bits
  packet[offset++] = 0x10; // No adaptation field, has payload

  // Pointer field (1 byte)
  packet[offset++] = 0x00;

  // PMT section header
  packet[offset++] = 0x02; // Table ID = 2 (PMT)
  final sectionLength = 9 + (streams.length * 5) + 4; // header + streams + CRC
  packet[offset++] = 0xB0 | ((sectionLength >> 8) & 0x0F); // Section syntax + length high
  packet[offset++] = sectionLength & 0xFF; // Section length low
  packet[offset++] = 0x00; // Program number high
  packet[offset++] = 0x01; // Program number low
  packet[offset++] = 0xC1; // Version=0, current=1
  packet[offset++] = 0x00; // Section number
  packet[offset++] = 0x00; // Last section number
  packet[offset++] = 0xE0; // Reserved + PCR PID high
  packet[offset++] = 0x00; // PCR PID low (none)
  packet[offset++] = 0xF0; // Reserved + program info length high
  packet[offset++] = 0x00; // Program info length low (no descriptors)

  // Stream entries
  for (final stream in streams) {
    packet[offset++] = stream.type; // Stream type
    packet[offset++] = 0xE0 | ((stream.pid >> 8) & 0x1F); // Reserved + PID high
    packet[offset++] = stream.pid & 0xFF; // PID low
    packet[offset++] = 0xF0; // Reserved + ES info length high
    packet[offset++] = 0x00; // ES info length low (no descriptors)
  }

  // CRC32 (placeholder)
  packet[offset++] = 0x00;
  packet[offset++] = 0x00;
  packet[offset++] = 0x00;
  packet[offset++] = 0x00;

  // Fill rest with 0xFF
  for (var i = offset; i < 188; i++) {
    packet[i] = 0xFF;
  }

  return packet;
}

/// Creates a null packet (PID 0x1FFF)
Uint8List _createNullPacket() {
  final packet = Uint8List(188);
  packet[0] = 0x47; // Sync byte
  packet[1] = 0x1F; // PID high bits (0x1FFF)
  packet[2] = 0xFF; // PID low bits
  packet[3] = 0x10; // No adaptation, has payload
  // Rest is padding
  return packet;
}

Uint8List _concatenatePackets(List<Uint8List> packets) {
  final totalLength = packets.fold<int>(0, (sum, p) => sum + p.length);
  final result = Uint8List(totalLength);
  var offset = 0;
  for (final packet in packets) {
    result.setRange(offset, offset + packet.length, packet);
    offset += packet.length;
  }
  return result;
}
