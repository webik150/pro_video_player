import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/src/container/mp4_box_reader.dart';
import 'package:pro_video_player_platform_interface/src/container/mp4_parser.dart';
import 'package:pro_video_player_platform_interface/src/types/container_track_type.dart';

void main() {
  group('Mp4Parser', () {
    group('detectFormat', () {
      test('detects mp4 from mp42 major brand', () {
        final data = _buildFtypBox('mp42', ['isom', 'mp42']);
        final reader = Mp4BoxReader(data);
        final box = reader.readBox()!;

        expect(Mp4Parser.detectFormat(reader, box), equals('mp4'));
      });

      test('detects mov from qt major brand', () {
        final data = _buildFtypBox('qt  ', ['qt  ']);
        final reader = Mp4BoxReader(data);
        final box = reader.readBox()!;

        expect(Mp4Parser.detectFormat(reader, box), equals('mov'));
      });

      test('detects m4a from M4A major brand', () {
        final data = _buildFtypBox('M4A ', ['isom', 'M4A ']);
        final reader = Mp4BoxReader(data);
        final box = reader.readBox()!;

        expect(Mp4Parser.detectFormat(reader, box), equals('m4a'));
      });

      test('detects m4v from M4V major brand', () {
        final data = _buildFtypBox('M4V ', ['isom', 'M4V ']);
        final reader = Mp4BoxReader(data);
        final box = reader.readBox()!;

        expect(Mp4Parser.detectFormat(reader, box), equals('m4v'));
      });

      test('detects 3gp from 3gp4 major brand', () {
        final data = _buildFtypBox('3gp4', ['isom', '3gp4']);
        final reader = Mp4BoxReader(data);
        final box = reader.readBox()!;

        expect(Mp4Parser.detectFormat(reader, box), equals('3gp'));
      });

      test('detects 3g2 from 3g2a major brand', () {
        final data = _buildFtypBox('3g2a', ['isom', '3g2a']);
        final reader = Mp4BoxReader(data);
        final box = reader.readBox()!;

        expect(Mp4Parser.detectFormat(reader, box), equals('3g2'));
      });

      test('detects mov from qt in compatible brands', () {
        final data = _buildFtypBox('isom', ['isom', 'qt  ']);
        final reader = Mp4BoxReader(data);
        final box = reader.readBox()!;

        expect(Mp4Parser.detectFormat(reader, box), equals('mov'));
      });

      test('defaults to mp4 for isom family', () {
        final data = _buildFtypBox('isom', ['isom', 'iso2', 'iso5']);
        final reader = Mp4BoxReader(data);
        final box = reader.readBox()!;

        expect(Mp4Parser.detectFormat(reader, box), equals('mp4'));
      });

      test('returns null for insufficient data', () {
        final data = Uint8List(4);
        final reader = Mp4BoxReader(data);

        // Can't even read a box header
        expect(reader.readBox(), isNull);
      });
    });

    group('parse', () {
      test('parses minimal mp4 with moov', () {
        final data = _buildMinimalMp4();
        final reader = Mp4BoxReader(data);

        final metadata = Mp4Parser.parse(reader, 'mp4');

        expect(metadata, isNotNull);
        expect(metadata!.format, equals('mp4'));
      });

      test('returns null when moov box missing', () {
        final ftyp = _buildFtypBox('mp42', ['isom']);
        final mdat = _buildBox('mdat', 1000);
        final data = Uint8List.fromList([...ftyp, ...mdat]);
        final reader = Mp4BoxReader(data);

        final metadata = Mp4Parser.parse(reader, 'mp4');

        expect(metadata, isNull);
      });

      test('extracts duration from mvhd', () {
        final data = _buildMp4WithMvhd(timescale: 1000, duration: 10000);
        final reader = Mp4BoxReader(data);

        final metadata = Mp4Parser.parse(reader, 'mp4');

        expect(metadata, isNotNull);
        expect(metadata!.duration.inSeconds, equals(10));
      });

      test('extracts timescale from mvhd', () {
        final data = _buildMp4WithMvhd(timescale: 90000, duration: 450000);
        final reader = Mp4BoxReader(data);

        final metadata = Mp4Parser.parse(reader, 'mp4');

        expect(metadata, isNotNull);
        expect(metadata!.timescale, equals(90000));
        expect(metadata.duration.inSeconds, equals(5));
      });

      test('handles version 1 mvhd with 64-bit duration', () {
        final data = _buildMp4WithMvhdV1(timescale: 1000, duration: 120000);
        final reader = Mp4BoxReader(data);

        final metadata = Mp4Parser.parse(reader, 'mp4');

        expect(metadata, isNotNull);
        expect(metadata!.duration.inMinutes, equals(2));
      });

      test('extracts compatible brands from ftyp', () {
        final data = _buildFtypWithMoov('mp42', ['isom', 'mp41', 'mp42', 'avc1']);
        final reader = Mp4BoxReader(data);

        final metadata = Mp4Parser.parse(reader, 'mp4');

        expect(metadata, isNotNull);
        expect(metadata!.compatibleBrands, containsAll(['isom', 'mp41', 'mp42', 'avc1']));
      });
    });

    group('track parsing', () {
      test('parses video track from trak box', () {
        final data = _buildMp4WithVideoTrack(width: 1920, height: 1080, codecFourcc: 'avc1');
        final reader = Mp4BoxReader(data);

        final metadata = Mp4Parser.parse(reader, 'mp4');

        expect(metadata, isNotNull);
        expect(metadata!.tracks.length, equals(1));
        expect(metadata.tracks[0].type, equals(ContainerTrackType.video));
        expect(metadata.tracks[0].codec.fourcc, equals('avc1'));
        expect(metadata.tracks[0].videoInfo?.width, equals(1920));
        expect(metadata.tracks[0].videoInfo?.height, equals(1080));
      });

      test('parses audio track from trak box', () {
        final data = _buildMp4WithAudioTrack(sampleRate: 48000, channelCount: 2, codecFourcc: 'mp4a');
        final reader = Mp4BoxReader(data);

        final metadata = Mp4Parser.parse(reader, 'mp4');

        expect(metadata, isNotNull);
        expect(metadata!.tracks.length, equals(1));
        expect(metadata.tracks[0].type, equals(ContainerTrackType.audio));
        expect(metadata.tracks[0].codec.fourcc, equals('mp4a'));
        expect(metadata.tracks[0].audioInfo?.sampleRate, equals(48000));
        expect(metadata.tracks[0].audioInfo?.channelCount, equals(2));
      });

      test('extracts language from mdhd', () {
        final data = _buildMp4WithAudioTrack(sampleRate: 48000, channelCount: 2, codecFourcc: 'mp4a', language: 'eng');
        final reader = Mp4BoxReader(data);

        final metadata = Mp4Parser.parse(reader, 'mp4');

        expect(metadata, isNotNull);
        expect(metadata!.tracks[0].language, equals('eng'));
      });

      test('parses multiple tracks', () {
        final data = _buildMp4WithMultipleTracks();
        final reader = Mp4BoxReader(data);

        final metadata = Mp4Parser.parse(reader, 'mp4');

        expect(metadata, isNotNull);
        expect(metadata!.tracks.length, equals(2));
        expect(metadata.videoTracks.length, equals(1));
        expect(metadata.audioTracks.length, equals(1));
      });
    });

    group('codec name mapping', () {
      test('maps common video codecs', () {
        final mappings = {
          'avc1': 'H.264',
          'avc3': 'H.264',
          'hvc1': 'HEVC',
          'hev1': 'HEVC',
          'vp08': 'VP8',
          'vp09': 'VP9',
          'av01': 'AV1',
        };

        for (final entry in mappings.entries) {
          final data = _buildMp4WithVideoTrack(width: 1920, height: 1080, codecFourcc: entry.key);
          final reader = Mp4BoxReader(data);
          final metadata = Mp4Parser.parse(reader, 'mp4');

          expect(metadata!.tracks[0].codec.name, equals(entry.value), reason: 'fourcc: ${entry.key}');
        }
      });

      test('maps common audio codecs', () {
        final mappings = {
          'mp4a': 'AAC',
          'ac-3': 'AC-3',
          'ec-3': 'E-AC-3',
          'opus': 'Opus',
          'alac': 'ALAC',
          'fLaC': 'FLAC',
        };

        for (final entry in mappings.entries) {
          final data = _buildMp4WithAudioTrack(sampleRate: 48000, channelCount: 2, codecFourcc: entry.key);
          final reader = Mp4BoxReader(data);
          final metadata = Mp4Parser.parse(reader, 'mp4');

          expect(metadata!.tracks[0].codec.name, equals(entry.value), reason: 'fourcc: ${entry.key}');
        }
      });
    });
  });
}

