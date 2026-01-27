import 'dart:typed_data';

import '../types/codec_info.dart';
import '../types/container_metadata.dart';
import '../types/container_track.dart';
import '../types/container_track_type.dart';

/// MPEG-TS stream type constants.
///
/// These are the stream_type values used in the PMT (Program Map Table)
/// to identify the codec/format of each elementary stream.
class TsStreamType {
  TsStreamType._();

  // Video stream types
  /// MPEG-1 Video (ISO/IEC 11172-2)
  static const int mpeg1Video = 0x01;

  /// MPEG-2 Video (ISO/IEC 13818-2)
  static const int mpeg2Video = 0x02;

  /// H.264/AVC (ISO/IEC 14496-10)
  static const int h264 = 0x1B;

  /// H.265/HEVC (ISO/IEC 23008-2)
  static const int hevc = 0x24;

  /// VP9 (in TS container)
  static const int vp9 = 0xC0; // Non-standard, used by some encoders

  /// AV1 (in TS container)
  static const int av1 = 0xC1; // Non-standard

  // Audio stream types
  /// MPEG-1 Audio Layer I/II (ISO/IEC 11172-3)
  static const int mpeg1Audio = 0x03;

  /// MPEG-2 Audio / MP3 (ISO/IEC 13818-3)
  static const int mp3 = 0x04;

  /// AAC ADTS (ISO/IEC 13818-7)
  static const int aac = 0x0F;

  /// AAC LATM (ISO/IEC 14496-3)
  static const int aacLatm = 0x11;

  /// AC-3 / Dolby Digital (ATSC A/52)
  static const int ac3 = 0x81;

  /// E-AC-3 / Dolby Digital Plus
  static const int eac3 = 0x87;

  /// DTS (Digital Theater Systems)
  static const int dts = 0x82;

  /// DTS-HD
  static const int dtsHd = 0x85;

  /// TrueHD
  static const int trueHd = 0x83;

  /// Opus (in TS container)
  static const int opus = 0xC2; // Non-standard

  // Subtitle/data stream types
  /// DVB Subtitles
  static const int dvbSubtitle = 0x06;

  /// Teletext
  static const int teletext = 0x56;

  /// SCTE-27 (Closed Captions)
  static const int scte27 = 0x05;

  /// Private data (often used for subtitles)
  static const int privateData = 0x06;
}

/// Parser for MPEG Transport Stream (TS) container files.
///
/// Extracts metadata from TS files including:
/// - Format detection
/// - Track information from PAT/PMT tables
/// - Codec identification
///
/// Example:
/// ```dart
/// final metadata = TsParser.parse(bytes);
/// if (metadata != null) {
///   print('Format: ${metadata.format}');
///   for (final track in metadata.tracks) {
///     print('Track ${track.id}: ${track.codec.name}');
///   }
/// }
/// ```
class TsParser {
  TsParser._();

  /// Standard TS packet size (188 bytes).
  static const int packetSize = 188;

  /// TS packet size with timestamp prefix (192 bytes).
  static const int packetSizeWithTimestamp = 192;

  /// TS sync byte value (0x47 = 'G').
  static const int syncByte = 0x47;

  /// PAT PID (Program Association Table).
  static const int patPid = 0x0000;

  /// Null packet PID (stuffing).
  static const int nullPid = 0x1FFF;

  /// PAT table ID.
  static const int patTableId = 0x00;

  /// PMT table ID.
  static const int pmtTableId = 0x02;

  /// Checks if the data is a valid TS stream.
  ///
  /// Validates by checking for sync bytes at expected packet intervals.
  static bool isValidTs(Uint8List data) {
    if (data.length < packetSize) return false;

    // Check for standard 188-byte packets
    if (data[0] == syncByte) {
      // Verify sync bytes at packet boundaries
      if (data.length >= packetSize * 2) {
        if (data[packetSize] != syncByte) return false;
      }
      return true;
    }

    // Check for 192-byte packets (4-byte timestamp prefix)
    if (data.length >= packetSizeWithTimestamp && data[4] == syncByte) {
      if (data.length >= packetSizeWithTimestamp * 2) {
        if (data[packetSizeWithTimestamp + 4] != syncByte) return false;
      }
      return true;
    }

    return false;
  }

