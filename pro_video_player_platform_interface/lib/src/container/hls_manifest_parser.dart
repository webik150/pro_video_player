import 'package:http/http.dart' as http;

/// Metadata extracted from an HLS master playlist.
///
/// Contains information about available video variants, audio tracks,
/// and subtitle tracks without downloading any media segments.
///
/// Example:
/// ```dart
/// final metadata = await HlsManifestParser.parse(m3u8Url);
/// if (metadata != null) {
///   print('Variants: ${metadata.variants.length}');
///   for (final variant in metadata.variants) {
///     print('  ${variant.resolution} @ ${variant.bandwidth ~/ 1000} kbps');
///   }
/// }
/// ```
class HlsManifestMetadata {
  /// Creates HLS manifest metadata.
  const HlsManifestMetadata({
    required this.variants,
    this.audioTracks = const [],
    this.subtitleTracks = const [],
    this.sessionData = const {},
    this.isLive = false,
  });

  /// Video variants (quality levels) available in the stream.
  final List<HlsVariant> variants;

  /// Alternative audio tracks (e.g., different languages).
  final List<HlsAudioTrack> audioTracks;

  /// Subtitle tracks available in the stream.
  final List<HlsSubtitleTrack> subtitleTracks;

  /// Session data from the manifest (key-value pairs).
  final Map<String, String> sessionData;

  /// Whether this is a live stream (vs VOD).
  final bool isLive;

  /// Returns the highest quality variant by bandwidth.
  HlsVariant? get highestQuality =>
      variants.isEmpty ? null : variants.reduce((a, b) => a.bandwidth > b.bandwidth ? a : b);

  /// Returns the lowest quality variant by bandwidth.
  HlsVariant? get lowestQuality =>
      variants.isEmpty ? null : variants.reduce((a, b) => a.bandwidth < b.bandwidth ? a : b);

  /// Returns variants sorted by bandwidth (ascending).
  List<HlsVariant> get variantsByBandwidth => [...variants]..sort((a, b) => a.bandwidth.compareTo(b.bandwidth));

  @override
  String toString() =>
      'HlsManifestMetadata(variants: ${variants.length}, audio: ${audioTracks.length}, subtitles: ${subtitleTracks.length})';
}

/// A video variant (quality level) in an HLS stream.
class HlsVariant {
  /// Creates an HLS variant.
  const HlsVariant({
    required this.bandwidth,
    required this.url,
    this.averageBandwidth,
    this.codecs,
    this.resolution,
    this.frameRate,
    this.hdcpLevel,
    this.audioGroupId,
    this.subtitleGroupId,
    this.closedCaptionsGroupId,
  });

  /// Peak bandwidth in bits per second.
  final int bandwidth;

  /// Average bandwidth in bits per second (may be null).
  final int? averageBandwidth;

  /// Codec string (e.g., "avc1.64001f,mp4a.40.2").
  final String? codecs;

  /// Video resolution (e.g., "1920x1080").
  final String? resolution;

  /// Frame rate (e.g., 29.97).
  final double? frameRate;

  /// HDCP level required (e.g., "TYPE-0", "TYPE-1", "NONE").
  final String? hdcpLevel;

  /// Reference to audio group for this variant.
  final String? audioGroupId;

  /// Reference to subtitle group for this variant.
  final String? subtitleGroupId;

  /// Reference to closed captions group for this variant.
  final String? closedCaptionsGroupId;

  /// URL of the variant playlist.
  final String url;

  /// Parses width from resolution string.
  int? get width {
    if (resolution == null) return null;
    final parts = resolution!.split('x');
    return parts.length == 2 ? int.tryParse(parts[0]) : null;
  }

  /// Parses height from resolution string.
  int? get height {
    if (resolution == null) return null;
    final parts = resolution!.split('x');
    return parts.length == 2 ? int.tryParse(parts[1]) : null;
  }

  /// Returns video codec from codecs string.
  String? get videoCodec {
    if (codecs == null) return null;
    final parts = codecs!.split(',');
    for (final codec in parts) {
      final trimmed = codec.trim();
      if (trimmed.startsWith('avc') ||
          trimmed.startsWith('hvc') ||
          trimmed.startsWith('hev') ||
          trimmed.startsWith('vp0') ||
          trimmed.startsWith('av01')) {
        return trimmed;
      }
    }
    return null;
  }

  /// Returns audio codec from codecs string.
  String? get audioCodec {
    if (codecs == null) return null;
    final parts = codecs!.split(',');
    for (final codec in parts) {
      final trimmed = codec.trim();
      if (trimmed.startsWith('mp4a') ||
          trimmed.startsWith('ac-3') ||
          trimmed.startsWith('ec-3') ||
          trimmed.startsWith('opus') ||
          trimmed.startsWith('flac')) {
        return trimmed;
      }
    }
    return null;
  }

