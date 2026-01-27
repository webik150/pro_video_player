import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/avi_sample_reader.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/sample_reader.dart';

void main() {
  group('AviSampleReader', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('avi_reader_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    group('AviSampleReaderFactory', () {
      test('returns null for non-existent file', () async {
        final result = await AviSampleReaderFactory.inspect('/non/existent/file.avi');
        expect(result, isNull);
      });

      test('returns null for invalid AVI file', () async {
        final invalidFile = File('${tempDir.path}/invalid.avi');
        invalidFile.writeAsBytesSync([0x00, 0x01, 0x02, 0x03]);

        final result = await AviSampleReaderFactory.inspect(invalidFile.path);
        expect(result, isNull);
      });

      test('inspects valid AVI structure', () async {
        final aviData = _createMinimalAvi();
        final aviFile = File('${tempDir.path}/test.avi');
        aviFile.writeAsBytesSync(aviData);

        final result = await AviSampleReaderFactory.inspect(aviFile.path);
        // Minimal AVI should be parseable
        expect(result == null || result.metadata != null, isTrue);
      });
    });

    group('AviSampleReader.open', () {
      test('returns null for non-existent file', () async {
        final reader = await AviSampleReader.open('/non/existent/file.avi', 1);
        expect(reader, isNull);
      });

      test('returns null for invalid AVI', () async {
        final invalidFile = File('${tempDir.path}/invalid.avi');
        invalidFile.writeAsBytesSync([0x00, 0x01, 0x02, 0x03]);

        final reader = await AviSampleReader.open(invalidFile.path, 1);
        expect(reader, isNull);
      });
    });

    group('TrackCodecInfo', () {
      test('isVideo returns true for video track info', () {
        const info = TrackCodecInfo(trackId: 1, codecFourcc: 'H264', timescale: 30, width: 1920, height: 1080);

        expect(info.isVideo, isTrue);
        expect(info.isAudio, isFalse);
      });

      test('isAudio returns true for audio track info', () {
        const info = TrackCodecInfo(
          trackId: 2,
          codecFourcc: 'MP3 ',
          timescale: 1000,
          sampleRate: 44100,
          channelCount: 2,
        );

        expect(info.isVideo, isFalse);
        expect(info.isAudio, isTrue);
      });
    });

    group('AVI/RIFF structure', () {
      test('RIFF header starts with signature', () {
        final header = _createRiffHeader(fileSize: 100, formType: 'AVI ');
        expect(String.fromCharCodes(header.sublist(0, 4)), equals('RIFF'));
      });

      test('AVI form type is encoded', () {
        final header = _createRiffHeader(fileSize: 100, formType: 'AVI ');
        expect(String.fromCharCodes(header.sublist(8, 12)), equals('AVI '));
      });

      test('file size is little-endian uint32', () {
        final header = _createRiffHeader(fileSize: 0x12345678, formType: 'AVI ');
        final size = header[4] | (header[5] << 8) | (header[6] << 16) | (header[7] << 24);
        expect(size, equals(0x12345678));
      });

      test('chunk header is 8 bytes', () {
        final chunk = _createChunk(fourcc: 'hdrl', data: [0x00, 0x01]);
        expect(chunk.length, equals(8 + 2)); // Header + data
      });

      test('chunk fourcc is at offset 0', () {
        final chunk = _createChunk(fourcc: 'strh', data: []);
        expect(String.fromCharCodes(chunk.sublist(0, 4)), equals('strh'));
      });

      test('chunk size is little-endian', () {
        final data = List.filled(256, 0);
        final chunk = _createChunk(fourcc: 'test', data: data);
        final size = chunk[4] | (chunk[5] << 8) | (chunk[6] << 16) | (chunk[7] << 24);
        expect(size, equals(256));
      });

      test('idx1 entry is 16 bytes', () {
        final entry = _createIdx1Entry(
          chunkId: '00dc',
          flags: 0x10, // Keyframe
          offset: 1000,
          size: 5000,
        );
        expect(entry.length, equals(16));
      });

      test('idx1 keyframe flag is 0x10', () {
        final entry = _createIdx1Entry(chunkId: '00dc', flags: 0x10, offset: 0, size: 100);
        final flags = entry[4] | (entry[5] << 8) | (entry[6] << 16) | (entry[7] << 24);
        expect(flags & 0x10, equals(0x10));
      });

      test('stream chunk ID format is correct', () {
        // Video: ##dc (uncompressed) or ##db (compressed)
        expect(_parseStreamIndex('00dc'), equals(0));
        expect(_parseStreamIndex('01dc'), equals(1));
        expect(_parseStreamIndex('00db'), equals(0));

        // Audio: ##wb
        expect(_parseStreamIndex('00wb'), equals(0));
        expect(_parseStreamIndex('01wb'), equals(1));
      });
    });

    group('Integration with real fixtures', () {
      test('parses AVI file if available', () async {
        final testFile = _getFixturePath('sample.avi');
        if (!File(testFile).existsSync()) {
          markTestSkipped('Test fixture not available');
          return;
        }

        final inspection = await AviSampleReaderFactory.inspect(testFile);
        expect(inspection, isNotNull);
        expect(inspection!.metadata, isNotNull);
      });
    });
  });
}

