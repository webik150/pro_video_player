import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/src/container/avi_parser.dart';
import 'package:pro_video_player_platform_interface/src/types/container_track_type.dart';

void main() {
  group('AviParser', () {
    group('format detection', () {
      test('detects valid AVI by RIFF/AVI signature', () {
        final data = _createAviHeader();
        expect(AviParser.isValidAvi(data), isTrue);
      });

      test('rejects data without RIFF signature', () {
        final data = Uint8List(12);
        data.setRange(0, 4, [0x00, 0x00, 0x00, 0x00]);
        expect(AviParser.isValidAvi(data), isFalse);
      });

      test('rejects RIFF without AVI type', () {
        final data = Uint8List(12);
        data.setRange(0, 4, [0x52, 0x49, 0x46, 0x46]); // "RIFF"
        data.setRange(4, 8, [0x00, 0x00, 0x00, 0x00]); // size
        data.setRange(8, 12, [0x57, 0x41, 0x56, 0x45]); // "WAVE" not "AVI "
        expect(AviParser.isValidAvi(data), isFalse);
      });

      test('rejects data too short', () {
        final data = Uint8List.fromList([0x52, 0x49, 0x46, 0x46]); // Just "RIFF"
        expect(AviParser.isValidAvi(data), isFalse);
      });

      test('detectFormat returns avi for valid data', () {
        final data = _createAviHeader();
        expect(AviParser.detectFormat(data), equals('avi'));
      });

      test('detectFormat returns null for invalid data', () {
        final data = Uint8List(12);
        expect(AviParser.detectFormat(data), isNull);
      });
    });

    group('stream parsing', () {
      test('extracts video track from stream header', () {
        final data = _createAviWithStreams(streams: [(type: 'vids', handler: 'H264')]);
        final result = AviParser.parse(data);

        expect(result, isNotNull);
        expect(result!.tracks.length, equals(1));
        expect(result.tracks[0].type, equals(ContainerTrackType.video));
        expect(result.tracks[0].codec.fourcc, equals('H264'));
      });

      test('extracts audio track from stream header', () {
        final data = _createAviWithStreams(streams: [(type: 'auds', handler: 'MP3 ')]);
        final result = AviParser.parse(data);

        expect(result, isNotNull);
        expect(result!.tracks.length, equals(1));
        expect(result.tracks[0].type, equals(ContainerTrackType.audio));
      });

      test('extracts multiple tracks', () {
        final data = _createAviWithStreams(
          streams: [(type: 'vids', handler: 'XVID'), (type: 'auds', handler: 'MP3 '), (type: 'auds', handler: 'AC3 ')],
        );
        final result = AviParser.parse(data);

        expect(result, isNotNull);
        expect(result!.tracks.length, equals(3));
        expect(result.tracks[0].type, equals(ContainerTrackType.video));
        expect(result.tracks[1].type, equals(ContainerTrackType.audio));
        expect(result.tracks[2].type, equals(ContainerTrackType.audio));
      });

      test('extracts subtitle track', () {
        final data = _createAviWithStreams(streams: [(type: 'txts', handler: 'SRT ')]);
        final result = AviParser.parse(data);

        expect(result, isNotNull);
        expect(result!.tracks[0].type, equals(ContainerTrackType.subtitle));
      });
    });

    group('video codec detection', () {
      test('detects H.264 codec', () {
        final data = _createAviWithStreams(streams: [(type: 'vids', handler: 'H264')]);
        final result = AviParser.parse(data);

        expect(result!.tracks[0].codec.name, equals('H.264'));
        expect(result.tracks[0].codec.fourcc, equals('H264'));
      });

      test('detects HEVC codec', () {
        final data = _createAviWithStreams(streams: [(type: 'vids', handler: 'HEVC')]);
        final result = AviParser.parse(data);

        expect(result!.tracks[0].codec.name, equals('HEVC'));
      });

      test('detects XVID codec', () {
        final data = _createAviWithStreams(streams: [(type: 'vids', handler: 'XVID')]);
        final result = AviParser.parse(data);

        expect(result!.tracks[0].codec.name, equals('Xvid'));
      });

      test('detects DivX codec', () {
        final data = _createAviWithStreams(streams: [(type: 'vids', handler: 'DIVX')]);
        final result = AviParser.parse(data);

        expect(result!.tracks[0].codec.name, equals('DivX'));
      });

      test('detects MJPEG codec', () {
        final data = _createAviWithStreams(streams: [(type: 'vids', handler: 'MJPG')]);
        final result = AviParser.parse(data);

        expect(result!.tracks[0].codec.name, equals('Motion JPEG'));
      });

      test('detects VP8 codec', () {
        final data = _createAviWithStreams(streams: [(type: 'vids', handler: 'VP80')]);
        final result = AviParser.parse(data);

        expect(result!.tracks[0].codec.name, equals('VP8'));
      });

      test('detects VP9 codec', () {
        final data = _createAviWithStreams(streams: [(type: 'vids', handler: 'VP90')]);
        final result = AviParser.parse(data);

        expect(result!.tracks[0].codec.name, equals('VP9'));
      });

      test('handles case-insensitive fourcc', () {
        final data = _createAviWithStreams(streams: [(type: 'vids', handler: 'h264')]);
        final result = AviParser.parse(data);

        expect(result!.tracks[0].codec.name, equals('H.264'));
      });
    });

    group('audio codec detection', () {
      test('detects MP3 audio', () {
        final data = _createAviWithStreams(streams: [(type: 'auds', handler: '\x55\x00\x00\x00')]);
        final result = AviParser.parse(data);

        expect(result!.tracks[0].type, equals(ContainerTrackType.audio));
        // Audio codec detection uses format tag from strf, handler may be generic
      });

      test('extracts audio stream from strf chunk', () {
        final data = _createAviWithAudioFormat(formatTag: 0x0055); // MP3
        final result = AviParser.parse(data);

        expect(result, isNotNull);
        expect(result!.tracks[0].type, equals(ContainerTrackType.audio));
        expect(result.tracks[0].codec.name, equals('MP3'));
      });

      test('extracts AAC audio', () {
        final data = _createAviWithAudioFormat(formatTag: 0x00FF); // AAC
        final result = AviParser.parse(data);

        expect(result!.tracks[0].codec.name, equals('AAC'));
      });

      test('extracts PCM audio', () {
        final data = _createAviWithAudioFormat(formatTag: 0x0001); // PCM
        final result = AviParser.parse(data);

        expect(result!.tracks[0].codec.name, equals('PCM'));
      });

      test('extracts AC-3 audio', () {
        final data = _createAviWithAudioFormat(formatTag: 0x2000); // AC-3
        final result = AviParser.parse(data);

        expect(result!.tracks[0].codec.name, equals('AC-3'));
      });

      test('extracts DTS audio', () {
        final data = _createAviWithAudioFormat(formatTag: 0x2001); // DTS
        final result = AviParser.parse(data);

        expect(result!.tracks[0].codec.name, equals('DTS'));
      });
    });

    group('video info extraction', () {
      test('extracts video dimensions from strf', () {
        final data = _createAviWithVideoFormat(width: 1920, height: 1080);
        final result = AviParser.parse(data);

        expect(result, isNotNull);
        expect(result!.tracks[0].videoInfo?.width, equals(1920));
        expect(result.tracks[0].videoInfo?.height, equals(1080));
      });

      test('extracts frame rate from strh', () {
        final data = _createAviWithVideoFormat(width: 1280, height: 720);
        final result = AviParser.parse(data);

        expect(result, isNotNull);
        expect(result!.tracks[0].videoInfo?.frameRate, closeTo(30.0, 0.01));
      });
    });

    group('audio info extraction', () {
      test('extracts sample rate from strf', () {
        final data = _createAviWithAudioFormat(formatTag: 0x0055);
        final result = AviParser.parse(data);

        expect(result, isNotNull);
        expect(result!.tracks[0].audioInfo?.sampleRate, equals(44100));
      });

      test('extracts channel count from strf', () {
        final data = _createAviWithAudioFormat(formatTag: 0x0055);
        final result = AviParser.parse(data);

        expect(result, isNotNull);
        expect(result!.tracks[0].audioInfo?.channelCount, equals(2));
      });
    });

    group('codec name mapping', () {
      test('maps all known video codecs', () {
        expect(AviParser.mapFourccToCodecName('H264'), equals('H.264'));
        expect(AviParser.mapFourccToCodecName('h264'), equals('H.264'));
        expect(AviParser.mapFourccToCodecName('X264'), equals('H.264'));
        expect(AviParser.mapFourccToCodecName('avc1'), equals('H.264'));
        expect(AviParser.mapFourccToCodecName('HEVC'), equals('HEVC'));
        expect(AviParser.mapFourccToCodecName('XVID'), equals('Xvid'));
        expect(AviParser.mapFourccToCodecName('xvid'), equals('Xvid'));
        expect(AviParser.mapFourccToCodecName('DIVX'), equals('DivX'));
        expect(AviParser.mapFourccToCodecName('DX50'), equals('DivX 5'));
        expect(AviParser.mapFourccToCodecName('MJPG'), equals('Motion JPEG'));
        expect(AviParser.mapFourccToCodecName('VP80'), equals('VP8'));
        expect(AviParser.mapFourccToCodecName('VP90'), equals('VP9'));
      });

      test('maps all known audio format tags', () {
        expect(AviParser.mapAudioFormatTagToCodecName(0x0001), equals('PCM'));
        expect(AviParser.mapAudioFormatTagToCodecName(0x0055), equals('MP3'));
        expect(AviParser.mapAudioFormatTagToCodecName(0x00FF), equals('AAC'));
        expect(AviParser.mapAudioFormatTagToCodecName(0x2000), equals('AC-3'));
        expect(AviParser.mapAudioFormatTagToCodecName(0x2001), equals('DTS'));
        expect(AviParser.mapAudioFormatTagToCodecName(0x0050), equals('MP2'));
        expect(AviParser.mapAudioFormatTagToCodecName(0x0006), equals('A-law'));
        expect(AviParser.mapAudioFormatTagToCodecName(0x0007), equals('mu-law'));
      });

      test('returns fourcc for unknown video codecs', () {
        expect(AviParser.mapFourccToCodecName('UNKN'), equals('UNKN'));
      });

      test('returns Unknown for unknown audio format tags', () {
        expect(AviParser.mapAudioFormatTagToCodecName(0xFFFF), equals('Unknown'));
      });
    });

    group('edge cases', () {
      test('returns null for empty data', () {
        expect(AviParser.parse(Uint8List(0)), isNull);
      });

      test('handles AVI with no streams', () {
        final data = _createAviHeader();
        final result = AviParser.parse(data);
        expect(result, isNotNull);
        expect(result!.tracks, isEmpty);
      });

      test('handles truncated stream list', () {
        final data = _createAviHeader();
        // Truncate to simulate incomplete data
        final truncated = data.sublist(0, data.length - 10);
        final result = AviParser.parse(truncated);
        expect(result, isNotNull);
        expect(result!.format, equals('avi'));
      });

      test('skips unknown chunk types gracefully', () {
        final data = _createAviWithUnknownChunks();
        final result = AviParser.parse(data);
        expect(result, isNotNull);
      });
    });
  });
}

