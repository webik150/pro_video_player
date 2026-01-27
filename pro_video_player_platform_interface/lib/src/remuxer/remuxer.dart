import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../container/container_parser.dart';
import '../container/mp4_box_reader.dart';
import '../types/container_metadata.dart';
import 'fmp4_segment_writer.dart';
import 'hls_playlist_writer.dart';
import 'mp4_sample_reader.dart';
import 'mp4_sample_table.dart';
import 'mp4_sample_table_parser.dart';
import 'remux_config.dart';
import 'remux_progress.dart';
import 'sample_reader.dart';
import 'segment_writer.dart';

/// Remuxes video files to HLS format.
///
/// Takes a video file (MP4, MKV, etc.) and converts it to HLS segments
/// with corresponding playlists, without re-encoding the video/audio.
///
/// Example:
/// ```dart
/// final remuxer = await VideoRemuxer.open('/path/to/video.mp4');
/// print('Duration: ${remuxer.metadata.duration}');
///
/// await for (final progress in remuxer.toHls(outputDir: '/output')) {
///   print('Progress: ${progress.progressPercent}%');
/// }
/// ```
class VideoRemuxer {
  VideoRemuxer._({
    required this.sourcePath,
    required this.metadata,
    required Uint8List sourceData,
    required List<_TrackInfo> trackInfos,
  }) : _sourceData = sourceData,
       _trackInfos = trackInfos;

  /// Opens a video file for remuxing.
  ///
  /// Parses the container metadata and sample tables needed for remuxing.
  /// Currently supports MP4 files.
  ///
  /// Throws [RemuxException] if the file cannot be parsed.
  static Future<VideoRemuxer> open(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw RemuxException('File not found: $filePath');
    }

    // Read the file
    final bytes = await file.readAsBytes();

    // Parse container metadata using ContainerParser
    final metadata = ContainerParser.parse(bytes);
    if (metadata == null) {
      throw RemuxException('Failed to parse container: $filePath');
    }

    // Parse sample tables for each track
    final trackInfos = <_TrackInfo>[];
    final reader = Mp4BoxReader(bytes);

    // Find moov box and parse tracks
    while (reader.hasRemaining(8)) {
      final box = reader.readBox();
      if (box == null) break;

      if (box.type == 'moov') {
        // Parse each trak box inside moov
        reader.seek(box.dataOffset);
        while (reader.position < box.endOffset && reader.hasRemaining(8)) {
          final childBox = reader.readChildBox(box);
          if (childBox == null) break;

          if (childBox.type == 'trak') {
            final trackInfo = _parseTrack(reader, childBox, bytes);
            if (trackInfo != null) {
              trackInfos.add(trackInfo);
            }
          }
          reader.seek(childBox.endOffset);
        }
        break;
      }

      reader.seek(box.endOffset);
    }

    if (trackInfos.isEmpty) {
      throw RemuxException('No valid tracks found in: $filePath');
    }

