import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../container/ts_parser.dart';
import '../types/container_metadata.dart';
import 'sample_reader.dart';

/// Information about a PES packet location in a TS file.
class _PesSampleInfo {
  const _PesSampleInfo({
    required this.fileOffset,
    required this.pid,
    required this.pts,
    required this.dts,
    required this.isKeyframe,
  });

  final int fileOffset;
  final int pid;
  final int pts;
  final int dts;
  final bool isKeyframe;
}

/// Reads media samples from an MPEG-TS file.
///
/// Parses TS packets and extracts PES packets as samples with proper timing.
class TsSampleReader implements SampleReader {
  TsSampleReader._({
    required RandomAccessFile file,
    required int trackId,
    required int pid,
    required TrackCodecInfo codecInfo,
    required int packetSize,
    required int syncOffset,
  }) : _file = file,
       _trackId = trackId,
       _pid = pid,
       _codecInfo = codecInfo,
       _packetSize = packetSize,
       _syncOffset = syncOffset;

  final RandomAccessFile _file;
  final int _trackId;
  final int _pid;
  final TrackCodecInfo _codecInfo;
  final int _packetSize;
  final int _syncOffset;

  List<_PesSampleInfo>? _sampleIndex;
  int _currentIndex = 0;
  bool _isClosed = false;

  @override
  int get trackId => _trackId;

  @override
  int get timescale => 90000; // TS uses 90kHz clock

  @override
  int get sampleCount => _sampleIndex?.length ?? 0;

  @override
  int get totalDuration {
    if (_sampleIndex == null || _sampleIndex!.isEmpty) return 0;
    return _sampleIndex!.last.pts - _sampleIndex!.first.pts;
  }

  @override
  bool get hasMoreSamples => _sampleIndex != null && _currentIndex < _sampleIndex!.length;

  @override
  int get currentIndex => _currentIndex;

  /// The codec information for this track.
  TrackCodecInfo get codecInfo => _codecInfo;

  /// Builds the sample index by scanning all PES packets.
  Future<void> buildIndex() async {
    if (_sampleIndex != null) return;

    _sampleIndex = [];
    final fileLength = await _file.length();
    final packetCount = fileLength ~/ _packetSize;

    // Scan for PES packets
    for (var i = 0; i < packetCount; i++) {
      final packetStart = i * _packetSize + _syncOffset;
      await _file.setPosition(packetStart);
      final packet = await _file.read(TsParser.packetSize);

      if (packet.length < TsParser.packetSize) break;
      if (packet[0] != TsParser.syncByte) continue;

      final pid = ((packet[1] & 0x1F) << 8) | packet[2];
      if (pid != _pid) continue;

      // Check for payload unit start indicator (PUSI)
      final pusi = (packet[1] & 0x40) != 0;
      if (!pusi) continue;

      // Get payload offset
      final adaptationControl = (packet[3] >> 4) & 0x03;
      var payloadOffset = 4;
      if (adaptationControl == 0x02 || adaptationControl == 0x03) {
        payloadOffset += 1 + packet[4];
      }

      if (payloadOffset + 9 >= TsParser.packetSize) continue;

      // Check PES start code
      if (packet[payloadOffset] != 0x00 || packet[payloadOffset + 1] != 0x00 || packet[payloadOffset + 2] != 0x01) {
        continue;
      }

      // Parse PES header
      final streamId = packet[payloadOffset + 3];
      // Skip non-media stream IDs (padding, private, program stream map, etc.)
      if (streamId < 0xC0 && streamId != 0xBD && streamId != 0xBF) continue;

      final pesHeaderDataLength = packet[payloadOffset + 8];
      final ptsDtsFlags = (packet[payloadOffset + 7] >> 6) & 0x03;

      var pts = 0;
      var dts = 0;

      if (ptsDtsFlags >= 0x02 && payloadOffset + 9 + 5 <= TsParser.packetSize) {
        pts = _parsePts(packet, payloadOffset + 9);
        dts = pts;
        if (ptsDtsFlags == 0x03 && payloadOffset + 9 + 10 <= TsParser.packetSize) {
          dts = _parsePts(packet, payloadOffset + 14);
        }
      }

      // Check for keyframe (random access indicator in adaptation field)
      var isKeyframe = false;
      if (adaptationControl == 0x02 || adaptationControl == 0x03) {
        if (packet[4] > 0) {
          isKeyframe = (packet[5] & 0x40) != 0;
        }
      }

      // For video, also check NAL unit type for IDR
      if (_codecInfo.isVideo && payloadOffset + 9 + pesHeaderDataLength + 5 <= TsParser.packetSize) {
        final nalOffset = payloadOffset + 9 + pesHeaderDataLength;
        // Look for start code
        if (packet[nalOffset] == 0x00 && packet[nalOffset + 1] == 0x00) {
          int nalTypeOffset;
          if (packet[nalOffset + 2] == 0x01) {
            nalTypeOffset = nalOffset + 3;
          } else if (packet[nalOffset + 2] == 0x00 && packet[nalOffset + 3] == 0x01) {
            nalTypeOffset = nalOffset + 4;
          } else {
            nalTypeOffset = -1;
          }

          if (nalTypeOffset > 0 && nalTypeOffset < TsParser.packetSize) {
            final nalType = packet[nalTypeOffset] & 0x1F;
            // H.264 IDR = 5, SPS = 7
            if (nalType == 5 || nalType == 7) {
              isKeyframe = true;
            }
          }
        }
      }

      _sampleIndex!.add(_PesSampleInfo(fileOffset: packetStart, pid: pid, pts: pts, dts: dts, isKeyframe: isKeyframe));
    }
  }

