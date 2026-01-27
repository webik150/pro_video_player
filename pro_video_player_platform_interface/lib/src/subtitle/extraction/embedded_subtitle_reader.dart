import 'dart:io';
import 'dart:typed_data';

import '../../container/container_parser.dart';
import '../../remuxer/mkv_sample_reader.dart';
import '../../remuxer/mp4_sample_reader.dart';
import '../../remuxer/mp4_sample_table.dart';
import '../../remuxer/sample_reader.dart';
import '../../types/container_metadata.dart';
import '../../types/container_track.dart';
import '../../types/container_track_type.dart';
import '../../types/embedded_subtitle_track.dart';
import '../../types/subtitle_cue.dart';
import 'subtitle_sample_decoder.dart';

/// Reads embedded subtitle samples from container files.
///
/// Wraps [SampleReader] implementations for MP4 and MKV containers,
/// providing a unified interface for extracting subtitle samples
/// and converting them to [SubtitleCue] objects.
///
/// Example:
/// ```dart
/// final reader = await EmbeddedSubtitleReader.open('/path/to/video.mp4', trackId: 3);
/// if (reader != null) {
///   final cues = await reader.extractAll();
///   for (final cue in cues) {
///     print('${cue.start} - ${cue.end}: ${cue.text}');
///   }
///   await reader.close();
/// }
/// ```
class EmbeddedSubtitleReader {
  EmbeddedSubtitleReader._({
    required SampleReader sampleReader,
    required SubtitleSampleDecoder decoder,
    required this.codecInfo,
  }) : _sampleReader = sampleReader,
       _decoder = decoder;

  final SampleReader _sampleReader;
  final SubtitleSampleDecoder _decoder;

  /// Codec information for this subtitle track.
  final TrackCodecInfo codecInfo;

  /// Track ID this reader is associated with.
  int get trackId => _sampleReader.trackId;

  /// Total number of subtitle samples.
  int get sampleCount => _sampleReader.sampleCount;

  /// Whether there are more samples to read.
  bool get hasMoreSamples => _sampleReader.hasMoreSamples;

  /// Opens a subtitle track from a file.
  ///
  /// Parameters:
  /// - [filePath]: Path to the container file
  /// - [trackId]: ID of the subtitle track to read
  ///
  /// Returns null if:
  /// - The file doesn't exist or can't be opened
  /// - The track ID doesn't exist or isn't a subtitle track
  /// - No decoder is available for the track's codec
  static Future<EmbeddedSubtitleReader?> open(String filePath, {required int trackId}) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    // Detect container format
    final raf = await file.open();
    final format = await ContainerParser.detectFormatFile(raf);
    await raf.close();

    if (format == null) return null;

    // Open appropriate sample reader based on format
    if (format == 'mkv' || format == 'webm') {
      return _openMkv(filePath, trackId);
    } else if (format == 'mp4' || format == 'mov' || format == 'm4a' || format == 'm4v' || format == '3gp') {
      return _openMp4(filePath, trackId);
    }

