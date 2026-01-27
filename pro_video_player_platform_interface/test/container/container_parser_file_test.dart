@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/src/container/container_parser.dart';

/// Tests for file-based container parsing via RandomAccessFile.
void main() {
  late String projectRoot;
  late File sampleMp4;
  late File sampleWithChapters;

  setUpAll(() {
    projectRoot = _findProjectRoot();
    sampleMp4 = File('$projectRoot/example-showcase/assets/videos/sample.mp4');
    sampleWithChapters = File('$projectRoot/example-showcase/assets/videos/sample_with_chapters.mp4');
  });

  group('ContainerParser.parseFilePath', () {
    test('parses file from path', () async {
      if (!sampleMp4.existsSync()) {
        markTestSkipped('sample.mp4 not found');
        return;
      }

      final metadata = await ContainerParser.parseFilePath(sampleMp4.path);

      expect(metadata, isNotNull);
      expect(metadata!.format, isNotEmpty);
      expect(metadata.duration.inMilliseconds, greaterThan(0));
    });

    test('returns null for non-existent file', () async {
      final metadata = await ContainerParser.parseFilePath('/non/existent/path.mp4');
      expect(metadata, isNull);
    });

    test('extracts same data as parseFile', () async {
      if (!sampleWithChapters.existsSync()) {
        markTestSkipped('sample_with_chapters.mp4 not found');
        return;
      }

      final pathMetadata = await ContainerParser.parseFilePath(sampleWithChapters.path);
      final file = await sampleWithChapters.open();
      try {
        final fileMetadata = await ContainerParser.parseFile(file);

        expect(pathMetadata, isNotNull);
        expect(fileMetadata, isNotNull);
        expect(pathMetadata!.format, equals(fileMetadata!.format));
        expect(pathMetadata.duration, equals(fileMetadata.duration));
        expect(pathMetadata.tracks.length, equals(fileMetadata.tracks.length));
      } finally {
        await file.close();
      }
    });
  });

  group('ContainerParser.parseFile', () {
    group('sample.mp4', () {
      test('parses metadata via RandomAccessFile', () async {
        if (!sampleMp4.existsSync()) {
          markTestSkipped('sample.mp4 not found');
          return;
        }

        final file = await sampleMp4.open();
        try {
          final metadata = await ContainerParser.parseFile(file);

          expect(metadata, isNotNull, reason: 'Failed to parse sample.mp4');
          expect(metadata!.format, isNotEmpty);
          expect(metadata.duration.inMilliseconds, greaterThan(0));
          expect(metadata.videoTracks, isNotEmpty);
        } finally {
          await file.close();
        }
      });

      test('extracts same data as bytes-based parse', () async {
        if (!sampleMp4.existsSync()) {
          markTestSkipped('sample.mp4 not found');
          return;
        }

        // Parse with bytes
        final bytes = await sampleMp4.readAsBytes();
        final bytesMetadata = ContainerParser.parse(bytes);

        // Parse with file
        final file = await sampleMp4.open();
        try {
          final fileMetadata = await ContainerParser.parseFile(file);

          expect(bytesMetadata, isNotNull);
          expect(fileMetadata, isNotNull);

          // Should produce identical results
          expect(fileMetadata!.format, equals(bytesMetadata!.format));
          expect(fileMetadata.duration, equals(bytesMetadata.duration));
          expect(fileMetadata.tracks.length, equals(bytesMetadata.tracks.length));
          expect(fileMetadata.compatibleBrands, equals(bytesMetadata.compatibleBrands));

          // Check track details
          for (var i = 0; i < fileMetadata.tracks.length; i++) {
            final fileTrack = fileMetadata.tracks[i];
            final bytesTrack = bytesMetadata.tracks[i];

            expect(fileTrack.id, equals(bytesTrack.id));
            expect(fileTrack.type, equals(bytesTrack.type));
            expect(fileTrack.codec.fourcc, equals(bytesTrack.codec.fourcc));
            expect(fileTrack.codec.name, equals(bytesTrack.codec.name));
          }
        } finally {
          await file.close();
        }
      });
    });

    group('sample_with_chapters.mp4', () {
      test('parses multi-track file', () async {
        if (!sampleWithChapters.existsSync()) {
          markTestSkipped('sample_with_chapters.mp4 not found');
          return;
        }

        final file = await sampleWithChapters.open();
        try {
          final metadata = await ContainerParser.parseFile(file);

          expect(metadata, isNotNull);
          expect(metadata!.videoTracks, isNotEmpty);
          expect(metadata.audioTracks, isNotEmpty);

          final video = metadata.primaryVideoTrack;
          expect(video, isNotNull);
          expect(video!.codec.fourcc, equals('avc1'));
          expect(video.videoInfo?.width, equals(480));
          expect(video.videoInfo?.height, equals(270));

          final audio = metadata.primaryAudioTrack;
          expect(audio, isNotNull);
          expect(audio!.codec.fourcc, equals('mp4a'));
        } finally {
          await file.close();
        }
      });
    });

    group('detectFormatFile', () {
      test('detects format from file', () async {
        if (!sampleMp4.existsSync()) {
          markTestSkipped('sample.mp4 not found');
          return;
        }

        final file = await sampleMp4.open();
        try {
          final format = await ContainerParser.detectFormatFile(file);
          expect(format, isNotNull);
          expect(['mp4', 'mov', 'm4v'].contains(format), isTrue);
        } finally {
          await file.close();
        }
      });
    });

    group('error handling', () {
      test('returns null for empty file', () async {
        final tempFile = File('${Directory.systemTemp.path}/empty_test.mp4');
        await tempFile.writeAsBytes([]);
        try {
          final file = await tempFile.open();
          try {
            final metadata = await ContainerParser.parseFile(file);
            expect(metadata, isNull);
          } finally {
            await file.close();
          }
        } finally {
          await tempFile.delete();
        }
      });

      test('returns null for file too small for box header', () async {
        final tempFile = File('${Directory.systemTemp.path}/small_test.mp4');
        await tempFile.writeAsBytes([0, 0, 0]); // Only 3 bytes
        try {
          final file = await tempFile.open();
          try {
            final metadata = await ContainerParser.parseFile(file);
            expect(metadata, isNull);
          } finally {
            await file.close();
          }
        } finally {
          await tempFile.delete();
        }
      });

      test('returns null for non-MP4 file', () async {
        final tempFile = File('${Directory.systemTemp.path}/not_mp4.txt');
        await tempFile.writeAsBytes(List.filled(100, 0x41)); // 'A' characters
        try {
          final file = await tempFile.open();
          try {
            final metadata = await ContainerParser.parseFile(file);
            expect(metadata, isNull);
          } finally {
            await file.close();
          }
        } finally {
          await tempFile.delete();
        }
      });
    });

    group('moov-at-end handling', () {
      test('parses file with moov at end', () async {
        // Create a test file with moov after mdat
        // This simulates a non-fast-start MP4
        final tempFile = await _createMoovAtEndTestFile();
        try {
          final file = await tempFile.open();
          try {
            final metadata = await ContainerParser.parseFile(file);
            expect(metadata, isNotNull, reason: 'Should parse moov-at-end file');
            expect(metadata!.format, isNotNull);
          } finally {
            await file.close();
          }
        } finally {
          await tempFile.delete();
        }
      });
    });
  });
}