  int _parsePts(Uint8List data, int offset) {
    final pts =
        ((data[offset] >> 1) & 0x07) << 30 |
        (data[offset + 1] << 22) |
        ((data[offset + 2] >> 1) << 15) |
        (data[offset + 3] << 7) |
        (data[offset + 4] >> 1);
    return pts;
  }

  @override
  Future<MediaSample?> readNextSample() async {
    if (_isClosed || _sampleIndex == null || !hasMoreSamples) return null;
    return readSampleAt(_currentIndex++);
  }

  @override
  Future<MediaSample?> readSampleAt(int index) async {
    if (_isClosed || _sampleIndex == null || index < 0 || index >= _sampleIndex!.length) return null;

    final info = _sampleIndex![index];

    // Read PES packet data by collecting TS packets
    final pesData = await _readPesPacket(info.fileOffset);
    if (pesData == null) return null;

    // Calculate duration
    var duration = 0;
    if (index + 1 < _sampleIndex!.length) {
      duration = _sampleIndex![index + 1].pts - info.pts;
    }

    return MediaSample(
      data: pesData,
      trackId: _trackId,
      sampleIndex: index,
      decodeTimestamp: info.dts,
      compositionTimestamp: info.pts,
      duration: duration,
      isKeyframe: info.isKeyframe,
    );
  }

  Future<Uint8List?> _readPesPacket(int startOffset) async {
    final buffer = BytesBuilder();
    var currentOffset = startOffset;
    final fileLength = await _file.length();
    var isFirstPacket = true;
    var pesLength = 0;
    var pesHeaderLength = 0;

    while (currentOffset < fileLength) {
      await _file.setPosition(currentOffset);
      final packet = await _file.read(TsParser.packetSize);

      if (packet.length < TsParser.packetSize) break;
      if (packet[0] != TsParser.syncByte) break;

      final pid = ((packet[1] & 0x1F) << 8) | packet[2];
      if (pid != _pid) {
        currentOffset += _packetSize;
        continue;
      }

      // Get payload
      final hasPayload = (packet[3] & 0x10) != 0;
      if (!hasPayload) {
        currentOffset += _packetSize;
        continue;
      }

      final adaptationControl = (packet[3] >> 4) & 0x03;
      var payloadOffset = 4;
      if (adaptationControl == 0x02 || adaptationControl == 0x03) {
        payloadOffset += 1 + packet[4];
      }

      if (payloadOffset >= TsParser.packetSize) {
        currentOffset += _packetSize;
        continue;
      }

      final pusi = (packet[1] & 0x40) != 0;

      if (isFirstPacket) {
        if (!pusi) {
          currentOffset += _packetSize;
          continue;
        }

        // Skip PES header
        if (payloadOffset + 9 >= TsParser.packetSize) break;

        pesLength = (packet[payloadOffset + 4] << 8) | packet[payloadOffset + 5];
        pesHeaderLength = packet[payloadOffset + 8];

        final dataStart = payloadOffset + 9 + pesHeaderLength;
        if (dataStart >= TsParser.packetSize) break;

        buffer.add(packet.sublist(dataStart, TsParser.packetSize));
        isFirstPacket = false;
      } else {
        // Check if this is a new PES packet
        if (pusi) break;

        buffer.add(packet.sublist(payloadOffset, TsParser.packetSize));
      }

      // Check if we have all data (if PES length was specified)
      if (pesLength > 0 && buffer.length >= pesLength - 3 - pesHeaderLength) {
        break;
      }

      currentOffset += _packetSize;
    }

    if (buffer.isEmpty) return null;

    final result = buffer.toBytes();
    if (pesLength > 0) {
      final expectedLength = pesLength - 3 - pesHeaderLength;
      if (result.length > expectedLength) {
        return Uint8List.sublistView(result, 0, expectedLength);
      }
    }

    return result;
  }

