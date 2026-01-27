import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../container/ebml_reader.dart';
import '../container/mkv_parser.dart';
import '../types/container_metadata.dart';
import '../types/container_track.dart';
import '../types/container_track_type.dart';
import 'sample_reader.dart';

/// Additional Matroska element IDs for cluster/block parsing.
class _ClusterIds {
  _ClusterIds._();

  /// Cluster timestamp in timecode scale units.
  static const int timestamp = 0xE7;

  /// SimpleBlock - contains a single frame or group of laced frames.
  static const int simpleBlock = 0xA3;

  /// BlockGroup - container for a Block with additional info.
  static const int blockGroup = 0xA0;

  /// Block - similar to SimpleBlock but within BlockGroup.
  static const int block = 0xA1;

  /// Reference to another block (for B-frames).
  static const int referenceBlock = 0xFB;
}

/// MKV lacing types.
enum _LacingType {
  /// No lacing - single frame per block.
  none,

  /// Xiph-style variable size lacing.
  xiph,

  /// Fixed-size lacing.
  fixedSize,

  /// EBML-style variable size lacing.
  ebml,
}

/// A parsed SimpleBlock or Block from MKV.
class _MkvBlock {
  const _MkvBlock({
    required this.trackNumber,
    required this.relativeTimestamp,
    required this.isKeyframe,
    required this.frames,
  });

  final int trackNumber;
  final int relativeTimestamp;
  final bool isKeyframe;
  final List<Uint8List> frames;
}

/// Information about a sample's location and timing.
class _MkvSampleInfo {
  const _MkvSampleInfo({
    required this.clusterOffset,
    required this.blockOffset,
    required this.frameIndex,
    required this.trackNumber,
    required this.timestamp,
    required this.isKeyframe,
  });

  final int clusterOffset;
  final int blockOffset;
  final int frameIndex;
  final int trackNumber;
  final int timestamp;
  final bool isKeyframe;
}

/// Reads media samples from an MKV/WebM file.
///
/// Parses Cluster and Block elements to extract individual samples
/// with proper timing information.
class MkvSampleReader implements SampleReader {
  MkvSampleReader._({
    required RandomAccessFile file,
    required Uint8List headerData,
    required int trackId,
    required TrackCodecInfo codecInfo,
    required int timecodeScale,
    required int segmentDataOffset,
  }) : _file = file,
       _headerData = headerData,
       _trackId = trackId,
       _codecInfo = codecInfo,
       _timecodeScale = timecodeScale,
       _segmentDataOffset = segmentDataOffset;

  final RandomAccessFile _file;
  final Uint8List _headerData;
  final int _trackId;
  final TrackCodecInfo _codecInfo;
  final int _timecodeScale;
  final int _segmentDataOffset;

  List<_MkvSampleInfo>? _sampleIndex;
  int _currentIndex = 0;
  bool _isClosed = false;

  @override
  int get trackId => _trackId;

  @override
  int get timescale => 1000000 ~/ _timecodeScale; // Samples per second

  @override
  int get sampleCount => _sampleIndex?.length ?? 0;

  @override
  int get totalDuration {
    if (_sampleIndex == null || _sampleIndex!.isEmpty) return 0;
    return _sampleIndex!.last.timestamp;
  }

  @override
  bool get hasMoreSamples => _sampleIndex != null && _currentIndex < _sampleIndex!.length;

  @override
  int get currentIndex => _currentIndex;

  /// The codec information for this track.
  TrackCodecInfo get codecInfo => _codecInfo;

  /// Builds the sample index by scanning all clusters.
  ///
  /// This must be called before reading samples.
  Future<void> buildIndex() async {
    if (_sampleIndex != null) return;

    _sampleIndex = [];
    await _scanClusters();
  }

