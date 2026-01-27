/// Detailed codec information including profile and level.
///
/// Contains metadata about a codec used in a container track,
/// including the four-character code, human-readable name,
/// and optional profile/level information for codec string generation.
///
/// Example:
/// ```dart
/// const h264Codec = CodecInfo(
///   fourcc: 'avc1',
///   name: 'H.264',
///   codecString: 'avc1.64001f',
///   mimeType: 'video/mp4; codecs=avc1.64001f',
///   profile: 100, // High profile
///   level: 31,    // Level 3.1
/// );
///
/// print(h264Codec.isVideoCodec); // true
/// print(h264Codec.codecString);  // 'avc1.64001f'
/// ```
class CodecInfo {
  /// Creates codec information with required fourcc and name.
  const CodecInfo({
    required this.fourcc,
    required this.name,
    this.codecString,
    this.mimeType,
    this.profile,
    this.level,
  });

  /// Creates a [CodecInfo] from a map representation.
  factory CodecInfo.fromMap(Map<String, dynamic> map) => CodecInfo(
    fourcc: map['fourcc'] as String? ?? '',
    name: map['name'] as String? ?? 'Unknown',
    codecString: map['codecString'] as String?,
    mimeType: map['mimeType'] as String?,
    profile: map['profile'] as int?,
    level: map['level'] as int?,
  );

  /// An empty codec info with unknown values.
  static const CodecInfo empty = CodecInfo(fourcc: '', name: 'Unknown');

  /// Four character code (e.g., "avc1", "hvc1", "mp4a").
  ///
  /// This is the codec identifier from the container's sample entry.
  final String fourcc;

  /// Human-readable codec name (e.g., "H.264", "HEVC", "AAC").
  final String name;

  /// Full codec string including profile and level.
  ///
  /// Examples:
  /// - H.264: "avc1.64001f" (High profile, level 3.1)
  /// - HEVC: "hvc1.1.6.L93.B0" (Main profile, level 3.1)
  /// - VP9: "vp09.00.41.08"
  /// - AV1: "av01.0.04M.08"
  final String? codecString;

  /// MIME type for codec compatibility checking.
  ///
  /// Used primarily for web `canPlayType()` and `isTypeSupported()` checks.
  /// Examples:
  /// - "video/mp4; codecs=avc1.64001f"
  /// - "video/webm; codecs=vp9"
  /// - "audio/mp4; codecs=mp4a.40.2"
  final String? mimeType;

  /// Profile identifier (codec-specific).
  ///
  /// For H.264: 66=Baseline, 77=Main, 100=High
  /// For HEVC: 1=Main, 2=Main 10
  final int? profile;

  /// Level identifier (codec-specific).
  ///
  /// For H.264/HEVC: Level * 10 (e.g., 31 = Level 3.1)
  final int? level;

  /// Whether this codec info has no valid data.
  bool get isEmpty => fourcc.isEmpty;

  /// Whether this codec is a known video codec.
  ///
  /// Recognizes H.264, HEVC, VP9, AV1, and other video codecs.
  bool get isVideoCodec {
    final lower = fourcc.toLowerCase();
    return lower == 'avc1' ||
        lower == 'avc3' ||
        lower == 'hvc1' ||
        lower == 'hev1' ||
        lower == 'vp08' ||
        lower == 'vp09' ||
        lower == 'av01' ||
        lower == 'mp4v' ||
        lower == 'encv' ||
        lower == 's263' ||
        lower == 'h263';
  }

  /// Whether this codec is a known audio codec.
  ///
  /// Recognizes AAC, AC3, EAC3, Opus, ALAC, FLAC, MP3, and others.
  bool get isAudioCodec {
    final lower = fourcc.toLowerCase();
    return lower == 'mp4a' ||
        lower == 'ac-3' ||
        lower == 'ec-3' ||
        lower == 'opus' ||
        lower == 'alac' ||
        lower == 'flac' ||
        lower == 'mp3 ' ||
        lower == '.mp3' ||
        lower == 'dtsc' ||
        lower == 'dtsh' ||
        lower == 'dtsl' ||
        lower == 'dtse' ||
        lower == 'enca' ||
        lower == 'mlpa';
  }

  /// Whether this codec is a known subtitle codec.
  ///
  /// Recognizes text, tx3g, WebVTT, TTML (stpp), and c608.
  bool get isSubtitleCodec {
    final lower = fourcc.toLowerCase();
    return lower == 'text' ||
        lower == 'tx3g' ||
        lower == 'wvtt' ||
        lower == 'stpp' ||
        lower == 'c608' ||
        lower == 'c708';
  }

  /// Converts this codec info to a map representation.
  ///
  /// Only includes non-null fields to minimize data transfer.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'fourcc': fourcc,
    'name': name,
    if (codecString != null) 'codecString': codecString,
    if (mimeType != null) 'mimeType': mimeType,
    if (profile != null) 'profile': profile,
    if (level != null) 'level': level,
  };

  /// Creates a copy with the given fields replaced.
  CodecInfo copyWith({String? fourcc, String? name, String? codecString, String? mimeType, int? profile, int? level}) =>
      CodecInfo(
        fourcc: fourcc ?? this.fourcc,
        name: name ?? this.name,
        codecString: codecString ?? this.codecString,
        mimeType: mimeType ?? this.mimeType,
        profile: profile ?? this.profile,
        level: level ?? this.level,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CodecInfo) return false;
    return fourcc == other.fourcc &&
        name == other.name &&
        codecString == other.codecString &&
        mimeType == other.mimeType &&
        profile == other.profile &&
        level == other.level;
  }

  @override
  int get hashCode => Object.hash(fourcc, name, codecString, mimeType, profile, level);

  @override
  String toString() =>
      'CodecInfo(fourcc: $fourcc, name: $name, codecString: $codecString, '
      'mimeType: $mimeType, profile: $profile, level: $level)';
}
