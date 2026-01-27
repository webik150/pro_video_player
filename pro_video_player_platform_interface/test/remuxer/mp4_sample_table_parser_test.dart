import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/src/container/mp4_box_reader.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/mp4_sample_table.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/mp4_sample_table_parser.dart';

void main() {
  group('Mp4SampleTableParser', () {
    group('parse', () {
      test('returns null when missing required boxes', () {
        // stbl with only stco - missing stts and stsz
        final data = _buildStblBox(stcoOffsets: [1000, 2000]);
        final reader = Mp4BoxReader(data);
        final stblBox = reader.readBox()!;

        final table = Mp4SampleTableParser.parse(reader, stblBox, 1000);

        expect(table, isNull);
      });

      test('parses minimal stbl with stts and stsz', () {
        final data = _buildStblBox(
          sttsEntries: [(10, 1000)],
          sampleSizes: [100, 100, 100, 100, 100, 100, 100, 100, 100, 100],
        );
        final reader = Mp4BoxReader(data);
        final stblBox = reader.readBox()!;

        final table = Mp4SampleTableParser.parse(reader, stblBox, 90000);

        expect(table, isNotNull);
        expect(table!.timescale, equals(90000));
        expect(table.sampleCount, equals(10));
        expect(table.sttsEntries.length, equals(1));
      });

      test('parses complete stbl with all boxes', () {
        final data = _buildStblBox(
          sttsEntries: [(100, 3000)],
          stscEntries: [(1, 10, 1)],
          stcoOffsets: [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000],
          sampleSizes: List.generate(100, (i) => 1000 + i),
          stssSamples: [1, 11, 21, 31, 41, 51, 61, 71, 81, 91],
          cttsEntries: [(100, 1000)],
        );
        final reader = Mp4BoxReader(data);
        final stblBox = reader.readBox()!;

        final table = Mp4SampleTableParser.parse(reader, stblBox, 90000);

        expect(table, isNotNull);
        expect(table!.sampleCount, equals(100));
        expect(table.chunkCount, equals(10));
        expect(table.stscEntries.length, equals(1));
        expect(table.syncSamples.length, equals(10));
        expect(table.cttsEntries.length, equals(1));
      });
    });

    group('stts parsing', () {
      test('parses single entry stts', () {
        final data = _buildStblBox(sttsEntries: [(300, 3000)], sampleSizes: List.filled(300, 100));
        final reader = Mp4BoxReader(data);
        final stblBox = reader.readBox()!;

        final table = Mp4SampleTableParser.parse(reader, stblBox, 90000)!;

        expect(table.sttsEntries.length, equals(1));
        expect(table.sttsEntries[0].sampleCount, equals(300));
        expect(table.sttsEntries[0].sampleDelta, equals(3000));
      });

      test('parses multiple entry stts', () {
        final data = _buildStblBox(
          sttsEntries: [(100, 3000), (50, 1500), (100, 3000)],
          sampleSizes: List.filled(250, 100),
        );
        final reader = Mp4BoxReader(data);
        final stblBox = reader.readBox()!;

        final table = Mp4SampleTableParser.parse(reader, stblBox, 90000)!;

        expect(table.sttsEntries.length, equals(3));
        expect(table.sttsEntries[1].sampleCount, equals(50));
        expect(table.sttsEntries[1].sampleDelta, equals(1500));
      });
    });

    group('stsc parsing', () {
      test('parses stsc with single entry', () {
        final data = _buildStblBox(
          sttsEntries: [(10, 1000)],
          stscEntries: [(1, 5, 1)],
          sampleSizes: List.filled(10, 100),
        );
        final reader = Mp4BoxReader(data);
        final stblBox = reader.readBox()!;

        final table = Mp4SampleTableParser.parse(reader, stblBox, 1000)!;

        expect(table.stscEntries.length, equals(1));
        expect(table.stscEntries[0].firstChunk, equals(1));
        expect(table.stscEntries[0].samplesPerChunk, equals(5));
        expect(table.stscEntries[0].sampleDescriptionIndex, equals(1));
      });

      test('parses stsc with variable samples per chunk', () {
        final data = _buildStblBox(
          sttsEntries: [(15, 1000)],
          stscEntries: [(1, 10, 1), (2, 5, 1)],
          sampleSizes: List.filled(15, 100),
        );
        final reader = Mp4BoxReader(data);
        final stblBox = reader.readBox()!;

        final table = Mp4SampleTableParser.parse(reader, stblBox, 1000)!;

        expect(table.stscEntries.length, equals(2));
        expect(table.stscEntries[0].samplesPerChunk, equals(10));
        expect(table.stscEntries[1].firstChunk, equals(2));
        expect(table.stscEntries[1].samplesPerChunk, equals(5));
      });
    });

    group('stco/co64 parsing', () {
      test('parses 32-bit chunk offsets (stco)', () {
        final data = _buildStblBox(
          sttsEntries: [(10, 1000)],
          stcoOffsets: [1000, 2000, 3000],
          sampleSizes: List.filled(10, 100),
        );
        final reader = Mp4BoxReader(data);
        final stblBox = reader.readBox()!;

        final table = Mp4SampleTableParser.parse(reader, stblBox, 1000)!;

        expect(table.chunkOffsets, equals([1000, 2000, 3000]));
      });

      test('parses 64-bit chunk offsets (co64)', () {
        // Large offset that requires 64-bit
        final data = _buildStblBox(
          sttsEntries: [(10, 1000)],
          co64Offsets: [0x100000000, 0x200000000], // 4GB+
          sampleSizes: List.filled(10, 100),
        );
        final reader = Mp4BoxReader(data);
        final stblBox = reader.readBox()!;

        final table = Mp4SampleTableParser.parse(reader, stblBox, 1000)!;

        expect(table.chunkOffsets, equals([0x100000000, 0x200000000]));
      });
    });

    group('stsz parsing', () {
      test('parses variable size samples', () {
        final data = _buildStblBox(sttsEntries: [(5, 1000)], sampleSizes: [100, 200, 150, 250, 175]);
        final reader = Mp4BoxReader(data);
        final stblBox = reader.readBox()!;

        final table = Mp4SampleTableParser.parse(reader, stblBox, 1000)!;

        expect(table.sampleSizes, equals([100, 200, 150, 250, 175]));
      });

      test('parses uniform size samples', () {
        final data = _buildStblBoxWithUniformStsz(sttsEntries: [(100, 1000)], uniformSize: 512, sampleCount: 100);
        final reader = Mp4BoxReader(data);
        final stblBox = reader.readBox()!;

        final table = Mp4SampleTableParser.parse(reader, stblBox, 1000)!;

        expect(table.sampleCount, equals(100));
        expect(table.sampleSizes.every((s) => s == 512), isTrue);
      });
    });

    group('stz2 parsing', () {
      test('parses 4-bit sample sizes', () {
        final data = _buildStblBoxWithStz2(sttsEntries: [(6, 1000)], fieldSize: 4, sizes: [1, 2, 3, 4, 5, 6]);
        final reader = Mp4BoxReader(data);
        final stblBox = reader.readBox()!;

        final table = Mp4SampleTableParser.parse(reader, stblBox, 1000)!;

        expect(table.sampleSizes, equals([1, 2, 3, 4, 5, 6]));
      });

      test('parses 8-bit sample sizes', () {
        final data = _buildStblBoxWithStz2(sttsEntries: [(4, 1000)], fieldSize: 8, sizes: [10, 20, 30, 40]);
        final reader = Mp4BoxReader(data);
        final stblBox = reader.readBox()!;

        final table = Mp4SampleTableParser.parse(reader, stblBox, 1000)!;

        expect(table.sampleSizes, equals([10, 20, 30, 40]));
      });

      test('parses 16-bit sample sizes', () {
        final data = _buildStblBoxWithStz2(sttsEntries: [(3, 1000)], fieldSize: 16, sizes: [1000, 2000, 3000]);
        final reader = Mp4BoxReader(data);
        final stblBox = reader.readBox()!;

        final table = Mp4SampleTableParser.parse(reader, stblBox, 1000)!;

        expect(table.sampleSizes, equals([1000, 2000, 3000]));
      });
    });

    group('stss parsing', () {
      test('parses sync sample indices', () {
        final data = _buildStblBox(
          sttsEntries: [(100, 1000)],
          sampleSizes: List.filled(100, 100),
          stssSamples: [1, 15, 30, 45, 60, 75, 90],
        );
        final reader = Mp4BoxReader(data);
        final stblBox = reader.readBox()!;

        final table = Mp4SampleTableParser.parse(reader, stblBox, 1000)!;

        expect(table.syncSamples, equals([1, 15, 30, 45, 60, 75, 90]));
        expect(table.isSyncSample(0), isTrue); // index 0 = sample 1
        expect(table.isSyncSample(14), isTrue); // index 14 = sample 15
        expect(table.isSyncSample(10), isFalse);
      });
    });

    group('ctts parsing', () {
      test('parses version 0 ctts (unsigned offsets)', () {
        final data = _buildStblBox(
          sttsEntries: [(10, 1000)],
          sampleSizes: List.filled(10, 100),
          cttsEntries: [(5, 500), (5, 1000)],
        );
        final reader = Mp4BoxReader(data);
        final stblBox = reader.readBox()!;

        final table = Mp4SampleTableParser.parse(reader, stblBox, 1000)!;

        expect(table.cttsEntries.length, equals(2));
        expect(table.cttsEntries[0].sampleCount, equals(5));
        expect(table.cttsEntries[0].sampleOffset, equals(500));
        expect(table.cttsEntries[1].sampleOffset, equals(1000));
      });

      test('parses version 1 ctts (signed offsets)', () {
        final data = _buildStblBox(
          sttsEntries: [(10, 1000)],
          sampleSizes: List.filled(10, 100),
          cttsEntries: [(5, -500), (5, 1000)],
          cttsVersion: 1,
        );
        final reader = Mp4BoxReader(data);
        final stblBox = reader.readBox()!;

        final table = Mp4SampleTableParser.parse(reader, stblBox, 1000)!;

        expect(table.cttsEntries[0].sampleOffset, equals(-500));
        expect(table.cttsEntries[1].sampleOffset, equals(1000));
      });
    });

    group('integration tests', () {
      test('correctly locates samples after parsing', () {
        final data = _buildStblBox(
          sttsEntries: [(6, 1000)],
          stscEntries: [(1, 2, 1)],
          stcoOffsets: [1000, 2000, 3000],
          sampleSizes: [100, 100, 200, 200, 300, 300],
        );
        final reader = Mp4BoxReader(data);
        final stblBox = reader.readBox()!;

        final table = Mp4SampleTableParser.parse(reader, stblBox, 1000)!;

        // First chunk (samples 0, 1) at offset 1000
        expect(table.getSampleLocation(0), equals(const SampleLocation(offset: 1000, size: 100)));
        expect(table.getSampleLocation(1), equals(const SampleLocation(offset: 1100, size: 100)));

        // Second chunk (samples 2, 3) at offset 2000
        expect(table.getSampleLocation(2), equals(const SampleLocation(offset: 2000, size: 200)));
        expect(table.getSampleLocation(3), equals(const SampleLocation(offset: 2200, size: 200)));

        // Third chunk (samples 4, 5) at offset 3000
        expect(table.getSampleLocation(4), equals(const SampleLocation(offset: 3000, size: 300)));
        expect(table.getSampleLocation(5), equals(const SampleLocation(offset: 3300, size: 300)));
      });

      test('correctly calculates timestamps after parsing', () {
        final data = _buildStblBox(
          sttsEntries: [(30, 3000)], // 30 fps at 90000 timescale
          sampleSizes: List.filled(30, 100),
        );
        final reader = Mp4BoxReader(data);
        final stblBox = reader.readBox()!;

        final table = Mp4SampleTableParser.parse(reader, stblBox, 90000)!;

        // At 30fps with timescale 90000, each frame is 3000 ticks
        expect(table.getDecodingTime(0), equals(0));
        expect(table.getDecodingTime(30), equals(90000)); // 1 second

        // Find sample at 0.5 seconds (45000 ticks)
        expect(table.findSampleAtTime(45000), equals(15));
      });
    });
  });
}

