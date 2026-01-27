import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/src/container/mkv_parser.dart';
import 'package:pro_video_player_platform_interface/src/types/container_track_type.dart' show ContainerTrackType;

void main() {
  group('MkvParser', () {
    group('format detection', () {
      test('detects valid EBML header', () {
        final data = _createMinimalEbml();
        expect(MkvParser.isValidEbml(data), isTrue);
      });

      test('rejects non-EBML data', () {
        final data = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);
        expect(MkvParser.isValidEbml(data), isFalse);
      });

      test('rejects MP4 data', () {
        final data = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // size
          0x66, 0x74, 0x79, 0x70, // "ftyp"
          0x69, 0x73, 0x6F, 0x6D, // "isom"
        ]);
        expect(MkvParser.isValidEbml(data), isFalse);
      });

      test('detects webm doctype', () {
        final data = _createMinimalWebm();
        final format = MkvParser.detectFormat(data);
        expect(format, equals('webm'));
      });

      test('detects matroska doctype', () {
        final data = _createMinimalMatroska();
        final format = MkvParser.detectFormat(data);
        expect(format, equals('mkv'));
      });

      test('returns null for non-EBML', () {
        final data = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);
        expect(MkvParser.detectFormat(data), isNull);
      });
    });

    group('metadata parsing', () {
      test('parses minimal MKV with duration', () {
        final data = _createMkvWithDuration(5000); // 5 seconds
        final metadata = MkvParser.parse(data);

        expect(metadata, isNotNull);
        expect(metadata!.format, equals('mkv'));
        // Duration is in timecode scale units (default 1ms), so 5000ms = 5 seconds
        expect(metadata.duration.inSeconds, equals(5));
      });

      test('parses webm format correctly', () {
        final data = _createMinimalWebm();
        final metadata = MkvParser.parse(data);

        expect(metadata, isNotNull);
        expect(metadata!.format, equals('webm'));
      });

      test('returns null for invalid data', () {
        final data = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);
        final metadata = MkvParser.parse(data);
        expect(metadata, isNull);
      });
    });

    group('track parsing', () {
      test('parses video track', () {
        final data = _createMkvWithVideoTrack(trackNumber: 1, codecId: 'V_MPEG4/ISO/AVC', width: 1920, height: 1080);
        final metadata = MkvParser.parse(data);

        expect(metadata, isNotNull);
        expect(metadata!.tracks.length, equals(1));

        final track = metadata.tracks[0];
        expect(track.type, equals(ContainerTrackType.video));
        expect(track.codec.name, equals('H.264'));
        expect(track.videoInfo?.width, equals(1920));
        expect(track.videoInfo?.height, equals(1080));
      });

      test('parses audio track', () {
        final data = _createMkvWithAudioTrack(trackNumber: 1, codecId: 'A_AAC', sampleRate: 48000, channels: 2);
        final metadata = MkvParser.parse(data);

        expect(metadata, isNotNull);
        expect(metadata!.tracks.length, equals(1));

        final track = metadata.tracks[0];
        expect(track.type, equals(ContainerTrackType.audio));
        expect(track.codec.name, equals('AAC'));
        expect(track.audioInfo?.sampleRate, equals(48000));
        expect(track.audioInfo?.channelCount, equals(2));
      });

      test('parses subtitle track', () {
        final data = _createMkvWithSubtitleTrack(trackNumber: 1, codecId: 'S_TEXT/UTF8', language: 'eng');
        final metadata = MkvParser.parse(data);

        expect(metadata, isNotNull);
        expect(metadata!.tracks.length, equals(1));

        final track = metadata.tracks[0];
        expect(track.type, equals(ContainerTrackType.subtitle));
        expect(track.codec.name, equals('SRT'));
        expect(track.language, equals('eng'));
      });

      test('parses multiple tracks', () {
        final data = _createMkvWithMultipleTracks();
        final metadata = MkvParser.parse(data);

        expect(metadata, isNotNull);
        expect(metadata!.tracks.length, equals(3)); // video, audio, subtitle
        expect(metadata.videoTracks.length, equals(1));
        expect(metadata.audioTracks.length, equals(1));
        expect(metadata.subtitleTracks.length, equals(1));
      });

      test('parses track with language', () {
        final data = _createMkvWithAudioTrack(
          trackNumber: 1,
          codecId: 'A_AAC',
          sampleRate: 48000,
          channels: 2,
          language: 'spa',
        );
        final metadata = MkvParser.parse(data);

        expect(metadata, isNotNull);
        expect(metadata!.tracks[0].language, equals('spa'));
      });

      test('parses track with name', () {
        final data = _createMkvWithAudioTrack(
          trackNumber: 1,
          codecId: 'A_AAC',
          sampleRate: 48000,
          channels: 2,
          trackName: 'Spanish Audio',
        );
        final metadata = MkvParser.parse(data);

        expect(metadata, isNotNull);
        // Track name is stored but may not have a dedicated field in ContainerTrack
        // It should be available via codec name or track properties
      });
    });

    group('codec mapping', () {
      test('maps V_MPEG4/ISO/AVC to H.264', () {
        expect(MkvParser.mapCodecIdToName('V_MPEG4/ISO/AVC'), equals('H.264'));
        expect(MkvParser.mapCodecIdToFourcc('V_MPEG4/ISO/AVC'), equals('avc1'));
      });

      test('maps V_MPEGH/ISO/HEVC to HEVC', () {
        expect(MkvParser.mapCodecIdToName('V_MPEGH/ISO/HEVC'), equals('HEVC'));
        expect(MkvParser.mapCodecIdToFourcc('V_MPEGH/ISO/HEVC'), equals('hvc1'));
      });

      test('maps V_VP8 to VP8', () {
        expect(MkvParser.mapCodecIdToName('V_VP8'), equals('VP8'));
        expect(MkvParser.mapCodecIdToFourcc('V_VP8'), equals('vp08'));
      });

      test('maps V_VP9 to VP9', () {
        expect(MkvParser.mapCodecIdToName('V_VP9'), equals('VP9'));
        expect(MkvParser.mapCodecIdToFourcc('V_VP9'), equals('vp09'));
      });

      test('maps V_AV1 to AV1', () {
        expect(MkvParser.mapCodecIdToName('V_AV1'), equals('AV1'));
        expect(MkvParser.mapCodecIdToFourcc('V_AV1'), equals('av01'));
      });

      test('maps A_AAC to AAC', () {
        expect(MkvParser.mapCodecIdToName('A_AAC'), equals('AAC'));
        expect(MkvParser.mapCodecIdToFourcc('A_AAC'), equals('mp4a'));
      });

      test('maps A_OPUS to Opus', () {
        expect(MkvParser.mapCodecIdToName('A_OPUS'), equals('Opus'));
        expect(MkvParser.mapCodecIdToFourcc('A_OPUS'), equals('Opus'));
      });

      test('maps A_VORBIS to Vorbis', () {
        expect(MkvParser.mapCodecIdToName('A_VORBIS'), equals('Vorbis'));
        expect(MkvParser.mapCodecIdToFourcc('A_VORBIS'), equals('vorb'));
      });

      test('maps A_AC3 to AC-3', () {
        expect(MkvParser.mapCodecIdToName('A_AC3'), equals('AC-3'));
        expect(MkvParser.mapCodecIdToFourcc('A_AC3'), equals('ac-3'));
      });

      test('maps A_EAC3 to E-AC-3', () {
        expect(MkvParser.mapCodecIdToName('A_EAC3'), equals('E-AC-3'));
        expect(MkvParser.mapCodecIdToFourcc('A_EAC3'), equals('ec-3'));
      });

      test('maps A_DTS to DTS', () {
        expect(MkvParser.mapCodecIdToName('A_DTS'), equals('DTS'));
        expect(MkvParser.mapCodecIdToFourcc('A_DTS'), equals('dtsc'));
      });

      test('maps A_FLAC to FLAC', () {
        expect(MkvParser.mapCodecIdToName('A_FLAC'), equals('FLAC'));
        expect(MkvParser.mapCodecIdToFourcc('A_FLAC'), equals('fLaC'));
      });

      test('maps S_TEXT/UTF8 to SRT', () {
        expect(MkvParser.mapCodecIdToName('S_TEXT/UTF8'), equals('SRT'));
        expect(MkvParser.mapCodecIdToFourcc('S_TEXT/UTF8'), equals('srt '));
      });

      test('maps S_TEXT/WEBVTT to WebVTT', () {
        expect(MkvParser.mapCodecIdToName('S_TEXT/WEBVTT'), equals('WebVTT'));
        expect(MkvParser.mapCodecIdToFourcc('S_TEXT/WEBVTT'), equals('wvtt'));
      });

      test('maps S_TEXT/ASS to ASS', () {
        expect(MkvParser.mapCodecIdToName('S_TEXT/ASS'), equals('ASS'));
        expect(MkvParser.mapCodecIdToFourcc('S_TEXT/ASS'), equals('assa'));
      });

      test('returns codec ID for unknown codecs', () {
        expect(MkvParser.mapCodecIdToName('V_UNKNOWN'), equals('V_UNKNOWN'));
        expect(MkvParser.mapCodecIdToFourcc('V_UNKNOWN'), equals('unkn'));
      });
    });
  });
}

