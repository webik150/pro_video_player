import '../types/audio_track_info.dart';
import '../types/codec_info.dart';
import '../types/container_metadata.dart';
import '../types/container_track.dart';
import '../types/container_track_type.dart';
import '../types/video_track_info.dart';
import 'mp4_box_reader.dart';

/// Parser for MP4/MOV container format (ISO Base Media File Format).
///
/// Extracts metadata from container headers including:
/// - Format and compatible brands
/// - Duration and timescale
/// - Track information (video, audio, subtitle)
/// - Codec details with profile/level
///
/// This is an internal implementation class. Use `ContainerParser` instead.
class Mp4Parser {
  Mp4Parser._();

  /// Detects the specific format from ftyp box contents.
  ///
  /// The [reader] should be positioned after reading the ftyp box header.
  /// Returns 'mp4', 'mov', 'm4a', 'm4v', '3gp', or null.
  static String? detectFormat(Mp4BoxReader reader, Mp4Box ftypBox) {
    reader.enterBox(ftypBox);

    if (reader.remaining < 8) return null;

    final majorBrand = reader.readFourCC().trim();

    // Skip minor version
    reader.skip(4);

    // Read compatible brands
    final brands = <String>[majorBrand];
    while (reader.position < ftypBox.endOffset && reader.hasRemaining(4)) {
      brands.add(reader.readFourCC().trim());
    }

    return _determineFormat(majorBrand, brands);
  }

  /// Parses full container metadata.
  static ContainerMetadata? parse(Mp4BoxReader reader, String format) {
    reader.seek(0);

    // Parse ftyp for brands
    final ftypBox = reader.findBox('ftyp');
    var compatibleBrands = const <String>[];
    if (ftypBox != null) {
      reader.enterBox(ftypBox);
      if (reader.hasRemaining(8)) {
        reader.skip(4); // major brand
        reader.skip(4); // minor version
        final brands = <String>[];
        while (reader.position < ftypBox.endOffset && reader.hasRemaining(4)) {
          brands.add(reader.readFourCC().trim());
        }
        compatibleBrands = brands;
      }
    }

    // Find moov box
    reader.seek(0);
    final moovBox = reader.findBox('moov');
    if (moovBox == null) return null;

    // Parse mvhd for movie header
    final mvhdBox = reader.findChildBox(moovBox, 'mvhd');
    var duration = Duration.zero;
    int? timescale;
    DateTime? creationTime;
    DateTime? modificationTime;

    if (mvhdBox != null) {
      final mvhdData = _parseMvhd(reader, mvhdBox);
      duration = mvhdData.duration;
      timescale = mvhdData.timescale;
      creationTime = mvhdData.creationTime;
      modificationTime = mvhdData.modificationTime;
    }

    // Parse tracks
    final tracks = <ContainerTrack>[];
    reader.seek(moovBox.dataOffset);

    while (reader.position < moovBox.endOffset) {
      final trakBox = reader.readChildBox(moovBox);
      if (trakBox == null) break;

      if (trakBox.type == 'trak') {
        final track = _parseTrak(reader, trakBox, timescale ?? 1000);
        if (track != null) {
          tracks.add(track);
        }
      }
      // Always advance to end of this box before reading next sibling
      reader.seek(trakBox.endOffset);
    }

    return ContainerMetadata(
      format: format,
      duration: duration,
      tracks: tracks,
      creationTime: creationTime,
      modificationTime: modificationTime,
      timescale: timescale,
      compatibleBrands: compatibleBrands,
    );
  }

  /// Determines format from brands.
  static String? _determineFormat(String majorBrand, List<String> brands) {
    // Check major brand first
    if (majorBrand == 'qt') return 'mov';
    if (majorBrand.startsWith('M4A')) return 'm4a';
    if (majorBrand.startsWith('M4V')) return 'm4v';
    if (majorBrand.startsWith('3gp')) return '3gp';
    if (majorBrand.startsWith('3g2')) return '3g2';

    // Check compatible brands
    for (final brand in brands) {
      if (brand == 'qt') return 'mov';
    }

    // Default to mp4 for ISO base media file format
    if (majorBrand.startsWith('iso') ||
        majorBrand.startsWith('mp4') ||
        majorBrand.startsWith('avc') ||
        majorBrand.startsWith('hvc') ||
        brands.any((b) => b.startsWith('iso') || b.startsWith('mp4'))) {
      return 'mp4';
    }

    return null;
  }

