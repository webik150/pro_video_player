import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'mp4_sample_table.dart';
import 'sample_reader.dart';

/// Reads media samples from an MP4 file.
///
/// Uses a [RandomAccessFile] for efficient seeking and reading,
/// combined with sample table data for locating samples.
class Mp4SampleReader implements SampleReader {
  /// Creates an MP4 sample reader.
  ///
  /// The [file] should be opened for reading.
  /// The [sampleTable] provides sample location and timing information.
  /// The [trackId] identifies which track this reader is for.
  /// The [codecInfo] contains codec-specific information for muxing.
  Mp4SampleReader({
    required RandomAccessFile file,
    required Mp4SampleTable sampleTable,
    required int trackId,
    required TrackCodecInfo codecInfo,
  }) : _file = file,
       _sampleTable = sampleTable,
       _trackId = trackId,
       _codecInfo = codecInfo,
       _currentIndex = 0;

  final RandomAccessFile _file;
  final Mp4SampleTable _sampleTable;
  final int _trackId;
  final TrackCodecInfo _codecInfo;
  int _currentIndex;
  bool _isClosed = false;

  @override
  int get trackId => _trackId;

  @override
  int get timescale => _sampleTable.timescale;

  @override
  int get sampleCount => _sampleTable.sampleCount;

  @override
  int get totalDuration {
    if (_sampleTable.sttsEntries.isEmpty) return 0;
    var duration = 0;
    for (final entry in _sampleTable.sttsEntries) {
      duration += entry.sampleCount * entry.sampleDelta;
    }
    return duration;
  }

  @override
  bool get hasMoreSamples => _currentIndex < sampleCount;

  @override
  int get currentIndex => _currentIndex;

  /// The codec information for this track.
  TrackCodecInfo get codecInfo => _codecInfo;

  @override
  Future<MediaSample?> readNextSample() async {
    if (_isClosed || !hasMoreSamples) return null;
    return readSampleAt(_currentIndex++);
  }

  @override
  Future<MediaSample?> readSampleAt(int index) async {
    if (_isClosed || index < 0 || index >= sampleCount) return null;

    final location = _sampleTable.getSampleLocation(index);
    if (location == null) return null;

    // Seek to sample position and read data
    await _file.setPosition(location.offset);
    final data = await _file.read(location.size);

    return MediaSample(
      data: data,
      trackId: _trackId,
      sampleIndex: index,
      decodeTimestamp: _sampleTable.getDecodingTime(index),
      compositionTimestamp: _sampleTable.getCompositionTime(index),
      duration: _sampleTable.getSampleDuration(index),
      isKeyframe: _sampleTable.isSyncSample(index),
    );
  }

  @override
  Future<int> seekToTimestamp(int timestamp, {bool toKeyframe = false}) async =>
      _currentIndex = _sampleTable.findSampleAtTime(timestamp, preferKeyframe: toKeyframe);