/// Finds the project root directory by looking for CLAUDE.md.
String _findProjectRoot() {
  var dir = Directory.current;

  while (dir.path != dir.parent.path) {
    if (File('${dir.path}/CLAUDE.md').existsSync()) {
      return dir.path;
    }
    dir = dir.parent;
  }

  return '../../..';
}

/// Creates a minimal test MP4 file with moov box after mdat.
Future<File> _createMoovAtEndTestFile() async {
  final tempFile = File('${Directory.systemTemp.path}/moov_at_end_test.mp4');

  // Build ftyp box
  final ftyp = _buildFtypBox();

  // Build a fake mdat box (just empty data)
  final mdat = _buildMdatBox(1000);

  // Build minimal moov box
  final moov = _buildMinimalMoovBox();

  // Write in order: ftyp, mdat, moov (moov at end)
  final bytes = <int>[...ftyp, ...mdat, ...moov];
  await tempFile.writeAsBytes(bytes);

  return tempFile;
}

/// Builds a minimal ftyp box.
List<int> _buildFtypBox() {
  final box = <int>[];

  // Size placeholder
  box.addAll([0, 0, 0, 0]);

  // Type: ftyp
  box.addAll('ftyp'.codeUnits);

  // Major brand: mp42
  box.addAll('mp42'.codeUnits);

  // Minor version: 0
  box.addAll([0, 0, 0, 0]);

  // Compatible brands: mp42, isom
  box.addAll('mp42'.codeUnits);
  box.addAll('isom'.codeUnits);

  // Update size
  final size = box.length;
  box[0] = (size >> 24) & 0xFF;
  box[1] = (size >> 16) & 0xFF;
  box[2] = (size >> 8) & 0xFF;
  box[3] = size & 0xFF;

  return box;
}