    // Other formats (TS, FLV, AVI) can be added later
    return null;
  }

  /// Opens an MP4 subtitle track.
  static Future<EmbeddedSubtitleReader?> _openMp4(String filePath, int trackId) async {
    final file = File(filePath);
    final raf = await file.open();

    // Parse container metadata to find track info
    final metadata = await ContainerParser.parseFile(raf);
    await raf.close();

    if (metadata == null) return null;

    // Find the subtitle track
    final track = metadata.tracks.where((t) => t.id == trackId && t.type == ContainerTrackType.subtitle).firstOrNull;

    if (track == null) return null;

    // Check if we have a decoder for this codec
    final fourcc = track.codec.fourcc;
    final decoder = SubtitleSampleDecoder.forCodec(fourcc);
    if (decoder == null) return null;

    // Parse sample table for this track
    final sampleTable = await _parseMp4SampleTable(filePath, trackId);
    if (sampleTable == null) return null;

    // Create sample reader
    final trackFile = await File(filePath).open();
    final codecInfo = TrackCodecInfo(trackId: trackId, codecFourcc: fourcc, timescale: sampleTable.timescale);

    final sampleReader = Mp4SampleReader(
      file: trackFile,
      sampleTable: sampleTable,
      trackId: trackId,
      codecInfo: codecInfo,
    );

    return EmbeddedSubtitleReader._(sampleReader: sampleReader, decoder: decoder, codecInfo: codecInfo);
  }

  /// Opens an MKV subtitle track.
  static Future<EmbeddedSubtitleReader?> _openMkv(String filePath, int trackId) async {
    final reader = await MkvSampleReader.open(filePath, trackId);
    if (reader == null) return null;

    // Check if this is a subtitle track
    final codecInfo = reader.codecInfo;
    if (!codecInfo.isSubtitle) {
      await reader.close();
      return null;
    }

    // Check if we have a decoder for this codec
    final decoder = SubtitleSampleDecoder.forCodec(codecInfo.codecFourcc);
    if (decoder == null) {
      await reader.close();
      return null;
    }

    return EmbeddedSubtitleReader._(sampleReader: reader, decoder: decoder, codecInfo: codecInfo);
  }

  /// Parses MP4 sample table for a specific track.
  static Future<Mp4SampleTable?> _parseMp4SampleTable(String filePath, int trackId) async {
    final file = File(filePath);
    final data = await file.readAsBytes();

    // Find stbl box for the track
    final sampleTable = Mp4SampleTableParser.parseForTrack(data, trackId);
    return sampleTable;
  }

  /// Reads the next subtitle sample and decodes it.
  ///
  /// Returns null if no more samples are available.
  Future<SubtitleCue?> readNextCue() async {
    final sample = await _sampleReader.readNextSample();
    if (sample == null) return null;

    return _decodeSample(sample);
  }

  /// Reads a specific subtitle sample by index.
  ///
  /// Returns null if the index is invalid.
  Future<SubtitleCue?> readCueAt(int index) async {
    final sample = await _sampleReader.readSampleAt(index);
    if (sample == null) return null;

    return _decodeSample(sample);
  }

  /// Decodes a media sample into a subtitle cue.
  SubtitleCue? _decodeSample(MediaSample sample) {
    final decoded = _decoder.decode(sample.data, sample.compositionTimestamp, sample.duration, _sampleReader.timescale);

    if (decoded == null) return null;

    return SubtitleCue(
      index: sample.sampleIndex,
      start: decoded.startTime,
      end: decoded.endTime,
      text: decoded.text,
      styledSpans: decoded.styledSpans,
    );
  }

  /// Extracts all subtitle cues from the track.
  ///
  /// This reads through all samples sequentially and returns them as cues.
  /// For large subtitle tracks, consider using [streamCues] instead.
  Future<List<SubtitleCue>> extractAll() async {
    final cues = <SubtitleCue>[];

    _sampleReader.seekToIndex(0);

    while (_sampleReader.hasMoreSamples) {
      final cue = await readNextCue();
      if (cue != null) {
        cues.add(cue);
      }
    }

    return cues;
  }

  /// Streams subtitle cues for memory-efficient processing.
  ///
  /// Yields cues one at a time starting from the current position.
  Stream<SubtitleCue> streamCues() async* {
    while (_sampleReader.hasMoreSamples) {
      final cue = await readNextCue();
      if (cue != null) {
        yield cue;
      }
    }
  }

  /// Seeks to a specific position in the subtitle track.
  ///
  /// The [timestamp] is in milliseconds.
  Future<void> seekToTimestamp(Duration timestamp) async {
    // Convert Duration to timescale units
    final timescaleUnits = timestamp.inMicroseconds * _sampleReader.timescale ~/ Duration.microsecondsPerSecond;
    await _sampleReader.seekToTimestamp(timescaleUnits);
  }

  /// Seeks to a specific sample index.
  void seekToIndex(int index) {
    _sampleReader.seekToIndex(index);
  }

  /// Closes the reader and releases resources.
  Future<void> close() async {
    await _sampleReader.close();
  }
}

