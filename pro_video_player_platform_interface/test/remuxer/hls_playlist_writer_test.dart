import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/hls_playlist_writer.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/sample_reader.dart';
import 'package:pro_video_player_platform_interface/src/remuxer/segment_writer.dart';

void main() {
  group('HlsSegmentInfo', () {
    test('creates with required parameters', () {
      const segment = HlsSegmentInfo(filename: 'segment1.m4s', duration: 6);

      expect(segment.filename, equals('segment1.m4s'));
      expect(segment.duration, equals(6.0));
      expect(segment.title, isNull);
      expect(segment.byteRange, isNull);
      expect(segment.discontinuity, isFalse);
      expect(segment.programDateTime, isNull);
    });

    test('creates with all parameters', () {
      final segment = HlsSegmentInfo(
        filename: 'segment2.m4s',
        duration: 5.5,
        title: 'My Segment',
        byteRange: const HlsByteRange(length: 1000, offset: 500),
        discontinuity: true,
        programDateTime: DateTime.utc(2024, 1, 15, 12, 30, 45),
      );

      expect(segment.filename, equals('segment2.m4s'));
      expect(segment.duration, equals(5.5));
      expect(segment.title, equals('My Segment'));
      expect(segment.byteRange, isNotNull);
      expect(segment.discontinuity, isTrue);
      expect(segment.programDateTime, isNotNull);
    });
  });

  group('HlsByteRange', () {
    test('toString with length only', () {
      const range = HlsByteRange(length: 1000);
      expect(range.toString(), equals('1000'));
    });

    test('toString with length and offset', () {
      const range = HlsByteRange(length: 1000, offset: 500);
      expect(range.toString(), equals('1000@500'));
    });
  });

  group('HlsVariantInfo', () {
    test('creates with required parameters', () {
      const variant = HlsVariantInfo(bandwidth: 5000000, playlistUri: 'video_1080p.m3u8');

      expect(variant.bandwidth, equals(5000000));
      expect(variant.playlistUri, equals('video_1080p.m3u8'));
      expect(variant.codecs, isNull);
      expect(variant.resolution, isNull);
    });

    test('creates with all parameters', () {
      const variant = HlsVariantInfo(
        bandwidth: 5000000,
        averageBandwidth: 4500000,
        playlistUri: 'video_1080p.m3u8',
        codecs: 'avc1.64001f,mp4a.40.2',
        resolution: '1920x1080',
        frameRate: 29.97,
        audioGroupId: 'audio-aac',
        subtitleGroupId: 'subs',
      );

      expect(variant.bandwidth, equals(5000000));
      expect(variant.averageBandwidth, equals(4500000));
      expect(variant.codecs, equals('avc1.64001f,mp4a.40.2'));
      expect(variant.resolution, equals('1920x1080'));
      expect(variant.frameRate, closeTo(29.97, 0.01));
      expect(variant.audioGroupId, equals('audio-aac'));
      expect(variant.subtitleGroupId, equals('subs'));
    });

    test('fromTrack creates variant info for video track', () {
      const track = TrackCodecInfo(trackId: 1, codecFourcc: 'avc1', timescale: 90000, width: 1920, height: 1080);

      final variant = HlsVariantInfo.fromTrack(track: track, bandwidth: 5000000, playlistUri: 'video.m3u8');

      expect(variant.bandwidth, equals(5000000));
      expect(variant.playlistUri, equals('video.m3u8'));
      expect(variant.codecs, contains('avc1'));
      expect(variant.resolution, equals('1920x1080'));
    });

    test('fromTrack handles different codecs', () {
      const hvcTrack = TrackCodecInfo(trackId: 1, codecFourcc: 'hvc1', timescale: 90000, width: 3840, height: 2160);
      final hvcVariant = HlsVariantInfo.fromTrack(track: hvcTrack, bandwidth: 15000000, playlistUri: 'video.m3u8');
      expect(hvcVariant.codecs, contains('hvc1'));

      const audioTrack = TrackCodecInfo(trackId: 2, codecFourcc: 'mp4a', timescale: 44100, sampleRate: 44100);
      final audioVariant = HlsVariantInfo.fromTrack(track: audioTrack, bandwidth: 128000, playlistUri: 'audio.m3u8');
      expect(audioVariant.codecs, contains('mp4a'));
    });
  });

  group('HlsAudioTrackInfo', () {
    test('creates with required parameters', () {
      const track = HlsAudioTrackInfo(groupId: 'audio-aac', name: 'English');

      expect(track.groupId, equals('audio-aac'));
      expect(track.name, equals('English'));
      expect(track.language, isNull);
      expect(track.isDefault, isFalse);
      expect(track.autoSelect, isTrue);
    });

    test('creates with all parameters', () {
      const track = HlsAudioTrackInfo(
        groupId: 'audio-aac',
        name: 'English',
        language: 'en',
        uri: 'audio_en.m3u8',
        isDefault: true,
        channels: '2',
        codecs: 'mp4a.40.2',
      );

      expect(track.groupId, equals('audio-aac'));
      expect(track.language, equals('en'));
      expect(track.uri, equals('audio_en.m3u8'));
      expect(track.isDefault, isTrue);
      expect(track.channels, equals('2'));
      expect(track.codecs, equals('mp4a.40.2'));
    });
  });

  group('HlsSubtitleTrackInfo', () {
    test('creates with required parameters', () {
      const track = HlsSubtitleTrackInfo(groupId: 'subs', name: 'English', uri: 'subs_en.m3u8');

      expect(track.groupId, equals('subs'));
      expect(track.name, equals('English'));
      expect(track.uri, equals('subs_en.m3u8'));
      expect(track.isDefault, isFalse);
      expect(track.forced, isFalse);
    });

    test('creates with all parameters', () {
      const track = HlsSubtitleTrackInfo(
        groupId: 'subs',
        name: 'English SDH',
        uri: 'subs_en_sdh.m3u8',
        language: 'en',
        isDefault: true,
        characteristics: 'public.accessibility.describes-spoken-dialog',
      );

      expect(track.language, equals('en'));
      expect(track.isDefault, isTrue);
      expect(track.characteristics, contains('accessibility'));
    });
  });

  group('HlsPlaylistWriter.writeMediaPlaylist', () {
    test('writes basic VOD playlist', () {
      final segments = [
        const HlsSegmentInfo(filename: 'segment0.m4s', duration: 6),
        const HlsSegmentInfo(filename: 'segment1.m4s', duration: 6),
        const HlsSegmentInfo(filename: 'segment2.m4s', duration: 4.5),
      ];

      final playlist = HlsPlaylistWriter.writeMediaPlaylist(
        segments: segments,
        targetDuration: 6,
        initSegment: 'init.mp4',
      );

      expect(playlist, contains('#EXTM3U'));
      expect(playlist, contains('#EXT-X-VERSION:7'));
      expect(playlist, contains('#EXT-X-TARGETDURATION:6'));
      expect(playlist, contains('#EXT-X-MEDIA-SEQUENCE:0'));
      expect(playlist, contains('#EXT-X-PLAYLIST-TYPE:VOD'));
      expect(playlist, contains('#EXT-X-INDEPENDENT-SEGMENTS'));
      expect(playlist, contains('#EXT-X-MAP:URI="init.mp4"'));
      expect(playlist, contains('#EXTINF:6.000000,'));
      expect(playlist, contains('segment0.m4s'));
      expect(playlist, contains('#EXTINF:4.500000,'));
      expect(playlist, contains('segment2.m4s'));
      expect(playlist, contains('#EXT-X-ENDLIST'));
    });

    test('writes event playlist', () {
      final segments = [const HlsSegmentInfo(filename: 'segment0.m4s', duration: 6)];

      final playlist = HlsPlaylistWriter.writeMediaPlaylist(
        segments: segments,
        targetDuration: 6,
        playlistType: HlsPlaylistType.event,
      );

      expect(playlist, contains('#EXT-X-PLAYLIST-TYPE:EVENT'));
      expect(playlist, isNot(contains('#EXT-X-ENDLIST'))); // event doesn't have endlist initially
    });

    test('writes live playlist without playlist type', () {
      final segments = [const HlsSegmentInfo(filename: 'segment0.m4s', duration: 6)];

      final playlist = HlsPlaylistWriter.writeMediaPlaylist(
        segments: segments,
        targetDuration: 6,
        playlistType: HlsPlaylistType.live,
      );

      expect(playlist, isNot(contains('#EXT-X-PLAYLIST-TYPE')));
      expect(playlist, isNot(contains('#EXT-X-ENDLIST')));
    });

    test('includes segment title when provided', () {
      final segments = [const HlsSegmentInfo(filename: 'segment0.m4s', duration: 6, title: 'Chapter 1')];

      final playlist = HlsPlaylistWriter.writeMediaPlaylist(segments: segments, targetDuration: 6);

      expect(playlist, contains('#EXTINF:6.000000,Chapter 1'));
    });

    test('includes byte range when provided', () {
      final segments = [
        const HlsSegmentInfo(filename: 'video.mp4', duration: 6, byteRange: HlsByteRange(length: 100000, offset: 0)),
        const HlsSegmentInfo(filename: 'video.mp4', duration: 6, byteRange: HlsByteRange(length: 150000)),
      ];

      final playlist = HlsPlaylistWriter.writeMediaPlaylist(segments: segments, targetDuration: 6);

      expect(playlist, contains('#EXT-X-BYTERANGE:100000@0'));
      expect(playlist, contains('#EXT-X-BYTERANGE:150000'));
    });

    test('includes discontinuity marker', () {
      final segments = [
        const HlsSegmentInfo(filename: 'segment0.m4s', duration: 6),
        const HlsSegmentInfo(filename: 'segment1.m4s', duration: 6, discontinuity: true),
      ];

      final playlist = HlsPlaylistWriter.writeMediaPlaylist(segments: segments, targetDuration: 6);

      expect(playlist, contains('#EXT-X-DISCONTINUITY'));
    });

    test('includes program date time', () {
      final segments = [
        HlsSegmentInfo(filename: 'segment0.m4s', duration: 6, programDateTime: DateTime.utc(2024, 1, 15, 12)),
      ];

      final playlist = HlsPlaylistWriter.writeMediaPlaylist(segments: segments, targetDuration: 6);

      expect(playlist, contains('#EXT-X-PROGRAM-DATE-TIME:2024-01-15T12:00:00.000Z'));
    });

    test('respects custom media sequence', () {
      final segments = [const HlsSegmentInfo(filename: 'segment100.m4s', duration: 6)];

      final playlist = HlsPlaylistWriter.writeMediaPlaylist(segments: segments, targetDuration: 6, mediaSequence: 100);

      expect(playlist, contains('#EXT-X-MEDIA-SEQUENCE:100'));
    });

    test('respects custom version', () {
      final segments = [const HlsSegmentInfo(filename: 'segment0.ts', duration: 6)];

      final playlist = HlsPlaylistWriter.writeMediaPlaylist(segments: segments, targetDuration: 6, version: 3);

      expect(playlist, contains('#EXT-X-VERSION:3'));
    });

    test('can disable independent segments', () {
      final segments = [const HlsSegmentInfo(filename: 'segment0.m4s', duration: 6)];

      final playlist = HlsPlaylistWriter.writeMediaPlaylist(
        segments: segments,
        targetDuration: 6,
        independentSegments: false,
      );

      expect(playlist, isNot(contains('#EXT-X-INDEPENDENT-SEGMENTS')));
    });
  });

  group('HlsPlaylistWriter.writeMasterPlaylist', () {
    test('writes basic master playlist', () {
      final variants = [
        const HlsVariantInfo(bandwidth: 2000000, playlistUri: 'video_720p.m3u8', resolution: '1280x720'),
        const HlsVariantInfo(bandwidth: 5000000, playlistUri: 'video_1080p.m3u8', resolution: '1920x1080'),
      ];

      final playlist = HlsPlaylistWriter.writeMasterPlaylist(variants: variants);

      expect(playlist, contains('#EXTM3U'));
      expect(playlist, contains('#EXT-X-VERSION:7'));
      expect(playlist, contains('#EXT-X-INDEPENDENT-SEGMENTS'));
      expect(playlist, contains('#EXT-X-STREAM-INF:BANDWIDTH=2000000'));
      expect(playlist, contains(',RESOLUTION=1280x720'));
      expect(playlist, contains('video_720p.m3u8'));
      expect(playlist, contains('#EXT-X-STREAM-INF:BANDWIDTH=5000000'));
      expect(playlist, contains(',RESOLUTION=1920x1080'));
      expect(playlist, contains('video_1080p.m3u8'));
    });

    test('includes variant codecs', () {
      final variants = [
        const HlsVariantInfo(bandwidth: 5000000, playlistUri: 'video.m3u8', codecs: 'avc1.64001f,mp4a.40.2'),
      ];

      final playlist = HlsPlaylistWriter.writeMasterPlaylist(variants: variants);

      expect(playlist, contains('CODECS="avc1.64001f,mp4a.40.2"'));
    });

    test('includes variant average bandwidth', () {
      final variants = [const HlsVariantInfo(bandwidth: 5000000, averageBandwidth: 4500000, playlistUri: 'video.m3u8')];

      final playlist = HlsPlaylistWriter.writeMasterPlaylist(variants: variants);

      expect(playlist, contains('AVERAGE-BANDWIDTH=4500000'));
    });

    test('includes variant frame rate', () {
      final variants = [const HlsVariantInfo(bandwidth: 5000000, playlistUri: 'video.m3u8', frameRate: 29.97)];

      final playlist = HlsPlaylistWriter.writeMasterPlaylist(variants: variants);

      expect(playlist, contains('FRAME-RATE=29.970'));
    });

    test('includes audio tracks', () {
      final variants = [const HlsVariantInfo(bandwidth: 5000000, playlistUri: 'video.m3u8', audioGroupId: 'audio-aac')];

      final audioTracks = [
        const HlsAudioTrackInfo(
          groupId: 'audio-aac',
          name: 'English',
          language: 'en',
          uri: 'audio_en.m3u8',
          isDefault: true,
          channels: '2',
        ),
        const HlsAudioTrackInfo(groupId: 'audio-aac', name: 'Spanish', language: 'es', uri: 'audio_es.m3u8'),
      ];

      final playlist = HlsPlaylistWriter.writeMasterPlaylist(variants: variants, audioTracks: audioTracks);

      expect(playlist, contains('#EXT-X-MEDIA:TYPE=AUDIO'));
      expect(playlist, contains('GROUP-ID="audio-aac"'));
      expect(playlist, contains('NAME="English"'));
      expect(playlist, contains('LANGUAGE="en"'));
      expect(playlist, contains('URI="audio_en.m3u8"'));
      expect(playlist, contains('DEFAULT=YES'));
      expect(playlist, contains('CHANNELS="2"'));
      expect(playlist, contains('NAME="Spanish"'));
      expect(playlist, contains('DEFAULT=NO'));
      expect(playlist, contains('AUDIO="audio-aac"'));
    });

    test('includes subtitle tracks', () {
      final variants = [const HlsVariantInfo(bandwidth: 5000000, playlistUri: 'video.m3u8', subtitleGroupId: 'subs')];

      final subtitleTracks = [
        const HlsSubtitleTrackInfo(
          groupId: 'subs',
          name: 'English',
          uri: 'subs_en.m3u8',
          language: 'en',
          isDefault: true,
        ),
        const HlsSubtitleTrackInfo(groupId: 'subs', name: 'French', uri: 'subs_fr.m3u8', language: 'fr', forced: true),
      ];

      final playlist = HlsPlaylistWriter.writeMasterPlaylist(variants: variants, subtitleTracks: subtitleTracks);

      expect(playlist, contains('#EXT-X-MEDIA:TYPE=SUBTITLES'));
      expect(playlist, contains('GROUP-ID="subs"'));
      expect(playlist, contains('NAME="English"'));
      expect(playlist, contains('URI="subs_en.m3u8"'));
      expect(playlist, contains('FORCED=NO'));
      expect(playlist, contains('NAME="French"'));
      expect(playlist, contains('FORCED=YES'));
      expect(playlist, contains('SUBTITLES="subs"'));
    });

    test('includes closed captions reference', () {
      final variants = [
        const HlsVariantInfo(bandwidth: 5000000, playlistUri: 'video.m3u8', closedCaptionsGroupId: 'cc'),
      ];

      final playlist = HlsPlaylistWriter.writeMasterPlaylist(variants: variants);

      expect(playlist, contains('CLOSED-CAPTIONS="cc"'));
    });

    test('handles CLOSED-CAPTIONS=NONE', () {
      final variants = [
        const HlsVariantInfo(bandwidth: 5000000, playlistUri: 'video.m3u8', closedCaptionsGroupId: 'NONE'),
      ];

      final playlist = HlsPlaylistWriter.writeMasterPlaylist(variants: variants);

      expect(playlist, contains('CLOSED-CAPTIONS=NONE'));
      expect(playlist, isNot(contains('CLOSED-CAPTIONS="NONE"')));
    });
  });

  group('HlsPlaylistWriter.segmentsToInfo', () {
    test('converts media segments to segment info', () {
      final segments = [
        MediaSegment(data: Uint8List(0), index: 0, startTime: 0, duration: 0, isInitSegment: true),
        MediaSegment(data: Uint8List(100), index: 1, startTime: 0, duration: 6, isInitSegment: false),
        MediaSegment(data: Uint8List(100), index: 2, startTime: 6, duration: 6, isInitSegment: false),
        MediaSegment(data: Uint8List(100), index: 3, startTime: 12, duration: 4, isInitSegment: false),
      ];

      final infos = HlsPlaylistWriter.segmentsToInfo(segments);

      expect(infos.length, equals(3)); // Excludes init segment
      expect(infos[0].filename, equals('segment1.m4s'));
      expect(infos[0].duration, equals(6));
      expect(infos[1].filename, equals('segment2.m4s'));
      expect(infos[2].filename, equals('segment3.m4s'));
    });

    test('uses custom filename generator', () {
      final segments = [
        MediaSegment(data: Uint8List(100), index: 1, startTime: 0, duration: 6, isInitSegment: false),
        MediaSegment(data: Uint8List(100), index: 2, startTime: 6, duration: 6, isInitSegment: false),
      ];

      final infos = HlsPlaylistWriter.segmentsToInfo(segments, filenameGenerator: (i) => 'chunk_$i.ts');

      expect(infos[0].filename, equals('chunk_1.ts'));
      expect(infos[1].filename, equals('chunk_2.ts'));
    });
  });

  group('HlsOutput', () {
    test('creates with all fields', () {
      const output = HlsOutput(
        masterPlaylist: '#EXTM3U\n...',
        mediaPlaylists: {'720p': '#EXTM3U\n...', '1080p': '#EXTM3U\n...'},
        initSegmentPath: 'init.mp4',
        segmentPaths: ['segment1.m4s', 'segment2.m4s'],
      );

      expect(output.masterPlaylist, contains('#EXTM3U'));
      expect(output.mediaPlaylists.length, equals(2));
      expect(output.initSegmentPath, equals('init.mp4'));
      expect(output.segmentPaths.length, equals(2));
    });
  });

  group('HLS playlist compatibility', () {
    test('generates valid fMP4 HLS playlist', () {
      final segments = [
        const HlsSegmentInfo(filename: 'segment0.m4s', duration: 6),
        const HlsSegmentInfo(filename: 'segment1.m4s', duration: 6),
      ];

      final playlist = HlsPlaylistWriter.writeMediaPlaylist(
        segments: segments,
        targetDuration: 6,
        initSegment: 'init.mp4',
      );

      // Verify structure is valid M3U8
      final lines = playlist.split('\n').where((l) => l.isNotEmpty).toList();
      expect(lines[0], equals('#EXTM3U'));
      expect(lines.any((l) => l.startsWith('#EXT-X-VERSION:')), isTrue);
      expect(lines.any((l) => l.startsWith('#EXT-X-TARGETDURATION:')), isTrue);
      expect(lines.any((l) => l.startsWith('#EXT-X-MAP:')), isTrue);
      expect(lines.any((l) => l.startsWith('#EXTINF:')), isTrue);
      expect(lines.last, equals('#EXT-X-ENDLIST'));
    });

    test('generates valid MPEG-TS HLS playlist', () {
      final segments = [
        const HlsSegmentInfo(filename: 'segment0.ts', duration: 10),
        const HlsSegmentInfo(filename: 'segment1.ts', duration: 10),
      ];

      final playlist = HlsPlaylistWriter.writeMediaPlaylist(
        segments: segments,
        targetDuration: 10,
        version: 3, // Older version for TS
      );

      // Should not have init segment for TS
      expect(playlist, isNot(contains('#EXT-X-MAP')));
      expect(playlist, contains('#EXT-X-VERSION:3'));
    });
  });
}
