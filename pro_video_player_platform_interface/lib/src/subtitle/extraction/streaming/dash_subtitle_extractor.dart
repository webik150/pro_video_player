import 'package:http/http.dart' as http;

import '../../../container/dash_manifest_parser.dart';
import '../../../types/subtitle_cue.dart';
import '../../ttml_parser.dart';
import '../../vtt_parser.dart';

/// Subtitle track information from a DASH stream.
class DashSubtitleInfo {
  /// Creates DASH subtitle info.
  const DashSubtitleInfo({required this.id, this.language, this.label, this.mimeType, this.codecs, this.bandwidth = 0});

  /// Creates from a [DashRepresentation].
  factory DashSubtitleInfo.fromRepresentation(DashRepresentation rep) => DashSubtitleInfo(
    id: rep.id,
    language: rep.language,
    label: rep.label,
    mimeType: rep.mimeType,
    codecs: rep.codecs,
    bandwidth: rep.bandwidth,
  );

  /// Unique identifier for this representation.
  final String id;

  /// Language code (e.g., "en", "es", "fr").
  final String? language;

  /// Human-readable label.
  final String? label;

  /// MIME type (e.g., "text/vtt", "application/ttml+xml").
  final String? mimeType;

  /// Codec string.
  final String? codecs;

  /// Bandwidth in bits per second.
  final int bandwidth;

  /// Whether this is a WebVTT track.
  bool get isWebVtt => mimeType?.contains('vtt') ?? false;

  /// Whether this is a TTML track.
  bool get isTtml => mimeType?.contains('ttml') ?? codecs?.contains('stpp') ?? false;

  @override
  String toString() => 'DashSubtitleInfo($id, lang: $language, mime: $mimeType)';
}

/// Extracts subtitles from DASH (Dynamic Adaptive Streaming over HTTP) sources.
///
/// DASH can use several subtitle formats:
/// - External WebVTT files
/// - External TTML/SMPTE-TT files
/// - Embedded subtitles in fMP4 segments (STPP/WVTT)
///
/// This extractor handles external subtitle files (the most common case).
///
/// ## Example
///
/// ```dart
/// final extractor = DashSubtitleExtractor();
///
/// // List available tracks
/// final tracks = await extractor.listTracks(
///   Uri.parse('https://example.com/manifest.mpd'),
/// );
///
/// // Extract subtitles from a track
/// if (tracks.isNotEmpty) {
///   final cues = await extractor.extractFromTrack(
///     Uri.parse('https://example.com/manifest.mpd'),
///     tracks.first,
///   );
/// }
///
/// // Or extract by language
/// final cues = await extractor.extractByLanguage(
///   Uri.parse('https://example.com/manifest.mpd'),
///   preferredLanguages: ['en', 'eng'],
/// );
/// ```
class DashSubtitleExtractor {
  /// Creates a DASH subtitle extractor.
  ///
  /// Optionally provide an [http.Client] for custom HTTP configuration.
  DashSubtitleExtractor({http.Client? client}) : _client = client;

  final http.Client? _client;

  /// Lists available subtitle tracks from a DASH MPD manifest.
  ///
  /// Returns an empty list if:
  /// - The URL is not accessible
  /// - The manifest is not a valid DASH MPD
  /// - No subtitle representations are defined
  Future<List<DashSubtitleInfo>> listTracks(Uri mpdUrl, {Map<String, String>? headers}) async {
    try {
      final metadata = await DashManifestParser.parseUrl(mpdUrl, client: _client, headers: headers);
      if (metadata == null) return [];

      return metadata.subtitleRepresentations.map(DashSubtitleInfo.fromRepresentation).toList();
    } catch (_) {
      return [];
    }
  }

  /// Extracts subtitles from a specific track.
  ///
  /// The [track] should be obtained from [listTracks].
  ///
  /// For DASH, subtitles can be delivered as:
  /// - Sidecar files (BaseURL in the AdaptationSet/Representation)
  /// - Segmented delivery (SegmentTemplate/SegmentList)
  ///
  /// This method attempts to fetch the subtitle content using the MPD structure.
  Future<List<SubtitleCue>> extractFromTrack(Uri mpdUrl, DashSubtitleInfo track, {Map<String, String>? headers}) async {
    // For DASH, we need to parse the MPD again to find the actual subtitle URLs
    // The DashRepresentation doesn't store the BaseURL/template info

    final httpClient = _client ?? http.Client();
    final shouldCloseClient = _client == null;

    try {
      final response = await httpClient.get(mpdUrl, headers: headers);
      if (response.statusCode != 200) return [];

      return _extractFromMpd(mpdUrl, response.body, track, headers: headers);
    } catch (_) {
      return [];
    } finally {
      if (shouldCloseClient) {
        httpClient.close();
      }
    }
  }

  /// Extracts subtitles based on language preference.
  ///
  /// Parameters:
  /// - [mpdUrl]: URL of the DASH MPD manifest
  /// - [preferredLanguages]: Language codes in order of preference (e.g., ['en', 'eng', 'es'])
  ///
  /// Track selection logic:
  /// 1. If [preferredLanguages] is specified, select first matching track
  /// 2. Otherwise, select the first track
  ///
  /// Returns an empty list if no suitable track is found.
  Future<List<SubtitleCue>> extractByLanguage(
    Uri mpdUrl, {
    List<String>? preferredLanguages,
    Map<String, String>? headers,
  }) async {
    final tracks = await listTracks(mpdUrl, headers: headers);
    if (tracks.isEmpty) return [];

    // Select track based on preferences
    final selectedTrack = _selectTrack(tracks, preferredLanguages);
    if (selectedTrack == null) return [];

    return extractFromTrack(mpdUrl, selectedTrack, headers: headers);
  }