  Future<void> _scanClusters() async {
    final reader = EbmlReader(_headerData);

    // Skip EBML header
    final ebmlElement = reader.readElement();
    if (ebmlElement == null) return;
    reader.position = ebmlElement.dataOffset + ebmlElement.dataSize;

    // Find Segment
    final segmentElement = reader.readElement();
    if (segmentElement == null || segmentElement.id != EbmlIds.segment) return;

    // Scan segment for clusters (in header data first)
    final segmentEnd = segmentElement.dataOffset + segmentElement.dataSize;
    final headerEnd = _headerData.length;

    while (reader.position < segmentEnd && reader.position < headerEnd) {
      final element = reader.readElement();
      if (element == null) break;

      if (element.id == EbmlIds.cluster) {
        await _parseCluster(reader, element);
      } else {
        reader.skip(element.dataSize);
      }
    }

    // If we haven't found clusters in header, scan file directly
    if (_sampleIndex!.isEmpty) {
      await _scanClustersFromFile();
    }
  }

  Future<void> _scanClustersFromFile() async {
    // Read file in chunks to find clusters
    const chunkSize = 1024 * 1024; // 1MB chunks
    final fileLength = await _file.length();
    var position = _segmentDataOffset;

    while (position < fileLength) {
      await _file.setPosition(position);
      final remaining = fileLength - position;
      final readSize = remaining < chunkSize ? remaining : chunkSize;
      final chunk = await _file.read(readSize);

      final reader = EbmlReader(chunk);
      while (reader.hasMore) {
        final elementStart = reader.position;
        final element = reader.readElement();
        if (element == null) break;

        if (element.id == EbmlIds.cluster) {
          // Read full cluster if it extends beyond our chunk
          final clusterEnd = element.dataOffset + element.dataSize;
          if (clusterEnd > chunk.length) {
            // Need to read the full cluster
            await _file.setPosition(position + elementStart);
            final fullCluster = await _file.read(element.totalSize);
            final clusterReader = EbmlReader(fullCluster);
            clusterReader.readElement(); // Skip header
            await _parseClusterFromData(clusterReader, element, position + elementStart);
          } else {
            await _parseClusterFromData(reader, element, position + elementStart);
          }

          position += elementStart + element.totalSize;
          break;
        } else if (_isTopLevelElement(element.id)) {
          reader.skip(element.dataSize);
        } else {
          // Unknown element or corrupted data, try to continue
          position += elementStart + 1;
          break;
        }
      }

      if (!reader.hasMore) {
        position += chunk.length;
      }
    }
  }

  bool _isTopLevelElement(int id) =>
      id == EbmlIds.seekHead ||
      id == EbmlIds.info ||
      id == EbmlIds.tracks ||
      id == EbmlIds.chapters ||
      id == EbmlIds.cluster ||
      id == EbmlIds.cues ||
      id == EbmlIds.attachments ||
      id == EbmlIds.tags;

  Future<void> _parseCluster(EbmlReader reader, EbmlElement clusterElement) async {
    await _parseClusterFromData(reader, clusterElement, clusterElement.dataOffset - clusterElement.headerSize);
  }