// Helper functions to build test MP4 box structures

Uint8List _buildBox(String type, Uint8List content) {
  final totalSize = 8 + content.length;
  final data = Uint8List(totalSize);
  final view = ByteData.view(data.buffer);

  view.setUint32(0, totalSize);
  data.setRange(4, 8, type.codeUnits);
  data.setRange(8, totalSize, content);

  return data;
}

Uint8List _buildStblBox({
  List<(int sampleCount, int sampleDelta)>? sttsEntries,
  List<(int firstChunk, int samplesPerChunk, int sampleDescIndex)>? stscEntries,
  List<int>? stcoOffsets,
  List<int>? co64Offsets,
  List<int>? sampleSizes,
  List<int>? stssSamples,
  List<(int sampleCount, int sampleOffset)>? cttsEntries,
  int cttsVersion = 0,
}) {
  final boxes = <Uint8List>[];

  if (sttsEntries != null) {
    boxes.add(_buildSttsBox(sttsEntries));
  }

  if (stscEntries != null) {
    boxes.add(_buildStscBox(stscEntries));
  }

  if (stcoOffsets != null) {
    boxes.add(_buildStcoBox(stcoOffsets));
  }

  if (co64Offsets != null) {
    boxes.add(_buildCo64Box(co64Offsets));
  }

  if (sampleSizes != null) {
    boxes.add(_buildStszBox(sampleSizes));
  }

  if (stssSamples != null) {
    boxes.add(_buildStssBox(stssSamples));
  }

  if (cttsEntries != null) {
    boxes.add(_buildCttsBox(cttsEntries, cttsVersion));
  }

  final content = Uint8List.fromList(boxes.expand((b) => b).toList());
  return _buildBox('stbl', content);
}