/// Builds a fake mdat box with specified data size.
List<int> _buildMdatBox(int dataSize) {
  final box = <int>[];

  final totalSize = 8 + dataSize;
  box.addAll([(totalSize >> 24) & 0xFF, (totalSize >> 16) & 0xFF, (totalSize >> 8) & 0xFF, totalSize & 0xFF]);

  // Type: mdat
  box.addAll('mdat'.codeUnits);

  // Fill with zeros
  box.addAll(List.filled(dataSize, 0));

  return box;
}

/// Builds a minimal moov box with mvhd only (no tracks for simplicity).
List<int> _buildMinimalMoovBox() {
  // Build mvhd first
  final mvhd = _buildMvhdBox();

  final box = <int>[];

  final moovSize = 8 + mvhd.length;
  box.addAll([(moovSize >> 24) & 0xFF, (moovSize >> 16) & 0xFF, (moovSize >> 8) & 0xFF, moovSize & 0xFF]);

  // Type: moov
  box.addAll('moov'.codeUnits);

  // Children
  box.addAll(mvhd);

  return box;
}

/// Builds a minimal mvhd box (version 0).
List<int> _buildMvhdBox() {
  final box = <int>[];

  // Size placeholder
  box.addAll([0, 0, 0, 0]);

  // Type: mvhd
  box.addAll('mvhd'.codeUnits);

  // Version and flags
  box.addAll([0, 0, 0, 0]);

  // Creation time (4 bytes)
  box.addAll([0, 0, 0, 0]);

  // Modification time (4 bytes)
  box.addAll([0, 0, 0, 0]);

  // Timescale (1000)
  box.addAll([0, 0, 0x03, 0xE8]);

  // Duration (5000 = 5 seconds)
  box.addAll([0, 0, 0x13, 0x88]);

  // Preferred rate (1.0 as 16.16)
  box.addAll([0, 1, 0, 0]);

  // Preferred volume (1.0 as 8.8)
  box.addAll([1, 0]);

  // Reserved (10 bytes)
  box.addAll(List.filled(10, 0));

  // Matrix (36 bytes - identity)
  box.addAll([0, 1, 0, 0]); // a = 1.0
  box.addAll([0, 0, 0, 0]); // b = 0
  box.addAll([0, 0, 0, 0]); // u = 0
  box.addAll([0, 0, 0, 0]); // c = 0
  box.addAll([0, 1, 0, 0]); // d = 1.0
  box.addAll([0, 0, 0, 0]); // v = 0
  box.addAll([0, 0, 0, 0]); // tx = 0
  box.addAll([0, 0, 0, 0]); // ty = 0
  box.addAll([0x40, 0, 0, 0]); // w = 1.0 (2.30)

  // Preview time
  box.addAll([0, 0, 0, 0]);

  // Preview duration
  box.addAll([0, 0, 0, 0]);

  // Poster time
  box.addAll([0, 0, 0, 0]);

  // Selection time
  box.addAll([0, 0, 0, 0]);

  // Selection duration
  box.addAll([0, 0, 0, 0]);

  // Current time
  box.addAll([0, 0, 0, 0]);

  // Next track ID
  box.addAll([0, 0, 0, 1]);

  // Update size
  final size = box.length;
  box[0] = (size >> 24) & 0xFF;
  box[1] = (size >> 16) & 0xFF;
  box[2] = (size >> 8) & 0xFF;
  box[3] = size & 0xFF;

  return box;
}
