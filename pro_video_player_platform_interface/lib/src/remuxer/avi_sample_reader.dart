import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../container/avi_parser.dart';
import '../types/container_metadata.dart';
import 'sample_reader.dart';

/// Information about an AVI sample from idx1 index.
class _AviSampleInfo {
  const _AviSampleInfo({
    required this.fileOffset,
    required this.size,
    required this.isKeyframe,
    required this.streamIndex,
  });

  final int fileOffset;
  final int size;
  final bool isKeyframe;
  final int streamIndex;
}

/// Reads media samples from an AVI file.
///
/// Parses idx1 index and extracts samples from movi chunks.
class AviSampleReader implements SampleReader {
  AviSampleReader._({
    required RandomAccessFile file,
    required int trackId,
    required TrackCodecInfo codecInfo,
    required int streamIndex,
    required double frameRate,
  }) : _file = file,
       _trackId = trackId,
       _codecInfo = codecInfo,
       _streamIndex = streamIndex,
       _frameRate = frameRate;

  final RandomAccessFile _file;
  final int _trackId;
  final TrackCodecInfo _codecInfo;
  final int _streamIndex;
  final double _frameRate;

  List<_AviSampleInfo>? _sampleIndex;
  int _currentIndex = 0;
  bool _isClosed = false;

  @override
  int get trackId => _trackId;

  @override
  int get timescale => _frameRate > 0 ? _frameRate.round() : 1000;

  @override
  int get sampleCount => _sampleIndex?.length ?? 0;

  @override
  int get totalDuration {
    if (_sampleIndex == null || _sampleIndex!.isEmpty || _frameRate <= 0) return 0;
    // Duration = sample count / frame rate * timescale
    return (_sampleIndex!.length * timescale / _frameRate).round();
  }

  @override
  bool get hasMoreSamples => _sampleIndex != null && _currentIndex < _sampleIndex!.length;

  @override
  int get currentIndex => _currentIndex;

  /// The codec information for this track.
  TrackCodecInfo get codecInfo => _codecInfo;

  /// Builds the sample index by parsing idx1 chunk.
  Future<void> buildIndex() async {
    if (_sampleIndex != null) return;

    _sampleIndex = [];
    final fileLength = await _file.length();

    // Find idx1 chunk by scanning from the end of file
    // Or scan through RIFF structure
    await _file.setPosition(0);
    final header = await _file.read(12);
    if (header.length < 12) return;

    var offset = 12; // After RIFF header + AVI type
    var moviOffset = 0;

    // Scan for movi and idx1 chunks
    while (offset + 8 < fileLength) {
      await _file.setPosition(offset);
      final chunkHeader = await _file.read(8);
      if (chunkHeader.length < 8) break;

      final chunkId = _readFourcc(chunkHeader, 0);
      final chunkSize = _readUint32Le(chunkHeader, 4);

      if (chunkId == 'LIST') {
        // Read list type
        final listTypeData = await _file.read(4);
        if (listTypeData.length < 4) break;
        final listType = _readFourcc(listTypeData, 0);

        if (listType == 'movi') {
          moviOffset = offset + 12; // Skip LIST header + 'movi'
        }
      } else if (chunkId == 'idx1') {
        // Parse index
        await _parseIdx1(offset + 8, chunkSize, moviOffset);
        break;
      }

      // Move to next chunk
      offset += 8 + chunkSize + (chunkSize & 1);
      if (chunkSize == 0) break;
    }

    // If no idx1 found, scan movi for samples
    if (_sampleIndex!.isEmpty && moviOffset > 0) {
      await _scanMoviChunk(moviOffset, fileLength);
    }
  }

  Future<void> _parseIdx1(int offset, int size, int moviOffset) async {
    await _file.setPosition(offset);
    final indexData = await _file.read(size);
    if (indexData.length < size) return;

    final entryCount = size ~/ 16;

    for (var i = 0; i < entryCount; i++) {
      final entryOffset = i * 16;

      final chunkId = _readFourcc(indexData, entryOffset);
      final flags = _readUint32Le(indexData, entryOffset + 4);
      var chunkOffset = _readUint32Le(indexData, entryOffset + 8);
      final chunkSize = _readUint32Le(indexData, entryOffset + 12);

      // Check if this entry is for our stream
      if (!_matchesStreamIndex(chunkId, _streamIndex)) continue;

      // Offset in idx1 can be relative to movi or absolute
      // Usually it's relative to movi data start
      if (moviOffset > 0 && chunkOffset < moviOffset) {
        chunkOffset += moviOffset;
      }

      final isKeyframe = (flags & 0x10) != 0; // AVIIF_KEYFRAME

      _sampleIndex!.add(
        _AviSampleInfo(
          fileOffset: chunkOffset + 8, // Skip chunk header
          size: chunkSize,
          isKeyframe: isKeyframe,
          streamIndex: _streamIndex,
        ),
      );
    }
  }