  /// Returns human-readable quality label (e.g., "1080p", "720p").
  String get qualityLabel {
    final h = height;
    if (h == null) return '${bandwidth ~/ 1000} kbps';
    if (h >= 2160) return '4K';
    if (h >= 1440) return '1440p';
    if (h >= 1080) return '1080p';
    if (h >= 720) return '720p';
    if (h >= 480) return '480p';
    if (h >= 360) return '360p';
    return '${h}p';
  }

  @override
  String toString() => 'HlsVariant($qualityLabel, ${bandwidth ~/ 1000} kbps, codecs: $codecs)';
}

/// An alternative audio track in an HLS stream.
class HlsAudioTrack {
  /// Creates an HLS audio track.
  const HlsAudioTrack({
    required this.groupId,
    required this.name,
    this.language,
    this.uri,
    this.isDefault = false,
    this.isAutoSelect = false,
    this.channels,
    this.codecs,
  });

  /// Group ID this track belongs to.
  final String groupId;

  /// Display name of the track.
  final String name;

  /// Language code (e.g., "en", "es", "fr").
  final String? language;

  /// URI of the audio playlist (null for muxed audio).
  final String? uri;

  /// Whether this is the default track.
  final bool isDefault;

  /// Whether this track should be auto-selected.
  final bool isAutoSelect;

  /// Number of audio channels (e.g., "2", "6" for 5.1).
  final String? channels;

  /// Audio codec (e.g., "mp4a.40.2").
  final String? codecs;

  @override
  String toString() => 'HlsAudioTrack($name, lang: $language, default: $isDefault)';
}

/// A subtitle track in an HLS stream.
class HlsSubtitleTrack {
  /// Creates an HLS subtitle track.
  const HlsSubtitleTrack({
    required this.groupId,
    required this.name,
    this.language,
    this.uri,
    this.isDefault = false,
    this.isAutoSelect = false,
    this.isForced = false,
    this.characteristics,
  });

  /// Group ID this track belongs to.
  final String groupId;

  /// Display name of the track.
  final String name;

  /// Language code (e.g., "en", "es", "fr").
  final String? language;

  /// URI of the subtitle playlist.
  final String? uri;

  /// Whether this is the default track.
  final bool isDefault;

  /// Whether this track should be auto-selected.
  final bool isAutoSelect;

  /// Whether this is a forced subtitle track (e.g., for foreign language dialogue).
  final bool isForced;

  /// Accessibility characteristics (e.g., "public.accessibility.describes-video").
  final String? characteristics;

  /// Whether this is an SDH (Subtitles for Deaf/Hard of hearing) track.
  bool get isSDH => characteristics?.contains('accessibility') ?? false;

  @override
  String toString() => 'HlsSubtitleTrack($name, lang: $language, default: $isDefault, forced: $isForced)';
}

/// Parser for HLS (HTTP Live Streaming) master playlists.
///
/// Extracts metadata from HLS manifests including:
/// - Video variants (quality levels) with bandwidth, resolution, codecs
/// - Alternative audio tracks with language and codec info
/// - Subtitle tracks with language info
///
/// Example:
/// ```dart
/// // From URL
/// final metadata = await HlsManifestParser.parseUrl(
///   Uri.parse('https://example.com/master.m3u8'),
/// );
///
/// // From content
/// final metadata = HlsManifestParser.parse(m3u8Content, baseUrl);
///
/// // List available qualities
/// for (final variant in metadata?.variants ?? []) {
///   print('${variant.qualityLabel}: ${variant.codecs}');
/// }
/// ```
class HlsManifestParser {
  HlsManifestParser._();

  /// Parses HLS manifest metadata from a URL.
  ///
  /// Fetches the manifest and parses it. Returns null if the URL
  /// is not accessible or the content is not a valid HLS manifest.
  static Future<HlsManifestMetadata?> parseUrl(Uri url, {http.Client? client, Map<String, String>? headers}) async {
    final httpClient = client ?? http.Client();
    final shouldCloseClient = client == null;

    try {
      final response = await httpClient.get(url, headers: headers);
      if (response.statusCode != 200) return null;

      return parse(response.body, url.toString());
    } finally {
      if (shouldCloseClient) {
        httpClient.close();
      }
    }
  }