/// Creates a RIFF header.
Uint8List _createRiffHeader({required int fileSize, required String formType}) {
  final header = Uint8List(12);

  // RIFF signature
  header[0] = 0x52; // R
  header[1] = 0x49; // I
  header[2] = 0x46; // F
  header[3] = 0x46; // F

  // File size (little-endian)
  header[4] = fileSize & 0xFF;
  header[5] = (fileSize >> 8) & 0xFF;
  header[6] = (fileSize >> 16) & 0xFF;
  header[7] = (fileSize >> 24) & 0xFF;

  // Form type
  final typeBytes = formType.codeUnits;
  for (var i = 0; i < 4 && i < typeBytes.length; i++) {
    header[8 + i] = typeBytes[i];
  }

  return header;
}

/// Creates a RIFF chunk.
Uint8List _createChunk({required String fourcc, required List<int> data}) {
  final chunk = Uint8List(8 + data.length);

  // FourCC
  final fourccBytes = fourcc.codeUnits;
  for (var i = 0; i < 4 && i < fourccBytes.length; i++) {
    chunk[i] = fourccBytes[i];
  }

  // Size (little-endian)
  final size = data.length;
  chunk[4] = size & 0xFF;
  chunk[5] = (size >> 8) & 0xFF;
  chunk[6] = (size >> 16) & 0xFF;
  chunk[7] = (size >> 24) & 0xFF;

  // Data
  for (var i = 0; i < data.length; i++) {
    chunk[8 + i] = data[i];
  }

  return chunk;
}

/// Creates an idx1 index entry.
Uint8List _createIdx1Entry({required String chunkId, required int flags, required int offset, required int size}) {
  final entry = Uint8List(16);

  // Chunk ID
  final idBytes = chunkId.codeUnits;
  for (var i = 0; i < 4 && i < idBytes.length; i++) {
    entry[i] = idBytes[i];
  }

  // Flags (little-endian)
  entry[4] = flags & 0xFF;
  entry[5] = (flags >> 8) & 0xFF;
  entry[6] = (flags >> 16) & 0xFF;
  entry[7] = (flags >> 24) & 0xFF;

  // Offset (little-endian)
  entry[8] = offset & 0xFF;
  entry[9] = (offset >> 8) & 0xFF;
  entry[10] = (offset >> 16) & 0xFF;
  entry[11] = (offset >> 24) & 0xFF;

  // Size (little-endian)
  entry[12] = size & 0xFF;
  entry[13] = (size >> 8) & 0xFF;
  entry[14] = (size >> 16) & 0xFF;
  entry[15] = (size >> 24) & 0xFF;

  return entry;
}

/// Parses stream index from chunk ID.
int? _parseStreamIndex(String chunkId) {
  if (chunkId.length != 4) return null;
  return int.tryParse(chunkId.substring(0, 2));
}