  /// Parses mvhd (movie header) box.
  static _MvhdData _parseMvhd(Mp4BoxReader reader, Mp4Box mvhdBox) {
    reader.enterBox(mvhdBox);

    final version = reader.readUint8();
    reader.skip(3); // flags

    int creationTimestamp;
    int modificationTimestamp;
    int timescale;
    int durationUnits;

    if (version == 1) {
      // 64-bit values
      creationTimestamp = reader.readUint64();
      modificationTimestamp = reader.readUint64();
      timescale = reader.readUint32();
      durationUnits = reader.readUint64();
    } else {
      // 32-bit values (version 0)
      creationTimestamp = reader.readUint32();
      modificationTimestamp = reader.readUint32();
      timescale = reader.readUint32();
      durationUnits = reader.readUint32();
    }

    // Convert MP4 timestamps (seconds since 1904-01-01) to DateTime
    DateTime? creationTime;
    DateTime? modificationTime;
    if (creationTimestamp > 0) {
      creationTime = _mp4TimestampToDateTime(creationTimestamp);
    }
    if (modificationTimestamp > 0) {
      modificationTime = _mp4TimestampToDateTime(modificationTimestamp);
    }

    // Calculate duration in milliseconds
    final durationMs = timescale > 0 ? (durationUnits * 1000 ~/ timescale) : 0;

    return _MvhdData(
      duration: Duration(milliseconds: durationMs),
      timescale: timescale,
      creationTime: creationTime,
      modificationTime: modificationTime,
    );
  }

  /// Parses a trak (track) box.
  static ContainerTrack? _parseTrak(Mp4BoxReader reader, Mp4Box trakBox, int movieTimescale) {
    // Parse tkhd for track ID and dimensions
    final tkhdBox = reader.findChildBox(trakBox, 'tkhd');
    if (tkhdBox == null) return null;

    final tkhdData = _parseTkhd(reader, tkhdBox);

    // Parse mdia for handler type, language, and codec info
    final mdiaBox = reader.findChildBox(trakBox, 'mdia');
    if (mdiaBox == null) return null;

    // Get handler type from hdlr
    final hdlrBox = reader.findChildBox(mdiaBox, 'hdlr');
    if (hdlrBox == null) return null;

    final handlerType = _parseHdlr(reader, hdlrBox);
    final trackType = ContainerTrackType.fromHandlerType(handlerType);

    // Get language and duration from mdhd
    final mdhdBox = reader.findChildBox(mdiaBox, 'mdhd');
    String? language;
    Duration? trackDuration;

    if (mdhdBox != null) {
      final mdhdData = _parseMdhd(reader, mdhdBox);
      language = mdhdData.language;
      trackDuration = mdhdData.duration;
    }

    // Get codec info from stsd
    final minfBox = reader.findChildBox(mdiaBox, 'minf');
    if (minfBox == null) return null;

    final stblBox = reader.findChildBox(minfBox, 'stbl');
    if (stblBox == null) return null;

    final stsdBox = reader.findChildBox(stblBox, 'stsd');
    var codec = CodecInfo.empty;
    VideoTrackInfo? videoInfo;
    AudioTrackInfo? audioInfo;

    if (stsdBox != null) {
      final stsdData = _parseStsd(reader, stsdBox, trackType);
      codec = stsdData.codec;
      videoInfo = stsdData.videoInfo;
      audioInfo = stsdData.audioInfo;
    }

    // Get sample count from stsz
    final stszBox = reader.findChildBox(stblBox, 'stsz');
    int? sampleCount;
    if (stszBox != null) {
      sampleCount = _parseStsz(reader, stszBox);
    }

    // Get bitrate estimate from sample sizes if available
    int? bitrate;
    if (trackDuration != null && trackDuration.inMilliseconds > 0 && sampleCount != null) {
      // Rough estimate: would need full stsz parsing for accurate value
    }

    // Apply tkhd dimensions to videoInfo if not set
    if (trackType == ContainerTrackType.video && videoInfo == null && tkhdData.width > 0) {
      videoInfo = VideoTrackInfo(
        width: tkhdData.width.round(),
        height: tkhdData.height.round(),
        rotation: tkhdData.rotation,
      );
    }

    return ContainerTrack(
      id: tkhdData.trackId,
      type: trackType,
      codec: codec,
      duration: trackDuration,
      language: language,
      bitrate: bitrate,
      sampleCount: sampleCount,
      videoInfo: videoInfo,
      audioInfo: audioInfo,
    );
  }

