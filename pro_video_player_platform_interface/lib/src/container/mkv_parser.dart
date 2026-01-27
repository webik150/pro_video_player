import 'dart:typed_data';

import '../types/audio_track_info.dart';
import '../types/codec_info.dart';
import '../types/container_metadata.dart';
import '../types/container_track.dart';
import '../types/container_track_type.dart' show ContainerTrackType;
import '../types/video_track_info.dart';
import 'ebml_reader.dart';

/// Parser for MKV/WebM (Matroska) container files.
///
/// Extracts metadata from EBML-based containers including:
/// - Format type (MKV or WebM)
/// - Duration
/// - Track information (video, audio, subtitle)
/// - Codec details with codec IDs
///
/// Example:
/// ```dart
/// final metadata = MkvParser.parse(bytes);
/// if (metadata != null) {
///   print('Format: ${metadata.format}');
///   print('Duration: ${metadata.duration}');
///   for (final track in metadata.tracks) {
///     print('Track ${track.id}: ${track.codec.name}');
///   }
/// }
/// ```
class MkvParser {
  MkvParser._();

  /// Checks if the data starts with a valid EBML header.
  static bool isValidEbml(Uint8List data) {
    if (data.length < 4) return false;
    // EBML element ID: 0x1A45DFA3
    return data[0] == 0x1A && data[1] == 0x45 && data[2] == 0xDF && data[3] == 0xA3;
  }

  /// Detects the format from EBML data (mkv or webm).
  ///
  /// Returns null if the data is not valid EBML.
  static String? detectFormat(Uint8List data) {
    if (!isValidEbml(data)) return null;

    final reader = EbmlReader(data);
    final ebmlElement = reader.readElement();
    if (ebmlElement == null || ebmlElement.id != EbmlIds.ebml) return null;

    // Parse EBML header to find DocType
    final ebmlEnd = ebmlElement.dataOffset + ebmlElement.dataSize;
    while (reader.position < ebmlEnd) {
      final child = reader.readElement();
      if (child == null) break;

      if (child.id == EbmlIds.docType) {
        final docType = reader.readString(child.dataSize);
        if (docType == 'webm') return 'webm';
        if (docType == 'matroska') return 'mkv';
        return null;
      }
      reader.skip(child.dataSize);
    }

    return null;
  }

  /// Parses MKV/WebM container metadata from bytes.
  ///
  /// Returns null if the data is not a valid MKV/WebM file.
  static ContainerMetadata? parse(Uint8List data) {
    final format = detectFormat(data);
    if (format == null) return null;

    final reader = EbmlReader(data);

    // Skip EBML header
    final ebmlElement = reader.readElement();
    if (ebmlElement == null) return null;
    reader.position = ebmlElement.dataOffset + ebmlElement.dataSize;

    // Find Segment element
    final segmentElement = reader.readElement();
    if (segmentElement == null || segmentElement.id != EbmlIds.segment) {
      return ContainerMetadata(format: format, duration: Duration.zero, tracks: const []);
    }

    // Parse segment children
    var duration = Duration.zero;
    var timecodeScale = 1000000; // Default: 1ms
    final tracks = <ContainerTrack>[];

    final segmentEnd = segmentElement.dataOffset + segmentElement.dataSize;

    while (reader.position < segmentEnd && reader.hasMore) {
      final element = reader.readElement();
      if (element == null) break;

      switch (element.id) {
        case EbmlIds.info:
          final infoResult = _parseInfo(reader, element);
          if (infoResult.timecodeScale != null) {
            timecodeScale = infoResult.timecodeScale!;
          }
          if (infoResult.durationMs != null) {
            // Duration is in timecode scale units
            final durationNs = (infoResult.durationMs! * timecodeScale).round();
            duration = Duration(microseconds: durationNs ~/ 1000);
          }

        case EbmlIds.tracks:
          tracks.addAll(_parseTracks(reader, element));

        default:
          reader.skip(element.dataSize);
      }
    }

    return ContainerMetadata(format: format, duration: duration, tracks: tracks);
  }

