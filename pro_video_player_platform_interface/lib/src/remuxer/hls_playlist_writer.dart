import 'sample_reader.dart';
import 'segment_writer.dart';

/// HLS output format for segments.
enum HlsOutputFormat {
  /// Fragmented MP4 segments (preferred for modern players).
  fmp4,

  /// MPEG-TS segments (legacy compatibility).
  mpegts,
}

/// Playlist type for HLS.
enum HlsPlaylistType {
  /// Video-on-demand playlist (has #EXT-X-ENDLIST).
  vod,

  /// Live/event playlist (no end marker initially).
  live,

  /// Event playlist (growing, will eventually end).
  event,
}

/// Information about a media segment for playlist generation.
class HlsSegmentInfo {
  /// Creates segment info.
  const HlsSegmentInfo({
    required this.filename,
    required this.duration,
    this.title,
    this.byteRange,
    this.discontinuity = false,
    this.programDateTime,
  });

  /// Segment filename (relative to playlist).
  final String filename;

  /// Segment duration in seconds.
  final double duration;

  /// Optional title for the segment.
  final String? title;

  /// Optional byte range for byte-range mode.
  final HlsByteRange? byteRange;

  /// Whether this segment starts a discontinuity.
  final bool discontinuity;

  /// Optional program date-time for this segment.
  final DateTime? programDateTime;
}

/// Byte range for HLS byte-range mode.
class HlsByteRange {
  /// Creates a byte range.
  const HlsByteRange({required this.length, this.offset});

  /// Length of the byte range.
  final int length;

  /// Optional offset from start of file.
  final int? offset;

  @override
  String toString() => offset != null ? '$length@$offset' : '$length';
}

/// Information about a variant stream for master playlist.
class HlsVariantInfo {
  /// Creates variant info.
  const HlsVariantInfo({
    required this.bandwidth,
    required this.playlistUri,
    this.averageBandwidth,
    this.codecs,
    this.resolution,
    this.frameRate,
    this.audioGroupId,
    this.subtitleGroupId,
    this.closedCaptionsGroupId,
  });

  /// Creates variant info from track codec info.
  factory HlsVariantInfo.fromTrack({
    required TrackCodecInfo track,
    required int bandwidth,
    required String playlistUri,
    String? audioGroupId,
  }) {
    String? codecs;
    String? resolution;

    // Map fourcc to HLS codec string
    codecs = _mapCodecFourcc(track.codecFourcc);

    if (track.isVideo) {
      if (track.width != null && track.height != null) {
        resolution = '${track.width}x${track.height}';
      }
    }

    return HlsVariantInfo(
      bandwidth: bandwidth,
      playlistUri: playlistUri,
      codecs: codecs,
      resolution: resolution,
      audioGroupId: audioGroupId,
    );
  }

  static String? _mapCodecFourcc(String fourcc) {
    switch (fourcc) {
      case 'avc1':
      case 'avc3':
        return 'avc1.64001f'; // H.264 High Profile Level 3.1 (generic)
      case 'hvc1':
      case 'hev1':
        return 'hvc1.1.6.L93.B0'; // H.265 Main Profile
      case 'vp09':
        return 'vp09.00.10.08';
      case 'av01':
        return 'av01.0.04M.08';
      case 'mp4a':
        return 'mp4a.40.2'; // AAC-LC
      case 'ac-3':
        return 'ac-3';
      case 'ec-3':
        return 'ec-3';
      default:
        return null;
    }
  }

  /// Peak bandwidth in bits per second.
  final int bandwidth;

  /// Average bandwidth in bits per second.
  final int? averageBandwidth;

  /// URI of the variant playlist.
  final String playlistUri;

  /// Codec string.
  final String? codecs;

  /// Video resolution (e.g., "1920x1080").
  final String? resolution;

  /// Frame rate.
  final double? frameRate;

  /// Audio group ID.
  final String? audioGroupId;

  /// Subtitle group ID.
  final String? subtitleGroupId;

  /// Closed captions group ID.
  final String? closedCaptionsGroupId;
}

/// Information about an audio track for master playlist.
class HlsAudioTrackInfo {
  /// Creates audio track info.
  const HlsAudioTrackInfo({
    required this.groupId,
    required this.name,
    this.language,
    this.uri,
    this.isDefault = false,
    this.autoSelect = true,
    this.channels,
    this.codecs,
  });

  /// Group ID.
  final String groupId;

  /// Display name.
  final String name;

  /// Language code (ISO 639-1 or 639-2).
  final String? language;

  /// Playlist URI (null for muxed audio).
  final String? uri;

  /// Whether this is the default track.
  final bool isDefault;

  /// Whether to auto-select.
  final bool autoSelect;

