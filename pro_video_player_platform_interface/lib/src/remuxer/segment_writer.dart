import 'dart:typed_data';

import 'sample_reader.dart';

/// A segment of media data ready to be written to a file or streamed.
class MediaSegment {
  /// Creates a media segment.
  const MediaSegment({
    required this.data,
    required this.index,
    required this.startTime,
    required this.duration,
    required this.isInitSegment,
  });

  /// The segment binary data.
  final Uint8List data;

  /// Segment index (0 for init segment, 1+ for media segments).
  final int index;

  /// Start time in seconds.
  final double startTime;

  /// Duration in seconds.
  final double duration;

  /// Whether this is an initialization segment.
  final bool isInitSegment;

  /// Size of the segment in bytes.
  int get size => data.length;

  @override
  String toString() =>
      'MediaSegment(index: $index, startTime: ${startTime.toStringAsFixed(3)}s, '
      'duration: ${duration.toStringAsFixed(3)}s, size: $size, init: $isInitSegment)';
}

/// Configuration for segment generation.
class SegmentConfig {
  /// Creates a segment configuration.
  const SegmentConfig({this.targetDuration = const Duration(seconds: 6), this.alignToKeyframes = true});

  /// Target duration for each segment.
  ///
  /// Actual duration may vary based on keyframe alignment.
  final Duration targetDuration;

  /// Whether to align segment boundaries to keyframes.
  ///
  /// When true (default), segments will start at keyframes for
  /// efficient seeking and better compression.
  final bool alignToKeyframes;
}

/// Abstract interface for writing media segments.
///
/// Implementations generate segments in specific container formats
/// (fMP4, MPEG-TS) from decoded samples.
abstract class SegmentWriter {
  /// Writes the initialization segment.
  ///
  /// The init segment contains codec configuration and track metadata
  /// needed to decode subsequent media segments.
  ///
  /// Returns the init segment data.
  Uint8List writeInitSegment(List<TrackCodecInfo> tracks);

  /// Writes a media segment containing the given samples.
  ///
  /// The [sequenceNumber] identifies this segment (1-based).
  /// The [baseDecodeTime] is the decode time of the first sample
  /// in timescale units.
  ///
  /// Returns the media segment data.
  Uint8List writeMediaSegment({
    required List<MediaSample> samples,
    required int sequenceNumber,
    required int baseDecodeTime,
    required int timescale,
  });

  /// Generates segments from a sample stream.
  ///
  /// Yields an init segment first, followed by media segments.
  /// Segment boundaries are determined by [config].
  Stream<MediaSegment> segmentStream({
    required Stream<MediaSample> samples,
    required List<TrackCodecInfo> tracks,
    required SegmentConfig config,
  });
}
