import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/src/container/dash_manifest_parser.dart';

void main() {
  group('DashManifestParser', () {
    group('parse', () {
      test('returns null for non-DASH content', () {
        final result = DashManifestParser.parse('not a dash manifest');
        expect(result, isNull);
      });

      test('parses simple MPD with video representations', () {
        const content = '''
<?xml version="1.0"?>
<MPD xmlns="urn:mpeg:dash:schema:mpd:2011" type="static" mediaPresentationDuration="PT1H30M">
  <Period>
    <AdaptationSet contentType="video" mimeType="video/mp4">
      <Representation id="1" bandwidth="1000000" width="1280" height="720" codecs="avc1.64001f"/>
      <Representation id="2" bandwidth="2500000" width="1920" height="1080" codecs="avc1.640028"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

        final result = DashManifestParser.parse(content);

        expect(result, isNotNull);
        expect(result!.videoRepresentations.length, equals(2));
        expect(result.isLive, isFalse);

        final rep720 = result.videoRepresentations[0];
        expect(rep720.id, equals('1'));
        expect(rep720.bandwidth, equals(1000000));
        expect(rep720.width, equals(1280));
        expect(rep720.height, equals(720));
        expect(rep720.codecs, equals('avc1.64001f'));
        expect(rep720.qualityLabel, equals('720p'));

        final rep1080 = result.videoRepresentations[1];
        expect(rep1080.qualityLabel, equals('1080p'));
      });

      test('parses audio representations', () {
        const content = '''
<MPD>
  <Period>
    <AdaptationSet contentType="audio" mimeType="audio/mp4" lang="en">
      <Representation id="audio-en" bandwidth="128000" codecs="mp4a.40.2" audioSamplingRate="48000"/>
    </AdaptationSet>
    <AdaptationSet contentType="audio" mimeType="audio/mp4" lang="es">
      <Representation id="audio-es" bandwidth="128000" codecs="mp4a.40.2"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

        final result = DashManifestParser.parse(content);

        expect(result, isNotNull);
        expect(result!.audioRepresentations.length, equals(2));

        final english = result.audioRepresentations[0];
        expect(english.id, equals('audio-en'));
        expect(english.language, equals('en'));
        expect(english.codecs, equals('mp4a.40.2'));
        expect(english.audioSamplingRate, equals(48000));
        expect(english.isAudio, isTrue);

        final spanish = result.audioRepresentations[1];
        expect(spanish.language, equals('es'));
      });

      test('parses subtitle representations', () {
        const content = '''
<MPD>
  <Period>
    <AdaptationSet contentType="text" mimeType="text/vtt" lang="en" label="English">
      <Representation id="sub-en" bandwidth="1000"/>
    </AdaptationSet>
    <AdaptationSet contentType="text" mimeType="application/ttml+xml" lang="es" label="Spanish">
      <Representation id="sub-es" bandwidth="1000"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

        final result = DashManifestParser.parse(content);

        expect(result, isNotNull);
        expect(result!.subtitleRepresentations.length, equals(2));

        final english = result.subtitleRepresentations[0];
        expect(english.id, equals('sub-en'));
        expect(english.language, equals('en'));
        expect(english.label, equals('English'));
        expect(english.isSubtitle, isTrue);
      });

      test('detects live stream (type=dynamic)', () {
        const content = '''
<MPD type="dynamic" minBufferTime="PT2S">
  <Period>
    <AdaptationSet contentType="video">
      <Representation id="1" bandwidth="1000000"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

        final result = DashManifestParser.parse(content);

        expect(result, isNotNull);
        expect(result!.isLive, isTrue);
      });

      test('parses duration correctly', () {
        const content = '''
<MPD mediaPresentationDuration="PT1H30M45S">
  <Period>
    <AdaptationSet contentType="video">
      <Representation id="1" bandwidth="1000000"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

        final result = DashManifestParser.parse(content);

        expect(result, isNotNull);
        expect(result!.duration, isNotNull);
        expect(result.duration!.inHours, equals(1));
        expect(result.duration!.inMinutes % 60, equals(30));
        expect(result.duration!.inSeconds % 60, equals(45));
      });

      test('parses duration with fractional seconds', () {
        const content = '''
<MPD mediaPresentationDuration="PT45.5S">
  <Period>
    <AdaptationSet contentType="video">
      <Representation id="1" bandwidth="1000000"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

        final result = DashManifestParser.parse(content);

        expect(result, isNotNull);
        expect(result!.duration!.inSeconds, equals(45));
        expect(result.duration!.inMilliseconds % 1000, equals(500));
      });

      test('parses minBufferTime', () {
        const content = '''
<MPD minBufferTime="PT2S">
  <Period>
    <AdaptationSet contentType="video">
      <Representation id="1" bandwidth="1000000"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

        final result = DashManifestParser.parse(content);

        expect(result, isNotNull);
        expect(result!.minBufferTime, equals(const Duration(seconds: 2)));
      });

      test('parses profiles', () {
        const content = '''
<MPD profiles="urn:mpeg:dash:profile:isoff-on-demand:2011,urn:mpeg:dash:profile:isoff-live:2011">
  <Period>
    <AdaptationSet contentType="video">
      <Representation id="1" bandwidth="1000000"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

        final result = DashManifestParser.parse(content);

        expect(result, isNotNull);
        expect(result!.profiles.length, equals(2));
        expect(result.profiles[0], contains('isoff-on-demand'));
      });

      test('parses frameRate attribute', () {
        const content = '''
<MPD>
  <Period>
    <AdaptationSet contentType="video">
      <Representation id="1" bandwidth="1000000" frameRate="30"/>
      <Representation id="2" bandwidth="2000000" frameRate="30/1"/>
      <Representation id="3" bandwidth="3000000" frameRate="29.97"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

        final result = DashManifestParser.parse(content);

        expect(result, isNotNull);
        expect(result!.videoRepresentations[0].frameRate, equals('30'));
        expect(result.videoRepresentations[0].frameRateValue, equals(30.0));

        expect(result.videoRepresentations[1].frameRate, equals('30/1'));
        expect(result.videoRepresentations[1].frameRateValue, equals(30.0));

        expect(result.videoRepresentations[2].frameRateValue, closeTo(29.97, 0.01));
      });

      test('inherits attributes from AdaptationSet', () {
        const content = '''
<MPD>
  <Period>
    <AdaptationSet contentType="video" codecs="avc1.64001f" width="1920" height="1080" frameRate="24">
      <Representation id="1" bandwidth="5000000"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

        final result = DashManifestParser.parse(content);

        expect(result, isNotNull);
        final rep = result!.videoRepresentations[0];
        expect(rep.codecs, equals('avc1.64001f'));
        expect(rep.width, equals(1920));
        expect(rep.height, equals(1080));
        expect(rep.frameRate, equals('24'));
      });

      test('infers content type from mimeType', () {
        const content = '''
<MPD>
  <Period>
    <AdaptationSet mimeType="video/mp4">
      <Representation id="1" bandwidth="1000000"/>
    </AdaptationSet>
    <AdaptationSet mimeType="audio/mp4">
      <Representation id="2" bandwidth="128000"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

        final result = DashManifestParser.parse(content);

        expect(result, isNotNull);
        expect(result!.videoRepresentations.length, equals(1));
        expect(result.audioRepresentations.length, equals(1));
      });

      test('parses audio channel configuration', () {
        const content = '''
<MPD>
  <Period>
    <AdaptationSet contentType="audio">
      <AudioChannelConfiguration value="6"/>
      <Representation id="1" bandwidth="384000"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

        final result = DashManifestParser.parse(content);

        expect(result, isNotNull);
        expect(result!.audioRepresentations[0].audioChannels, equals(6));
      });

      test('parses HEVC codecs', () {
        const content = '''
<MPD>
  <Period>
    <AdaptationSet contentType="video">
      <Representation id="1" bandwidth="8000000" codecs="hvc1.1.6.L93.B0" width="3840" height="2160"/>
    </AdaptationSet>
  </Period>
</MPD>
''';

        final result = DashManifestParser.parse(content);

        expect(result, isNotNull);
        final rep = result!.videoRepresentations[0];
        expect(rep.codecs, equals('hvc1.1.6.L93.B0'));
        expect(rep.qualityLabel, equals('4K'));
      });
    });

    group('DashRepresentation', () {
      test('qualityLabel returns correct labels for common resolutions', () {
        expect(const DashRepresentation(id: '1', bandwidth: 1000000, height: 2160).qualityLabel, equals('4K'));
        expect(const DashRepresentation(id: '1', bandwidth: 1000000, height: 1440).qualityLabel, equals('1440p'));
        expect(const DashRepresentation(id: '1', bandwidth: 1000000, height: 1080).qualityLabel, equals('1080p'));
        expect(const DashRepresentation(id: '1', bandwidth: 1000000, height: 720).qualityLabel, equals('720p'));
        expect(const DashRepresentation(id: '1', bandwidth: 1000000, height: 480).qualityLabel, equals('480p'));
      });

      test('qualityLabel returns bandwidth when no height', () {
        expect(const DashRepresentation(id: '1', bandwidth: 5000000).qualityLabel, equals('5000 kbps'));
      });

      test('isVideo returns true for video content', () {
        expect(const DashRepresentation(id: '1', bandwidth: 1000000, contentType: 'video').isVideo, isTrue);
        expect(const DashRepresentation(id: '1', bandwidth: 1000000, mimeType: 'video/mp4').isVideo, isTrue);
      });

      test('isAudio returns true for audio content', () {
        expect(const DashRepresentation(id: '1', bandwidth: 1000000, contentType: 'audio').isAudio, isTrue);
        expect(const DashRepresentation(id: '1', bandwidth: 1000000, mimeType: 'audio/mp4').isAudio, isTrue);
      });

      test('isSubtitle returns true for text content', () {
        expect(const DashRepresentation(id: '1', bandwidth: 1000, contentType: 'text').isSubtitle, isTrue);
        expect(const DashRepresentation(id: '1', bandwidth: 1000, mimeType: 'text/vtt').isSubtitle, isTrue);
        expect(const DashRepresentation(id: '1', bandwidth: 1000, mimeType: 'application/ttml+xml').isSubtitle, isTrue);
      });
    });

    group('DashManifestMetadata', () {
      test('highestQualityVideo returns representation with highest bandwidth', () {
        const metadata = DashManifestMetadata(
          videoRepresentations: [
            DashRepresentation(id: '1', bandwidth: 1000000),
            DashRepresentation(id: '2', bandwidth: 5000000),
            DashRepresentation(id: '3', bandwidth: 10000000),
          ],
        );

        expect(metadata.highestQualityVideo?.bandwidth, equals(10000000));
      });

      test('lowestQualityVideo returns representation with lowest bandwidth', () {
        const metadata = DashManifestMetadata(
          videoRepresentations: [
            DashRepresentation(id: '1', bandwidth: 1000000),
            DashRepresentation(id: '2', bandwidth: 5000000),
            DashRepresentation(id: '3', bandwidth: 10000000),
          ],
        );

        expect(metadata.lowestQualityVideo?.bandwidth, equals(1000000));
      });

      test('videoByBandwidth returns sorted list', () {
        const metadata = DashManifestMetadata(
          videoRepresentations: [
            DashRepresentation(id: '2', bandwidth: 5000000),
            DashRepresentation(id: '3', bandwidth: 10000000),
            DashRepresentation(id: '1', bandwidth: 1000000),
          ],
        );

        final sorted = metadata.videoByBandwidth;
        expect(sorted[0].bandwidth, equals(1000000));
        expect(sorted[1].bandwidth, equals(5000000));
        expect(sorted[2].bandwidth, equals(10000000));
      });

      test('highestQualityVideo returns null for empty list', () {
        const metadata = DashManifestMetadata(videoRepresentations: []);
        expect(metadata.highestQualityVideo, isNull);
      });
    });
  });
}
