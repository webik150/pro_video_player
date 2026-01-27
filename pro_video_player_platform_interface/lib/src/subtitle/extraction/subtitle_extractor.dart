import 'dart:io';

import '../../types/embedded_subtitle_track.dart';
import '../../types/subtitle_cue.dart';
import 'embedded_subtitle_reader.dart';
import 'subtitle_sample_decoder.dart';

/// Unified API for extracting embedded subtitles from container files.
///
/// Provides methods to:
/// - List available subtitle tracks in a file
/// - Extract subtitles from a specific track
/// - Auto-select the best track based on language preferences
///
/// Supports multiple container formats:
/// - **MP4/MOV**: TX3G (timed text), STPP (TTML), WVTT (WebVTT)
/// - **MKV/WebM**: S_TEXT/UTF8 (SRT), S_TEXT/ASS, S_TEXT/SSA, S_TEXT/WEBVTT
///
/// Styling information is preserved when available - see [SubtitleCue.styledSpans].
///
/// ## Example
///
/// ```dart
/// final extractor = SubtitleExtractor();
///
/// // List available tracks
/// final tracks = await extractor.listTracks('/path/to/video.mp4');
/// for (final track in tracks) {
///   print('Track ${track.trackId}: ${track.codecName} (${track.language})');
/// }
///
/// // Extract subtitles from first track
/// if (tracks.isNotEmpty) {
///   final cues = await extractor.extractFromFile(
///     '/path/to/video.mp4',
///     trackId: tracks.first.trackId,
///   );
///   for (final cue in cues) {
///     print('${cue.start} - ${cue.end}: ${cue.text}');
///   }
/// }
///
/// // Or auto-select by language
/// final englishCues = await extractor.extractFromFile(
///   '/path/to/video.mp4',
///   preferredLanguages: ['eng', 'en'],
/// );
/// ```
class SubtitleExtractor {
  /// Creates a subtitle extractor.
  const SubtitleExtractor();

  /// Lists all embedded subtitle tracks in a container file.
  ///
  /// Returns an empty list if:
  /// - The file doesn't exist
  /// - The file format isn't supported
  /// - No subtitle tracks are found
  Future<List<EmbeddedSubtitleTrack>> listTracks(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return [];

    return listEmbeddedSubtitleTracks(filePath);
  }

  /// Extracts subtitles from a file.
  ///
  /// Parameters:
  /// - [filePath]: Path to the container file
  /// - [trackId]: Specific track ID to extract (takes precedence)
  /// - [preferredLanguages]: Language codes in order of preference (e.g., ['eng', 'en', 'spa'])
  ///
  /// Track selection logic:
  /// 1. If [trackId] is specified, extract from that track
  /// 2. If [preferredLanguages] is specified, select first matching track
  /// 3. Otherwise, select the first subtitle track marked as default
  /// 4. If no default, select the first subtitle track
  ///
  /// Returns an empty list if no suitable track is found.
  ///
  /// Example:
  /// ```dart
  /// // Extract from specific track
  /// final cues = await extractor.extractFromFile('video.mp4', trackId: 3);
  ///
  /// // Auto-select based on language
  /// final cues = await extractor.extractFromFile(
  ///   'video.mp4',
  ///   preferredLanguages: ['eng', 'en'],
  /// );
  /// ```
  Future<List<SubtitleCue>> extractFromFile(String filePath, {int? trackId, List<String>? preferredLanguages}) async {
    final file = File(filePath);
    if (!file.existsSync()) return [];

    // If trackId specified, extract directly
    if (trackId != null) {
      return _extractFromTrack(filePath, trackId);
    }

    // List available tracks
    final tracks = await listTracks(filePath);
    if (tracks.isEmpty) return [];

    // Filter to only supported codecs
    final supportedTracks = tracks.where((t) => SubtitleSampleDecoder.isSupported(t.codec)).toList();
    if (supportedTracks.isEmpty) return [];

    // Select track based on preferences
    final selectedTrack = _selectTrack(supportedTracks, preferredLanguages);
    if (selectedTrack == null) return [];

    return _extractFromTrack(filePath, selectedTrack.trackId);
  }