  /// Parses the Info element.
  static ({int? timecodeScale, double? durationMs}) _parseInfo(EbmlReader reader, EbmlElement infoElement) {
    int? timecodeScale;
    double? durationMs;

    final infoEnd = infoElement.dataOffset + infoElement.dataSize;

    while (reader.position < infoEnd) {
      final element = reader.readElement();
      if (element == null) break;

      switch (element.id) {
        case MatroskaIds.timecodeScale:
          timecodeScale = reader.readUint(element.dataSize);

        case MatroskaIds.duration:
          durationMs = reader.readFloat(element.dataSize);

        default:
          reader.skip(element.dataSize);
      }
    }

    return (timecodeScale: timecodeScale, durationMs: durationMs);
  }

  /// Parses the Tracks element.
  static List<ContainerTrack> _parseTracks(EbmlReader reader, EbmlElement tracksElement) {
    final tracks = <ContainerTrack>[];
    final tracksEnd = tracksElement.dataOffset + tracksElement.dataSize;

    while (reader.position < tracksEnd) {
      final element = reader.readElement();
      if (element == null) break;

      if (element.id == MatroskaIds.trackEntry) {
        final track = _parseTrackEntry(reader, element);
        if (track != null) {
          tracks.add(track);
        }
      } else {
        reader.skip(element.dataSize);
      }
    }

    return tracks;
  }

  /// Parses a single TrackEntry element.
  static ContainerTrack? _parseTrackEntry(EbmlReader reader, EbmlElement trackElement) {
    int? trackNumber;
    int? trackType;
    String? codecId;
    String? language;
    VideoTrackInfo? videoInfo;
    AudioTrackInfo? audioInfo;

    final trackEnd = trackElement.dataOffset + trackElement.dataSize;

    while (reader.position < trackEnd) {
      final element = reader.readElement();
      if (element == null) break;

      switch (element.id) {
        case MatroskaIds.trackNumber:
          trackNumber = reader.readUint(element.dataSize);

        case MatroskaIds.trackType:
          trackType = reader.readUint(element.dataSize);

        case MatroskaIds.codecId:
          codecId = reader.readString(element.dataSize);

        case MatroskaIds.language:
          language = reader.readString(element.dataSize);

        case MatroskaIds.languageBcp47:
          // Prefer BCP 47 over ISO 639-2
          language = reader.readString(element.dataSize);

        case MatroskaIds.name:
          // Track name - skip for now (not in ContainerTrack type)
          reader.skip(element.dataSize);

        case MatroskaIds.video:
          videoInfo = _parseVideoElement(reader, element);

        case MatroskaIds.audio:
          audioInfo = _parseAudioElement(reader, element);

        default:
          reader.skip(element.dataSize);
      }
    }

    if (trackNumber == null || trackType == null) return null;

    final type = _mapTrackType(trackType);
    final codec = _createCodecInfo(codecId ?? '');

    return ContainerTrack(
      id: trackNumber,
      type: type,
      codec: codec,
      language: language,
      videoInfo: videoInfo,
      audioInfo: audioInfo,
    );
  }

