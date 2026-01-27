/// Tests for video_player compatibility caption file parsers.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player/video_player_compat.dart';

void main() {
  group('ClosedCaptionFile', () {
    test('is abstract class with captions getter', () {
      // SubRipCaptionFile and WebVTTCaptionFile extend ClosedCaptionFile
      final srt = SubRipCaptionFile('');
      expect(srt, isA<ClosedCaptionFile>());
      expect(srt.captions, isA<List<Caption>>());
    });
  });

  group('SubRipCaptionFile', () {
    test('parses empty file', () {
      final file = SubRipCaptionFile('');

      expect(file.captions, isEmpty);
      expect(file.fileContents, isEmpty);
    });

    test('parses simple SRT file', () {
      const srtContent = '''
1
00:00:01,000 --> 00:00:04,000
Hello, world!

2
00:00:05,000 --> 00:00:08,000
This is a subtitle.
''';

      final file = SubRipCaptionFile(srtContent);

      expect(file.captions, hasLength(2));
      expect(file.captions[0].number, equals(1));
      expect(file.captions[0].start, equals(const Duration(seconds: 1)));
      expect(file.captions[0].end, equals(const Duration(seconds: 4)));
      expect(file.captions[0].text, equals('Hello, world!'));

      expect(file.captions[1].number, equals(2));
      expect(file.captions[1].start, equals(const Duration(seconds: 5)));
      expect(file.captions[1].end, equals(const Duration(seconds: 8)));
      expect(file.captions[1].text, equals('This is a subtitle.'));
    });

    test('parses SRT with milliseconds', () {
      const srtContent = '''
1
00:01:30,500 --> 00:01:35,750
Caption with milliseconds
''';

      final file = SubRipCaptionFile(srtContent);

      expect(file.captions, hasLength(1));
      expect(file.captions[0].start, equals(const Duration(minutes: 1, seconds: 30, milliseconds: 500)));
      expect(file.captions[0].end, equals(const Duration(minutes: 1, seconds: 35, milliseconds: 750)));
    });

    test('parses multi-line captions', () {
      const srtContent = '''
1
00:00:01,000 --> 00:00:04,000
Line one
Line two
''';

      final file = SubRipCaptionFile(srtContent);

      expect(file.captions, hasLength(1));
      expect(file.captions[0].text, contains('Line one'));
      expect(file.captions[0].text, contains('Line two'));
    });

    test('preserves original fileContents', () {
      const srtContent = '''
1
00:00:01,000 --> 00:00:04,000
Test
''';

      final file = SubRipCaptionFile(srtContent);

      expect(file.fileContents, equals(srtContent));
    });

    test('numbers captions sequentially starting from 1', () {
      const srtContent = '''
1
00:00:01,000 --> 00:00:02,000
First

2
00:00:03,000 --> 00:00:04,000
Second

3
00:00:05,000 --> 00:00:06,000
Third
''';

      final file = SubRipCaptionFile(srtContent);

      expect(file.captions, hasLength(3));
      expect(file.captions[0].number, equals(1));
      expect(file.captions[1].number, equals(2));
      expect(file.captions[2].number, equals(3));
    });
  });

  group('WebVTTCaptionFile', () {
    test('parses empty file', () {
      final file = WebVTTCaptionFile('');

      expect(file.captions, isEmpty);
      expect(file.fileContents, isEmpty);
    });

    test('parses simple WebVTT file', () {
      const vttContent = '''
WEBVTT

00:00:01.000 --> 00:00:04.000
Hello, world!

00:00:05.000 --> 00:00:08.000
This is a subtitle.
''';

      final file = WebVTTCaptionFile(vttContent);

      expect(file.captions, hasLength(2));
      expect(file.captions[0].number, equals(1));
      expect(file.captions[0].start, equals(const Duration(seconds: 1)));
      expect(file.captions[0].end, equals(const Duration(seconds: 4)));
      expect(file.captions[0].text, equals('Hello, world!'));

      expect(file.captions[1].number, equals(2));
      expect(file.captions[1].start, equals(const Duration(seconds: 5)));
      expect(file.captions[1].end, equals(const Duration(seconds: 8)));
      expect(file.captions[1].text, equals('This is a subtitle.'));
    });

    test('parses WebVTT with milliseconds', () {
      const vttContent = '''
WEBVTT

00:01:30.500 --> 00:01:35.750
Caption with milliseconds
''';

      final file = WebVTTCaptionFile(vttContent);

      expect(file.captions, hasLength(1));
      expect(file.captions[0].start, equals(const Duration(minutes: 1, seconds: 30, milliseconds: 500)));
      expect(file.captions[0].end, equals(const Duration(minutes: 1, seconds: 35, milliseconds: 750)));
    });

    test('parses WebVTT with cue identifiers', () {
      const vttContent = '''
WEBVTT

1
00:00:01.000 --> 00:00:04.000
First cue

second-cue
00:00:05.000 --> 00:00:08.000
Second cue
''';

      final file = WebVTTCaptionFile(vttContent);

      expect(file.captions, hasLength(2));
      expect(file.captions[0].text, equals('First cue'));
      expect(file.captions[1].text, equals('Second cue'));
    });

    test('parses multi-line captions', () {
      const vttContent = '''
WEBVTT

00:00:01.000 --> 00:00:04.000
Line one
Line two
''';

      final file = WebVTTCaptionFile(vttContent);

      expect(file.captions, hasLength(1));
      expect(file.captions[0].text, contains('Line one'));
      expect(file.captions[0].text, contains('Line two'));
    });

    test('preserves original fileContents', () {
      const vttContent = '''
WEBVTT

00:00:01.000 --> 00:00:04.000
Test
''';

      final file = WebVTTCaptionFile(vttContent);

      expect(file.fileContents, equals(vttContent));
    });

    test('handles WebVTT header variations', () {
      const vttContent = '''
WEBVTT - This is a comment

00:00:01.000 --> 00:00:04.000
Test
''';

      final file = WebVTTCaptionFile(vttContent);

      expect(file.captions, hasLength(1));
      expect(file.captions[0].text, equals('Test'));
    });
  });

  group('Caption number assignment', () {
    test('SubRipCaptionFile assigns sequential numbers', () {
      const srtContent = '''
100
00:00:01,000 --> 00:00:02,000
First

200
00:00:03,000 --> 00:00:04,000
Second
''';

      final file = SubRipCaptionFile(srtContent);

      // Numbers are assigned by position, not from file
      expect(file.captions[0].number, equals(1));
      expect(file.captions[1].number, equals(2));
    });

    test('WebVTTCaptionFile assigns sequential numbers', () {
      const vttContent = '''
WEBVTT

00:00:01.000 --> 00:00:02.000
First

00:00:03.000 --> 00:00:04.000
Second

00:00:05.000 --> 00:00:06.000
Third
''';

      final file = WebVTTCaptionFile(vttContent);

      expect(file.captions[0].number, equals(1));
      expect(file.captions[1].number, equals(2));
      expect(file.captions[2].number, equals(3));
    });
  });
}