// Helper functions to build test MP4 structures

Uint8List _buildFtypBox(String majorBrand, List<String> compatibleBrands) {
  final brandCount = compatibleBrands.length;
  final size = 8 + 4 + 4 + (brandCount * 4);

  final data = Uint8List(size);
  final view = ByteData.view(data.buffer);

  view.setUint32(0, size);
  data.setRange(4, 8, 'ftyp'.codeUnits);
  data.setRange(8, 12, majorBrand.codeUnits);
  view.setUint32(12, 0);
  for (var i = 0; i < brandCount; i++) {
    data.setRange(16 + i * 4, 16 + i * 4 + 4, compatibleBrands[i].codeUnits);
  }

  return data;
}

Uint8List _buildBox(String type, int dataSize) {
  final totalSize = 8 + dataSize;
  final data = Uint8List(totalSize);
  final view = ByteData.view(data.buffer);

  view.setUint32(0, totalSize);
  data.setRange(4, 8, type.codeUnits);

  return data;
}

Uint8List _buildBoxWithContent(String type, Uint8List content) {
  final totalSize = 8 + content.length;
  final data = Uint8List(totalSize);
  final view = ByteData.view(data.buffer);

  view.setUint32(0, totalSize);
  data.setRange(4, 8, type.codeUnits);
  data.setRange(8, totalSize, content);

  return data;
}

