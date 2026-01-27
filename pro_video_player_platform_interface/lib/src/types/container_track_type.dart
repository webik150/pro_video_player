/// Type of media track within a container.
///
/// Used by `ContainerTrack` to identify the kind of media data
/// the track contains (video, audio, subtitles, etc.).
enum ContainerTrackType {
  /// Video track containing visual frames.
  video,

  /// Audio track containing sound data.
  audio,

  /// Subtitle or closed caption track.
  subtitle,

  /// Hint track for streaming protocols (RTP).
  hint,

  /// Metadata track (timed metadata, chapter info).
  metadata,

  /// Unknown or unrecognized track type.
  unknown;

  /// Creates a track type from an MP4 handler type string.
  ///
  /// MP4 files use four-character handler types in the `hdlr` box:
  /// - `vide` → video
  /// - `soun` → audio
  /// - `text`, `sbtl`, `subt` → subtitle
  /// - `hint` → hint
  /// - `meta` → metadata
  ///
  /// Returns [unknown] for unrecognized handler types.
  static ContainerTrackType fromHandlerType(String handlerType) => switch (handlerType) {
    'vide' => ContainerTrackType.video,
    'soun' => ContainerTrackType.audio,
    'text' || 'sbtl' || 'subt' => ContainerTrackType.subtitle,
    'hint' => ContainerTrackType.hint,
    'meta' => ContainerTrackType.metadata,
    _ => ContainerTrackType.unknown,
  };

  /// Human-readable display name for this track type.
  String get displayName => switch (this) {
    ContainerTrackType.video => 'Video',
    ContainerTrackType.audio => 'Audio',
    ContainerTrackType.subtitle => 'Subtitle',
    ContainerTrackType.hint => 'Hint',
    ContainerTrackType.metadata => 'Metadata',
    ContainerTrackType.unknown => 'Unknown',
  };

  /// Whether this track contains playable media (video or audio).
  ///
  /// Returns `true` for [video] and [audio] tracks.
  bool get isMedia => this == video || this == audio;
}
