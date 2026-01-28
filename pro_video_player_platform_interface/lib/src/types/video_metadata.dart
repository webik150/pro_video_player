import 'media_metadata.dart' show MediaMetadata;
import 'subtitle_track.dart';

/// Metadata extracted from a video file or stream.
///
/// This contains both technical information (encoding, resolution, bitrate)
/// and descriptive metadata (title, artist, album) when available.
///
/// For display in media controls (Now Playing, notifications), use
/// [MediaMetadata] which is specifically designed for that purpose.
///
/// Video metadata is automatically extracted when a video is loaded and can
/// be accessed via the controller's `videoMetadata` property, or extracted
/// standalone using `ProVideoPlayerController.extractMetadata()`.
///
/// Example:
/// ```dart
/// // Access metadata after video is loaded
/// final metadata = controller.videoMetadata;
/// if (metadata != null) {
///   print('Title: ${metadata.title}');
///   print('Codec: ${metadata.videoCodec}');
///   print('Resolution: ${metadata.resolution}');
///   print('Subtitles: ${metadata.subtitleTracks?.length ?? 0} tracks');
/// }
/// ```
class VideoMetadata {
  /// Creates video metadata with optional fields.
  ///
  /// All fields are optional since not all platforms can extract all metadata.
  const VideoMetadata({
    // Technical metadata
    this.videoCodec,
    this.audioCodec,
    this.width,
    this.height,
    this.videoBitrate,
    this.audioBitrate,
    this.frameRate,
    this.duration,
    this.containerFormat,
    this.fileSize,
    this.audioSampleRate,
    this.audioChannels,
    // Descriptive metadata
    this.title,
    this.artist,
    this.album,
    this.year,
    this.genre,
    // Track information
    this.subtitleTracks,
    this.audioTrackCount,
  });

  /// Creates a [VideoMetadata] from a map representation.
  ///
  /// Used for deserializing metadata from platform channels.
  factory VideoMetadata.fromMap(Map<String, dynamic> map) => VideoMetadata(
    // Technical metadata
    videoCodec: map['videoCodec'] as String?,
    audioCodec: map['audioCodec'] as String?,
    width: map['width'] as int?,
    height: map['height'] as int?,
    videoBitrate: map['videoBitrate'] as int?,
    audioBitrate: map['audioBitrate'] as int?,
    frameRate: (map['frameRate'] as num?)?.toDouble(),
    duration: map['durationMs'] != null ? Duration(milliseconds: map['durationMs'] as int) : null,
    containerFormat: map['containerFormat'] as String?,
    fileSize: map['fileSize'] as int?,
    audioSampleRate: map['audioSampleRate'] as int?,
    audioChannels: map['audioChannels'] as int?,
    // Descriptive metadata
    title: map['title'] as String?,
    artist: map['artist'] as String?,
    album: map['album'] as String?,
    year: map['year'] as int?,
    genre: map['genre'] as String?,
    // Track information
    audioTrackCount: map['audioTrackCount'] as int?,
  );

  /// An empty metadata instance with all fields set to null.
  static const VideoMetadata empty = VideoMetadata();

  /// The video codec (e.g., "h264", "hevc", "vp9", "av1").
  final String? videoCodec;

  /// The audio codec (e.g., "aac", "mp3", "opus", "ac3").
  final String? audioCodec;

  /// The video width in pixels.
  final int? width;

  /// The video height in pixels.
  final int? height;

  /// The video bitrate in bits per second.
  final int? videoBitrate;

  /// The audio bitrate in bits per second.
  final int? audioBitrate;

  /// The frame rate in frames per second (e.g., 29.97, 30.0, 60.0).
  final double? frameRate;

  /// The total duration of the video.
  final Duration? duration;

  /// The container format (e.g., "mp4", "mkv", "webm", "hls").
  final String? containerFormat;

  /// The file size in bytes.
  ///
  /// For local files, this is the actual file size.
  /// For network sources, this is obtained from HTTP Content-Length header.
  /// May be null for live streams or when size cannot be determined.
  final int? fileSize;

  /// The audio sample rate in Hz (e.g., 44100, 48000).
  final int? audioSampleRate;

  /// The number of audio channels (e.g., 1=mono, 2=stereo, 6=5.1 surround).
  final int? audioChannels;

  // ==================== Descriptive Metadata ====================

  /// The title of the video (from container metadata).
  ///
  /// Available when the video file has embedded title metadata, such as:
  /// - iTunes movies with title tags
  /// - MKV files with title metadata
  /// - MP4 files with ©nam atom
  final String? title;

  /// The artist or creator of the video.
  ///
  /// May contain the director, channel name, or content creator.
  final String? artist;

  /// The album or collection name.
  ///
  /// For TV shows, this might be the series name.
  final String? album;

  /// The release year of the video.
  final int? year;

  /// The genre of the video content.
  final String? genre;

  // ==================== Track Information ====================

