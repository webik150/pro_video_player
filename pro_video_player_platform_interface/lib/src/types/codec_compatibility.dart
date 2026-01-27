import 'package:flutter/foundation.dart';

import 'codec_info.dart';

/// Level of codec support on the current platform.
///
/// Used to indicate whether a codec can be decoded by the platform's
/// native video player or hardware decoder.
enum CodecSupportLevel {
  /// Codec is fully supported with hardware or software decoding.
  ///
  /// The platform has confirmed it can play this codec.
  supported,

  /// Codec is probably supported based on platform checks.
  ///
  /// The platform indicates support but hasn't been definitively confirmed.
  /// Corresponds to "maybe" from `canPlayType()` on web.
  probablySupported,

  /// Codec is not supported on this platform.
  ///
  /// The platform has confirmed it cannot play this codec.
  notSupported,

  /// Support status is unknown.
  ///
  /// Unable to determine codec support, possibly due to:
  /// - Platform doesn't provide capability checking
  /// - Codec string format not recognized
  /// - API call failed
  unknown;

  /// Whether this support level indicates the codec is likely playable.
  ///
  /// Returns `true` for [supported] and [probablySupported].
  bool get isPlayable => this == supported || this == probablySupported;
}

/// Result of checking codec compatibility on the current platform.
///
/// Contains detailed information about whether a specific codec can be
/// played on the device, including helpful messages for users and developers.
///
/// Example:
/// ```dart
/// final result = await platform.checkCodecCompatibility(h264Codec);
/// if (!result.isPlayable) {
///   print('Cannot play: ${result.message}');
///   print('Try one of: ${result.alternativeCodecs.join(", ")}');
/// }
/// ```
@immutable
class CodecCompatibility {
  /// Creates codec compatibility information.
  const CodecCompatibility({
    required this.codec,
    required this.supportLevel,
    this.message,
    this.minimumOsVersion,
    this.alternativeCodecs = const [],
  });

  /// Creates a [CodecCompatibility] from a map representation.
  factory CodecCompatibility.fromMap(Map<String, dynamic> map) {
    final codecMap = map['codec'] as Map<String, dynamic>? ?? {};
    final supportLevelStr = map['supportLevel'] as String? ?? 'unknown';
    final altCodecs = map['alternativeCodecs'] as List<dynamic>?;

    return CodecCompatibility(
      codec: CodecInfo.fromMap(codecMap),
      supportLevel: _parseSupportLevel(supportLevelStr),
      message: map['message'] as String?,
      minimumOsVersion: map['minimumOsVersion'] as String?,
      alternativeCodecs: altCodecs?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  /// The codec that was checked.
  final CodecInfo codec;

  /// The level of support for this codec.
  final CodecSupportLevel supportLevel;

  /// Human-readable message about the support status.
  ///
  /// May include:
  /// - Why the codec is not supported
  /// - Requirements for support (e.g., "Requires iOS 17+")
  /// - Hardware decoder availability
  final String? message;

  /// Minimum OS version required for this codec.
  ///
  /// If set, indicates the codec requires a newer OS version.
  /// Format varies by platform (e.g., "17.0" for iOS, "33" for Android API level).
  final String? minimumOsVersion;

  /// Alternative codecs that are supported.
  ///
  /// Suggested alternatives when the requested codec is not supported.
  /// For example, if AV1 is not supported, may suggest ["H.264", "HEVC"].
  final List<String> alternativeCodecs;

  /// Whether this codec is likely playable.
  ///
  /// Returns `true` if [supportLevel] is [CodecSupportLevel.supported]
  /// or [CodecSupportLevel.probablySupported].
  bool get isPlayable => supportLevel.isPlayable;

  /// Converts this compatibility result to a map representation.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'codec': codec.toMap(),
    'supportLevel': supportLevel.name,
    if (message != null) 'message': message,
    if (minimumOsVersion != null) 'minimumOsVersion': minimumOsVersion,
    if (alternativeCodecs.isNotEmpty) 'alternativeCodecs': alternativeCodecs,
  };

  /// Creates a copy with the given fields replaced.
  CodecCompatibility copyWith({
    CodecInfo? codec,
    CodecSupportLevel? supportLevel,
    String? message,
    String? minimumOsVersion,
    List<String>? alternativeCodecs,
  }) => CodecCompatibility(
    codec: codec ?? this.codec,
    supportLevel: supportLevel ?? this.supportLevel,
    message: message ?? this.message,
    minimumOsVersion: minimumOsVersion ?? this.minimumOsVersion,
    alternativeCodecs: alternativeCodecs ?? this.alternativeCodecs,
  );

  static CodecSupportLevel _parseSupportLevel(String value) => switch (value) {
    'supported' => CodecSupportLevel.supported,
    'probablySupported' => CodecSupportLevel.probablySupported,
    'notSupported' => CodecSupportLevel.notSupported,
    _ => CodecSupportLevel.unknown,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CodecCompatibility) return false;
    return codec == other.codec &&
        supportLevel == other.supportLevel &&
        message == other.message &&
        minimumOsVersion == other.minimumOsVersion &&
        listEquals(alternativeCodecs, other.alternativeCodecs);
  }

