import 'dart:typed_data';

/// Low-level MPEG-TS packet writing utilities.
///
/// MPEG-TS packets are exactly 188 bytes, consisting of:
/// - 4-byte header (sync byte + flags + PID + continuity counter)
/// - Optional adaptation field
/// - Payload
abstract final class TsPacketWriter {
  /// TS packet size in bytes.
  static const int packetSize = 188;

  /// Sync byte that starts every TS packet.
  static const int syncByte = 0x47;

  /// PAT (Program Association Table) PID.
  static const int patPid = 0x0000;

  /// Default PMT (Program Map Table) PID.
  static const int pmtPid = 0x1000;

  /// Default video elementary stream PID.
  static const int videoPid = 0x0100;

  /// Default audio elementary stream PID.
  static const int audioPid = 0x0101;

  /// Stream type for H.264/AVC video.
  static const int streamTypeAvc = 0x1B;

  /// Stream type for HEVC video.
  static const int streamTypeHevc = 0x24;

  /// Stream type for AAC audio (ADTS).
  static const int streamTypeAacAdts = 0x0F;

  /// Stream type for AC-3 audio.
  static const int streamTypeAc3 = 0x81;

  /// Writes a PAT (Program Association Table) packet.
  ///
  /// PAT is always on PID 0x0000 and maps program numbers to PMT PIDs.
  static Uint8List writePat({int programNumber = 1, int pmtPid = TsPacketWriter.pmtPid, int continuityCounter = 0}) {
    final packet = Uint8List(packetSize);
    var offset = 0;

    // TS header
    packet[offset++] = syncByte;
    packet[offset++] = 0x40; // payload_unit_start_indicator = 1, PID high bits = 0
    packet[offset++] = 0x00; // PID low bits = 0 (PAT PID)
    packet[offset++] = 0x10 | (continuityCounter & 0x0F); // adaptation_field_control = 01 (payload only)

    // Pointer field (required for tables)
    packet[offset++] = 0x00;

    // PAT section
    final sectionStart = offset;
    packet[offset++] = 0x00; // table_id = PAT
    // Section length placeholder (will be filled in)
    final sectionLengthOffset = offset;
    offset += 2;

    packet[offset++] = 0x00; // transport_stream_id high
    packet[offset++] = 0x01; // transport_stream_id low
    packet[offset++] = 0xC1; // version = 0, current_next = 1
    packet[offset++] = 0x00; // section_number
    packet[offset++] = 0x00; // last_section_number

    // Program entry
    packet[offset++] = (programNumber >> 8) & 0xFF;
    packet[offset++] = programNumber & 0xFF;
    packet[offset++] = 0xE0 | ((pmtPid >> 8) & 0x1F); // reserved bits + PID high
    packet[offset++] = pmtPid & 0xFF;

    // Calculate and write section length (includes CRC32)
    final sectionLength = offset - sectionStart - 3 + 4; // +4 for CRC32
    packet[sectionLengthOffset] = 0xB0 | ((sectionLength >> 8) & 0x0F);
    packet[sectionLengthOffset + 1] = sectionLength & 0xFF;

    // CRC32
    final crc = _calculateCrc32(packet, sectionStart, offset - sectionStart);
    packet[offset++] = (crc >> 24) & 0xFF;
    packet[offset++] = (crc >> 16) & 0xFF;
    packet[offset++] = (crc >> 8) & 0xFF;
    packet[offset++] = crc & 0xFF;

    // Fill rest with padding
    for (var i = offset; i < packetSize; i++) {
      packet[i] = 0xFF;
    }

    return packet;
  }