  /// List of available subtitle tracks.
  ///
  /// Contains information about embedded and detected subtitle tracks,
  /// including language and label. Returns null if no subtitle tracks
  /// were detected or if track detection is not supported.
  final List<SubtitleTrack>? subtitleTracks;

  /// The number of audio tracks available.
  ///
  /// Returns null if audio track count could not be determined.
  final int? audioTrackCount;

  /// Returns `true` if all metadata fields are null.
  bool get isEmpty =>
      videoCodec == null &&
      audioCodec == null &&
      width == null &&
      height == null &&
      videoBitrate == null &&
      audioBitrate == null &&
      frameRate == null &&
      duration == null &&
      containerFormat == null &&
      fileSize == null &&
      audioSampleRate == null &&
      audioChannels == null &&
      title == null &&
      artist == null &&
      album == null &&
      year == null &&
      genre == null &&
      subtitleTracks == null &&
      audioTrackCount == null;

  /// Returns `true` if any metadata field is set.
  bool get isNotEmpty => !isEmpty;

  /// The total bitrate (video + audio) in bits per second.
  ///
  /// Returns `null` if either bitrate is not available.
  int? get totalBitrate {
    if (videoBitrate == null || audioBitrate == null) return null;
    return videoBitrate! + audioBitrate!;
  }

  /// The aspect ratio (width / height).
  ///
  /// Returns `null` if dimensions are not available or height is zero.
  double? get aspectRatio {
    if (width == null || height == null || height == 0) return null;
    return width! / height!;
  }

  /// The resolution as a formatted string (e.g., "1920x1080").
  ///
  /// Returns `null` if dimensions are not available.
  String? get resolution {
    if (width == null || height == null) return null;
    return '${width}x$height';
  }

  /// Returns `true` if the video is HD quality (720p or higher).
  bool get isHD => height != null && height! >= 720;

  /// Returns `true` if the video is 4K quality (2160p or higher).
  bool get is4K => height != null && height! >= 2160;

  /// The video bitrate in megabits per second.
  ///
  /// Returns `null` if video bitrate is not available.
  double? get videoBitrateInMbps {
    if (videoBitrate == null) return null;
    return videoBitrate! / 1000000.0;
  }

  /// The audio bitrate in kilobits per second.
  ///
  /// Returns `null` if audio bitrate is not available.
  double? get audioBitrateInKbps {
    if (audioBitrate == null) return null;
    return audioBitrate! / 1000.0;
  }

  /// Creates a copy of this metadata with the given fields replaced.
  VideoMetadata copyWith({
    String? videoCodec,
    String? audioCodec,
    int? width,
    int? height,
    int? videoBitrate,
    int? audioBitrate,
    double? frameRate,
    Duration? duration,
    String? containerFormat,
    int? fileSize,
    int? audioSampleRate,
    int? audioChannels,
    String? title,
    String? artist,
    String? album,
    int? year,
    String? genre,
    List<SubtitleTrack>? subtitleTracks,
    int? audioTrackCount,
  }) => VideoMetadata(
    videoCodec: videoCodec ?? this.videoCodec,
    audioCodec: audioCodec ?? this.audioCodec,
    width: width ?? this.width,
    height: height ?? this.height,
    videoBitrate: videoBitrate ?? this.videoBitrate,
    audioBitrate: audioBitrate ?? this.audioBitrate,
    frameRate: frameRate ?? this.frameRate,
    duration: duration ?? this.duration,
    containerFormat: containerFormat ?? this.containerFormat,
    fileSize: fileSize ?? this.fileSize,
    audioSampleRate: audioSampleRate ?? this.audioSampleRate,
    audioChannels: audioChannels ?? this.audioChannels,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    year: year ?? this.year,
    genre: genre ?? this.genre,
    subtitleTracks: subtitleTracks ?? this.subtitleTracks,
    audioTrackCount: audioTrackCount ?? this.audioTrackCount,
  );

  /// Converts this metadata to a map representation.
  ///
  /// Only includes non-null fields to minimize data transfer.
  Map<String, dynamic> toMap() => <String, dynamic>{
    if (videoCodec != null) 'videoCodec': videoCodec,
    if (audioCodec != null) 'audioCodec': audioCodec,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (videoBitrate != null) 'videoBitrate': videoBitrate,
    if (audioBitrate != null) 'audioBitrate': audioBitrate,
    if (frameRate != null) 'frameRate': frameRate,
    if (duration != null) 'durationMs': duration!.inMilliseconds,
    if (containerFormat != null) 'containerFormat': containerFormat,
    if (fileSize != null) 'fileSize': fileSize,
    if (audioSampleRate != null) 'audioSampleRate': audioSampleRate,
    if (audioChannels != null) 'audioChannels': audioChannels,
    if (title != null) 'title': title,
    if (artist != null) 'artist': artist,
    if (album != null) 'album': album,
    if (year != null) 'year': year,
    if (genre != null) 'genre': genre,
    if (audioTrackCount != null) 'audioTrackCount': audioTrackCount,
  };