/// Parser for MP4 sample tables.
///
/// Extracts sample table data from MP4 moov/trak boxes for a specific track.
class Mp4SampleTableParser {
  Mp4SampleTableParser._();

  /// Parses the sample table for a specific track ID.
  static Mp4SampleTable? parseForTrack(Uint8List data, int trackId) {
    var offset = 0;

    // Find moov box
    while (offset + 8 <= data.length) {
      final boxSize = _readUint32(data, offset);
      final boxType = String.fromCharCodes(data.sublist(offset + 4, offset + 8));

      if (boxSize < 8) break;

      if (boxType == 'moov') {
        return _parseTrackInMoov(data, offset + 8, offset + boxSize, trackId);
      }

      offset += boxSize;
    }

    return null;
  }

  /// Searches for and parses the sample table for a track within moov.
  static Mp4SampleTable? _parseTrackInMoov(Uint8List data, int start, int end, int trackId) {
    var offset = start;

    while (offset + 8 <= end) {
      final boxSize = _readUint32(data, offset);
      final boxType = String.fromCharCodes(data.sublist(offset + 4, offset + 8));

      if (boxSize < 8) break;

      if (boxType == 'trak') {
        // Check if this is the track we're looking for
        final parsedTrackId = _getTrackId(data, offset + 8, offset + boxSize);
        if (parsedTrackId == trackId) {
          return _parseSampleTable(data, offset + 8, offset + boxSize);
        }
      }

      offset += boxSize;
    }

    return null;
  }

  /// Gets the track ID from a trak box.
  static int? _getTrackId(Uint8List data, int start, int end) {
    var offset = start;

    while (offset + 8 <= end) {
      final boxSize = _readUint32(data, offset);
      final boxType = String.fromCharCodes(data.sublist(offset + 4, offset + 8));

      if (boxSize < 8) break;

      if (boxType == 'tkhd') {
        // Track header: version (1) + flags (3) + creation/modification times + track_id
        final version = data[offset + 8];
        final trackIdOffset = version == 1 ? offset + 8 + 1 + 3 + 8 + 8 : offset + 8 + 1 + 3 + 4 + 4;
        return _readUint32(data, trackIdOffset);
      }

      offset += boxSize;
    }

    return null;
  }

  /// Parses the sample table (stbl) from a trak box.
  static Mp4SampleTable? _parseSampleTable(Uint8List data, int start, int end) {
    // Find mdia -> minf -> stbl
    final mdiaBox = _findChildBox(data, start, end, 'mdia');
    if (mdiaBox == null) return null;

    final minfBox = _findChildBox(data, mdiaBox.$1, mdiaBox.$2, 'minf');
    if (minfBox == null) return null;

    final stblBox = _findChildBox(data, minfBox.$1, minfBox.$2, 'stbl');
    if (stblBox == null) return null;

    // Parse sample table boxes
    final sttsEntries = _parseStts(data, stblBox.$1, stblBox.$2);
    final cttsEntries = _parseCtts(data, stblBox.$1, stblBox.$2);
    final stszEntries = _parseStsz(data, stblBox.$1, stblBox.$2);
    final stscEntries = _parseStsc(data, stblBox.$1, stblBox.$2);
    final chunkOffsets = _parseStco(data, stblBox.$1, stblBox.$2);
    final syncSamples = _parseStss(data, stblBox.$1, stblBox.$2);

    // Get timescale from mdhd
    final mdhdBox = _findChildBox(data, mdiaBox.$1, mdiaBox.$2, 'mdhd');
    final timescale = mdhdBox != null ? _getTimescale(data, mdhdBox.$1) : 1000;

    if (sttsEntries == null || stszEntries == null || stscEntries == null || chunkOffsets == null) {
      return null;
    }

    return Mp4SampleTable(
      timescale: timescale,
      sttsEntries: sttsEntries,
      cttsEntries: cttsEntries ?? [],
      sampleSizes: stszEntries,
      stscEntries: stscEntries,
      chunkOffsets: chunkOffsets,
      syncSamples: syncSamples ?? [],
    );
  }

