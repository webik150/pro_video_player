import 'audio_track_info.dart';
import 'codec_info.dart';
import 'container_track_type.dart';
import 'video_track_info.dart';

/// Metadata for a single track within a media container.
///
/// Represents a video, audio, subtitle, or other track extracted
/// from a container file (MP4, MKV, etc.). Contains codec information,
/// timing data, and track-specific metadata.
///
/// Example:
/// ```dart
/// const videoTrack = ContainerTrack(
///   id: 1,
///   type: ContainerTrackType.video,
///   codec: CodecInfo(fourcc: 'avc1', name: 'H.264'),
///   duration: Duration(minutes: 5),
///   bitrate: 5000000,
///   videoInfo: VideoTrackInfo(width: 1920, height: 1080),
/// );
///
/// print(videoTrack.isVideo);        // true
/// print(videoTrack.bitrateInKbps);  // 5000.0
/// ```
class ContainerTrack {
  /// Creates a container track with required fields.
  const ContainerTrack({
    required this.id,
    required this.type,
    required this.codec,
    this.duration,
    this.language,
    this.bitrate,
    this.sampleCount,
    this.dataOffset,
    this.videoInfo,
    this.audioInfo,
  });

  /// Creates a [ContainerTrack] from a map representation.
  factory ContainerTrack.fromMap(Map<String, dynamic> map) {
    final typeStr = map['type'] as String? ?? 'unknown';
    final type = ContainerTrackType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => ContainerTrackType.unknown,
    );

    return ContainerTrack(
      id: map['id'] as int? ?? 0,
      type: type,
      codec: CodecInfo.fromMap(map['codec'] as Map<String, dynamic>? ?? {}),
      duration: map['durationMs'] != null ? Duration(milliseconds: map['durationMs'] as int) : null,
      language: map['language'] as String?,
      bitrate: map['bitrate'] as int?,
      sampleCount: map['sampleCount'] as int?,
      dataOffset: map['dataOffset'] as int?,
      videoInfo: map['videoInfo'] != null ? VideoTrackInfo.fromMap(map['videoInfo'] as Map<String, dynamic>) : null,
      audioInfo: map['audioInfo'] != null ? AudioTrackInfo.fromMap(map['audioInfo'] as Map<String, dynamic>) : null,
    );
  }

  /// Track ID from the container's track header (tkhd box in MP4).
  final int id;

  /// Type of track (video, audio, subtitle, etc.).
  final ContainerTrackType type;

  /// Codec information extracted from sample entry.
  final CodecInfo codec;

  /// Track duration.
  final Duration? duration;

  /// Language code (ISO 639-2/T, e.g., "eng", "fra", "und").
  final String? language;

  /// Average bitrate in bits per second.
  final int? bitrate;

  /// Number of samples in this track.
  ///
  /// For video, this is the frame count.
  /// For audio, this is the number of audio samples.
  final int? sampleCount;

  /// Byte offset of track data in the file.
  ///
  /// Used for remuxing and stream positioning.
  final int? dataOffset;

  /// Video-specific information (null for non-video tracks).
  final VideoTrackInfo? videoInfo;

  /// Audio-specific information (null for non-audio tracks).
  final AudioTrackInfo? audioInfo;

  /// Whether this is a video track.
  bool get isVideo => type == ContainerTrackType.video;

  /// Whether this is an audio track.
  bool get isAudio => type == ContainerTrackType.audio;

  /// Whether this is a subtitle track.
  bool get isSubtitle => type == ContainerTrackType.subtitle;

  /// Bitrate in kilobits per second.
  double? get bitrateInKbps => bitrate != null ? bitrate! / 1000.0 : null;

  /// Converts this track to a map representation.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'type': type.name,
    'codec': codec.toMap(),
    if (duration != null) 'durationMs': duration!.inMilliseconds,
    if (language != null) 'language': language,
    if (bitrate != null) 'bitrate': bitrate,
    if (sampleCount != null) 'sampleCount': sampleCount,
    if (dataOffset != null) 'dataOffset': dataOffset,
    if (videoInfo != null) 'videoInfo': videoInfo!.toMap(),
    if (audioInfo != null) 'audioInfo': audioInfo!.toMap(),
  };

  /// Creates a copy with the given fields replaced.
  ContainerTrack copyWith({
    int? id,
    ContainerTrackType? type,
    CodecInfo? codec,
    Duration? duration,
    String? language,
    int? bitrate,
    int? sampleCount,
    int? dataOffset,
    VideoTrackInfo? videoInfo,
    AudioTrackInfo? audioInfo,
  }) => ContainerTrack(
    id: id ?? this.id,
    type: type ?? this.type,
    codec: codec ?? this.codec,
    duration: duration ?? this.duration,
    language: language ?? this.language,
    bitrate: bitrate ?? this.bitrate,
    sampleCount: sampleCount ?? this.sampleCount,
    dataOffset: dataOffset ?? this.dataOffset,
    videoInfo: videoInfo ?? this.videoInfo,
    audioInfo: audioInfo ?? this.audioInfo,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ContainerTrack) return false;
    return id == other.id &&
        type == other.type &&
        codec == other.codec &&
        duration == other.duration &&
        language == other.language &&
        bitrate == other.bitrate &&
        sampleCount == other.sampleCount &&
        dataOffset == other.dataOffset &&
        videoInfo == other.videoInfo &&
        audioInfo == other.audioInfo;
  }

  @override
  int get hashCode =>
      Object.hash(id, type, codec, duration, language, bitrate, sampleCount, dataOffset, videoInfo, audioInfo);

  @override
  String toString() =>
      'ContainerTrack(id: $id, type: ${type.name}, codec: ${codec.fourcc}, '
      'language: $language, bitrate: $bitrate)';
}
