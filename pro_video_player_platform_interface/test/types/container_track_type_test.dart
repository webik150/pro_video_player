import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

void main() {
  group('ContainerTrackType', () {
    test('has all expected values', () {
      expect(ContainerTrackType.values, hasLength(6));
      expect(ContainerTrackType.values, contains(ContainerTrackType.video));
      expect(ContainerTrackType.values, contains(ContainerTrackType.audio));
      expect(ContainerTrackType.values, contains(ContainerTrackType.subtitle));
      expect(ContainerTrackType.values, contains(ContainerTrackType.hint));
      expect(ContainerTrackType.values, contains(ContainerTrackType.metadata));
      expect(ContainerTrackType.values, contains(ContainerTrackType.unknown));
    });

    group('displayName', () {
      test('returns correct display name for video', () {
        expect(ContainerTrackType.video.displayName, equals('Video'));
      });

      test('returns correct display name for audio', () {
        expect(ContainerTrackType.audio.displayName, equals('Audio'));
      });

      test('returns correct display name for subtitle', () {
        expect(ContainerTrackType.subtitle.displayName, equals('Subtitle'));
      });

      test('returns correct display name for hint', () {
        expect(ContainerTrackType.hint.displayName, equals('Hint'));
      });

      test('returns correct display name for metadata', () {
        expect(ContainerTrackType.metadata.displayName, equals('Metadata'));
      });

      test('returns correct display name for unknown', () {
        expect(ContainerTrackType.unknown.displayName, equals('Unknown'));
      });
    });

    group('fromHandlerType', () {
      test('returns video for vide', () {
        expect(ContainerTrackType.fromHandlerType('vide'), equals(ContainerTrackType.video));
      });

      test('returns audio for soun', () {
        expect(ContainerTrackType.fromHandlerType('soun'), equals(ContainerTrackType.audio));
      });

      test('returns subtitle for text', () {
        expect(ContainerTrackType.fromHandlerType('text'), equals(ContainerTrackType.subtitle));
      });

      test('returns subtitle for sbtl', () {
        expect(ContainerTrackType.fromHandlerType('sbtl'), equals(ContainerTrackType.subtitle));
      });

      test('returns subtitle for subt', () {
        expect(ContainerTrackType.fromHandlerType('subt'), equals(ContainerTrackType.subtitle));
      });

      test('returns hint for hint', () {
        expect(ContainerTrackType.fromHandlerType('hint'), equals(ContainerTrackType.hint));
      });

      test('returns metadata for meta', () {
        expect(ContainerTrackType.fromHandlerType('meta'), equals(ContainerTrackType.metadata));
      });

      test('returns unknown for unrecognized types', () {
        expect(ContainerTrackType.fromHandlerType('xyz'), equals(ContainerTrackType.unknown));
        expect(ContainerTrackType.fromHandlerType(''), equals(ContainerTrackType.unknown));
        expect(ContainerTrackType.fromHandlerType('VIDEO'), equals(ContainerTrackType.unknown));
      });
    });

    group('isMedia', () {
      test('returns true for video', () {
        expect(ContainerTrackType.video.isMedia, isTrue);
      });

      test('returns true for audio', () {
        expect(ContainerTrackType.audio.isMedia, isTrue);
      });

      test('returns false for subtitle', () {
        expect(ContainerTrackType.subtitle.isMedia, isFalse);
      });

      test('returns false for hint', () {
        expect(ContainerTrackType.hint.isMedia, isFalse);
      });

      test('returns false for metadata', () {
        expect(ContainerTrackType.metadata.isMedia, isFalse);
      });

      test('returns false for unknown', () {
        expect(ContainerTrackType.unknown.isMedia, isFalse);
      });
    });
  });
}
