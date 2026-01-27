/// Information about an embedded subtitle track in a container file.
///
/// Represents a subtitle track discovered in a media container (MP4, MKV, etc.)
/// that can be extracted and rendered.
class EmbeddedSubtitleTrack {
  /// Creates an embedded subtitle track info.
  const EmbeddedSubtitleTrack({
    required this.trackId,
    required this.codec,
    this.language,
    this.label,
    this.isDefault = false,
    this.isForced = false,
  });

  /// The track ID in the container.
  ///
  /// Used to identify which track to extract when extracting
  /// subtitles from a container file.
  final int trackId;

  /// Codec identifier (fourcc or codec ID).
  ///
  /// Common values:
  /// - **MP4**: `tx3g` (3GPP Timed Text), `stpp` (TTML), `wvtt` (WebVTT),
  ///   `c608` (CEA-608), `c708` (CEA-708)
  /// - **MKV**: `S_TEXT/UTF8` (SRT-style), `S_TEXT/ASS`, `S_TEXT/WEBVTT`,
  ///   `S_HDMV/PGS` (Blu-ray)
  final String codec;

  /// ISO 639-2/T language code (e.g., "eng", "fra", "spa").
  ///
  /// May be null if the container doesn't specify a language.
  final String? language;

  /// Human-readable label for the track.
  ///
  /// E.g., "English", "English (SDH)", "Commentary".
  final String? label;

  /// Whether this is the default subtitle track.
  final bool isDefault;

  /// Whether this is a forced subtitle track.
  ///
  /// Forced subtitles contain only essential dialogue
  /// (e.g., foreign language portions in an English film).
  final bool isForced;

  /// Human-readable codec name.
  String get codecName {
    final lower = codec.toLowerCase();

    // MP4 codecs
    if (lower == 'tx3g') return 'Timed Text';
    if (lower == 'stpp') return 'TTML';
    if (lower == 'wvtt') return 'WebVTT';
    if (lower == 'c608') return 'CEA-608';
    if (lower == 'c708') return 'CEA-708';
    if (lower == 'text') return 'Text';

    // MKV codecs
    if (lower == 's_text/utf8') return 'SRT';
    if (lower == 's_text/ass') return 'ASS';
    if (lower == 's_text/ssa') return 'SSA';
    if (lower == 's_text/webvtt') return 'WebVTT';
    if (lower == 's_hdmv/pgs') return 'PGS';
    if (lower == 's_vobsub') return 'VobSub';
    if (lower == 's_dvbsub') return 'DVB';

    return codec;
  }

  /// Whether this is a text-based subtitle format.
  ///
  /// Text-based formats can be parsed for styling information.
  /// Image-based formats (PGS, VobSub, DVB) cannot.
  bool get isTextBased {
    final lower = codec.toLowerCase();
    return lower == 'tx3g' ||
        lower == 'stpp' ||
        lower == 'wvtt' ||
        lower == 'text' ||
        lower == 's_text/utf8' ||
        lower == 's_text/ass' ||
        lower == 's_text/ssa' ||
        lower == 's_text/webvtt';
  }

  /// Whether this is an image-based subtitle format.
  ///
  /// Image-based formats (PGS, VobSub, DVB) require bitmap rendering.
  bool get isImageBased {
    final lower = codec.toLowerCase();
    return lower == 's_hdmv/pgs' || lower == 's_vobsub' || lower == 's_dvbsub' || lower == 'dvbs';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! EmbeddedSubtitleTrack) return false;
    return trackId == other.trackId &&
        codec == other.codec &&
        language == other.language &&
        label == other.label &&
        isDefault == other.isDefault &&
        isForced == other.isForced;
  }

  @override
  int get hashCode => Object.hash(trackId, codec, language, label, isDefault, isForced);

  @override
  String toString() =>
      'EmbeddedSubtitleTrack(id: $trackId, codec: $codecName, '
      'language: $language, label: $label, default: $isDefault, forced: $isForced)';
}
