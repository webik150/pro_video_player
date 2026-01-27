import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/src/container/container_parser.dart';

void main() {
  group('ContainerParser', () {
    group('detectFormat', () {
      test('detects mp4 format from ftyp box', () {
        final data = _buildFtypBox('mp42', ['isom', 'mp41', 'mp42']);

        expect(ContainerParser.detectFormat(data), equals('mp4'));
      });

      test('detects mov format from qt brand', () {
        final data = _buildFtypBox('qt  ', ['qt  ']);

        expect(ContainerParser.detectFormat(data), equals('mov'));
      });

      test('detects m4a format from M4A brand', () {
        final data = _buildFtypBox('M4A ', ['isom', 'M4A ']);

        expect(ContainerParser.detectFormat(data), equals('m4a'));
      });

      test('detects m4v format from M4V brand', () {
        final data = _buildFtypBox('M4V ', ['isom', 'M4V ']);

        expect(ContainerParser.detectFormat(data), equals('m4v'));
      });

      test('detects 3gp format from 3gp brand', () {
        final data = _buildFtypBox('3gp4', ['isom', '3gp4']);

        expect(ContainerParser.detectFormat(data), equals('3gp'));
      });

      test('detects generic isom as mp4', () {
        final data = _buildFtypBox('isom', ['isom', 'iso2']);

        expect(ContainerParser.detectFormat(data), equals('mp4'));
      });

      test('returns null for empty data', () {
        final data = Uint8List(0);

        expect(ContainerParser.detectFormat(data), isNull);
      });

      test('returns null for non-mp4 data', () {
        final data = Uint8List.fromList([0x1A, 0x45, 0xDF, 0xA3]); // MKV EBML header

        expect(ContainerParser.detectFormat(data), isNull);
      });

      test('returns null when first box is not ftyp', () {
        final data = _buildBox('moov', 100);

        expect(ContainerParser.detectFormat(data), isNull);
      });
    });

    group('parse', () {
      test('returns null for empty data', () {
        final data = Uint8List(0);

        expect(ContainerParser.parse(data), isNull);
      });

      test('returns null for non-mp4 data', () {
        final data = Uint8List.fromList([0x1A, 0x45, 0xDF, 0xA3]); // MKV header

        expect(ContainerParser.parse(data), isNull);
      });

      test('parses minimal mp4 with ftyp and moov', () {
        final data = _buildMinimalMp4();

        final metadata = ContainerParser.parse(data);

        expect(metadata, isNotNull);
        expect(metadata!.format, equals('mp4'));
      });

      test('extracts duration from mvhd', () {
        final data = _buildMp4WithMvhd(timescale: 1000, duration: 5000);

        final metadata = ContainerParser.parse(data);

        expect(metadata, isNotNull);
        expect(metadata!.duration, equals(const Duration(seconds: 5)));
      });

      test('extracts timescale from mvhd', () {
        final data = _buildMp4WithMvhd(timescale: 90000, duration: 900000);

        final metadata = ContainerParser.parse(data);

        expect(metadata, isNotNull);
        expect(metadata!.timescale, equals(90000));
        expect(metadata.duration, equals(const Duration(seconds: 10)));
      });

      test('handles version 1 mvhd (64-bit values)', () {
        final data = _buildMp4WithMvhdV1(timescale: 1000, duration: 60000);

        final metadata = ContainerParser.parse(data);

        expect(metadata, isNotNull);
        expect(metadata!.duration, equals(const Duration(seconds: 60)));
      });

      test('extracts compatible brands', () {
        final data = _buildFtypWithMoov('mp42', ['isom', 'mp41', 'mp42', 'avc1']);

        final metadata = ContainerParser.parse(data);

        expect(metadata, isNotNull);
        expect(metadata!.compatibleBrands, containsAll(['isom', 'mp41', 'mp42', 'avc1']));
      });
    });

    group('isSupportedFormat', () {
      test('returns true for mp4 files', () {
        final data = _buildFtypBox('mp42', ['isom']);

        expect(ContainerParser.isSupportedFormat(data), isTrue);
      });

      test('returns true for mov files', () {
        final data = _buildFtypBox('qt  ', ['qt  ']);

        expect(ContainerParser.isSupportedFormat(data), isTrue);
      });

      test('returns false for unknown formats', () {
        final data = Uint8List.fromList([0x1A, 0x45, 0xDF, 0xA3]); // MKV

        expect(ContainerParser.isSupportedFormat(data), isFalse);
      });
    });
  });
}

/// Builds an ftyp box with major brand and compatible brands.
Uint8List _buildFtypBox(String majorBrand, List<String> compatibleBrands) {
  // ftyp box: size (4) + 'ftyp' (4) + major_brand (4) + minor_version (4) + compatible_brands
  final brandCount = compatibleBrands.length;
  final size = 8 + 4 + 4 + (brandCount * 4); // header + major + minor + brands

  final data = Uint8List(size);
  final view = ByteData.view(data.buffer);

  // Size
  view.setUint32(0, size);
  // Type 'ftyp'
  data.setRange(4, 8, 'ftyp'.codeUnits);
  // Major brand
  data.setRange(8, 12, majorBrand.codeUnits);
  // Minor version (0)
  view.setUint32(12, 0);
  // Compatible brands
  for (var i = 0; i < brandCount; i++) {
    data.setRange(16 + i * 4, 16 + i * 4 + 4, compatibleBrands[i].codeUnits);
  }

  return data;
}

