import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

void main() {
  group('CodecInfo', () {
    group('constructor', () {
      test('creates with required fields only', () {
        const codec = CodecInfo(fourcc: 'avc1', name: 'H.264');

        expect(codec.fourcc, equals('avc1'));
        expect(codec.name, equals('H.264'));
        expect(codec.codecString, isNull);
        expect(codec.mimeType, isNull);
        expect(codec.profile, isNull);
        expect(codec.level, isNull);
      });

      test('creates with all fields', () {
        const codec = CodecInfo(
          fourcc: 'hvc1',
          name: 'HEVC',
          codecString: 'hvc1.1.6.L93.B0',
          mimeType: 'video/mp4; codecs=hvc1.1.6.L93.B0',
          profile: 1,
          level: 93,
        );

        expect(codec.fourcc, equals('hvc1'));
        expect(codec.name, equals('HEVC'));
        expect(codec.codecString, equals('hvc1.1.6.L93.B0'));
        expect(codec.mimeType, equals('video/mp4; codecs=hvc1.1.6.L93.B0'));
        expect(codec.profile, equals(1));
        expect(codec.level, equals(93));
      });
    });

    group('empty', () {
      test('has empty values', () {
        expect(CodecInfo.empty.fourcc, equals(''));
        expect(CodecInfo.empty.name, equals('Unknown'));
        expect(CodecInfo.empty.codecString, isNull);
        expect(CodecInfo.empty.mimeType, isNull);
        expect(CodecInfo.empty.profile, isNull);
        expect(CodecInfo.empty.level, isNull);
      });

      test('isEmpty returns true', () {
        expect(CodecInfo.empty.isEmpty, isTrue);
      });
    });

    group('isEmpty', () {
      test('returns true for empty fourcc', () {
        const codec = CodecInfo(fourcc: '', name: 'Test');
        expect(codec.isEmpty, isTrue);
      });

      test('returns false for non-empty fourcc', () {
        const codec = CodecInfo(fourcc: 'avc1', name: 'H.264');
        expect(codec.isEmpty, isFalse);
      });
    });

    group('isVideoCodec', () {
      test('returns true for H.264', () {
        const codec = CodecInfo(fourcc: 'avc1', name: 'H.264');
        expect(codec.isVideoCodec, isTrue);
      });

      test('returns true for HEVC variants', () {
        expect(const CodecInfo(fourcc: 'hvc1', name: 'HEVC').isVideoCodec, isTrue);
        expect(const CodecInfo(fourcc: 'hev1', name: 'HEVC').isVideoCodec, isTrue);
      });

      test('returns true for VP9', () {
        const codec = CodecInfo(fourcc: 'vp09', name: 'VP9');
        expect(codec.isVideoCodec, isTrue);
      });

      test('returns true for AV1', () {
        const codec = CodecInfo(fourcc: 'av01', name: 'AV1');
        expect(codec.isVideoCodec, isTrue);
      });

      test('returns false for AAC', () {
        const codec = CodecInfo(fourcc: 'mp4a', name: 'AAC');
        expect(codec.isVideoCodec, isFalse);
      });
    });

    group('isAudioCodec', () {
      test('returns true for AAC', () {
        const codec = CodecInfo(fourcc: 'mp4a', name: 'AAC');
        expect(codec.isAudioCodec, isTrue);
      });

      test('returns true for AC3', () {
        const codec = CodecInfo(fourcc: 'ac-3', name: 'AC3');
        expect(codec.isAudioCodec, isTrue);
      });

      test('returns true for EAC3', () {
        const codec = CodecInfo(fourcc: 'ec-3', name: 'EAC3');
        expect(codec.isAudioCodec, isTrue);
      });

      test('returns true for Opus', () {
        const codec = CodecInfo(fourcc: 'Opus', name: 'Opus');
        expect(codec.isAudioCodec, isTrue);
      });

      test('returns true for ALAC', () {
        const codec = CodecInfo(fourcc: 'alac', name: 'Apple Lossless');
        expect(codec.isAudioCodec, isTrue);
      });

      test('returns true for FLAC', () {
        const codec = CodecInfo(fourcc: 'fLaC', name: 'FLAC');
        expect(codec.isAudioCodec, isTrue);
      });

      test('returns false for H.264', () {
        const codec = CodecInfo(fourcc: 'avc1', name: 'H.264');
        expect(codec.isAudioCodec, isFalse);
      });
    });

    group('isSubtitleCodec', () {
      test('returns true for text subtitles', () {
        const codec = CodecInfo(fourcc: 'text', name: 'Text');
        expect(codec.isSubtitleCodec, isTrue);
      });

      test('returns true for tx3g', () {
        const codec = CodecInfo(fourcc: 'tx3g', name: '3GPP Timed Text');
        expect(codec.isSubtitleCodec, isTrue);
      });

      test('returns true for WebVTT', () {
        const codec = CodecInfo(fourcc: 'wvtt', name: 'WebVTT');
        expect(codec.isSubtitleCodec, isTrue);
      });

      test('returns true for STPP', () {
        const codec = CodecInfo(fourcc: 'stpp', name: 'TTML');
        expect(codec.isSubtitleCodec, isTrue);
      });

      test('returns false for video codec', () {
        const codec = CodecInfo(fourcc: 'avc1', name: 'H.264');
        expect(codec.isSubtitleCodec, isFalse);
      });
    });

    group('fromMap', () {
      test('creates from complete map', () {
        final codec = CodecInfo.fromMap({
          'fourcc': 'avc1',
          'name': 'H.264',
          'codecString': 'avc1.64001f',
          'mimeType': 'video/mp4; codecs=avc1.64001f',
          'profile': 100,
          'level': 31,
        });

        expect(codec.fourcc, equals('avc1'));
        expect(codec.name, equals('H.264'));
        expect(codec.codecString, equals('avc1.64001f'));
        expect(codec.mimeType, equals('video/mp4; codecs=avc1.64001f'));
        expect(codec.profile, equals(100));
        expect(codec.level, equals(31));
      });

      test('handles missing optional fields', () {
        final codec = CodecInfo.fromMap({'fourcc': 'avc1', 'name': 'H.264'});

        expect(codec.fourcc, equals('avc1'));
        expect(codec.name, equals('H.264'));
        expect(codec.codecString, isNull);
        expect(codec.mimeType, isNull);
        expect(codec.profile, isNull);
        expect(codec.level, isNull);
      });

      test('handles missing required fields with defaults', () {
        final codec = CodecInfo.fromMap(<String, dynamic>{});

        expect(codec.fourcc, equals(''));
        expect(codec.name, equals('Unknown'));
      });
    });

    group('toMap', () {
      test('converts all fields to map', () {
        const codec = CodecInfo(
          fourcc: 'hvc1',
          name: 'HEVC',
          codecString: 'hvc1.1.6.L93.B0',
          mimeType: 'video/mp4; codecs=hvc1.1.6.L93.B0',
          profile: 1,
          level: 93,
        );

        final map = codec.toMap();

        expect(map['fourcc'], equals('hvc1'));
        expect(map['name'], equals('HEVC'));
        expect(map['codecString'], equals('hvc1.1.6.L93.B0'));
        expect(map['mimeType'], equals('video/mp4; codecs=hvc1.1.6.L93.B0'));
        expect(map['profile'], equals(1));
        expect(map['level'], equals(93));
      });

      test('excludes null fields', () {
        const codec = CodecInfo(fourcc: 'avc1', name: 'H.264');

        final map = codec.toMap();

        expect(map.containsKey('fourcc'), isTrue);
        expect(map.containsKey('name'), isTrue);
        expect(map.containsKey('codecString'), isFalse);
        expect(map.containsKey('mimeType'), isFalse);
        expect(map.containsKey('profile'), isFalse);
        expect(map.containsKey('level'), isFalse);
      });
    });

    group('copyWith', () {
      test('creates copy with same values', () {
        const original = CodecInfo(
          fourcc: 'avc1',
          name: 'H.264',
          codecString: 'avc1.64001f',
          mimeType: 'video/mp4; codecs=avc1.64001f',
          profile: 100,
          level: 31,
        );

        final copy = original.copyWith();

        expect(copy, equals(original));
      });

      test('updates specific fields', () {
        const original = CodecInfo(fourcc: 'avc1', name: 'H.264');

        final updated = original.copyWith(
          codecString: 'avc1.64001f',
          mimeType: 'video/mp4; codecs=avc1.64001f',
          profile: 100,
        );

        expect(updated.fourcc, equals('avc1'));
        expect(updated.name, equals('H.264'));
        expect(updated.codecString, equals('avc1.64001f'));
        expect(updated.mimeType, equals('video/mp4; codecs=avc1.64001f'));
        expect(updated.profile, equals(100));
        expect(updated.level, isNull);
      });
    });

    group('equality', () {
      test('equal instances are equal', () {
        const a = CodecInfo(fourcc: 'avc1', name: 'H.264', profile: 100);
        const b = CodecInfo(fourcc: 'avc1', name: 'H.264', profile: 100);

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different fourcc makes inequality', () {
        const a = CodecInfo(fourcc: 'avc1', name: 'H.264');
        const b = CodecInfo(fourcc: 'hvc1', name: 'H.264');

        expect(a, isNot(equals(b)));
      });

      test('different name makes inequality', () {
        const a = CodecInfo(fourcc: 'avc1', name: 'H.264');
        const b = CodecInfo(fourcc: 'avc1', name: 'AVC');

        expect(a, isNot(equals(b)));
      });

      test('different profile makes inequality', () {
        const a = CodecInfo(fourcc: 'avc1', name: 'H.264', profile: 100);
        const b = CodecInfo(fourcc: 'avc1', name: 'H.264', profile: 77);

        expect(a, isNot(equals(b)));
      });

      test('different mimeType makes inequality', () {
        const a = CodecInfo(fourcc: 'avc1', name: 'H.264', mimeType: 'video/mp4; codecs=avc1');
        const b = CodecInfo(fourcc: 'avc1', name: 'H.264', mimeType: 'video/webm; codecs=avc1');

        expect(a, isNot(equals(b)));
      });
    });

    group('toString', () {
      test('returns readable representation', () {
        const codec = CodecInfo(fourcc: 'avc1', name: 'H.264', codecString: 'avc1.64001f');

        expect(codec.toString(), contains('CodecInfo'));
        expect(codec.toString(), contains('avc1'));
        expect(codec.toString(), contains('H.264'));
      });
    });
  });
}
