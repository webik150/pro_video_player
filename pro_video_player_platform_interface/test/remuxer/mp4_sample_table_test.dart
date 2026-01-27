import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/mp4_sample_table.dart';

void main() {
  group('SttsEntry', () {
    test('creates with required parameters', () {
      const entry = SttsEntry(sampleCount: 100, sampleDelta: 1024);

      expect(entry.sampleCount, equals(100));
      expect(entry.sampleDelta, equals(1024));
    });

    test('equality works correctly', () {
      const entry1 = SttsEntry(sampleCount: 100, sampleDelta: 1024);
      const entry2 = SttsEntry(sampleCount: 100, sampleDelta: 1024);
      const entry3 = SttsEntry(sampleCount: 200, sampleDelta: 1024);

      expect(entry1, equals(entry2));
      expect(entry1, isNot(equals(entry3)));
    });

    test('hashCode is consistent', () {
      const entry1 = SttsEntry(sampleCount: 100, sampleDelta: 1024);
      const entry2 = SttsEntry(sampleCount: 100, sampleDelta: 1024);

      expect(entry1.hashCode, equals(entry2.hashCode));
    });

    test('toString returns readable string', () {
      const entry = SttsEntry(sampleCount: 100, sampleDelta: 1024);
      expect(entry.toString(), contains('SttsEntry'));
      expect(entry.toString(), contains('100'));
      expect(entry.toString(), contains('1024'));
    });
  });

  group('StscEntry', () {
    test('creates with required parameters', () {
      const entry = StscEntry(firstChunk: 1, samplesPerChunk: 10, sampleDescriptionIndex: 1);

      expect(entry.firstChunk, equals(1));
      expect(entry.samplesPerChunk, equals(10));
      expect(entry.sampleDescriptionIndex, equals(1));
    });

    test('equality works correctly', () {
      const entry1 = StscEntry(firstChunk: 1, samplesPerChunk: 10, sampleDescriptionIndex: 1);
      const entry2 = StscEntry(firstChunk: 1, samplesPerChunk: 10, sampleDescriptionIndex: 1);
      const entry3 = StscEntry(firstChunk: 2, samplesPerChunk: 10, sampleDescriptionIndex: 1);

      expect(entry1, equals(entry2));
      expect(entry1, isNot(equals(entry3)));
    });
  });

  group('CttsEntry', () {
    test('creates with required parameters', () {
      const entry = CttsEntry(sampleCount: 50, sampleOffset: 1000);

      expect(entry.sampleCount, equals(50));
      expect(entry.sampleOffset, equals(1000));
    });

    test('supports negative offsets', () {
      const entry = CttsEntry(sampleCount: 50, sampleOffset: -500);

      expect(entry.sampleOffset, equals(-500));
    });

    test('equality works correctly', () {
      const entry1 = CttsEntry(sampleCount: 50, sampleOffset: 1000);
      const entry2 = CttsEntry(sampleCount: 50, sampleOffset: 1000);
      const entry3 = CttsEntry(sampleCount: 50, sampleOffset: 2000);

      expect(entry1, equals(entry2));
      expect(entry1, isNot(equals(entry3)));
    });
  });

  group('SampleLocation', () {
    test('creates with required parameters', () {
      const location = SampleLocation(offset: 1000, size: 256);

      expect(location.offset, equals(1000));
      expect(location.size, equals(256));
    });

    test('equality works correctly', () {
      const loc1 = SampleLocation(offset: 1000, size: 256);
      const loc2 = SampleLocation(offset: 1000, size: 256);
      const loc3 = SampleLocation(offset: 2000, size: 256);

      expect(loc1, equals(loc2));
      expect(loc1, isNot(equals(loc3)));
    });
  });

  group('Mp4SampleTable', () {
    test('creates with required timescale', () {
      const table = Mp4SampleTable(timescale: 90000);

      expect(table.timescale, equals(90000));
      expect(table.sampleCount, equals(0));
      expect(table.chunkCount, equals(0));
    });

    test('sampleCount reflects sampleSizes length', () {
      const table = Mp4SampleTable(timescale: 1000, sampleSizes: [100, 200, 300]);

      expect(table.sampleCount, equals(3));
    });

    test('chunkCount reflects chunkOffsets length', () {
      const table = Mp4SampleTable(timescale: 1000, chunkOffsets: [0, 1000, 2000]);

      expect(table.chunkCount, equals(3));
    });

    group('isSyncSample', () {
      test('returns true for all samples when syncSamples is empty', () {
        const table = Mp4SampleTable(timescale: 1000, sampleSizes: [100, 200, 300, 400, 500]);

        expect(table.isSyncSample(0), isTrue);
        expect(table.isSyncSample(1), isTrue);
        expect(table.isSyncSample(4), isTrue);
      });

      test('returns correct value when syncSamples specified', () {
        const table = Mp4SampleTable(
          timescale: 1000,
          sampleSizes: [100, 200, 300, 400, 500],
          syncSamples: [1, 3], // 1-based indices
        );

        expect(table.isSyncSample(0), isTrue); // index 0 = sample 1
        expect(table.isSyncSample(1), isFalse); // index 1 = sample 2
        expect(table.isSyncSample(2), isTrue); // index 2 = sample 3
        expect(table.isSyncSample(3), isFalse);
        expect(table.isSyncSample(4), isFalse);
      });

      test('hasExplicitSyncSamples is true when syncSamples not empty', () {
        const table1 = Mp4SampleTable(timescale: 1000);
        const table2 = Mp4SampleTable(timescale: 1000, syncSamples: [1, 5]);

        expect(table1.hasExplicitSyncSamples, isFalse);
        expect(table2.hasExplicitSyncSamples, isTrue);
      });
    });

    group('getDecodingTime', () {
      test('returns 0 for empty stts', () {
        const table = Mp4SampleTable(timescale: 1000);

        expect(table.getDecodingTime(0), equals(0));
        expect(table.getDecodingTime(100), equals(0));
      });

      test('returns correct DTS with uniform frame duration', () {
        // 30 fps video: 300 frames @ 3000 timescale units each
        const table = Mp4SampleTable(timescale: 90000, sttsEntries: [SttsEntry(sampleCount: 300, sampleDelta: 3000)]);

        expect(table.getDecodingTime(0), equals(0));
        expect(table.getDecodingTime(1), equals(3000));
        expect(table.getDecodingTime(30), equals(90000)); // 1 second
        expect(table.getDecodingTime(299), equals(897000));
      });

      test('returns correct DTS with variable frame durations', () {
        // Mix of different durations
        const table = Mp4SampleTable(
          timescale: 1000,
          sttsEntries: [
            SttsEntry(sampleCount: 10, sampleDelta: 100),
            SttsEntry(sampleCount: 5, sampleDelta: 200),
            SttsEntry(sampleCount: 10, sampleDelta: 50),
          ],
        );

        // First 10 samples: delta=100 each
        expect(table.getDecodingTime(0), equals(0));
        expect(table.getDecodingTime(9), equals(900));

        // Next 5 samples: delta=200 each, starting at time 1000
        expect(table.getDecodingTime(10), equals(1000));
        expect(table.getDecodingTime(14), equals(1800));

        // Last 10 samples: delta=50 each, starting at time 2000
        expect(table.getDecodingTime(15), equals(2000));
        expect(table.getDecodingTime(24), equals(2450));
      });

      test('returns 0 for negative index', () {
        const table = Mp4SampleTable(timescale: 1000, sttsEntries: [SttsEntry(sampleCount: 100, sampleDelta: 33)]);

        expect(table.getDecodingTime(-1), equals(0));
      });
    });

    group('getCompositionTime', () {
      test('returns DTS when no ctts entries', () {
        const table = Mp4SampleTable(timescale: 1000, sttsEntries: [SttsEntry(sampleCount: 100, sampleDelta: 33)]);

        expect(table.getCompositionTime(0), equals(0));
        expect(table.getCompositionTime(1), equals(33));
      });

      test('returns DTS + offset with ctts entries', () {
        const table = Mp4SampleTable(
          timescale: 1000,
          sttsEntries: [SttsEntry(sampleCount: 100, sampleDelta: 33)],
          cttsEntries: [CttsEntry(sampleCount: 100, sampleOffset: 66)],
        );

        // PTS = DTS + offset
        expect(table.getCompositionTime(0), equals(66)); // 0 + 66
        expect(table.getCompositionTime(1), equals(99)); // 33 + 66
      });

      test('handles variable ctts offsets', () {
        const table = Mp4SampleTable(
          timescale: 1000,
          sttsEntries: [SttsEntry(sampleCount: 20, sampleDelta: 100)],
          cttsEntries: [CttsEntry(sampleCount: 10, sampleOffset: 200), CttsEntry(sampleCount: 10, sampleOffset: 100)],
        );

        expect(table.getCompositionTime(0), equals(200)); // 0 + 200
        expect(table.getCompositionTime(9), equals(1100)); // 900 + 200
        expect(table.getCompositionTime(10), equals(1100)); // 1000 + 100
        expect(table.getCompositionTime(19), equals(2000)); // 1900 + 100
      });
    });

    group('getSampleDuration', () {
      test('returns 0 for empty stts', () {
        const table = Mp4SampleTable(timescale: 1000);

        expect(table.getSampleDuration(0), equals(0));
      });

      test('returns correct duration', () {
        const table = Mp4SampleTable(
          timescale: 1000,
          sttsEntries: [SttsEntry(sampleCount: 10, sampleDelta: 100), SttsEntry(sampleCount: 5, sampleDelta: 200)],
        );

        expect(table.getSampleDuration(0), equals(100));
        expect(table.getSampleDuration(9), equals(100));
        expect(table.getSampleDuration(10), equals(200));
        expect(table.getSampleDuration(14), equals(200));
      });
    });

    group('getSampleLocation', () {
      test('returns null for invalid index', () {
        const table = Mp4SampleTable(
          timescale: 1000,
          sampleSizes: [100, 200, 300],
          chunkOffsets: [1000],
          stscEntries: [StscEntry(firstChunk: 1, samplesPerChunk: 3, sampleDescriptionIndex: 1)],
        );

        expect(table.getSampleLocation(-1), isNull);
        expect(table.getSampleLocation(3), isNull);
        expect(table.getSampleLocation(100), isNull);
      });

      test('returns null when missing required data', () {
        const table1 = Mp4SampleTable(timescale: 1000, sampleSizes: [100]);
        const table2 = Mp4SampleTable(timescale: 1000, chunkOffsets: [1000]);

        expect(table1.getSampleLocation(0), isNull);
        expect(table2.getSampleLocation(0), isNull);
      });

      test('returns correct location for single chunk', () {
        const table = Mp4SampleTable(
          timescale: 1000,
          sampleSizes: [100, 200, 300],
          chunkOffsets: [1000],
          stscEntries: [StscEntry(firstChunk: 1, samplesPerChunk: 3, sampleDescriptionIndex: 1)],
        );

        expect(table.getSampleLocation(0), equals(const SampleLocation(offset: 1000, size: 100)));
        expect(table.getSampleLocation(1), equals(const SampleLocation(offset: 1100, size: 200)));
        expect(table.getSampleLocation(2), equals(const SampleLocation(offset: 1300, size: 300)));
      });

      test('returns correct location for multiple chunks', () {
        const table = Mp4SampleTable(
          timescale: 1000,
          sampleSizes: [100, 100, 200, 200],
          chunkOffsets: [1000, 2000],
          stscEntries: [StscEntry(firstChunk: 1, samplesPerChunk: 2, sampleDescriptionIndex: 1)],
        );

        // First chunk at offset 1000
        expect(table.getSampleLocation(0), equals(const SampleLocation(offset: 1000, size: 100)));
        expect(table.getSampleLocation(1), equals(const SampleLocation(offset: 1100, size: 100)));

        // Second chunk at offset 2000
        expect(table.getSampleLocation(2), equals(const SampleLocation(offset: 2000, size: 200)));
        expect(table.getSampleLocation(3), equals(const SampleLocation(offset: 2200, size: 200)));
      });

      test('handles variable samples per chunk', () {
        const table = Mp4SampleTable(
          timescale: 1000,
          sampleSizes: [100, 100, 100, 200, 300, 300],
          chunkOffsets: [1000, 2000, 3000],
          stscEntries: [
            StscEntry(firstChunk: 1, samplesPerChunk: 3, sampleDescriptionIndex: 1),
            StscEntry(firstChunk: 2, samplesPerChunk: 1, sampleDescriptionIndex: 1),
            StscEntry(firstChunk: 3, samplesPerChunk: 2, sampleDescriptionIndex: 1),
          ],
        );

        // First chunk: 3 samples
        expect(table.getSampleLocation(0), equals(const SampleLocation(offset: 1000, size: 100)));
        expect(table.getSampleLocation(2), equals(const SampleLocation(offset: 1200, size: 100)));

        // Second chunk: 1 sample
        expect(table.getSampleLocation(3), equals(const SampleLocation(offset: 2000, size: 200)));

        // Third chunk: 2 samples
        expect(table.getSampleLocation(4), equals(const SampleLocation(offset: 3000, size: 300)));
        expect(table.getSampleLocation(5), equals(const SampleLocation(offset: 3300, size: 300)));
      });
    });

    group('findSampleAtTime', () {
      test('returns 0 for empty stts', () {
        const table = Mp4SampleTable(timescale: 1000, sampleSizes: [100, 200, 300]);

        expect(table.findSampleAtTime(500), equals(0));
      });

      test('finds correct sample index', () {
        final table = Mp4SampleTable(
          timescale: 1000,
          sttsEntries: const [SttsEntry(sampleCount: 100, sampleDelta: 33)],
          sampleSizes: List.filled(100, 100),
        );

        expect(table.findSampleAtTime(0), equals(0));
        expect(table.findSampleAtTime(33), equals(1));
        expect(table.findSampleAtTime(66), equals(2));
        expect(table.findSampleAtTime(3300), equals(99)); // Clamped to sampleCount-1
      });

      test('finds nearest preceding keyframe when preferKeyframe is true', () {
        final table = Mp4SampleTable(
          timescale: 1000,
          sttsEntries: const [SttsEntry(sampleCount: 100, sampleDelta: 100)],
          sampleSizes: List.filled(100, 100),
          syncSamples: const [1, 11, 21, 31], // Keyframes at 0, 10, 20, 30 (0-based)
        );

        expect(table.findSampleAtTime(1500, preferKeyframe: true), equals(10)); // Time 1500 -> sample 15 -> keyframe 10
        expect(table.findSampleAtTime(2500, preferKeyframe: true), equals(20)); // Time 2500 -> sample 25 -> keyframe 20
      });
    });

    group('findNearestSyncSample', () {
      test('returns same index when no sync samples', () {
        const table = Mp4SampleTable(timescale: 1000);

        expect(table.findNearestSyncSample(5), equals(5));
        expect(table.findNearestSyncSample(5, searchBackward: false), equals(5));
      });

      test('finds nearest preceding sync sample', () {
        const table = Mp4SampleTable(
          timescale: 1000,
          syncSamples: [1, 11, 21, 31], // 1-based
        );

        expect(table.findNearestSyncSample(0), equals(0));
        expect(table.findNearestSyncSample(5), equals(0));
        expect(table.findNearestSyncSample(10), equals(10));
        expect(table.findNearestSyncSample(15), equals(10));
      });

      test('finds nearest following sync sample', () {
        const table = Mp4SampleTable(
          timescale: 1000,
          syncSamples: [1, 11, 21, 31], // 1-based
        );

        expect(table.findNearestSyncSample(0, searchBackward: false), equals(0));
        expect(table.findNearestSyncSample(5, searchBackward: false), equals(10));
        expect(table.findNearestSyncSample(15, searchBackward: false), equals(20));
        expect(table.findNearestSyncSample(50, searchBackward: false), equals(30)); // Last keyframe
      });
    });

    group('copyWith', () {
      test('creates copy with modified fields', () {
        const original = Mp4SampleTable(timescale: 1000, sampleSizes: [100, 200], syncSamples: [1]);

        final copy = original.copyWith(timescale: 2000, sampleSizes: [300, 400, 500]);

        expect(copy.timescale, equals(2000));
        expect(copy.sampleSizes, equals([300, 400, 500]));
        expect(copy.syncSamples, equals([1])); // Unchanged
      });

      test('preserves original fields when not specified', () {
        const original = Mp4SampleTable(timescale: 1000, sttsEntries: [SttsEntry(sampleCount: 10, sampleDelta: 100)]);

        final copy = original.copyWith();

        expect(copy.timescale, equals(1000));
        expect(copy.sttsEntries, equals(original.sttsEntries));
      });
    });

    test('toString returns readable string', () {
      const table = Mp4SampleTable(
        timescale: 1000,
        sampleSizes: [100, 200, 300],
        chunkOffsets: [1000, 2000],
        syncSamples: [1],
      );

      final str = table.toString();
      expect(str, contains('Mp4SampleTable'));
      expect(str, contains('samples: 3'));
      expect(str, contains('chunks: 2'));
      expect(str, contains('keyframes: 1'));
    });
  });
}