Uint8List _buildStblBoxWithUniformStsz({
  required int uniformSize,
  required int sampleCount,
  List<(int sampleCount, int sampleDelta)>? sttsEntries,
}) {
  final boxes = <Uint8List>[];

  if (sttsEntries != null) {
    boxes.add(_buildSttsBox(sttsEntries));
  }

  boxes.add(_buildStszBoxUniform(uniformSize, sampleCount));

  final content = Uint8List.fromList(boxes.expand((b) => b).toList());
  return _buildBox('stbl', content);
}

Uint8List _buildStblBoxWithStz2({
  required int fieldSize,
  required List<int> sizes,
  List<(int sampleCount, int sampleDelta)>? sttsEntries,
}) {
  final boxes = <Uint8List>[];

  if (sttsEntries != null) {
    boxes.add(_buildSttsBox(sttsEntries));
  }

  boxes.add(_buildStz2Box(fieldSize, sizes));

  final content = Uint8List.fromList(boxes.expand((b) => b).toList());
  return _buildBox('stbl', content);
}

Uint8List _buildSttsBox(List<(int sampleCount, int sampleDelta)> entries) {
  final content = Uint8List(4 + 4 + entries.length * 8);
  final view = ByteData.view(content.buffer);

  view.setUint32(0, 0); // version + flags
  view.setUint32(4, entries.length);

  for (var i = 0; i < entries.length; i++) {
    view.setUint32(8 + i * 8, entries[i].$1);
    view.setUint32(8 + i * 8 + 4, entries[i].$2);
  }

  return _buildBox('stts', content);
}