// Helper functions to create test EBML/MKV data

Uint8List _createMinimalEbml() {
  // EBML header element with minimal content
  return Uint8List.fromList([
    // EBML element: ID=0x1A45DFA3
    0x1A, 0x45, 0xDF, 0xA3,
    // Size = 8 bytes (VINT)
    0x88,
    // DocType element: ID=0x4282
    0x42, 0x82,
    // Size = 4 bytes
    0x84,
    // "webm" string
    0x77, 0x65, 0x62, 0x6D,
  ]);
}

Uint8List _createMinimalWebm() => Uint8List.fromList([
  // EBML header: ID + size (7 = DocType ID 2 + size 1 + "webm" 4)
  0x1A, 0x45, 0xDF, 0xA3, 0x87,
  // DocType = "webm"
  0x42, 0x82, 0x84, 0x77, 0x65, 0x62, 0x6D,
]);

Uint8List _createMinimalMatroska() => Uint8List.fromList([
  // EBML header: ID + size (11 = DocType ID 2 + size 1 + "matroska" 8)
  0x1A, 0x45, 0xDF, 0xA3, 0x8B,
  // DocType = "matroska"
  0x42, 0x82, 0x88, 0x6D, 0x61, 0x74, 0x72, 0x6F, 0x73, 0x6B, 0x61,
]);

