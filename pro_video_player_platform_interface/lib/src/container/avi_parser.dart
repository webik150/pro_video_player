import 'dart:typed_data';

import '../types/audio_track_info.dart';
import '../types/codec_info.dart';
import '../types/container_metadata.dart';
import '../types/container_track.dart';
import '../types/container_track_type.dart';
import '../types/video_track_info.dart';

/// AVI stream type fourcc values.
class AviStreamType {
  AviStreamType._();

  /// Video stream
  static const String video = 'vids';

  /// Audio stream
  static const String audio = 'auds';

  /// Subtitle/text stream
  static const String subtitle = 'txts';

  /// MIDI stream
  static const String midi = 'mids';
}

/// Common audio format tags used in AVI files.
class AviAudioFormat {
  AviAudioFormat._();

  /// PCM (uncompressed)
  static const int pcm = 0x0001;

  /// ADPCM
  static const int adpcm = 0x0002;

  /// IEEE float
  static const int ieeeFloat = 0x0003;

  /// A-law
  static const int alaw = 0x0006;

  /// mu-law
  static const int mulaw = 0x0007;

  /// IMA ADPCM
  static const int imaAdpcm = 0x0011;

  /// MP2
  static const int mp2 = 0x0050;

  /// MP3
  static const int mp3 = 0x0055;

  /// AAC
  static const int aac = 0x00FF;

  /// WMA v1
  static const int wma1 = 0x0160;

  /// WMA v2
  static const int wma2 = 0x0161;

  /// WMA Pro
  static const int wmaPro = 0x0162;

  /// AC-3
  static const int ac3 = 0x2000;

  /// DTS
  static const int dts = 0x2001;

  /// Vorbis
  static const int vorbis = 0x566F;

  /// FLAC
  static const int flac = 0xF1AC;

  /// Extensible format
  static const int extensible = 0xFFFE;
}

/// Parser for AVI (Audio Video Interleave) container files.
///
/// Extracts metadata from AVI files including:
/// - Format detection via RIFF/AVI signature
/// - Track information from stream headers (strh/strf)
/// - Video codec detection via fourcc
/// - Audio codec detection via format tag
/// - Video dimensions and frame rate
/// - Audio sample rate and channels
///
/// Example:
/// ```dart
/// final metadata = AviParser.parse(bytes);
/// if (metadata != null) {
///   print('Format: ${metadata.format}');
///   for (final track in metadata.tracks) {
///     print('Track ${track.id}: ${track.codec.name}');
///   }
/// }
/// ```
class AviParser {
  AviParser._();

  /// RIFF signature bytes.
  static const List<int> riffSignature = [0x52, 0x49, 0x46, 0x46]; // "RIFF"

  /// AVI form type bytes.
  static const List<int> aviType = [0x41, 0x56, 0x49, 0x20]; // "AVI "

  /// Checks if the data is a valid AVI file.
  ///
  /// Validates RIFF signature and AVI form type.
  static bool isValidAvi(Uint8List data) {
    if (data.length < 12) return false;

    // Check RIFF signature
    if (data[0] != riffSignature[0] ||
        data[1] != riffSignature[1] ||
        data[2] != riffSignature[2] ||
        data[3] != riffSignature[3]) {
      return false;
    }

    // Check AVI form type (at offset 8)
    if (data[8] != aviType[0] || data[9] != aviType[1] || data[10] != aviType[2] || data[11] != aviType[3]) {
      return false;
    }

    return true;
  }

  /// Detects if data is an AVI file and returns format string.
  static String? detectFormat(Uint8List data) => isValidAvi(data) ? 'avi' : null;

  /// Parses AVI container metadata from bytes.
  ///
  /// Returns null if the data is not a valid AVI file.
  static ContainerMetadata? parse(Uint8List data) {
    if (!isValidAvi(data)) return null;

    final tracks = <ContainerTrack>[];
    var offset = 12; // Skip RIFF header + AVI type

    // Parse chunks
    while (offset + 8 <= data.length) {
      final chunkId = _readFourcc(data, offset);
      final chunkSize = _readUint32Le(data, offset + 4);

      if (chunkId == 'LIST') {
        final listType = _readFourcc(data, offset + 8);

        if (listType == 'hdrl') {
          // Parse header list
          _parseHdrlList(data, offset + 12, chunkSize - 4, tracks);
        }
      }

      // Move to next chunk (size + 8 for header, pad to word boundary)
      offset += 8 + chunkSize + (chunkSize & 1);

      // Safety check for malformed files
      if (chunkSize == 0 || offset > data.length) break;
    }

    return ContainerMetadata(
      format: 'avi',
      duration: Duration.zero, // Would need to parse avih for duration
      tracks: tracks,
    );
  }