  /// Finds a child box within a parent box.
  static (int, int)? _findChildBox(Uint8List data, int start, int end, String targetType) {
    var offset = start;

    while (offset + 8 <= end) {
      final boxSize = _readUint32(data, offset);
      final boxType = String.fromCharCodes(data.sublist(offset + 4, offset + 8));

      if (boxSize < 8) break;

      if (boxType == targetType) {
        return (offset + 8, offset + boxSize);
      }

      offset += boxSize;
    }

    return null;
  }

  /// Gets timescale from mdhd box.
  static int _getTimescale(Uint8List data, int offset) {
    final version = data[offset];
    // Skip version (1) + flags (3) + creation/modification times
    final timescaleOffset = version == 1 ? offset + 1 + 3 + 8 + 8 : offset + 1 + 3 + 4 + 4;
    return _readUint32(data, timescaleOffset);
  }

  /// Parses stts (decoding time to sample) box.
  static List<SttsEntry>? _parseStts(Uint8List data, int start, int end) {
    final box = _findChildBox(data, start, end, 'stts');
    if (box == null) return null;

    var offset = box.$1;
    offset += 4; // Skip version + flags
    final entryCount = _readUint32(data, offset);
    offset += 4;

    final entries = <SttsEntry>[];
    for (var i = 0; i < entryCount && offset + 8 <= box.$2; i++) {
      entries.add(SttsEntry(sampleCount: _readUint32(data, offset), sampleDelta: _readUint32(data, offset + 4)));
      offset += 8;
    }

    return entries;
  }

  /// Parses ctts (composition time to sample) box.
  static List<CttsEntry>? _parseCtts(Uint8List data, int start, int end) {
    final box = _findChildBox(data, start, end, 'ctts');
    if (box == null) return null;

    var offset = box.$1;
    final version = data[offset];
    offset += 4; // Skip version + flags
    final entryCount = _readUint32(data, offset);
    offset += 4;

    final entries = <CttsEntry>[];
    for (var i = 0; i < entryCount && offset + 8 <= box.$2; i++) {
      final sampleCount = _readUint32(data, offset);
      final compositionOffset = version == 1
          ? _readInt32(data, offset + 4) // signed for version 1
          : _readUint32(data, offset + 4); // unsigned for version 0
      entries.add(CttsEntry(sampleCount: sampleCount, sampleOffset: compositionOffset));
      offset += 8;
    }

    return entries;
  }

  /// Parses stsz (sample size) box.
  static List<int>? _parseStsz(Uint8List data, int start, int end) {
    final box = _findChildBox(data, start, end, 'stsz');
    if (box == null) return null;

    var offset = box.$1;
    offset += 4; // Skip version + flags
    final uniformSize = _readUint32(data, offset);
    offset += 4;
    final sampleCount = _readUint32(data, offset);
    offset += 4;

    if (uniformSize != 0) {
      // All samples have the same size
      return List.filled(sampleCount, uniformSize);
    }

    // Variable sample sizes
    final sizes = <int>[];
    for (var i = 0; i < sampleCount && offset + 4 <= box.$2; i++) {
      sizes.add(_readUint32(data, offset));
      offset += 4;
    }

    return sizes;
  }