  /// Parses tkhd (track header) box.
  static _TkhdData _parseTkhd(Mp4BoxReader reader, Mp4Box tkhdBox) {
    reader.enterBox(tkhdBox);

    final version = reader.readUint8();
    reader.skip(3); // flags

    int trackId;
    if (version == 1) {
      reader.skip(8); // creation_time
      reader.skip(8); // modification_time
      trackId = reader.readUint32();
      reader.skip(4); // reserved
      reader.skip(8); // duration
    } else {
      reader.skip(4); // creation_time
      reader.skip(4); // modification_time
      trackId = reader.readUint32();
      reader.skip(4); // reserved
      reader.skip(4); // duration
    }

    reader.skip(8); // reserved[2]
    reader.skip(2); // layer
    reader.skip(2); // alternate_group
    reader.skip(2); // volume
    reader.skip(2); // reserved

    // Read transformation matrix (36 bytes)
    final rotation = reader.readRotationFromMatrix();

    // Width and height are 16.16 fixed-point
    final width = reader.readFixedPoint16_16();
    final height = reader.readFixedPoint16_16();

    return _TkhdData(trackId: trackId, width: width, height: height, rotation: rotation);
  }

  /// Parses hdlr (handler) box to get handler type.
  static String _parseHdlr(Mp4BoxReader reader, Mp4Box hdlrBox) {
    reader.enterBox(hdlrBox);

    reader.skip(4); // version + flags
    reader.skip(4); // pre_defined

    return reader.readFourCC();
  }

  /// Parses mdhd (media header) box.
  static _MdhdData _parseMdhd(Mp4BoxReader reader, Mp4Box mdhdBox) {
    reader.enterBox(mdhdBox);

    final version = reader.readUint8();
    reader.skip(3); // flags

    int timescale;
    int durationUnits;

    if (version == 1) {
      reader.skip(8); // creation_time
      reader.skip(8); // modification_time
      timescale = reader.readUint32();
      durationUnits = reader.readUint64();
    } else {
      reader.skip(4); // creation_time
      reader.skip(4); // modification_time
      timescale = reader.readUint32();
      durationUnits = reader.readUint32();
    }

    final language = reader.readLanguage();

    final durationMs = timescale > 0 ? (durationUnits * 1000 ~/ timescale) : 0;

    return _MdhdData(
      duration: Duration(milliseconds: durationMs),
      language: language,
    );
  }

  /// Parses stsd (sample description) box.
  static _StsdData _parseStsd(Mp4BoxReader reader, Mp4Box stsdBox, ContainerTrackType trackType) {
    reader.enterBox(stsdBox);

    reader.skip(4); // version + flags
    final entryCount = reader.readUint32();

    if (entryCount == 0) {
      return const _StsdData(codec: CodecInfo.empty);
    }

    // Read first sample entry
    final entryBox = reader.readBox();
    if (entryBox == null) {
      return const _StsdData(codec: CodecInfo.empty);
    }

    final fourcc = entryBox.type;
    final codecName = _getCodecName(fourcc);
    String? codecString;
    int? profile;
    int? level;
    VideoTrackInfo? videoInfo;
    AudioTrackInfo? audioInfo;

    reader.enterBox(entryBox);

    if (trackType == ContainerTrackType.video) {
      // Skip common video sample entry fields
      reader.skip(6); // reserved
      reader.skip(2); // data_reference_index
      reader.skip(2); // pre_defined
      reader.skip(2); // reserved
      reader.skip(12); // pre_defined[3]

      final width = reader.readUint16();
      final height = reader.readUint16();

      reader.skip(4); // horizresolution
      reader.skip(4); // vertresolution
      reader.skip(4); // reserved
      reader.skip(2); // frame_count
      reader.skip(32); // compressorname
      reader.skip(2); // depth
      reader.skip(2); // pre_defined

      videoInfo = VideoTrackInfo(width: width, height: height);

      // Look for codec configuration boxes
      final codecConfig = _parseVideoCodecConfig(reader, entryBox, fourcc);
      if (codecConfig != null) {
        codecString = codecConfig.codecString;
        profile = codecConfig.profile;
        level = codecConfig.level;
      }
    } else if (trackType == ContainerTrackType.audio) {
      // Skip common audio sample entry fields
      reader.skip(6); // reserved
      reader.skip(2); // data_reference_index
      reader.skip(8); // reserved[2]

      final channelCount = reader.readUint16();
      reader.skip(2); // sampleSize
      reader.skip(2); // pre_defined
      reader.skip(2); // reserved

      final sampleRate = reader.readUint32() >> 16; // 16.16 fixed point

      audioInfo = AudioTrackInfo(sampleRate: sampleRate, channelCount: channelCount);

      // Look for codec configuration boxes
      final codecConfig = _parseAudioCodecConfig(reader, entryBox, fourcc);
      if (codecConfig != null) {
        codecString = codecConfig.codecString;
        profile = codecConfig.profile;
        level = codecConfig.level;
      }
    }

    return _StsdData(
      codec: CodecInfo(fourcc: fourcc, name: codecName, codecString: codecString, profile: profile, level: level),
      videoInfo: videoInfo,
      audioInfo: audioInfo,
    );
  }

