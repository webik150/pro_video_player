import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/ts_packet_writer.dart';

void main() {
  group('TsPacketWriter', () {
    group('constants', () {
      test('has correct packet size', () {
        expect(TsPacketWriter.packetSize, equals(188));
      });

      test('has correct sync byte', () {
        expect(TsPacketWriter.syncByte, equals(0x47));
      });

      test('has correct PIDs', () {
        expect(TsPacketWriter.patPid, equals(0x0000));
        expect(TsPacketWriter.pmtPid, equals(0x1000));
        expect(TsPacketWriter.videoPid, equals(0x0100));
        expect(TsPacketWriter.audioPid, equals(0x0101));
      });

      test('has correct stream types', () {
        expect(TsPacketWriter.streamTypeAvc, equals(0x1B));
        expect(TsPacketWriter.streamTypeHevc, equals(0x24));
        expect(TsPacketWriter.streamTypeAacAdts, equals(0x0F));
        expect(TsPacketWriter.streamTypeAc3, equals(0x81));
      });
    });

    group('writePat', () {
      test('writes 188-byte packet', () {
        final packet = TsPacketWriter.writePat();
        expect(packet.length, equals(188));
      });

      test('starts with sync byte', () {
        final packet = TsPacketWriter.writePat();
        expect(packet[0], equals(0x47));
      });

      test('has correct PID (0x0000)', () {
        final packet = TsPacketWriter.writePat();
        // PID is in bytes 1-2 (bits 4-0 of byte 1, all of byte 2)
        final pidHigh = packet[1] & 0x1F;
        final pidLow = packet[2];
        final pid = (pidHigh << 8) | pidLow;
        expect(pid, equals(0x0000));
      });

      test('has payload unit start indicator set', () {
        final packet = TsPacketWriter.writePat();
        expect(packet[1] & 0x40, equals(0x40));
      });

      test('has correct continuity counter', () {
        final packet0 = TsPacketWriter.writePat();
        final packet5 = TsPacketWriter.writePat(continuityCounter: 5);
        final packet15 = TsPacketWriter.writePat(continuityCounter: 15);

        expect(packet0[3] & 0x0F, equals(0));
        expect(packet5[3] & 0x0F, equals(5));
        expect(packet15[3] & 0x0F, equals(15));
      });

      test('has PAT table_id (0x00)', () {
        final packet = TsPacketWriter.writePat();
        // Pointer field at byte 4, table_id at byte 5
        expect(packet[5], equals(0x00));
      });

      test('uses custom PMT PID', () {
        // Use 0x1234 (4660) which is within valid 13-bit PID range (0-8191)
        final packet = TsPacketWriter.writePat(pmtPid: 0x1234);
        // PMT PID is in the program entry
        // After header (4) + pointer (1) + table_id (1) + section length (2) +
        // transport_stream_id (2) + flags (1) + section/last section (2) +
        // program_number (2) = byte 15
        final pmtPidHigh = packet[15] & 0x1F;
        final pmtPidLow = packet[16];
        final pmtPid = (pmtPidHigh << 8) | pmtPidLow;
        expect(pmtPid, equals(0x1234));
      });

      test('includes CRC32', () {
        final packet = TsPacketWriter.writePat();
        // CRC32 should be non-zero for valid data
        // It appears after the PAT section data
        // Check that the packet has non-padding data beyond the basic PAT
        final nonPaddingEnd = packet.lastIndexWhere((b) => b != 0xFF);
        expect(nonPaddingEnd, greaterThan(16)); // Should have CRC after section
      });
    });

    group('writePmt', () {
      test('writes 188-byte packet', () {
        final streams = [const TsStreamInfo(streamType: TsPacketWriter.streamTypeAvc, pid: TsPacketWriter.videoPid)];
        final packet = TsPacketWriter.writePmt(streams: streams);
        expect(packet.length, equals(188));
      });

      test('starts with sync byte', () {
        final streams = [const TsStreamInfo(streamType: TsPacketWriter.streamTypeAvc, pid: TsPacketWriter.videoPid)];
        final packet = TsPacketWriter.writePmt(streams: streams);
        expect(packet[0], equals(0x47));
      });

      test('has correct default PMT PID (0x1000)', () {
        final streams = [const TsStreamInfo(streamType: TsPacketWriter.streamTypeAvc, pid: TsPacketWriter.videoPid)];
        final packet = TsPacketWriter.writePmt(streams: streams);
        final pidHigh = packet[1] & 0x1F;
        final pidLow = packet[2];
        final pid = (pidHigh << 8) | pidLow;
        expect(pid, equals(0x1000));
      });

      test('has PMT table_id (0x02)', () {
        final streams = [const TsStreamInfo(streamType: TsPacketWriter.streamTypeAvc, pid: TsPacketWriter.videoPid)];
        final packet = TsPacketWriter.writePmt(streams: streams);
        expect(packet[5], equals(0x02));
      });

      test('includes video stream entry', () {
        final streams = [const TsStreamInfo(streamType: TsPacketWriter.streamTypeAvc, pid: TsPacketWriter.videoPid)];
        final packet = TsPacketWriter.writePmt(streams: streams);

        // Find stream type 0x1B (AVC) in the packet
        var foundAvc = false;
        for (var i = 0; i < packet.length - 1; i++) {
          if (packet[i] == 0x1B) {
            foundAvc = true;
            break;
          }
        }
        expect(foundAvc, isTrue);
      });

      test('includes audio stream entry', () {
        final streams = [
          const TsStreamInfo(streamType: TsPacketWriter.streamTypeAvc, pid: TsPacketWriter.videoPid),
          const TsStreamInfo(streamType: TsPacketWriter.streamTypeAacAdts, pid: TsPacketWriter.audioPid),
        ];
        final packet = TsPacketWriter.writePmt(streams: streams);

        // Find stream type 0x0F (AAC) in the packet
        var foundAac = false;
        for (var i = 0; i < packet.length - 1; i++) {
          if (packet[i] == 0x0F) {
            foundAac = true;
            break;
          }
        }
        expect(foundAac, isTrue);
      });
    });

    group('writePesHeader', () {
      test('creates valid header with PTS only', () {
        final header = TsPacketWriter.writePesHeader(streamId: PesStreamId.video(0), dataLength: 1000, pts: 90000);

        expect(header.length, equals(14)); // 9 base + 5 for PTS
        // Start code prefix
        expect(header[0], equals(0x00));
        expect(header[1], equals(0x00));
        expect(header[2], equals(0x01));
        // Stream ID
        expect(header[3], equals(0xE0)); // video stream 0
      });

      test('creates valid header with PTS and DTS', () {
        final header = TsPacketWriter.writePesHeader(
          streamId: PesStreamId.video(0),
          dataLength: 1000,
          pts: 90000,
          dts: 80000,
        );

        expect(header.length, equals(19)); // 9 base + 5 for PTS + 5 for DTS
      });

      test('creates header without timestamps', () {
        final header = TsPacketWriter.writePesHeader(streamId: PesStreamId.audio(0), dataLength: 500);

        expect(header.length, equals(9)); // 9 base only
      });

      test('sets PTS flag when PTS provided', () {
        final header = TsPacketWriter.writePesHeader(streamId: PesStreamId.video(0), dataLength: 1000, pts: 90000);

        // Byte 7 contains PTS/DTS flags
        expect(header[7] & 0x80, equals(0x80)); // PTS flag
        expect(header[7] & 0x40, equals(0x00)); // DTS flag not set
      });

      test('sets both flags when PTS and DTS provided', () {
        final header = TsPacketWriter.writePesHeader(
          streamId: PesStreamId.video(0),
          dataLength: 1000,
          pts: 90000,
          dts: 80000,
        );

        expect(header[7] & 0xC0, equals(0xC0)); // Both flags set
      });
    });

    group('packetize', () {
      test('creates single packet for small data', () {
        final data = Uint8List(100);
        final packets = TsPacketWriter.packetize(
          pid: TsPacketWriter.videoPid,
          data: data,
          isPayloadStart: true,
          continuityCounter: 0,
        );

        expect(packets.length, equals(1));
        expect(packets[0].length, equals(188));
      });

      test('creates multiple packets for large data', () {
        final data = Uint8List(500); // More than one packet can hold
        final packets = TsPacketWriter.packetize(
          pid: TsPacketWriter.videoPid,
          data: data,
          isPayloadStart: true,
          continuityCounter: 0,
        );

        expect(packets.length, greaterThan(1));
        for (final packet in packets) {
          expect(packet.length, equals(188));
        }
      });

      test('sets payload unit start indicator on first packet only', () {
        final data = Uint8List(500);
        final packets = TsPacketWriter.packetize(
          pid: TsPacketWriter.videoPid,
          data: data,
          isPayloadStart: true,
          continuityCounter: 0,
        );

        // First packet should have PUSI set
        expect(packets[0][1] & 0x40, equals(0x40));
        // Subsequent packets should not
        if (packets.length > 1) {
          expect(packets[1][1] & 0x40, equals(0x00));
        }
      });

      test('increments continuity counter', () {
        final data = Uint8List(500);
        final packets = TsPacketWriter.packetize(
          pid: TsPacketWriter.videoPid,
          data: data,
          isPayloadStart: true,
          continuityCounter: 5,
        );

        expect(packets[0][3] & 0x0F, equals(5));
        if (packets.length > 1) {
          expect(packets[1][3] & 0x0F, equals(6));
        }
        if (packets.length > 2) {
          expect(packets[2][3] & 0x0F, equals(7));
        }
      });

      test('wraps continuity counter at 15', () {
        final data = Uint8List(500);
        final packets = TsPacketWriter.packetize(
          pid: TsPacketWriter.videoPid,
          data: data,
          isPayloadStart: true,
          continuityCounter: 14,
        );

        expect(packets[0][3] & 0x0F, equals(14));
        if (packets.length > 1) {
          expect(packets[1][3] & 0x0F, equals(15));
        }
        if (packets.length > 2) {
          expect(packets[2][3] & 0x0F, equals(0)); // Wrapped
        }
      });

      test('includes PCR when provided', () {
        final data = Uint8List(100);
        final packets = TsPacketWriter.packetize(
          pid: TsPacketWriter.videoPid,
          data: data,
          isPayloadStart: true,
          continuityCounter: 0,
          pcr: 90000,
        );

        expect(packets.length, equals(1));
        // Adaptation field control should indicate adaptation field present
        expect(packets[0][3] & 0x30, equals(0x30)); // Both adaptation and payload
      });

      test('sets correct PID', () {
        final data = Uint8List(100);

        final videoPackets = TsPacketWriter.packetize(
          pid: TsPacketWriter.videoPid,
          data: data,
          isPayloadStart: true,
          continuityCounter: 0,
        );

        final audioPackets = TsPacketWriter.packetize(
          pid: TsPacketWriter.audioPid,
          data: data,
          isPayloadStart: true,
          continuityCounter: 0,
        );

        // Extract PIDs
        final videoPid = ((videoPackets[0][1] & 0x1F) << 8) | videoPackets[0][2];
        final audioPid = ((audioPackets[0][1] & 0x1F) << 8) | audioPackets[0][2];

        expect(videoPid, equals(TsPacketWriter.videoPid));
        expect(audioPid, equals(TsPacketWriter.audioPid));
      });
    });

    group('convertAvcToAnnexB', () {
      test('converts single NAL unit', () {
        // Create AVC data with 4-byte length prefix
        final avcData = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x05, // Length = 5
          0x65, 0x01, 0x02, 0x03, 0x04, // NAL unit (IDR slice)
        ]);

        final annexB = TsPacketWriter.convertAvcToAnnexB(avcData, 4);

        // Should have start code + NAL data
        expect(annexB.length, equals(9)); // 4 start code + 5 NAL
        expect(annexB[0], equals(0x00));
        expect(annexB[1], equals(0x00));
        expect(annexB[2], equals(0x00));
        expect(annexB[3], equals(0x01));
        expect(annexB[4], equals(0x65)); // NAL type
      });

      test('converts multiple NAL units', () {
        // Create AVC data with two NAL units
        final avcData = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x03, // Length = 3
          0x67, 0xAA, 0xBB, // SPS
          0x00, 0x00, 0x00, 0x02, // Length = 2
          0x68, 0xCC, // PPS
        ]);

        final annexB = TsPacketWriter.convertAvcToAnnexB(avcData, 4);

        // Should have two start codes
        expect(annexB.length, equals(13)); // 4+3 + 4+2
        // First NAL
        expect(annexB.sublist(0, 4), equals([0x00, 0x00, 0x00, 0x01]));
        expect(annexB[4], equals(0x67));
        // Second NAL
        expect(annexB.sublist(7, 11), equals([0x00, 0x00, 0x00, 0x01]));
        expect(annexB[11], equals(0x68));
      });

      test('handles empty input', () {
        final annexB = TsPacketWriter.convertAvcToAnnexB(Uint8List(0), 4);
        expect(annexB.length, equals(0));
      });

      test('handles different NAL length sizes', () {
        // 2-byte length prefix
        final avcData2 = Uint8List.fromList([
          0x00, 0x03, // Length = 3
          0x65, 0x01, 0x02,
        ]);
        final annexB2 = TsPacketWriter.convertAvcToAnnexB(avcData2, 2);
        expect(annexB2.length, equals(7)); // 4 + 3
        expect(annexB2[4], equals(0x65));

        // 1-byte length prefix
        final avcData1 = Uint8List.fromList([
          0x03, // Length = 3
          0x65, 0x01, 0x02,
        ]);
        final annexB1 = TsPacketWriter.convertAvcToAnnexB(avcData1, 1);
        expect(annexB1.length, equals(7)); // 4 + 3
      });
    });

    group('createAdtsHeader', () {
      test('creates 7-byte header', () {
        final header = TsPacketWriter.createAdtsHeader(sampleRate: 44100, channelCount: 2, frameLength: 100);

        expect(header.length, equals(7));
      });

      test('starts with ADTS syncword', () {
        final header = TsPacketWriter.createAdtsHeader(sampleRate: 44100, channelCount: 2, frameLength: 100);

        // Syncword is 0xFFF (12 bits)
        expect(header[0], equals(0xFF));
        expect(header[1] & 0xF0, equals(0xF0));
      });

      test('sets MPEG-4 flag', () {
        final header = TsPacketWriter.createAdtsHeader(sampleRate: 44100, channelCount: 2, frameLength: 100);

        // ID bit (bit 3 of byte 1): 0 = MPEG-4
        expect(header[1] & 0x08, equals(0x00));
      });

      test('encodes frame length correctly', () {
        final header = TsPacketWriter.createAdtsHeader(sampleRate: 44100, channelCount: 2, frameLength: 100);

        // Frame length includes header (7 bytes), so total = 107
        final frameLength = ((header[3] & 0x03) << 11) | (header[4] << 3) | ((header[5] & 0xE0) >> 5);
        expect(frameLength, equals(107));
      });

      test('handles different sample rates', () {
        // 48000 Hz - index 3
        final header48k = TsPacketWriter.createAdtsHeader(sampleRate: 48000, channelCount: 2, frameLength: 100);

        // 44100 Hz - index 4
        final header44k = TsPacketWriter.createAdtsHeader(sampleRate: 44100, channelCount: 2, frameLength: 100);

        // Sample rate index is bits 2-5 of byte 2
        final index48k = (header48k[2] >> 2) & 0x0F;
        final index44k = (header44k[2] >> 2) & 0x0F;

        expect(index48k, equals(3));
        expect(index44k, equals(4));
      });

      test('handles different channel counts', () {
        final headerMono = TsPacketWriter.createAdtsHeader(sampleRate: 44100, channelCount: 1, frameLength: 100);
        final headerStereo = TsPacketWriter.createAdtsHeader(sampleRate: 44100, channelCount: 2, frameLength: 100);
        final header51 = TsPacketWriter.createAdtsHeader(sampleRate: 44100, channelCount: 6, frameLength: 100);

        // Channel config is bit 0 of byte 2 + bits 6-7 of byte 3
        int getChannelConfig(Uint8List h) => ((h[2] & 0x01) << 2) | ((h[3] & 0xC0) >> 6);

        expect(getChannelConfig(headerMono), equals(1));
        expect(getChannelConfig(headerStereo), equals(2));
        expect(getChannelConfig(header51), equals(6));
      });
    });
  });

  group('TsStreamInfo', () {
    test('stores stream type and PID', () {
      const info = TsStreamInfo(streamType: 0x1B, pid: 0x0100);

      expect(info.streamType, equals(0x1B));
      expect(info.pid, equals(0x0100));
    });
  });

  group('PesStreamId', () {
    test('has correct private stream ID', () {
      expect(PesStreamId.privateStream1, equals(0xBD));
    });

    test('generates audio stream IDs correctly', () {
      expect(PesStreamId.audio(0), equals(0xC0));
      expect(PesStreamId.audio(1), equals(0xC1));
      expect(PesStreamId.audio(31), equals(0xDF));
    });

    test('generates video stream IDs correctly', () {
      expect(PesStreamId.video(0), equals(0xE0));
      expect(PesStreamId.video(1), equals(0xE1));
      expect(PesStreamId.video(15), equals(0xEF));
    });

    test('wraps audio stream index', () {
      // Index 32 should wrap to 0
      expect(PesStreamId.audio(32), equals(0xC0));
    });

    test('wraps video stream index', () {
      // Index 16 should wrap to 0
      expect(PesStreamId.video(16), equals(0xE0));
    });
  });
}