  Future<void> _parseClusterFromData(EbmlReader reader, EbmlElement clusterElement, int clusterFileOffset) async {
    final clusterEnd = clusterElement.dataOffset + clusterElement.dataSize;
    var clusterTimestamp = 0;

    while (reader.position < clusterEnd && reader.hasMore) {
      final blockStart = reader.position;
      final element = reader.readElement();
      if (element == null) break;

      switch (element.id) {
        case _ClusterIds.timestamp:
          clusterTimestamp = reader.readUint(element.dataSize);

        case _ClusterIds.simpleBlock:
          final blockData = reader.readBinary(element.dataSize);
          final block = _parseSimpleBlock(blockData);
          if (block != null && block.trackNumber == _trackId) {
            final absoluteTimestamp = clusterTimestamp + block.relativeTimestamp;
            for (var i = 0; i < block.frames.length; i++) {
              _sampleIndex!.add(
                _MkvSampleInfo(
                  clusterOffset: clusterFileOffset,
                  blockOffset: blockStart,
                  frameIndex: i,
                  trackNumber: block.trackNumber,
                  timestamp: absoluteTimestamp,
                  isKeyframe: block.isKeyframe,
                ),
              );
            }
          }

        case _ClusterIds.blockGroup:
          final blockGroupEnd = element.dataOffset + element.dataSize;
          _MkvBlock? block;
          var isKeyframe = true; // Assume keyframe unless ReferenceBlock present

          while (reader.position < blockGroupEnd) {
            final groupElement = reader.readElement();
            if (groupElement == null) break;

            switch (groupElement.id) {
              case _ClusterIds.block:
                final blockData = reader.readBinary(groupElement.dataSize);
                block = _parseBlock(blockData);

              case _ClusterIds.referenceBlock:
                // Presence of ReferenceBlock means not a keyframe
                isKeyframe = false;
                reader.skip(groupElement.dataSize);

              default:
                reader.skip(groupElement.dataSize);
            }
          }

          if (block != null && block.trackNumber == _trackId) {
            final absoluteTimestamp = clusterTimestamp + block.relativeTimestamp;
            for (var i = 0; i < block.frames.length; i++) {
              _sampleIndex!.add(
                _MkvSampleInfo(
                  clusterOffset: clusterFileOffset,
                  blockOffset: blockStart,
                  frameIndex: i,
                  trackNumber: block.trackNumber,
                  timestamp: absoluteTimestamp,
                  isKeyframe: isKeyframe,
                ),
              );
            }
          }

        default:
          reader.skip(element.dataSize);
      }
    }
  }

  /// Parses a SimpleBlock and extracts frames.
  _MkvBlock? _parseSimpleBlock(Uint8List data) {
    if (data.length < 4) return null;

    var offset = 0;

    // Track number (VINT)
    final trackNumber = _readVint(data, offset);
    if (trackNumber == null) return null;
    offset += trackNumber.length;

    // Relative timestamp (signed 16-bit)
    if (offset + 2 > data.length) return null;
    final relativeTimestamp = (data[offset] << 8) | data[offset + 1];
    // Convert to signed
    final signedTimestamp = relativeTimestamp > 0x7FFF ? relativeTimestamp - 0x10000 : relativeTimestamp;
    offset += 2;

    // Flags
    if (offset >= data.length) return null;
    final flags = data[offset++];
    final isKeyframe = (flags & 0x80) != 0;
    final lacingType = _getLacingType((flags >> 1) & 0x03);

    // Parse frames based on lacing
    final frameData = Uint8List.sublistView(data, offset);
    final frames = _parseFrames(frameData, lacingType);

    return _MkvBlock(
      trackNumber: trackNumber.value,
      relativeTimestamp: signedTimestamp,
      isKeyframe: isKeyframe,
      frames: frames,
    );
  }

  /// Parses a Block (within BlockGroup).
  _MkvBlock? _parseBlock(Uint8List data) {
    if (data.length < 4) return null;

    var offset = 0;

    // Track number (VINT)
    final trackNumber = _readVint(data, offset);
    if (trackNumber == null) return null;
    offset += trackNumber.length;

    // Relative timestamp (signed 16-bit)
    if (offset + 2 > data.length) return null;
    final relativeTimestamp = (data[offset] << 8) | data[offset + 1];
    final signedTimestamp = relativeTimestamp > 0x7FFF ? relativeTimestamp - 0x10000 : relativeTimestamp;
    offset += 2;

    // Flags
    if (offset >= data.length) return null;
    final flags = data[offset++];
    final lacingType = _getLacingType((flags >> 1) & 0x03);

    // Parse frames
    final frameData = Uint8List.sublistView(data, offset);
    final frames = _parseFrames(frameData, lacingType);

    // Keyframe is determined by BlockGroup's ReferenceBlock presence
    return _MkvBlock(
      trackNumber: trackNumber.value,
      relativeTimestamp: signedTimestamp,
      isKeyframe: true,
      frames: frames,
    );
  }

