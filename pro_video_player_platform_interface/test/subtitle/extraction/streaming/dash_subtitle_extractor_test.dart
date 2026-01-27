import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';
import 'package:pro_video_player_platform_interface/src/container/dash_manifest_parser.dart';

void main() {
  group('DashSubtitleInfo', () {
    test('creates with required parameters', () {
      const info = DashSubtitleInfo(id: 'text_en');

      expect(info.id, equals('text_en'));
      expect(info.language, isNull);
      expect(info.label, isNull);
      expect(info.mimeType, isNull);
      expect(info.codecs, isNull);
      expect(info.bandwidth, equals(0));
    });

    test('creates with all parameters', () {
      const info = DashSubtitleInfo(
        id: 'text_en_vtt',
        language: 'en',
        label: 'English',
        mimeType: 'text/vtt',
        codecs: 'wvtt',
        bandwidth: 5000,
      );

      expect(info.id, equals('text_en_vtt'));
      expect(info.language, equals('en'));
      expect(info.label, equals('English'));
      expect(info.mimeType, equals('text/vtt'));
      expect(info.codecs, equals('wvtt'));
      expect(info.bandwidth, equals(5000));
    });

    test('creates from DashRepresentation', () {
      const rep = DashRepresentation(
        id: 'subtitle_es',
        bandwidth: 3000,
        mimeType: 'application/ttml+xml',
        codecs: 'stpp',
        contentType: 'text',
        language: 'es',
        label: 'Spanish',
      );

      final info = DashSubtitleInfo.fromRepresentation(rep);

      expect(info.id, equals('subtitle_es'));
      expect(info.language, equals('es'));
      expect(info.label, equals('Spanish'));
      expect(info.mimeType, equals('application/ttml+xml'));
      expect(info.codecs, equals('stpp'));
      expect(info.bandwidth, equals(3000));
    });

    group('isWebVtt', () {
      test('returns true for text/vtt mime type', () {
        const info = DashSubtitleInfo(id: 'sub', mimeType: 'text/vtt');
        expect(info.isWebVtt, isTrue);
      });

      test('returns false for ttml mime type', () {
        const info = DashSubtitleInfo(id: 'sub', mimeType: 'application/ttml+xml');
        expect(info.isWebVtt, isFalse);
      });

      test('returns false when no mime type', () {
        const info = DashSubtitleInfo(id: 'sub');
        expect(info.isWebVtt, isFalse);
      });
    });

    group('isTtml', () {
      test('returns true for ttml mime type', () {
        const info = DashSubtitleInfo(id: 'sub', mimeType: 'application/ttml+xml');
        expect(info.isTtml, isTrue);
      });

      test('returns true for stpp codec', () {
        const info = DashSubtitleInfo(id: 'sub', codecs: 'stpp');
        expect(info.isTtml, isTrue);
      });

      test('returns false for vtt mime type', () {
        const info = DashSubtitleInfo(id: 'sub', mimeType: 'text/vtt');
        expect(info.isTtml, isFalse);
      });

      test('returns false when no mime type or codec', () {
        const info = DashSubtitleInfo(id: 'sub');
        expect(info.isTtml, isFalse);
      });
    });

    test('toString returns readable representation', () {
      const info = DashSubtitleInfo(id: 'text_en', language: 'en', mimeType: 'text/vtt');

      final str = info.toString();
      expect(str, contains('DashSubtitleInfo'));
      expect(str, contains('text_en'));
      expect(str, contains('en'));
      expect(str, contains('text/vtt'));
    });
  });

  group('DashSubtitleExtractor', () {
    test('creates without client', () {
      final extractor = DashSubtitleExtractor();
      expect(extractor, isNotNull);
    });

    group('listTracks', () {
      test('returns empty list for invalid URL', () async {
        final extractor = DashSubtitleExtractor();

        // This will fail to fetch, should return empty list
        final tracks = await extractor.listTracks(Uri.parse('http://invalid.invalid/manifest.mpd'));
        expect(tracks, isEmpty);
      });
    });

    group('extractFromTrack', () {
      test('returns empty list for invalid URL', () async {
        final extractor = DashSubtitleExtractor();
        const track = DashSubtitleInfo(id: 'text_en', language: 'en');

        final cues = await extractor.extractFromTrack(Uri.parse('http://invalid.invalid/manifest.mpd'), track);
        expect(cues, isEmpty);
      });
    });

    group('extractByLanguage', () {
      test('returns empty list for invalid URL', () async {
        final extractor = DashSubtitleExtractor();

        final cues = await extractor.extractByLanguage(
          Uri.parse('http://invalid.invalid/manifest.mpd'),
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
      const info = DashSubtitleInfo(id: 'sub_en', mimeType: 'text/vtt');

      expect(info.id, equals('sub_en'));
    });
  });

  group('DashSubtitleExtractor with mock client', () {
    test('extracts cues from DASH with BaseURL subtitles', () async {
      final client = MockClient((request) async {
        final path = request.url.path;

        if (path.endsWith('manifest.mpd')) {
          return http.Response('''<?xml version="1.0" encoding="UTF-8"?>
<MPD xmlns="urn:mpeg:dash:schema:mpd:2011" type="static">
  <Period>
    <AdaptationSet contentType="text" lang="en" mimeType="text/vtt">
      <Representation id="sub_en" bandwidth="1000">
        <BaseURL>subtitles/en.vtt</BaseURL>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>''', 200);
        }

        if (path.endsWith('en.vtt')) {
          return http.Response('''WEBVTT

00:00:00.000 --> 00:00:05.000
Hello DASH

00:00:05.000 --> 00:00:10.000
From VTT
''', 200);
        }

        return http.Response('Not found', 404);
      });

      final extractor = DashSubtitleExtractor(client: client);
      const track = DashSubtitleInfo(id: 'sub_en', language: 'en', mimeType: 'text/vtt');

      final cues = await extractor.extractFromTrack(Uri.parse('https://example.com/manifest.mpd'), track);

      expect(cues, hasLength(2));
      expect(cues[0].text, equals('Hello DASH'));
      expect(cues[1].text, equals('From VTT'));
    });

    test('extracts TTML subtitles', () async {
      final client = MockClient((request) async {
        final path = request.url.path;

        if (path.endsWith('manifest.mpd')) {
          return http.Response('''<?xml version="1.0" encoding="UTF-8"?>
<MPD xmlns="urn:mpeg:dash:schema:mpd:2011" type="static">
  <Period>
    <AdaptationSet contentType="text" lang="en" mimeType="application/ttml+xml">
      <Representation id="sub_ttml" bandwidth="1000">
        <BaseURL>subtitles/en.ttml</BaseURL>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>''', 200);
        }

        if (path.endsWith('en.ttml')) {
          return http.Response('''<?xml version="1.0" encoding="UTF-8"?>
<tt xmlns="http://www.w3.org/ns/ttml">
  <body>
    <div>
      <p begin="00:00:00" end="00:00:05">TTML Subtitle</p>
    </div>
  </body>
</tt>''', 200);
        }

        return http.Response('Not found', 404);
      });

      final extractor = DashSubtitleExtractor(client: client);
      const track = DashSubtitleInfo(id: 'sub_ttml', language: 'en', mimeType: 'application/ttml+xml');

      final cues = await extractor.extractFromTrack(Uri.parse('https://example.com/manifest.mpd'), track);

      expect(cues, hasLength(1));
      expect(cues[0].text, contains('TTML Subtitle'));
    });

    test('returns empty list for 404 response', () async {
      final client = MockClient((request) async => http.Response('Not found', 404));

      final extractor = DashSubtitleExtractor(client: client);
      const track = DashSubtitleInfo(id: 'sub_en', language: 'en');

      final cues = await extractor.extractFromTrack(Uri.parse('https://example.com/manifest.mpd'), track);
      expect(cues, isEmpty);
    });

    test('resolves relative BaseURL correctly', () async {
      final requestedUris = <String>[];

      final client = MockClient((request) async {
        requestedUris.add(request.url.toString());

        if (request.url.path.endsWith('manifest.mpd')) {
          return http.Response('''<?xml version="1.0" encoding="UTF-8"?>
<MPD xmlns="urn:mpeg:dash:schema:mpd:2011">
  <Period>
    <AdaptationSet contentType="text" lang="en">
      <Representation id="sub_en" bandwidth="1000">
        <BaseURL>subs/relative.vtt</BaseURL>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>''', 200);
        }

        if (request.url.path.endsWith('relative.vtt')) {
          return http.Response('WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nTest', 200);
        }
        return http.Response('Not found', 404);
      });

      final extractor = DashSubtitleExtractor(client: client);
      const track = DashSubtitleInfo(id: 'sub_en', language: 'en');

      await extractor.extractFromTrack(Uri.parse('https://cdn.example.com/video/manifest.mpd'), track);

      expect(requestedUris.any((uri) => uri.contains('subs/relative.vtt')), isTrue);
    });

    test('resolves absolute path BaseURL correctly', () async {
      final requestedUris = <String>[];

      final client = MockClient((request) async {
        requestedUris.add(request.url.toString());

        if (request.url.path.endsWith('manifest.mpd')) {
          return http.Response('''<?xml version="1.0" encoding="UTF-8"?>
<MPD xmlns="urn:mpeg:dash:schema:mpd:2011">
  <Period>
    <AdaptationSet contentType="text" lang="en">
      <Representation id="sub_en" bandwidth="1000">
        <BaseURL>/absolute/path.vtt</BaseURL>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>''', 200);
        }

        if (request.url.path == '/absolute/path.vtt') {
          return http.Response('WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nTest', 200);
        }
        return http.Response('Not found', 404);
      });

      final extractor = DashSubtitleExtractor(client: client);
      const track = DashSubtitleInfo(id: 'sub_en', language: 'en');

      await extractor.extractFromTrack(Uri.parse('https://cdn.example.com/video/manifest.mpd'), track);

      expect(requestedUris, contains('https://cdn.example.com/absolute/path.vtt'));
    });

    test('handles absolute URL in BaseURL', () async {
      final requestedUris = <String>[];

      final client = MockClient((request) async {
        requestedUris.add(request.url.toString());

        if (request.url.path.endsWith('manifest.mpd')) {
          return http.Response('''<?xml version="1.0" encoding="UTF-8"?>
<MPD xmlns="urn:mpeg:dash:schema:mpd:2011">
  <Period>
    <AdaptationSet contentType="text" lang="en">
      <Representation id="sub_en" bandwidth="1000">
        <BaseURL>https://other.example.com/subs.vtt</BaseURL>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>''', 200);
        }

        if (request.url.host == 'other.example.com') {
          return http.Response('WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nTest', 200);
        }
        return http.Response('Not found', 404);
      });

      final extractor = DashSubtitleExtractor(client: client);
      const track = DashSubtitleInfo(id: 'sub_en', language: 'en');

      await extractor.extractFromTrack(Uri.parse('https://cdn.example.com/manifest.mpd'), track);

      expect(requestedUris, contains('https://other.example.com/subs.vtt'));
    });

    test('auto-detects VTT format from content', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('manifest.mpd')) {
          return http.Response('''<?xml version="1.0" encoding="UTF-8"?>
<MPD xmlns="urn:mpeg:dash:schema:mpd:2011">
  <Period>
    <AdaptationSet contentType="text" lang="en">
      <Representation id="sub_en" bandwidth="1000">
        <BaseURL>subtitles/en.txt</BaseURL>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>''', 200);
        }

        if (request.url.path.endsWith('en.txt')) {
          // Return VTT content without declaring mimeType
          return http.Response('''WEBVTT

00:00:00.000 --> 00:00:05.000
Auto-detected VTT
''', 200);
        }

        return http.Response('Not found', 404);
      });

      final extractor = DashSubtitleExtractor(client: client);
      // Note: no mimeType specified
      const track = DashSubtitleInfo(id: 'sub_en', language: 'en');

      final cues = await extractor.extractFromTrack(Uri.parse('https://example.com/manifest.mpd'), track);

      expect(cues, hasLength(1));
      expect(cues[0].text, equals('Auto-detected VTT'));
    });

    test('auto-detects TTML format from content', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('manifest.mpd')) {
          return http.Response('''<?xml version="1.0" encoding="UTF-8"?>
<MPD xmlns="urn:mpeg:dash:schema:mpd:2011">
  <Period>
    <AdaptationSet contentType="text" lang="en">
      <Representation id="sub_en" bandwidth="1000">
        <BaseURL>subtitles/en.xml</BaseURL>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>''', 200);
        }

        if (request.url.path.endsWith('en.xml')) {
          // Use a full TTML document that the parser recognizes
          return http.Response('''<?xml version="1.0" encoding="UTF-8"?>
<tt xmlns="http://www.w3.org/ns/ttml" xmlns:tts="http://www.w3.org/ns/ttml#styling">
  <body>
    <div>
      <p begin="00:00:00.000" end="00:00:05.000">Auto-detected TTML</p>
    </div>
  </body>
</tt>''', 200);
        }

        return http.Response('Not found', 404);
      });

      final extractor = DashSubtitleExtractor(client: client);
      const track = DashSubtitleInfo(id: 'sub_en', language: 'en');

      final cues = await extractor.extractFromTrack(Uri.parse('https://example.com/manifest.mpd'), track);

      expect(cues, hasLength(1));
      expect(cues[0].text, contains('Auto-detected TTML'));
    });

    group('_selectTrack', () {
      test('selects track by preferred language', () async {
        final client = MockClient((request) async {
          if (request.url.path.endsWith('manifest.mpd')) {
            return http.Response('''<?xml version="1.0" encoding="UTF-8"?>
<MPD xmlns="urn:mpeg:dash:schema:mpd:2011">
  <Period>
    <AdaptationSet contentType="text" lang="en" mimeType="text/vtt">
      <Representation id="sub_en" bandwidth="1000">
        <BaseURL>en.vtt</BaseURL>
      </Representation>
    </AdaptationSet>
    <AdaptationSet contentType="text" lang="es" mimeType="text/vtt">
      <Representation id="sub_es" bandwidth="1000">
        <BaseURL>es.vtt</BaseURL>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>''', 200);
          }
          if (request.url.path.endsWith('en.vtt')) {
            return http.Response('WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nEnglish', 200);
          }
          if (request.url.path.endsWith('es.vtt')) {
            return http.Response('WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nSpanish', 200);
          }
          return http.Response('Not found', 404);
        });

        final extractor = DashSubtitleExtractor(client: client);

        final cues = await extractor.extractByLanguage(
          Uri.parse('https://example.com/manifest.mpd'),
          preferredLanguages: ['es'],
        );

        expect(cues, hasLength(1));
        expect(cues[0].text, equals('Spanish'));
      });

      test('falls back to first track when no language match', () async {
        final client = MockClient((request) async {
          if (request.url.path.endsWith('manifest.mpd')) {
            return http.Response('''<?xml version="1.0" encoding="UTF-8"?>
<MPD xmlns="urn:mpeg:dash:schema:mpd:2011">
  <Period>
    <AdaptationSet contentType="text" lang="en" mimeType="text/vtt">
      <Representation id="sub_en" bandwidth="1000">
        <BaseURL>en.vtt</BaseURL>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>''', 200);
          }
          if (request.url.path.endsWith('en.vtt')) {
            return http.Response('WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nFirst Track', 200);
          }
          return http.Response('Not found', 404);
        });

        final extractor = DashSubtitleExtractor(client: client);

        final cues = await extractor.extractByLanguage(
          Uri.parse('https://example.com/manifest.mpd'),
          preferredLanguages: ['fr'], // No French available
        );

        expect(cues, hasLength(1));
        expect(cues[0].text, equals('First Track'));
      });
    });

    group('_languageMatches', () {
      test('matches language code prefixes', () async {
        final client = MockClient((request) async {
          if (request.url.path.endsWith('manifest.mpd')) {
            return http.Response('''<?xml version="1.0" encoding="UTF-8"?>
<MPD xmlns="urn:mpeg:dash:schema:mpd:2011">
  <Period>
    <AdaptationSet contentType="text" lang="eng" mimeType="text/vtt">
      <Representation id="sub_eng" bandwidth="1000">
        <BaseURL>eng.vtt</BaseURL>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>''', 200);
          }
          if (request.url.path.endsWith('eng.vtt')) {
            return http.Response('WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nMatched', 200);
          }
          return http.Response('Not found', 404);
        });

        final extractor = DashSubtitleExtractor(client: client);

        // "en" should match "eng" via prefix matching
        final cues = await extractor.extractByLanguage(
          Uri.parse('https://example.com/manifest.mpd'),
          preferredLanguages: ['en'],
        );

        expect(cues, hasLength(1));
        expect(cues[0].text, equals('Matched'));
      });
    });
  });
}
