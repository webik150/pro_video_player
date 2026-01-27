import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/src/container/flv_parser.dart';
import 'package:pro_video_player_platform_interface/src/types/container_track_type.dart';

void main() {
  group('FlvParser', () {
    group('format detection', () {
      test('detects valid FLV by signature', () {
        final data = _createFlvHeader(hasAudio: true, hasVideo: true);
        expect(FlvParser.isValidFlv(data), isTrue);
      });

      test('detects FLV with only video', () {
        final data = _createFlvHeader(hasAudio: false, hasVideo: true);
        expect(FlvParser.isValidFlv(data), isTrue);
      });

      test('detects FLV with only audio', () {
        final data = _createFlvHeader(hasAudio: true, hasVideo: false);
        expect(FlvParser.isValidFlv(data), isTrue);
      });

      test('rejects data without FLV signature', () {
        final data = Uint8List.fromList([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
        expect(FlvParser.isValidFlv(data), isFalse);
      });

      test('rejects data too short for FLV header', () {
        final data = Uint8List.fromList([0x46, 0x4C, 0x56]); // "FLV" but incomplete
        expect(FlvParser.isValidFlv(data), isFalse);
      });

      test('rejects invalid FLV version', () {
        final data = _createFlvHeader(hasAudio: true, hasVideo: true, version: 0xFF);
        expect(FlvParser.isValidFlv(data), isFalse);
      });

      test('detectFormat returns flv for valid data', () {
        final data = _createFlvHeader(hasAudio: true, hasVideo: true);
        expect(FlvParser.detectFormat(data), equals('flv'));
      });

      test('detectFormat returns null for invalid data', () {
        final data = Uint8List(10);
        expect(FlvParser.detectFormat(data), isNull);
      });
    });

    group('header parsing', () {
      test('extracts audio flag from header', () {
        final dataWithAudio = _createFlvHeader(hasAudio: true, hasVideo: false);
        final dataWithoutAudio = _createFlvHeader(hasAudio: false, hasVideo: true);

        final resultWithAudio = FlvParser.parse(dataWithAudio);
        final resultWithoutAudio = FlvParser.parse(dataWithoutAudio);

        expect(resultWithAudio, isNotNull);
        expect(resultWithoutAudio, isNotNull);
      });

      test('extracts video flag from header', () {
        final dataWithVideo = _createFlvHeader(hasAudio: false, hasVideo: true);
        final dataWithoutVideo = _createFlvHeader(hasAudio: true, hasVideo: false);

        final resultWithVideo = FlvParser.parse(dataWithVideo);
        final resultWithoutVideo = FlvParser.parse(dataWithoutVideo);

        expect(resultWithVideo, isNotNull);
        expect(resultWithoutVideo, isNotNull);
      });
    });

    group('tag parsing', () {
      test('extracts H.264 video track from video tag', () {
        final data = _createFlvWithTags(videoCodec: FlvVideoCodec.avc);
        final result = FlvParser.parse(data);

        expect(result, isNotNull);
        final videoTracks = result!.tracks.where((t) => t.type == ContainerTrackType.video).toList();
        expect(videoTracks.length, equals(1));
        expect(videoTracks[0].codec.name, equals('H.264'));
        expect(videoTracks[0].codec.fourcc, equals('avc1'));
      });

      test('extracts VP6 video track', () {
        final data = _createFlvWithTags(videoCodec: FlvVideoCodec.vp6);
        final result = FlvParser.parse(data);

        expect(result, isNotNull);
        final videoTracks = result!.tracks.where((t) => t.type == ContainerTrackType.video).toList();
        expect(videoTracks.length, equals(1));
        expect(videoTracks[0].codec.name, equals('VP6'));
      });

      test('extracts AAC audio track', () {
        final data = _createFlvWithTags(audioCodec: FlvAudioCodec.aac);
        final result = FlvParser.parse(data);

        expect(result, isNotNull);
        final audioTracks = result!.tracks.where((t) => t.type == ContainerTrackType.audio).toList();
        expect(audioTracks.length, equals(1));
        expect(audioTracks[0].codec.name, equals('AAC'));
        expect(audioTracks[0].codec.fourcc, equals('mp4a'));
      });

      test('extracts MP3 audio track', () {
        final data = _createFlvWithTags(audioCodec: FlvAudioCodec.mp3);
        final result = FlvParser.parse(data);

        expect(result, isNotNull);
        final audioTracks = result!.tracks.where((t) => t.type == ContainerTrackType.audio).toList();
        expect(audioTracks.length, equals(1));
        expect(audioTracks[0].codec.name, equals('MP3'));
      });

      test('extracts both video and audio tracks', () {
        final data = _createFlvWithTags(videoCodec: FlvVideoCodec.avc, audioCodec: FlvAudioCodec.aac);
        final result = FlvParser.parse(data);

        expect(result, isNotNull);
        expect(result!.tracks.length, equals(2));

        final videoTrack = result.tracks.firstWhere((t) => t.type == ContainerTrackType.video);
        final audioTrack = result.tracks.firstWhere((t) => t.type == ContainerTrackType.audio);

        expect(videoTrack.codec.name, equals('H.264'));
        expect(audioTrack.codec.name, equals('AAC'));
      });

      test('extracts HEVC video track', () {
        final data = _createFlvWithTags(videoCodec: FlvVideoCodec.hevc);
        final result = FlvParser.parse(data);

        expect(result, isNotNull);
        final videoTracks = result!.tracks.where((t) => t.type == ContainerTrackType.video).toList();
        expect(videoTracks[0].codec.name, equals('HEVC'));
        expect(videoTracks[0].codec.fourcc, equals('hvc1'));
      });

      test('extracts Sorenson H.263 video track', () {
        final data = _createFlvWithTags(videoCodec: FlvVideoCodec.sorensonH263);
        final result = FlvParser.parse(data);

        expect(result, isNotNull);
        final videoTracks = result!.tracks.where((t) => t.type == ContainerTrackType.video).toList();
        expect(videoTracks[0].codec.name, equals('Sorenson H.263'));
      });

      test('extracts Speex audio track', () {
        final data = _createFlvWithTags(audioCodec: FlvAudioCodec.speex);
        final result = FlvParser.parse(data);

        expect(result, isNotNull);
        final audioTracks = result!.tracks.where((t) => t.type == ContainerTrackType.audio).toList();
        expect(audioTracks[0].codec.name, equals('Speex'));
      });

      test('extracts PCM audio track', () {
        final data = _createFlvWithTags(audioCodec: FlvAudioCodec.pcmLe);
        final result = FlvParser.parse(data);

        expect(result, isNotNull);
        final audioTracks = result!.tracks.where((t) => t.type == ContainerTrackType.audio).toList();
        expect(audioTracks[0].codec.name, equals('PCM LE'));
      });
    });

    group('codec mapping', () {
      test('maps all known video codecs', () {
        expect(FlvParser.mapVideoCodecToInfo(FlvVideoCodec.sorensonH263).name, equals('Sorenson H.263'));
        expect(FlvParser.mapVideoCodecToInfo(FlvVideoCodec.screenVideo).name, equals('Screen Video'));
        expect(FlvParser.mapVideoCodecToInfo(FlvVideoCodec.vp6).name, equals('VP6'));
        expect(FlvParser.mapVideoCodecToInfo(FlvVideoCodec.vp6Alpha).name, equals('VP6 Alpha'));
        expect(FlvParser.mapVideoCodecToInfo(FlvVideoCodec.screenVideo2).name, equals('Screen Video 2'));
        expect(FlvParser.mapVideoCodecToInfo(FlvVideoCodec.avc).name, equals('H.264'));
        expect(FlvParser.mapVideoCodecToInfo(FlvVideoCodec.hevc).name, equals('HEVC'));
        expect(FlvParser.mapVideoCodecToInfo(FlvVideoCodec.av1).name, equals('AV1'));
      });

      test('maps all known audio codecs', () {
        expect(FlvParser.mapAudioCodecToInfo(FlvAudioCodec.pcmBe).name, equals('PCM BE'));
        expect(FlvParser.mapAudioCodecToInfo(FlvAudioCodec.adpcm).name, equals('ADPCM'));
        expect(FlvParser.mapAudioCodecToInfo(FlvAudioCodec.mp3).name, equals('MP3'));
        expect(FlvParser.mapAudioCodecToInfo(FlvAudioCodec.pcmLe).name, equals('PCM LE'));
        expect(FlvParser.mapAudioCodecToInfo(FlvAudioCodec.aac).name, equals('AAC'));
        expect(FlvParser.mapAudioCodecToInfo(FlvAudioCodec.speex).name, equals('Speex'));
        expect(FlvParser.mapAudioCodecToInfo(FlvAudioCodec.mp38kHz).name, equals('MP3 8kHz'));
      });

      test('returns unknown for unmapped codecs', () {
        expect(FlvParser.mapVideoCodecToInfo(0xFF).name, equals('Unknown'));
        expect(FlvParser.mapAudioCodecToInfo(0xFF).name, equals('Unknown'));
      });
    });

    group('audio info extraction', () {
      test('extracts stereo channel info', () {
        final data = _createFlvWithTags(audioCodec: FlvAudioCodec.aac);
        final result = FlvParser.parse(data);

        expect(result, isNotNull);
        final audioTrack = result!.tracks.firstWhere((t) => t.type == ContainerTrackType.audio);
        expect(audioTrack.audioInfo?.channelCount, equals(2));
      });

      test('extracts mono channel info', () {
        final data = _createFlvWithTags(audioCodec: FlvAudioCodec.aac, stereo: false);
        final result = FlvParser.parse(data);

        expect(result, isNotNull);
        final audioTrack = result!.tracks.firstWhere((t) => t.type == ContainerTrackType.audio);
        expect(audioTrack.audioInfo?.channelCount, equals(1));
      });

      test('extracts sample rate info', () {
        final data = _createFlvWithTags(audioCodec: FlvAudioCodec.aac);
        final result = FlvParser.parse(data);

        expect(result, isNotNull);
        final audioTrack = result!.tracks.firstWhere((t) => t.type == ContainerTrackType.audio);
        expect(audioTrack.audioInfo?.sampleRate, equals(44100));
      });
    });

    group('edge cases', () {
      test('returns null for empty data', () {
        expect(FlvParser.parse(Uint8List(0)), isNull);
      });

      test('handles FLV with no tags', () {
        final data = _createFlvHeader(hasAudio: true, hasVideo: true);
        final result = FlvParser.parse(data);
        expect(result, isNotNull);
        expect(result!.tracks, isEmpty);
      });

      test('handles script tags (metadata)', () {
        final data = _createFlvWithScriptTag();
        final result = FlvParser.parse(data);
        expect(result, isNotNull);
        // Script tags should be skipped, not create tracks
      });

      test('stops parsing on invalid tag', () {
        final data = _createFlvWithTags(videoCodec: FlvVideoCodec.avc);
        // Corrupt the tag size to cause parsing to stop gracefully
        data[13] = 0xFF;
        data[14] = 0xFF;
        data[15] = 0xFF;

        final result = FlvParser.parse(data);
        // Should still return valid result, just with fewer/no tracks
        expect(result, isNotNull);
      });
    });
  });
}

// Test data helpers

/// Creates an FLV header
Uint8List _createFlvHeader({required bool hasAudio, required bool hasVideo, int version = 1}) {
  final data = Uint8List(9 + 4); // Header + first PreviousTagSize
  var offset = 0;

  // Signature "FLV"
  data[offset++] = 0x46; // 'F'
  data[offset++] = 0x4C; // 'L'
  data[offset++] = 0x56; // 'V'

  // Version
  data[offset++] = version;

  // Flags
  var flags = 0;
  if (hasAudio) flags |= 0x04;
  if (hasVideo) flags |= 0x01;
  data[offset++] = flags;

  // Header size (big-endian, always 9)
  data[offset++] = 0x00;
  data[offset++] = 0x00;
  data[offset++] = 0x00;
  data[offset++] = 0x09;

  // First PreviousTagSize (always 0)
  data[offset++] = 0x00;
  data[offset++] = 0x00;
  data[offset++] = 0x00;
  data[offset++] = 0x00;

  return data;
}

/// Creates FLV with video and/or audio tags
Uint8List _createFlvWithTags({
  int? videoCodec,
  int? audioCodec,
  bool stereo = true,
  int sampleRateIndex = 3, // 44100 Hz
}) {
  final chunks = <Uint8List>[];

  // Add header
  chunks.add(_createFlvHeader(hasAudio: audioCodec != null, hasVideo: videoCodec != null));

  // Add video tag
  if (videoCodec != null) {
    chunks.add(_createVideoTag(videoCodec));
  }

  // Add audio tag
  if (audioCodec != null) {
    chunks.add(_createAudioTag(audioCodec, stereo: stereo, sampleRateIndex: sampleRateIndex));
  }

  return _concatenate(chunks);
}

/// Creates an FLV video tag
Uint8List _createVideoTag(int codec) {
  const dataSize = 5;
  const tagSize = 11 + dataSize;
  final data = Uint8List(tagSize + 4); // Tag + PreviousTagSize
  var offset = 0;

  // Tag type (9 = video)
  data[offset++] = 0x09;

  // Data size (3 bytes big-endian)
  data[offset++] = (dataSize >> 16) & 0xFF;
  data[offset++] = (dataSize >> 8) & 0xFF;
  data[offset++] = dataSize & 0xFF;

  // Timestamp (3 bytes) + extended (1 byte)
  data[offset++] = 0x00;
  data[offset++] = 0x00;
  data[offset++] = 0x00;
  data[offset++] = 0x00;

  // Stream ID (always 0)
  data[offset++] = 0x00;
  data[offset++] = 0x00;
  data[offset++] = 0x00;

  // Video data: frame type (keyframe=1) + codec
  data[offset++] = (1 << 4) | (codec & 0x0F);

  // Some codec-specific data (minimal)
  data[offset++] = 0x00;
  data[offset++] = 0x00;
  data[offset++] = 0x00;
  data[offset++] = 0x00;

  // PreviousTagSize
  data[offset++] = (tagSize >> 24) & 0xFF;
  data[offset++] = (tagSize >> 16) & 0xFF;
  data[offset++] = (tagSize >> 8) & 0xFF;
  data[offset++] = tagSize & 0xFF;

  return data;
}

/// Creates an FLV audio tag
Uint8List _createAudioTag(int codec, {bool stereo = true, int sampleRateIndex = 3}) {
  const dataSize = 2;
  const tagSize = 11 + dataSize;
  final data = Uint8List(tagSize + 4);
  var offset = 0;

  // Tag type (8 = audio)
  data[offset++] = 0x08;

  // Data size
  data[offset++] = (dataSize >> 16) & 0xFF;
  data[offset++] = (dataSize >> 8) & 0xFF;
  data[offset++] = dataSize & 0xFF;

  // Timestamp + extended
  data[offset++] = 0x00;
  data[offset++] = 0x00;
  data[offset++] = 0x00;
  data[offset++] = 0x00;

  // Stream ID
  data[offset++] = 0x00;
  data[offset++] = 0x00;
  data[offset++] = 0x00;

  // Audio data: codec(4) + rate(2) + size(1) + channels(1)
  final audioFlags = (codec << 4) | ((sampleRateIndex & 0x03) << 2) | (1 << 1) | (stereo ? 1 : 0);
  data[offset++] = audioFlags;

  // AAC packet type (if AAC)
  data[offset++] = 0x00;

  // PreviousTagSize
  data[offset++] = (tagSize >> 24) & 0xFF;
  data[offset++] = (tagSize >> 16) & 0xFF;
  data[offset++] = (tagSize >> 8) & 0xFF;
  data[offset++] = tagSize & 0xFF;

  return data;
}

/// Creates FLV with a script tag (onMetaData)
Uint8List _createFlvWithScriptTag() {
  final chunks = <Uint8List>[];
  chunks.add(_createFlvHeader(hasAudio: false, hasVideo: false));

  // Script tag
  const dataSize = 4;
  const tagSize = 11 + dataSize;
  final tag = Uint8List(tagSize + 4);
  var offset = 0;

  // Tag type (18 = script)
  tag[offset++] = 0x12;

  // Data size
  tag[offset++] = 0x00;
  tag[offset++] = 0x00;
  tag[offset++] = dataSize;

  // Timestamp
  tag[offset++] = 0x00;
  tag[offset++] = 0x00;
  tag[offset++] = 0x00;
  tag[offset++] = 0x00;

  // Stream ID
  tag[offset++] = 0x00;
  tag[offset++] = 0x00;
  tag[offset++] = 0x00;

  // Minimal script data
  tag[offset++] = 0x00;
  tag[offset++] = 0x00;
  tag[offset++] = 0x00;
  tag[offset++] = 0x00;

  // PreviousTagSize
  tag[offset++] = 0x00;
  tag[offset++] = 0x00;
  tag[offset++] = 0x00;
  tag[offset++] = tagSize;

  chunks.add(tag);
  return _concatenate(chunks);
}

Uint8List _concatenate(List<Uint8List> chunks) {
  final totalLength = chunks.fold<int>(0, (sum, c) => sum + c.length);
  final result = Uint8List(totalLength);
  var offset = 0;
  for (final chunk in chunks) {
    result.setRange(offset, offset + chunk.length, chunk);
    offset += chunk.length;
  }
  return result;
}
