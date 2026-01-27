import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

void main() {
  group('AudioTrackInfo', () {
    group('constructor', () {
      test('creates with required fields only', () {
        const info = AudioTrackInfo(sampleRate: 48000, channelCount: 2);

        expect(info.sampleRate, equals(48000));
        expect(info.channelCount, equals(2));
        expect(info.bitsPerSample, isNull);
        expect(info.channelLayout, isNull);
      });

      test('creates with all fields', () {
        const info = AudioTrackInfo(sampleRate: 48000, channelCount: 6, bitsPerSample: 24, channelLayout: '5.1');

        expect(info.sampleRate, equals(48000));
        expect(info.channelCount, equals(6));
        expect(info.bitsPerSample, equals(24));
        expect(info.channelLayout, equals('5.1'));
      });
    });

    group('channelDescription', () {
      test('returns mono for 1 channel', () {
        const info = AudioTrackInfo(sampleRate: 48000, channelCount: 1);
        expect(info.channelDescription, equals('Mono'));
      });

      test('returns stereo for 2 channels', () {
        const info = AudioTrackInfo(sampleRate: 48000, channelCount: 2);
        expect(info.channelDescription, equals('Stereo'));
      });

      test('returns 5.1 for 6 channels', () {
        const info = AudioTrackInfo(sampleRate: 48000, channelCount: 6);
        expect(info.channelDescription, equals('5.1'));
      });

      test('returns 7.1 for 8 channels', () {
        const info = AudioTrackInfo(sampleRate: 48000, channelCount: 8);
        expect(info.channelDescription, equals('7.1'));
      });

      test('returns channel count for other values', () {
        const info = AudioTrackInfo(sampleRate: 48000, channelCount: 4);
        expect(info.channelDescription, equals('4 channels'));
      });

      test('uses channelLayout when available', () {
        const info = AudioTrackInfo(sampleRate: 48000, channelCount: 6, channelLayout: '5.1(side)');
        expect(info.channelDescription, equals('5.1(side)'));
      });
    });

    group('sampleRateKHz', () {
      test('returns sample rate in kHz', () {
        const info = AudioTrackInfo(sampleRate: 48000, channelCount: 2);
        expect(info.sampleRateKHz, equals(48.0));
      });

      test('returns 44.1 for CD quality', () {
        const info = AudioTrackInfo(sampleRate: 44100, channelCount: 2);
        expect(info.sampleRateKHz, equals(44.1));
      });
    });

    group('fromMap', () {
      test('creates from complete map', () {
        final info = AudioTrackInfo.fromMap({
          'sampleRate': 48000,
          'channelCount': 6,
          'bitsPerSample': 24,
          'channelLayout': '5.1',
        });

        expect(info.sampleRate, equals(48000));
        expect(info.channelCount, equals(6));
        expect(info.bitsPerSample, equals(24));
        expect(info.channelLayout, equals('5.1'));
      });

      test('handles missing optional fields', () {
        final info = AudioTrackInfo.fromMap({'sampleRate': 48000, 'channelCount': 2});

        expect(info.sampleRate, equals(48000));
        expect(info.channelCount, equals(2));
        expect(info.bitsPerSample, isNull);
        expect(info.channelLayout, isNull);
      });

      test('uses defaults for missing required fields', () {
        final info = AudioTrackInfo.fromMap(<String, dynamic>{});

        expect(info.sampleRate, equals(0));
        expect(info.channelCount, equals(0));
      });
    });

    group('toMap', () {
      test('converts all fields to map', () {
        const info = AudioTrackInfo(sampleRate: 48000, channelCount: 6, bitsPerSample: 24, channelLayout: '5.1');

        final map = info.toMap();

        expect(map['sampleRate'], equals(48000));
        expect(map['channelCount'], equals(6));
        expect(map['bitsPerSample'], equals(24));
        expect(map['channelLayout'], equals('5.1'));
      });

      test('excludes null fields', () {
        const info = AudioTrackInfo(sampleRate: 48000, channelCount: 2);

        final map = info.toMap();

        expect(map.containsKey('sampleRate'), isTrue);
        expect(map.containsKey('channelCount'), isTrue);
        expect(map.containsKey('bitsPerSample'), isFalse);
        expect(map.containsKey('channelLayout'), isFalse);
      });
    });

    group('copyWith', () {
      test('creates copy with same values', () {
        const original = AudioTrackInfo(sampleRate: 48000, channelCount: 2, bitsPerSample: 16);

        final copy = original.copyWith();

        expect(copy, equals(original));
      });

      test('updates specific fields', () {
        const original = AudioTrackInfo(sampleRate: 44100, channelCount: 2);

        final updated = original.copyWith(sampleRate: 48000, channelLayout: 'stereo');

        expect(updated.sampleRate, equals(48000));
        expect(updated.channelCount, equals(2));
        expect(updated.channelLayout, equals('stereo'));
      });
    });

    group('equality', () {
      test('equal instances are equal', () {
        const a = AudioTrackInfo(sampleRate: 48000, channelCount: 2);
        const b = AudioTrackInfo(sampleRate: 48000, channelCount: 2);

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different sampleRate makes inequality', () {
        const a = AudioTrackInfo(sampleRate: 48000, channelCount: 2);
        const b = AudioTrackInfo(sampleRate: 44100, channelCount: 2);

        expect(a, isNot(equals(b)));
      });

      test('different channelCount makes inequality', () {
        const a = AudioTrackInfo(sampleRate: 48000, channelCount: 2);
        const b = AudioTrackInfo(sampleRate: 48000, channelCount: 6);

        expect(a, isNot(equals(b)));
      });
    });

    group('toString', () {
      test('returns readable representation', () {
        const info = AudioTrackInfo(sampleRate: 48000, channelCount: 2);

        expect(info.toString(), contains('AudioTrackInfo'));
        expect(info.toString(), contains('48000'));
        expect(info.toString(), contains('2'));
      });
    });
  });
}