  _LacingType _getLacingType(int value) => switch (value) {
    0 => _LacingType.none,
    1 => _LacingType.xiph,
    2 => _LacingType.fixedSize,
    3 => _LacingType.ebml,
    _ => _LacingType.none,
  };

  List<Uint8List> _parseFrames(Uint8List data, _LacingType lacingType) {
    if (lacingType == _LacingType.none) {
      return [data];
    }

    if (data.isEmpty) return [];

    // Number of frames (0-based, so add 1)
    final frameCount = data[0] + 1;
    if (frameCount == 1) {
      return [Uint8List.sublistView(data, 1)];
    }

    var offset = 1;
    final frameSizes = <int>[];

    switch (lacingType) {
      case _LacingType.xiph:
        // Xiph lacing: sizes encoded as sum of 255s + final byte
        for (var i = 0; i < frameCount - 1; i++) {
          var size = 0;
          while (offset < data.length && data[offset] == 255) {
            size += 255;
            offset++;
          }
          if (offset < data.length) {
            size += data[offset++];
          }
          frameSizes.add(size);
        }

      case _LacingType.fixedSize:
        // All frames same size
        final totalSize = data.length - offset;
        final frameSize = totalSize ~/ frameCount;
        for (var i = 0; i < frameCount - 1; i++) {
          frameSizes.add(frameSize);
        }

      case _LacingType.ebml:
        // EBML lacing: first size as VINT, then deltas as signed VINTs
        if (offset >= data.length) return [];
        final firstSize = _readVint(data, offset);
        if (firstSize == null) return [];
        frameSizes.add(firstSize.value);
        offset += firstSize.length;

        for (var i = 1; i < frameCount - 1; i++) {
          final delta = _readSignedVint(data, offset);
          if (delta == null) break;
          final prevSize = frameSizes.last;
          frameSizes.add(prevSize + delta.value);
          offset += delta.length;
        }

      case _LacingType.none:
        return [data];
    }

    // Calculate last frame size
    final usedSize = frameSizes.fold<int>(0, (sum, size) => sum + size);
    final lastSize = data.length - offset - usedSize;
    frameSizes.add(lastSize);

    // Extract frames
    final frames = <Uint8List>[];
    for (final size in frameSizes) {
      if (offset + size > data.length) break;
      frames.add(Uint8List.sublistView(data, offset, offset + size));
      offset += size;
    }

    return frames;
  }

  ({int value, int length})? _readVint(Uint8List data, int offset) {
    if (offset >= data.length) return null;
    final firstByte = data[offset];
    if (firstByte == 0) return null;

    final length = _vintLength(firstByte);
    if (offset + length > data.length) return null;

    final mask = _vintMask(length);
    var value = firstByte & mask;
    for (var i = 1; i < length; i++) {
      value = (value << 8) | data[offset + i];
    }

    return (value: value, length: length);
  }

  ({int value, int length})? _readSignedVint(Uint8List data, int offset) {
    final result = _readVint(data, offset);
    if (result == null) return null;

    // Convert to signed using EBML signed VINT encoding
    // The bias is (2^(7*length-1) - 1)
    final bias = (1 << (7 * result.length - 1)) - 1;
    final signedValue = result.value - bias;

    return (value: signedValue, length: result.length);
  }

  int _vintLength(int firstByte) {
    if (firstByte & 0x80 != 0) return 1;
    if (firstByte & 0x40 != 0) return 2;
    if (firstByte & 0x20 != 0) return 3;
    if (firstByte & 0x10 != 0) return 4;
    if (firstByte & 0x08 != 0) return 5;
    if (firstByte & 0x04 != 0) return 6;
    if (firstByte & 0x02 != 0) return 7;
    if (firstByte & 0x01 != 0) return 8;
    return 1;
  }