  /// Detects if data is a TS stream and returns format string.
  static String? detectFormat(Uint8List data) => isValidTs(data) ? 'ts' : null;

  /// Parses TS container metadata from bytes.
  ///
  /// Returns null if the data is not a valid TS stream or lacks PAT/PMT.
  static ContainerMetadata? parse(Uint8List data) {
    if (!isValidTs(data)) return null;

    // Determine packet size (188 or 192)
    final actualPacketSize = data[0] == syncByte ? packetSize : packetSizeWithTimestamp;
    final syncOffset = actualPacketSize == packetSize ? 0 : 4;

    // First pass: Find PAT and extract PMT PID
    int? pmtPid;
    final packetCount = data.length ~/ actualPacketSize;

    for (var i = 0; i < packetCount && pmtPid == null; i++) {
      final packetStart = i * actualPacketSize + syncOffset;
      if (packetStart + packetSize > data.length) break;

      final pid = _extractPid(data, packetStart);
      if (pid == patPid) {
        pmtPid = _parsePatPacket(data, packetStart);
      }
    }

    if (pmtPid == null) return null;

    // Second pass: Find PMT and extract streams
    final tracks = <ContainerTrack>[];

    for (var i = 0; i < packetCount; i++) {
      final packetStart = i * actualPacketSize + syncOffset;
      if (packetStart + packetSize > data.length) break;

      final pid = _extractPid(data, packetStart);
      if (pid == pmtPid) {
        tracks.addAll(_parsePmtPacket(data, packetStart));
        break; // PMT found, no need to continue
      }
    }

    return ContainerMetadata(
      format: 'ts',
      duration: Duration.zero, // TS doesn't have duration in headers
      tracks: tracks,
    );
  }

  /// Extracts PID from TS packet header.
  static int _extractPid(Uint8List data, int packetStart) {
    final byte1 = data[packetStart + 1];
    final byte2 = data[packetStart + 2];
    return ((byte1 & 0x1F) << 8) | byte2;
  }

  /// Checks if packet has payload.
  static bool _hasPayload(Uint8List data, int packetStart) => (data[packetStart + 3] & 0x10) != 0;

  /// Gets payload start offset (after adaptation field if present).
  static int _getPayloadStart(Uint8List data, int packetStart) {
    var offset = packetStart + 4; // After TS header

    // Check for adaptation field
    final adaptationControl = (data[packetStart + 3] >> 4) & 0x03;
    if (adaptationControl == 0x02 || adaptationControl == 0x03) {
      // Adaptation field present
      final adaptationLength = data[offset];
      offset += 1 + adaptationLength;
    }

    return offset;
  }

  /// Parses PAT packet and returns PMT PID.
  static int? _parsePatPacket(Uint8List data, int packetStart) {
    if (!_hasPayload(data, packetStart)) return null;

    var offset = _getPayloadStart(data, packetStart);

    // Skip pointer field
    final pointerField = data[offset++];
    offset += pointerField;

    // Check table ID
    if (data[offset] != patTableId) return null;
    offset++;

    // Section length
    final sectionLength = ((data[offset] & 0x0F) << 8) | data[offset + 1];
    offset += 2;

    // Skip transport stream ID (2), version/current (1), section numbers (2)
    offset += 5;

    // Calculate number of programs (section length - header - CRC)
    final programDataLength = sectionLength - 5 - 4;
    final programCount = programDataLength ~/ 4;

    // Parse first non-NIT program entry
    for (var i = 0; i < programCount; i++) {
      final programNumber = (data[offset] << 8) | data[offset + 1];
      offset += 2;
      final pid = ((data[offset] & 0x1F) << 8) | data[offset + 1];
      offset += 2;

      // Program 0 is NIT, skip it
      if (programNumber != 0) {
        return pid; // Return first PMT PID
      }
    }

    return null;
  }