  /// Parses HLS manifest metadata from content string.
  ///
  /// [content] is the raw M3U8 playlist content.
  /// [baseUrl] is used to resolve relative URLs in the manifest.
  ///
  /// Returns null if the content is not a valid HLS manifest.
  static HlsManifestMetadata? parse(String content, String baseUrl) {
    if (!content.contains('#EXTM3U')) return null;

    // Check if this is a master playlist (has stream-inf or media tags)
    final isMaster = content.contains('#EXT-X-STREAM-INF') || content.contains('#EXT-X-MEDIA');

    if (!isMaster) {
      // This is a media playlist, not a master playlist
      // Return minimal metadata
      final isLive = !content.contains('#EXT-X-ENDLIST');
      return HlsManifestMetadata(variants: const [], isLive: isLive);
    }

    final variants = <HlsVariant>[];
    final audioTracks = <HlsAudioTrack>[];
    final subtitleTracks = <HlsSubtitleTrack>[];
    final sessionData = <String, String>{};

    final lines = content.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Parse #EXT-X-STREAM-INF (video variants)
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        final attrs = _parseAttributes(line.substring(18));
        final nextLine = i + 1 < lines.length ? lines[i + 1].trim() : '';

        if (nextLine.isNotEmpty && !nextLine.startsWith('#')) {
          final url = _resolveUrl(nextLine, baseUrl);
          variants.add(
            HlsVariant(
              bandwidth: int.tryParse(attrs['BANDWIDTH'] ?? '') ?? 0,
              averageBandwidth: int.tryParse(attrs['AVERAGE-BANDWIDTH'] ?? ''),
              codecs: attrs['CODECS'],
              resolution: attrs['RESOLUTION'],
              frameRate: double.tryParse(attrs['FRAME-RATE'] ?? ''),
              hdcpLevel: attrs['HDCP-LEVEL'],
              audioGroupId: attrs['AUDIO'],
              subtitleGroupId: attrs['SUBTITLES'],
              closedCaptionsGroupId: attrs['CLOSED-CAPTIONS'],
              url: url,
            ),
          );
        }
        continue;
      }

      // Parse #EXT-X-MEDIA (audio and subtitle tracks)
      if (line.startsWith('#EXT-X-MEDIA:')) {
        final attrs = _parseAttributes(line.substring(13));
        final type = attrs['TYPE'];
        final groupId = attrs['GROUP-ID'] ?? '';
        final name = attrs['NAME'] ?? '';
        final language = attrs['LANGUAGE'];
        final uri = attrs['URI'] != null ? _resolveUrl(attrs['URI']!, baseUrl) : null;
        final isDefault = attrs['DEFAULT'] == 'YES';
        final isAutoSelect = attrs['AUTOSELECT'] == 'YES';

        if (type == 'AUDIO') {
          audioTracks.add(
            HlsAudioTrack(
              groupId: groupId,
              name: name,
              language: language,
              uri: uri,
              isDefault: isDefault,
              isAutoSelect: isAutoSelect,
              channels: attrs['CHANNELS'],
              codecs: attrs['CODECS'],
            ),
          );
        } else if (type == 'SUBTITLES') {
          subtitleTracks.add(
            HlsSubtitleTrack(
              groupId: groupId,
              name: name,
              language: language,
              uri: uri,
              isDefault: isDefault,
              isAutoSelect: isAutoSelect,
              isForced: attrs['FORCED'] == 'YES',
              characteristics: attrs['CHARACTERISTICS'],
            ),
          );
        }
        continue;
      }

      // Parse #EXT-X-SESSION-DATA
      if (line.startsWith('#EXT-X-SESSION-DATA:')) {
        final attrs = _parseAttributes(line.substring(20));
        final dataId = attrs['DATA-ID'];
        final value = attrs['VALUE'];
        if (dataId != null && value != null) {
          sessionData[dataId] = value;
        }
        continue;
      }
    }

    return HlsManifestMetadata(
      variants: variants,
      audioTracks: audioTracks,
      subtitleTracks: subtitleTracks,
      sessionData: sessionData,
      isLive: !content.contains('#EXT-X-ENDLIST'),
    );
  }

  /// Parses HLS attribute string into key-value pairs.
  static Map<String, String> _parseAttributes(String attrString) {
    final attrs = <String, String>{};
    final regex = RegExp('([A-Z-]+)=(?:"([^"]*)"|([^,]*))');

    for (final match in regex.allMatches(attrString)) {
      final key = match.group(1)!;
      final value = match.group(2) ?? match.group(3) ?? '';
      attrs[key] = value;
    }

    return attrs;
  }

  /// Resolves a potentially relative URL against a base URL.
  static String _resolveUrl(String url, String baseUrl) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    final baseUri = Uri.parse(baseUrl);

    if (url.startsWith('/')) {
      return '${baseUri.scheme}://${baseUri.authority}$url';
    }

    final basePath = baseUri.path.substring(0, baseUri.path.lastIndexOf('/') + 1);
    return '${baseUri.scheme}://${baseUri.authority}$basePath$url';
  }
}