  int _vintMask(int length) => switch (length) {
    1 => 0x7F,
    2 => 0x3F,
    3 => 0x1F,
    4 => 0x0F,
    5 => 0x07,
    6 => 0x03,
    7 => 0x01,
    8 => 0x00,
    _ => 0x7F,
  };

  @override
  Future<MediaSample?> readNextSample() async {
    if (_isClosed || _sampleIndex == null || !hasMoreSamples) return null;
    return readSampleAt(_currentIndex++);
  }

  @override
  Future<MediaSample?> readSampleAt(int index) async {
    if (_isClosed || _sampleIndex == null || index < 0 || index >= _sampleIndex!.length) return null;

    final info = _sampleIndex![index];

    // Read the block from file
    await _file.setPosition(info.clusterOffset);

    // We need to re-parse the cluster to get the actual frame data
    // This is less efficient but works for now
    // TODO: Cache cluster data for better performance
    final clusterHeader = await _file.read(12); // Max EBML element header
    final headerReader = EbmlReader(clusterHeader);
    final clusterElement = headerReader.readElement();
    if (clusterElement == null || clusterElement.id != EbmlIds.cluster) return null;

    await _file.setPosition(info.clusterOffset);
    final clusterData = await _file.read(clusterElement.totalSize);

    final reader = EbmlReader(clusterData);
    reader.readElement(); // Skip cluster header

    final clusterEnd = clusterElement.totalSize;
    var clusterTimestamp = 0;

    while (reader.position < clusterEnd) {
      final element = reader.readElement();
      if (element == null) break;

      switch (element.id) {
        case _ClusterIds.timestamp:
          clusterTimestamp = reader.readUint(element.dataSize);

        case _ClusterIds.simpleBlock:
          final blockData = reader.readBinary(element.dataSize);
          final block = _parseSimpleBlock(blockData);
          if (block != null && block.trackNumber == _trackId) {
            final absoluteTimestamp = clusterTimestamp + block.relativeTimestamp;
            if (absoluteTimestamp == info.timestamp && info.frameIndex < block.frames.length) {
              return _createSample(index, block.frames[info.frameIndex], absoluteTimestamp, block.isKeyframe);
            }
          }

        case _ClusterIds.blockGroup:
          final blockGroupEnd = element.dataOffset + element.dataSize;
          _MkvBlock? block;
          var isKeyframe = true;

          while (reader.position < blockGroupEnd) {
            final groupElement = reader.readElement();
            if (groupElement == null) break;

            switch (groupElement.id) {
              case _ClusterIds.block:
                final blockData = reader.readBinary(groupElement.dataSize);
                block = _parseBlock(blockData);

              case _ClusterIds.referenceBlock:
                isKeyframe = false;
                reader.skip(groupElement.dataSize);

              default:
                reader.skip(groupElement.dataSize);
            }
          }

          if (block != null && block.trackNumber == _trackId) {
            final absoluteTimestamp = clusterTimestamp + block.relativeTimestamp;
            if (absoluteTimestamp == info.timestamp && info.frameIndex < block.frames.length) {
              return _createSample(index, block.frames[info.frameIndex], absoluteTimestamp, isKeyframe);
            }
          }

        default:
          reader.skip(element.dataSize);
      }
    }

    return null;
  }