  /// Parses video codec configuration boxes (avcC, hvcC, etc.).
  static _CodecConfig? _parseVideoCodecConfig(Mp4BoxReader reader, Mp4Box entryBox, String fourcc) {
    // Position after the base video sample entry header
    final startPos = reader.position;

    // Look for codec-specific boxes
    while (reader.position < entryBox.endOffset && reader.hasRemaining(8)) {
      final childBox = reader.readChildBox(entryBox);
      if (childBox == null) break;

      if (childBox.type == 'avcC') {
        return _parseAvcC(reader, childBox);
      } else if (childBox.type == 'hvcC') {
        return _parseHvcC(reader, childBox);
      } else if (childBox.type == 'vpcC') {
        return _parseVpcC(reader, childBox);
      } else if (childBox.type == 'av1C') {
        return _parseAv1C(reader, childBox);
      }
    }

    reader.seek(startPos);
    return null;
  }

  /// Parses audio codec configuration boxes (esds, dac3, etc.).
  static _CodecConfig? _parseAudioCodecConfig(Mp4BoxReader reader, Mp4Box entryBox, String fourcc) {
    final startPos = reader.position;

    while (reader.position < entryBox.endOffset && reader.hasRemaining(8)) {
      final childBox = reader.readChildBox(entryBox);
      if (childBox == null) break;

      if (childBox.type == 'esds') {
        return _parseEsds(reader, childBox);
      } else if (childBox.type == 'dac3') {
        return _parseDac3(reader, childBox);
      } else if (childBox.type == 'dec3') {
        return _parseDec3(reader, childBox);
      } else if (childBox.type == 'dOps') {
        return _parseDOps(reader, childBox);
      } else if (childBox.type == 'alac') {
        return _parseAlac(reader, childBox);
      } else if (childBox.type == 'fLaC') {
        return _parseFlac(reader, childBox);
      }
    }

    reader.seek(startPos);
    return null;
  }

  /// Parses avcC box (H.264/AVC configuration).
  static _CodecConfig _parseAvcC(Mp4BoxReader reader, Mp4Box box) {
    reader.enterBox(box);

    if (!reader.hasRemaining(4)) {
      return const _CodecConfig();
    }

    reader.skip(1); // configurationVersion
    final profileIdc = reader.readUint8();
    final profileCompatibility = reader.readUint8();
    final levelIdc = reader.readUint8();

    // Build codec string: avc1.PPCCLL
    final codecString =
        'avc1.${profileIdc.toRadixString(16).padLeft(2, '0')}${profileCompatibility.toRadixString(16).padLeft(2, '0')}${levelIdc.toRadixString(16).padLeft(2, '0')}';

    return _CodecConfig(codecString: codecString, profile: profileIdc, level: levelIdc);
  }

  /// Parses hvcC box (HEVC/H.265 configuration).
  static _CodecConfig _parseHvcC(Mp4BoxReader reader, Mp4Box box) {
    reader.enterBox(box);

    if (!reader.hasRemaining(23)) {
      return const _CodecConfig();
    }

    reader.skip(1); // configurationVersion
    final generalProfileSpaceTierFlag = reader.readUint8();
    final generalProfileIdc = generalProfileSpaceTierFlag & 0x1F;
    final generalTierFlag = (generalProfileSpaceTierFlag >> 5) & 1;

    final generalProfileCompatibilityFlags = reader.readUint32();
    reader.skip(6); // general_constraint_indicator_flags (48 bits)
    final generalLevelIdc = reader.readUint8();

    // Build codec string: hvc1.P.XXXX.TLLL
    // Simplified version - full spec is more complex
    final tier = generalTierFlag == 1 ? 'H' : 'L';
    final codecString =
        'hvc1.$generalProfileIdc.'
        '${generalProfileCompatibilityFlags.toRadixString(16)}.'
        '$tier$generalLevelIdc';

    return _CodecConfig(codecString: codecString, profile: generalProfileIdc, level: generalLevelIdc);
  }