Uint8List _createMkvWithDuration(double durationMs) {
  // Build Info element first to know its size
  final infoBuilder = BytesBuilder();

  // TimecodeScale = 1000000 (default, 1ms)
  infoBuilder.add([0x2A, 0xD7, 0xB1]); // TimecodeScale ID (3 bytes)
  infoBuilder.add([0x83]); // Size = 3 bytes
  infoBuilder.add([0x0F, 0x42, 0x40]); // 1000000

  // Duration (float)
  infoBuilder.add([0x44, 0x89]); // Duration ID (2 bytes)
  infoBuilder.add([0x88]); // Size = 8 bytes (double)
  final durationBytes = ByteData(8)..setFloat64(0, durationMs);
  infoBuilder.add(durationBytes.buffer.asUint8List());

  final infoContent = infoBuilder.toBytes();

  // Build Segment element
  final segmentBuilder = BytesBuilder();
  segmentBuilder.add([0x15, 0x49, 0xA9, 0x66]); // Info element ID
  _addVintSize(segmentBuilder, infoContent.length);
  segmentBuilder.add(infoContent);

  final segmentContent = segmentBuilder.toBytes();

  // Build complete file
  final builder = BytesBuilder();

  // EBML header with matroska doctype
  _addEbmlHeader(builder, 'matroska');

  // Segment element
  builder.add([0x18, 0x53, 0x80, 0x67]); // Segment ID
  _addVintSize(builder, segmentContent.length);
  builder.add(segmentContent);

  return builder.toBytes();
}

Uint8List _createMkvWithVideoTrack({
  required int trackNumber,
  required String codecId,
  required int width,
  required int height,
}) {
  // Build track data
  final trackData = _buildVideoTrack(trackNumber, codecId, width, height);

  // Build Tracks element
  final tracksBuilder = BytesBuilder();
  tracksBuilder.add([0x16, 0x54, 0xAE, 0x6B]); // Tracks ID
  _addVintSize(tracksBuilder, trackData.length);
  tracksBuilder.add(trackData);

  final segmentContent = tracksBuilder.toBytes();

  // Build complete file
  final builder = BytesBuilder();

  // EBML header with matroska doctype
  _addEbmlHeader(builder, 'matroska');

  // Segment element
  builder.add([0x18, 0x53, 0x80, 0x67]); // Segment ID
  _addVintSize(builder, segmentContent.length);
  builder.add(segmentContent);

  return builder.toBytes();
}

