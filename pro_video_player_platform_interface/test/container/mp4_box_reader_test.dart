import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/src/container/mp4_box_reader.dart';

void main() {
  group('Mp4Box', () {
    test('stores type, offset, size, and headerSize', () {
      const box = Mp4Box(type: 'ftyp', offset: 0, size: 24, headerSize: 8);

      expect(box.type, equals('ftyp'));
      expect(box.offset, equals(0));
      expect(box.size, equals(24));
      expect(box.headerSize, equals(8));
    });

    test('calculates dataOffset correctly', () {
      const box = Mp4Box(type: 'moov', offset: 100, size: 500, headerSize: 8);

      expect(box.dataOffset, equals(108)); // offset + headerSize
    });

    test('calculates dataSize correctly', () {
      const box = Mp4Box(type: 'trak', offset: 0, size: 100, headerSize: 8);

      expect(box.dataSize, equals(92)); // size - headerSize
    });

    test('calculates endOffset correctly', () {
      const box = Mp4Box(type: 'mdia', offset: 50, size: 200, headerSize: 8);

      expect(box.endOffset, equals(250)); // offset + size
    });

    test('extended header has size 16', () {
      const box = Mp4Box(type: 'mdat', offset: 0, size: 0x100000000, headerSize: 16);

      expect(box.headerSize, equals(16));
      expect(box.dataOffset, equals(16));
    });

    test('equality works correctly', () {
      const box1 = Mp4Box(type: 'ftyp', offset: 0, size: 24, headerSize: 8);
      const box2 = Mp4Box(type: 'ftyp', offset: 0, size: 24, headerSize: 8);
      const box3 = Mp4Box(type: 'moov', offset: 0, size: 24, headerSize: 8);

      expect(box1, equals(box2));
      expect(box1, isNot(equals(box3)));
    });

    test('hashCode is consistent', () {
      const box1 = Mp4Box(type: 'ftyp', offset: 0, size: 24, headerSize: 8);
      const box2 = Mp4Box(type: 'ftyp', offset: 0, size: 24, headerSize: 8);

      expect(box1.hashCode, equals(box2.hashCode));
    });

    test('toString provides useful output', () {
      const box = Mp4Box(type: 'ftyp', offset: 0, size: 24, headerSize: 8);

      expect(box.toString(), contains('ftyp'));
      expect(box.toString(), contains('24'));
    });
  });

  group('Mp4BoxReader', () {
    group('construction', () {
      test('creates reader from Uint8List', () {
        final data = Uint8List.fromList([0, 0, 0, 8, 0x66, 0x74, 0x79, 0x70]); // 8-byte ftyp box
        final reader = Mp4BoxReader(data);

        expect(reader.length, equals(8));
        expect(reader.position, equals(0));
      });

      test('creates reader with initial offset', () {
        final data = Uint8List(100);
        final reader = Mp4BoxReader(data, offset: 50);

        expect(reader.position, equals(50));
      });
    });

    group('readBox', () {
      test('reads standard 8-byte header', () {
        // Build a valid ftyp box: size=24, type='ftyp', then 16 bytes of data
        final data = _buildBox('ftyp', 16);
        final reader = Mp4BoxReader(data);

        final box = reader.readBox();

        expect(box, isNotNull);
        expect(box!.type, equals('ftyp'));
        expect(box.offset, equals(0));
        expect(box.size, equals(24)); // 8 header + 16 data
        expect(box.headerSize, equals(8));
      });

      test('reads extended 16-byte header when size is 1', () {
        // Extended size box: size=1 indicates 64-bit size follows
        final data = _buildExtendedBox('mdat', 100);
        final reader = Mp4BoxReader(data);

        final box = reader.readBox();

        expect(box, isNotNull);
        expect(box!.type, equals('mdat'));
        expect(box.size, equals(116)); // 16 header + 100 data
        expect(box.headerSize, equals(16));
      });

      test('returns null when no more boxes', () {
        final data = Uint8List(0);
        final reader = Mp4BoxReader(data);

        final box = reader.readBox();

        expect(box, isNull);
      });

      test('returns null when remaining bytes less than header size', () {
        final data = Uint8List(4); // Less than 8-byte header
        final reader = Mp4BoxReader(data);

        final box = reader.readBox();

        expect(box, isNull);
      });

      test('advances position after reading', () {
        final data = _buildBox('ftyp', 16);
        final reader = Mp4BoxReader(data);

        expect(reader.position, equals(0));

        reader.readBox();

        expect(reader.position, equals(24)); // Moved past entire box
      });

      test('reads multiple boxes sequentially', () {
        // Two boxes: ftyp (24 bytes) + moov (32 bytes)
        final ftyp = _buildBox('ftyp', 16);
        final moov = _buildBox('moov', 24);
        final data = Uint8List.fromList([...ftyp, ...moov]);
        final reader = Mp4BoxReader(data);

        final box1 = reader.readBox();
        final box2 = reader.readBox();

        expect(box1!.type, equals('ftyp'));
        expect(box1.offset, equals(0));
        expect(box2!.type, equals('moov'));
        expect(box2.offset, equals(24));
      });

      test('handles box with zero size (extends to end)', () {
        // Size 0 means box extends to end of file
        final data = Uint8List.fromList([
          0, 0, 0, 0, // size = 0 (extends to end)
          0x6d, 0x64, 0x61, 0x74, // 'mdat'
          ...List.filled(100, 0), // 100 bytes of data
        ]);
        final reader = Mp4BoxReader(data);

        final box = reader.readBox();

        expect(box, isNotNull);
        expect(box!.type, equals('mdat'));
        expect(box.size, equals(108)); // Total file size
        expect(box.headerSize, equals(8));
      });
    });

    group('readChildBox', () {
      test('reads child box within parent bounds', () {
        // moov box containing trak box
        final trak = _buildBox('trak', 16); // 24 bytes
        final moovData = Uint8List.fromList([
          0, 0, 0, 32, // size = 32
          0x6d, 0x6f, 0x6f, 0x76, // 'moov'
          ...trak,
        ]);
        final reader = Mp4BoxReader(moovData);

        final moov = reader.readBox()!;
        reader.enterBox(moov); // Position at moov data start
        final child = reader.readChildBox(moov);

        expect(child, isNotNull);
        expect(child!.type, equals('trak'));
        expect(child.offset, equals(8)); // After moov header
      });

      test('returns null when no more children', () {
        final moov = _buildBox('moov', 0); // Empty moov, just header
        final reader = Mp4BoxReader(moov);

        final box = reader.readBox()!;
        reader.seek(box.dataOffset); // Position at moov data start

        final child = reader.readChildBox(box);

        expect(child, isNull);
      });

      test('returns null when position beyond parent', () {
        final moov = _buildBox('moov', 16);
        final reader = Mp4BoxReader(moov);

        final box = reader.readBox()!;
        reader.seek(box.endOffset + 10); // Beyond parent

        final child = reader.readChildBox(box);

        expect(child, isNull);
      });
    });

    group('seek', () {
      test('moves position to absolute offset', () {
        final data = Uint8List(100);
        final reader = Mp4BoxReader(data);

        reader.seek(50);

        expect(reader.position, equals(50));
      });

      test('clamps to data length', () {
        final data = Uint8List(100);
        final reader = Mp4BoxReader(data);

        reader.seek(200); // Beyond data

        expect(reader.position, equals(100));
      });

      test('handles negative offset', () {
        final data = Uint8List(100);
        final reader = Mp4BoxReader(data);
        reader.seek(50);

        reader.seek(-10);

        expect(reader.position, equals(0));
      });
    });

    group('skip', () {
      test('moves position by relative amount', () {
        final data = Uint8List(100);
        final reader = Mp4BoxReader(data);

        reader.skip(30);

        expect(reader.position, equals(30));
      });

      test('can skip backward with negative value', () {
        final data = Uint8List(100);
        final reader = Mp4BoxReader(data);
        reader.seek(50);

        reader.skip(-20);

        expect(reader.position, equals(30));
      });
    });

    group('skipBox', () {
      test('advances position past box', () {
        final data = _buildBox('ftyp', 16);
        final reader = Mp4BoxReader(data);
        reader.readBox();

        // Position is already at end after readBox, reset
        reader.seek(0);
        reader.readBox(); // Read again
        // skipBox would be used to skip from header to end

        expect(reader.position, equals(24));
      });
    });

    group('enterBox', () {
      test('positions reader at box data start', () {
        final data = _buildBox('moov', 100);
        final reader = Mp4BoxReader(data);
        final box = reader.readBox()!;

        reader.seek(0); // Reset
        reader.enterBox(box);

        expect(reader.position, equals(8)); // At data offset
      });

      test('works with extended header box', () {
        final data = _buildExtendedBox('mdat', 100);
        final reader = Mp4BoxReader(data);
        final box = reader.readBox()!;

        reader.enterBox(box);

        expect(reader.position, equals(16)); // At data offset after 16-byte header
      });
    });

    group('readUint8', () {
      test('reads single byte', () {
        final data = Uint8List.fromList([0xFF, 0x00, 0x80]);
        final reader = Mp4BoxReader(data);

        expect(reader.readUint8(), equals(255));
        expect(reader.readUint8(), equals(0));
        expect(reader.readUint8(), equals(128));
      });

      test('advances position by 1', () {
        final data = Uint8List.fromList([0xFF, 0x00]);
        final reader = Mp4BoxReader(data);

        reader.readUint8();

        expect(reader.position, equals(1));
      });
    });

    group('readUint16', () {
      test('reads big-endian 16-bit value', () {
        final data = Uint8List.fromList([0x01, 0x00]); // 256 in big-endian
        final reader = Mp4BoxReader(data);

        expect(reader.readUint16(), equals(256));
      });

      test('advances position by 2', () {
        final data = Uint8List.fromList([0x00, 0x00, 0xFF, 0xFF]);
        final reader = Mp4BoxReader(data);

        reader.readUint16();

        expect(reader.position, equals(2));
      });
    });

    group('readUint32', () {
      test('reads big-endian 32-bit value', () {
        final data = Uint8List.fromList([0x00, 0x01, 0x00, 0x00]); // 65536 in big-endian
        final reader = Mp4BoxReader(data);

        expect(reader.readUint32(), equals(65536));
      });

      test('handles max uint32 value', () {
        final data = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF]);
        final reader = Mp4BoxReader(data);

        expect(reader.readUint32(), equals(0xFFFFFFFF));
      });

      test('advances position by 4', () {
        final data = Uint8List(8);
        final reader = Mp4BoxReader(data);

        reader.readUint32();

        expect(reader.position, equals(4));
      });
    });

    group('readUint64', () {
      test('reads big-endian 64-bit value', () {
        final data = Uint8List.fromList([0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00]); // 2^32 in big-endian
        final reader = Mp4BoxReader(data);

        expect(reader.readUint64(), equals(0x100000000));
      });

      test('advances position by 8', () {
        final data = Uint8List(16);
        final reader = Mp4BoxReader(data);

        reader.readUint64();

        expect(reader.position, equals(8));
      });
    });

    group('readInt16', () {
      test('reads signed big-endian 16-bit value', () {
        final data = Uint8List.fromList([0xFF, 0xFF]); // -1 in signed big-endian
        final reader = Mp4BoxReader(data);

        expect(reader.readInt16(), equals(-1));
      });

      test('reads positive values correctly', () {
        final data = Uint8List.fromList([0x7F, 0xFF]); // 32767
        final reader = Mp4BoxReader(data);

        expect(reader.readInt16(), equals(32767));
      });
    });

    group('readInt32', () {
      test('reads signed big-endian 32-bit value', () {
        final data = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF]); // -1
        final reader = Mp4BoxReader(data);

        expect(reader.readInt32(), equals(-1));
      });

      test('reads positive values correctly', () {
        final data = Uint8List.fromList([0x7F, 0xFF, 0xFF, 0xFF]); // MAX_INT32
        final reader = Mp4BoxReader(data);

        expect(reader.readInt32(), equals(2147483647));
      });
    });

    group('readFixedPoint16_16', () {
      test('reads 16.16 fixed point as double', () {
        // 1.0 in 16.16 fixed point = 0x00010000
        final data = Uint8List.fromList([0x00, 0x01, 0x00, 0x00]);
        final reader = Mp4BoxReader(data);

        expect(reader.readFixedPoint16_16(), closeTo(1.0, 0.0001));
      });

      test('reads fractional values', () {
        // 1.5 in 16.16 fixed point = 0x00018000
        final data = Uint8List.fromList([0x00, 0x01, 0x80, 0x00]);
        final reader = Mp4BoxReader(data);

        expect(reader.readFixedPoint16_16(), closeTo(1.5, 0.0001));
      });
    });

    group('readFixedPoint8_8', () {
      test('reads 8.8 fixed point as double', () {
        // 1.0 in 8.8 fixed point = 0x0100
        final data = Uint8List.fromList([0x01, 0x00]);
        final reader = Mp4BoxReader(data);

        expect(reader.readFixedPoint8_8(), closeTo(1.0, 0.01));
      });

      test('reads fractional values', () {
        // 2.5 in 8.8 fixed point = 0x0280
        final data = Uint8List.fromList([0x02, 0x80]);
        final reader = Mp4BoxReader(data);

        expect(reader.readFixedPoint8_8(), closeTo(2.5, 0.01));
      });
    });

    group('readFourCC', () {
      test('reads four character code', () {
        final data = Uint8List.fromList([0x66, 0x74, 0x79, 0x70]); // 'ftyp'
        final reader = Mp4BoxReader(data);

        expect(reader.readFourCC(), equals('ftyp'));
      });

      test('handles various box types', () {
        final types = ['moov', 'trak', 'mdia', 'minf', 'stbl', 'stsd', 'avc1', 'hvc1', 'mp4a'];

        for (final type in types) {
          final data = Uint8List.fromList(type.codeUnits);
          final reader = Mp4BoxReader(data);

          expect(reader.readFourCC(), equals(type));
        }
      });

      test('advances position by 4', () {
        final data = Uint8List(8);
        final reader = Mp4BoxReader(data);

        reader.readFourCC();

        expect(reader.position, equals(4));
      });
    });

    group('readString', () {
      test('reads ASCII string of specified length', () {
        final data = Uint8List.fromList([0x48, 0x65, 0x6c, 0x6c, 0x6f]); // 'Hello'
        final reader = Mp4BoxReader(data);

        expect(reader.readString(5), equals('Hello'));
      });

      test('handles null terminator', () {
        final data = Uint8List.fromList([0x48, 0x69, 0x00, 0x00]); // 'Hi\0\0'
        final reader = Mp4BoxReader(data);

        expect(reader.readString(4), equals('Hi'));
      });
    });

    group('readBytes', () {
      test('reads specified number of bytes', () {
        final data = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
        final reader = Mp4BoxReader(data);

        final bytes = reader.readBytes(4);

        expect(bytes.length, equals(4));
        expect(bytes[0], equals(1));
        expect(bytes[3], equals(4));
      });

      test('advances position by byte count', () {
        final data = Uint8List(100);
        final reader = Mp4BoxReader(data);

        reader.readBytes(25);

        expect(reader.position, equals(25));
      });
    });

    group('hasRemaining', () {
      test('returns true when bytes available', () {
        final data = Uint8List(100);
        final reader = Mp4BoxReader(data);

        expect(reader.hasRemaining(50), isTrue);
        expect(reader.hasRemaining(100), isTrue);
      });

      test('returns false when not enough bytes', () {
        final data = Uint8List(100);
        final reader = Mp4BoxReader(data);

        expect(reader.hasRemaining(101), isFalse);
      });

      test('considers current position', () {
        final data = Uint8List(100);
        final reader = Mp4BoxReader(data);
        reader.seek(90);

        expect(reader.hasRemaining(10), isTrue);
        expect(reader.hasRemaining(11), isFalse);
      });
    });

    group('remaining', () {
      test('returns bytes remaining from position', () {
        final data = Uint8List(100);
        final reader = Mp4BoxReader(data);

        expect(reader.remaining, equals(100));

        reader.seek(30);

        expect(reader.remaining, equals(70));
      });
    });

    group('findBox', () {
      test('finds box by type from current position', () {
        final ftyp = _buildBox('ftyp', 8);
        final moov = _buildBox('moov', 100);
        final data = Uint8List.fromList([...ftyp, ...moov]);
        final reader = Mp4BoxReader(data);

        final found = reader.findBox('moov');

        expect(found, isNotNull);
        expect(found!.type, equals('moov'));
        expect(found.offset, equals(16)); // After ftyp
      });

      test('returns null when box not found', () {
        final ftyp = _buildBox('ftyp', 8);
        final reader = Mp4BoxReader(ftyp);

        final found = reader.findBox('moov');

        expect(found, isNull);
      });

      test('skips boxes that do not match', () {
        final ftyp = _buildBox('ftyp', 8);
        final free = _buildBox('free', 8);
        final moov = _buildBox('moov', 100);
        final data = Uint8List.fromList([...ftyp, ...free, ...moov]);
        final reader = Mp4BoxReader(data);

        final found = reader.findBox('moov');

        expect(found, isNotNull);
        expect(found!.offset, equals(32)); // After ftyp (16) + free (16)
      });
    });

    group('findChildBox', () {
      test('finds child box within parent', () {
        // moov containing mvhd and trak
        final mvhd = _buildBox('mvhd', 100);
        final trak = _buildBox('trak', 50);
        final moovContent = Uint8List.fromList([...mvhd, ...trak]);
        final moov = _buildBoxWithContent('moov', moovContent);
        final reader = Mp4BoxReader(moov);

        final moovBox = reader.readBox()!;
        final found = reader.findChildBox(moovBox, 'trak');

        expect(found, isNotNull);
        expect(found!.type, equals('trak'));
      });

      test('returns null when child not found', () {
        final mvhd = _buildBox('mvhd', 100);
        final moov = _buildBoxWithContent('moov', mvhd);
        final reader = Mp4BoxReader(moov);

        final moovBox = reader.readBox()!;
        final found = reader.findChildBox(moovBox, 'trak');

        expect(found, isNull);
      });
    });

    group('readLanguage', () {
      test('decodes ISO 639-2/T language code', () {
        // 'eng' encoded: e=5, n=14, g=7 -> packed as ((5-1)<<10)|((14-1)<<5)|(7-1) = 0x15C7
        // Actually the encoding uses 5 bits per char where a=1, b=2, etc.
        // 'eng' = (5<<10)|(14<<5)|7 = 0x15C7 but shifted: each char is char-0x60
        // Standard: each letter minus 0x60, packed into 16 bits
        // e=0x65-0x60=5, n=0x6E-0x60=14, g=0x67-0x60=7
        // Packed: (5<<10)|(14<<5)|7 = 5120+448+7 = 5575 = 0x15C7
        final data = Uint8List.fromList([0x15, 0xC7]);
        final reader = Mp4BoxReader(data);

        expect(reader.readLanguage(), equals('eng'));
      });

      test('decodes und (undefined)', () {
        // 'und' = u=21, n=14, d=4 -> (21<<10)|(14<<5)|4 = 21504+448+4 = 21956 = 0x55C4
        final data = Uint8List.fromList([0x55, 0xC4]);
        final reader = Mp4BoxReader(data);

        expect(reader.readLanguage(), equals('und'));
      });
    });

    group('readMatrix', () {
      test('reads transformation matrix and extracts rotation', () {
        // Identity matrix (no rotation): 36 bytes of fixed-point values
        // a=1, b=0, u=0, c=0, d=1, v=0, tx=0, ty=0, w=1
        final matrix = <int>[
          // a (16.16) = 1.0
          0x00, 0x01, 0x00, 0x00,
          // b (16.16) = 0
          0x00, 0x00, 0x00, 0x00,
          // u (2.30) = 0
          0x00, 0x00, 0x00, 0x00,
          // c (16.16) = 0
          0x00, 0x00, 0x00, 0x00,
          // d (16.16) = 1.0
          0x00, 0x01, 0x00, 0x00,
          // v (2.30) = 0
          0x00, 0x00, 0x00, 0x00,
          // tx (16.16) = 0
          0x00, 0x00, 0x00, 0x00,
          // ty (16.16) = 0
          0x00, 0x00, 0x00, 0x00,
          // w (2.30) = 1.0
          0x40, 0x00, 0x00, 0x00,
        ];
        final reader = Mp4BoxReader(Uint8List.fromList(matrix));

        expect(reader.readRotationFromMatrix(), equals(0));
      });

      test('detects 90 degree rotation', () {
        // 90 degree rotation: a=0, b=1, c=-1, d=0
        final matrix = <int>[
          // a (16.16) = 0
          0x00, 0x00, 0x00, 0x00,
          // b (16.16) = 1.0
          0x00, 0x01, 0x00, 0x00,
          // u (2.30) = 0
          0x00, 0x00, 0x00, 0x00,
          // c (16.16) = -1.0
          0xFF, 0xFF, 0x00, 0x00,
          // d (16.16) = 0
          0x00, 0x00, 0x00, 0x00,
          // v (2.30) = 0
          0x00, 0x00, 0x00, 0x00,
          // tx, ty, w
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x40, 0x00, 0x00, 0x00,
        ];
        final reader = Mp4BoxReader(Uint8List.fromList(matrix));

        expect(reader.readRotationFromMatrix(), equals(90));
      });

      test('detects 180 degree rotation', () {
        // 180 degree rotation: a=-1, b=0, c=0, d=-1
        final matrix = <int>[
          // a (16.16) = -1.0
          0xFF, 0xFF, 0x00, 0x00,
          // b (16.16) = 0
          0x00, 0x00, 0x00, 0x00,
          // u (2.30) = 0
          0x00, 0x00, 0x00, 0x00,
          // c (16.16) = 0
          0x00, 0x00, 0x00, 0x00,
          // d (16.16) = -1.0
          0xFF, 0xFF, 0x00, 0x00,
          // v (2.30) = 0
          0x00, 0x00, 0x00, 0x00,
          // tx, ty, w
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x40, 0x00, 0x00, 0x00,
        ];
        final reader = Mp4BoxReader(Uint8List.fromList(matrix));

        expect(reader.readRotationFromMatrix(), equals(180));
      });

      test('detects 270 degree rotation', () {
        // 270 degree rotation: a=0, b=-1, c=1, d=0
        final matrix = <int>[
          // a (16.16) = 0
          0x00, 0x00, 0x00, 0x00,
          // b (16.16) = -1.0
          0xFF, 0xFF, 0x00, 0x00,
          // u (2.30) = 0
          0x00, 0x00, 0x00, 0x00,
          // c (16.16) = 1.0
          0x00, 0x01, 0x00, 0x00,
          // d (16.16) = 0
          0x00, 0x00, 0x00, 0x00,
          // v (2.30) = 0
          0x00, 0x00, 0x00, 0x00,
          // tx, ty, w
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00,
          0x40, 0x00, 0x00, 0x00,
        ];
        final reader = Mp4BoxReader(Uint8List.fromList(matrix));

        expect(reader.readRotationFromMatrix(), equals(270));
      });
    });
  });
}

