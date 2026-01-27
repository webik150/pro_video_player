import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

void main() {
  group('ContainerMetadata', () {
    const testCodec = CodecInfo(fourcc: 'avc1', name: 'H.264');
    const testAudioCodec = CodecInfo(fourcc: 'mp4a', name: 'AAC');
    const testSubtitleCodec = CodecInfo(fourcc: 'tx3g', name: '3GPP Timed Text');

    const videoTrack = ContainerTrack(
      id: 1,
      type: ContainerTrackType.video,
      codec: testCodec,
      videoInfo: VideoTrackInfo(width: 1920, height: 1080),
    );

    const audioTrack = ContainerTrack(
      id: 2,
      type: ContainerTrackType.audio,
      codec: testAudioCodec,
      language: 'eng',
      audioInfo: AudioTrackInfo(sampleRate: 48000, channelCount: 2),
    );

    const subtitleTrack = ContainerTrack(
      id: 3,
      type: ContainerTrackType.subtitle,
      codec: testSubtitleCodec,
      language: 'eng',
    );

    group('constructor', () {
      test('creates with required fields only', () {
        const metadata = ContainerMetadata(format: 'mp4', duration: Duration(minutes: 5), tracks: []);

        expect(metadata.format, equals('mp4'));
        expect(metadata.duration, equals(const Duration(minutes: 5)));
        expect(metadata.tracks, isEmpty);
        expect(metadata.creationTime, isNull);
        expect(metadata.modificationTime, isNull);
        expect(metadata.timescale, isNull);
        expect(metadata.compatibleBrands, isEmpty);
      });

      test('creates with all fields', () {
        final now = DateTime.now();
        final metadata = ContainerMetadata(
          format: 'mp4',
          duration: const Duration(minutes: 5),
          tracks: [videoTrack, audioTrack],
          creationTime: now,
          modificationTime: now,
          timescale: 90000,
          compatibleBrands: ['isom', 'iso2', 'avc1'],
        );

        expect(metadata.format, equals('mp4'));
        expect(metadata.duration, equals(const Duration(minutes: 5)));
        expect(metadata.tracks, hasLength(2));
        expect(metadata.creationTime, equals(now));
        expect(metadata.timescale, equals(90000));
        expect(metadata.compatibleBrands, contains('avc1'));
      });
    });

    group('empty', () {
      test('has default empty values', () {
        expect(ContainerMetadata.empty.format, equals(''));
        expect(ContainerMetadata.empty.duration, equals(Duration.zero));
        expect(ContainerMetadata.empty.tracks, isEmpty);
        expect(ContainerMetadata.empty.isEmpty, isTrue);
      });
    });

    group('isEmpty', () {
      test('returns true for empty format', () {
        const metadata = ContainerMetadata(format: '', duration: Duration.zero, tracks: []);
        expect(metadata.isEmpty, isTrue);
      });

      test('returns false when format is set', () {
        const metadata = ContainerMetadata(format: 'mp4', duration: Duration(minutes: 5), tracks: []);
        expect(metadata.isEmpty, isFalse);
      });
    });

    group('track accessors', () {
      const metadata = ContainerMetadata(
        format: 'mp4',
        duration: Duration(minutes: 5),
        tracks: [videoTrack, audioTrack, subtitleTrack],
      );

      test('primaryVideoTrack returns first video track', () {
        expect(metadata.primaryVideoTrack, equals(videoTrack));
      });

      test('primaryAudioTrack returns first audio track', () {
        expect(metadata.primaryAudioTrack, equals(audioTrack));
      });

      test('videoTracks filters correctly', () {
        expect(metadata.videoTracks, hasLength(1));
        expect(metadata.videoTracks.first, equals(videoTrack));
      });

      test('audioTracks filters correctly', () {
        expect(metadata.audioTracks, hasLength(1));
        expect(metadata.audioTracks.first, equals(audioTrack));
      });

      test('subtitleTracks filters correctly', () {
        expect(metadata.subtitleTracks, hasLength(1));
        expect(metadata.subtitleTracks.first, equals(subtitleTrack));
      });

      test('returns null when no video track', () {
        const audioOnly = ContainerMetadata(format: 'mp4', duration: Duration(minutes: 5), tracks: [audioTrack]);
        expect(audioOnly.primaryVideoTrack, isNull);
      });
    });

    group('fromMap', () {
      test('creates from complete map', () {
        final metadata = ContainerMetadata.fromMap({
          'format': 'mp4',
          'durationMs': 300000,
          'tracks': [
            {
              'id': 1,
              'type': 'video',
              'codec': {'fourcc': 'avc1', 'name': 'H.264'},
            },
            {
              'id': 2,
              'type': 'audio',
              'codec': {'fourcc': 'mp4a', 'name': 'AAC'},
            },
          ],
          'creationTimeMs': 1609459200000,
          'modificationTimeMs': 1609459200000,
          'timescale': 90000,
          'compatibleBrands': ['isom', 'iso2'],
        });

        expect(metadata.format, equals('mp4'));
        expect(metadata.duration, equals(const Duration(minutes: 5)));
        expect(metadata.tracks, hasLength(2));
        expect(metadata.timescale, equals(90000));
        expect(metadata.compatibleBrands, contains('isom'));
      });

      test('handles missing optional fields', () {
        final metadata = ContainerMetadata.fromMap({
          'format': 'mp4',
          'durationMs': 300000,
          'tracks': <Map<String, dynamic>>[],
        });

        expect(metadata.format, equals('mp4'));
        expect(metadata.creationTime, isNull);
        expect(metadata.compatibleBrands, isEmpty);
      });
    });

    group('toMap', () {
      test('converts all fields to map', () {
        final now = DateTime.fromMillisecondsSinceEpoch(1609459200000);
        final metadata = ContainerMetadata(
          format: 'mp4',
          duration: const Duration(minutes: 5),
          tracks: [videoTrack],
          creationTime: now,
          timescale: 90000,
          compatibleBrands: ['isom'],
        );

        final map = metadata.toMap();

        expect(map['format'], equals('mp4'));
        expect(map['durationMs'], equals(300000));
        expect(map['tracks'], hasLength(1));
        expect(map['creationTimeMs'], equals(1609459200000));
        expect(map['timescale'], equals(90000));
        expect(map['compatibleBrands'], contains('isom'));
      });

      test('excludes null fields', () {
        const metadata = ContainerMetadata(format: 'mp4', duration: Duration(minutes: 5), tracks: []);

        final map = metadata.toMap();

        expect(map.containsKey('format'), isTrue);
        expect(map.containsKey('durationMs'), isTrue);
        expect(map.containsKey('creationTimeMs'), isFalse);
        expect(map.containsKey('timescale'), isFalse);
      });
    });

    group('copyWith', () {
      test('creates copy with same values', () {
        const metadata = ContainerMetadata(format: 'mp4', duration: Duration(minutes: 5), tracks: [videoTrack]);

        final copy = metadata.copyWith();

        expect(copy, equals(metadata));
      });

      test('updates specific fields', () {
        const original = ContainerMetadata(format: 'mp4', duration: Duration(minutes: 5), tracks: []);

        final updated = original.copyWith(format: 'mov', timescale: 90000);

        expect(updated.format, equals('mov'));
        expect(updated.duration, equals(const Duration(minutes: 5)));
        expect(updated.timescale, equals(90000));
      });
    });

    group('equality', () {
      test('equal instances are equal', () {
        const a = ContainerMetadata(format: 'mp4', duration: Duration(minutes: 5), tracks: []);
        const b = ContainerMetadata(format: 'mp4', duration: Duration(minutes: 5), tracks: []);

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different format makes inequality', () {
        const a = ContainerMetadata(format: 'mp4', duration: Duration(minutes: 5), tracks: []);
        const b = ContainerMetadata(format: 'mov', duration: Duration(minutes: 5), tracks: []);

        expect(a, isNot(equals(b)));
      });

      test('different tracks makes inequality', () {
        const a = ContainerMetadata(format: 'mp4', duration: Duration(minutes: 5), tracks: [videoTrack]);
        const b = ContainerMetadata(format: 'mp4', duration: Duration(minutes: 5), tracks: []);

        expect(a, isNot(equals(b)));
      });
    });

    group('toString', () {
      test('returns readable representation', () {
        const metadata = ContainerMetadata(
          format: 'mp4',
          duration: Duration(minutes: 5),
          tracks: [videoTrack, audioTrack],
        );

        expect(metadata.toString(), contains('ContainerMetadata'));
        expect(metadata.toString(), contains('mp4'));
        expect(metadata.toString(), contains('2 tracks'));
      });
    });
  });
}
