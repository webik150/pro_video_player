import 'dart:typed_data';

/// Represents a single media sample (video frame or audio packet).
///
/// Contains the raw compressed data along with timing and sync information
/// needed for proper playback and muxing.
class MediaSample {
  /// Creates a media sample.
  const MediaSample({
    required this.data,
    required this.trackId,
    required this.sampleIndex,
    required this.decodeTimestamp,
    required this.compositionTimestamp,
    required this.duration,
    required this.isKeyframe,
  });

  /// The compressed sample data.
  final Uint8List data;

  /// Track ID this sample belongs to.
  final int trackId;

  /// Zero-based index of this sample in the track.
  final int sampleIndex;

  /// Decode timestamp (DTS) in timescale units.
  ///
  /// This is when the decoder should process the sample.
  final int decodeTimestamp;

  /// Composition/presentation timestamp (PTS) in timescale units.
  ///
  /// This is when the sample should be displayed.
  /// For video with B-frames, PTS may differ from DTS.
  final int compositionTimestamp;

  /// Duration of this sample in timescale units.
  final int duration;

  /// Whether this sample is a sync sample (keyframe).
  ///
  /// For video, this indicates an IDR frame or equivalent.
  /// For audio, typically all samples are sync samples.
  final bool isKeyframe;

  /// Size of the sample data in bytes.
  int get size => data.length;

  @override
  String toString() =>
      'MediaSample(track: $trackId, index: $sampleIndex, dts: $decodeTimestamp, pts: $compositionTimestamp, '
      'size: $size, keyframe: $isKeyframe)';
}

/// Abstract interface for reading media samples from a container.
///
/// Implementations provide sequential or random access to samples
/// within a specific container format.
abstract class SampleReader {
  /// The track ID this reader is associated with.
  int get trackId;

  /// Track timescale (samples per second).
  int get timescale;

  /// Total number of samples in this track.
  int get sampleCount;

  /// Total duration in timescale units.
  int get totalDuration;

  /// Whether there are more samples to read.
  bool get hasMoreSamples;

  /// Current sample index (0-based).
  int get currentIndex;

  /// Reads the next sample in sequence.
  ///
  /// Returns null if no more samples are available.
  Future<MediaSample?> readNextSample();

  /// Reads a specific sample by index.
  ///
  /// Returns null if the index is invalid.
  Future<MediaSample?> readSampleAt(int index);

  /// Seeks to the sample at or before the given timestamp.
  ///
  /// The [timestamp] is in timescale units.
  /// If [toKeyframe] is true, seeks to the nearest preceding keyframe.
  /// Returns the index of the sample that will be read next.
  Future<int> seekToTimestamp(int timestamp, {bool toKeyframe = false});

  /// Seeks to the specified sample index.
  ///
  /// If [index] is negative, seeks to the first sample.
  /// If [index] exceeds sample count, seeks to the last sample.
  void seekToIndex(int index);

  /// Iterates through samples starting from current position.
  ///
  /// Yields samples one at a time for memory-efficient processing.
  Stream<MediaSample> samples();

  /// Closes the reader and releases resources.
  Future<void> close();
}

/// Information about a track's codec for muxing purposes.
class TrackCodecInfo {
  /// Creates track codec information.
  const TrackCodecInfo({
    required this.trackId,
    required this.codecFourcc,
    required this.timescale,
    this.codecPrivateData,
    this.width,
    this.height,
    this.sampleRate,
    this.channelCount,
  });

  /// Track ID.
  final int trackId;

  /// Codec four character code (e.g., 'avc1', 'mp4a').
  final String codecFourcc;

  /// Track timescale.
  final int timescale;

  /// Codec-specific initialization data (e.g., avcC, hvcC, esds).
  final Uint8List? codecPrivateData;

  /// Video width (for video tracks).
  final int? width;

  /// Video height (for video tracks).
  final int? height;

  /// Audio sample rate (for audio tracks).
  final int? sampleRate;

  /// Audio channel count (for audio tracks).
  final int? channelCount;

  /// Whether this is a video track.
  bool get isVideo => width != null && height != null;

  /// Whether this is an audio track.
  bool get isAudio => sampleRate != null;

  /// Whether this is a subtitle track.
  ///
  /// Identifies subtitle codecs from MP4 (tx3g, stpp, wvtt, c608, c708),
  /// MKV (S_TEXT/*, S_HDMV/*), and other containers.
  bool get isSubtitle {
    final lower = codecFourcc.toLowerCase();
    // MP4 subtitle codecs
    if (lower == 'tx3g' ||
        lower == 'stpp' ||
        lower == 'wvtt' ||
        lower == 'c608' ||
        lower == 'c708' ||
        lower == 'text') {
      return true;
    }
    // MKV subtitle codecs (S_TEXT/UTF8, S_TEXT/ASS, S_HDMV/PGS, etc.)
    if (lower.startsWith('s_text') || lower.startsWith('s_hdmv')) {
      return true;
    }
    // TS/DVB subtitle codecs
    if (lower == 'dvbs' || lower == 'ttxt') {
      return true;
    }
    return false;
  }

  @override
  String toString() {
    if (isVideo) {
      return 'TrackCodecInfo(track: $trackId, codec: $codecFourcc, ${width}x$height)';
    } else if (isAudio) {
      return 'TrackCodecInfo(track: $trackId, codec: $codecFourcc, $sampleRate Hz, $channelCount ch)';
    } else if (isSubtitle) {
      return 'TrackCodecInfo(track: $trackId, codec: $codecFourcc, subtitle)';
    }
    return 'TrackCodecInfo(track: $trackId, codec: $codecFourcc)';
  }
}
