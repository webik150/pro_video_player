import 'dart:typed_data';

import '../types/audio_track_info.dart';
import '../types/codec_info.dart';
import '../types/container_metadata.dart';
import '../types/container_track.dart';
import '../types/container_track_type.dart';

/// FLV video codec constants.
///
/// These are the codecId values in the video tag header (bits 0-3).
class FlvVideoCodec {
  FlvVideoCodec._();

  /// Sorenson H.263 (Flash 6+)
  static const int sorensonH263 = 2;

  /// Screen Video (Flash 7+)
  static const int screenVideo = 3;

  /// VP6 (Flash 8+)
  static const int vp6 = 4;

  /// VP6 with alpha channel (Flash 8+)
  static const int vp6Alpha = 5;

  /// Screen Video 2 (Flash 8+)
  static const int screenVideo2 = 6;

  /// H.264/AVC (Flash 9+)
  static const int avc = 7;

  /// H.265/HEVC (enhanced FLV)
  static const int hevc = 12;

  /// AV1 (enhanced FLV)
  static const int av1 = 13;
}

/// FLV audio codec constants.
///
/// These are the soundFormat values in the audio tag header (bits 4-7).
class FlvAudioCodec {
  FlvAudioCodec._();

  /// Linear PCM, platform endian
  static const int pcmBe = 0;

  /// ADPCM
  static const int adpcm = 1;

  /// MP3
  static const int mp3 = 2;

  /// Linear PCM, little endian
  static const int pcmLe = 3;

  /// Nellymoser 16kHz mono
  static const int nellymoser16kHz = 4;

  /// Nellymoser 8kHz mono
  static const int nellymoser8kHz = 5;

  /// Nellymoser
  static const int nellymoser = 6;

  /// G.711 A-law
  static const int g711Alaw = 7;

  /// G.711 mu-law
  static const int g711Mulaw = 8;

  /// Reserved
  static const int reserved = 9;

  /// AAC
  static const int aac = 10;

  /// Speex
  static const int speex = 11;

  /// MP3 8kHz
  static const int mp38kHz = 14;

  /// Device-specific sound
  static const int deviceSpecific = 15;
}

/// FLV tag type constants.
class FlvTagType {
  FlvTagType._();

  /// Audio tag
  static const int audio = 8;

  /// Video tag
  static const int video = 9;

  /// Script data tag (metadata)
  static const int script = 18;
}

/// Parser for FLV (Flash Video) container files.
///
/// Extracts metadata from FLV files including:
/// - Format detection
/// - Track information from tag headers
/// - Codec identification
/// - Audio properties (channels, sample rate)
///
/// Example:
/// ```dart
/// final metadata = FlvParser.parse(bytes);
/// if (metadata != null) {
///   print('Format: ${metadata.format}');
///   for (final track in metadata.tracks) {
///     print('Track ${track.id}: ${track.codec.name}');
///   }
/// }
/// ```
class FlvParser {
  FlvParser._();

  /// FLV header size (always 9 bytes).
  static const int headerSize = 9;

  /// FLV signature bytes ("FLV").
  static const List<int> signature = [0x46, 0x4C, 0x56];

  /// Checks if the data is a valid FLV file.
  ///
  /// Validates signature, version, and header size.
  static bool isValidFlv(Uint8List data) {
    if (data.length < headerSize) return false;

    // Check signature "FLV"
    if (data[0] != signature[0] || data[1] != signature[1] || data[2] != signature[2]) {
      return false;
    }

    // Check version (should be 1)
    if (data[3] != 1) return false;

    return true;
  }

  /// Detects if data is an FLV file and returns format string.
  static String? detectFormat(Uint8List data) => isValidFlv(data) ? 'flv' : null;