Uint8List _buildMinimalMp4() {
  final ftyp = _buildFtypBox('mp42', ['isom', 'mp42']);
  final mvhd = _buildMvhd(timescale: 1000, duration: 0);
  final moov = _buildBoxWithContent('moov', mvhd);

  return Uint8List.fromList([...ftyp, ...moov]);
}

Uint8List _buildMp4WithMvhd({required int timescale, required int duration}) {
  final ftyp = _buildFtypBox('mp42', ['isom', 'mp42']);
  final mvhd = _buildMvhd(timescale: timescale, duration: duration);
  final moov = _buildBoxWithContent('moov', mvhd);

  return Uint8List.fromList([...ftyp, ...moov]);
}

Uint8List _buildMp4WithMvhdV1({required int timescale, required int duration}) {
  final ftyp = _buildFtypBox('mp42', ['isom', 'mp42']);
  final mvhd = _buildMvhdV1(timescale: timescale, duration: duration);
  final moov = _buildBoxWithContent('moov', mvhd);

  return Uint8List.fromList([...ftyp, ...moov]);
}

Uint8List _buildFtypWithMoov(String majorBrand, List<String> compatibleBrands) {
  final ftyp = _buildFtypBox(majorBrand, compatibleBrands);
  final mvhd = _buildMvhd(timescale: 1000, duration: 0);
  final moov = _buildBoxWithContent('moov', mvhd);

  return Uint8List.fromList([...ftyp, ...moov]);
}

Uint8List _buildMvhd({required int timescale, required int duration}) {
  const size = 108;
  final data = Uint8List(size);
  final view = ByteData.view(data.buffer);

  view.setUint32(0, size);
  data.setRange(4, 8, 'mvhd'.codeUnits);
  view.setUint32(8, 0); // version 0 + flags
  view.setUint32(12, 0); // creation_time
  view.setUint32(16, 0); // modification_time
  view.setUint32(20, timescale);
  view.setUint32(24, duration);
  view.setUint32(28, 0x00010000); // rate
  view.setUint16(32, 0x0100); // volume

  return data;
}