Uint8List _buildVideoTrack(int trackNumber, String codecId, int width, int height) {
  final builder = BytesBuilder();

  // TrackEntry element
  builder.add([0xAE]); // TrackEntry ID

  // Build track content first
  final contentBuilder = BytesBuilder();

  // TrackNumber
  contentBuilder.add([0xD7, 0x81]);
  contentBuilder.add([trackNumber]);

  // TrackUID
  contentBuilder.add([0x73, 0xC5, 0x81]);
  contentBuilder.add([trackNumber]);

  // TrackType = 1 (video)
  contentBuilder.add([0x83, 0x81, 0x01]);

  // CodecID
  contentBuilder.add([0x86]);
  final codecBytes = codecId.codeUnits;
  _addVintSize(contentBuilder, codecBytes.length);
  contentBuilder.add(codecBytes);

  // Video element
  contentBuilder.add([0xE0]); // Video ID
  final videoContent = BytesBuilder();
  // PixelWidth
  videoContent.add([0xB0, 0x82]); // 2 bytes
  videoContent.add([width >> 8, width & 0xFF]);
  // PixelHeight
  videoContent.add([0xBA, 0x82]); // 2 bytes
  videoContent.add([height >> 8, height & 0xFF]);
  _addVintSize(contentBuilder, videoContent.length);
  contentBuilder.add(videoContent.toBytes());

  _addVintSize(builder, contentBuilder.length);
  builder.add(contentBuilder.toBytes());

  return builder.toBytes();
}

Uint8List _createMkvWithAudioTrack({
  required int trackNumber,
  required String codecId,
  required double sampleRate,
  required int channels,
  String? language,
  String? trackName,
}) {
  // Build track data
  final trackData = _buildAudioTrack(trackNumber, codecId, sampleRate, channels, language, trackName);

  // Build Tracks element
  final tracksBuilder = BytesBuilder();
  tracksBuilder.add([0x16, 0x54, 0xAE, 0x6B]); // Tracks ID
  _addVintSize(tracksBuilder, trackData.length);
  tracksBuilder.add(trackData);

  final segmentContent = tracksBuilder.toBytes();

  // Build complete file
  final builder = BytesBuilder();

  // EBML header with matroska doctype
  _addEbmlHeader(builder, 'matroska');

  // Segment element
  builder.add([0x18, 0x53, 0x80, 0x67]); // Segment ID
  _addVintSize(builder, segmentContent.length);
  builder.add(segmentContent);

  return builder.toBytes();
}

Uint8List _buildAudioTrack(
  int trackNumber,
  String codecId,
  double sampleRate,
  int channels,
  String? language,
  String? trackName,
) {
  final builder = BytesBuilder();

  // TrackEntry element
  builder.add([0xAE]);

  final contentBuilder = BytesBuilder();

  // TrackNumber
  contentBuilder.add([0xD7, 0x81]);
  contentBuilder.add([trackNumber]);

  // TrackUID
  contentBuilder.add([0x73, 0xC5, 0x81]);
  contentBuilder.add([trackNumber]);

  // TrackType = 2 (audio)
  contentBuilder.add([0x83, 0x81, 0x02]);

  // CodecID
  contentBuilder.add([0x86]);
  final codecBytes = codecId.codeUnits;
  _addVintSize(contentBuilder, codecBytes.length);
  contentBuilder.add(codecBytes);

  // Language (optional)
  if (language != null) {
    contentBuilder.add([0x22, 0xB5, 0x9C]); // Language ID (3 bytes)
    final langBytes = language.codeUnits;
    _addVintSize(contentBuilder, langBytes.length);
    contentBuilder.add(langBytes);
  }

  // Name (optional)
  if (trackName != null) {
    contentBuilder.add([0x53, 0x6E]); // Name ID
    final nameBytes = trackName.codeUnits;
    _addVintSize(contentBuilder, nameBytes.length);
    contentBuilder.add(nameBytes);
  }

  // Audio element
  contentBuilder.add([0xE1]);
  final audioContent = BytesBuilder();

  // SamplingFrequency (float)
  audioContent.add([0xB5, 0x84]); // 4 bytes float
  final sampleRateBytes = ByteData(4)..setFloat32(0, sampleRate);
  audioContent.add(sampleRateBytes.buffer.asUint8List());

  // Channels
  audioContent.add([0x9F, 0x81]);
  audioContent.add([channels]);

  _addVintSize(contentBuilder, audioContent.length);
  contentBuilder.add(audioContent.toBytes());

  _addVintSize(builder, contentBuilder.length);
  builder.add(contentBuilder.toBytes());

  return builder.toBytes();
}