  /// Parses vpcC box (VP9 configuration).
  static _CodecConfig _parseVpcC(Mp4BoxReader reader, Mp4Box box) {
    reader.enterBox(box);

    if (!reader.hasRemaining(8)) {
      return const _CodecConfig();
    }

    reader.skip(1); // version
    reader.skip(3); // flags
    final profile = reader.readUint8();
    final level = reader.readUint8();
    final bitDepthChroma = reader.readUint8();
    final colorPrimaries = (bitDepthChroma >> 4) & 0x0F;

    // Build codec string: vp09.PP.LL.DD
    final codecString =
        'vp09.'
        '${profile.toString().padLeft(2, '0')}.'
        '${level.toString().padLeft(2, '0')}.'
        '${colorPrimaries.toString().padLeft(2, '0')}';

    return _CodecConfig(codecString: codecString, profile: profile, level: level);
  }

  /// Parses av1C box (AV1 configuration).
  static _CodecConfig _parseAv1C(Mp4BoxReader reader, Mp4Box box) {
    reader.enterBox(box);

    if (!reader.hasRemaining(4)) {
      return const _CodecConfig();
    }

    final byte1 = reader.readUint8();
    final seqProfile = (byte1 >> 5) & 0x07;
    final seqLevelIdx0 = byte1 & 0x1F;

    final byte2 = reader.readUint8();
    final seqTier0 = (byte2 >> 7) & 1;
    final highBitdepth = (byte2 >> 6) & 1;
    final twelveBit = (byte2 >> 5) & 1;
    final bitDepth = highBitdepth == 1 ? (twelveBit == 1 ? 12 : 10) : 8;

    // Build codec string: av01.P.LLT.BB
    final tier = seqTier0 == 1 ? 'H' : 'M';
    final codecString =
        'av01.$seqProfile.'
        '${seqLevelIdx0.toString().padLeft(2, '0')}$tier.'
        '${bitDepth.toString().padLeft(2, '0')}';

    return _CodecConfig(codecString: codecString, profile: seqProfile, level: seqLevelIdx0);
  }

  /// Parses esds box (Elementary Stream Descriptor).
  static _CodecConfig? _parseEsds(Mp4BoxReader reader, Mp4Box box) {
    reader.enterBox(box);

    reader.skip(4); // version + flags

    // Parse ES_Descriptor
    if (!reader.hasRemaining(3)) return null;

    final tag = reader.readUint8();
    if (tag != 0x03) return null; // ES_DescrTag

    _readDescriptorLength(reader);
    reader.skip(2); // ES_ID
    reader.skip(1); // flags

    // Parse DecoderConfigDescriptor
    if (!reader.hasRemaining(2)) return null;

    final dcTag = reader.readUint8();
    if (dcTag != 0x04) return null; // DecoderConfigDescrTag

    _readDescriptorLength(reader);

    if (!reader.hasRemaining(13)) return null;

    final objectTypeIndication = reader.readUint8();
    reader.skip(12); // streamType, bufferSize, maxBitrate, avgBitrate

    // Parse DecoderSpecificInfo for AAC
    if (!reader.hasRemaining(2)) return null;

    final dsiTag = reader.readUint8();
    if (dsiTag != 0x05) return null; // DecSpecificInfoTag

    final dsiLength = _readDescriptorLength(reader);
    if (dsiLength < 2 || !reader.hasRemaining(2)) return null;

    // Parse AudioSpecificConfig (first byte contains audioObjectType in top 5 bits)
    final byte1 = reader.readUint8();
    reader.skip(1); // Second byte not needed for audioObjectType

    final audioObjectType = (byte1 >> 3) & 0x1F;

    // Build codec string: mp4a.40.X
    final codecString = 'mp4a.${objectTypeIndication.toRadixString(16)}.$audioObjectType';

    return _CodecConfig(codecString: codecString, profile: audioObjectType);
  }