// Test data helpers

/// Creates a minimal AVI header (RIFF + AVI)
Uint8List _createAviHeader() {
  final data = BytesBuilder();

  // RIFF header
  data.add([0x52, 0x49, 0x46, 0x46]); // "RIFF"
  data.add(_uint32Le(1000)); // File size (placeholder)
  data.add([0x41, 0x56, 0x49, 0x20]); // "AVI "

  // hdrl LIST
  data.add([0x4C, 0x49, 0x53, 0x54]); // "LIST"
  data.add(_uint32Le(100)); // Size
  data.add([0x68, 0x64, 0x72, 0x6C]); // "hdrl"

  // avih chunk (main AVI header)
  data.add([0x61, 0x76, 0x69, 0x68]); // "avih"
  data.add(_uint32Le(56)); // Size
  data.add(Uint8List(56)); // Placeholder header data

  return data.toBytes();
}

/// Creates AVI with stream headers
Uint8List _createAviWithStreams({required List<({String type, String handler})> streams}) {
  final data = BytesBuilder();

  // RIFF header
  data.add([0x52, 0x49, 0x46, 0x46]); // "RIFF"
  data.add(_uint32Le(10000)); // File size
  data.add([0x41, 0x56, 0x49, 0x20]); // "AVI "

  // hdrl LIST
  final hdrlContent = BytesBuilder();

  // avih chunk
  hdrlContent.add([0x61, 0x76, 0x69, 0x68]); // "avih"
  hdrlContent.add(_uint32Le(56));
  hdrlContent.add(Uint8List(56));

  // Stream lists
  for (final stream in streams) {
    final strlContent = BytesBuilder();

    // strh chunk (stream header)
    strlContent.add([0x73, 0x74, 0x72, 0x68]); // "strh"
    strlContent.add(_uint32Le(56));

    // fccType (vids, auds, txts, etc.)
    strlContent.add(_fourcc(stream.type));

    // fccHandler (codec fourcc)
    strlContent.add(_fourcc(stream.handler));

    // Rest of strh
    strlContent.add(Uint8List(48));

    // strl LIST
    hdrlContent.add([0x4C, 0x49, 0x53, 0x54]); // "LIST"
    hdrlContent.add(_uint32Le(strlContent.length + 4));
    hdrlContent.add([0x73, 0x74, 0x72, 0x6C]); // "strl"
    hdrlContent.add(strlContent.toBytes());
  }

  // Write hdrl LIST
  data.add([0x4C, 0x49, 0x53, 0x54]); // "LIST"
  data.add(_uint32Le(hdrlContent.length + 4));
  data.add([0x68, 0x64, 0x72, 0x6C]); // "hdrl"
  data.add(hdrlContent.toBytes());

  return data.toBytes();
}

