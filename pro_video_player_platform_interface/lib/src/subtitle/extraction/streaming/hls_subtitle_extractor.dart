import 'package:http/http.dart' as http;

import '../../../container/hls_manifest_parser.dart';
import '../../../types/subtitle_cue.dart';
import '../../vtt_parser.dart';

/// Subtitle track information from an HLS stream.
class HlsSubtitleInfo {
  /// Creates HLS subtitle info.
  const HlsSubtitleInfo({
    required this.groupId,
    required this.name,
    this.language,
    this.uri,
    this.isDefault = false,
    this.isAutoSelect = false,
    this.isForced = false,
    this.isSDH = false,
  });

  /// Creates from an [HlsSubtitleTrack].
  factory HlsSubtitleInfo.fromTrack(HlsSubtitleTrack track) => HlsSubtitleInfo(
    groupId: track.groupId,
    name: track.name,
    language: track.language,
    uri: track.uri,
    isDefault: track.isDefault,
    isAutoSelect: track.isAutoSelect,
    isForced: track.isForced,
    isSDH: track.isSDH,
  );

  /// Group ID this track belongs to.
  final String groupId;

  /// Display name of the track.
  final String name;

  /// Language code (e.g., "en", "es", "fr").
  final String? language;

  /// URI of the subtitle playlist or file.
  final String? uri;

  /// Whether this is the default track.
  final bool isDefault;

  /// Whether this track should be auto-selected.
  final bool isAutoSelect;

  /// Whether this is a forced subtitle track.
  final bool isForced;

  /// Whether this is an SDH (Subtitles for Deaf/Hard of hearing) track.
  final bool isSDH;

  @override
  String toString() => 'HlsSubtitleInfo($name, lang: $language, default: $isDefault, forced: $isForced)';
}

/// Extracts subtitles from HLS (HTTP Live Streaming) sources.
///
/// HLS typically uses external WebVTT files for subtitles. This extractor:
/// - Parses the HLS master playlist to find subtitle tracks
/// - Fetches and parses subtitle playlists
/// - Downloads and concatenates WebVTT segment files
///
/// ## Example
///
/// ```dart
/// final extractor = HlsSubtitleExtractor();
///
/// // List available tracks
/// final tracks = await extractor.listTracks(
///   Uri.parse('https://example.com/master.m3u8'),
/// );
///
/// // Extract subtitles from a track
/// if (tracks.isNotEmpty) {
///   final cues = await extractor.extractFromTrack(
///     Uri.parse('https://example.com/master.m3u8'),
///     tracks.first,
///   );
/// }
///
/// // Or extract by language
/// final cues = await extractor.extractByLanguage(
///   Uri.parse('https://example.com/master.m3u8'),
///   preferredLanguages: ['en', 'eng'],
/// );
/// ```
class HlsSubtitleExtractor {
  /// Creates an HLS subtitle extractor.
  ///
  /// Optionally provide an [http.Client] for custom HTTP configuration.
  HlsSubtitleExtractor({http.Client? client}) : _client = client;

  final http.Client? _client;

  /// Lists available subtitle tracks from an HLS master playlist.
  ///
  /// Returns an empty list if:
  /// - The URL is not accessible
  /// - The manifest is not a valid HLS master playlist
  /// - No subtitle tracks are defined
  Future<List<HlsSubtitleInfo>> listTracks(Uri masterPlaylistUrl, {Map<String, String>? headers}) async {
    try {
      final metadata = await HlsManifestParser.parseUrl(masterPlaylistUrl, client: _client, headers: headers);
      if (metadata == null) return [];

      return metadata.subtitleTracks.map(HlsSubtitleInfo.fromTrack).toList();
    } catch (_) {
      return [];
    }
  }

  /// Extracts subtitles from a specific track.
  ///
  /// The [track] should be obtained from [listTracks].
  /// Returns an empty list if the track has no URI or fetching fails.
  Future<List<SubtitleCue>> extractFromTrack(
    Uri masterPlaylistUrl,
    HlsSubtitleInfo track, {
    Map<String, String>? headers,
  }) async {
    if (track.uri == null) return [];

    final subtitleUri = _resolveUri(masterPlaylistUrl, track.uri!);
    return _fetchAndParseSubtitles(subtitleUri, headers: headers);
  }

  /// Extracts subtitles based on language preference.
  ///
  /// Parameters:
  /// - [masterPlaylistUrl]: URL of the HLS master playlist
  /// - [preferredLanguages]: Language codes in order of preference (e.g., ['en', 'eng', 'es'])
  ///
  /// Track selection logic:
  /// 1. If [preferredLanguages] is specified, select first matching track
  /// 2. Otherwise, select the track marked as default
  /// 3. If no default, select the first track
  ///
  /// Returns an empty list if no suitable track is found.
  Future<List<SubtitleCue>> extractByLanguage(
    Uri masterPlaylistUrl, {
    List<String>? preferredLanguages,
    Map<String, String>? headers,
  }) async {
    final tracks = await listTracks(masterPlaylistUrl, headers: headers);
    if (tracks.isEmpty) return [];

    // Select track based on preferences
    final selectedTrack = _selectTrack(tracks, preferredLanguages);
    if (selectedTrack == null) return [];

    return extractFromTrack(masterPlaylistUrl, selectedTrack, headers: headers);
  }