    return VideoRemuxer._(sourcePath: filePath, metadata: metadata, sourceData: bytes, trackInfos: trackInfos);
  }

  /// Parses a single track from a trak box.
  static _TrackInfo? _parseTrack(Mp4BoxReader reader, Mp4Box trakBox, Uint8List data) {
    int? trackId;
    int? timescale;
    int? width;
    int? height;
    int? sampleRate;
    int? channelCount;
    String? codecFourcc;
    Uint8List? codecPrivateData;
    Mp4SampleTable? sampleTable;

    reader.seek(trakBox.dataOffset);
    while (reader.position < trakBox.endOffset && reader.hasRemaining(8)) {
      final box = reader.readChildBox(trakBox);
      if (box == null) break;

      switch (box.type) {
        case 'tkhd':
          // Track header - get track ID
          reader.enterBox(box);
          final version = reader.readUint8();
          reader.skip(3); // flags
          if (version == 1) {
            reader.skip(16); // creation_time, modification_time (64-bit)
            trackId = reader.readUint32();
          } else {
            reader.skip(8); // creation_time, modification_time (32-bit)
            trackId = reader.readUint32();
          }

        case 'mdia':
          // Media container - parse for timescale and handler
          final mdiaResult = _parseMdia(reader, box);
          timescale = mdiaResult.timescale;
          sampleTable = mdiaResult.sampleTable;
          width = mdiaResult.width;
          height = mdiaResult.height;
          sampleRate = mdiaResult.sampleRate;
          channelCount = mdiaResult.channelCount;
          codecFourcc = mdiaResult.codecFourcc;
          codecPrivateData = mdiaResult.codecPrivateData;
      }

      reader.seek(box.endOffset);
    }

    if (trackId == null || timescale == null || sampleTable == null || codecFourcc == null) {
      return null;
    }

    return _TrackInfo(
      trackId: trackId,
      timescale: timescale,
      sampleTable: sampleTable,
      codecInfo: TrackCodecInfo(
        trackId: trackId,
        codecFourcc: codecFourcc,
        timescale: timescale,
        width: width,
        height: height,
        sampleRate: sampleRate,
        channelCount: channelCount,
        codecPrivateData: codecPrivateData,
      ),
    );
  }

  /// Parses mdia box for timescale and sample table.
  static _MdiaResult _parseMdia(Mp4BoxReader reader, Mp4Box mdiaBox) {
    int? timescale;
    Mp4SampleTable? sampleTable;
    int? width;
    int? height;
    int? sampleRate;
    int? channelCount;
    String? codecFourcc;
    Uint8List? codecPrivateData;

    reader.seek(mdiaBox.dataOffset);
    while (reader.position < mdiaBox.endOffset && reader.hasRemaining(8)) {
      final box = reader.readChildBox(mdiaBox);
      if (box == null) break;

      switch (box.type) {
        case 'mdhd':
          // Media header - get timescale
          reader.enterBox(box);
          final version = reader.readUint8();
          reader.skip(3); // flags
          if (version == 1) {
            reader.skip(16); // creation_time, modification_time (64-bit)
            timescale = reader.readUint32();
          } else {
            reader.skip(8); // creation_time, modification_time (32-bit)
            timescale = reader.readUint32();
          }

        case 'minf':
          // Media information - contains stbl
          final minfResult = _parseMinf(reader, box, timescale ?? 1000);
          sampleTable = minfResult.sampleTable;
          width = minfResult.width;
          height = minfResult.height;
          sampleRate = minfResult.sampleRate;
          channelCount = minfResult.channelCount;
          codecFourcc = minfResult.codecFourcc;
          codecPrivateData = minfResult.codecPrivateData;
      }

      reader.seek(box.endOffset);
    }

    return _MdiaResult(
      timescale: timescale,
      sampleTable: sampleTable,
      width: width,
      height: height,
      sampleRate: sampleRate,
      channelCount: channelCount,
      codecFourcc: codecFourcc,
      codecPrivateData: codecPrivateData,
    );
  }

  /// Parses minf box for stbl.
  static _MdiaResult _parseMinf(Mp4BoxReader reader, Mp4Box minfBox, int timescale) {
    Mp4SampleTable? sampleTable;
    int? width;
    int? height;
    int? sampleRate;
    int? channelCount;
    String? codecFourcc;
    Uint8List? codecPrivateData;

    reader.seek(minfBox.dataOffset);
    while (reader.position < minfBox.endOffset && reader.hasRemaining(8)) {
      final box = reader.readChildBox(minfBox);
      if (box == null) break;

      if (box.type == 'stbl') {
        // Sample table - parse sample descriptions and table data
        final stblResult = _parseStbl(reader, box, timescale);
        sampleTable = stblResult.sampleTable;
        width = stblResult.width;
        height = stblResult.height;
        sampleRate = stblResult.sampleRate;
        channelCount = stblResult.channelCount;
        codecFourcc = stblResult.codecFourcc;
        codecPrivateData = stblResult.codecPrivateData;
      }

      reader.seek(box.endOffset);
    }

    return _MdiaResult(
      timescale: timescale,
      sampleTable: sampleTable,
      width: width,
      height: height,
      sampleRate: sampleRate,
      channelCount: channelCount,
      codecFourcc: codecFourcc,
      codecPrivateData: codecPrivateData,
    );
  }

  /// Parses stbl box for sample table and codec info.
  static _MdiaResult _parseStbl(Mp4BoxReader reader, Mp4Box stblBox, int timescale) {
    int? width;
    int? height;
    int? sampleRate;
    int? channelCount;
    String? codecFourcc;
    Uint8List? codecPrivateData;

    // First pass - get codec info from stsd
    reader.seek(stblBox.dataOffset);
    while (reader.position < stblBox.endOffset && reader.hasRemaining(8)) {
      final box = reader.readChildBox(stblBox);
      if (box == null) break;

      if (box.type == 'stsd') {
        final codecResult = _parseStsd(reader, box);
        width = codecResult.width;
        height = codecResult.height;
        sampleRate = codecResult.sampleRate;
        channelCount = codecResult.channelCount;
        codecFourcc = codecResult.codecFourcc;
        codecPrivateData = codecResult.codecPrivateData;
      }

      reader.seek(box.endOffset);
    }

    // Use Mp4SampleTableParser for sample table parsing
    final sampleTable = Mp4SampleTableParser.parse(reader, stblBox, timescale);

    return _MdiaResult(
      timescale: timescale,
      sampleTable: sampleTable,
      width: width,
      height: height,
      sampleRate: sampleRate,
      channelCount: channelCount,
      codecFourcc: codecFourcc,
      codecPrivateData: codecPrivateData,
    );
  }

  /// Parses stsd box for codec information.
  static _CodecResult _parseStsd(Mp4BoxReader reader, Mp4Box stsdBox) {
    reader.enterBox(stsdBox);
    reader.skip(4); // version + flags
    final entryCount = reader.readUint32();
    if (entryCount == 0) return const _CodecResult();

    // Read first sample entry
    if (!reader.hasRemaining(8)) return const _CodecResult();
    final entryBox = reader.readBox();
    if (entryBox == null) return const _CodecResult();

    final codecFourcc = entryBox.type;

    // Parse based on codec type
    if (_isVideoCodec(codecFourcc)) {
      return _parseVideoSampleEntry(reader, entryBox, codecFourcc);
    } else if (_isAudioCodec(codecFourcc)) {
      return _parseAudioSampleEntry(reader, entryBox, codecFourcc);
    }

    return _CodecResult(codecFourcc: codecFourcc);
  }

  static bool _isVideoCodec(String fourcc) =>
      fourcc == 'avc1' ||
      fourcc == 'avc3' ||
      fourcc == 'hvc1' ||
      fourcc == 'hev1' ||
      fourcc == 'vp09' ||
      fourcc == 'av01';

  static bool _isAudioCodec(String fourcc) =>
      fourcc == 'mp4a' || fourcc == 'ac-3' || fourcc == 'ec-3' || fourcc == 'Opus' || fourcc == 'fLaC';

  static _CodecResult _parseVideoSampleEntry(Mp4BoxReader reader, Mp4Box entryBox, String codecFourcc) {
    reader.enterBox(entryBox);
    reader.skip(6); // reserved
    reader.skip(2); // data_reference_index
    reader.skip(16); // pre_defined, reserved, pre_defined
    final width = reader.readUint16();
    final height = reader.readUint16();
    reader.skip(8); // horiz/vert resolution
    reader.skip(4); // reserved
    reader.skip(2); // frame_count
    reader.skip(32); // compressor name
    reader.skip(4); // depth, pre_defined

    // Look for codec config box (avcC, hvcC, etc.)
    Uint8List? codecPrivateData;
    while (reader.position < entryBox.endOffset && reader.hasRemaining(8)) {
      final configBox = reader.readBox();
      if (configBox == null) break;

      if (configBox.type == 'avcC' ||
          configBox.type == 'hvcC' ||
          configBox.type == 'vpcC' ||
          configBox.type == 'av1C') {
        // Read the entire config box as codec private data
        reader.seek(configBox.offset);
        codecPrivateData = reader.readBytes(configBox.size);
        break;
      }

      reader.seek(configBox.endOffset);
    }

    return _CodecResult(codecFourcc: codecFourcc, width: width, height: height, codecPrivateData: codecPrivateData);
  }

  static _CodecResult _parseAudioSampleEntry(Mp4BoxReader reader, Mp4Box entryBox, String codecFourcc) {
    reader.enterBox(entryBox);
    reader.skip(6); // reserved
    reader.skip(2); // data_reference_index
    reader.skip(8); // reserved
    final channelCount = reader.readUint16();
    reader.skip(2); // sample_size
    reader.skip(4); // pre_defined, reserved
    final sampleRateFixed = reader.readUint32();
    final sampleRate = sampleRateFixed >> 16; // 16.16 fixed point

    // Look for codec config box (esds for AAC)
    Uint8List? codecPrivateData;
    while (reader.position < entryBox.endOffset && reader.hasRemaining(8)) {
      final configBox = reader.readBox();
      if (configBox == null) break;

      if (configBox.type == 'esds' ||
          configBox.type == 'dac3' ||
          configBox.type == 'dec3' ||
          configBox.type == 'dOps') {
        reader.seek(configBox.offset);
        codecPrivateData = reader.readBytes(configBox.size);
        break;
      }

      reader.seek(configBox.endOffset);
    }

    return _CodecResult(
      codecFourcc: codecFourcc,
      sampleRate: sampleRate,
      channelCount: channelCount,
      codecPrivateData: codecPrivateData,
    );
  }

  /// Path to the source video file.
  final String sourcePath;

  /// Metadata extracted from the source file.
  final ContainerMetadata metadata;

  final Uint8List _sourceData;
  final List<_TrackInfo> _trackInfos;

  /// Duration of the video.
  Duration get duration => metadata.duration;

  /// Number of tracks in the source file.
  int get trackCount => _trackInfos.length;

  /// Codec information for all tracks.
  List<TrackCodecInfo> get tracks => _trackInfos.map((t) => t.codecInfo).toList();

  /// Converts the video to HLS format.
  ///
  /// [outputDir] is the directory to write output files.
  /// [config] specifies remuxing options (segment duration, format, etc.).
  /// [filenamePrefix] is the prefix for output files (default: 'video').
  ///
  /// Returns a stream of progress updates, with the final event containing
  /// the result information.
  Stream<RemuxProgress> toHls({
    required String outputDir,
    RemuxConfig config = const RemuxConfig(),
    String filenamePrefix = 'video',
  }) async* {
    yield const RemuxProgress.parsing(progress: 0.1, message: 'Starting remux...');

    // Ensure output directory exists
    final dir = Directory(outputDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    yield const RemuxProgress.parsing(progress: 0.2, message: 'Preparing segments...');

    // Find video and audio tracks
    final videoTrackInfo = _trackInfos.where((t) => t.codecInfo.isVideo).firstOrNull;
    final audioTrackInfo = config.includeAudio ? _trackInfos.where((t) => t.codecInfo.isAudio).firstOrNull : null;

    if (videoTrackInfo == null) {
      throw const RemuxException('No video track found');
    }

    // Create in-memory sample readers
    final videoReader = InMemorySampleReader(
      data: _sourceData,
      sampleTable: videoTrackInfo.sampleTable,
      trackId: videoTrackInfo.trackId,
    );

    InMemorySampleReader? audioReader;
    if (audioTrackInfo != null) {
      audioReader = InMemorySampleReader(
        data: _sourceData,
        sampleTable: audioTrackInfo.sampleTable,
        trackId: audioTrackInfo.trackId,
      );
    }

    // Create segment writer
    const segmentWriter = Fmp4SegmentWriter();
    final tracksForMuxing = [videoTrackInfo.codecInfo, if (audioTrackInfo != null) audioTrackInfo.codecInfo];

    // Write init segment
    yield const RemuxProgress.parsing(progress: 0.3, message: 'Writing init segment...');
    final initSegmentData = segmentWriter.writeInitSegment(tracksForMuxing);
    final initSegmentPath = '$outputDir/${filenamePrefix}_init.mp4';
    File(initSegmentPath).writeAsBytesSync(initSegmentData);

    // Calculate estimated segment count
    final durationSeconds = duration.inMilliseconds / 1000.0;
    final estimatedSegments = (durationSeconds / config.segmentDuration.inSeconds).ceil();

    // Generate segments
    final segmentPaths = <String>[];
    final segmentInfos = <HlsSegmentInfo>[];
    var segmentIndex = 0;

    yield const RemuxProgress.writing(progress: 0.35, currentSegment: 0, message: 'Generating segments...');

    // Use segmentStream for efficient streaming
    final segmentConfig = SegmentConfig(
      targetDuration: config.segmentDuration,
      alignToKeyframes: config.alignToKeyframes,
    );

    // Merge samples from video and audio tracks
    final sampleStream = _mergeTrackSamples(videoReader, audioReader);

    await for (final segment in segmentWriter.segmentStream(
      samples: sampleStream,
      tracks: tracksForMuxing,
      config: segmentConfig,
    )) {
      if (segment.isInitSegment) {
        // Skip init segment, we already wrote it
        continue;
      }

      segmentIndex++;
      final segmentPath = '$outputDir/${filenamePrefix}_$segmentIndex.m4s';
      File(segmentPath).writeAsBytesSync(segment.data);
      segmentPaths.add(segmentPath);

      segmentInfos.add(HlsSegmentInfo(filename: '${filenamePrefix}_$segmentIndex.m4s', duration: segment.duration));

      final progress = 0.35 + (0.55 * segmentIndex / estimatedSegments).clamp(0.0, 0.55);
      yield RemuxProgress.writing(
        progress: progress,
        currentSegment: segmentIndex,
        totalSegments: estimatedSegments,
        message: 'Writing segment $segmentIndex...',
      );
    }

    // Generate playlists
    yield const RemuxProgress.generatingPlaylists(message: 'Generating playlists...');

    final targetDuration = config.segmentDuration.inSeconds;
    final mediaPlaylist = HlsPlaylistWriter.writeMediaPlaylist(
      segments: segmentInfos,
      targetDuration: targetDuration,
      playlistType: config.playlistType,
      initSegment: '${filenamePrefix}_init.mp4',
      version: config.hlsVersion,
    );

    final mediaPlaylistPath = '$outputDir/$filenamePrefix.m3u8';
    File(mediaPlaylistPath).writeAsStringSync(mediaPlaylist);

    String? masterPlaylistPath;
    if (config.generateMasterPlaylist) {
      final bandwidth = _estimateBandwidth(videoTrackInfo.codecInfo, audioTrackInfo?.codecInfo);
      final variants = [
        HlsVariantInfo.fromTrack(
          track: videoTrackInfo.codecInfo,
          bandwidth: bandwidth,
          playlistUri: '$filenamePrefix.m3u8',
        ),
      ];

      final masterPlaylist = HlsPlaylistWriter.writeMasterPlaylist(variants: variants, version: config.hlsVersion);

      masterPlaylistPath = '$outputDir/master.m3u8';
      File(masterPlaylistPath).writeAsStringSync(masterPlaylist);
    }

    yield RemuxProgress.complete(message: 'Remux complete: ${segmentInfos.length} segments');
  }

  /// Merges samples from video and optionally audio tracks.
  Stream<MediaSample> _mergeTrackSamples(InMemorySampleReader videoReader, InMemorySampleReader? audioReader) async* {
    if (audioReader == null) {
      // Video only
      await for (final sample in videoReader.samples()) {
        yield sample;
      }
      return;
    }

    // Interleave video and audio samples by DTS
    final videoIter = StreamIterator(videoReader.samples());
    final audioIter = StreamIterator(audioReader.samples());

    var hasVideo = await videoIter.moveNext();
    var hasAudio = await audioIter.moveNext();

    while (hasVideo || hasAudio) {
      if (!hasVideo) {
        yield audioIter.current;
        hasAudio = await audioIter.moveNext();
      } else if (!hasAudio) {
        yield videoIter.current;
        hasVideo = await videoIter.moveNext();
      } else {
        // Both have samples - interleave by normalized timestamp
        final videoDts = videoIter.current.decodeTimestamp / videoReader.timescale;
        final audioDts = audioIter.current.decodeTimestamp / audioReader.timescale;

        if (videoDts <= audioDts) {
          yield videoIter.current;
          hasVideo = await videoIter.moveNext();
        } else {
          yield audioIter.current;
          hasAudio = await audioIter.moveNext();
        }
      }
    }

    await videoIter.cancel();
    await audioIter.cancel();
  }

  /// Estimates bandwidth for a track.
  int _estimateBandwidth(TrackCodecInfo video, TrackCodecInfo? audio) {
    // Rough estimate based on resolution
    var bandwidth = 0;

    if (video.width != null && video.height != null) {
      final pixels = video.width! * video.height!;
      if (pixels >= 1920 * 1080) {
        bandwidth = 5000000; // 5 Mbps for 1080p
      } else if (pixels >= 1280 * 720) {
        bandwidth = 2500000; // 2.5 Mbps for 720p
      } else if (pixels >= 854 * 480) {
        bandwidth = 1200000; // 1.2 Mbps for 480p
      } else {
        bandwidth = 600000; // 600 Kbps for smaller
      }
    } else {
      bandwidth = 2000000; // Default 2 Mbps
    }

    if (audio != null) {
      bandwidth += 128000; // Add ~128 Kbps for audio
    }

    return bandwidth;
  }
}

