import 'package:http/http.dart' as http;

/// Metadata extracted from a DASH MPD manifest.
///
/// Contains information about available video and audio representations,
/// subtitle tracks, and stream properties without downloading any segments.
///
/// Example:
/// ```dart
/// final metadata = await DashManifestParser.parse(mpdUrl);
/// if (metadata != null) {
///   print('Video representations: ${metadata.videoRepresentations.length}');
///   for (final rep in metadata.videoRepresentations) {
///     print('  ${rep.width}x${rep.height} @ ${rep.bandwidth ~/ 1000} kbps');
///   }
/// }
/// ```
class DashManifestMetadata {
  /// Creates DASH manifest metadata.
  const DashManifestMetadata({
    required this.videoRepresentations,
    this.audioRepresentations = const [],
    this.subtitleRepresentations = const [],
    this.duration,
    this.minBufferTime,
    this.isLive = false,
    this.profiles = const [],
  });

  /// Video representations (quality levels) available in the stream.
  final List<DashRepresentation> videoRepresentations;

  /// Audio representations available in the stream.
  final List<DashRepresentation> audioRepresentations;

  /// Subtitle/text representations available in the stream.
  final List<DashRepresentation> subtitleRepresentations;

  /// Total duration of the content (for VOD).
  final Duration? duration;

  /// Minimum buffer time recommended.
  final Duration? minBufferTime;

  /// Whether this is a live stream (dynamic MPD).
  final bool isLive;

  /// DASH profiles used by this manifest.
  final List<String> profiles;

  /// Returns the highest quality video by bandwidth.
  DashRepresentation? get highestQualityVideo =>
      videoRepresentations.isEmpty ? null : videoRepresentations.reduce((a, b) => a.bandwidth > b.bandwidth ? a : b);

  /// Returns the lowest quality video by bandwidth.
  DashRepresentation? get lowestQualityVideo =>
      videoRepresentations.isEmpty ? null : videoRepresentations.reduce((a, b) => a.bandwidth < b.bandwidth ? a : b);

  /// Returns video representations sorted by bandwidth (ascending).
  List<DashRepresentation> get videoByBandwidth =>
      [...videoRepresentations]..sort((a, b) => a.bandwidth.compareTo(b.bandwidth));

  @override
  String toString() =>
      'DashManifestMetadata(video: ${videoRepresentations.length}, audio: ${audioRepresentations.length}, subtitles: ${subtitleRepresentations.length}, live: $isLive)';
}

/// A representation (quality level) in a DASH stream.
class DashRepresentation {
  /// Creates a DASH representation.
  const DashRepresentation({
    required this.id,
    required this.bandwidth,
    this.width,
    this.height,
    this.frameRate,
    this.codecs,
    this.mimeType,
    this.contentType,
    this.language,
    this.label,
    this.audioSamplingRate,
    this.audioChannels,
  });

  /// Unique identifier for this representation.
  final String id;

  /// Bandwidth in bits per second.
  final int bandwidth;

  /// Video width in pixels.
  final int? width;

  /// Video height in pixels.
  final int? height;

  /// Frame rate (e.g., "30", "29.97", "30/1").
  final String? frameRate;

  /// Codec string (e.g., "avc1.64001f", "mp4a.40.2").
  final String? codecs;

  /// MIME type (e.g., "video/mp4", "audio/mp4").
  final String? mimeType;

  /// Content type (video, audio, text).
  final String? contentType;

  /// Language code for audio/subtitle tracks.
  final String? language;

  /// Human-readable label.
  final String? label;

  /// Audio sampling rate in Hz.
  final int? audioSamplingRate;

  /// Number of audio channels.
  final int? audioChannels;