/// Creates AVI with audio format chunk
Uint8List _createAviWithAudioFormat({required int formatTag, int channels = 2, int sampleRate = 44100}) {
  final data = BytesBuilder();

  // RIFF header
  data.add([0x52, 0x49, 0x46, 0x46]); // "RIFF"
  data.add(_uint32Le(10000));
  data.add([0x41, 0x56, 0x49, 0x20]); // "AVI "

  // hdrl LIST
  final hdrlContent = BytesBuilder();

  // avih chunk
  hdrlContent.add([0x61, 0x76, 0x69, 0x68]); // "avih"
  hdrlContent.add(_uint32Le(56));
  hdrlContent.add(Uint8List(56));

  // strl LIST with audio stream
  final strlContent = BytesBuilder();

  // strh chunk
  strlContent.add([0x73, 0x74, 0x72, 0x68]); // "strh"
  strlContent.add(_uint32Le(56));
  strlContent.add([0x61, 0x75, 0x64, 0x73]); // "auds"
  strlContent.add(Uint8List(52)); // Rest of strh

  // strf chunk (WAVEFORMATEX)
  strlContent.add([0x73, 0x74, 0x72, 0x66]); // "strf"
  strlContent.add(_uint32Le(18)); // Size of WAVEFORMATEX

  // WAVEFORMATEX structure
  strlContent.add(_uint16Le(formatTag)); // wFormatTag
  strlContent.add(_uint16Le(channels)); // nChannels
  strlContent.add(_uint32Le(sampleRate)); // nSamplesPerSec
  strlContent.add(_uint32Le(sampleRate * channels * 2)); // nAvgBytesPerSec
  strlContent.add(_uint16Le(channels * 2)); // nBlockAlign
  strlContent.add(_uint16Le(16)); // wBitsPerSample
  strlContent.add(_uint16Le(0)); // cbSize

  // strl LIST
  hdrlContent.add([0x4C, 0x49, 0x53, 0x54]); // "LIST"
  hdrlContent.add(_uint32Le(strlContent.length + 4));
  hdrlContent.add([0x73, 0x74, 0x72, 0x6C]); // "strl"
  hdrlContent.add(strlContent.toBytes());

  // Write hdrl LIST
  data.add([0x4C, 0x49, 0x53, 0x54]); // "LIST"
  data.add(_uint32Le(hdrlContent.length + 4));
  data.add([0x68, 0x64, 0x72, 0x6C]); // "hdrl"
  data.add(hdrlContent.toBytes());

  return data.toBytes();
}