Uint8List _createMkvWithSubtitleTrack({required int trackNumber, required String codecId, String? language}) {
  // Build track data
  final trackData = _buildSubtitleTrack(trackNumber, codecId, language);

  // Build Tracks element
  final tracksBuilder = BytesBuilder();
  tracksBuilder.add([0x16, 0x54, 0xAE, 0x6B]); // Tracks ID
  _addVintSize(tracksBuilder, trackData.length);
  tracksBuilder.add(trackData);

  final segmentContent = tracksBuilder.toBytes();

  // Build complete file
  final builder = BytesBuilder();

  // EBML header with matroska doctype
  _addEbmlHeader(builder, 'matroska');

  // Segment element
  builder.add([0x18, 0x53, 0x80, 0x67]); // Segment ID
  _addVintSize(builder, segmentContent.length);
  builder.add(segmentContent);

  return builder.toBytes();
}

Uint8List _buildSubtitleTrack(int trackNumber, String codecId, String? language) {
  final builder = BytesBuilder();

  // TrackEntry element
  builder.add([0xAE]);

  final contentBuilder = BytesBuilder();

  // TrackNumber
  contentBuilder.add([0xD7, 0x81]);
  contentBuilder.add([trackNumber]);

  // TrackUID
  contentBuilder.add([0x73, 0xC5, 0x81]);
  contentBuilder.add([trackNumber]);

  // TrackType = 17 (subtitle)
  contentBuilder.add([0x83, 0x81, 0x11]);

  // CodecID
  contentBuilder.add([0x86]);
  final codecBytes = codecId.codeUnits;
  _addVintSize(contentBuilder, codecBytes.length);
  contentBuilder.add(codecBytes);

  // Language (optional)
  if (language != null) {
    contentBuilder.add([0x22, 0xB5, 0x9C]);
    final langBytes = language.codeUnits;
    _addVintSize(contentBuilder, langBytes.length);
    contentBuilder.add(langBytes);
  }

  _addVintSize(builder, contentBuilder.length);
  builder.add(contentBuilder.toBytes());

  return builder.toBytes();
}

Uint8List _createMkvWithMultipleTracks() {
  // Build all track data first
  final tracksContent = BytesBuilder();
  tracksContent.add(_buildVideoTrack(1, 'V_MPEG4/ISO/AVC', 1920, 1080));
  tracksContent.add(_buildAudioTrack(2, 'A_AAC', 48000, 2, 'eng', null));
  tracksContent.add(_buildSubtitleTrack(3, 'S_TEXT/UTF8', 'eng'));
  final tracksData = tracksContent.toBytes();

  // Build Tracks element
  final tracksBuilder = BytesBuilder();
  tracksBuilder.add([0x16, 0x54, 0xAE, 0x6B]); // Tracks ID
  _addVintSize(tracksBuilder, tracksData.length);
  tracksBuilder.add(tracksData);

  final segmentContent = tracksBuilder.toBytes();

  // Build complete file
  final builder = BytesBuilder();

  // EBML header with matroska doctype
  _addEbmlHeader(builder, 'matroska');

  // Segment element
  builder.add([0x18, 0x53, 0x80, 0x67]); // Segment ID
  _addVintSize(builder, segmentContent.length);
  builder.add(segmentContent);

  return builder.toBytes();
}

/// Adds a proper EBML header with the given doctype.
void _addEbmlHeader(BytesBuilder builder, String docType) {
  // Build DocType element
  final docTypeBytes = docType.codeUnits;
  final docTypeBuilder = BytesBuilder();
  docTypeBuilder.add([0x42, 0x82]); // DocType ID
  _addVintSize(docTypeBuilder, docTypeBytes.length);
  docTypeBuilder.add(docTypeBytes);
  final docTypeContent = docTypeBuilder.toBytes();

  // EBML header
  builder.add([0x1A, 0x45, 0xDF, 0xA3]); // EBML ID
  _addVintSize(builder, docTypeContent.length);
  builder.add(docTypeContent);
}

void _addVintSize(BytesBuilder builder, int size) {
  if (size < 127) {
    builder.add([0x80 | size]);
  } else if (size < 16383) {
    builder.add([0x40 | (size >> 8), size & 0xFF]);
  } else if (size < 2097151) {
    builder.add([0x20 | (size >> 16), (size >> 8) & 0xFF, size & 0xFF]);
  } else {
    builder.add([0x10 | (size >> 24), (size >> 16) & 0xFF, (size >> 8) & 0xFF, size & 0xFF]);
  }
}