  /// Returns `true` if this metadata has any descriptive fields set.
  bool get hasDescriptiveMetadata => title != null || artist != null || album != null || year != null || genre != null;

  /// Returns `true` if subtitle tracks are available.
  bool get hasSubtitles => subtitleTracks != null && subtitleTracks!.isNotEmpty;

  /// The number of subtitle tracks available.
  int get subtitleTrackCount => subtitleTracks?.length ?? 0;

  /// A fingerprint based on metadata only (without content sampling).
  ///
  /// This is a quick fingerprint that doesn't require reading file content.
  /// For robust deduplication that can distinguish trimmed versions,
  /// use [ProVideoPlayerController.extractContentFingerprint] instead.
  ///
  /// Returns `null` if insufficient metadata is available.
  String? get metadataFingerprint {
    // Need at least file size or duration for a meaningful fingerprint
    if (fileSize == null && duration == null) return null;

    // Build fingerprint from all available metadata
    final components = <String>[
      if (fileSize != null) 's$fileSize',
      if (duration != null) 'd${duration!.inMilliseconds}',
      if (width != null) 'w$width',
      if (height != null) 'h$height',
      if (videoCodec != null) 'vc$videoCodec',
      if (audioCodec != null) 'ac$audioCodec',
      if (videoBitrate != null) 'vb$videoBitrate',
      if (audioBitrate != null) 'ab$audioBitrate',
      if (frameRate != null) 'fr${frameRate!.toStringAsFixed(2)}',
      if (audioSampleRate != null) 'sr$audioSampleRate',
      if (audioChannels != null) 'ch$audioChannels',
    ];

    // Generate hash from components
    final hash = Object.hashAll(components);
    return hash.toRadixString(16).padLeft(16, '0');
  }

  /// The file size formatted as a human-readable string.
  ///
  /// Returns values like "1.5 GB", "256 MB", "45 KB".
  /// Returns `null` if file size is not available.
  String? get fileSizeFormatted {
    if (fileSize == null) return null;

    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;

    if (fileSize! >= gb) {
      return '${(fileSize! / gb).toStringAsFixed(1)} GB';
    } else if (fileSize! >= mb) {
      return '${(fileSize! / mb).toStringAsFixed(1)} MB';
    } else if (fileSize! >= kb) {
      return '${(fileSize! / kb).toStringAsFixed(0)} KB';
    } else {
      return '$fileSize bytes';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! VideoMetadata) return false;
    return videoCodec == other.videoCodec &&
        audioCodec == other.audioCodec &&
        width == other.width &&
        height == other.height &&
        videoBitrate == other.videoBitrate &&
        audioBitrate == other.audioBitrate &&
        frameRate == other.frameRate &&
        duration == other.duration &&
        containerFormat == other.containerFormat &&
        fileSize == other.fileSize &&
        audioSampleRate == other.audioSampleRate &&
        audioChannels == other.audioChannels &&
        title == other.title &&
        artist == other.artist &&
        album == other.album &&
        year == other.year &&
        genre == other.genre &&
        audioTrackCount == other.audioTrackCount &&
        _listEquals(subtitleTracks, other.subtitleTracks);
  }

  static bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    videoCodec,
    audioCodec,
    width,
    height,
    videoBitrate,
    audioBitrate,
    frameRate,
    duration,
    containerFormat,
    fileSize,
    audioSampleRate,
    audioChannels,
    title,
    artist,
    album,
    year,
    genre,
    Object.hash(audioTrackCount, subtitleTracks != null ? Object.hashAll(subtitleTracks!) : null),
  );

  @override
  String toString() {
    final parts = <String>[];
    if (title != null) parts.add('title: $title');
    if (artist != null) parts.add('artist: $artist');
    if (album != null) parts.add('album: $album');
    if (year != null) parts.add('year: $year');
    if (genre != null) parts.add('genre: $genre');
    if (videoCodec != null) parts.add('videoCodec: $videoCodec');
    if (audioCodec != null) parts.add('audioCodec: $audioCodec');
    if (width != null && height != null) parts.add('resolution: ${width}x$height');
    if (duration != null) parts.add('duration: $duration');
    if (fileSize != null) parts.add('fileSize: $fileSizeFormatted');
    if (containerFormat != null) parts.add('containerFormat: $containerFormat');
    if (audioSampleRate != null) parts.add('audioSampleRate: $audioSampleRate Hz');
    if (audioChannels != null) parts.add('audioChannels: $audioChannels');
    if (subtitleTracks != null) parts.add('subtitleTracks: ${subtitleTracks!.length}');
    if (audioTrackCount != null) parts.add('audioTracks: $audioTrackCount');
    return 'VideoMetadata(${parts.join(', ')})';
  }
}