Uint8List _buildMvhdV1({required int timescale, required int duration}) {
  const size = 120;
  final data = Uint8List(size);
  final view = ByteData.view(data.buffer);

  view.setUint32(0, size);
  data.setRange(4, 8, 'mvhd'.codeUnits);
  view.setUint32(8, 0x01000000); // version 1 + flags
  view.setUint64(12, 0); // creation_time
  view.setUint64(20, 0); // modification_time
  view.setUint32(28, timescale);
  view.setUint64(32, duration);
  view.setUint32(40, 0x00010000); // rate
  view.setUint16(44, 0x0100); // volume

  return data;
}

Uint8List _buildMp4WithVideoTrack({required int width, required int height, required String codecFourcc}) {
  final ftyp = _buildFtypBox('mp42', ['isom', 'mp42']);
  final mvhd = _buildMvhd(timescale: 1000, duration: 5000);
  final trak = _buildVideoTrak(width: width, height: height, codecFourcc: codecFourcc);
  final moovContent = Uint8List.fromList([...mvhd, ...trak]);
  final moov = _buildBoxWithContent('moov', moovContent);

  return Uint8List.fromList([...ftyp, ...moov]);
}

Uint8List _buildMp4WithAudioTrack({
  required int sampleRate,
  required int channelCount,
  required String codecFourcc,
  String? language,
}) {
  final ftyp = _buildFtypBox('mp42', ['isom', 'mp42']);
  final mvhd = _buildMvhd(timescale: 1000, duration: 5000);
  final trak = _buildAudioTrak(
    sampleRate: sampleRate,
    channelCount: channelCount,
    codecFourcc: codecFourcc,
    language: language,
  );
  final moovContent = Uint8List.fromList([...mvhd, ...trak]);
  final moov = _buildBoxWithContent('moov', moovContent);

  return Uint8List.fromList([...ftyp, ...moov]);
}

Uint8List _buildMp4WithMultipleTracks() {
  final ftyp = _buildFtypBox('mp42', ['isom', 'mp42']);
  final mvhd = _buildMvhd(timescale: 1000, duration: 5000);
  final videoTrak = _buildVideoTrak(width: 1920, height: 1080, codecFourcc: 'avc1');
  final audioTrak = _buildAudioTrak(sampleRate: 48000, channelCount: 2, codecFourcc: 'mp4a');
  final moovContent = Uint8List.fromList([...mvhd, ...videoTrak, ...audioTrak]);
  final moov = _buildBoxWithContent('moov', moovContent);

  return Uint8List.fromList([...ftyp, ...moov]);
}

Uint8List _buildVideoTrak({required int width, required int height, required String codecFourcc}) {
  final tkhd = _buildTkhd(trackId: 1, width: width.toDouble(), height: height.toDouble());
  final mdia = _buildVideoMdia(width: width, height: height, codecFourcc: codecFourcc);
  final trakContent = Uint8List.fromList([...tkhd, ...mdia]);
  return _buildBoxWithContent('trak', trakContent);
}

Uint8List _buildAudioTrak({
  required int sampleRate,
  required int channelCount,
  required String codecFourcc,
  String? language,
}) {
  final tkhd = _buildTkhd(trackId: 2, width: 0, height: 0);
  final mdia = _buildAudioMdia(
    sampleRate: sampleRate,
    channelCount: channelCount,
    codecFourcc: codecFourcc,
    language: language,
  );
  final trakContent = Uint8List.fromList([...tkhd, ...mdia]);
  return _buildBoxWithContent('trak', trakContent);
}

Uint8List _buildTkhd({required int trackId, required double width, required double height}) {
  const size = 92;
  final data = Uint8List(size);
  final view = ByteData.view(data.buffer);

  view.setUint32(0, size);
  data.setRange(4, 8, 'tkhd'.codeUnits);
  view.setUint32(8, 0x00000003); // version 0, flags (enabled + in_movie)
  view.setUint32(12, 0); // creation_time
  view.setUint32(16, 0); // modification_time
  view.setUint32(20, trackId);
  view.setUint32(24, 0); // reserved
  view.setUint32(28, 5000); // duration
  // reserved[2] (8 bytes)
  // layer (2), alternate_group (2), volume (2), reserved (2) = 8 bytes
  // Matrix (36 bytes) - identity matrix
  view.setUint32(48, 0x00010000); // a = 1.0
  view.setUint32(60, 0x00010000); // d = 1.0
  view.setUint32(80, 0x40000000); // w = 1.0

  // width and height (16.16 fixed point)
  view.setUint32(84, width.toInt() << 16);
  view.setUint32(88, height.toInt() << 16);

  return data;
}

