import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../container/flv_parser.dart';
import '../types/container_metadata.dart';
import '../types/container_track_type.dart';
import 'sample_reader.dart';

/// Information about an FLV tag sample.
class _FlvSampleInfo {
  const _FlvSampleInfo({
    required this.fileOffset,
    required this.dataSize,
    required this.timestamp,
    required this.isKeyframe,
    required this.isVideo,
  });

  final int fileOffset;
  final int dataSize;
  final int timestamp;
  final bool isKeyframe;
  final bool isVideo;
}

/// Reads media samples from an FLV file.
///
/// Parses FLV tags and extracts samples with proper timing.
class FlvSampleReader implements SampleReader {
  FlvSampleReader._({
    required RandomAccessFile file,
    required int trackId,
    required TrackCodecInfo codecInfo,
    required bool isVideo,
  }) : _file = file,
       _trackId = trackId,
       _codecInfo = codecInfo,
       _isVideo = isVideo;

  final RandomAccessFile _file;
  final int _trackId;
  final TrackCodecInfo _codecInfo;
  final bool _isVideo;

  List<_FlvSampleInfo>? _sampleIndex;
  int _currentIndex = 0;
  bool _isClosed = false;

  @override
  int get trackId => _trackId;

  @override
  int get timescale => 1000; // FLV uses millisecond timestamps

  @override
  int get sampleCount => _sampleIndex?.length ?? 0;

  @override
  int get totalDuration {
    if (_sampleIndex == null || _sampleIndex!.isEmpty) return 0;
    return _sampleIndex!.last.timestamp - _sampleIndex!.first.timestamp;
  }

  @override
  bool get hasMoreSamples => _sampleIndex != null && _currentIndex < _sampleIndex!.length;

  @override
  int get currentIndex => _currentIndex;

  /// The codec information for this track.
  TrackCodecInfo get codecInfo => _codecInfo;

  /// Builds the sample index by scanning all FLV tags.
  Future<void> buildIndex() async {
    if (_sampleIndex != null) return;

    _sampleIndex = [];
    final fileLength = await _file.length();

    // Read FLV header to get data offset
    await _file.setPosition(0);
    final header = await _file.read(FlvParser.headerSize);
    if (header.length < FlvParser.headerSize) return;

    final dataOffset = _readUint32Be(header, 5);
    var offset = dataOffset + 4; // Skip first PreviousTagSize

    while (offset + 11 < fileLength) {
      await _file.setPosition(offset);
      final tagHeader = await _file.read(11);
      if (tagHeader.length < 11) break;

      final tagType = tagHeader[0];
      final dataSize = _readUint24Be(tagHeader, 1);
      final timestamp = _readTimestamp(tagHeader, 4);

      // Check for relevant tag type
      final isVideo = tagType == FlvTagType.video;
      final isAudio = tagType == FlvTagType.audio;

      if ((_isVideo && isVideo) || (!_isVideo && isAudio)) {
        // Check if keyframe (for video)
        var isKeyframe = !isVideo; // Audio is always considered a keyframe

        if (isVideo && dataSize > 0) {
          await _file.setPosition(offset + 11);
          final videoFlags = await _file.read(1);
          if (videoFlags.isNotEmpty) {
            final frameType = (videoFlags[0] >> 4) & 0x0F;
            isKeyframe = frameType == 1; // 1 = keyframe
          }
        }

        _sampleIndex!.add(
          _FlvSampleInfo(
            fileOffset: offset,
            dataSize: dataSize,
            timestamp: timestamp,
            isKeyframe: isKeyframe,
            isVideo: isVideo,
          ),
        );
      }

      // Move to next tag
      offset += 11 + dataSize + 4;
    }
  }

  int _readUint24Be(Uint8List data, int offset) => (data[offset] << 16) | (data[offset + 1] << 8) | data[offset + 2];

  int _readUint32Be(Uint8List data, int offset) =>
      (data[offset] << 24) | (data[offset + 1] << 16) | (data[offset + 2] << 8) | data[offset + 3];

