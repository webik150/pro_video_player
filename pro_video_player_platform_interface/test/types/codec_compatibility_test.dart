import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/src/types/codec_compatibility.dart';
import 'package:pro_video_player_platform_interface/src/types/codec_info.dart';

void main() {
  group('CodecSupportLevel', () {
    test('has correct values', () {
      expect(CodecSupportLevel.values.length, equals(4));
      expect(CodecSupportLevel.values, contains(CodecSupportLevel.supported));
      expect(CodecSupportLevel.values, contains(CodecSupportLevel.probablySupported));
      expect(CodecSupportLevel.values, contains(CodecSupportLevel.notSupported));
      expect(CodecSupportLevel.values, contains(CodecSupportLevel.unknown));
    });

    test('isPlayable returns true for supported and probablySupported', () {
      expect(CodecSupportLevel.supported.isPlayable, isTrue);
      expect(CodecSupportLevel.probablySupported.isPlayable, isTrue);
      expect(CodecSupportLevel.notSupported.isPlayable, isFalse);
      expect(CodecSupportLevel.unknown.isPlayable, isFalse);
    });
  });

  group('CodecCompatibility', () {
    test('creates with required parameters', () {
      const codec = CodecInfo(fourcc: 'avc1', name: 'H.264');
      const compat = CodecCompatibility(codec: codec, supportLevel: CodecSupportLevel.supported);

      expect(compat.codec, equals(codec));
      expect(compat.supportLevel, equals(CodecSupportLevel.supported));
      expect(compat.message, isNull);
      expect(compat.minimumOsVersion, isNull);
      expect(compat.alternativeCodecs, isEmpty);
    });

    test('creates with all parameters', () {
      const codec = CodecInfo(fourcc: 'av01', name: 'AV1');
      const compat = CodecCompatibility(
        codec: codec,
        supportLevel: CodecSupportLevel.notSupported,
        message: 'Requires iOS 17+',
        minimumOsVersion: '17.0',
        alternativeCodecs: ['H.264', 'HEVC'],
      );

      expect(compat.codec, equals(codec));
      expect(compat.supportLevel, equals(CodecSupportLevel.notSupported));
      expect(compat.message, equals('Requires iOS 17+'));
      expect(compat.minimumOsVersion, equals('17.0'));
      expect(compat.alternativeCodecs, equals(['H.264', 'HEVC']));
    });

    test('isPlayable returns correct value based on supportLevel', () {
      const codec = CodecInfo(fourcc: 'avc1', name: 'H.264');

      expect(const CodecCompatibility(codec: codec, supportLevel: CodecSupportLevel.supported).isPlayable, isTrue);
      expect(
        const CodecCompatibility(codec: codec, supportLevel: CodecSupportLevel.probablySupported).isPlayable,
        isTrue,
      );
      expect(const CodecCompatibility(codec: codec, supportLevel: CodecSupportLevel.notSupported).isPlayable, isFalse);
      expect(const CodecCompatibility(codec: codec, supportLevel: CodecSupportLevel.unknown).isPlayable, isFalse);
    });

    test('fromMap creates instance correctly', () {
      final map = {
        'codec': {'fourcc': 'hvc1', 'name': 'HEVC'},
        'supportLevel': 'supported',
        'message': 'Fully supported',
        'minimumOsVersion': '11.0',
        'alternativeCodecs': ['H.264'],
      };

      final compat = CodecCompatibility.fromMap(map);

      expect(compat.codec.fourcc, equals('hvc1'));
      expect(compat.codec.name, equals('HEVC'));
      expect(compat.supportLevel, equals(CodecSupportLevel.supported));
      expect(compat.message, equals('Fully supported'));
      expect(compat.minimumOsVersion, equals('11.0'));
      expect(compat.alternativeCodecs, equals(['H.264']));
    });

    test('fromMap handles all supportLevel values', () {
      expect(
        CodecCompatibility.fromMap(const {
          'codec': {'fourcc': 'avc1', 'name': 'H.264'},
          'supportLevel': 'supported',
        }).supportLevel,
        equals(CodecSupportLevel.supported),
      );
      expect(
        CodecCompatibility.fromMap(const {
          'codec': {'fourcc': 'avc1', 'name': 'H.264'},
          'supportLevel': 'probablySupported',
        }).supportLevel,
        equals(CodecSupportLevel.probablySupported),
      );
      expect(
        CodecCompatibility.fromMap(const {
          'codec': {'fourcc': 'avc1', 'name': 'H.264'},
          'supportLevel': 'notSupported',
        }).supportLevel,
        equals(CodecSupportLevel.notSupported),
      );
      expect(
        CodecCompatibility.fromMap(const {
          'codec': {'fourcc': 'avc1', 'name': 'H.264'},
          'supportLevel': 'unknown',
        }).supportLevel,
        equals(CodecSupportLevel.unknown),
      );
    });

    test('fromMap defaults to unknown for invalid supportLevel', () {
      final compat = CodecCompatibility.fromMap(const {
        'codec': {'fourcc': 'avc1', 'name': 'H.264'},
        'supportLevel': 'invalid',
      });
      expect(compat.supportLevel, equals(CodecSupportLevel.unknown));
    });

    test('toMap returns correct map', () {
      const compat = CodecCompatibility(
        codec: CodecInfo(fourcc: 'vp09', name: 'VP9', codecString: 'vp09.00.41.08'),
        supportLevel: CodecSupportLevel.probablySupported,
        message: 'May require hardware support',
        minimumOsVersion: '14.0',
        alternativeCodecs: ['H.264'],
      );

      final map = compat.toMap();
      final codecMap = map['codec'] as Map<String, dynamic>;

      expect(codecMap['fourcc'], equals('vp09'));
      expect(codecMap['name'], equals('VP9'));
      expect(codecMap['codecString'], equals('vp09.00.41.08'));
      expect(map['supportLevel'], equals('probablySupported'));
      expect(map['message'], equals('May require hardware support'));
      expect(map['minimumOsVersion'], equals('14.0'));
      expect(map['alternativeCodecs'], equals(['H.264']));
    });

    test('toMap omits null fields', () {
      const compat = CodecCompatibility(
        codec: CodecInfo(fourcc: 'avc1', name: 'H.264'),
        supportLevel: CodecSupportLevel.supported,
      );

      final map = compat.toMap();

      expect(map.containsKey('message'), isFalse);
      expect(map.containsKey('minimumOsVersion'), isFalse);
      expect(map.containsKey('alternativeCodecs'), isFalse);
    });

    test('copyWith creates copy with modified fields', () {
      const original = CodecCompatibility(
        codec: CodecInfo(fourcc: 'avc1', name: 'H.264'),
        supportLevel: CodecSupportLevel.supported,
        message: 'Original',
      );

      final copy = original.copyWith(supportLevel: CodecSupportLevel.notSupported, message: 'Updated');

      expect(copy.codec, equals(original.codec));
      expect(copy.supportLevel, equals(CodecSupportLevel.notSupported));
      expect(copy.message, equals('Updated'));
    });

    test('equality works correctly', () {
      const compat1 = CodecCompatibility(
        codec: CodecInfo(fourcc: 'avc1', name: 'H.264'),
        supportLevel: CodecSupportLevel.supported,
      );
      const compat2 = CodecCompatibility(
        codec: CodecInfo(fourcc: 'avc1', name: 'H.264'),
        supportLevel: CodecSupportLevel.supported,
      );
      const compat3 = CodecCompatibility(
        codec: CodecInfo(fourcc: 'hvc1', name: 'HEVC'),
        supportLevel: CodecSupportLevel.supported,
      );

      expect(compat1, equals(compat2));
      expect(compat1, isNot(equals(compat3)));
    });

    test('hashCode is consistent', () {
      const compat1 = CodecCompatibility(
        codec: CodecInfo(fourcc: 'avc1', name: 'H.264'),
        supportLevel: CodecSupportLevel.supported,
      );
      const compat2 = CodecCompatibility(
        codec: CodecInfo(fourcc: 'avc1', name: 'H.264'),
        supportLevel: CodecSupportLevel.supported,
      );

      expect(compat1.hashCode, equals(compat2.hashCode));
    });

    test('toString returns readable string', () {
      const compat = CodecCompatibility(
        codec: CodecInfo(fourcc: 'avc1', name: 'H.264'),
        supportLevel: CodecSupportLevel.supported,
      );

      expect(compat.toString(), contains('CodecCompatibility'));
      expect(compat.toString(), contains('avc1'));
      expect(compat.toString(), contains('supported'));
    });
  });

  group('ContainerCompatibility', () {
    test('creates with required parameters', () {
      const compat = ContainerCompatibility(format: 'mp4', isPlayable: true, trackCompatibility: []);

      expect(compat.format, equals('mp4'));
      expect(compat.isPlayable, isTrue);
      expect(compat.trackCompatibility, isEmpty);
      expect(compat.message, isNull);
    });

    test('creates with all parameters', () {
      const videoCompat = CodecCompatibility(
        codec: CodecInfo(fourcc: 'avc1', name: 'H.264'),
        supportLevel: CodecSupportLevel.supported,
      );
      const audioCompat = CodecCompatibility(
        codec: CodecInfo(fourcc: 'mp4a', name: 'AAC'),
        supportLevel: CodecSupportLevel.supported,
      );

      const compat = ContainerCompatibility(
        format: 'mp4',
        isPlayable: true,
        trackCompatibility: [videoCompat, audioCompat],
        message: 'All codecs supported',
      );

      expect(compat.format, equals('mp4'));
      expect(compat.isPlayable, isTrue);
      expect(compat.trackCompatibility.length, equals(2));
      expect(compat.message, equals('All codecs supported'));
    });

    test('videoCompatibility returns only video codec results', () {
      const videoCompat = CodecCompatibility(
        codec: CodecInfo(fourcc: 'avc1', name: 'H.264'),
        supportLevel: CodecSupportLevel.supported,
      );
      const audioCompat = CodecCompatibility(
        codec: CodecInfo(fourcc: 'mp4a', name: 'AAC'),
        supportLevel: CodecSupportLevel.supported,
      );

      const compat = ContainerCompatibility(
        format: 'mp4',
        isPlayable: true,
        trackCompatibility: [videoCompat, audioCompat],
      );

      expect(compat.videoCompatibility.length, equals(1));
      expect(compat.videoCompatibility.first.codec.fourcc, equals('avc1'));
    });

    test('audioCompatibility returns only audio codec results', () {
      const videoCompat = CodecCompatibility(
        codec: CodecInfo(fourcc: 'avc1', name: 'H.264'),
        supportLevel: CodecSupportLevel.supported,
      );
      const audioCompat = CodecCompatibility(
        codec: CodecInfo(fourcc: 'mp4a', name: 'AAC'),
        supportLevel: CodecSupportLevel.supported,
      );

      const compat = ContainerCompatibility(
        format: 'mp4',
        isPlayable: true,
        trackCompatibility: [videoCompat, audioCompat],
      );

      expect(compat.audioCompatibility.length, equals(1));
      expect(compat.audioCompatibility.first.codec.fourcc, equals('mp4a'));
    });

    test('unsupportedCodecs returns only non-playable codecs', () {
      const supported = CodecCompatibility(
        codec: CodecInfo(fourcc: 'avc1', name: 'H.264'),
        supportLevel: CodecSupportLevel.supported,
      );
      const notSupported = CodecCompatibility(
        codec: CodecInfo(fourcc: 'av01', name: 'AV1'),
        supportLevel: CodecSupportLevel.notSupported,
      );
      const unknown = CodecCompatibility(
        codec: CodecInfo(fourcc: 'xyz1', name: 'Unknown'),
        supportLevel: CodecSupportLevel.unknown,
      );

      const compat = ContainerCompatibility(
        format: 'mp4',
        isPlayable: false,
        trackCompatibility: [supported, notSupported, unknown],
      );

      expect(compat.unsupportedCodecs.length, equals(2));
      expect(compat.unsupportedCodecs.map((c) => c.codec.fourcc), containsAll(['av01', 'xyz1']));
    });

    test('fromMap creates instance correctly', () {
      final map = {
        'format': 'mkv',
        'isPlayable': false,
        'trackCompatibility': [
          {
            'codec': {'fourcc': 'hvc1', 'name': 'HEVC'},
            'supportLevel': 'notSupported',
            'message': 'HEVC not supported',
          },
        ],
        'message': 'Contains unsupported codecs',
      };

      final compat = ContainerCompatibility.fromMap(map);

      expect(compat.format, equals('mkv'));
      expect(compat.isPlayable, isFalse);
      expect(compat.trackCompatibility.length, equals(1));
      expect(compat.trackCompatibility.first.codec.fourcc, equals('hvc1'));
      expect(compat.message, equals('Contains unsupported codecs'));
    });

    test('toMap returns correct map', () {
      const videoCompat = CodecCompatibility(
        codec: CodecInfo(fourcc: 'avc1', name: 'H.264'),
        supportLevel: CodecSupportLevel.supported,
      );

      const compat = ContainerCompatibility(
        format: 'mp4',
        isPlayable: true,
        trackCompatibility: [videoCompat],
        message: 'OK',
      );

      final map = compat.toMap();

      expect(map['format'], equals('mp4'));
      expect(map['isPlayable'], isTrue);
      expect(map['trackCompatibility'], isA<List<dynamic>>());
      expect((map['trackCompatibility'] as List<dynamic>).length, equals(1));
      expect(map['message'], equals('OK'));
    });

    test('copyWith creates copy with modified fields', () {
      const original = ContainerCompatibility(format: 'mp4', isPlayable: true, trackCompatibility: []);

      final copy = original.copyWith(isPlayable: false, message: 'Updated');

      expect(copy.format, equals('mp4'));
      expect(copy.isPlayable, isFalse);
      expect(copy.message, equals('Updated'));
    });

    test('equality works correctly', () {
      const compat1 = ContainerCompatibility(format: 'mp4', isPlayable: true, trackCompatibility: []);
      const compat2 = ContainerCompatibility(format: 'mp4', isPlayable: true, trackCompatibility: []);
      const compat3 = ContainerCompatibility(format: 'mkv', isPlayable: true, trackCompatibility: []);

      expect(compat1, equals(compat2));
      expect(compat1, isNot(equals(compat3)));
    });
  });
}