  /// Number of channels (e.g., "2" for stereo, "6" for 5.1).
  final String? channels;

  /// Audio codec.
  final String? codecs;
}

/// Information about a subtitle track for master playlist.
class HlsSubtitleTrackInfo {
  /// Creates subtitle track info.
  const HlsSubtitleTrackInfo({
    required this.groupId,
    required this.name,
    required this.uri,
    this.language,
    this.isDefault = false,
    this.autoSelect = true,
    this.forced = false,
    this.characteristics,
  });

  /// Group ID.
  final String groupId;

  /// Display name.
  final String name;

  /// Playlist URI.
  final String uri;

  /// Language code.
  final String? language;

  /// Whether this is the default track.
  final bool isDefault;

  /// Whether to auto-select.
  final bool autoSelect;

  /// Whether this is a forced subtitle.
  final bool forced;

  /// Accessibility characteristics.
  final String? characteristics;
}

/// Generates HLS playlists (M3U8).
///
/// Creates both master playlists (for adaptive streaming with multiple
/// qualities) and media playlists (for individual quality levels).
///
/// Example:
/// ```dart
/// // Media playlist
/// final playlist = HlsPlaylistWriter.writeMediaPlaylist(
///   segments: segmentInfos,
///   targetDuration: 6,
///   playlistType: HlsPlaylistType.vod,
///   initSegment: 'init.mp4',
/// );
///
/// // Master playlist
/// final master = HlsPlaylistWriter.writeMasterPlaylist(
///   variants: [variant720p, variant1080p],
///   audioTracks: [englishAudio, spanishAudio],
/// );
/// ```
class HlsPlaylistWriter {
  HlsPlaylistWriter._();

  /// Writes a media playlist (segment list).
  ///
  /// [segments] is the list of segment information.
  /// [targetDuration] is the maximum segment duration (rounded up).
  /// [playlistType] controls whether this is VOD, live, or event.
  /// [initSegment] is the initialization segment filename for fMP4.
  /// [mediaSequence] is the sequence number of the first segment.
  /// [version] is the HLS version (default 7 for fMP4 byte-range).
  static String writeMediaPlaylist({
    required List<HlsSegmentInfo> segments,
    required int targetDuration,
    HlsPlaylistType playlistType = HlsPlaylistType.vod,
    String? initSegment,
    int mediaSequence = 0,
    int version = 7,
    bool independentSegments = true,
  }) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('#EXTM3U');
    buffer.writeln('#EXT-X-VERSION:$version');
    buffer.writeln('#EXT-X-TARGETDURATION:$targetDuration');
    buffer.writeln('#EXT-X-MEDIA-SEQUENCE:$mediaSequence');

    // Playlist type
    switch (playlistType) {
      case HlsPlaylistType.vod:
        buffer.writeln('#EXT-X-PLAYLIST-TYPE:VOD');
      case HlsPlaylistType.event:
        buffer.writeln('#EXT-X-PLAYLIST-TYPE:EVENT');
      case HlsPlaylistType.live:
        // No playlist type tag for live
        break;
    }

    if (independentSegments) {
      buffer.writeln('#EXT-X-INDEPENDENT-SEGMENTS');
    }

    // Init segment for fMP4
    if (initSegment != null) {
      buffer.writeln('#EXT-X-MAP:URI="$initSegment"');
    }

    // Segments
    for (final segment in segments) {
      if (segment.discontinuity) {
        buffer.writeln('#EXT-X-DISCONTINUITY');
      }

      if (segment.programDateTime != null) {
        buffer.writeln('#EXT-X-PROGRAM-DATE-TIME:${_formatDateTime(segment.programDateTime!)}');
      }

      if (segment.byteRange != null) {
        buffer.writeln('#EXT-X-BYTERANGE:${segment.byteRange}');
      }

      // Duration with optional title
      final duration = segment.duration.toStringAsFixed(6);
      if (segment.title != null) {
        buffer.writeln('#EXTINF:$duration,${segment.title}');
      } else {
        buffer.writeln('#EXTINF:$duration,');
      }

      buffer.writeln(segment.filename);
    }

    // End marker for VOD and EVENT playlists
    if (playlistType == HlsPlaylistType.vod) {
      buffer.writeln('#EXT-X-ENDLIST');
    }