  /// Selects the best track based on preferences.
  EmbeddedSubtitleTrack? _selectTrack(List<EmbeddedSubtitleTrack> tracks, List<String>? preferredLanguages) {
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
    // e.g., 'eng' matches 'en', 'spa' matches 'es'
    if (trackLower.startsWith(targetLower) || targetLower.startsWith(trackLower)) {
      return true;
    }

    // Common language code mappings
    const languageMappings = {
      'eng': ['en', 'english'],
      'spa': ['es', 'spanish', 'español'],
      'fra': ['fr', 'french', 'français'],
      'deu': ['de', 'german', 'deutsch'],
      'ita': ['it', 'italian', 'italiano'],
      'por': ['pt', 'portuguese', 'português'],
      'rus': ['ru', 'russian', 'русский'],
      'jpn': ['ja', 'japanese', '日本語'],
      'kor': ['ko', 'korean', '한국어'],
      'zho': ['zh', 'chinese', '中文'],
      'ara': ['ar', 'arabic', 'العربية'],
      'hin': ['hi', 'hindi', 'हिन्दी'],
      'nld': ['nl', 'dutch', 'nederlands'],
      'pol': ['pl', 'polish', 'polski'],
      'tur': ['tr', 'turkish', 'türkçe'],
      'vie': ['vi', 'vietnamese', 'tiếng việt'],
      'tha': ['th', 'thai', 'ไทย'],
      'swe': ['sv', 'swedish', 'svenska'],
      'nor': ['no', 'norwegian', 'norsk'],
      'dan': ['da', 'danish', 'dansk'],
      'fin': ['fi', 'finnish', 'suomi'],
      'ces': ['cs', 'czech', 'čeština'],
      'hun': ['hu', 'hungarian', 'magyar'],
      'ron': ['ro', 'romanian', 'română'],
      'ell': ['el', 'greek', 'ελληνικά'],
      'heb': ['he', 'hebrew', 'עברית'],
      'ind': ['id', 'indonesian', 'bahasa indonesia'],
      'msa': ['ms', 'malay', 'bahasa melayu'],
      'ukr': ['uk', 'ukrainian', 'українська'],
      'bul': ['bg', 'bulgarian', 'български'],
      'hrv': ['hr', 'croatian', 'hrvatski'],
      'slk': ['sk', 'slovak', 'slovenčina'],
      'slv': ['sl', 'slovenian', 'slovenščina'],
      'srp': ['sr', 'serbian', 'српски'],
      'cat': ['ca', 'catalan', 'català'],
      'eus': ['eu', 'basque', 'euskara'],
      'glg': ['gl', 'galician', 'galego'],
      'lit': ['lt', 'lithuanian', 'lietuvių'],
      'lav': ['lv', 'latvian', 'latviešu'],
      'est': ['et', 'estonian', 'eesti'],
    };

    // Check if track language maps to target
    for (final entry in languageMappings.entries) {
      final codes = [entry.key, ...entry.value];
      if (codes.contains(trackLower) && codes.contains(targetLower)) {
        return true;
      }
    }

    return false;
  }

  /// Extracts subtitles from a specific track.
  Future<List<SubtitleCue>> _extractFromTrack(String filePath, int trackId) async {
    final reader = await EmbeddedSubtitleReader.open(filePath, trackId: trackId);
    if (reader == null) return [];

    try {
      return await reader.extractAll();
    } finally {
      await reader.close();
    }
  }

  /// Gets information about a specific track.
  ///
  /// Returns null if the track doesn't exist or isn't a subtitle track.
  Future<EmbeddedSubtitleTrack?> getTrackInfo(String filePath, int trackId) async {
    final tracks = await listTracks(filePath);
    return tracks.where((t) => t.trackId == trackId).firstOrNull;
  }

  /// Checks if a file has any extractable subtitle tracks.
  ///
  /// Only counts tracks with supported codecs.
  Future<bool> hasSubtitles(String filePath) async {
    final tracks = await listTracks(filePath);
    return tracks.any((t) => SubtitleSampleDecoder.isSupported(t.codec));
  }

  /// Returns the list of supported subtitle codec identifiers.
  ///
  /// These are the codecs that can be extracted and decoded.
  static List<String> get supportedCodecs => SubtitleSampleDecoder.supportedCodecs;

  /// Checks if a codec is supported for extraction.
  static bool isCodecSupported(String codec) => SubtitleSampleDecoder.isSupported(codec);
}