  /// Fetches subtitles from a URL (either playlist or direct WebVTT file).
  Future<List<SubtitleCue>> _fetchAndParseSubtitles(Uri uri, {Map<String, String>? headers}) async {
    final httpClient = _client ?? http.Client();
    final shouldCloseClient = _client == null;

    try {
      final response = await httpClient.get(uri, headers: headers);
      if (response.statusCode != 200) return [];

      final content = response.body;

      // Check if this is a subtitle playlist (m3u8) or direct subtitle file
      if (_isSubtitlePlaylist(content)) {
        return _extractFromPlaylist(uri, content, headers: headers);
      } else {
        // Direct subtitle file (WebVTT)
        return _parseSubtitleContent(content);
      }
    } finally {
      if (shouldCloseClient) {
        httpClient.close();
      }
    }
  }

  /// Checks if content is a subtitle playlist.
  bool _isSubtitlePlaylist(String content) =>
      content.contains('#EXTM3U') && (content.contains('#EXTINF') || content.contains('#EXT-X-TARGETDURATION'));

  /// Extracts subtitles from a subtitle playlist.
  Future<List<SubtitleCue>> _extractFromPlaylist(
    Uri playlistUri,
    String playlistContent, {
    Map<String, String>? headers,
  }) async {
    final segmentUris = _parseSegmentUris(playlistUri, playlistContent);
    if (segmentUris.isEmpty) return [];

    final httpClient = _client ?? http.Client();
    final shouldCloseClient = _client == null;

    try {
      final allCues = <SubtitleCue>[];
      var cueIndex = 0;

      for (final segmentUri in segmentUris) {
        final response = await httpClient.get(segmentUri, headers: headers);
        if (response.statusCode != 200) continue;

        final cues = _parseSubtitleContent(response.body);

        // Re-index cues to be sequential across all segments
        for (final cue in cues) {
          allCues.add(
            SubtitleCue(
              index: cueIndex++,
              start: cue.start,
              end: cue.end,
              text: cue.text,
              styledSpans: cue.styledSpans,
            ),
          );
        }
      }

      // Deduplicate cues that appear in multiple segments
      // HLS segments often repeat cues that span segment boundaries
      final uniqueCues = _deduplicateCues(allCues);

      // Sort by start time (segments may be out of order)
      uniqueCues.sort((a, b) => a.start.compareTo(b.start));

      // Re-index after sorting
      return uniqueCues.asMap().entries.map((e) {
        final cue = e.value;
        return SubtitleCue(index: e.key, start: cue.start, end: cue.end, text: cue.text, styledSpans: cue.styledSpans);
      }).toList();
    } finally {
      if (shouldCloseClient) {
        httpClient.close();
      }
    }
  }

  /// Parses segment URIs from a playlist.
  List<Uri> _parseSegmentUris(Uri playlistUri, String content) {
    final uris = <Uri>[];
    final lines = content.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Skip empty lines and comments
      if (line.isEmpty || line.startsWith('#')) continue;

      // This should be a segment URI
      uris.add(_resolveUri(playlistUri, line));
    }

    return uris;
  }

  /// Removes duplicate cues based on start time, end time, and text content.
  ///
  /// HLS WebVTT segments often repeat cues that span segment boundaries.
  /// This ensures each unique cue appears only once.
  List<SubtitleCue> _deduplicateCues(List<SubtitleCue> cues) {
    final seen = <String>{};
    final unique = <SubtitleCue>[];

    for (final cue in cues) {
      // Create a key from start, end, and text to identify duplicates
      final key = '${cue.start.inMilliseconds}|${cue.end.inMilliseconds}|${cue.text}';
      if (!seen.contains(key)) {
        seen.add(key);
        unique.add(cue);
      }
    }

    return unique;
  }

  /// Parses subtitle content (WebVTT or plain text).
  List<SubtitleCue> _parseSubtitleContent(String content) {
    final trimmed = content.trim();

    // Check for WebVTT signature
    if (trimmed.startsWith('WEBVTT')) {
      return const VttParser().parse(content);
    }

    // Try parsing as VTT anyway (some files omit the header)
    try {
      final cues = const VttParser().parse(content);
      if (cues.isNotEmpty) return cues;
    } catch (_) {
      // Not valid VTT
    }

    return [];
  }

  /// Selects the best track based on preferences.
  HlsSubtitleInfo? _selectTrack(List<HlsSubtitleInfo> tracks, List<String>? preferredLanguages) {
    if (tracks.isEmpty) return null;

    // Try to find track by preferred language
    if (preferredLanguages != null && preferredLanguages.isNotEmpty) {
      for (final lang in preferredLanguages) {
        final match = tracks.where((t) => _languageMatches(t.language, lang)).firstOrNull;
        if (match != null) return match;
      }
    }

    // Find default track
    final defaultTrack = tracks.where((t) => t.isDefault).firstOrNull;
    if (defaultTrack != null) return defaultTrack;

    // Fall back to first track
    return tracks.first;
  }

  /// Checks if track language matches the target.
  bool _languageMatches(String? trackLang, String target) {
    if (trackLang == null) return false;

    final trackLower = trackLang.toLowerCase();
    final targetLower = target.toLowerCase();

    // Exact match
    if (trackLower == targetLower) return true;

    // Handle 2-letter vs 3-letter codes
    if (trackLower.startsWith(targetLower) || targetLower.startsWith(trackLower)) {
      return true;
    }

    return false;
  }

  /// Resolves a potentially relative URI against a base URI.
  Uri _resolveUri(Uri baseUri, String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Uri.parse(url);
    }

    if (url.startsWith('/')) {
      return Uri(scheme: baseUri.scheme, host: baseUri.host, port: baseUri.port, path: url);
    }

    // Relative path - resolve against base
    final basePath = baseUri.path.substring(0, baseUri.path.lastIndexOf('/') + 1);
    return Uri(scheme: baseUri.scheme, host: baseUri.host, port: baseUri.port, path: basePath + url);
  }
}
