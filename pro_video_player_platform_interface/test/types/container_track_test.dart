import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

void main() {
  group('ContainerTrack', () {
    const testCodec = CodecInfo(fourcc: 'avc1', name: 'H.264');
    const testVideoInfo = VideoTrackInfo(width: 1920, height: 1080);
    const testAudioInfo = AudioTrackInfo(sampleRate: 48000, channelCount: 2);

    group('constructor', () {
      test('creates with required fields only', () {
        const track = ContainerTrack(id: 1, type: ContainerTrackType.video, codec: testCodec);

        expect(track.id, equals(1));
        expect(track.type, equals(ContainerTrackType.video));
        expect(track.codec, equals(testCodec));
        expect(track.duration, isNull);
        expect(track.language, isNull);
        expect(track.bitrate, isNull);
        expect(track.sampleCount, isNull);
        expect(track.dataOffset, isNull);
        expect(track.videoInfo, isNull);
        expect(track.audioInfo, isNull);
      });

      test('creates video track with all fields', () {
        const track = ContainerTrack(
          id: 1,
          type: ContainerTrackType.video,
          codec: testCodec,
          duration: Duration(minutes: 5),
          language: 'und',
          bitrate: 5000000,
          sampleCount: 7500,
          dataOffset: 1024,
          videoInfo: testVideoInfo,
        );

        expect(track.id, equals(1));
        expect(track.type, equals(ContainerTrackType.video));
        expect(track.codec, equals(testCodec));
        expect(track.duration, equals(const Duration(minutes: 5)));
        expect(track.language, equals('und'));
        expect(track.bitrate, equals(5000000));
        expect(track.sampleCount, equals(7500));
        expect(track.dataOffset, equals(1024));
        expect(track.videoInfo, equals(testVideoInfo));
        expect(track.audioInfo, isNull);
      });

      test('creates audio track with all fields', () {
        const track = ContainerTrack(
          id: 2,
          type: ContainerTrackType.audio,
          codec: CodecInfo(fourcc: 'mp4a', name: 'AAC'),
          duration: Duration(minutes: 5),
          language: 'eng',
          bitrate: 128000,
          sampleCount: 14400000,
          audioInfo: testAudioInfo,
        );

        expect(track.id, equals(2));
        expect(track.type, equals(ContainerTrackType.audio));
        expect(track.language, equals('eng'));
        expect(track.bitrate, equals(128000));
        expect(track.audioInfo, equals(testAudioInfo));
        expect(track.videoInfo, isNull);
      });
    });

    group('isVideo', () {
      test('returns true for video track', () {
        const track = ContainerTrack(id: 1, type: ContainerTrackType.video, codec: testCodec);
        expect(track.isVideo, isTrue);
      });

      test('returns false for audio track', () {
        const track = ContainerTrack(id: 1, type: ContainerTrackType.audio, codec: testCodec);
        expect(track.isVideo, isFalse);
      });
    });

    group('isAudio', () {
      test('returns true for audio track', () {
        const track = ContainerTrack(id: 1, type: ContainerTrackType.audio, codec: testCodec);
        expect(track.isAudio, isTrue);
      });

      test('returns false for video track', () {
        const track = ContainerTrack(id: 1, type: ContainerTrackType.video, codec: testCodec);
        expect(track.isAudio, isFalse);
      });
    });

    group('isSubtitle', () {
      test('returns true for subtitle track', () {
        const track = ContainerTrack(
          id: 1,
          type: ContainerTrackType.subtitle,
          codec: CodecInfo(fourcc: 'tx3g', name: '3GPP Timed Text'),
        );
        expect(track.isSubtitle, isTrue);
      });

      test('returns false for video track', () {
        const track = ContainerTrack(id: 1, type: ContainerTrackType.video, codec: testCodec);
        expect(track.isSubtitle, isFalse);
      });
    });

    group('bitrateInKbps', () {
      test('returns bitrate in kbps', () {
        const track = ContainerTrack(id: 1, type: ContainerTrackType.video, codec: testCodec, bitrate: 5000000);
        expect(track.bitrateInKbps, equals(5000.0));
      });

      test('returns null when bitrate is null', () {
        const track = ContainerTrack(id: 1, type: ContainerTrackType.video, codec: testCodec);
        expect(track.bitrateInKbps, isNull);
      });
    });

    group('fromMap', () {
      test('creates from complete map', () {
        final track = ContainerTrack.fromMap({
          'id': 1,
          'type': 'video',
          'codec': {'fourcc': 'avc1', 'name': 'H.264'},
          'durationMs': 300000,
          'language': 'eng',
          'bitrate': 5000000,
          'sampleCount': 7500,
          'dataOffset': 1024,
          'videoInfo': {'width': 1920, 'height': 1080},
        });

        expect(track.id, equals(1));
        expect(track.type, equals(ContainerTrackType.video));
        expect(track.codec.fourcc, equals('avc1'));
        expect(track.duration, equals(const Duration(minutes: 5)));
        expect(track.language, equals('eng'));
        expect(track.bitrate, equals(5000000));
        expect(track.videoInfo?.width, equals(1920));
      });

      test('creates audio track from map', () {
        final track = ContainerTrack.fromMap({
          'id': 2,
          'type': 'audio',
          'codec': {'fourcc': 'mp4a', 'name': 'AAC'},
          'audioInfo': {'sampleRate': 48000, 'channelCount': 2},
        });

        expect(track.id, equals(2));
        expect(track.type, equals(ContainerTrackType.audio));
        expect(track.audioInfo?.sampleRate, equals(48000));
      });

      test('handles missing optional fields', () {
        final track = ContainerTrack.fromMap({
          'id': 1,
          'type': 'video',
          'codec': {'fourcc': 'avc1', 'name': 'H.264'},
        });

        expect(track.id, equals(1));
        expect(track.duration, isNull);
        expect(track.language, isNull);
        expect(track.videoInfo, isNull);
      });
    });

    group('toMap', () {
      test('converts all fields to map', () {
        const track = ContainerTrack(
          id: 1,
          type: ContainerTrackType.video,
          codec: testCodec,
          duration: Duration(minutes: 5),
          language: 'eng',
          bitrate: 5000000,
          videoInfo: testVideoInfo,
        );

        final map = track.toMap();

        expect(map['id'], equals(1));
        expect(map['type'], equals('video'));
        expect((map['codec'] as Map<String, dynamic>)['fourcc'], equals('avc1'));
        expect(map['durationMs'], equals(300000));
        expect(map['language'], equals('eng'));
        expect(map['bitrate'], equals(5000000));
        expect((map['videoInfo'] as Map<String, dynamic>)['width'], equals(1920));
      });

      test('excludes null fields', () {
        const track = ContainerTrack(id: 1, type: ContainerTrackType.video, codec: testCodec);

        final map = track.toMap();

        expect(map.containsKey('id'), isTrue);
        expect(map.containsKey('type'), isTrue);
        expect(map.containsKey('codec'), isTrue);
        expect(map.containsKey('duration'), isFalse);
        expect(map.containsKey('language'), isFalse);
        expect(map.containsKey('videoInfo'), isFalse);
      });
    });

    group('copyWith', () {
      test('creates copy with same values', () {
        const original = ContainerTrack(id: 1, type: ContainerTrackType.video, codec: testCodec, language: 'eng');

        final copy = original.copyWith();

        expect(copy, equals(original));
      });

      test('updates specific fields', () {
        const original = ContainerTrack(id: 1, type: ContainerTrackType.video, codec: testCodec);

        final updated = original.copyWith(language: 'fra', bitrate: 3000000);

        expect(updated.id, equals(1));
        expect(updated.type, equals(ContainerTrackType.video));
        expect(updated.language, equals('fra'));
        expect(updated.bitrate, equals(3000000));
      });
    });

    group('equality', () {
      test('equal instances are equal', () {
        const a = ContainerTrack(id: 1, type: ContainerTrackType.video, codec: testCodec);
        const b = ContainerTrack(id: 1, type: ContainerTrackType.video, codec: testCodec);

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different id makes inequality', () {
        const a = ContainerTrack(id: 1, type: ContainerTrackType.video, codec: testCodec);
        const b = ContainerTrack(id: 2, type: ContainerTrackType.video, codec: testCodec);

        expect(a, isNot(equals(b)));
      });

      test('different type makes inequality', () {
        const a = ContainerTrack(id: 1, type: ContainerTrackType.video, codec: testCodec);
        const b = ContainerTrack(id: 1, type: ContainerTrackType.audio, codec: testCodec);

        expect(a, isNot(equals(b)));
      });
    });

    group('toString', () {
      test('returns readable representation', () {
        const track = ContainerTrack(id: 1, type: ContainerTrackType.video, codec: testCodec);

        expect(track.toString(), contains('ContainerTrack'));
        expect(track.toString(), contains('video'));
        expect(track.toString(), contains('avc1'));
      });
    });
  });
}