  /// Parses Video element.
  static VideoTrackInfo _parseVideoElement(EbmlReader reader, EbmlElement videoElement) {
    var width = 0;
    var height = 0;
    int? displayWidth;
    int? displayHeight;
    double? frameRate;

    final videoEnd = videoElement.dataOffset + videoElement.dataSize;

    while (reader.position < videoEnd) {
      final element = reader.readElement();
      if (element == null) break;

      switch (element.id) {
        case MatroskaIds.pixelWidth:
          width = reader.readUint(element.dataSize);

        case MatroskaIds.pixelHeight:
          height = reader.readUint(element.dataSize);

        case MatroskaIds.displayWidth:
          displayWidth = reader.readUint(element.dataSize);

        case MatroskaIds.displayHeight:
          displayHeight = reader.readUint(element.dataSize);

        case MatroskaIds.frameRate:
          frameRate = reader.readFloat(element.dataSize);

        default:
          reader.skip(element.dataSize);
      }
    }

    // Calculate pixel aspect ratio if display dimensions differ
    double? pixelAspectRatio;
    if (displayWidth != null && displayHeight != null && width > 0 && height > 0) {
      final displayAspect = displayWidth / displayHeight;
      final pixelAspect = width / height;
      if ((displayAspect - pixelAspect).abs() > 0.01) {
        pixelAspectRatio = displayAspect / pixelAspect;
      }
    }

    return VideoTrackInfo(width: width, height: height, frameRate: frameRate, pixelAspectRatio: pixelAspectRatio);
  }

  /// Parses Audio element.
  static AudioTrackInfo _parseAudioElement(EbmlReader reader, EbmlElement audioElement) {
    var sampleRate = 8000.0;
    var channels = 1;

    final audioEnd = audioElement.dataOffset + audioElement.dataSize;

    while (reader.position < audioEnd) {
      final element = reader.readElement();
      if (element == null) break;

      switch (element.id) {
        case MatroskaIds.samplingFrequency:
          sampleRate = reader.readFloat(element.dataSize);

        case MatroskaIds.channels:
          channels = reader.readUint(element.dataSize);

        case MatroskaIds.bitDepth:
          // Bit depth - skip for now (not in AudioTrackInfo type)
          reader.skip(element.dataSize);

        default:
          reader.skip(element.dataSize);
      }
    }

    // Map channels to layout name
    String? channelLayout;
    switch (channels) {
      case 1:
        channelLayout = 'mono';
      case 2:
        channelLayout = 'stereo';
      case 6:
        channelLayout = '5.1';
      case 8:
        channelLayout = '7.1';
    }

    return AudioTrackInfo(sampleRate: sampleRate.round(), channelCount: channels, channelLayout: channelLayout);
  }

  /// Maps Matroska track type to ContainerTrackType enum.
  static ContainerTrackType _mapTrackType(int mkvType) => switch (mkvType) {
    MatroskaTrackType.video => ContainerTrackType.video,
    MatroskaTrackType.audio => ContainerTrackType.audio,
    MatroskaTrackType.subtitle => ContainerTrackType.subtitle,
    _ => ContainerTrackType.unknown,
  };

  /// Creates CodecInfo from Matroska codec ID.
  static CodecInfo _createCodecInfo(String codecId) =>
      CodecInfo(fourcc: mapCodecIdToFourcc(codecId), name: mapCodecIdToName(codecId), codecString: codecId);

  /// Maps Matroska codec ID to human-readable name.
  static String mapCodecIdToName(String codecId) => _codecNames[codecId] ?? codecId;

  /// Maps Matroska codec ID to FourCC.
  static String mapCodecIdToFourcc(String codecId) => _codecFourccs[codecId] ?? 'unkn';