  @override
  Future<int> seekToTimestamp(int timestamp, {bool toKeyframe = false}) async {
    if (_sampleIndex == null || _sampleIndex!.isEmpty) return 0;

    // Binary search for timestamp
    var low = 0;
    var high = _sampleIndex!.length - 1;

    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (_sampleIndex![mid].pts <= timestamp) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }

    if (toKeyframe) {
      while (low > 0 && !_sampleIndex![low].isKeyframe) {
        low--;
      }
    }

    return _currentIndex = low;
  }

  @override
  void seekToIndex(int index) {
    if (_sampleIndex == null) {
      _currentIndex = 0;
      return;
    }

    if (index < 0) {
      _currentIndex = 0;
    } else if (index >= _sampleIndex!.length) {
      _currentIndex = _sampleIndex!.isEmpty ? 0 : _sampleIndex!.length - 1;
    } else {
      _currentIndex = index;
    }
  }

  @override
  Stream<MediaSample> samples() async* {
    while (hasMoreSamples && !_isClosed) {
      final sample = await readNextSample();
      if (sample != null) {
        yield sample;
      }
    }
  }

  @override
  Future<void> close() async {
    if (!_isClosed) {
      _isClosed = true;
      await _file.close();
    }
  }

  /// Opens a TS file and creates a sample reader for a specific track.
  static Future<TsSampleReader?> open(String filePath, int trackId) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    // Read header to parse metadata
    const headerSize = 1024 * 1024; // 1MB should be enough for PAT/PMT
    final fileLength = await file.length();
    final readSize = fileLength < headerSize ? fileLength : headerSize;

    final headerData = await file.openRead(0, readSize).fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
    final data = Uint8List.fromList(headerData);

    final metadata = TsParser.parse(data);
    if (metadata == null) return null;

    // Find the requested track
    final track = metadata.tracks.where((t) => t.id == trackId).firstOrNull;
    if (track == null) return null;

    // Determine packet size
    final packetSize = data[0] == TsParser.syncByte ? TsParser.packetSize : TsParser.packetSizeWithTimestamp;
    final syncOffset = packetSize == TsParser.packetSize ? 0 : 4;

    // Find PID for the track from PMT
    final trackPid = _findPidForTrack(data, trackId, packetSize, syncOffset);
    if (trackPid == null) return null;

    // Create codec info
    final codecInfo = TrackCodecInfo(
      trackId: trackId,
      codecFourcc: track.codec.fourcc,
      timescale: 90000,
      width: track.videoInfo?.width,
      height: track.videoInfo?.height,
      sampleRate: track.audioInfo?.sampleRate,
      channelCount: track.audioInfo?.channelCount,
    );

    final raf = await file.open();
    final reader = TsSampleReader._(
      file: raf,
      trackId: trackId,
      pid: trackPid,
      codecInfo: codecInfo,
      packetSize: packetSize,
      syncOffset: syncOffset,
    );

    await reader.buildIndex();
    return reader;
  }

  static int? _findPidForTrack(Uint8List data, int trackId, int packetSize, int syncOffset) {
    // Find PMT PID from PAT first
    int? pmtPid;
    final packetCount = data.length ~/ packetSize;

    for (var i = 0; i < packetCount && pmtPid == null; i++) {
      final packetStart = i * packetSize + syncOffset;
      if (packetStart + TsParser.packetSize > data.length) break;

      final pid = ((data[packetStart + 1] & 0x1F) << 8) | data[packetStart + 2];
      if (pid == TsParser.patPid) {
        pmtPid = _parsePatForPmtPid(data, packetStart);
      }
    }

    if (pmtPid == null) return null;

    // Find PID from PMT
    for (var i = 0; i < packetCount; i++) {
      final packetStart = i * packetSize + syncOffset;
      if (packetStart + TsParser.packetSize > data.length) break;

      final pid = ((data[packetStart + 1] & 0x1F) << 8) | data[packetStart + 2];
      if (pid == pmtPid) {
        return _parsePmtForTrackPid(data, packetStart, trackId);
      }
    }

    return null;
  }

  static int? _parsePatForPmtPid(Uint8List data, int packetStart) {
    if ((data[packetStart + 3] & 0x10) == 0) return null;

    var offset = packetStart + 4;
    final adaptationControl = (data[packetStart + 3] >> 4) & 0x03;
    if (adaptationControl == 0x02 || adaptationControl == 0x03) {
      offset += 1 + data[offset];
    }

    final pointerField = data[offset++];
    offset += pointerField;

    if (data[offset] != TsParser.patTableId) return null;
    offset++;

    final sectionLength = ((data[offset] & 0x0F) << 8) | data[offset + 1];
    offset += 7;

    final programDataLength = sectionLength - 5 - 4;
    final programCount = programDataLength ~/ 4;

    for (var i = 0; i < programCount; i++) {
      final programNumber = (data[offset] << 8) | data[offset + 1];
      offset += 2;
      final pid = ((data[offset] & 0x1F) << 8) | data[offset + 1];
      offset += 2;

      if (programNumber != 0) return pid;
    }

    return null;
  }

  static int? _parsePmtForTrackPid(Uint8List data, int packetStart, int trackId) {
    if ((data[packetStart + 3] & 0x10) == 0) return null;

    var offset = packetStart + 4;
    final adaptationControl = (data[packetStart + 3] >> 4) & 0x03;
    if (adaptationControl == 0x02 || adaptationControl == 0x03) {
      offset += 1 + data[offset];
    }

    final pointerField = data[offset++];
    offset += pointerField;

    if (data[offset] != TsParser.pmtTableId) return null;
    offset++;

    final sectionLength = ((data[offset] & 0x0F) << 8) | data[offset + 1];
    offset += 7;

    final programInfoLength = ((data[offset] & 0x0F) << 8) | data[offset + 1];
    offset += 2 + programInfoLength;

    final sectionEnd = offset - programInfoLength - 4 + sectionLength - 4;

    var currentTrackId = 1;
    while (offset + 5 <= sectionEnd && offset + 5 < data.length) {
      // final streamType = data[offset++];
      offset++;
      final elementaryPid = ((data[offset] & 0x1F) << 8) | data[offset + 1];
      offset += 2;
      final esInfoLength = ((data[offset] & 0x0F) << 8) | data[offset + 1];
      offset += 2 + esInfoLength;

      if (elementaryPid == TsParser.nullPid) continue;

      if (currentTrackId == trackId) {
        return elementaryPid;
      }
      currentTrackId++;
    }

    return null;
  }
}

/// Factory for creating TS sample readers for all tracks.
class TsSampleReaderFactory {
  TsSampleReaderFactory._();

  /// Opens a TS file and returns metadata and available track IDs.
  static Future<({ContainerMetadata? metadata, List<int> trackIds})?> inspect(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    const headerSize = 1024 * 1024;
    final fileLength = await file.length();
    final readSize = fileLength < headerSize ? fileLength : headerSize;

    final data = await file.openRead(0, readSize).fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));

    final metadata = TsParser.parse(Uint8List.fromList(data));
    if (metadata == null) return null;

    final trackIds = metadata.tracks.map((t) => t.id).toList();
    return (metadata: metadata, trackIds: trackIds);
  }

  /// Creates sample readers for all tracks in a TS file.
  static Future<Map<int, TsSampleReader>> openAll(String filePath) async {
    final inspection = await inspect(filePath);
    if (inspection == null) return {};

    final readers = <int, TsSampleReader>{};
    for (final trackId in inspection.trackIds) {
      final reader = await TsSampleReader.open(filePath, trackId);
      if (reader != null) {
        readers[trackId] = reader;
      }
    }

    return readers;
  }
}