  MediaSample _createSample(int index, Uint8List data, int timestamp, bool isKeyframe) {
    // Convert timestamp from timecode scale to microseconds
    final timestampUs = timestamp * _timecodeScale ~/ 1000;

    // Calculate duration to next sample
    var duration = 0;
    if (index + 1 < _sampleIndex!.length) {
      final nextTimestamp = _sampleIndex![index + 1].timestamp;
      duration = (nextTimestamp - timestamp) * _timecodeScale ~/ 1000;
    }

    return MediaSample(
      data: data,
      trackId: _trackId,
      sampleIndex: index,
      decodeTimestamp: timestampUs,
      compositionTimestamp: timestampUs, // MKV doesn't have separate PTS/DTS
      duration: duration,
      isKeyframe: isKeyframe,
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
      // Search backwards for keyframe
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

  /// Opens an MKV file and creates a sample reader for a specific track.
  static Future<MkvSampleReader?> open(String filePath, int trackId) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    // Read header (first 10MB should contain all metadata)
    const maxHeaderSize = 10 * 1024 * 1024;
    final fileLength = await file.length();
    final headerSize = fileLength < maxHeaderSize ? fileLength : maxHeaderSize;

    final raf = await file.open();
    final headerData = await raf.read(headerSize);

    // Parse metadata
    final metadata = MkvParser.parse(headerData);
    if (metadata == null) {
      await raf.close();
      return null;
    }

    // Find the requested track
    final track = metadata.tracks.where((t) => t.id == trackId).firstOrNull;
    if (track == null) {
      await raf.close();
      return null;
    }

    // Get timecode scale
    final timecodeScale = _getTimecodeScale(headerData);

    // Find segment data offset
    final segmentDataOffset = _findSegmentDataOffset(headerData);

    // Create codec info
    final codecInfo = _createCodecInfo(headerData, track, trackId);

    final reader = MkvSampleReader._(
      file: raf,
      headerData: headerData,
      trackId: trackId,
      codecInfo: codecInfo,
      timecodeScale: timecodeScale,
      segmentDataOffset: segmentDataOffset,
    );

    await reader.buildIndex();
    return reader;
  }

  static int _getTimecodeScale(Uint8List data) {
    final reader = EbmlReader(data);

    // Skip EBML header
    final ebmlElement = reader.readElement();
    if (ebmlElement == null) return 1000000;
    reader.position = ebmlElement.dataOffset + ebmlElement.dataSize;

    // Find Segment
    final segmentElement = reader.readElement();
    if (segmentElement == null || segmentElement.id != EbmlIds.segment) return 1000000;

    final segmentEnd = segmentElement.dataOffset + segmentElement.dataSize;

    while (reader.position < segmentEnd && reader.hasMore) {
      final element = reader.readElement();
      if (element == null) break;

      if (element.id == EbmlIds.info) {
        final infoEnd = element.dataOffset + element.dataSize;
        while (reader.position < infoEnd) {
          final infoChild = reader.readElement();
          if (infoChild == null) break;

          if (infoChild.id == MatroskaIds.timecodeScale) {
            return reader.readUint(infoChild.dataSize);
          }
          reader.skip(infoChild.dataSize);
        }
        break;
      }

      reader.skip(element.dataSize);
    }

    return 1000000; // Default 1ms
  }

  static int _findSegmentDataOffset(Uint8List data) {
    final reader = EbmlReader(data);

    // Skip EBML header
    final ebmlElement = reader.readElement();
    if (ebmlElement == null) return 0;
    reader.position = ebmlElement.dataOffset + ebmlElement.dataSize;

    // Find Segment
    final segmentElement = reader.readElement();
    if (segmentElement == null) return 0;

    return segmentElement.dataOffset;
  }

  static TrackCodecInfo _createCodecInfo(Uint8List data, ContainerTrack track, int trackId) {
    // Extract codec private data if available
    Uint8List? codecPrivate;
    final reader = EbmlReader(data);

    // Skip EBML header
    final ebmlElement = reader.readElement();
    if (ebmlElement != null) {
      reader.position = ebmlElement.dataOffset + ebmlElement.dataSize;

      // Find Segment
      final segmentElement = reader.readElement();
      if (segmentElement != null && segmentElement.id == EbmlIds.segment) {
        final segmentEnd = segmentElement.dataOffset + segmentElement.dataSize;

        while (reader.position < segmentEnd && reader.hasMore) {
          final element = reader.readElement();
          if (element == null) break;

          if (element.id == EbmlIds.tracks) {
            codecPrivate = _findCodecPrivate(reader, element, trackId);
            break;
          }
          reader.skip(element.dataSize);
        }
      }
    }

    // Build codec info based on track type
    final codecFourcc = track.codec.fourcc;
    final videoInfo = track.videoInfo;
    final audioInfo = track.audioInfo;

    if (track.type == ContainerTrackType.video && videoInfo != null) {
      return TrackCodecInfo(
        trackId: trackId,
        codecFourcc: codecFourcc,
        timescale: 1000000, // MKV uses nanoseconds, we normalize to microseconds
        codecPrivateData: codecPrivate,
        width: videoInfo.width,
        height: videoInfo.height,
      );
    } else if (track.type == ContainerTrackType.audio && audioInfo != null) {
      return TrackCodecInfo(
        trackId: trackId,
        codecFourcc: codecFourcc,
        timescale: 1000000,
        codecPrivateData: codecPrivate,
        sampleRate: audioInfo.sampleRate,
        channelCount: audioInfo.channelCount,
      );
    }

    return TrackCodecInfo(
      trackId: trackId,
      codecFourcc: codecFourcc,
      timescale: 1000000,
      codecPrivateData: codecPrivate,
    );
  }

  static Uint8List? _findCodecPrivate(EbmlReader reader, EbmlElement tracksElement, int trackId) {
    final tracksEnd = tracksElement.dataOffset + tracksElement.dataSize;

    while (reader.position < tracksEnd) {
      final element = reader.readElement();
      if (element == null) break;

      if (element.id == MatroskaIds.trackEntry) {
        final result = _parseTrackEntryForCodecPrivate(reader, element, trackId);
        if (result != null) return result;
      } else {
        reader.skip(element.dataSize);
      }
    }

    return null;
  }

  static Uint8List? _parseTrackEntryForCodecPrivate(EbmlReader reader, EbmlElement trackElement, int targetTrackId) {
    final trackEnd = trackElement.dataOffset + trackElement.dataSize;
    int? foundTrackNumber;
    Uint8List? codecPrivate;

    while (reader.position < trackEnd) {
      final element = reader.readElement();
      if (element == null) break;

      switch (element.id) {
        case MatroskaIds.trackNumber:
          foundTrackNumber = reader.readUint(element.dataSize);

        case MatroskaIds.codecPrivate:
          codecPrivate = reader.readBinary(element.dataSize);

        default:
          reader.skip(element.dataSize);
      }
    }

    if (foundTrackNumber == targetTrackId) {
      return codecPrivate;
    }
    return null;
  }
}

/// Factory for creating MKV sample readers for all tracks.
class MkvSampleReaderFactory {
  MkvSampleReaderFactory._();

  /// Opens an MKV file and returns metadata and available track IDs.
  static Future<({ContainerMetadata? metadata, List<int> trackIds})?> inspect(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    const maxHeaderSize = 10 * 1024 * 1024;
    final fileLength = await file.length();
    final headerSize = fileLength < maxHeaderSize ? fileLength : maxHeaderSize;

    final data = await file.openRead(0, headerSize).fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));

    final metadata = MkvParser.parse(Uint8List.fromList(data));
    if (metadata == null) return null;

    final trackIds = metadata.tracks.map((t) => t.id).toList();
    return (metadata: metadata, trackIds: trackIds);
  }

  /// Creates sample readers for all tracks in an MKV file.
  static Future<Map<int, MkvSampleReader>> openAll(String filePath) async {
    final inspection = await inspect(filePath);
    if (inspection == null) return {};

    final readers = <int, MkvSampleReader>{};
    for (final trackId in inspection.trackIds) {
      final reader = await MkvSampleReader.open(filePath, trackId);
      if (reader != null) {
        readers[trackId] = reader;
      }
    }

    return readers;
  }
}