  /// Returns parsed frame rate as double.
  double? get frameRateValue {
    if (frameRate == null) return null;
    if (frameRate!.contains('/')) {
      final parts = frameRate!.split('/');
      if (parts.length == 2) {
        final num = double.tryParse(parts[0]);
        final den = double.tryParse(parts[1]);
        if (num != null && den != null && den != 0) {
          return num / den;
        }
      }
    }
    return double.tryParse(frameRate!);
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

  /// Whether this is a video representation.
  bool get isVideo => contentType == 'video' || (mimeType?.startsWith('video/') ?? false);

  /// Whether this is an audio representation.
  bool get isAudio => contentType == 'audio' || (mimeType?.startsWith('audio/') ?? false);

  /// Whether this is a subtitle/text representation.
  bool get isSubtitle =>
      contentType == 'text' ||
      (mimeType?.startsWith('text/') ?? false) ||
      (mimeType?.startsWith('application/ttml') ?? false);

  @override
  String toString() {
    if (isVideo) {
      return 'DashRepresentation($id, $qualityLabel, ${bandwidth ~/ 1000} kbps, codecs: $codecs)';
    } else if (isAudio) {
      return 'DashRepresentation($id, audio, ${bandwidth ~/ 1000} kbps, lang: $language)';
    } else {
      return 'DashRepresentation($id, $contentType, lang: $language)';
    }
  }
}

/// Parser for DASH (Dynamic Adaptive Streaming over HTTP) MPD manifests.
///
/// Extracts metadata from DASH manifests including:
/// - Video representations with bandwidth, resolution, codecs
/// - Audio representations with language and codec info
/// - Subtitle/text representations
///
/// Example:
/// ```dart
/// // From URL
/// final metadata = await DashManifestParser.parseUrl(
///   Uri.parse('https://example.com/manifest.mpd'),
/// );
///
/// // From content
/// final metadata = DashManifestParser.parse(mpdContent);
///
/// // List available qualities
/// for (final rep in metadata?.videoRepresentations ?? []) {
///   print('${rep.qualityLabel}: ${rep.codecs}');
/// }
/// ```
class DashManifestParser {
  DashManifestParser._();

  /// Parses DASH manifest metadata from a URL.
  ///
  /// Fetches the manifest and parses it. Returns null if the URL
  /// is not accessible or the content is not a valid DASH manifest.
  static Future<DashManifestMetadata?> parseUrl(Uri url, {http.Client? client, Map<String, String>? headers}) async {
    final httpClient = client ?? http.Client();
    final shouldCloseClient = client == null;

    try {
      final response = await httpClient.get(url, headers: headers);
      if (response.statusCode != 200) return null;

      return parse(response.body);
    } finally {
      if (shouldCloseClient) {
        httpClient.close();
      }
    }
  }