/// Internal track information.
class _TrackInfo {
  const _TrackInfo({
    required this.trackId,
    required this.timescale,
    required this.sampleTable,
    required this.codecInfo,
  });

  final int trackId;
  final int timescale;
  final Mp4SampleTable sampleTable;
  final TrackCodecInfo codecInfo;
}

/// Result from parsing mdia box.
class _MdiaResult {
  const _MdiaResult({
    this.timescale,
    this.sampleTable,
    this.width,
    this.height,
    this.sampleRate,
    this.channelCount,
    this.codecFourcc,
    this.codecPrivateData,
  });

  final int? timescale;
  final Mp4SampleTable? sampleTable;
  final int? width;
  final int? height;
  final int? sampleRate;
  final int? channelCount;
  final String? codecFourcc;
  final Uint8List? codecPrivateData;
}

/// Result from parsing stsd box.
class _CodecResult {
  const _CodecResult({
    this.codecFourcc,
    this.width,
    this.height,
    this.sampleRate,
    this.channelCount,
    this.codecPrivateData,
  });

  final String? codecFourcc;
  final int? width;
  final int? height;
  final int? sampleRate;
  final int? channelCount;
  final Uint8List? codecPrivateData;
}

/// Exception thrown during remuxing operations.
class RemuxException implements Exception {
  /// Creates a remux exception.
  const RemuxException(this.message);

  /// The error message.
  final String message;

  @override
  String toString() => 'RemuxException: $message';
}