Uint8List _buildVideoMdia({required int width, required int height, required String codecFourcc}) {
  final mdhd = _buildMdhd(language: 'und');
  final hdlr = _buildHdlr('vide');
  final minf = _buildVideoMinf(width: width, height: height, codecFourcc: codecFourcc);
  final mdiaContent = Uint8List.fromList([...mdhd, ...hdlr, ...minf]);
  return _buildBoxWithContent('mdia', mdiaContent);
}

Uint8List _buildAudioMdia({
  required int sampleRate,
  required int channelCount,
  required String codecFourcc,
  String? language,
}) {
  final mdhd = _buildMdhd(language: language ?? 'und');
  final hdlr = _buildHdlr('soun');
  final minf = _buildAudioMinf(sampleRate: sampleRate, channelCount: channelCount, codecFourcc: codecFourcc);
  final mdiaContent = Uint8List.fromList([...mdhd, ...hdlr, ...minf]);
  return _buildBoxWithContent('mdia', mdiaContent);
}

Uint8List _buildMdhd({required String language}) {
  const size = 32;
  final data = Uint8List(size);
  final view = ByteData.view(data.buffer);

  view.setUint32(0, size);
  data.setRange(4, 8, 'mdhd'.codeUnits);
  view.setUint32(8, 0); // version 0 + flags
  view.setUint32(12, 0); // creation_time
  view.setUint32(16, 0); // modification_time
  view.setUint32(20, 1000); // timescale
  view.setUint32(24, 5000); // duration

  // Pack language (ISO 639-2/T)
  final c1 = language.codeUnitAt(0) - 0x60;
  final c2 = language.codeUnitAt(1) - 0x60;
  final c3 = language.codeUnitAt(2) - 0x60;
  final packed = ((c1 & 0x1F) << 10) | ((c2 & 0x1F) << 5) | (c3 & 0x1F);
  view.setUint16(28, packed);
  view.setUint16(30, 0); // pre_defined

  return data;
}

Uint8List _buildHdlr(String handlerType) {
  const size = 32;
  final data = Uint8List(size);
  final view = ByteData.view(data.buffer);

  view.setUint32(0, size);
  data.setRange(4, 8, 'hdlr'.codeUnits);
  view.setUint32(8, 0); // version + flags
  view.setUint32(12, 0); // pre_defined
  data.setRange(16, 20, handlerType.codeUnits);
  // reserved[3] (12 bytes)
  // name (null-terminated)

  return data;
}

Uint8List _buildVideoMinf({required int width, required int height, required String codecFourcc}) {
  final vmhd = _buildBox('vmhd', 12);
  final dinf = _buildDinf();
  final stbl = _buildVideoStbl(width: width, height: height, codecFourcc: codecFourcc);
  final minfContent = Uint8List.fromList([...vmhd, ...dinf, ...stbl]);
  return _buildBoxWithContent('minf', minfContent);
}

Uint8List _buildAudioMinf({required int sampleRate, required int channelCount, required String codecFourcc}) {
  final smhd = _buildBox('smhd', 8);
  final dinf = _buildDinf();
  final stbl = _buildAudioStbl(sampleRate: sampleRate, channelCount: channelCount, codecFourcc: codecFourcc);
  final minfContent = Uint8List.fromList([...smhd, ...dinf, ...stbl]);
  return _buildBoxWithContent('minf', minfContent);
}

Uint8List _buildDinf() {
  final dref = _buildBox('dref', 8);
  return _buildBoxWithContent('dinf', dref);
}

Uint8List _buildVideoStbl({required int width, required int height, required String codecFourcc}) {
  final stsd = _buildVideoStsd(width: width, height: height, codecFourcc: codecFourcc);
  final stts = _buildBox('stts', 8);
  final stsc = _buildBox('stsc', 8);
  final stsz = _buildStsz(sampleCount: 150);
  final stco = _buildBox('stco', 8);
  final stblContent = Uint8List.fromList([...stsd, ...stts, ...stsc, ...stsz, ...stco]);
  return _buildBoxWithContent('stbl', stblContent);
}