  /// Extracts subtitles by parsing the full MPD content.
  Future<List<SubtitleCue>> _extractFromMpd(
    Uri mpdUrl,
    String mpdContent,
    DashSubtitleInfo track, {
    Map<String, String>? headers,
  }) async {
    // Find the AdaptationSet for this subtitle track
    final subtitleUrl = _findSubtitleUrl(mpdUrl, mpdContent, track);
    if (subtitleUrl == null) return [];

    return _fetchAndParseSubtitles(subtitleUrl, track, headers: headers);
  }

  /// Finds the subtitle URL from the MPD for a specific track.
  Uri? _findSubtitleUrl(Uri mpdUrl, String mpdContent, DashSubtitleInfo track) {
    // Look for AdaptationSet with matching representation ID
    // This is a simplified parser - a full implementation would use XML parsing

    // Pattern 1: BaseURL directly in the representation
    final baseUrlPattern = RegExp(
      '<Representation[^>]*id="[^"]*${RegExp.escape(track.id)}"[^>]*>.*?<BaseURL>([^<]+)</BaseURL>',
      caseSensitive: false,
      dotAll: true,
    );

    var match = baseUrlPattern.firstMatch(mpdContent);
    if (match != null) {
      return _resolveUri(mpdUrl, match.group(1)!);
    }

    // Pattern 2: BaseURL in AdaptationSet with matching lang
    if (track.language != null) {
      final langBaseUrlPattern = RegExp(
        '<AdaptationSet[^>]*contentType="text"[^>]*lang="${track.language}"[^>]*>.*?<BaseURL>([^<]+)</BaseURL>',
        caseSensitive: false,
        dotAll: true,
      );

      match = langBaseUrlPattern.firstMatch(mpdContent);
      if (match != null) {
        return _resolveUri(mpdUrl, match.group(1)!);
      }
    }

    // Pattern 3: SegmentTemplate with $RepresentationID$
    final templatePattern = RegExp(
      '<AdaptationSet[^>]*contentType="text"[^>]*>.*?'
      '<SegmentTemplate[^>]*media="([^"]+)"',
      caseSensitive: false,
      dotAll: true,
    );

    match = templatePattern.firstMatch(mpdContent);
    if (match != null) {
      var template = match.group(1)!;
      // Replace $RepresentationID$ with actual ID
      template = template.replaceAll(r'$RepresentationID$', track.id);
      // For single-segment subtitles, Number might be 1 or not needed
      template = template.replaceAll(RegExp(r'\$Number[^$]*\$'), '1');
      template = template.replaceAll(RegExp(r'\$Time[^$]*\$'), '0');
      return _resolveUri(mpdUrl, template);
    }

    return null;
  }

  /// Fetches and parses subtitle content.
  Future<List<SubtitleCue>> _fetchAndParseSubtitles(
    Uri uri,
    DashSubtitleInfo track, {
    Map<String, String>? headers,
  }) async {
    final httpClient = _client ?? http.Client();
    final shouldCloseClient = _client == null;

    try {
      final response = await httpClient.get(uri, headers: headers);
      if (response.statusCode != 200) return [];

      return _parseSubtitleContent(response.body, track);
    } finally {
      if (shouldCloseClient) {
        httpClient.close();
      }
    }
  }

  /// Parses subtitle content based on track type.
  List<SubtitleCue> _parseSubtitleContent(String content, DashSubtitleInfo track) {
    final trimmed = content.trim();

    // Check for WebVTT
    if (track.isWebVtt || trimmed.startsWith('WEBVTT')) {
      return const VttParser().parse(content);
    }

    // Check for TTML/SMPTE-TT
    if (track.isTtml || trimmed.contains('<tt') || trimmed.contains('<tt:')) {
      return const TtmlParser().parse(content);
    }

    // Try to auto-detect format
    if (trimmed.startsWith('WEBVTT')) {
      return const VttParser().parse(content);
    }

    if (trimmed.contains('<tt') || trimmed.contains('xmlns:ttml') || trimmed.contains('xmlns:tt')) {
      return const TtmlParser().parse(content);
    }

    // Try both parsers
    try {
      final vttCues = const VttParser().parse(content);
      if (vttCues.isNotEmpty) return vttCues;
    } catch (_) {}

    try {
      final ttmlCues = const TtmlParser().parse(content);
      if (ttmlCues.isNotEmpty) return ttmlCues;
    } catch (_) {}

    return [];
  }

  /// Selects the best track based on preferences.
  DashSubtitleInfo? _selectTrack(List<DashSubtitleInfo> tracks, List<String>? preferredLanguages) {
    if (tracks.isEmpty) return null;

    // Try to find track by preferred language
    if (preferredLanguages != null && preferredLanguages.isNotEmpty) {
      for (final lang in preferredLanguages) {
        final match = tracks.where((t) => _languageMatches(t.language, lang)).firstOrNull;
        if (match != null) return match;
      }
    }

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