  /// Parses dac3 box (AC-3 configuration).
  static _CodecConfig _parseDac3(Mp4BoxReader reader, Mp4Box box) {
    reader.enterBox(box);
    // AC-3 doesn't have profile/level in the traditional sense
    return const _CodecConfig(codecString: 'ac-3');
  }

  /// Parses dec3 box (E-AC-3 configuration).
  static _CodecConfig _parseDec3(Mp4BoxReader reader, Mp4Box box) {
    reader.enterBox(box);
    return const _CodecConfig(codecString: 'ec-3');
  }

  /// Parses dOps box (Opus configuration).
  static _CodecConfig _parseDOps(Mp4BoxReader reader, Mp4Box box) {
    reader.enterBox(box);
    return const _CodecConfig(codecString: 'opus');
  }

  /// Parses alac box (Apple Lossless configuration).
  static _CodecConfig _parseAlac(Mp4BoxReader reader, Mp4Box box) {
    reader.enterBox(box);
    return const _CodecConfig(codecString: 'alac');
  }

  /// Parses fLaC box (FLAC configuration).
  static _CodecConfig _parseFlac(Mp4BoxReader reader, Mp4Box box) {
    reader.enterBox(box);
    return const _CodecConfig(codecString: 'flac');
  }

  /// Reads a variable-length descriptor length.
  static int _readDescriptorLength(Mp4BoxReader reader) {
    var length = 0;
    for (var i = 0; i < 4; i++) {
      final byte = reader.readUint8();
      length = (length << 7) | (byte & 0x7F);
      if ((byte & 0x80) == 0) break;
    }
    return length;
  }

  /// Parses stsz (sample size) box for sample count.
  static int _parseStsz(Mp4BoxReader reader, Mp4Box box) {
    reader.enterBox(box);

    reader.skip(4); // version + flags
    reader.skip(4); // sample_size

    return reader.readUint32(); // sample_count
  }

  /// Converts MP4 timestamp (seconds since 1904-01-01) to DateTime.
  static DateTime _mp4TimestampToDateTime(int timestamp) {
    // MP4 epoch is 1904-01-01 00:00:00 UTC
    const mp4Epoch = -2082844800; // Seconds from Unix epoch to MP4 epoch
    return DateTime.fromMillisecondsSinceEpoch((timestamp + mp4Epoch) * 1000, isUtc: true);
  }

  /// Gets human-readable codec name from fourcc.
  static String _getCodecName(String fourcc) => switch (fourcc) {
    'avc1' || 'avc3' => 'H.264',
    'hvc1' || 'hev1' => 'HEVC',
    'vp08' => 'VP8',
    'vp09' => 'VP9',
    'av01' => 'AV1',
    'mp4a' => 'AAC',
    'ac-3' => 'AC-3',
    'ec-3' => 'E-AC-3',
    'opus' || 'Opus' => 'Opus',
    'alac' => 'ALAC',
    'fLaC' => 'FLAC',
    'mp3 ' || '.mp3' => 'MP3',
    'text' => 'Text',
    'tx3g' => 'Timed Text',
    'wvtt' => 'WebVTT',
    'stpp' => 'TTML',
    'c608' => 'CEA-608',
    'c708' => 'CEA-708',
    _ => fourcc,
  };
}

/// Internal data class for mvhd parsing results.
class _MvhdData {
  const _MvhdData({required this.duration, required this.timescale, this.creationTime, this.modificationTime});

  final Duration duration;
  final int timescale;
  final DateTime? creationTime;
  final DateTime? modificationTime;
}

/// Internal data class for tkhd parsing results.
class _TkhdData {
  const _TkhdData({required this.trackId, required this.width, required this.height, required this.rotation});

  final int trackId;
  final double width;
  final double height;
  final int rotation;
}

/// Internal data class for mdhd parsing results.
class _MdhdData {
  const _MdhdData({required this.duration, required this.language});

  final Duration duration;
  final String language;
}

/// Internal data class for stsd parsing results.
class _StsdData {
  const _StsdData({required this.codec, this.videoInfo, this.audioInfo});

  final CodecInfo codec;
  final VideoTrackInfo? videoInfo;
  final AudioTrackInfo? audioInfo;
}

/// Internal data class for codec configuration.
class _CodecConfig {
  const _CodecConfig({this.codecString, this.profile, this.level});

  final String? codecString;
  final int? profile;
  final int? level;
}