/// Creates AVI with video format chunk
Uint8List _createAviWithVideoFormat({required int width, required int height, double frameRate = 30.0}) {
  final data = BytesBuilder();

  // RIFF header
  data.add([0x52, 0x49, 0x46, 0x46]); // "RIFF"
  data.add(_uint32Le(10000));
  data.add([0x41, 0x56, 0x49, 0x20]); // "AVI "

  // hdrl LIST
  final hdrlContent = BytesBuilder();

  // avih chunk
  hdrlContent.add([0x61, 0x76, 0x69, 0x68]); // "avih"
  hdrlContent.add(_uint32Le(56));
  hdrlContent.add(Uint8List(56));

  // strl LIST with video stream
  final strlContent = BytesBuilder();

  // strh chunk
  strlContent.add([0x73, 0x74, 0x72, 0x68]); // "strh"
  strlContent.add(_uint32Le(56));
  strlContent.add([0x76, 0x69, 0x64, 0x73]); // "vids"
  strlContent.add([0x48, 0x32, 0x36, 0x34]); // "H264"

  // strh fields
  strlContent.add(_uint32Le(0)); // dwFlags
  strlContent.add(_uint16Le(0)); // wPriority
  strlContent.add(_uint16Le(0)); // wLanguage
  strlContent.add(_uint32Le(0)); // dwInitialFrames
  strlContent.add(_uint32Le(1)); // dwScale
  strlContent.add(_uint32Le(frameRate.round())); // dwRate
  strlContent.add(_uint32Le(0)); // dwStart
  strlContent.add(_uint32Le(0)); // dwLength
  strlContent.add(_uint32Le(0)); // dwSuggestedBufferSize
  strlContent.add(_uint32Le(0)); // dwQuality
  strlContent.add(_uint32Le(0)); // dwSampleSize
  strlContent.add(_uint16Le(0)); // rcFrame.left
  strlContent.add(_uint16Le(0)); // rcFrame.top
  strlContent.add(_uint16Le(width)); // rcFrame.right
  strlContent.add(_uint16Le(height)); // rcFrame.bottom

  // strf chunk (BITMAPINFOHEADER)
  strlContent.add([0x73, 0x74, 0x72, 0x66]); // "strf"
  strlContent.add(_uint32Le(40)); // Size of BITMAPINFOHEADER

  // BITMAPINFOHEADER structure
  strlContent.add(_uint32Le(40)); // biSize
  strlContent.add(_int32Le(width)); // biWidth
  strlContent.add(_int32Le(height)); // biHeight
  strlContent.add(_uint16Le(1)); // biPlanes
  strlContent.add(_uint16Le(24)); // biBitCount
  strlContent.add([0x48, 0x32, 0x36, 0x34]); // biCompression (H264)
  strlContent.add(_uint32Le(width * height * 3)); // biSizeImage
  strlContent.add(_uint32Le(0)); // biXPelsPerMeter
  strlContent.add(_uint32Le(0)); // biYPelsPerMeter
  strlContent.add(_uint32Le(0)); // biClrUsed
  strlContent.add(_uint32Le(0)); // biClrImportant

  // strl LIST
  hdrlContent.add([0x4C, 0x49, 0x53, 0x54]); // "LIST"
  hdrlContent.add(_uint32Le(strlContent.length + 4));
  hdrlContent.add([0x73, 0x74, 0x72, 0x6C]); // "strl"
  hdrlContent.add(strlContent.toBytes());

  // Write hdrl LIST
  data.add([0x4C, 0x49, 0x53, 0x54]); // "LIST"
  data.add(_uint32Le(hdrlContent.length + 4));
  data.add([0x68, 0x64, 0x72, 0x6C]); // "hdrl"
  data.add(hdrlContent.toBytes());

  return data.toBytes();
}