  @override
  int get hashCode => Object.hash(codec, supportLevel, message, minimumOsVersion, Object.hashAll(alternativeCodecs));

  @override
  String toString() =>
      'CodecCompatibility(codec: $codec, supportLevel: $supportLevel, '
      'message: $message)';
}

/// Result of checking container compatibility on the current platform.
///
/// Aggregates compatibility results for all tracks in a container,
/// providing an overall playability assessment.
///
/// Example:
/// ```dart
/// final metadata = ContainerParser.parse(fileBytes);
/// final result = await platform.checkContainerCompatibility(metadata!);
///
/// if (!result.isPlayable) {
///   print('Cannot play this file: ${result.message}');
///   for (final unsupported in result.unsupportedCodecs) {
///     print('  - ${unsupported.codec.name}: ${unsupported.message}');
///   }
/// }
/// ```
@immutable
class ContainerCompatibility {
  /// Creates container compatibility information.
  const ContainerCompatibility({
    required this.format,
    required this.isPlayable,
    required this.trackCompatibility,
    this.message,
  });

  /// Creates a [ContainerCompatibility] from a map representation.
  factory ContainerCompatibility.fromMap(Map<String, dynamic> map) {
    final trackMaps = map['trackCompatibility'] as List<dynamic>? ?? [];

    return ContainerCompatibility(
      format: map['format'] as String? ?? 'unknown',
      isPlayable: map['isPlayable'] as bool? ?? false,
      trackCompatibility: trackMaps.whereType<Map<String, dynamic>>().map(CodecCompatibility.fromMap).toList(),
      message: map['message'] as String?,
    );
  }

  /// Container format (e.g., "mp4", "mkv", "webm").
  final String format;

  /// Whether all required tracks are playable.
  ///
  /// `true` if the container can be played on this platform.
  /// A container is considered playable if at least one video track
  /// (if present) and one audio track (if present) are supported.
  final bool isPlayable;

  /// Compatibility results for each track in the container.
  final List<CodecCompatibility> trackCompatibility;

  /// Human-readable message about the overall compatibility.
  ///
  /// May include:
  /// - Summary of unsupported codecs
  /// - Suggestions for alternatives
  /// - Platform-specific notes
  final String? message;

  /// Compatibility results for video tracks only.
  List<CodecCompatibility> get videoCompatibility => trackCompatibility.where((c) => c.codec.isVideoCodec).toList();

  /// Compatibility results for audio tracks only.
  List<CodecCompatibility> get audioCompatibility => trackCompatibility.where((c) => c.codec.isAudioCodec).toList();

  /// Tracks that are not playable on this platform.
  List<CodecCompatibility> get unsupportedCodecs => trackCompatibility.where((c) => !c.isPlayable).toList();

  /// Converts this compatibility result to a map representation.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'format': format,
    'isPlayable': isPlayable,
    'trackCompatibility': trackCompatibility.map((c) => c.toMap()).toList(),
    if (message != null) 'message': message,
  };

  /// Creates a copy with the given fields replaced.
  ContainerCompatibility copyWith({
    String? format,
    bool? isPlayable,
    List<CodecCompatibility>? trackCompatibility,
    String? message,
  }) => ContainerCompatibility(
    format: format ?? this.format,
    isPlayable: isPlayable ?? this.isPlayable,
    trackCompatibility: trackCompatibility ?? this.trackCompatibility,
    message: message ?? this.message,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ContainerCompatibility) return false;
    return format == other.format &&
        isPlayable == other.isPlayable &&
        listEquals(trackCompatibility, other.trackCompatibility) &&
        message == other.message;
  }

  @override
  int get hashCode => Object.hash(format, isPlayable, Object.hashAll(trackCompatibility), message);

  @override
  String toString() =>
      'ContainerCompatibility(format: $format, isPlayable: $isPlayable, '
      'tracks: ${trackCompatibility.length}, message: $message)';
}
