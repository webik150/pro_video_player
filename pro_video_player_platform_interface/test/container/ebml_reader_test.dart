import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/src/container/ebml_reader.dart';

void main() {
  group('EbmlReader', () {
    group('VINT parsing', () {
      test('parses 1-byte VINT (0x81 = value 1)', () {
        final data = Uint8List.fromList([0x81]); // 1000 0001 = 1
        final reader = EbmlReader(data);
        expect(reader.readVint(), equals(1));
      });

      test('parses 1-byte VINT (0x82 = value 2)', () {
        final data = Uint8List.fromList([0x82]);
        final reader = EbmlReader(data);
        expect(reader.readVint(), equals(2));
      });

      test('parses 1-byte VINT (0xFF = value 127)', () {
        final data = Uint8List.fromList([0xFF]); // 1111 1111 = 127
        final reader = EbmlReader(data);
        expect(reader.readVint(), equals(127));
      });

      test('parses 2-byte VINT (0x4000 = value 0)', () {
        final data = Uint8List.fromList([0x40, 0x00]); // 0100 0000 0000 0000 = 0
        final reader = EbmlReader(data);
        expect(reader.readVint(), equals(0));
      });

      test('parses 2-byte VINT (0x4001 = value 1)', () {
        final data = Uint8List.fromList([0x40, 0x01]);
        final reader = EbmlReader(data);
        expect(reader.readVint(), equals(1));
      });

      test('parses 2-byte VINT (0x407F = value 127)', () {
        final data = Uint8List.fromList([0x40, 0x7F]);
        final reader = EbmlReader(data);
        expect(reader.readVint(), equals(127));
      });

      test('parses 2-byte VINT (0x4080 = value 128)', () {
        final data = Uint8List.fromList([0x40, 0x80]);
        final reader = EbmlReader(data);
        expect(reader.readVint(), equals(128));
      });

      test('parses 3-byte VINT', () {
        // 0010 0000 0000 0000 0000 0001 = 1
        final data = Uint8List.fromList([0x20, 0x00, 0x01]);
        final reader = EbmlReader(data);
        expect(reader.readVint(), equals(1));
      });

      test('parses 4-byte VINT', () {
        // 0001 0000 0000 0000 0000 0000 0000 0001 = 1
        final data = Uint8List.fromList([0x10, 0x00, 0x00, 0x01]);
        final reader = EbmlReader(data);
        expect(reader.readVint(), equals(1));
      });

      test('parses VINT with preserved marker bit (for element IDs)', () {
        // Element ID parsing preserves the marker bit
        final data = Uint8List.fromList([0x1A, 0x45, 0xDF, 0xA3]); // EBML header ID
        final reader = EbmlReader(data);
        expect(reader.readVintRaw(), equals(0x1A45DFA3));
      });
    });

    group('element reading', () {
      test('reads EBML header element', () {
        // EBML header: ID=0x1A45DFA3, minimal content
        final data = Uint8List.fromList([
          0x1A, 0x45, 0xDF, 0xA3, // Element ID (EBML)
          0x84, // Size = 4 bytes (VINT: 1000 0100)
          0x42, 0x86, // DocType element ID
          0x81, // Size = 1
          0x00, // Empty string
        ]);
        final reader = EbmlReader(data);
        final element = reader.readElement();

        expect(element, isNotNull);
        expect(element!.id, equals(0x1A45DFA3));
        expect(element.dataSize, equals(4));
      });

      test('reads element with 1-byte ID', () {
        final data = Uint8List.fromList([
          0xEC, // Void element ID (1-byte)
          0x81, // Size = 1
          0x00, // Padding byte
        ]);
        final reader = EbmlReader(data);
        final element = reader.readElement();

        expect(element, isNotNull);
        expect(element!.id, equals(0xEC));
        expect(element.dataSize, equals(1));
      });

      test('reads element with 2-byte ID', () {
        final data = Uint8List.fromList([
          0x42, 0x86, // DocType element ID (2-byte)
          0x88, // Size = 8
          0x77, 0x65, 0x62, 0x6D, 0x00, 0x00, 0x00, 0x00, // "webm" + padding
        ]);
        final reader = EbmlReader(data);
        final element = reader.readElement();

        expect(element, isNotNull);
        expect(element!.id, equals(0x4286));
        expect(element.dataSize, equals(8));
      });

      test('returns null at end of data', () {
        final data = Uint8List.fromList([]);
        final reader = EbmlReader(data);
        expect(reader.readElement(), isNull);
      });

      test('reads multiple elements sequentially', () {
        final data = Uint8List.fromList([
          0xEC, 0x81, 0x00, // Void, size 1
          0xEC, 0x82, 0x00, 0x00, // Void, size 2
        ]);
        final reader = EbmlReader(data);

        final element1 = reader.readElement();
        expect(element1!.dataSize, equals(1));
        reader.skip(element1.dataSize);

        final element2 = reader.readElement();
        expect(element2!.dataSize, equals(2));
      });
    });

    group('data extraction', () {
      test('reads unsigned integer (1 byte)', () {
        final data = Uint8List.fromList([0x42]);
        final reader = EbmlReader(data);
        expect(reader.readUint(1), equals(66));
      });

      test('reads unsigned integer (2 bytes)', () {
        final data = Uint8List.fromList([0x01, 0x00]);
        final reader = EbmlReader(data);
        expect(reader.readUint(2), equals(256));
      });

      test('reads unsigned integer (4 bytes)', () {
        final data = Uint8List.fromList([0x00, 0x01, 0x00, 0x00]);
        final reader = EbmlReader(data);
        expect(reader.readUint(4), equals(65536));
      });

      test('reads unsigned integer (8 bytes)', () {
        final data = Uint8List.fromList([0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00]);
        final reader = EbmlReader(data);
        expect(reader.readUint(8), equals(4294967296));
      });

      test('reads float (4 bytes)', () {
        // IEEE 754 float for 1.0: 0x3F800000
        final data = Uint8List.fromList([0x3F, 0x80, 0x00, 0x00]);
        final reader = EbmlReader(data);
        expect(reader.readFloat(4), closeTo(1.0, 0.0001));
      });

      test('reads float (8 bytes)', () {
        // IEEE 754 double for 1.0: 0x3FF0000000000000
        final data = Uint8List.fromList([0x3F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
        final reader = EbmlReader(data);
        expect(reader.readFloat(8), closeTo(1.0, 0.0001));
      });

      test('reads ASCII string', () {
        final data = Uint8List.fromList([0x77, 0x65, 0x62, 0x6D]); // "webm"
        final reader = EbmlReader(data);
        expect(reader.readString(4), equals('webm'));
      });

      test('reads UTF-8 string', () {
        final data = Uint8List.fromList([0xC3, 0xA9]); // "é" in UTF-8
        final reader = EbmlReader(data);
        expect(reader.readUtf8(2), equals('é'));
      });

      test('reads binary data', () {
        final data = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]);
        final reader = EbmlReader(data);
        final binary = reader.readBinary(4);
        expect(binary, equals([0xDE, 0xAD, 0xBE, 0xEF]));
      });
    });

    group('position management', () {
      test('position starts at 0', () {
        final reader = EbmlReader(Uint8List.fromList([0x00, 0x01, 0x02]));
        expect(reader.position, equals(0));
      });

      test('position advances after reading', () {
        final reader = EbmlReader(Uint8List.fromList([0x81, 0x82, 0x83]));
        reader.readVint();
        expect(reader.position, equals(1));
      });

      test('seek changes position', () {
        final reader = EbmlReader(Uint8List.fromList([0x00, 0x01, 0x02]));
        reader.position = 2;
        expect(reader.position, equals(2));
      });

      test('skip advances position', () {
        final reader = EbmlReader(Uint8List.fromList([0x00, 0x01, 0x02]));
        reader.skip(2);
        expect(reader.position, equals(2));
      });

      test('hasMore returns true when data remains', () {
        final reader = EbmlReader(Uint8List.fromList([0x00, 0x01]));
        expect(reader.hasMore, isTrue);
        reader.skip(1);
        expect(reader.hasMore, isTrue);
        reader.skip(1);
        expect(reader.hasMore, isFalse);
      });

      test('remaining returns bytes left', () {
        final reader = EbmlReader(Uint8List.fromList([0x00, 0x01, 0x02]));
        expect(reader.remaining, equals(3));
        reader.skip(1);
        expect(reader.remaining, equals(2));
      });
    });

    group('EBML element IDs', () {
      test('EbmlIds contains standard IDs', () {
        expect(EbmlIds.ebml, equals(0x1A45DFA3));
        expect(EbmlIds.segment, equals(0x18538067));
        expect(EbmlIds.info, equals(0x1549A966));
        expect(EbmlIds.tracks, equals(0x1654AE6B));
      });

      test('MatroskaIds contains track-related IDs', () {
        expect(MatroskaIds.trackEntry, equals(0xAE));
        expect(MatroskaIds.trackNumber, equals(0xD7));
        expect(MatroskaIds.trackType, equals(0x83));
        expect(MatroskaIds.codecId, equals(0x86));
      });
    });
  });
}