  @override
  void seekToIndex(int index) {
    if (index < 0) {
      _currentIndex = 0;
    } else if (index >= sampleCount) {
      _currentIndex = sampleCount > 0 ? sampleCount - 1 : 0;
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

  /// Reads samples within a time range.
  ///
  /// Yields samples from [startTime] to [endTime] (in timescale units).
  /// If [startFromKeyframe] is true, starts from the nearest preceding keyframe.
  Stream<MediaSample> samplesInRange({
    required int startTime,
    required int endTime,
    bool startFromKeyframe = true,
  }) async* {
    await seekToTimestamp(startTime, toKeyframe: startFromKeyframe);

    while (hasMoreSamples && !_isClosed) {
      final sample = await readNextSample();
      if (sample == null) break;

      // Stop if we've passed the end time
      if (sample.decodeTimestamp >= endTime) break;

      yield sample;
    }
  }

  /// Reads keyframes only.
  ///
  /// Useful for generating thumbnails or seeking preview.
  Stream<MediaSample> keyframes() async* {
    if (!_sampleTable.hasExplicitSyncSamples) {
      // All samples are keyframes
      await for (final sample in samples()) {
        yield sample;
      }
      return;
    }

    for (final syncIndex in _sampleTable.syncSamples) {
      if (_isClosed) break;
      // syncSamples are 1-based indices
      final sample = await readSampleAt(syncIndex - 1);
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
}

/// Creates sample readers for all tracks in an MP4 file.
///
/// This is a factory that opens an MP4 file and creates readers
/// for each track with parsed sample tables.
class Mp4SampleReaderFactory {
  Mp4SampleReaderFactory._();

  /// Opens an MP4 file and creates sample readers for all tracks.
  ///
  /// Returns a map of track ID to sample reader.
  /// The caller is responsible for closing all readers when done.
  static Future<Map<int, Mp4SampleReader>> open(
    String filePath, {
    List<Mp4SampleTable> sampleTables = const [],
    List<TrackCodecInfo> codecInfos = const [],
  }) async {
    final file = await File(filePath).open();
    final readers = <int, Mp4SampleReader>{};

    for (var i = 0; i < sampleTables.length && i < codecInfos.length; i++) {
      final trackId = codecInfos[i].trackId;
      // Each track needs its own file handle for independent seeking
      final trackFile = await File(filePath).open();
      readers[trackId] = Mp4SampleReader(
        file: trackFile,
        sampleTable: sampleTables[i],
        trackId: trackId,
        codecInfo: codecInfos[i],
      );
    }

    // Close the initial file handle as we created per-track handles
    await file.close();

    return readers;
  }
}

/// In-memory sample reader for testing and small files.
///
/// Reads samples from a byte buffer instead of a file.
class InMemorySampleReader implements SampleReader {
  /// Creates an in-memory sample reader.
  InMemorySampleReader({required Uint8List data, required Mp4SampleTable sampleTable, required int trackId})
    : _data = data,
      _sampleTable = sampleTable,
      _trackId = trackId,
      _currentIndex = 0;

  final Uint8List _data;
  final Mp4SampleTable _sampleTable;
  final int _trackId;
  int _currentIndex;

  @override
  int get trackId => _trackId;

  @override
  int get timescale => _sampleTable.timescale;

  @override
  int get sampleCount => _sampleTable.sampleCount;

  @override
  int get totalDuration {
    var duration = 0;
    for (final entry in _sampleTable.sttsEntries) {
      duration += entry.sampleCount * entry.sampleDelta;
    }
    return duration;
  }

  @override
  bool get hasMoreSamples => _currentIndex < sampleCount;

  @override
  int get currentIndex => _currentIndex;

  @override
  Future<MediaSample?> readNextSample() async {
    if (!hasMoreSamples) return null;
    return readSampleAt(_currentIndex++);
  }

  @override
  Future<MediaSample?> readSampleAt(int index) async {
    if (index < 0 || index >= sampleCount) return null;

    final location = _sampleTable.getSampleLocation(index);
    if (location == null) return null;

    // Check bounds
    if (location.offset + location.size > _data.length) return null;

    final sampleData = Uint8List.sublistView(_data, location.offset, location.offset + location.size);

    return MediaSample(
      data: sampleData,
      trackId: _trackId,
      sampleIndex: index,
      decodeTimestamp: _sampleTable.getDecodingTime(index),
      compositionTimestamp: _sampleTable.getCompositionTime(index),
      duration: _sampleTable.getSampleDuration(index),
      isKeyframe: _sampleTable.isSyncSample(index),
    );
  }

  @override
  Future<int> seekToTimestamp(int timestamp, {bool toKeyframe = false}) async =>
      _currentIndex = _sampleTable.findSampleAtTime(timestamp, preferKeyframe: toKeyframe);

  @override
  void seekToIndex(int index) {
    if (index < 0) {
      _currentIndex = 0;
    } else if (index >= sampleCount) {
      _currentIndex = sampleCount > 0 ? sampleCount - 1 : 0;
    } else {
      _currentIndex = index;
    }
  }

  @override
  Stream<MediaSample> samples() async* {
    while (hasMoreSamples) {
      final sample = await readNextSample();
      if (sample != null) {
        yield sample;
      }
    }
  }

  @override
  Future<void> close() async {
    // No resources to release for in-memory reader
  }
}