  /// Writes a PMT (Program Map Table) packet.
  ///
  /// PMT describes the streams in a program and their PIDs.
  static Uint8List writePmt({
    required List<TsStreamInfo> streams,
    int programNumber = 1,
    int pcrPid = videoPid,
    int continuityCounter = 0,
  }) {
    final packet = Uint8List(packetSize);
    var offset = 0;

    // TS header
    packet[offset++] = syncByte;
    packet[offset++] = 0x40 | ((pmtPid >> 8) & 0x1F); // payload_unit_start_indicator = 1
    packet[offset++] = pmtPid & 0xFF;
    packet[offset++] = 0x10 | (continuityCounter & 0x0F);

    // Pointer field
    packet[offset++] = 0x00;

    // PMT section
    final sectionStart = offset;
    packet[offset++] = 0x02; // table_id = PMT
    final sectionLengthOffset = offset;
    offset += 2;

    packet[offset++] = (programNumber >> 8) & 0xFF;
    packet[offset++] = programNumber & 0xFF;
    packet[offset++] = 0xC1; // version = 0, current_next = 1
    packet[offset++] = 0x00; // section_number
    packet[offset++] = 0x00; // last_section_number
    packet[offset++] = 0xE0 | ((pcrPid >> 8) & 0x1F); // PCR_PID
    packet[offset++] = pcrPid & 0xFF;
    packet[offset++] = 0xF0; // program_info_length = 0
    packet[offset++] = 0x00;

    // Stream entries
    for (final stream in streams) {
      packet[offset++] = stream.streamType;
      packet[offset++] = 0xE0 | ((stream.pid >> 8) & 0x1F);
      packet[offset++] = stream.pid & 0xFF;
      packet[offset++] = 0xF0; // ES_info_length = 0
      packet[offset++] = 0x00;
    }

    // Section length
    final sectionLength = offset - sectionStart - 3 + 4;
    packet[sectionLengthOffset] = 0xB0 | ((sectionLength >> 8) & 0x0F);
    packet[sectionLengthOffset + 1] = sectionLength & 0xFF;

    // CRC32
    final crc = _calculateCrc32(packet, sectionStart, offset - sectionStart);
    packet[offset++] = (crc >> 24) & 0xFF;
    packet[offset++] = (crc >> 16) & 0xFF;
    packet[offset++] = (crc >> 8) & 0xFF;
    packet[offset++] = crc & 0xFF;

    // Fill rest with padding
    for (var i = offset; i < packetSize; i++) {
      packet[i] = 0xFF;
    }

    return packet;
  }

  /// Writes a PES (Packetized Elementary Stream) packet header.
  ///
  /// Returns the header bytes that should precede the elementary stream data.
  static Uint8List writePesHeader({required int streamId, required int dataLength, int? pts, int? dts}) {
    final hasPts = pts != null;
    final hasDts = dts != null && dts != pts;
    final headerDataLength = (hasPts ? 5 : 0) + (hasDts ? 5 : 0);
    final pesPacketLength = 3 + headerDataLength + dataLength;

    // PES header is variable length
    final header = Uint8List(9 + headerDataLength);
    var offset = 0;

    // Start code prefix
    header[offset++] = 0x00;
    header[offset++] = 0x00;
    header[offset++] = 0x01;

    // Stream ID
    header[offset++] = streamId;

    // PES packet length (0 for unbounded video)
    if (pesPacketLength <= 65535) {
      header[offset++] = (pesPacketLength >> 8) & 0xFF;
      header[offset++] = pesPacketLength & 0xFF;
    } else {
      header[offset++] = 0x00;
      header[offset++] = 0x00;
    }

    // PES header flags
    header[offset++] = 0x80; // '10' marker bits
    header[offset++] = (hasPts ? 0x80 : 0x00) | (hasDts ? 0x40 : 0x00); // PTS/DTS flags
    header[offset++] = headerDataLength;

    // PTS
    if (hasPts) {
      final ptsValue = pts;
      header[offset++] = (hasDts ? 0x30 : 0x20) | (ptsValue >> 29 & 0x0E) | 0x01;
      header[offset++] = (ptsValue >> 22) & 0xFF;
      header[offset++] = (ptsValue >> 14 & 0xFE) | 0x01;
      header[offset++] = (ptsValue >> 7) & 0xFF;
      header[offset++] = (ptsValue << 1 & 0xFE) | 0x01;
    }

    // DTS
    if (hasDts) {
      final dtsValue = dts;
      header[offset++] = 0x10 | (dtsValue >> 29 & 0x0E) | 0x01;
      header[offset++] = (dtsValue >> 22) & 0xFF;
      header[offset++] = (dtsValue >> 14 & 0xFE) | 0x01;
      header[offset++] = (dtsValue >> 7) & 0xFF;
      header[offset++] = (dtsValue << 1 & 0xFE) | 0x01;
    }

    return header;
  }