  int _readTimestamp(Uint8List data, int offset) {
    // Timestamp is 24 bits + 8 bit extension for 32-bit timestamp
    final lower = _readUint24Be(data, offset);
    final upper = data[offset + 3];
    return (upper << 24) | lower;
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

    // Read tag data (skip header byte for video/audio)
    await _file.setPosition(info.fileOffset + 11);
    final rawData = await _file.read(info.dataSize);
    if (rawData.length < info.dataSize) return null;

    // Extract actual sample data
    Uint8List sampleData;

    if (info.isVideo) {
      // Video: skip frame type byte
      // For AVC, also check for AVC packet type
      if (rawData.length > 1) {
        final codecId = rawData[0] & 0x0F;
        if (codecId == FlvVideoCodec.avc && rawData.length > 5) {
          final avcPacketType = rawData[1];
          if (avcPacketType == 0) {
            // AVC sequence header - include it
            sampleData = Uint8List.sublistView(rawData, 5);
          } else {
            // AVC NALU - skip composition time offset (3 bytes)
            sampleData = Uint8List.sublistView(rawData, 5);
          }
        } else {
          sampleData = Uint8List.sublistView(rawData, 1);
        }
      } else {
        sampleData = rawData;
      }
    } else {
      // Audio: skip format byte
      // For AAC, also check for AAC packet type
      if (rawData.length > 1) {
        final codecId = (rawData[0] >> 4) & 0x0F;
        if (codecId == FlvAudioCodec.aac && rawData.length > 2) {
          final aacPacketType = rawData[1];
          if (aacPacketType == 0) {
            // AAC sequence header - audio specific config
            sampleData = Uint8List.sublistView(rawData, 2);
          } else {
            // AAC raw data
            sampleData = Uint8List.sublistView(rawData, 2);
          }
        } else {
          sampleData = Uint8List.sublistView(rawData, 1);
        }
      } else {
        sampleData = rawData;
      }
    }

    // Calculate duration
    var duration = 0;
    if (index + 1 < _sampleIndex!.length) {
      duration = _sampleIndex![index + 1].timestamp - info.timestamp;
    }

    return MediaSample(
      data: sampleData,
      trackId: _trackId,
      sampleIndex: index,
      decodeTimestamp: info.timestamp,
      compositionTimestamp: info.timestamp, // FLV uses single timestamp
      duration: duration,
      isKeyframe: info.isKeyframe,
    );
  }

  @override
  Future<int> seekToTimestamp(int timestamp, {bool toKeyframe = false}) async {
    if (_sampleIndex == null || _sampleIndex!.isEmpty) return 0;

    // Binary search for timestamp
    var low = 0;
    var high = _sampleIndex!.length - 1;

    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (_sampleIndex![mid].timestamp <= timestamp) {
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

  /// Opens an FLV file and creates a sample reader for a specific track.
  static Future<FlvSampleReader?> open(String filePath, int trackId) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    // Read header to parse metadata
    const headerSize = 256 * 1024; // 256KB should be enough
    final fileLength = await file.length();
    final readSize = fileLength < headerSize ? fileLength : headerSize;

    final headerData = await file.openRead(0, readSize).fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
    final data = Uint8List.fromList(headerData);

    final metadata = FlvParser.parse(data);
    if (metadata == null) return null;

    // Find the requested track
    final track = metadata.tracks.where((t) => t.id == trackId).firstOrNull;
    if (track == null) return null;

    // Create codec info
    final codecInfo = TrackCodecInfo(
      trackId: trackId,
      codecFourcc: track.codec.fourcc,
      timescale: 1000,
      width: track.videoInfo?.width,
      height: track.videoInfo?.height,
      sampleRate: track.audioInfo?.sampleRate,
      channelCount: track.audioInfo?.channelCount,
    );

    final isVideo = track.type == ContainerTrackType.video;

    final raf = await file.open();
    final reader = FlvSampleReader._(file: raf, trackId: trackId, codecInfo: codecInfo, isVideo: isVideo);

    await reader.buildIndex();
    return reader;
  }
}

/// Factory for creating FLV sample readers for all tracks.
class FlvSampleReaderFactory {
  FlvSampleReaderFactory._();

  /// Opens an FLV file and returns metadata and available track IDs.
  static Future<({ContainerMetadata? metadata, List<int> trackIds})?> inspect(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    const headerSize = 256 * 1024;
    final fileLength = await file.length();
    final readSize = fileLength < headerSize ? fileLength : headerSize;

    final data = await file.openRead(0, readSize).fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));

    final metadata = FlvParser.parse(Uint8List.fromList(data));
    if (metadata == null) return null;

    final trackIds = metadata.tracks.map((t) => t.id).toList();
    return (metadata: metadata, trackIds: trackIds);
  }

  /// Creates sample readers for all tracks in an FLV file.
  static Future<Map<int, FlvSampleReader>> openAll(String filePath) async {
    final inspection = await inspect(filePath);
    if (inspection == null) return {};

    final readers = <int, FlvSampleReader>{};
    for (final trackId in inspection.trackIds) {
      final reader = await FlvSampleReader.open(filePath, trackId);
      if (reader != null) {
        readers[trackId] = reader;
      }
    }

    return readers;
  }
}