  /// Parses stsc (sample to chunk) box.
  static List<StscEntry>? _parseStsc(Uint8List data, int start, int end) {
    final box = _findChildBox(data, start, end, 'stsc');
    if (box == null) return null;

    var offset = box.$1;
    offset += 4; // Skip version + flags
    final entryCount = _readUint32(data, offset);
    offset += 4;

    final entries = <StscEntry>[];
    for (var i = 0; i < entryCount && offset + 12 <= box.$2; i++) {
      entries.add(
        StscEntry(
          firstChunk: _readUint32(data, offset),
          samplesPerChunk: _readUint32(data, offset + 4),
          sampleDescriptionIndex: _readUint32(data, offset + 8),
        ),
      );
      offset += 12;
    }

    return entries;
  }

  /// Parses stco/co64 (chunk offset) box.
  static List<int>? _parseStco(Uint8List data, int start, int end) {
    // Try stco (32-bit offsets) first
    var box = _findChildBox(data, start, end, 'stco');
    var is64Bit = false;

    if (box == null) {
      // Try co64 (64-bit offsets)
      box = _findChildBox(data, start, end, 'co64');
      is64Bit = true;
    }

    if (box == null) return null;

    var offset = box.$1;
    offset += 4; // Skip version + flags
    final entryCount = _readUint32(data, offset);
    offset += 4;

    final offsets = <int>[];
    final entrySize = is64Bit ? 8 : 4;

    for (var i = 0; i < entryCount && offset + entrySize <= box.$2; i++) {
      offsets.add(is64Bit ? _readUint64(data, offset) : _readUint32(data, offset));
      offset += entrySize;
    }

    return offsets;
  }

  /// Parses stss (sync sample) box.
  static List<int>? _parseStss(Uint8List data, int start, int end) {
    final box = _findChildBox(data, start, end, 'stss');
    if (box == null) return null;

    var offset = box.$1;
    offset += 4; // Skip version + flags
    final entryCount = _readUint32(data, offset);
    offset += 4;

    final samples = <int>[];
    for (var i = 0; i < entryCount && offset + 4 <= box.$2; i++) {
      samples.add(_readUint32(data, offset));
      offset += 4;
    }

    return samples;
  }

  static int _readUint32(Uint8List data, int offset) =>
      (data[offset] << 24) | (data[offset + 1] << 16) | (data[offset + 2] << 8) | data[offset + 3];

  static int _readInt32(Uint8List data, int offset) {
    final unsigned = _readUint32(data, offset);
    return unsigned >= 0x80000000 ? unsigned - 0x100000000 : unsigned;
  }

  static int _readUint64(Uint8List data, int offset) =>
      (data[offset] << 56) |
      (data[offset + 1] << 48) |
      (data[offset + 2] << 40) |
      (data[offset + 3] << 32) |
      (data[offset + 4] << 24) |
      (data[offset + 5] << 16) |
      (data[offset + 6] << 8) |
      data[offset + 7];
}

/// Lists embedded subtitle tracks from a container file.
///
/// Returns a list of [EmbeddedSubtitleTrack] objects describing each
/// subtitle track found in the file.
Future<List<EmbeddedSubtitleTrack>> listEmbeddedSubtitleTracks(String filePath) async {
  final metadata = await ContainerParser.parseFilePath(filePath);
  if (metadata == null) return [];

  return _tracksFromMetadata(metadata);
}

/// Converts container metadata tracks to EmbeddedSubtitleTrack list.
List<EmbeddedSubtitleTrack> _tracksFromMetadata(ContainerMetadata metadata) {
  final tracks = <EmbeddedSubtitleTrack>[];

  for (final track in metadata.tracks) {
    if (track.type != ContainerTrackType.subtitle) continue;

    tracks.add(_trackFromContainerTrack(track));
  }

  return tracks;
}

/// Converts a ContainerTrack to an EmbeddedSubtitleTrack.
EmbeddedSubtitleTrack _trackFromContainerTrack(ContainerTrack track) => EmbeddedSubtitleTrack(
  trackId: track.id,
  codec: track.codec.fourcc,
  language: track.language,
  // Note: label, isDefault and isForced require additional parsing of
  // track metadata which isn't currently exposed in ContainerTrack
);