  /// Parses DASH manifest metadata from MPD content string.
  ///
  /// Returns null if the content is not a valid DASH manifest.
  static DashManifestMetadata? parse(String content) {
    if (!content.contains('<MPD') && !content.contains('<mpd')) return null;

    final videoReps = <DashRepresentation>[];
    final audioReps = <DashRepresentation>[];
    final subtitleReps = <DashRepresentation>[];
    final profiles = <String>[];

    // Extract MPD attributes
    final mpdMatch = RegExp('<MPD[^>]*>', caseSensitive: false).firstMatch(content);
    Duration? duration;
    Duration? minBufferTime;
    var isLive = false;

    if (mpdMatch != null) {
      final mpdTag = mpdMatch.group(0)!;

      // Check if live (type="dynamic")
      isLive = mpdTag.contains('type="dynamic"') || mpdTag.contains("type='dynamic'");

      // Parse duration (mediaPresentationDuration="PT1H30M45S")
      final durationMatch = RegExp('mediaPresentationDuration="([^"]*)"').firstMatch(mpdTag);
      if (durationMatch != null) {
        duration = _parseIso8601Duration(durationMatch.group(1)!);
      }

      // Parse minBufferTime
      final bufferMatch = RegExp('minBufferTime="([^"]*)"').firstMatch(mpdTag);
      if (bufferMatch != null) {
        minBufferTime = _parseIso8601Duration(bufferMatch.group(1)!);
      }

      // Parse profiles
      final profilesMatch = RegExp('profiles="([^"]*)"').firstMatch(mpdTag);
      if (profilesMatch != null) {
        profiles.addAll(profilesMatch.group(1)!.split(',').map((p) => p.trim()));
      }
    }

    // Parse AdaptationSets
    final adaptationSetPattern = RegExp(
      '<AdaptationSet[^>]*>(.*?)</AdaptationSet>',
      caseSensitive: false,
      dotAll: true,
    );

    for (final asMatch in adaptationSetPattern.allMatches(content)) {
      final asContent = asMatch.group(0)!;
      final asInner = asMatch.group(1)!;

      // Determine content type from AdaptationSet attributes
      var contentType = _extractAttribute(asContent, 'contentType');
      final mimeType = _extractAttribute(asContent, 'mimeType');
      final asCodecs = _extractAttribute(asContent, 'codecs');
      final asLang = _extractAttribute(asContent, 'lang');
      final asLabel = _extractAttribute(asContent, 'label');
      final asWidth = int.tryParse(_extractAttribute(asContent, 'width') ?? '');
      final asHeight = int.tryParse(_extractAttribute(asContent, 'height') ?? '');
      final asFrameRate = _extractAttribute(asContent, 'frameRate');

      // Infer content type from mimeType if not specified
      if (contentType == null && mimeType != null) {
        if (mimeType.startsWith('video/')) {
          contentType = 'video';
        } else if (mimeType.startsWith('audio/')) {
          contentType = 'audio';
        } else if (mimeType.startsWith('text/') || mimeType.contains('ttml')) {
          contentType = 'text';
        }
      }

      // Parse Representations within this AdaptationSet
      // Match both self-closing <Representation .../> and <Representation ...>...</Representation>
      final repPattern = RegExp(r'<Representation\s+([^>]*)(?:/>|>)', caseSensitive: false);

      for (final repMatch in repPattern.allMatches(asInner)) {
        // Include the Representation tag name for attribute extraction
        final repTag = '<Representation ${repMatch.group(1)!}>';

        final id = _extractAttribute(repTag, 'id') ?? '';
        final bandwidth = int.tryParse(_extractAttribute(repTag, 'bandwidth') ?? '') ?? 0;
        final width = int.tryParse(_extractAttribute(repTag, 'width') ?? '') ?? asWidth;
        final height = int.tryParse(_extractAttribute(repTag, 'height') ?? '') ?? asHeight;
        final frameRate = _extractAttribute(repTag, 'frameRate') ?? asFrameRate;
        final codecs = _extractAttribute(repTag, 'codecs') ?? asCodecs;
        final repMimeType = _extractAttribute(repTag, 'mimeType') ?? mimeType;
        final audioSamplingRate = int.tryParse(_extractAttribute(repTag, 'audioSamplingRate') ?? '');

        // Parse AudioChannelConfiguration for channel count
        int? audioChannels;
        final channelConfigMatch = RegExp(
          r'<AudioChannelConfiguration[^>]*value="(\d+)"',
          caseSensitive: false,
        ).firstMatch(asInner);
        if (channelConfigMatch != null) {
          audioChannels = int.tryParse(channelConfigMatch.group(1)!);
        }

        final rep = DashRepresentation(
          id: id,
          bandwidth: bandwidth,
          width: width,
          height: height,
          frameRate: frameRate,
          codecs: codecs,
          mimeType: repMimeType,
          contentType: contentType,
          language: asLang,
          label: asLabel,
          audioSamplingRate: audioSamplingRate,
          audioChannels: audioChannels,
        );

        // Categorize by content type
        if (contentType == 'video' || rep.isVideo) {
          videoReps.add(rep);
        } else if (contentType == 'audio' || rep.isAudio) {
          audioReps.add(rep);
        } else if (contentType == 'text' || rep.isSubtitle) {
          subtitleReps.add(rep);
        }
      }
    }

    return DashManifestMetadata(
      videoRepresentations: videoReps,
      audioRepresentations: audioReps,
      subtitleRepresentations: subtitleReps,
      duration: duration,
      minBufferTime: minBufferTime,
      isLive: isLive,
      profiles: profiles,
    );
  }

  /// Extracts an attribute value from an XML tag.
  static String? _extractAttribute(String tag, String name) {
    // Use word boundary \b to avoid matching 'width' inside 'bandwidth'
    final match = RegExp('\\b$name="([^"]*)"', caseSensitive: false).firstMatch(tag);
    return match?.group(1);
  }

  /// Parses ISO 8601 duration (e.g., "PT1H30M45.5S") to Duration.
  static Duration? _parseIso8601Duration(String iso) {
    // Format: PT[nH][nM][nS] or PT[n.n]S
    final match = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d+)?)S)?').firstMatch(iso);
    if (match == null) return null;

    final hours = int.tryParse(match.group(1) ?? '') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
    final secondsStr = match.group(3);
    final seconds = secondsStr != null ? double.tryParse(secondsStr) ?? 0.0 : 0.0;

    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds.floor(),
      milliseconds: ((seconds - seconds.floor()) * 1000).round(),
    );
  }
}