    return buffer.toString();
  }

  /// Writes a master playlist (variant list).
  ///
  /// [variants] is the list of quality variants.
  /// [audioTracks] is optional alternative audio tracks.
  /// [subtitleTracks] is optional subtitle tracks.
  /// [independentSegments] indicates segments can be decoded independently.
  static String writeMasterPlaylist({
    required List<HlsVariantInfo> variants,
    List<HlsAudioTrackInfo> audioTracks = const [],
    List<HlsSubtitleTrackInfo> subtitleTracks = const [],
    bool independentSegments = true,
    int version = 7,
  }) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('#EXTM3U');
    buffer.writeln('#EXT-X-VERSION:$version');

    if (independentSegments) {
      buffer.writeln('#EXT-X-INDEPENDENT-SEGMENTS');
    }

    // Audio tracks
    for (final audio in audioTracks) {
      buffer.write('#EXT-X-MEDIA:TYPE=AUDIO');
      buffer.write(',GROUP-ID="${audio.groupId}"');
      buffer.write(',NAME="${audio.name}"');
      if (audio.language != null) {
        buffer.write(',LANGUAGE="${audio.language}"');
      }
      if (audio.uri != null) {
        buffer.write(',URI="${audio.uri}"');
      }
      buffer.write(',DEFAULT=${audio.isDefault ? "YES" : "NO"}');
      buffer.write(',AUTOSELECT=${audio.autoSelect ? "YES" : "NO"}');
      if (audio.channels != null) {
        buffer.write(',CHANNELS="${audio.channels}"');
      }
      if (audio.codecs != null) {
        buffer.write(',CODECS="${audio.codecs}"');
      }
      buffer.writeln();
    }

    // Subtitle tracks
    for (final subtitle in subtitleTracks) {
      buffer.write('#EXT-X-MEDIA:TYPE=SUBTITLES');
      buffer.write(',GROUP-ID="${subtitle.groupId}"');
      buffer.write(',NAME="${subtitle.name}"');
      if (subtitle.language != null) {
        buffer.write(',LANGUAGE="${subtitle.language}"');
      }
      buffer.write(',URI="${subtitle.uri}"');
      buffer.write(',DEFAULT=${subtitle.isDefault ? "YES" : "NO"}');
      buffer.write(',AUTOSELECT=${subtitle.autoSelect ? "YES" : "NO"}');
      buffer.write(',FORCED=${subtitle.forced ? "YES" : "NO"}');
      if (subtitle.characteristics != null) {
        buffer.write(',CHARACTERISTICS="${subtitle.characteristics}"');
      }
      buffer.writeln();
    }

    // Variants
    for (final variant in variants) {
      buffer.write('#EXT-X-STREAM-INF:BANDWIDTH=${variant.bandwidth}');
      if (variant.averageBandwidth != null) {
        buffer.write(',AVERAGE-BANDWIDTH=${variant.averageBandwidth}');
      }
      if (variant.codecs != null) {
        buffer.write(',CODECS="${variant.codecs}"');
      }
      if (variant.resolution != null) {
        buffer.write(',RESOLUTION=${variant.resolution}');
      }
      if (variant.frameRate != null) {
        buffer.write(',FRAME-RATE=${variant.frameRate!.toStringAsFixed(3)}');
      }
      if (variant.audioGroupId != null) {
        buffer.write(',AUDIO="${variant.audioGroupId}"');
      }
      if (variant.subtitleGroupId != null) {
        buffer.write(',SUBTITLES="${variant.subtitleGroupId}"');
      }
      if (variant.closedCaptionsGroupId != null) {
        if (variant.closedCaptionsGroupId == 'NONE') {
          buffer.write(',CLOSED-CAPTIONS=NONE');
        } else {
          buffer.write(',CLOSED-CAPTIONS="${variant.closedCaptionsGroupId}"');
        }
      }
      buffer.writeln();
      buffer.writeln(variant.playlistUri);
    }

    return buffer.toString();
  }

  /// Generates segment info list from media segments.
  ///
  /// Converts MediaSegment objects to HlsSegmentInfo for playlist generation.
  static List<HlsSegmentInfo> segmentsToInfo(
    List<MediaSegment> segments, {
    String Function(int index)? filenameGenerator,
  }) {
    final generator = filenameGenerator ?? (i) => 'segment$i.m4s';

    return segments
        .where((s) => !s.isInitSegment)
        .map((s) => HlsSegmentInfo(filename: generator(s.index), duration: s.duration))
        .toList();
  }

  /// Formats a DateTime in ISO 8601 format for HLS.
  static String _formatDateTime(DateTime dt) => dt.toUtc().toIso8601String();
}

/// Result of remuxing to HLS.
class HlsOutput {
  /// Creates HLS output.
  const HlsOutput({
    required this.masterPlaylist,
    required this.mediaPlaylists,
    required this.initSegmentPath,
    required this.segmentPaths,
  });

  /// Master playlist content (M3U8).
  final String masterPlaylist;

  /// Media playlist contents by variant name.
  final Map<String, String> mediaPlaylists;

  /// Path to the init segment file.
  final String initSegmentPath;

  /// Paths to segment files.
  final List<String> segmentPaths;
}