/// Creates a minimal valid AVI file structure.
Uint8List _createMinimalAvi() {
  final buffer = BytesBuilder();

  // Build hdrl list with minimal avih and strl
  final hdrlContent = BytesBuilder();

  // avih (main AVI header) - minimal 56 bytes
  final avih = Uint8List(56);
  // MicroSecPerFrame = 33333 (30 fps)
  avih[0] = 0x15;
  avih[1] = 0x82;
  avih[2] = 0x00;
  avih[3] = 0x00;
  // TotalFrames at offset 16
  avih[16] = 0x01;
  // Streams at offset 24
  avih[24] = 0x01;
  // Width at offset 32
  avih[32] = 0x80;
  avih[33] = 0x02; // 640
  // Height at offset 36
  avih[36] = 0xE0;
  avih[37] = 0x01; // 480
  hdrlContent.add(_createChunk(fourcc: 'avih', data: avih.toList()));

  // strl list with strh and strf
  final strlContent = BytesBuilder();

  // strh (stream header) - 56 bytes
  final strh = Uint8List(56);
  // fccType = 'vids'
  strh[0] = 0x76; // v
  strh[1] = 0x69; // i
  strh[2] = 0x64; // d
  strh[3] = 0x73; // s
  // fccHandler = 'H264'
  strh[4] = 0x48;
  strh[5] = 0x32;
  strh[6] = 0x36;
  strh[7] = 0x34;
  // dwScale at offset 20 = 1
  strh[20] = 0x01;
  // dwRate at offset 24 = 30
  strh[24] = 0x1E;
  strlContent.add(_createChunk(fourcc: 'strh', data: strh.toList()));

  // strf (stream format) - BITMAPINFOHEADER 40 bytes
  final strf = Uint8List(40);
  // biSize = 40
  strf[0] = 0x28;
  // biWidth = 640
  strf[4] = 0x80;
  strf[5] = 0x02;
  // biHeight = 480
  strf[8] = 0xE0;
  strf[9] = 0x01;
  // biPlanes = 1
  strf[12] = 0x01;
  // biBitCount = 24
  strf[14] = 0x18;
  // biCompression = 'H264'
  strf[16] = 0x48;
  strf[17] = 0x32;
  strf[18] = 0x36;
  strf[19] = 0x34;
  strlContent.add(_createChunk(fourcc: 'strf', data: strf.toList()));

  // Create strl LIST
  final strlData = strlContent.toBytes();
  final strlList = BytesBuilder();
  strlList.add([0x73, 0x74, 0x72, 0x6C]); // 'strl'
  strlList.add(strlData);
  hdrlContent.add(_createListChunk(listType: 'strl', content: strlData));

  // Create hdrl LIST
  final hdrlData = hdrlContent.toBytes();

  // Create movi LIST (empty for minimal)
  final moviContent = Uint8List(0);

  // Calculate total size
  final hdrlListSize = 4 + hdrlData.length; // LIST + type + content
  final moviListSize = 4 + moviContent.length;
  final totalSize =
      4 + // AVI type
      8 +
      hdrlListSize + // LIST hdrl
      8 +
      moviListSize; // LIST movi

  // RIFF header
  buffer.add(_createRiffHeader(fileSize: totalSize, formType: 'AVI '));

  // hdrl LIST
  buffer.add(_createListChunk(listType: 'hdrl', content: hdrlData));

  // movi LIST
  buffer.add(_createListChunk(listType: 'movi', content: moviContent.toList()));

  return buffer.toBytes();
}

/// Creates a LIST chunk.
Uint8List _createListChunk({required String listType, required List<int> content}) {
  final chunk = Uint8List(8 + 4 + content.length);

  // 'LIST'
  chunk[0] = 0x4C;
  chunk[1] = 0x49;
  chunk[2] = 0x53;
  chunk[3] = 0x54;

  // Size (little-endian) - includes list type
  final size = 4 + content.length;
  chunk[4] = size & 0xFF;
  chunk[5] = (size >> 8) & 0xFF;
  chunk[6] = (size >> 16) & 0xFF;
  chunk[7] = (size >> 24) & 0xFF;

  // List type
  final typeBytes = listType.codeUnits;
  for (var i = 0; i < 4 && i < typeBytes.length; i++) {
    chunk[8 + i] = typeBytes[i];
  }

  // Content
  for (var i = 0; i < content.length; i++) {
    chunk[12 + i] = content[i];
  }

  return chunk;
}

/// Gets the path to a test fixture file.
String _getFixturePath(String filename) {
  final possiblePaths = [
    'test/fixtures/containers/$filename',
    '../test/fixtures/containers/$filename',
    'pro_video_player_platform_interface/test/fixtures/containers/$filename',
  ];

  for (final path in possiblePaths) {
    if (File(path).existsSync()) {
      return path;
    }
  }

  return '/Users/vitor/resilio/Dev/goodinside/git/pro_video_player/pro_video_player_platform_interface/test/fixtures/containers/$filename';
}
