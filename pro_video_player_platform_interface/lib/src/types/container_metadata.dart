import 'package:flutter/foundation.dart';

import 'container_track.dart';
import 'container_track_type.dart';

/// Comprehensive metadata extracted from container headers.
///
/// Contains all information extracted from a container file (MP4, MKV, etc.)
/// including format, duration, and all tracks (video, audio, subtitle).
///
/// Example:
/// ```dart
/// final metadata = ContainerParser.parse(bytes);
/// if (metadata != null) {
///   print('Format: ${metadata.format}');
///   print('Duration: ${metadata.duration}');
///   print('Video: ${metadata.primaryVideoTrack?.codec.name}');
///   print('Audio tracks: ${metadata.audioTracks.length}');
/// }
/// ```
class ContainerMetadata {
  /// Creates container metadata with required fields.
  const ContainerMetadata({
    required this.format,
    required this.duration,
    required this.tracks,
    this.creationTime,
    this.modificationTime,
    this.timescale,
    this.compatibleBrands = const [],
  });

  /// Creates a [ContainerMetadata] from a map representation.
  factory ContainerMetadata.fromMap(Map<String, dynamic> map) {
    final tracksList = map['tracks'] as List<dynamic>? ?? [];

    return ContainerMetadata(
      format: map['format'] as String? ?? '',
      duration: Duration(milliseconds: map['durationMs'] as int? ?? 0),
      tracks: tracksList.cast<Map<String, dynamic>>().map(ContainerTrack.fromMap).toList(),
      creationTime: map['creationTimeMs'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['creationTimeMs'] as int)
          : null,
      modificationTime: map['modificationTimeMs'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['modificationTimeMs'] as int)
          : null,
      timescale: map['timescale'] as int?,
      compatibleBrands: (map['compatibleBrands'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }

  /// An empty metadata instance.
  static const ContainerMetadata empty = ContainerMetadata(format: '', duration: Duration.zero, tracks: []);

  /// The container format detected from ftyp box.
  ///
  /// Common values: "mp4", "mov", "m4a", "m4v", "3gp"
  final String format;

  /// Total duration of the media.
  final Duration duration;

  /// All tracks in the container (video, audio, subtitle, etc.).
  final List<ContainerTrack> tracks;

  /// File creation timestamp from mvhd box.
  final DateTime? creationTime;

  /// File modification timestamp from mvhd box.
  final DateTime? modificationTime;

  /// Movie timescale from mvhd box (units per second).
  ///
  /// Common values: 600, 1000, 90000
  final int? timescale;

  /// Compatible brands from ftyp box.
  ///
  /// Common brands: "isom", "iso2", "iso5", "avc1", "mp41", "mp42"
  final List<String> compatibleBrands;

  /// Whether this metadata has no valid data.
  bool get isEmpty => format.isEmpty;

  /// Whether this metadata has valid data.
  bool get isNotEmpty => !isEmpty;

  /// The first video track, or null if none.
  ContainerTrack? get primaryVideoTrack {
    for (final track in tracks) {
      if (track.type == ContainerTrackType.video) return track;
    }
    return null;
  }

  /// The first audio track, or null if none.
  ContainerTrack? get primaryAudioTrack {
    for (final track in tracks) {
      if (track.type == ContainerTrackType.audio) return track;
    }
    return null;
  }

  /// All video tracks.
  List<ContainerTrack> get videoTracks => tracks.where((t) => t.type == ContainerTrackType.video).toList();

  /// All audio tracks.
  List<ContainerTrack> get audioTracks => tracks.where((t) => t.type == ContainerTrackType.audio).toList();

  /// All subtitle tracks.
  List<ContainerTrack> get subtitleTracks => tracks.where((t) => t.type == ContainerTrackType.subtitle).toList();

  /// Converts this metadata to a map representation.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'format': format,
    'durationMs': duration.inMilliseconds,
    'tracks': tracks.map((t) => t.toMap()).toList(),
    if (creationTime != null) 'creationTimeMs': creationTime!.millisecondsSinceEpoch,
    if (modificationTime != null) 'modificationTimeMs': modificationTime!.millisecondsSinceEpoch,
    if (timescale != null) 'timescale': timescale,
    if (compatibleBrands.isNotEmpty) 'compatibleBrands': compatibleBrands,
  };

  /// Creates a copy with the given fields replaced.
  ContainerMetadata copyWith({
    String? format,
    Duration? duration,
    List<ContainerTrack>? tracks,
    DateTime? creationTime,
    DateTime? modificationTime,
    int? timescale,
    List<String>? compatibleBrands,
  }) => ContainerMetadata(
    format: format ?? this.format,
    duration: duration ?? this.duration,
    tracks: tracks ?? this.tracks,
    creationTime: creationTime ?? this.creationTime,
    modificationTime: modificationTime ?? this.modificationTime,
    timescale: timescale ?? this.timescale,
    compatibleBrands: compatibleBrands ?? this.compatibleBrands,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ContainerMetadata) return false;
    return format == other.format &&
        duration == other.duration &&
        listEquals(tracks, other.tracks) &&
        creationTime == other.creationTime &&
        modificationTime == other.modificationTime &&
        timescale == other.timescale &&
        listEquals(compatibleBrands, other.compatibleBrands);
  }

  @override
  int get hashCode => Object.hash(
    format,
    duration,
    Object.hashAll(tracks),
    creationTime,
    modificationTime,
    timescale,
    Object.hashAll(compatibleBrands),
  );

  @override
  String toString() =>
      'ContainerMetadata(format: $format, duration: $duration, '
      '${tracks.length} tracks)';
}
