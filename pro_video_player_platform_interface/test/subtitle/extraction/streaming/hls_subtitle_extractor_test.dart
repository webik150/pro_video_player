import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';
import 'package:pro_video_player_platform_interface/src/container/hls_manifest_parser.dart';

void main() {
  group('HlsSubtitleInfo', () {
    test('creates with required parameters', () {
      const info = HlsSubtitleInfo(groupId: 'subs', name: 'English');

      expect(info.groupId, equals('subs'));
      expect(info.name, equals('English'));
      expect(info.language, isNull);
      expect(info.uri, isNull);
      expect(info.isDefault, isFalse);
      expect(info.isAutoSelect, isFalse);
      expect(info.isForced, isFalse);
      expect(info.isSDH, isFalse);
    });

    test('creates with all parameters', () {
      const info = HlsSubtitleInfo(
        groupId: 'subs',
        name: 'English (CC)',
        language: 'en',
        uri: 'https://example.com/subs/en.m3u8',
        isDefault: true,
        isAutoSelect: true,
        isForced: false,
        isSDH: true,
      );

      expect(info.groupId, equals('subs'));
      expect(info.name, equals('English (CC)'));
      expect(info.language, equals('en'));
      expect(info.uri, equals('https://example.com/subs/en.m3u8'));
      expect(info.isDefault, isTrue);
      expect(info.isAutoSelect, isTrue);
      expect(info.isForced, isFalse);
      expect(info.isSDH, isTrue);
    });

    test('creates from HlsSubtitleTrack', () {
      const track = HlsSubtitleTrack(
        groupId: 'subs',
        name: 'Spanish',
        language: 'es',
        uri: 'https://example.com/subs/es.m3u8',
        isDefault: false,
        isAutoSelect: true,
        isForced: true,
        characteristics: 'public.accessibility.describes-video',
      );

      final info = HlsSubtitleInfo.fromTrack(track);

      expect(info.groupId, equals('subs'));
      expect(info.name, equals('Spanish'));
      expect(info.language, equals('es'));
      expect(info.uri, equals('https://example.com/subs/es.m3u8'));
      expect(info.isDefault, isFalse);
      expect(info.isAutoSelect, isTrue);
      expect(info.isForced, isTrue);
      expect(info.isSDH, isTrue);
    });

    test('toString returns readable representation', () {
      const info = HlsSubtitleInfo(groupId: 'subs', name: 'English', language: 'en', isDefault: true, isForced: false);

      final str = info.toString();
      expect(str, contains('HlsSubtitleInfo'));
      expect(str, contains('English'));
      expect(str, contains('en'));
      expect(str, contains('default: true'));
      expect(str, contains('forced: false'));
    });
  });

  group('HlsSubtitleExtractor', () {
    test('creates without client', () {
      final extractor = HlsSubtitleExtractor();
      expect(extractor, isNotNull);
    });

    group('listTracks', () {
      test('returns empty list for invalid URL', () async {
        final extractor = HlsSubtitleExtractor();

        // This will fail to fetch, should return empty list
        final tracks = await extractor.listTracks(Uri.parse('http://invalid.invalid/master.m3u8'));
        expect(tracks, isEmpty);
      });
    });

    group('extractFromTrack', () {
      test('returns empty list when track has no URI', () async {
        final extractor = HlsSubtitleExtractor();
        const track = HlsSubtitleInfo(groupId: 'subs', name: 'English');

        final cues = await extractor.extractFromTrack(Uri.parse('http://example.com/master.m3u8'), track);
        expect(cues, isEmpty);
      });
    });

    group('extractByLanguage', () {
      test('returns empty list for invalid URL', () async {
        final extractor = HlsSubtitleExtractor();

        final cues = await extractor.extractByLanguage(
          Uri.parse('http://invalid.invalid/master.m3u8'),
          preferredLanguages: ['en'],
        );
        expect(cues, isEmpty);
      });
    });
  });

  group('URI resolution', () {
    // Test the URI resolution logic through public API behavior
    test('handles various URI formats', () {
      // The extractor resolves URIs internally
      // We test this indirectly through the track creation
      const info = HlsSubtitleInfo(groupId: 'subs', name: 'Test', uri: 'https://cdn.example.com/subtitles/en.vtt');

      expect(info.uri, startsWith('https://'));
    });
  });

  group('HlsSubtitleExtractor with mock client', () {
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient((request) async {
        final path = request.url.path;

        if (path.endsWith('master.m3u8')) {
          return http.Response('''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="English",LANGUAGE="en",DEFAULT=YES,URI="subs/en.m3u8"
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="Spanish",LANGUAGE="es",DEFAULT=NO,URI="subs/es.m3u8"
#EXT-X-STREAM-INF:BANDWIDTH=1000000,SUBTITLES="subs"
video.m3u8
''', 200);
        }

        if (path.endsWith('en.m3u8')) {
          return http.Response('''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:10
#EXTINF:10.0,
segment1.vtt
#EXTINF:10.0,
segment2.vtt
#EXT-X-ENDLIST
''', 200);
        }

        if (path.endsWith('segment1.vtt')) {
          return http.Response('''WEBVTT

00:00:00.000 --> 00:00:05.000
Hello World

00:00:05.000 --> 00:00:10.000
This is segment 1
''', 200);
        }

        if (path.endsWith('segment2.vtt')) {
          return http.Response('''WEBVTT

00:00:10.000 --> 00:00:15.000
This is segment 2

00:00:15.000 --> 00:00:20.000
Goodbye
''', 200);
        }

        if (path.endsWith('direct.vtt')) {
          return http.Response('''WEBVTT

00:00:00.000 --> 00:00:05.000
Direct VTT content
''', 200);
        }

        return http.Response('Not found', 404);
      });
    });

    test('extracts cues from segmented HLS subtitles', () async {
      final extractor = HlsSubtitleExtractor(client: mockClient);
      const track = HlsSubtitleInfo(groupId: 'subs', name: 'English', language: 'en', uri: 'subs/en.m3u8');

      final cues = await extractor.extractFromTrack(Uri.parse('https://example.com/master.m3u8'), track);

      expect(cues, hasLength(4));
      expect(cues[0].text, equals('Hello World'));
      expect(cues[1].text, equals('This is segment 1'));
      expect(cues[2].text, equals('This is segment 2'));
      expect(cues[3].text, equals('Goodbye'));
    });

    test('extracts cues from direct VTT file', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('direct.vtt')) {
          return http.Response('''WEBVTT

00:00:00.000 --> 00:00:05.000
Direct VTT content
''', 200);
        }
        return http.Response('Not found', 404);
      });

      final extractor = HlsSubtitleExtractor(client: client);
      const track = HlsSubtitleInfo(groupId: 'subs', name: 'English', uri: 'https://example.com/direct.vtt');

      final cues = await extractor.extractFromTrack(Uri.parse('https://example.com/master.m3u8'), track);

      expect(cues, hasLength(1));
      expect(cues[0].text, equals('Direct VTT content'));
    });

    test('returns empty list for 404 response', () async {
      final client = MockClient((request) async => http.Response('Not found', 404));

      final extractor = HlsSubtitleExtractor(client: client);
      const track = HlsSubtitleInfo(groupId: 'subs', name: 'English', uri: 'https://example.com/missing.vtt');

      final cues = await extractor.extractFromTrack(Uri.parse('https://example.com/master.m3u8'), track);
      expect(cues, isEmpty);
    });

    test('handles VTT without WEBVTT header', () async {
      final client = MockClient((request) async {
        return http.Response('''
00:00:00.000 --> 00:00:05.000
No header
''', 200);
      });

      final extractor = HlsSubtitleExtractor(client: client);
      const track = HlsSubtitleInfo(groupId: 'subs', name: 'English', uri: 'https://example.com/noheader.vtt');

      final cues = await extractor.extractFromTrack(Uri.parse('https://example.com/master.m3u8'), track);
      // VTT parser may or may not parse this - just verify no crash
      expect(cues, isNotNull);
    });

    test('resolves relative URIs correctly', () async {
      final requestedUris = <String>[];

      final client = MockClient((request) async {
        requestedUris.add(request.url.toString());

        if (request.url.path.endsWith('relative.vtt')) {
          return http.Response('WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nTest', 200);
        }
        return http.Response('Not found', 404);
      });

      final extractor = HlsSubtitleExtractor(client: client);
      const track = HlsSubtitleInfo(groupId: 'subs', name: 'Test', uri: 'subtitles/relative.vtt');

      await extractor.extractFromTrack(Uri.parse('https://cdn.example.com/video/master.m3u8'), track);

      expect(requestedUris, contains('https://cdn.example.com/video/subtitles/relative.vtt'));
    });

    test('resolves absolute path URIs correctly', () async {
      final requestedUris = <String>[];

      final client = MockClient((request) async {
        requestedUris.add(request.url.toString());
        return http.Response('WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nTest', 200);
      });

      final extractor = HlsSubtitleExtractor(client: client);
      const track = HlsSubtitleInfo(groupId: 'subs', name: 'Test', uri: '/absolute/path.vtt');

      await extractor.extractFromTrack(Uri.parse('https://cdn.example.com/video/master.m3u8'), track);

      expect(requestedUris, contains('https://cdn.example.com/absolute/path.vtt'));
    });

    test('handles absolute URLs in track URI', () async {
      final requestedUris = <String>[];

      final client = MockClient((request) async {
        requestedUris.add(request.url.toString());
        return http.Response('WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nTest', 200);
      });

      final extractor = HlsSubtitleExtractor(client: client);
      const track = HlsSubtitleInfo(groupId: 'subs', name: 'Test', uri: 'https://other.example.com/subs.vtt');

      await extractor.extractFromTrack(Uri.parse('https://cdn.example.com/master.m3u8'), track);

      expect(requestedUris, contains('https://other.example.com/subs.vtt'));
    });

    group('_selectTrack', () {
      test('selects track by preferred language', () async {
        final client = MockClient((request) async {
          if (request.url.path.endsWith('master.m3u8')) {
            return http.Response('''#EXTM3U
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="English",LANGUAGE="en",DEFAULT=NO,URI="en.vtt"
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="Spanish",LANGUAGE="es",DEFAULT=YES,URI="es.vtt"
''', 200);
          }
          if (request.url.path.endsWith('en.vtt')) {
            return http.Response('WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nEnglish', 200);
          }
          if (request.url.path.endsWith('es.vtt')) {
            return http.Response('WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nSpanish', 200);
          }
          return http.Response('Not found', 404);
        });

        final extractor = HlsSubtitleExtractor(client: client);

        final cues = await extractor.extractByLanguage(
          Uri.parse('https://example.com/master.m3u8'),
          preferredLanguages: ['en'],
        );

        expect(cues, hasLength(1));
        expect(cues[0].text, equals('English'));
      });

      test('falls back to default track when no language match', () async {
        final client = MockClient((request) async {
          if (request.url.path.endsWith('master.m3u8')) {
            return http.Response('''#EXTM3U
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="English",LANGUAGE="en",DEFAULT=NO,URI="en.vtt"
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="Spanish",LANGUAGE="es",DEFAULT=YES,URI="es.vtt"
''', 200);
          }
          if (request.url.path.endsWith('es.vtt')) {
            return http.Response('WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nDefault Spanish', 200);
          }
          return http.Response('Not found', 404);
        });

        final extractor = HlsSubtitleExtractor(client: client);

        final cues = await extractor.extractByLanguage(
          Uri.parse('https://example.com/master.m3u8'),
          preferredLanguages: ['fr'], // No French available
        );

        expect(cues, hasLength(1));
        expect(cues[0].text, equals('Default Spanish'));
      });

      test('falls back to first track when no default', () async {
        final client = MockClient((request) async {
          if (request.url.path.endsWith('master.m3u8')) {
            return http.Response('''#EXTM3U
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="English",LANGUAGE="en",DEFAULT=NO,URI="en.vtt"
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="Spanish",LANGUAGE="es",DEFAULT=NO,URI="es.vtt"
''', 200);
          }
          if (request.url.path.endsWith('en.vtt')) {
            return http.Response('WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nFirst Track', 200);
          }
          return http.Response('Not found', 404);
        });

        final extractor = HlsSubtitleExtractor(client: client);

        final cues = await extractor.extractByLanguage(
          Uri.parse('https://example.com/master.m3u8'),
          preferredLanguages: ['fr'], // No French available
        );

        expect(cues, hasLength(1));
        expect(cues[0].text, equals('First Track'));
      });
    });

    group('deduplication', () {
      test('removes duplicate cues from overlapping segments', () async {
        // Simulate HLS segments that repeat cues at boundaries
        final client = MockClient((request) async {
          final path = request.url.path;

          if (path.endsWith('subs.m3u8')) {
            return http.Response('''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:10
#EXTINF:10.0,
segment1.vtt
#EXTINF:10.0,
segment2.vtt
#EXT-X-ENDLIST
''', 200);
          }

          if (path.endsWith('segment1.vtt')) {
            // First segment has cue from 3s-7s
            return http.Response('''WEBVTT

00:00:03.000 --> 00:00:07.000
Captain's log

00:00:07.000 --> 00:00:10.000
Segment 1 only
''', 200);
          }

          if (path.endsWith('segment2.vtt')) {
            // Second segment repeats the 3s-7s cue (common in HLS)
            return http.Response('''WEBVTT

00:00:03.000 --> 00:00:07.000
Captain's log

00:00:10.000 --> 00:00:15.000
Segment 2 only
''', 200);
          }

          return http.Response('Not found', 404);
        });

        final extractor = HlsSubtitleExtractor(client: client);
        const track = HlsSubtitleInfo(groupId: 'subs', name: 'English', uri: 'subs.m3u8');

        final cues = await extractor.extractFromTrack(Uri.parse('https://example.com/master.m3u8'), track);

        // Should have 3 unique cues, not 4 (duplicate removed)
        expect(cues, hasLength(3));
        expect(cues[0].text, equals("Captain's log"));
        expect(cues[0].start, equals(const Duration(seconds: 3)));
        expect(cues[1].text, equals('Segment 1 only'));
        expect(cues[2].text, equals('Segment 2 only'));

        // Verify indices are sequential after deduplication
        expect(cues[0].index, equals(0));
        expect(cues[1].index, equals(1));
        expect(cues[2].index, equals(2));
      });

      test('keeps cues with same text but different timing', () async {
        final client = MockClient((request) async {
          final path = request.url.path;

          if (path.endsWith('subs.m3u8')) {
            return http.Response('''
#EXTM3U
#EXT-X-TARGETDURATION:10
#EXTINF:10.0,
segment.vtt
#EXT-X-ENDLIST
''', 200);
          }

          if (path.endsWith('segment.vtt')) {
            return http.Response('''WEBVTT

00:00:00.000 --> 00:00:05.000
Hello

00:00:10.000 --> 00:00:15.000
Hello
''', 200);
          }

          return http.Response('Not found', 404);
        });

        final extractor = HlsSubtitleExtractor(client: client);
        const track = HlsSubtitleInfo(groupId: 'subs', name: 'English', uri: 'subs.m3u8');

        final cues = await extractor.extractFromTrack(Uri.parse('https://example.com/master.m3u8'), track);

        // Both cues should be kept - same text but different timing
        expect(cues, hasLength(2));
        expect(cues[0].text, equals('Hello'));
        expect(cues[0].start, equals(Duration.zero));
        expect(cues[1].text, equals('Hello'));
        expect(cues[1].start, equals(const Duration(seconds: 10)));
      });
    });

    group('_languageMatches', () {
      test('matches exact language codes', () async {
        final client = MockClient((request) async {
          if (request.url.path.endsWith('master.m3u8')) {
            return http.Response('''#EXTM3U
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="English",LANGUAGE="en",URI="en.vtt"
''', 200);
          }
          if (request.url.path.endsWith('en.vtt')) {
            return http.Response('WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nMatched', 200);
          }
          return http.Response('Not found', 404);
        });

        final extractor = HlsSubtitleExtractor(client: client);

        final cues = await extractor.extractByLanguage(
          Uri.parse('https://example.com/master.m3u8'),
          preferredLanguages: ['en'],
        );

        expect(cues, hasLength(1));
      });

      test('matches language code prefixes', () async {
        final client = MockClient((request) async {
          if (request.url.path.endsWith('master.m3u8')) {
            return http.Response('''#EXTM3U
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="English",LANGUAGE="eng",URI="eng.vtt"
''', 200);
          }
          if (request.url.path.endsWith('eng.vtt')) {
            return http.Response('WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nMatched eng', 200);
          }
          return http.Response('Not found', 404);
        });

        final extractor = HlsSubtitleExtractor(client: client);

        // "en" should match "eng" via prefix matching
        final cues = await extractor.extractByLanguage(
          Uri.parse('https://example.com/master.m3u8'),
          preferredLanguages: ['en'],
        );

        expect(cues, hasLength(1));
      });
    });
  });
}