Uint8List _buildAudioStbl({required int sampleRate, required int channelCount, required String codecFourcc}) {
  final stsd = _buildAudioStsd(sampleRate: sampleRate, channelCount: channelCount, codecFourcc: codecFourcc);
  final stts = _buildBox('stts', 8);
  final stsc = _buildBox('stsc', 8);
  final stsz = _buildStsz(sampleCount: 5000);
  final stco = _buildBox('stco', 8);
  final stblContent = Uint8List.fromList([...stsd, ...stts, ...stsc, ...stsz, ...stco]);
  return _buildBoxWithContent('stbl', stblContent);
}

Uint8List _buildVideoStsd({required int width, required int height, required String codecFourcc}) {
  final sampleEntry = _buildVideoSampleEntry(width: width, height: height, codecFourcc: codecFourcc);
  final stsdContent = Uint8List(8 + sampleEntry.length);
  final view = ByteData.view(stsdContent.buffer);
  view.setUint32(0, 0); // version + flags
  view.setUint32(4, 1); // entry_count
  stsdContent.setRange(8, 8 + sampleEntry.length, sampleEntry);

  return _buildBoxWithContent('stsd', stsdContent);
}

Uint8List _buildAudioStsd({required int sampleRate, required int channelCount, required String codecFourcc}) {
  final sampleEntry = _buildAudioSampleEntry(
    sampleRate: sampleRate,
    channelCount: channelCount,
    codecFourcc: codecFourcc,
  );
  final stsdContent = Uint8List(8 + sampleEntry.length);
  final view = ByteData.view(stsdContent.buffer);
  view.setUint32(0, 0); // version + flags
  view.setUint32(4, 1); // entry_count
  stsdContent.setRange(8, 8 + sampleEntry.length, sampleEntry);

  return _buildBoxWithContent('stsd', stsdContent);
}

Uint8List _buildVideoSampleEntry({required int width, required int height, required String codecFourcc}) {
  const size = 86;
  final data = Uint8List(size);
  final view = ByteData.view(data.buffer);

  view.setUint32(0, size);
  data.setRange(4, 8, codecFourcc.codeUnits);
  // reserved (6 bytes)
  view.setUint16(14, 1); // data_reference_index
  // pre_defined (2), reserved (2), pre_defined[3] (12) = 16 bytes
  view.setUint16(32, width);
  view.setUint16(34, height);
  view.setUint32(36, 0x00480000); // horizresolution
  view.setUint32(40, 0x00480000); // vertresolution
  view.setUint32(44, 0); // reserved
  view.setUint16(48, 1); // frame_count
  // compressorname (32 bytes)
  view.setUint16(82, 24); // depth
  view.setInt16(84, -1); // pre_defined

  return data;
}

Uint8List _buildAudioSampleEntry({required int sampleRate, required int channelCount, required String codecFourcc}) {
  const size = 36;
  final data = Uint8List(size);
  final view = ByteData.view(data.buffer);

  view.setUint32(0, size);
  data.setRange(4, 8, codecFourcc.codeUnits);
  // reserved (6 bytes)
  view.setUint16(14, 1); // data_reference_index
  // reserved[2] (8 bytes)
  view.setUint16(24, channelCount);
  view.setUint16(26, 16); // sampleSize
  view.setUint16(28, 0); // pre_defined
  view.setUint16(30, 0); // reserved
  view.setUint32(32, sampleRate << 16); // 16.16 fixed point

  return data;
}

Uint8List _buildStsz({required int sampleCount}) {
  const headerSize = 8 + 4 + 4 + 4; // box header + version/flags + sample_size + sample_count
  final data = Uint8List(headerSize);
  final view = ByteData.view(data.buffer);

  view.setUint32(0, headerSize);
  data.setRange(4, 8, 'stsz'.codeUnits);
  view.setUint32(8, 0); // version + flags
  view.setUint32(12, 0); // sample_size (0 = variable)
  view.setUint32(16, sampleCount);

  return data;
}
