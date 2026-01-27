import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/src/container/mp4_box_reader.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/mp4_box_writer.dart';

void main() {
  group('Mp4BoxWriter', () {
    group('primitive types', () {
      test('writeUint8 writes single byte', () {
        final writer = Mp4BoxWriter();
        writer.writeUint8(0xFF);
        expect(writer.toBytes(), equals([0xFF]));
      });

      test('writeUint16 writes big-endian', () {
        final writer = Mp4BoxWriter();
        writer.writeUint16(0x1234);
        expect(writer.toBytes(), equals([0x12, 0x34]));
      });

      test('writeUint24 writes big-endian', () {
        final writer = Mp4BoxWriter();
        writer.writeUint24(0x123456);
        expect(writer.toBytes(), equals([0x12, 0x34, 0x56]));
      });

      test('writeUint32 writes big-endian', () {
        final writer = Mp4BoxWriter();
        writer.writeUint32(0x12345678);
        expect(writer.toBytes(), equals([0x12, 0x34, 0x56, 0x78]));
      });

      test('writeUint64 writes big-endian', () {
        final writer = Mp4BoxWriter();
        // Use smaller value that fits in JS safe integer range
        writer.writeUint64(0x01020304);
        expect(writer.toBytes(), equals([0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04]));
      });

      test('writeInt16 writes signed value', () {
        final writer = Mp4BoxWriter();
        writer.writeInt16(-1);
        expect(writer.toBytes(), equals([0xFF, 0xFF]));
      });

      test('writeInt32 writes signed value', () {
        final writer = Mp4BoxWriter();
        writer.writeInt32(-1);
        expect(writer.toBytes(), equals([0xFF, 0xFF, 0xFF, 0xFF]));
      });

      test('writeFixedPoint16_16 writes correctly', () {
        final writer = Mp4BoxWriter();
        writer.writeFixedPoint16_16(1.5);
        // 1.5 = 0x00018000 (1 in upper 16 bits, 0.5 * 65536 = 32768 in lower)
        expect(writer.toBytes(), equals([0x00, 0x01, 0x80, 0x00]));
      });

      test('writeFixedPoint8_8 writes correctly', () {
        final writer = Mp4BoxWriter();
        writer.writeFixedPoint8_8(1.5);
        // 1.5 = 0x0180 (1 in upper 8 bits, 0.5 * 256 = 128 in lower)
        expect(writer.toBytes(), equals([0x01, 0x80]));
      });

      test('writeFourCC writes 4 characters', () {
        final writer = Mp4BoxWriter();
        writer.writeFourCC('ftyp');
        expect(writer.toBytes(), equals([0x66, 0x74, 0x79, 0x70])); // 'ftyp' ASCII
      });

      test('writeFourCC throws on wrong length', () {
        final writer = Mp4BoxWriter();
        expect(() => writer.writeFourCC('abc'), throwsArgumentError);
        expect(() => writer.writeFourCC('abcde'), throwsArgumentError);
      });

      test('writeBytes appends raw data', () {
        final writer = Mp4BoxWriter();
        writer.writeBytes(Uint8List.fromList([1, 2, 3]));
        expect(writer.toBytes(), equals([1, 2, 3]));
      });

      test('writeZeros writes padding', () {
        final writer = Mp4BoxWriter();
        writer.writeZeros(4);
        expect(writer.toBytes(), equals([0, 0, 0, 0]));
      });

      test('writeLanguage encodes ISO 639-2/T', () {
        final writer = Mp4BoxWriter();
        writer.writeLanguage('eng');
        // e=5, n=14, g=7 -> (5<<10)|(14<<5)|7 = 5120 + 448 + 7 = 5575 = 0x15C7
        expect(writer.toBytes(), equals([0x15, 0xC7]));
      });

      test('writeLanguage throws on wrong length', () {
        final writer = Mp4BoxWriter();
        expect(() => writer.writeLanguage('en'), throwsArgumentError);
        expect(() => writer.writeLanguage('engl'), throwsArgumentError);
      });
    });

    group('box writing', () {
      test('writeBox creates valid box structure', () {
        final writer = Mp4BoxWriter();
        writer.writeBox('test', (w) {
          w.writeUint32(0x12345678);
        });

        final bytes = writer.toBytes();
        expect(bytes.length, equals(12)); // 8 header + 4 data

        // Verify with reader
        final reader = Mp4BoxReader(bytes);
        final box = reader.readBox();
        expect(box, isNotNull);
        expect(box!.type, equals('test'));
        expect(box.size, equals(12));
        expect(box.dataSize, equals(4));
      });

      test('writeFullBoxHeader writes version and flags', () {
        final writer = Mp4BoxWriter();
        writer.writeFullBoxHeader(1, 0x000001);
        final bytes = writer.toBytes();
        expect(bytes, equals([0x01, 0x00, 0x00, 0x01]));
      });

      test('writeIdentityMatrix writes 36 bytes', () {
        final writer = Mp4BoxWriter();
        writer.writeIdentityMatrix();
        final bytes = writer.toBytes();
        expect(bytes.length, equals(36));

        // Read back and verify identity matrix values
        final view = ByteData.view(bytes.buffer);
        expect(view.getInt32(0) / 65536.0, closeTo(1.0, 0.001)); // a
        expect(view.getInt32(4) / 65536.0, closeTo(0.0, 0.001)); // b
        expect(view.getInt32(12) / 65536.0, closeTo(0.0, 0.001)); // c
        expect(view.getInt32(16) / 65536.0, closeTo(1.0, 0.001)); // d
      });
    });

    group('common boxes', () {
      test('writeFtyp creates valid ftyp box', () {
        final writer = Mp4BoxWriter();
        writer.writeFtyp(majorBrand: 'isom', minorVersion: 0x200, compatibleBrands: ['isom', 'mp41']);

        final bytes = writer.toBytes();
        final reader = Mp4BoxReader(bytes);
        final box = reader.readBox();

        expect(box, isNotNull);
        expect(box!.type, equals('ftyp'));

        // Parse ftyp content
        reader.seek(box.dataOffset);
        expect(reader.readFourCC(), equals('isom'));
        expect(reader.readUint32(), equals(0x200));
        expect(reader.readFourCC(), equals('isom'));
        expect(reader.readFourCC(), equals('mp41'));
      });

      test('writeMvhd creates valid mvhd box', () {
        final writer = Mp4BoxWriter();
        writer.writeMvhd(timescale: 1000, duration: 5000, nextTrackId: 3);

        final bytes = writer.toBytes();
        final reader = Mp4BoxReader(bytes);
        final box = reader.readBox();

        expect(box, isNotNull);
        expect(box!.type, equals('mvhd'));
        expect(box.dataSize, equals(100)); // v0 mvhd is 100 bytes
      });

      test('writeTkhd creates valid tkhd box', () {
        final writer = Mp4BoxWriter();
        writer.writeTkhd(trackId: 1, duration: 5000, width: 1920, height: 1080);

        final bytes = writer.toBytes();
        final reader = Mp4BoxReader(bytes);
        final box = reader.readBox();

        expect(box, isNotNull);
        expect(box!.type, equals('tkhd'));
        expect(box.dataSize, equals(84)); // v0 tkhd is 84 bytes
      });

      test('writeMdhd creates valid mdhd box', () {
        final writer = Mp4BoxWriter();
        writer.writeMdhd(timescale: 90000, duration: 450000, language: 'eng');

        final bytes = writer.toBytes();
        final reader = Mp4BoxReader(bytes);
        final box = reader.readBox();

        expect(box, isNotNull);
        expect(box!.type, equals('mdhd'));
        expect(box.dataSize, equals(24)); // v0 mdhd is 24 bytes
      });

      test('writeHdlr creates valid hdlr box', () {
        final writer = Mp4BoxWriter();
        writer.writeHdlr(handlerType: 'vide', name: 'VideoHandler');

        final bytes = writer.toBytes();
        final reader = Mp4BoxReader(bytes);
        final box = reader.readBox();

        expect(box, isNotNull);
        expect(box!.type, equals('hdlr'));

        reader.enterBox(box);
        reader.skip(4); // version + flags
        reader.skip(4); // pre_defined
        expect(reader.readFourCC(), equals('vide'));
      });

      test('writeVmhd creates valid vmhd box', () {
        final writer = Mp4BoxWriter();
        writer.writeVmhd();

        final bytes = writer.toBytes();
        final reader = Mp4BoxReader(bytes);
        final box = reader.readBox();

        expect(box, isNotNull);
        expect(box!.type, equals('vmhd'));
        expect(box.dataSize, equals(12));
      });

      test('writeSmhd creates valid smhd box', () {
        final writer = Mp4BoxWriter();
        writer.writeSmhd();

        final bytes = writer.toBytes();
        final reader = Mp4BoxReader(bytes);
        final box = reader.readBox();

        expect(box, isNotNull);
        expect(box!.type, equals('smhd'));
        expect(box.dataSize, equals(8));
      });

      test('writeDinf creates valid dinf/dref structure', () {
        final writer = Mp4BoxWriter();
        writer.writeDinf();

        final bytes = writer.toBytes();
        final reader = Mp4BoxReader(bytes);
        final dinf = reader.readBox();

        expect(dinf, isNotNull);
        expect(dinf!.type, equals('dinf'));

        final dref = reader.findChildBox(dinf, 'dref');
        expect(dref, isNotNull);
      });

      test('writeEmptyStbl creates valid stbl with empty tables', () {
        final writer = Mp4BoxWriter();
        writer.writeEmptyStbl(stsdContent: Uint8List(0));

        final bytes = writer.toBytes();
        final reader = Mp4BoxReader(bytes);
        final stbl = reader.readBox();

        expect(stbl, isNotNull);
        expect(stbl!.type, equals('stbl'));

        // Find child boxes
        final stsd = reader.findChildBox(stbl, 'stsd');
        expect(stsd, isNotNull);

        final stts = reader.findChildBox(stbl, 'stts');
        expect(stts, isNotNull);

        final stsc = reader.findChildBox(stbl, 'stsc');
        expect(stsc, isNotNull);

        final stsz = reader.findChildBox(stbl, 'stsz');
        expect(stsz, isNotNull);

        final stco = reader.findChildBox(stbl, 'stco');
        expect(stco, isNotNull);
      });

      test('writeTrex creates valid trex box', () {
        final writer = Mp4BoxWriter();
        writer.writeTrex(trackId: 1);

        final bytes = writer.toBytes();
        final reader = Mp4BoxReader(bytes);
        final box = reader.readBox();

        expect(box, isNotNull);
        expect(box!.type, equals('trex'));
        expect(box.dataSize, equals(24));
      });

      test('writeMfhd creates valid mfhd box', () {
        final writer = Mp4BoxWriter();
        writer.writeMfhd(sequenceNumber: 5);

        final bytes = writer.toBytes();
        final reader = Mp4BoxReader(bytes);
        final box = reader.readBox();

        expect(box, isNotNull);
        expect(box!.type, equals('mfhd'));

        reader.enterBox(box);
        reader.skip(4); // version + flags
        expect(reader.readUint32(), equals(5));
      });

      test('writeTfhd creates valid tfhd box', () {
        final writer = Mp4BoxWriter();
        writer.writeTfhd(trackId: 1, defaultSampleDuration: 1024);

        final bytes = writer.toBytes();
        final reader = Mp4BoxReader(bytes);
        final box = reader.readBox();

        expect(box, isNotNull);
        expect(box!.type, equals('tfhd'));
      });

      test('writeTfdt creates valid tfdt box', () {
        final writer = Mp4BoxWriter();
        writer.writeTfdt(baseMediaDecodeTime: 90000);

        final bytes = writer.toBytes();
        final reader = Mp4BoxReader(bytes);
        final box = reader.readBox();

        expect(box, isNotNull);
        expect(box!.type, equals('tfdt'));

        reader.enterBox(box);
        reader.skip(4); // version + flags
        expect(reader.readUint32(), equals(90000));
      });

      test('writeTfdt version 1 uses 64-bit time', () {
        final writer = Mp4BoxWriter();
        writer.writeTfdt(baseMediaDecodeTime: 0x100000000, version1: true);

        final bytes = writer.toBytes();
        final reader = Mp4BoxReader(bytes);
        final box = reader.readBox();

        expect(box, isNotNull);
        reader.enterBox(box!);
        final version = reader.readUint8();
        expect(version, equals(1));
        reader.skip(3); // flags
        // Use JS-safe integer for comparison
        expect(reader.readUint64(), equals(0x100000000));
      });

      test('writeTrun creates valid trun box with samples', () {
        final writer = Mp4BoxWriter();
        writer.writeTrun(
          samples: [
            const TrunSample(duration: 1024, size: 100, flags: 0x02000000),
            const TrunSample(duration: 1024, size: 200, flags: 0x01010000),
          ],
          dataOffset: 120,
        );

        final bytes = writer.toBytes();
        final reader = Mp4BoxReader(bytes);
        final box = reader.readBox();

        expect(box, isNotNull);
        expect(box!.type, equals('trun'));

        reader.enterBox(box);
        reader.skip(4); // version + flags
        final sampleCount = reader.readUint32();
        expect(sampleCount, equals(2));
      });
    });

    group('length tracking', () {
      test('length property reflects written bytes', () {
        final writer = Mp4BoxWriter();
        expect(writer.length, equals(0));

        writer.writeUint32(0);
        expect(writer.length, equals(4));

        writer.writeFourCC('test');
        expect(writer.length, equals(8));
      });

      test('toBytes clears buffer', () {
        final writer = Mp4BoxWriter();
        writer.writeUint32(0x12345678);
        expect(writer.length, equals(4));

        writer.toBytes();
        expect(writer.length, equals(0));
      });
    });
  });

  group('TrunSample', () {
    test('creates with all fields', () {
      const sample = TrunSample(duration: 1024, size: 100, flags: 0x02000000, compositionOffset: 500);

      expect(sample.duration, equals(1024));
      expect(sample.size, equals(100));
      expect(sample.flags, equals(0x02000000));
      expect(sample.compositionOffset, equals(500));
    });

    test('creates with partial fields', () {
      const sample = TrunSample(size: 100);

      expect(sample.duration, isNull);
      expect(sample.size, equals(100));
      expect(sample.flags, isNull);
      expect(sample.compositionOffset, isNull);
    });
  });
}