  /// Parses PMT packet and returns list of tracks.
  static List<ContainerTrack> _parsePmtPacket(Uint8List data, int packetStart) {
    final tracks = <ContainerTrack>[];

    if (!_hasPayload(data, packetStart)) return tracks;

    var offset = _getPayloadStart(data, packetStart);

    // Skip pointer field
    final pointerField = data[offset++];
    offset += pointerField;

    // Check table ID
    if (data[offset] != pmtTableId) return tracks;
    offset++;

    // Section length
    final sectionLength = ((data[offset] & 0x0F) << 8) | data[offset + 1];
    offset += 2;

    // Skip program number (2), version/current (1), section numbers (2)
    offset += 5;

    // Skip PCR PID
    offset += 2;

    // Program info length
    final programInfoLength = ((data[offset] & 0x0F) << 8) | data[offset + 1];
    offset += 2 + programInfoLength;

    // Calculate end of stream entries
    final sectionEnd = offset - programInfoLength - 4 + sectionLength - 4;

    // Parse stream entries
    var trackId = 1;
    while (offset + 5 <= sectionEnd && offset + 5 < data.length) {
      final streamType = data[offset++];
      final elementaryPid = ((data[offset] & 0x1F) << 8) | data[offset + 1];
      offset += 2;
      final esInfoLength = ((data[offset] & 0x0F) << 8) | data[offset + 1];
      offset += 2 + esInfoLength;

      // Skip null PIDs
      if (elementaryPid == nullPid) continue;

      final trackType = getTrackType(streamType);
      if (trackType == ContainerTrackType.unknown) continue;

      final codec = mapStreamTypeToCodec(streamType);

      tracks.add(ContainerTrack(id: trackId++, type: trackType, codec: codec));
    }

    return tracks;
  }

  /// Maps stream type to track type.
  static ContainerTrackType getTrackType(int streamType) {
    switch (streamType) {
      // Video
      case TsStreamType.mpeg1Video:
      case TsStreamType.mpeg2Video:
      case TsStreamType.h264:
      case TsStreamType.hevc:
      case TsStreamType.vp9:
      case TsStreamType.av1:
        return ContainerTrackType.video;

      // Audio
      case TsStreamType.mpeg1Audio:
      case TsStreamType.mp3:
      case TsStreamType.aac:
      case TsStreamType.aacLatm:
      case TsStreamType.ac3:
      case TsStreamType.eac3:
      case TsStreamType.dts:
      case TsStreamType.dtsHd:
      case TsStreamType.trueHd:
      case TsStreamType.opus:
        return ContainerTrackType.audio;

      // Subtitle
      case TsStreamType.dvbSubtitle:
      case TsStreamType.teletext:
      case TsStreamType.scte27:
        return ContainerTrackType.subtitle;

      default:
        return ContainerTrackType.unknown;
    }
  }

  /// Maps stream type to codec info.
  static CodecInfo mapStreamTypeToCodec(int streamType) {
    final (name, fourcc) = switch (streamType) {
      // Video
      TsStreamType.mpeg1Video => ('MPEG-1', 'mpg1'),
      TsStreamType.mpeg2Video => ('MPEG-2', 'mpg2'),
      TsStreamType.h264 => ('H.264', 'avc1'),
      TsStreamType.hevc => ('HEVC', 'hvc1'),
      TsStreamType.vp9 => ('VP9', 'vp09'),
      TsStreamType.av1 => ('AV1', 'av01'),

      // Audio
      TsStreamType.mpeg1Audio => ('MP1', '.mp1'),
      TsStreamType.mp3 => ('MP3', '.mp3'),
      TsStreamType.aac || TsStreamType.aacLatm => ('AAC', 'mp4a'),
      TsStreamType.ac3 => ('AC-3', 'ac-3'),
      TsStreamType.eac3 => ('E-AC-3', 'ec-3'),
      TsStreamType.dts => ('DTS', 'dtsc'),
      TsStreamType.dtsHd => ('DTS-HD', 'dtsh'),
      TsStreamType.trueHd => ('TrueHD', 'mlpa'),
      TsStreamType.opus => ('Opus', 'Opus'),

      // Subtitle
      TsStreamType.dvbSubtitle || TsStreamType.privateData => ('DVB Subtitle', 'dvbs'),
      TsStreamType.teletext => ('Teletext', 'ttxt'),
      TsStreamType.scte27 => ('SCTE-27', 'sc27'),

      _ => ('Unknown', 'unkn'),
    };

    return CodecInfo(
      fourcc: fourcc,
      name: name,
      codecString: '0x${streamType.toRadixString(16).padLeft(2, '0').toUpperCase()}',
    );
  }
}