  /// Parses the hdrl (header list) to extract stream information.
  static void _parseHdrlList(Uint8List data, int startOffset, int size, List<ContainerTrack> tracks) {
    final endOffset = startOffset + size;
    var offset = startOffset;

    while (offset + 8 <= endOffset && offset + 8 <= data.length) {
      final chunkId = _readFourcc(data, offset);
      final chunkSize = _readUint32Le(data, offset + 4);

      if (chunkId == 'LIST') {
        final listType = _readFourcc(data, offset + 8);

        if (listType == 'strl') {
          // Parse stream list
          final track = _parseStrlList(data, offset + 12, chunkSize - 4, tracks.length + 1);
          if (track != null) {
            tracks.add(track);
          }
        }
      }

      offset += 8 + chunkSize + (chunkSize & 1);
      if (chunkSize == 0) break;
    }
  }

  /// Parses a strl (stream list) to extract track information.
  static ContainerTrack? _parseStrlList(Uint8List data, int startOffset, int size, int trackId) {
    final endOffset = startOffset + size;
    var offset = startOffset;

    String? streamType;
    String? handler;
    int? formatTag;
    int? width;
    int? height;
    double? frameRate;
    int? sampleRate;
    int? channels;

    while (offset + 8 <= endOffset && offset + 8 <= data.length) {
      final chunkId = _readFourcc(data, offset);
      final chunkSize = _readUint32Le(data, offset + 4);
      final dataOffset = offset + 8;

      if (dataOffset + chunkSize > data.length) break;

      switch (chunkId) {
        case 'strh':
          // Stream header
          if (chunkSize >= 8) {
            streamType = _readFourcc(data, dataOffset);
            handler = _readFourcc(data, dataOffset + 4);

            // Extract frame rate (dwScale/dwRate at offset 20 and 24)
            if (chunkSize >= 28) {
              final dwScale = _readUint32Le(data, dataOffset + 20);
              final dwRate = _readUint32Le(data, dataOffset + 24);
              if (dwScale > 0) {
                frameRate = dwRate / dwScale;
              }
            }
          }

        case 'strf':
          // Stream format
          if (streamType == AviStreamType.video && chunkSize >= 40) {
            // BITMAPINFOHEADER
            width = _readInt32Le(data, dataOffset + 4);
            height = _readInt32Le(data, dataOffset + 8).abs(); // Can be negative

            // biCompression (fourcc) at offset 16
            final compression = _readFourcc(data, dataOffset + 16);
            if (compression != '\x00\x00\x00\x00' && compression.trim().isNotEmpty) {
              handler = compression;
            }
          } else if (streamType == AviStreamType.audio && chunkSize >= 2) {
            // WAVEFORMATEX
            formatTag = _readUint16Le(data, dataOffset);
            if (chunkSize >= 4) {
              channels = _readUint16Le(data, dataOffset + 2);
            }
            if (chunkSize >= 8) {
              sampleRate = _readUint32Le(data, dataOffset + 4);
            }
          }
      }

      offset += 8 + chunkSize + (chunkSize & 1);
      if (chunkSize == 0) break;
    }

    if (streamType == null) return null;

    final type = _mapStreamType(streamType);
    if (type == ContainerTrackType.unknown) return null;

    CodecInfo codec;
    VideoTrackInfo? videoInfo;
    AudioTrackInfo? audioInfo;

    if (type == ContainerTrackType.video) {
      final codecName = mapFourccToCodecName(handler ?? '');
      codec = CodecInfo(fourcc: (handler ?? 'unkn').toUpperCase(), name: codecName, codecString: handler);
      if (width != null && height != null) {
        videoInfo = VideoTrackInfo(width: width, height: height, frameRate: frameRate);
      }
    } else if (type == ContainerTrackType.audio) {
      final codecName = formatTag != null ? mapAudioFormatTagToCodecName(formatTag) : handler ?? 'Unknown';
      codec = CodecInfo(
        fourcc: formatTag != null ? '0x${formatTag.toRadixString(16).padLeft(4, '0')}' : handler ?? 'unkn',
        name: codecName,
        codecString: formatTag?.toString(),
      );
      if (sampleRate != null || channels != null) {
        audioInfo = AudioTrackInfo(
          sampleRate: sampleRate ?? 0,
          channelCount: channels ?? 0,
          channelLayout: channels == 1
              ? 'mono'
              : channels == 2
              ? 'stereo'
              : null,
        );
      }
    } else {
      codec = CodecInfo(fourcc: handler ?? 'unkn', name: handler ?? 'Unknown', codecString: handler);
    }

    return ContainerTrack(id: trackId, type: type, codec: codec, videoInfo: videoInfo, audioInfo: audioInfo);
  }

