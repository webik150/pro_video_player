import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/hls_playlist_writer.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/remux_config.dart';

void main() {
  group('RemuxConfig', () {
    test('has sensible default values', () {
      const config = RemuxConfig();

      expect(config.segmentDuration, equals(const Duration(seconds: 6)));
      expect(config.outputFormat, equals(HlsOutputFormat.fmp4));
      expect(config.playlistType, equals(HlsPlaylistType.vod));
      expect(config.alignToKeyframes, isTrue);
      expect(config.includeAudio, isTrue);
      expect(config.includeSubtitles, isTrue);
      expect(config.generateMasterPlaylist, isTrue);
      expect(config.hlsVersion, equals(7));
    });

    test('accepts custom values', () {
      const config = RemuxConfig(
        segmentDuration: Duration(seconds: 10),
        outputFormat: HlsOutputFormat.mpegts,
        playlistType: HlsPlaylistType.live,
        alignToKeyframes: false,
        includeAudio: false,
        includeSubtitles: false,
        generateMasterPlaylist: false,
        hlsVersion: 3,
      );

      expect(config.segmentDuration, equals(const Duration(seconds: 10)));
      expect(config.outputFormat, equals(HlsOutputFormat.mpegts));
      expect(config.playlistType, equals(HlsPlaylistType.live));
      expect(config.alignToKeyframes, isFalse);
      expect(config.includeAudio, isFalse);
      expect(config.includeSubtitles, isFalse);
      expect(config.generateMasterPlaylist, isFalse);
      expect(config.hlsVersion, equals(3));
    });

    group('copyWith', () {
      test('returns same config when no arguments', () {
        const original = RemuxConfig();
        final copied = original.copyWith();

        expect(copied.segmentDuration, equals(original.segmentDuration));
        expect(copied.outputFormat, equals(original.outputFormat));
        expect(copied.playlistType, equals(original.playlistType));
        expect(copied.alignToKeyframes, equals(original.alignToKeyframes));
        expect(copied.includeAudio, equals(original.includeAudio));
        expect(copied.includeSubtitles, equals(original.includeSubtitles));
        expect(copied.generateMasterPlaylist, equals(original.generateMasterPlaylist));
        expect(copied.hlsVersion, equals(original.hlsVersion));
      });

      test('copies with single field changed', () {
        const original = RemuxConfig();
        final copied = original.copyWith(segmentDuration: const Duration(seconds: 4));

        expect(copied.segmentDuration, equals(const Duration(seconds: 4)));
        expect(copied.outputFormat, equals(original.outputFormat));
        expect(copied.playlistType, equals(original.playlistType));
      });

      test('copies with multiple fields changed', () {
        const original = RemuxConfig();
        final copied = original.copyWith(outputFormat: HlsOutputFormat.mpegts, hlsVersion: 3, includeSubtitles: false);

        expect(copied.segmentDuration, equals(original.segmentDuration));
        expect(copied.outputFormat, equals(HlsOutputFormat.mpegts));
        expect(copied.playlistType, equals(original.playlistType));
        expect(copied.alignToKeyframes, equals(original.alignToKeyframes));
        expect(copied.includeAudio, equals(original.includeAudio));
        expect(copied.includeSubtitles, isFalse);
        expect(copied.generateMasterPlaylist, equals(original.generateMasterPlaylist));
        expect(copied.hlsVersion, equals(3));
      });
    });

    test('toString returns readable string', () {
      const config = RemuxConfig();
      final str = config.toString();

      expect(str, contains('RemuxConfig'));
      expect(str, contains('segmentDuration'));
      expect(str, contains('fmp4'));
      expect(str, contains('vod'));
    });

    test('supports event playlist type', () {
      const config = RemuxConfig(playlistType: HlsPlaylistType.event);

      expect(config.playlistType, equals(HlsPlaylistType.event));
    });
  });
}