  /// Packetizes data into TS packets.
  ///
  /// [pid] is the packet identifier for the stream.
  /// [data] is the elementary stream data (with PES header if applicable).
  /// [isPayloadStart] should be true for the first packet of a PES packet.
  /// [continuityCounter] should be incremented for each packet of the same PID.
  /// [pcr] is the Program Clock Reference timestamp (optional, for adaptation field).
  static List<Uint8List> packetize({
    required int pid,
    required Uint8List data,
    required bool isPayloadStart,
    required int continuityCounter,
    int? pcr,
  }) {
    final packets = <Uint8List>[];
    var dataOffset = 0;
    var cc = continuityCounter;
    var isFirst = isPayloadStart;

    while (dataOffset < data.length) {
      final packet = Uint8List(packetSize);
      var offset = 0;

      // Calculate available payload space
      final needsPcr = isFirst && pcr != null;
      final remainingData = data.length - dataOffset;

      // Max payload without adaptation: 188 - 4 (header) = 184
      // Max payload with PCR adaptation: 188 - 4 - 8 (adaptation w/PCR) = 176
      // Max payload with stuffing adaptation: 188 - 4 - 2 (min adaptation) = 182
      const maxPayloadNoAdapt = packetSize - 4;
      const maxPayloadWithPcr = packetSize - 4 - 8;
      const maxPayloadWithStuffing = packetSize - 4 - 2;

      // Determine if we need stuffing (data doesn't fill packet)
      final effectiveMaxPayload = needsPcr ? maxPayloadWithPcr : maxPayloadNoAdapt;
      final needsStuffing = remainingData < effectiveMaxPayload && !needsPcr;

      // TS header
      packet[offset++] = syncByte;
      packet[offset++] = (isFirst ? 0x40 : 0x00) | ((pid >> 8) & 0x1F);
      packet[offset++] = pid & 0xFF;

      // Adaptation field control + continuity counter
      final hasAdaptation = needsPcr || needsStuffing;
      packet[offset++] = (hasAdaptation ? 0x30 : 0x10) | (cc & 0x0F);

      // Adaptation field
      if (hasAdaptation) {
        final adaptFieldStart = offset;
        offset++; // placeholder for adaptation_field_length

        if (needsPcr) {
          final pcrValue = pcr; // Safe: needsPcr = isFirst && pcr != null
          packet[offset++] = 0x10; // PCR flag
          // PCR (48 bits: 33 bits base + 6 reserved + 9 bits extension)
          packet[offset++] = (pcrValue >> 25) & 0xFF;
          packet[offset++] = (pcrValue >> 17) & 0xFF;
          packet[offset++] = (pcrValue >> 9) & 0xFF;
          packet[offset++] = (pcrValue >> 1) & 0xFF;
          packet[offset++] = ((pcrValue & 0x01) << 7) | 0x7E; // reserved bits
          packet[offset++] = 0x00; // extension low byte
        } else {
          packet[offset++] = 0x00; // flags (no PCR)
        }

        // Calculate and add stuffing bytes to fill the packet
        // We want: payload = min(remainingData, available space)
        // Stuffing fills the gap between current offset and payload start
        if (needsStuffing) {
          final payloadSize = remainingData < maxPayloadWithStuffing ? remainingData : maxPayloadWithStuffing;
          final targetOffset = packetSize - payloadSize;
          while (offset < targetOffset) {
            packet[offset++] = 0xFF;
          }
        }

        packet[adaptFieldStart] = offset - adaptFieldStart - 1;
      }

      // Payload
      final payloadLength = packetSize - offset;
      final bytesToCopy = payloadLength < remainingData ? payloadLength : remainingData;
      packet.setRange(offset, offset + bytesToCopy, data, dataOffset);
      offset += bytesToCopy;
      dataOffset += bytesToCopy;

      // Fill any remaining space (shouldn't happen with correct stuffing)
      while (offset < packetSize) {
        packet[offset++] = 0xFF;
      }

      packets.add(packet);
      cc = (cc + 1) & 0x0F;
      isFirst = false;
    }

    return packets;
  }

  /// Converts H.264 Annex B NAL units to have proper start codes.
  ///
  /// MP4 uses length-prefixed NAL units; TS uses start code prefixed.
  static Uint8List convertAvcToAnnexB(Uint8List data, int nalLengthSize) {
    final output = <int>[];
    var offset = 0;

    while (offset + nalLengthSize <= data.length) {
      // Read NAL unit length
      var nalLength = 0;
      for (var i = 0; i < nalLengthSize; i++) {
        nalLength = (nalLength << 8) | data[offset + i];
      }
      offset += nalLengthSize;

      if (offset + nalLength > data.length) break;

      // Add start code
      output.addAll([0x00, 0x00, 0x00, 0x01]);

      // Add NAL unit data
      output.addAll(data.sublist(offset, offset + nalLength));
      offset += nalLength;
    }

    return Uint8List.fromList(output);
  }

