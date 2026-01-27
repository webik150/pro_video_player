/// Audio-specific track information.
///
/// Contains metadata about the audio sample rate, channel count,
/// and bit depth extracted from a container track.
///
/// Example:
/// ```dart
/// const audioInfo = AudioTrackInfo(
///   sampleRate: 48000,
///   channelCount: 6,
///   channelLayout: '5.1',
/// );
///
/// print(audioInfo.channelDescription);  // '5.1'
/// print(audioInfo.sampleRateKHz);       // 48.0
/// ```
class AudioTrackInfo {
  /// Creates audio track information with required fields.
  const AudioTrackInfo({required this.sampleRate, required this.channelCount, this.bitsPerSample, this.channelLayout});

  /// Creates an [AudioTrackInfo] from a map representation.
  factory AudioTrackInfo.fromMap(Map<String, dynamic> map) => AudioTrackInfo(
    sampleRate: map['sampleRate'] as int? ?? 0,
    channelCount: map['channelCount'] as int? ?? 0,
    bitsPerSample: map['bitsPerSample'] as int?,
    channelLayout: map['channelLayout'] as String?,
  );

  /// Sample rate in Hz (e.g., 44100, 48000, 96000).
  final int sampleRate;

  /// Number of audio channels.
  final int channelCount;

  /// Bits per sample (if applicable).
  ///
  /// Common values: 16, 24, 32
  final int? bitsPerSample;

  /// Channel layout description (e.g., "stereo", "5.1", "7.1").
  ///
  /// When available, provides more detail than just channel count.
  final String? channelLayout;

  /// Sample rate in kHz.
  double get sampleRateKHz => sampleRate / 1000.0;

  /// Human-readable channel description.
  ///
  /// Uses [channelLayout] if available, otherwise infers from [channelCount]:
  /// - 1 channel: "Mono"
  /// - 2 channels: "Stereo"
  /// - 6 channels: "5.1"
  /// - 8 channels: "7.1"
  /// - Other: "N channels"
  String get channelDescription {
    if (channelLayout != null) return channelLayout!;

    return switch (channelCount) {
      1 => 'Mono',
      2 => 'Stereo',
      6 => '5.1',
      8 => '7.1',
      _ => '$channelCount channels',
    };
  }

  /// Converts this audio info to a map representation.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'sampleRate': sampleRate,
    'channelCount': channelCount,
    if (bitsPerSample != null) 'bitsPerSample': bitsPerSample,
    if (channelLayout != null) 'channelLayout': channelLayout,
  };

  /// Creates a copy with the given fields replaced.
  AudioTrackInfo copyWith({int? sampleRate, int? channelCount, int? bitsPerSample, String? channelLayout}) =>
      AudioTrackInfo(
        sampleRate: sampleRate ?? this.sampleRate,
        channelCount: channelCount ?? this.channelCount,
        bitsPerSample: bitsPerSample ?? this.bitsPerSample,
        channelLayout: channelLayout ?? this.channelLayout,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AudioTrackInfo) return false;
    return sampleRate == other.sampleRate &&
        channelCount == other.channelCount &&
        bitsPerSample == other.bitsPerSample &&
        channelLayout == other.channelLayout;
  }

  @override
  int get hashCode => Object.hash(sampleRate, channelCount, bitsPerSample, channelLayout);

  @override
  String toString() =>
      'AudioTrackInfo(sampleRate: $sampleRate, channelCount: $channelCount, '
      'bitsPerSample: $bitsPerSample, channelLayout: $channelLayout)';
}