Uint8List _buildStscBox(List<(int firstChunk, int samplesPerChunk, int sampleDescIndex)> entries) {
  final content = Uint8List(4 + 4 + entries.length * 12);
  final view = ByteData.view(content.buffer);

  view.setUint32(0, 0); // version + flags
  view.setUint32(4, entries.length);

  for (var i = 0; i < entries.length; i++) {
    view.setUint32(8 + i * 12, entries[i].$1);
    view.setUint32(8 + i * 12 + 4, entries[i].$2);
    view.setUint32(8 + i * 12 + 8, entries[i].$3);
  }

  return _buildBox('stsc', content);
}

Uint8List _buildStcoBox(List<int> offsets) {
  final content = Uint8List(4 + 4 + offsets.length * 4);
  final view = ByteData.view(content.buffer);

  view.setUint32(0, 0); // version + flags
  view.setUint32(4, offsets.length);

  for (var i = 0; i < offsets.length; i++) {
    view.setUint32(8 + i * 4, offsets[i]);
  }

  return _buildBox('stco', content);
}

Uint8List _buildCo64Box(List<int> offsets) {
  final content = Uint8List(4 + 4 + offsets.length * 8);
  final view = ByteData.view(content.buffer);

  view.setUint32(0, 0); // version + flags
  view.setUint32(4, offsets.length);

  for (var i = 0; i < offsets.length; i++) {
    view.setUint64(8 + i * 8, offsets[i]);
  }

  return _buildBox('co64', content);
}