/// Builds a generic box with the given type and data size.
Uint8List _buildBox(String type, int dataSize) {
  final totalSize = 8 + dataSize;
  final data = Uint8List(totalSize);
  final view = ByteData.view(data.buffer);

  view.setUint32(0, totalSize);
  data.setRange(4, 8, type.codeUnits);

  return data;
}

/// Builds a minimal MP4 with ftyp and empty moov.
Uint8List _buildMinimalMp4() {
  final ftyp = _buildFtypBox('mp42', ['isom', 'mp42']);
  final mvhd = _buildMvhd(timescale: 1000, duration: 0);
  final moov = _buildBoxWithContent('moov', mvhd);

  return Uint8List.fromList([...ftyp, ...moov]);
}

/// Builds an MP4 with mvhd containing specified timescale and duration.
Uint8List _buildMp4WithMvhd({required int timescale, required int duration}) {
  final ftyp = _buildFtypBox('mp42', ['isom', 'mp42']);
  final mvhd = _buildMvhd(timescale: timescale, duration: duration);
  final moov = _buildBoxWithContent('moov', mvhd);

  return Uint8List.fromList([...ftyp, ...moov]);
}

/// Builds an MP4 with version 1 mvhd (64-bit duration).
Uint8List _buildMp4WithMvhdV1({required int timescale, required int duration}) {
  final ftyp = _buildFtypBox('mp42', ['isom', 'mp42']);
  final mvhd = _buildMvhdV1(timescale: timescale, duration: duration);
  final moov = _buildBoxWithContent('moov', mvhd);

  return Uint8List.fromList([...ftyp, ...moov]);
}

/// Builds ftyp + moov with mvhd.
Uint8List _buildFtypWithMoov(String majorBrand, List<String> compatibleBrands) {
  final ftyp = _buildFtypBox(majorBrand, compatibleBrands);
  final mvhd = _buildMvhd(timescale: 1000, duration: 0);
  final moov = _buildBoxWithContent('moov', mvhd);

  return Uint8List.fromList([...ftyp, ...moov]);
}

/// Builds mvhd box (version 0, 32-bit values).
Uint8List _buildMvhd({required int timescale, required int duration}) {
  // mvhd v0: fullbox header (12) + creation_time (4) + modification_time (4) +
  //          timescale (4) + duration (4) + rest (76) = 108 total
  const size = 108;
  final data = Uint8List(size);
  final view = ByteData.view(data.buffer);

  // Box header
  view.setUint32(0, size);
  data.setRange(4, 8, 'mvhd'.codeUnits);

  // FullBox: version (0) + flags (0)
  view.setUint32(8, 0);

  // creation_time, modification_time
  view.setUint32(12, 0);
  view.setUint32(16, 0);

  // timescale
  view.setUint32(20, timescale);

  // duration
  view.setUint32(24, duration);

  // rate (16.16) = 1.0
  view.setUint32(28, 0x00010000);

  // volume (8.8) = 1.0
  view.setUint16(32, 0x0100);

  // reserved (2 + 8)
  // reserved int[2] (8)
  // matrix (36)
  // pre_defined (24)
  // next_track_ID (4)
  // Total: 2 + 8 + 36 + 24 + 4 = 74 bytes from offset 34

  return data;
}

/// Builds mvhd box version 1 (64-bit values).
Uint8List _buildMvhdV1({required int timescale, required int duration}) {
  // mvhd v1: fullbox header (12) + creation_time (8) + modification_time (8) +
  //          timescale (4) + duration (8) + rest (76) = 120 total
  const size = 120;
  final data = Uint8List(size);
  final view = ByteData.view(data.buffer);

  // Box header
  view.setUint32(0, size);
  data.setRange(4, 8, 'mvhd'.codeUnits);

  // FullBox: version (1) + flags (0)
  view.setUint32(8, 0x01000000); // version 1

  // creation_time (64-bit)
  view.setUint64(12, 0);

  // modification_time (64-bit)
  view.setUint64(20, 0);

  // timescale (32-bit)
  view.setUint32(28, timescale);

  // duration (64-bit)
  view.setUint64(32, duration);

  // rate (16.16) = 1.0
  view.setUint32(40, 0x00010000);

  // volume (8.8) = 1.0
  view.setUint16(44, 0x0100);

  return data;
}

/// Builds a box with specific content data.
Uint8List _buildBoxWithContent(String type, Uint8List content) {
  final totalSize = 8 + content.length;
  final data = Uint8List(totalSize);
  final view = ByteData.view(data.buffer);

  view.setUint32(0, totalSize);
  data.setRange(4, 8, type.codeUnits);
  data.setRange(8, totalSize, content);

  return data;
}