/// Creates AVI with unknown chunks to test graceful skipping
Uint8List _createAviWithUnknownChunks() {
  final data = BytesBuilder();

  // RIFF header
  data.add([0x52, 0x49, 0x46, 0x46]); // "RIFF"
  data.add(_uint32Le(1000));
  data.add([0x41, 0x56, 0x49, 0x20]); // "AVI "

  // Unknown chunk
  data.add([0x75, 0x6E, 0x6B, 0x6E]); // "unkn"
  data.add(_uint32Le(8));
  data.add(Uint8List(8));

  // hdrl LIST
  data.add([0x4C, 0x49, 0x53, 0x54]); // "LIST"
  data.add(_uint32Le(68));
  data.add([0x68, 0x64, 0x72, 0x6C]); // "hdrl"

  // avih chunk
  data.add([0x61, 0x76, 0x69, 0x68]); // "avih"
  data.add(_uint32Le(56));
  data.add(Uint8List(56));

  return data.toBytes();
}

// Helper functions for little-endian encoding

Uint8List _uint16Le(int value) {
  final bytes = Uint8List(2);
  bytes[0] = value & 0xFF;
  bytes[1] = (value >> 8) & 0xFF;
  return bytes;
}

Uint8List _uint32Le(int value) {
  final bytes = Uint8List(4);
  bytes[0] = value & 0xFF;
  bytes[1] = (value >> 8) & 0xFF;
  bytes[2] = (value >> 16) & 0xFF;
  bytes[3] = (value >> 24) & 0xFF;
  return bytes;
}

Uint8List _int32Le(int value) => _uint32Le(value);

Uint8List _fourcc(String fourcc) {
  final bytes = Uint8List(4);
  for (var i = 0; i < 4 && i < fourcc.length; i++) {
    bytes[i] = fourcc.codeUnitAt(i);
  }
  return bytes;
}
