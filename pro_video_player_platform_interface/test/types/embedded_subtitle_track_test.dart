import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

void main() {
  group('EmbeddedSubtitleTrack', () {
    test('creates with required parameters', () {
      const track = EmbeddedSubtitleTrack(trackId: 3, codec: 'tx3g');

      expect(track.trackId, equals(3));
      expect(track.codec, equals('tx3g'));
      expect(track.language, isNull);
      expect(track.label, isNull);
      expect(track.isDefault, isFalse);
      expect(track.isForced, isFalse);
    });

    test('creates with all parameters', () {
      const track = EmbeddedSubtitleTrack(
        trackId: 5,
        codec: 's_text/ass',
        language: 'eng',
        label: 'English (SDH)',
        isDefault: true,
      );

      expect(track.trackId, equals(5));
      expect(track.codec, equals('s_text/ass'));
      expect(track.language, equals('eng'));
      expect(track.label, equals('English (SDH)'));
      expect(track.isDefault, isTrue);
      expect(track.isForced, isFalse);
    });

    group('codecName', () {
      test('returns Timed Text for tx3g', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 'tx3g');
        expect(track.codecName, equals('Timed Text'));
      });

      test('returns TTML for stpp', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 'stpp');
        expect(track.codecName, equals('TTML'));
      });

      test('returns WebVTT for wvtt', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 'wvtt');
        expect(track.codecName, equals('WebVTT'));
      });

      test('returns CEA-608 for c608', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 'c608');
        expect(track.codecName, equals('CEA-608'));
      });

      test('returns CEA-708 for c708', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 'c708');
        expect(track.codecName, equals('CEA-708'));
      });

      test('returns Text for text', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 'text');
        expect(track.codecName, equals('Text'));
      });

      test('returns SRT for s_text/utf8', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 's_text/utf8');
        expect(track.codecName, equals('SRT'));
      });

      test('returns ASS for s_text/ass', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 's_text/ass');
        expect(track.codecName, equals('ASS'));
      });

      test('returns SSA for s_text/ssa', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 's_text/ssa');
        expect(track.codecName, equals('SSA'));
      });

      test('returns WebVTT for s_text/webvtt', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 's_text/webvtt');
        expect(track.codecName, equals('WebVTT'));
      });

      test('returns PGS for s_hdmv/pgs', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 's_hdmv/pgs');
        expect(track.codecName, equals('PGS'));
      });

      test('returns VobSub for s_vobsub', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 's_vobsub');
        expect(track.codecName, equals('VobSub'));
      });

      test('returns DVB for s_dvbsub', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 's_dvbsub');
        expect(track.codecName, equals('DVB'));
      });

      test('returns raw codec for unknown codec', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 'unknown');
        expect(track.codecName, equals('unknown'));
      });

      test('handles uppercase codec', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 'TX3G');
        expect(track.codecName, equals('Timed Text'));
      });
    });

    group('isTextBased', () {
      test('returns true for tx3g', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 'tx3g');
        expect(track.isTextBased, isTrue);
      });

      test('returns true for stpp', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 'stpp');
        expect(track.isTextBased, isTrue);
      });

      test('returns true for wvtt', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 'wvtt');
        expect(track.isTextBased, isTrue);
      });

      test('returns true for text', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 'text');
        expect(track.isTextBased, isTrue);
      });

      test('returns true for s_text/utf8', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 's_text/utf8');
        expect(track.isTextBased, isTrue);
      });

      test('returns true for s_text/ass', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 's_text/ass');
        expect(track.isTextBased, isTrue);
      });

      test('returns true for s_text/ssa', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 's_text/ssa');
        expect(track.isTextBased, isTrue);
      });

      test('returns true for s_text/webvtt', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 's_text/webvtt');
        expect(track.isTextBased, isTrue);
      });

      test('returns false for s_hdmv/pgs', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 's_hdmv/pgs');
        expect(track.isTextBased, isFalse);
      });

      test('returns false for s_vobsub', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 's_vobsub');
        expect(track.isTextBased, isFalse);
      });

      test('returns false for unknown codec', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 'unknown');
        expect(track.isTextBased, isFalse);
      });
    });

    group('isImageBased', () {
      test('returns true for s_hdmv/pgs', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 's_hdmv/pgs');
        expect(track.isImageBased, isTrue);
      });

      test('returns true for s_vobsub', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 's_vobsub');
        expect(track.isImageBased, isTrue);
      });

      test('returns true for s_dvbsub', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 's_dvbsub');
        expect(track.isImageBased, isTrue);
      });

      test('returns true for dvbs', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 'dvbs');
        expect(track.isImageBased, isTrue);
      });

      test('returns false for tx3g', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 'tx3g');
        expect(track.isImageBased, isFalse);
      });

      test('returns false for s_text/utf8', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 's_text/utf8');
        expect(track.isImageBased, isFalse);
      });

      test('returns false for unknown codec', () {
        const track = EmbeddedSubtitleTrack(trackId: 1, codec: 'unknown');
        expect(track.isImageBased, isFalse);
      });
    });

    group('equality', () {
      test('equal tracks are equal', () {
        const track1 = EmbeddedSubtitleTrack(
          trackId: 3,
          codec: 'tx3g',
          language: 'eng',
          label: 'English',
          isDefault: true,
        );
        const track2 = EmbeddedSubtitleTrack(
          trackId: 3,
          codec: 'tx3g',
          language: 'eng',
          label: 'English',
          isDefault: true,
        );

        expect(track1, equals(track2));
      });

      test('tracks with different trackId are not equal', () {
        const track1 = EmbeddedSubtitleTrack(trackId: 1, codec: 'tx3g');
        const track2 = EmbeddedSubtitleTrack(trackId: 2, codec: 'tx3g');

        expect(track1, isNot(equals(track2)));
      });

      test('tracks with different codec are not equal', () {
        const track1 = EmbeddedSubtitleTrack(trackId: 1, codec: 'tx3g');
        const track2 = EmbeddedSubtitleTrack(trackId: 1, codec: 'wvtt');

        expect(track1, isNot(equals(track2)));
      });

      test('tracks with different language are not equal', () {
        const track1 = EmbeddedSubtitleTrack(trackId: 1, codec: 'tx3g', language: 'eng');
        const track2 = EmbeddedSubtitleTrack(trackId: 1, codec: 'tx3g', language: 'fra');

        expect(track1, isNot(equals(track2)));
      });

      test('tracks with different label are not equal', () {
        const track1 = EmbeddedSubtitleTrack(trackId: 1, codec: 'tx3g', label: 'English');
        const track2 = EmbeddedSubtitleTrack(trackId: 1, codec: 'tx3g', label: 'English (SDH)');

        expect(track1, isNot(equals(track2)));
      });

      test('tracks with different isDefault are not equal', () {
        const track1 = EmbeddedSubtitleTrack(trackId: 1, codec: 'tx3g', isDefault: true);
        const track2 = EmbeddedSubtitleTrack(trackId: 1, codec: 'tx3g');

        expect(track1, isNot(equals(track2)));
      });

      test('tracks with different isForced are not equal', () {
        const track1 = EmbeddedSubtitleTrack(trackId: 1, codec: 'tx3g', isForced: true);
        const track2 = EmbeddedSubtitleTrack(trackId: 1, codec: 'tx3g');

        expect(track1, isNot(equals(track2)));
      });
    });

    test('hashCode is consistent with equality', () {
      const track1 = EmbeddedSubtitleTrack(
        trackId: 3,
        codec: 'tx3g',
        language: 'eng',
        label: 'English',
        isDefault: true,
      );
      const track2 = EmbeddedSubtitleTrack(
        trackId: 3,
        codec: 'tx3g',
        language: 'eng',
        label: 'English',
        isDefault: true,
      );

      expect(track1.hashCode, equals(track2.hashCode));
    });

    test('toString returns readable representation', () {
      const track = EmbeddedSubtitleTrack(
        trackId: 3,
        codec: 'tx3g',
        language: 'eng',
        label: 'English',
        isDefault: true,
      );

      final str = track.toString();
      expect(str, contains('EmbeddedSubtitleTrack'));
      expect(str, contains('3'));
      expect(str, contains('Timed Text'));
      expect(str, contains('eng'));
      expect(str, contains('English'));
      expect(str, contains('default: true'));
      expect(str, contains('forced: false'));
    });
  });
}