Uint8List _buildStszBox(List<int> sizes) {
  final content = Uint8List(4 + 4 + 4 + sizes.length * 4);
  final view = ByteData.view(content.buffer);

  view.setUint32(0, 0); // version + flags
  view.setUint32(4, 0); // sample_size (0 = variable)
  view.setUint32(8, sizes.length);

  for (var i = 0; i < sizes.length; i++) {
    view.setUint32(12 + i * 4, sizes[i]);
  }

  return _buildBox('stsz', content);
}

Uint8List _buildStszBoxUniform(int uniformSize, int sampleCount) {
  final content = Uint8List(4 + 4 + 4);
  final view = ByteData.view(content.buffer);

  view.setUint32(0, 0); // version + flags
  view.setUint32(4, uniformSize);
  view.setUint32(8, sampleCount);

  return _buildBox('stsz', content);
}

Uint8List _buildStz2Box(int fieldSize, List<int> sizes) {
  final int contentSize;
  switch (fieldSize) {
    case 4:
      contentSize = 4 + 4 + 4 + (sizes.length + 1) ~/ 2;
    case 8:
      contentSize = 4 + 4 + 4 + sizes.length;
    case 16:
      contentSize = 4 + 4 + 4 + sizes.length * 2;
    default:
      contentSize = 4 + 4 + 4;
  }

  final content = Uint8List(contentSize);
  final view = ByteData.view(content.buffer);

  view.setUint32(0, 0); // version + flags
  // reserved (3 bytes) + field_size (1 byte)
  content[7] = fieldSize;
  view.setUint32(8, sizes.length);

  switch (fieldSize) {
    case 4:
      for (var i = 0; i < sizes.length; i += 2) {
        final high = sizes[i] & 0x0F;
        final low = (i + 1 < sizes.length) ? sizes[i + 1] & 0x0F : 0;
        content[12 + i ~/ 2] = (high << 4) | low;
      }
    case 8:
      for (var i = 0; i < sizes.length; i++) {
        content[12 + i] = sizes[i];
      }
    case 16:
      for (var i = 0; i < sizes.length; i++) {
        view.setUint16(12 + i * 2, sizes[i]);
      }
  }

  return _buildBox('stz2', content);
}

Uint8List _buildStssBox(List<int> syncSamples) {
  final content = Uint8List(4 + 4 + syncSamples.length * 4);
  final view = ByteData.view(content.buffer);

  view.setUint32(0, 0); // version + flags
  view.setUint32(4, syncSamples.length);

  for (var i = 0; i < syncSamples.length; i++) {
    view.setUint32(8 + i * 4, syncSamples[i]);
  }

  return _buildBox('stss', content);
}

Uint8List _buildCttsBox(List<(int sampleCount, int sampleOffset)> entries, int version) {
  final content = Uint8List(4 + 4 + entries.length * 8);
  final view = ByteData.view(content.buffer);

  view.setUint32(0, version << 24); // version + flags
  view.setUint32(4, entries.length);

  for (var i = 0; i < entries.length; i++) {
    view.setUint32(8 + i * 8, entries[i].$1);
    if (version == 0) {
      view.setUint32(8 + i * 8 + 4, entries[i].$2);
    } else {
      view.setInt32(8 + i * 8 + 4, entries[i].$2);
    }
  }

  return _buildBox('ctts', content);
}