  /// Codec ID to name mapping.
  static const _codecNames = {
    // Video
    'V_MPEG4/ISO/AVC': 'H.264',
    'V_MPEGH/ISO/HEVC': 'HEVC',
    'V_VP8': 'VP8',
    'V_VP9': 'VP9',
    'V_AV1': 'AV1',
    'V_MPEG4/ISO/SP': 'MPEG-4 SP',
    'V_MPEG4/ISO/ASP': 'MPEG-4 ASP',
    'V_MPEG4/ISO/AP': 'MPEG-4 AP',
    'V_MPEG4/MS/V3': 'MPEG-4 V3',
    'V_MPEG1': 'MPEG-1',
    'V_MPEG2': 'MPEG-2',
    'V_THEORA': 'Theora',
    'V_PRORES': 'ProRes',

    // Audio
    'A_AAC': 'AAC',
    'A_AAC/MPEG2/LC': 'AAC LC',
    'A_AAC/MPEG2/MAIN': 'AAC Main',
    'A_AAC/MPEG4/LC': 'AAC LC',
    'A_AAC/MPEG4/MAIN': 'AAC Main',
    'A_AAC/MPEG4/LC/SBR': 'HE-AAC',
    'A_AAC/MPEG4/SBR': 'HE-AAC',
    'A_OPUS': 'Opus',
    'A_VORBIS': 'Vorbis',
    'A_AC3': 'AC-3',
    'A_EAC3': 'E-AC-3',
    'A_DTS': 'DTS',
    'A_DTS/EXPRESS': 'DTS Express',
    'A_DTS/LOSSLESS': 'DTS-HD MA',
    'A_TRUEHD': 'TrueHD',
    'A_FLAC': 'FLAC',
    'A_ALAC': 'ALAC',
    'A_PCM/INT/BIG': 'PCM BE',
    'A_PCM/INT/LIT': 'PCM LE',
    'A_PCM/FLOAT/IEEE': 'PCM Float',
    'A_MPEG/L3': 'MP3',
    'A_MPEG/L2': 'MP2',
    'A_MPEG/L1': 'MP1',

    // Subtitles
    'S_TEXT/UTF8': 'SRT',
    'S_TEXT/WEBVTT': 'WebVTT',
    'S_TEXT/ASS': 'ASS',
    'S_TEXT/SSA': 'SSA',
    'S_TEXT/USF': 'USF',
    'S_HDMV/PGS': 'PGS',
    'S_HDMV/TEXTST': 'HDMV Text',
    'S_VOBSUB': 'VobSub',
    'S_DVBSUB': 'DVB Sub',
    'S_KATE': 'Kate',
  };

  /// Codec ID to FourCC mapping.
  static const _codecFourccs = {
    // Video
    'V_MPEG4/ISO/AVC': 'avc1',
    'V_MPEGH/ISO/HEVC': 'hvc1',
    'V_VP8': 'vp08',
    'V_VP9': 'vp09',
    'V_AV1': 'av01',
    'V_MPEG4/ISO/SP': 'mp4v',
    'V_MPEG4/ISO/ASP': 'mp4v',
    'V_MPEG4/ISO/AP': 'mp4v',
    'V_MPEG1': 'mpg1',
    'V_MPEG2': 'mpg2',
    'V_THEORA': 'theo',
    'V_PRORES': 'apch',

    // Audio
    'A_AAC': 'mp4a',
    'A_AAC/MPEG2/LC': 'mp4a',
    'A_AAC/MPEG2/MAIN': 'mp4a',
    'A_AAC/MPEG4/LC': 'mp4a',
    'A_AAC/MPEG4/MAIN': 'mp4a',
    'A_AAC/MPEG4/LC/SBR': 'mp4a',
    'A_AAC/MPEG4/SBR': 'mp4a',
    'A_OPUS': 'Opus',
    'A_VORBIS': 'vorb',
    'A_AC3': 'ac-3',
    'A_EAC3': 'ec-3',
    'A_DTS': 'dtsc',
    'A_DTS/EXPRESS': 'dtse',
    'A_DTS/LOSSLESS': 'dtsh',
    'A_TRUEHD': 'mlpa',
    'A_FLAC': 'fLaC',
    'A_ALAC': 'alac',
    'A_MPEG/L3': '.mp3',
    'A_MPEG/L2': '.mp2',
    'A_MPEG/L1': '.mp1',

    // Subtitles
    'S_TEXT/UTF8': 'srt ',
    'S_TEXT/WEBVTT': 'wvtt',
    'S_TEXT/ASS': 'assa',
    'S_TEXT/SSA': 'ssa ',
    'S_HDMV/PGS': 'pgs ',
    'S_VOBSUB': 'vobs',
    'S_DVBSUB': 'dvbs',
  };
}