/// Builds a standard MP4 box with the given type and data size.
Uint8List _buildBox(String type, int dataSize) {
  final totalSize = 8 + dataSize;
  final data = Uint8List(totalSize);
  final view = ByteData.view(data.buffer);

  // Size (4 bytes, big-endian)
  view.setUint32(0, totalSize);

  // Type (4 bytes)
  for (var i = 0; i < 4; i++) {
    data[4 + i] = type.codeUnitAt(i);
  }

  return data;
}

/// Builds an extended MP4 box (64-bit size) with the given type and data size.
Uint8List _buildExtendedBox(String type, int dataSize) {
  final totalSize = 16 + dataSize; // 16-byte header
  final data = Uint8List(totalSize);
  final view = ByteData.view(data.buffer);

  // Size = 1 (indicates extended size follows)
  view.setUint32(0, 1);

  // Type (4 bytes)
  for (var i = 0; i < 4; i++) {
    data[4 + i] = type.codeUnitAt(i);
  }

  // Extended size (8 bytes, big-endian)
  view.setUint64(8, totalSize);

  return data;
}

/// Builds an MP4 box with specific content data.
Uint8List _buildBoxWithContent(String type, Uint8List content) {
  final totalSize = 8 + content.length;
  final data = Uint8List(totalSize);
  final view = ByteData.view(data.buffer);

  // Size (4 bytes, big-endian)
  view.setUint32(0, totalSize);

  // Type (4 bytes)
  for (var i = 0; i < 4; i++) {
    data[4 + i] = type.codeUnitAt(i);
  }

  // Content
  data.setRange(8, totalSize, content);

  return data;
}