  /// Parses FLV container metadata from bytes.
  ///
  /// Returns null if the data is not a valid FLV file.
  static ContainerMetadata? parse(Uint8List data) {
    if (!isValidFlv(data)) return null;

    // Read header flags
    final flags = data[4];
    final hasAudio = (flags & 0x04) != 0;
    final hasVideo = (flags & 0x01) != 0;

    // Get header size (should be 9)
    final dataOffset = _readUint32(data, 5);

    final tracks = <ContainerTrack>[];
    var foundVideo = false;
    var foundAudio = false;

    // Parse tags to find codec info
    var offset = dataOffset + 4; // Skip first PreviousTagSize

    while (offset + 11 < data.length) {
      // Stop if we've found all expected tracks
      if ((!hasVideo || foundVideo) && (!hasAudio || foundAudio)) {
        break;
      }

      // Read tag header
      final tagType = data[offset];
      final dataSize = _readUint24(data, offset + 1);
      final tagDataOffset = offset + 11;

      // Validate tag data is within bounds
      if (tagDataOffset + dataSize > data.length) break;

      switch (tagType) {
        case FlvTagType.video:
          if (!foundVideo && dataSize > 0) {
            final videoFlags = data[tagDataOffset];
            final codecId = videoFlags & 0x0F;
            final codec = mapVideoCodecToInfo(codecId);

            tracks.add(ContainerTrack(id: tracks.length + 1, type: ContainerTrackType.video, codec: codec));
            foundVideo = true;
          }

        case FlvTagType.audio:
          if (!foundAudio && dataSize > 0) {
            final audioFlags = data[tagDataOffset];
            final codecId = (audioFlags >> 4) & 0x0F;
            final sampleRateIndex = (audioFlags >> 2) & 0x03;
            final stereo = (audioFlags & 0x01) != 0;

            final codec = mapAudioCodecToInfo(codecId);
            final sampleRate = _sampleRates[sampleRateIndex];
            final channelCount = stereo ? 2 : 1;

            tracks.add(
              ContainerTrack(
                id: tracks.length + 1,
                type: ContainerTrackType.audio,
                codec: codec,
                audioInfo: AudioTrackInfo(
                  sampleRate: sampleRate,
                  channelCount: channelCount,
                  channelLayout: stereo ? 'stereo' : 'mono',
                ),
              ),
            );
            foundAudio = true;
          }

        case FlvTagType.script:
          // Skip script tags (metadata)
          break;
      }

      // Move to next tag (11 byte header + data + 4 byte PreviousTagSize)
      offset += 11 + dataSize + 4;
    }

    return ContainerMetadata(
      format: 'flv',
      duration: Duration.zero, // Would need to parse script tag for duration
      tracks: tracks,
    );
  }

  /// Maps video codec ID to codec info.
  static CodecInfo mapVideoCodecToInfo(int codecId) {
    final (name, fourcc) = switch (codecId) {
      FlvVideoCodec.sorensonH263 => ('Sorenson H.263', 'flv1'),
      FlvVideoCodec.screenVideo => ('Screen Video', 'fsv1'),
      FlvVideoCodec.vp6 => ('VP6', 'vp6f'),
      FlvVideoCodec.vp6Alpha => ('VP6 Alpha', 'vp6a'),
      FlvVideoCodec.screenVideo2 => ('Screen Video 2', 'fsv2'),
      FlvVideoCodec.avc => ('H.264', 'avc1'),
      FlvVideoCodec.hevc => ('HEVC', 'hvc1'),
      FlvVideoCodec.av1 => ('AV1', 'av01'),
      _ => ('Unknown', 'unkn'),
    };

    return CodecInfo(fourcc: fourcc, name: name, codecString: 'flv-video-$codecId');
  }

  /// Maps audio codec ID to codec info.
  static CodecInfo mapAudioCodecToInfo(int codecId) {
    final (name, fourcc) = switch (codecId) {
      FlvAudioCodec.pcmBe => ('PCM BE', 'twos'),
      FlvAudioCodec.adpcm => ('ADPCM', 'adpm'),
      FlvAudioCodec.mp3 || FlvAudioCodec.mp38kHz => ('MP3', '.mp3'),
      FlvAudioCodec.pcmLe => ('PCM LE', 'sowt'),
      FlvAudioCodec.nellymoser16kHz => ('Nellymoser 16kHz', 'nmos'),
      FlvAudioCodec.nellymoser8kHz => ('Nellymoser 8kHz', 'nmos'),
      FlvAudioCodec.nellymoser => ('Nellymoser', 'nmos'),
      FlvAudioCodec.g711Alaw => ('G.711 A-law', 'alaw'),
      FlvAudioCodec.g711Mulaw => ('G.711 mu-law', 'ulaw'),
      FlvAudioCodec.aac => ('AAC', 'mp4a'),
      FlvAudioCodec.speex => ('Speex', 'spex'),
      FlvAudioCodec.deviceSpecific => ('Device Audio', 'deva'),
      _ => ('Unknown', 'unkn'),
    };

    // Special case for mp3 8kHz to have distinct name
    if (codecId == FlvAudioCodec.mp38kHz) {
      return CodecInfo(fourcc: fourcc, name: 'MP3 8kHz', codecString: 'flv-audio-$codecId');
    }

    return CodecInfo(fourcc: fourcc, name: name, codecString: 'flv-audio-$codecId');
  }

  /// Sample rate lookup table (indexed by soundRate field).
  static const _sampleRates = [5512, 11025, 22050, 44100];

  /// Reads a 24-bit big-endian unsigned integer.
  static int _readUint24(Uint8List data, int offset) =>
      (data[offset] << 16) | (data[offset + 1] << 8) | data[offset + 2];

  /// Reads a 32-bit big-endian unsigned integer.
  static int _readUint32(Uint8List data, int offset) =>
      (data[offset] << 24) | (data[offset + 1] << 16) | (data[offset + 2] << 8) | data[offset + 3];
}