  /// Creates an ADTS header for AAC audio.
  ///
  /// [sampleRate] is the audio sample rate.
  /// [channelCount] is the number of audio channels.
  /// [frameLength] is the length of the AAC frame data.
  static Uint8List createAdtsHeader({required int sampleRate, required int channelCount, required int frameLength}) {
    final header = Uint8List(7);

    // Sample rate index lookup
    final sampleRateIndex = _getSampleRateIndex(sampleRate);
    final fullFrameLength = frameLength + 7; // Include header length

    // Syncword (12 bits) + ID (1 bit) + Layer (2 bits) + Protection absent (1 bit)
    header[0] = 0xFF;
    header[1] = 0xF1; // MPEG-4, no CRC

    // Profile (2 bits) + Sample rate index (4 bits) + Private (1 bit) + Channel config high (1 bit)
    header[2] =
        (1 << 6) | // AAC-LC profile (2 = AAC-LC, but stored as profile - 1)
        ((sampleRateIndex & 0x0F) << 2) |
        (channelCount >> 2 & 0x01);

    // Channel config low (2 bits) + Original (1 bit) + Home (1 bit) + Copyright ID (1 bit) + Copyright start (1 bit) + Frame length high (2 bits)
    header[3] = ((channelCount & 0x03) << 6) | ((fullFrameLength >> 11) & 0x03);

    // Frame length middle (8 bits)
    header[4] = (fullFrameLength >> 3) & 0xFF;

    // Frame length low (3 bits) + Buffer fullness high (5 bits)
    header[5] = ((fullFrameLength & 0x07) << 5) | 0x1F;

    // Buffer fullness low (6 bits) + Number of AAC frames - 1 (2 bits)
    header[6] = 0xFC;

    return header;
  }

  /// Gets the ADTS sample rate index for a given sample rate.
  static int _getSampleRateIndex(int sampleRate) {
    const sampleRates = [96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050, 16000, 12000, 11025, 8000, 7350];

    for (var i = 0; i < sampleRates.length; i++) {
      if (sampleRate == sampleRates[i]) return i;
    }
    return 4; // Default to 44100
  }

  /// CRC32 lookup table for MPEG-2 CRC.
  static final List<int> _crc32Table = _buildCrc32Table();

  static List<int> _buildCrc32Table() {
    final table = List<int>.filled(256, 0);
    for (var i = 0; i < 256; i++) {
      var crc = i << 24;
      for (var j = 0; j < 8; j++) {
        if ((crc & 0x80000000) != 0) {
          crc = ((crc << 1) ^ 0x04C11DB7) & 0xFFFFFFFF;
        } else {
          crc = (crc << 1) & 0xFFFFFFFF;
        }
      }
      table[i] = crc;
    }
    return table;
  }

  /// Calculates MPEG-2 CRC32 for PAT/PMT tables.
  static int _calculateCrc32(Uint8List data, int start, int length) {
    var crc = 0xFFFFFFFF;
    for (var i = start; i < start + length; i++) {
      final index = ((crc >> 24) ^ data[i]) & 0xFF;
      crc = ((crc << 8) ^ _crc32Table[index]) & 0xFFFFFFFF;
    }
    return crc;
  }
}

/// Information about a stream in the TS multiplex.
class TsStreamInfo {
  /// Creates stream info.
  const TsStreamInfo({required this.streamType, required this.pid});

  /// Stream type code (e.g., 0x1B for H.264).
  final int streamType;

  /// Packet identifier for this stream.
  final int pid;
}

/// Stream IDs for PES packets.
abstract final class PesStreamId {
  /// Private stream 1 (used for AC-3, DTS, etc.)
  static const int privateStream1 = 0xBD;

  /// Audio streams (0xC0-0xDF)
  static int audio(int index) => 0xC0 + (index & 0x1F);

  /// Video streams (0xE0-0xEF)
  static int video(int index) => 0xE0 + (index & 0x0F);
}
