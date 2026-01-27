import 'hls_playlist_writer.dart';

/// Configuration for video remuxing operations.
class RemuxConfig {
  /// Creates a remux configuration.
  const RemuxConfig({
    this.segmentDuration = const Duration(seconds: 6),
    this.outputFormat = HlsOutputFormat.fmp4,
    this.playlistType = HlsPlaylistType.vod,
    this.alignToKeyframes = true,
    this.includeAudio = true,
    this.includeSubtitles = true,
    this.generateMasterPlaylist = true,
    this.hlsVersion = 7,
  });

  /// Target duration for each segment.
  ///
  /// The actual duration may vary based on keyframe alignment.
  /// Default is 6 seconds, which is optimal for most use cases.
  final Duration segmentDuration;

  /// Output format for HLS segments.
  ///
  /// - [HlsOutputFormat.fmp4]: Fragmented MP4 (recommended for modern players)
  /// - [HlsOutputFormat.mpegts]: MPEG-TS (legacy compatibility)
  final HlsOutputFormat outputFormat;

  /// Playlist type for the output HLS.
  ///
  /// - [HlsPlaylistType.vod]: Video-on-demand (includes #EXT-X-ENDLIST)
  /// - [HlsPlaylistType.live]: Live streaming (no end marker)
  /// - [HlsPlaylistType.event]: Event streaming (grows until complete)
  final HlsPlaylistType playlistType;

  /// Whether to align segment boundaries to keyframes.
  ///
  /// When true (default), segments will start at keyframes for efficient
  /// seeking and better compression. This may cause segment durations
  /// to vary from the target.
  final bool alignToKeyframes;

  /// Whether to include audio tracks in the output.
  final bool includeAudio;

  /// Whether to include subtitle tracks in the output.
  final bool includeSubtitles;

  /// Whether to generate a master playlist.
  ///
  /// When true (default), generates a master playlist that references
  /// the media playlists. Set to false for single-quality output.
  final bool generateMasterPlaylist;

  /// HLS version for the output playlists.
  ///
  /// Default is 7, which supports fMP4 and byte ranges.
  /// Use version 3 for maximum legacy compatibility (TS only).
  final int hlsVersion;

  /// Creates a copy with modified values.
  RemuxConfig copyWith({
    Duration? segmentDuration,
    HlsOutputFormat? outputFormat,
    HlsPlaylistType? playlistType,
    bool? alignToKeyframes,
    bool? includeAudio,
    bool? includeSubtitles,
    bool? generateMasterPlaylist,
    int? hlsVersion,
  }) => RemuxConfig(
    segmentDuration: segmentDuration ?? this.segmentDuration,
    outputFormat: outputFormat ?? this.outputFormat,
    playlistType: playlistType ?? this.playlistType,
    alignToKeyframes: alignToKeyframes ?? this.alignToKeyframes,
    includeAudio: includeAudio ?? this.includeAudio,
    includeSubtitles: includeSubtitles ?? this.includeSubtitles,
    generateMasterPlaylist: generateMasterPlaylist ?? this.generateMasterPlaylist,
    hlsVersion: hlsVersion ?? this.hlsVersion,
  );

  @override
  String toString() =>
      'RemuxConfig(segmentDuration: $segmentDuration, '
      'format: $outputFormat, playlistType: $playlistType, '
      'alignToKeyframes: $alignToKeyframes)';
}
