import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/mp4_sample_reader.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/mp4_sample_table.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/sample_reader.dart';

void main() {
  group('MediaSample', () {
    test('creates with required parameters', () {
      final sample = MediaSample(
        data: Uint8List.fromList([1, 2, 3, 4]),
        trackId: 1,
        sampleIndex: 0,
        decodeTimestamp: 0,
        compositionTimestamp: 1000,
        duration: 3000,
        isKeyframe: true,
      );

      expect(sample.data.length, equals(4));
      expect(sample.trackId, equals(1));
      expect(sample.sampleIndex, equals(0));
      expect(sample.decodeTimestamp, equals(0));
      expect(sample.compositionTimestamp, equals(1000));
      expect(sample.duration, equals(3000));
      expect(sample.isKeyframe, isTrue);
      expect(sample.size, equals(4));
    });

    test('toString returns readable string', () {
      final sample = MediaSample(
        data: Uint8List.fromList([1, 2, 3]),
        trackId: 1,
        sampleIndex: 5,
        decodeTimestamp: 15000,
        compositionTimestamp: 16000,
        duration: 3000,
        isKeyframe: false,
      );

      final str = sample.toString();
      expect(str, contains('MediaSample'));
      expect(str, contains('track: 1'));
      expect(str, contains('index: 5'));
      expect(str, contains('dts: 15000'));
      expect(str, contains('pts: 16000'));
    });
  });

  group('TrackCodecInfo', () {
    test('creates video track info', () {
      const info = TrackCodecInfo(trackId: 1, codecFourcc: 'avc1', timescale: 90000, width: 1920, height: 1080);

      expect(info.trackId, equals(1));
      expect(info.codecFourcc, equals('avc1'));
      expect(info.isVideo, isTrue);
      expect(info.isAudio, isFalse);
    });

    test('creates audio track info', () {
      const info = TrackCodecInfo(
        trackId: 2,
        codecFourcc: 'mp4a',
        timescale: 44100,
        sampleRate: 44100,
        channelCount: 2,
      );

      expect(info.trackId, equals(2));
      expect(info.codecFourcc, equals('mp4a'));
      expect(info.isVideo, isFalse);
      expect(info.isAudio, isTrue);
    });

    test('toString formats video track correctly', () {
      const info = TrackCodecInfo(trackId: 1, codecFourcc: 'avc1', timescale: 90000, width: 1920, height: 1080);

      expect(info.toString(), contains('1920x1080'));
      expect(info.toString(), contains('avc1'));
    });

    test('toString formats audio track correctly', () {
      const info = TrackCodecInfo(
        trackId: 2,
        codecFourcc: 'mp4a',
        timescale: 48000,
        sampleRate: 48000,
        channelCount: 2,
      );

      expect(info.toString(), contains('48000 Hz'));
      expect(info.toString(), contains('2 ch'));
    });

    group('isSubtitle', () {
      test('returns true for MP4 tx3g', () {
        const info = TrackCodecInfo(trackId: 3, codecFourcc: 'tx3g', timescale: 1000);
        expect(info.isSubtitle, isTrue);
      });

      test('returns true for MP4 stpp', () {
        const info = TrackCodecInfo(trackId: 3, codecFourcc: 'stpp', timescale: 1000);
        expect(info.isSubtitle, isTrue);
      });

      test('returns true for MP4 wvtt', () {
        const info = TrackCodecInfo(trackId: 3, codecFourcc: 'wvtt', timescale: 1000);
        expect(info.isSubtitle, isTrue);
      });

      test('returns true for MP4 c608', () {
        const info = TrackCodecInfo(trackId: 3, codecFourcc: 'c608', timescale: 1000);
        expect(info.isSubtitle, isTrue);
      });

      test('returns true for MP4 c708', () {
        const info = TrackCodecInfo(trackId: 3, codecFourcc: 'c708', timescale: 1000);
        expect(info.isSubtitle, isTrue);
      });

      test('returns true for MP4 text', () {
        const info = TrackCodecInfo(trackId: 3, codecFourcc: 'text', timescale: 1000);
        expect(info.isSubtitle, isTrue);
      });

      test('returns true for MKV S_TEXT/UTF8', () {
        const info = TrackCodecInfo(trackId: 3, codecFourcc: 's_text/utf8', timescale: 1000);
        expect(info.isSubtitle, isTrue);
      });

      test('returns true for MKV S_TEXT/ASS', () {
        const info = TrackCodecInfo(trackId: 3, codecFourcc: 's_text/ass', timescale: 1000);
        expect(info.isSubtitle, isTrue);
      });

      test('returns true for MKV S_TEXT/SSA', () {
        const info = TrackCodecInfo(trackId: 3, codecFourcc: 's_text/ssa', timescale: 1000);
        expect(info.isSubtitle, isTrue);
      });

      test('returns true for MKV S_TEXT/WEBVTT', () {
        const info = TrackCodecInfo(trackId: 3, codecFourcc: 's_text/webvtt', timescale: 1000);
        expect(info.isSubtitle, isTrue);
      });

      test('returns true for MKV S_HDMV/PGS', () {
        const info = TrackCodecInfo(trackId: 3, codecFourcc: 's_hdmv/pgs', timescale: 1000);
        expect(info.isSubtitle, isTrue);
      });

      test('returns true for TS DVB subtitles', () {
        const info = TrackCodecInfo(trackId: 3, codecFourcc: 'dvbs', timescale: 1000);
        expect(info.isSubtitle, isTrue);
      });

      test('returns true for TS ttxt', () {
        const info = TrackCodecInfo(trackId: 3, codecFourcc: 'ttxt', timescale: 1000);
        expect(info.isSubtitle, isTrue);
      });

      test('returns false for video codec', () {
        const info = TrackCodecInfo(trackId: 1, codecFourcc: 'avc1', timescale: 90000, width: 1920, height: 1080);
        expect(info.isSubtitle, isFalse);
      });

      test('returns false for audio codec', () {
        const info = TrackCodecInfo(
          trackId: 2,
          codecFourcc: 'mp4a',
          timescale: 44100,
          sampleRate: 44100,
          channelCount: 2,
        );
        expect(info.isSubtitle, isFalse);
      });

      test('returns false for unknown codec', () {
        const info = TrackCodecInfo(trackId: 3, codecFourcc: 'xxxx', timescale: 1000);
        expect(info.isSubtitle, isFalse);
      });

      test('is case insensitive', () {
        const info1 = TrackCodecInfo(trackId: 3, codecFourcc: 'TX3G', timescale: 1000);
        const info2 = TrackCodecInfo(trackId: 3, codecFourcc: 'S_TEXT/UTF8', timescale: 1000);
        expect(info1.isSubtitle, isTrue);
        expect(info2.isSubtitle, isTrue);
      });
    });

    test('toString formats subtitle track correctly', () {
      const info = TrackCodecInfo(trackId: 3, codecFourcc: 'tx3g', timescale: 1000);
      expect(info.toString(), contains('subtitle'));
      expect(info.toString(), contains('tx3g'));
    });
  });

  group('InMemorySampleReader', () {
    late Uint8List testData;
    late Mp4SampleTable sampleTable;
    late InMemorySampleReader reader;

    setUp(() {
      // Create test data: 6 samples of varying sizes at different offsets
      // Sample layout: [100 bytes][100 bytes][200 bytes][200 bytes][300 bytes][300 bytes]
      // Chunk 1 at offset 0: samples 0, 1 (size 100 each)
      // Chunk 2 at offset 200: samples 2, 3 (size 200 each)
      // Chunk 3 at offset 600: samples 4, 5 (size 300 each)
      testData = Uint8List(1200);
      // Fill with identifiable data
      for (var i = 0; i < 100; i++) {
        testData[i] = 0x01; // Sample 0
      }
      for (var i = 100; i < 200; i++) {
        testData[i] = 0x02; // Sample 1
      }
      for (var i = 200; i < 400; i++) {
        testData[i] = 0x03; // Sample 2
      }
      for (var i = 400; i < 600; i++) {
        testData[i] = 0x04; // Sample 3
      }
      for (var i = 600; i < 900; i++) {
        testData[i] = 0x05; // Sample 4
      }
      for (var i = 900; i < 1200; i++) {
        testData[i] = 0x06; // Sample 5
      }

      sampleTable = const Mp4SampleTable(
        timescale: 1000,
        sttsEntries: [SttsEntry(sampleCount: 6, sampleDelta: 1000)],
        stscEntries: [StscEntry(firstChunk: 1, samplesPerChunk: 2, sampleDescriptionIndex: 1)],
        chunkOffsets: [0, 200, 600],
        sampleSizes: [100, 100, 200, 200, 300, 300],
        syncSamples: [1, 4], // Samples 0 and 3 (0-based) are keyframes
      );

      reader = InMemorySampleReader(data: testData, sampleTable: sampleTable, trackId: 1);
    });

    test('properties are correct', () {
      expect(reader.trackId, equals(1));
      expect(reader.timescale, equals(1000));
      expect(reader.sampleCount, equals(6));
      expect(reader.totalDuration, equals(6000));
      expect(reader.currentIndex, equals(0));
      expect(reader.hasMoreSamples, isTrue);
    });

    test('readNextSample reads samples sequentially', () async {
      final sample0 = await reader.readNextSample();
      expect(sample0, isNotNull);
      expect(sample0!.sampleIndex, equals(0));
      expect(sample0.size, equals(100));
      expect(sample0.data.every((b) => b == 0x01), isTrue);
      expect(sample0.isKeyframe, isTrue); // First sample is keyframe
      expect(reader.currentIndex, equals(1));

      final sample1 = await reader.readNextSample();
      expect(sample1!.sampleIndex, equals(1));
      expect(sample1.size, equals(100));
      expect(sample1.data.every((b) => b == 0x02), isTrue);
      expect(sample1.isKeyframe, isFalse);

      final sample2 = await reader.readNextSample();
      expect(sample2!.sampleIndex, equals(2));
      expect(sample2.size, equals(200));
      expect(sample2.data.every((b) => b == 0x03), isTrue);
    });

    test('readSampleAt reads specific sample', () async {
      final sample3 = await reader.readSampleAt(3);
      expect(sample3, isNotNull);
      expect(sample3!.sampleIndex, equals(3));
      expect(sample3.size, equals(200));
      expect(sample3.data.every((b) => b == 0x04), isTrue);
      expect(sample3.isKeyframe, isTrue); // Sample 3 is a keyframe (stss index 4 = 1-based)
    });

    test('readSampleAt returns null for invalid index', () async {
      expect(await reader.readSampleAt(-1), isNull);
      expect(await reader.readSampleAt(100), isNull);
    });

    test('samples returns correct decode and composition timestamps', () async {
      final sample0 = await reader.readSampleAt(0);
      expect(sample0!.decodeTimestamp, equals(0));
      expect(sample0.compositionTimestamp, equals(0));
      expect(sample0.duration, equals(1000));

      final sample3 = await reader.readSampleAt(3);
      expect(sample3!.decodeTimestamp, equals(3000));
      expect(sample3.duration, equals(1000));
    });

    test('seekToIndex positions correctly', () async {
      reader.seekToIndex(3);
      expect(reader.currentIndex, equals(3));

      final sample = await reader.readNextSample();
      expect(sample!.sampleIndex, equals(3));
    });

    test('seekToIndex clamps to valid range', () {
      reader.seekToIndex(-10);
      expect(reader.currentIndex, equals(0));

      reader.seekToIndex(100);
      expect(reader.currentIndex, equals(5)); // sampleCount - 1
    });

    test('seekToTimestamp positions to correct sample', () async {
      final index = await reader.seekToTimestamp(2500);
      expect(index, equals(2)); // Sample at or before time 2500
      expect(reader.currentIndex, equals(2));
    });

    test('seekToTimestamp with toKeyframe finds preceding keyframe', () async {
      final index = await reader.seekToTimestamp(5000, toKeyframe: true);
      // Time 5000 is at sample 5, nearest preceding keyframe is sample 3
      expect(index, equals(3));
    });

    test('samples stream yields all samples', () async {
      final samples = await reader.samples().toList();

      expect(samples.length, equals(6));
      expect(samples[0].sampleIndex, equals(0));
      expect(samples[5].sampleIndex, equals(5));
    });

    test('hasMoreSamples is false after reading all samples', () async {
      await reader.samples().toList();
      expect(reader.hasMoreSamples, isFalse);
    });

    test('readNextSample returns null when no more samples', () async {
      await reader.samples().toList();
      expect(await reader.readNextSample(), isNull);
    });

    test('close does not throw', () async {
      await expectLater(reader.close(), completes);
    });
  });

  group('InMemorySampleReader with ctts', () {
    test('returns correct composition timestamps with offsets', () async {
      final testData = Uint8List(300);
      for (var i = 0; i < 300; i++) {
        testData[i] = (i ~/ 100) + 1;
      }

      const sampleTable = Mp4SampleTable(
        timescale: 1000,
        sttsEntries: [SttsEntry(sampleCount: 3, sampleDelta: 1000)],
        stscEntries: [StscEntry(firstChunk: 1, samplesPerChunk: 3, sampleDescriptionIndex: 1)],
        chunkOffsets: [0],
        sampleSizes: [100, 100, 100],
        cttsEntries: [CttsEntry(sampleCount: 3, sampleOffset: 500)],
      );

      final reader = InMemorySampleReader(data: testData, sampleTable: sampleTable, trackId: 1);

      final sample0 = await reader.readSampleAt(0);
      expect(sample0!.decodeTimestamp, equals(0));
      expect(sample0.compositionTimestamp, equals(500)); // DTS + offset

      final sample1 = await reader.readSampleAt(1);
      expect(sample1!.decodeTimestamp, equals(1000));
      expect(sample1.compositionTimestamp, equals(1500)); // DTS + offset
    });
  });

  group('Edge cases', () {
    test('handles empty sample table', () async {
      final testData = Uint8List(0);
      const sampleTable = Mp4SampleTable(timescale: 1000);

      final reader = InMemorySampleReader(data: testData, sampleTable: sampleTable, trackId: 1);

      expect(reader.sampleCount, equals(0));
      expect(reader.hasMoreSamples, isFalse);
      expect(await reader.readNextSample(), isNull);
    });

    test('handles single sample', () async {
      final testData = Uint8List.fromList(List.generate(50, (i) => i));
      const sampleTable = Mp4SampleTable(
        timescale: 1000,
        sttsEntries: [SttsEntry(sampleCount: 1, sampleDelta: 1000)],
        stscEntries: [StscEntry(firstChunk: 1, samplesPerChunk: 1, sampleDescriptionIndex: 1)],
        chunkOffsets: [0],
        sampleSizes: [50],
      );

      final reader = InMemorySampleReader(data: testData, sampleTable: sampleTable, trackId: 1);

      expect(reader.sampleCount, equals(1));
      final sample = await reader.readNextSample();
      expect(sample, isNotNull);
      expect(sample!.size, equals(50));
      expect(reader.hasMoreSamples, isFalse);
    });

    test('returns null when data buffer too small', () async {
      final testData = Uint8List(50); // Only 50 bytes
      const sampleTable = Mp4SampleTable(
        timescale: 1000,
        sttsEntries: [SttsEntry(sampleCount: 1, sampleDelta: 1000)],
        stscEntries: [StscEntry(firstChunk: 1, samplesPerChunk: 1, sampleDescriptionIndex: 1)],
        chunkOffsets: [0],
        sampleSizes: [100], // Sample needs 100 bytes
      );

      final reader = InMemorySampleReader(data: testData, sampleTable: sampleTable, trackId: 1);

      // Should return null because data is too small
      expect(await reader.readSampleAt(0), isNull);
    });
  });
}