  /// Maps stream type fourcc to track type.
  static ContainerTrackType _mapStreamType(String streamType) => switch (streamType) {
    AviStreamType.video => ContainerTrackType.video,
    AviStreamType.audio => ContainerTrackType.audio,
    AviStreamType.subtitle => ContainerTrackType.subtitle,
    _ => ContainerTrackType.unknown,
  };

  /// Maps video fourcc to human-readable codec name.
  static String mapFourccToCodecName(String fourcc) {
    final upper = fourcc.toUpperCase().trim();

    return switch (upper) {
      // H.264/AVC variants
      'H264' || 'X264' || 'AVC1' || 'DAVC' || 'VSSH' => 'H.264',

      // HEVC variants
      'HEVC' || 'H265' || 'HVC1' || 'HEV1' => 'HEVC',

      // MPEG-4 Part 2
      'XVID' => 'Xvid',
      'DIVX' || 'DIV3' || 'DIV4' => 'DivX',
      'DX50' => 'DivX 5',
      'MP4V' || 'MP42' || 'MP43' => 'MPEG-4',
      'FMP4' => 'FFmpeg MPEG-4',

      // MPEG-1/2
      'MPEG' || 'MPG1' => 'MPEG-1',
      'MPG2' || 'MPEG2' => 'MPEG-2',

      // MJPEG variants
      'MJPG' || 'MJPA' || 'MJPB' || 'JPEG' => 'Motion JPEG',

      // VP codecs
      'VP80' || 'VP8 ' => 'VP8',
      'VP90' || 'VP9 ' => 'VP9',
      'AV01' => 'AV1',

      // Lossless
      'HFYU' => 'Huffyuv',
      'FFV1' => 'FFV1',
      'LAGARITH' || 'LAGS' => 'Lagarith',

      // Screen capture
      'CSCD' => 'CamStudio',
      'TSCC' => 'TechSmith',

      // Other
      'CVID' => 'Cinepak',
      'IV31' || 'IV32' => 'Intel Indeo 3',
      'IV41' || 'IV50' => 'Intel Indeo',
      'WMV1' => 'WMV 7',
      'WMV2' => 'WMV 8',
      'WMV3' => 'WMV 9',
      'WVC1' => 'VC-1',

      _ => fourcc.isEmpty ? 'Unknown' : fourcc,
    };
  }

  /// Maps audio format tag to human-readable codec name.
  static String mapAudioFormatTagToCodecName(int formatTag) => switch (formatTag) {
    AviAudioFormat.pcm => 'PCM',
    AviAudioFormat.adpcm => 'ADPCM',
    AviAudioFormat.ieeeFloat => 'PCM Float',
    AviAudioFormat.alaw => 'A-law',
    AviAudioFormat.mulaw => 'mu-law',
    AviAudioFormat.imaAdpcm => 'IMA ADPCM',
    AviAudioFormat.mp2 => 'MP2',
    AviAudioFormat.mp3 => 'MP3',
    AviAudioFormat.aac => 'AAC',
    AviAudioFormat.wma1 => 'WMA',
    AviAudioFormat.wma2 => 'WMA v2',
    AviAudioFormat.wmaPro => 'WMA Pro',
    AviAudioFormat.ac3 => 'AC-3',
    AviAudioFormat.dts => 'DTS',
    AviAudioFormat.vorbis => 'Vorbis',
    AviAudioFormat.flac => 'FLAC',
    AviAudioFormat.extensible => 'Extensible',
    _ => 'Unknown',
  };

  /// Reads a fourcc string from data.
  static String _readFourcc(Uint8List data, int offset) {
    if (offset + 4 > data.length) return '';
    return String.fromCharCodes(data.sublist(offset, offset + 4));
  }

  /// Reads a 16-bit little-endian unsigned integer.
  static int _readUint16Le(Uint8List data, int offset) {
    if (offset + 2 > data.length) return 0;
    return data[offset] | (data[offset + 1] << 8);
  }

  /// Reads a 32-bit little-endian unsigned integer.
  static int _readUint32Le(Uint8List data, int offset) {
    if (offset + 4 > data.length) return 0;
    return data[offset] | (data[offset + 1] << 8) | (data[offset + 2] << 16) | (data[offset + 3] << 24);
  }

  /// Reads a 32-bit little-endian signed integer.
  static int _readInt32Le(Uint8List data, int offset) {
    final unsigned = _readUint32Le(data, offset);
    // Convert to signed
    if (unsigned >= 0x80000000) {
      return unsigned - 0x100000000;
    }
    return unsigned;
  }
}