  Future<void> _scanMoviChunk(int moviStart, int fileLength) async {
    var offset = moviStart;

    while (offset + 8 < fileLength) {
      await _file.setPosition(offset);
      final chunkHeader = await _file.read(8);
      if (chunkHeader.length < 8) break;

      final chunkId = _readFourcc(chunkHeader, 0);
      final chunkSize = _readUint32Le(chunkHeader, 4);

      // Check if this is data for our stream
      if (_matchesStreamIndex(chunkId, _streamIndex)) {
        // Determine keyframe (first frame is always keyframe)
        final isKeyframe = _sampleIndex!.isEmpty;

        _sampleIndex!.add(
          _AviSampleInfo(fileOffset: offset + 8, size: chunkSize, isKeyframe: isKeyframe, streamIndex: _streamIndex),
        );
      } else if (chunkId == 'LIST') {
        // Skip nested lists
        offset += 12;
        continue;
      } else if (chunkId == 'idx1' || chunkId == 'JUNK') {
        // End of movi
        break;
      }

      offset += 8 + chunkSize + (chunkSize & 1);
      if (chunkSize == 0) break;
    }
  }

  bool _matchesStreamIndex(String chunkId, int streamIndex) {
    if (chunkId.length != 4) return false;

    // Parse stream index from chunk ID (e.g., "00dc", "01wb")
    final indexStr = chunkId.substring(0, 2);
    final parsedIndex = int.tryParse(indexStr);
    if (parsedIndex == null) return false;

    return parsedIndex == streamIndex;
  }

  String _readFourcc(Uint8List data, int offset) {
    if (offset + 4 > data.length) return '';
    return String.fromCharCodes(data.sublist(offset, offset + 4));
  }

  int _readUint32Le(Uint8List data, int offset) {
    if (offset + 4 > data.length) return 0;
    return data[offset] | (data[offset + 1] << 8) | (data[offset + 2] << 16) | (data[offset + 3] << 24);
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

    // Read sample data
    await _file.setPosition(info.fileOffset);
    final data = await _file.read(info.size);
    if (data.length < info.size) return null;

    // Calculate timestamp and duration
    final timestamp = _frameRate > 0 ? (index * timescale / _frameRate).round() : index;
    final duration = _frameRate > 0 ? (timescale / _frameRate).round() : 1;

    return MediaSample(
      data: data,
      trackId: _trackId,
      sampleIndex: index,
      decodeTimestamp: timestamp,
      compositionTimestamp: timestamp,
      duration: duration,
      isKeyframe: info.isKeyframe,
    );
  }

  @override
  Future<int> seekToTimestamp(int timestamp, {bool toKeyframe = false}) async {
    if (_sampleIndex == null || _sampleIndex!.isEmpty || _frameRate <= 0) return 0;

    // Convert timestamp to sample index
    final targetIndex = (timestamp * _frameRate / timescale).round();
    var index = targetIndex.clamp(0, _sampleIndex!.length - 1);

    if (toKeyframe) {
      while (index > 0 && !_sampleIndex![index].isKeyframe) {
        index--;
      }
    }

    return _currentIndex = index;
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

  /// Opens an AVI file and creates a sample reader for a specific track.
  static Future<AviSampleReader?> open(String filePath, int trackId) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    // Read header to parse metadata
    const headerSize = 1024 * 1024; // 1MB should be enough for headers
    final fileLength = await file.length();
    final readSize = fileLength < headerSize ? fileLength : headerSize;

    final headerData = await file.openRead(0, readSize).fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
    final data = Uint8List.fromList(headerData);

    final metadata = AviParser.parse(data);
    if (metadata == null) return null;

    // Find the requested track
    final track = metadata.tracks.where((t) => t.id == trackId).firstOrNull;
    if (track == null) return null;

    // Stream index is track ID - 1 (0-based)
    final streamIndex = trackId - 1;

    // Get frame rate
    final audioInfo = track.audioInfo;
    final frameRate = track.videoInfo?.frameRate ?? (audioInfo != null ? audioInfo.sampleRate.toDouble() / 1000 : 0);

    // Create codec info
    final codecInfo = TrackCodecInfo(
      trackId: trackId,
      codecFourcc: track.codec.fourcc,
      timescale: frameRate > 0 ? frameRate.round() : 1000,
      width: track.videoInfo?.width,
      height: track.videoInfo?.height,
      sampleRate: track.audioInfo?.sampleRate,
      channelCount: track.audioInfo?.channelCount,
    );

    final raf = await file.open();
    final reader = AviSampleReader._(
      file: raf,
      trackId: trackId,
      codecInfo: codecInfo,
      streamIndex: streamIndex,
      frameRate: frameRate,
    );

    await reader.buildIndex();
    return reader;
  }
}

/// Factory for creating AVI sample readers for all tracks.
class AviSampleReaderFactory {
  AviSampleReaderFactory._();

  /// Opens an AVI file and returns metadata and available track IDs.
  static Future<({ContainerMetadata? metadata, List<int> trackIds})?> inspect(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    const headerSize = 1024 * 1024;
    final fileLength = await file.length();
    final readSize = fileLength < headerSize ? fileLength : headerSize;

    final data = await file.openRead(0, readSize).fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));

    final metadata = AviParser.parse(Uint8List.fromList(data));
    if (metadata == null) return null;

    final trackIds = metadata.tracks.map((t) => t.id).toList();
    return (metadata: metadata, trackIds: trackIds);
  }

  /// Creates sample readers for all tracks in an AVI file.
  static Future<Map<int, AviSampleReader>> openAll(String filePath) async {
    final inspection = await inspect(filePath);
    if (inspection == null) return {};

    final readers = <int, AviSampleReader>{};
    for (final trackId in inspection.trackIds) {
      final reader = await AviSampleReader.open(filePath, trackId);
      if (reader != null) {
        readers[trackId] = reader;
      }
    }

    return readers;
  }
}
