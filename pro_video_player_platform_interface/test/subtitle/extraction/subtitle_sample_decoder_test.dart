import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/src/subtitle/extraction/subtitle_sample_decoder.dart';

void main() {
  group('DecodedSubtitleSample', () {
    test('creates with required parameters', () {
      const sample = DecodedSubtitleSample(
        startTime: Duration(seconds: 1),
        endTime: Duration(seconds: 5),
        text: 'Hello, World!',
      );

      expect(sample.startTime, equals(const Duration(seconds: 1)));
      expect(sample.endTime, equals(const Duration(seconds: 5)));
      expect(sample.text, equals('Hello, World!'));
      expect(sample.styledSpans, isNull);
    });

    test('duration getter calculates correctly', () {
      const sample = DecodedSubtitleSample(
        startTime: Duration(seconds: 1),
        endTime: Duration(seconds: 5),
        text: 'Test',
      );

      expect(sample.duration, equals(const Duration(seconds: 4)));
    });

    test('hasStyledSpans returns false when styledSpans is null', () {
      const sample = DecodedSubtitleSample(startTime: Duration.zero, endTime: Duration(seconds: 1), text: 'Test');

      expect(sample.hasStyledSpans, isFalse);
    });

    test('hasStyledSpans returns false when styledSpans is empty', () {
      const sample = DecodedSubtitleSample(
        startTime: Duration.zero,
        endTime: Duration(seconds: 1),
        text: 'Test',
        styledSpans: [],
      );

      expect(sample.hasStyledSpans, isFalse);
    });

    test('toString returns readable representation', () {
      const sample = DecodedSubtitleSample(
        startTime: Duration(seconds: 1),
        endTime: Duration(seconds: 5),
        text: 'Hello',
      );

      final str = sample.toString();
      expect(str, contains('DecodedSubtitleSample'));
      expect(str, contains('start:'));
      expect(str, contains('end:'));
      expect(str, contains('Hello'));
    });
  });

  group('SubtitleSampleDecoder.forCodec', () {
    test('returns Tx3gDecoder for tx3g', () {
      final decoder = SubtitleSampleDecoder.forCodec('tx3g');
      expect(decoder, isA<Tx3gDecoder>());
    });

    test('returns Tx3gDecoder for TX3G (case insensitive)', () {
      final decoder = SubtitleSampleDecoder.forCodec('TX3G');
      expect(decoder, isA<Tx3gDecoder>());
    });

    test('returns StppDecoder for stpp', () {
      final decoder = SubtitleSampleDecoder.forCodec('stpp');
      expect(decoder, isA<StppDecoder>());
    });

    test('returns WvttDecoder for wvtt', () {
      final decoder = SubtitleSampleDecoder.forCodec('wvtt');
      expect(decoder, isA<WvttDecoder>());
    });

    test('returns MkvSrtDecoder for s_text/utf8', () {
      final decoder = SubtitleSampleDecoder.forCodec('s_text/utf8');
      expect(decoder, isA<MkvSrtDecoder>());
    });

    test('returns MkvSrtDecoder for srt', () {
      final decoder = SubtitleSampleDecoder.forCodec('srt');
      expect(decoder, isA<MkvSrtDecoder>());
    });

    test('returns MkvAssDecoder for s_text/ass', () {
      final decoder = SubtitleSampleDecoder.forCodec('s_text/ass');
      expect(decoder, isA<MkvAssDecoder>());
    });

    test('returns MkvAssDecoder for s_text/ssa', () {
      final decoder = SubtitleSampleDecoder.forCodec('s_text/ssa');
      expect(decoder, isA<MkvAssDecoder>());
    });

    test('returns MkvAssDecoder for assa', () {
      final decoder = SubtitleSampleDecoder.forCodec('assa');
      expect(decoder, isA<MkvAssDecoder>());
    });

    test('returns MkvAssDecoder for ssa', () {
      final decoder = SubtitleSampleDecoder.forCodec('ssa');
      expect(decoder, isA<MkvAssDecoder>());
    });

    test('returns MkvVttDecoder for s_text/webvtt', () {
      final decoder = SubtitleSampleDecoder.forCodec('s_text/webvtt');
      expect(decoder, isA<MkvVttDecoder>());
    });

    test('returns null for unknown codec', () {
      final decoder = SubtitleSampleDecoder.forCodec('unknown');
      expect(decoder, isNull);
    });

    test('returns null for empty codec', () {
      final decoder = SubtitleSampleDecoder.forCodec('');
      expect(decoder, isNull);
    });

    test('returns null for image-based codecs', () {
      expect(SubtitleSampleDecoder.forCodec('s_hdmv/pgs'), isNull);
      expect(SubtitleSampleDecoder.forCodec('s_vobsub'), isNull);
      expect(SubtitleSampleDecoder.forCodec('c608'), isNull);
      expect(SubtitleSampleDecoder.forCodec('c708'), isNull);
    });
  });

  group('SubtitleSampleDecoder.isSupported', () {
    test('returns true for supported codecs', () {
      expect(SubtitleSampleDecoder.isSupported('tx3g'), isTrue);
      expect(SubtitleSampleDecoder.isSupported('stpp'), isTrue);
      expect(SubtitleSampleDecoder.isSupported('wvtt'), isTrue);
      expect(SubtitleSampleDecoder.isSupported('s_text/utf8'), isTrue);
      expect(SubtitleSampleDecoder.isSupported('s_text/ass'), isTrue);
      expect(SubtitleSampleDecoder.isSupported('s_text/webvtt'), isTrue);
    });

    test('returns false for unsupported codecs', () {
      expect(SubtitleSampleDecoder.isSupported('unknown'), isFalse);
      expect(SubtitleSampleDecoder.isSupported('s_hdmv/pgs'), isFalse);
      expect(SubtitleSampleDecoder.isSupported(''), isFalse);
    });
  });

  group('SubtitleSampleDecoder.supportedCodecs', () {
    test('contains expected codecs', () {
      expect(SubtitleSampleDecoder.supportedCodecs, contains('tx3g'));
      expect(SubtitleSampleDecoder.supportedCodecs, contains('stpp'));
      expect(SubtitleSampleDecoder.supportedCodecs, contains('wvtt'));
      expect(SubtitleSampleDecoder.supportedCodecs, contains('s_text/utf8'));
      expect(SubtitleSampleDecoder.supportedCodecs, contains('s_text/ass'));
      expect(SubtitleSampleDecoder.supportedCodecs, contains('s_text/ssa'));
      expect(SubtitleSampleDecoder.supportedCodecs, contains('s_text/webvtt'));
    });
  });

  group('Tx3gDecoder', () {
    const decoder = Tx3gDecoder();

    test('decodes simple text sample', () {
      // TX3G format: 2-byte length (big-endian) + UTF-8 text
      final text = 'Hello, World!';
      final textBytes = utf8.encode(text);
      final data = Uint8List(2 + textBytes.length);
      data[0] = (textBytes.length >> 8) & 0xFF;
      data[1] = textBytes.length & 0xFF;
      data.setRange(2, 2 + textBytes.length, textBytes);

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.text, equals('Hello, World!'));
      expect(result.startTime, equals(Duration.zero));
      expect(result.endTime, equals(const Duration(seconds: 1)));
    });

    test('handles timescale conversion', () {
      final text = 'Test';
      final textBytes = utf8.encode(text);
      final data = Uint8List(2 + textBytes.length);
      data[0] = 0;
      data[1] = textBytes.length;
      data.setRange(2, 2 + textBytes.length, textBytes);

      // 45000 ticks at 90000 timescale = 500ms
      final result = decoder.decode(data, 45000, 45000, 90000);

      expect(result, isNotNull);
      expect(result!.startTime, equals(const Duration(milliseconds: 500)));
      expect(result.endTime, equals(const Duration(seconds: 1)));
    });

    test('returns null for data too short', () {
      final result = decoder.decode(Uint8List.fromList([0]), 0, 1000, 1000);
      expect(result, isNull);
    });

    test('returns null for empty text', () {
      final data = Uint8List.fromList([0, 0]); // Length = 0
      final result = decoder.decode(data, 0, 1000, 1000);
      expect(result, isNull);
    });

    test('returns null when text length exceeds data', () {
      final data = Uint8List.fromList([0, 10, 0x41, 0x42]); // Claims 10 bytes but only 2
      final result = decoder.decode(data, 0, 1000, 1000);
      expect(result, isNull);
    });

    test('handles unicode text', () {
      final text = 'Héllo 世界! 🎬';
      final textBytes = utf8.encode(text);
      final data = Uint8List(2 + textBytes.length);
      data[0] = (textBytes.length >> 8) & 0xFF;
      data[1] = textBytes.length & 0xFF;
      data.setRange(2, 2 + textBytes.length, textBytes);

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.text, equals('Héllo 世界! 🎬'));
    });
  });

  group('StppDecoder', () {
    const decoder = StppDecoder();

    test('decodes simple TTML', () {
      const ttml = '<tt><body><div><p>Hello from TTML</p></div></body></tt>';
      final data = Uint8List.fromList(utf8.encode(ttml));

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.text, contains('Hello from TTML'));
    });

    test('strips XML tags', () {
      const ttml = '<tt xmlns="http://www.w3.org/ns/ttml"><body><div><p>Plain text</p></div></body></tt>';
      final data = Uint8List.fromList(utf8.encode(ttml));

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.text, isNot(contains('<')));
      expect(result.text, isNot(contains('>')));
      expect(result.text, contains('Plain text'));
    });

    test('returns null for empty data', () {
      final result = decoder.decode(Uint8List(0), 0, 1000, 1000);
      expect(result, isNull);
    });

    test('handles timing conversion', () {
      const ttml = '<tt><body><p>Test</p></body></tt>';
      final data = Uint8List.fromList(utf8.encode(ttml));

      // 2000 ticks at 1000 timescale = 2 seconds
      final result = decoder.decode(data, 2000, 3000, 1000);

      expect(result, isNotNull);
      expect(result!.startTime, equals(const Duration(seconds: 2)));
      expect(result.endTime, equals(const Duration(seconds: 5)));
    });
  });

  group('WvttDecoder', () {
    const decoder = WvttDecoder();

    test('decodes vttc box with payl payload', () {
      // Build a minimal WVTT sample:
      // vttc box (size 8+8+4=20) containing payl box (size 8+4=12) with "Test"
      final text = 'Test';
      final textBytes = utf8.encode(text);
      final paylSize = 8 + textBytes.length;
      final vttcSize = 8 + paylSize;

      final data = Uint8List(vttcSize);
      var offset = 0;

      // vttc box header
      data[offset++] = (vttcSize >> 24) & 0xFF;
      data[offset++] = (vttcSize >> 16) & 0xFF;
      data[offset++] = (vttcSize >> 8) & 0xFF;
      data[offset++] = vttcSize & 0xFF;
      data[offset++] = 0x76; // v
      data[offset++] = 0x74; // t
      data[offset++] = 0x74; // t
      data[offset++] = 0x63; // c

      // payl box header
      data[offset++] = (paylSize >> 24) & 0xFF;
      data[offset++] = (paylSize >> 16) & 0xFF;
      data[offset++] = (paylSize >> 8) & 0xFF;
      data[offset++] = paylSize & 0xFF;
      data[offset++] = 0x70; // p
      data[offset++] = 0x61; // a
      data[offset++] = 0x79; // y
      data[offset++] = 0x6C; // l

      // Payload
      data.setRange(offset, offset + textBytes.length, textBytes);

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.text, equals('Test'));
    });

    test('returns null for data too short', () {
      final result = decoder.decode(Uint8List.fromList([0, 0, 0, 0]), 0, 1000, 1000);
      expect(result, isNull);
    });

    test('returns null for invalid box size', () {
      // Box with size 0
      final data = Uint8List.fromList([0, 0, 0, 0, 0x76, 0x74, 0x74, 0x63]);
      final result = decoder.decode(data, 0, 1000, 1000);
      expect(result, isNull);
    });
  });

  group('MkvSrtDecoder', () {
    const decoder = MkvSrtDecoder();

    test('decodes plain text', () {
      final text = 'Simple subtitle text';
      final data = Uint8List.fromList(utf8.encode(text));

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.text, equals('Simple subtitle text'));
    });

    test('trims whitespace', () {
      final text = '  \n  Text with whitespace  \n  ';
      final data = Uint8List.fromList(utf8.encode(text));

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.text, equals('Text with whitespace'));
    });

    test('returns null for empty text', () {
      final data = Uint8List.fromList(utf8.encode('   \n   '));
      final result = decoder.decode(data, 0, 1000, 1000);
      expect(result, isNull);
    });

    test('handles multi-line text', () {
      final text = 'Line 1\nLine 2\nLine 3';
      final data = Uint8List.fromList(utf8.encode(text));

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.text, contains('Line 1'));
      expect(result.text, contains('Line 2'));
      expect(result.text, contains('Line 3'));
    });
  });

  group('MkvAssDecoder', () {
    const decoder = MkvAssDecoder();

    test('decodes ASS dialogue format', () {
      // Format: ReadOrder,Layer,Style,Name,MarginL,MarginR,MarginV,Effect,Text
      final line = '0,0,Default,,0,0,0,,Hello from ASS';
      final data = Uint8List.fromList(utf8.encode(line));

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.text, equals('Hello from ASS'));
    });

    test('strips ASS override tags', () {
      final line = r'0,0,Default,,0,0,0,,{\i1}Italic{\i0} and {\b1}bold{\b0}';
      final data = Uint8List.fromList(utf8.encode(line));

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.text, equals('Italic and bold'));
    });

    test('handles newline escapes', () {
      final line = r'0,0,Default,,0,0,0,,Line 1\NLine 2\nLine 3';
      final data = Uint8List.fromList(utf8.encode(line));

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.text, contains('\n'));
    });

    test('handles text with commas', () {
      final line = '0,0,Default,,0,0,0,,Hello, world, test';
      final data = Uint8List.fromList(utf8.encode(line));

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.text, equals('Hello, world, test'));
    });

    test('treats non-dialogue lines as plain text', () {
      final line = 'Plain text without dialogue format';
      final data = Uint8List.fromList(utf8.encode(line));

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.text, equals('Plain text without dialogue format'));
    });

    test('returns null for empty text after stripping', () {
      final line = r'0,0,Default,,0,0,0,,{\pos(100,100)}';
      final data = Uint8List.fromList(utf8.encode(line));

      final result = decoder.decode(data, 0, 1000, 1000);
      expect(result, isNull);
    });
  });

  group('MkvVttDecoder', () {
    const decoder = MkvVttDecoder();

    test('decodes plain text', () {
      final text = 'Simple VTT cue';
      final data = Uint8List.fromList(utf8.encode(text));

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.text, equals('Simple VTT cue'));
    });

    test('strips VTT styling tags', () {
      final text = '<c.yellow>Colored</c> and <b>bold</b> text';
      final data = Uint8List.fromList(utf8.encode(text));

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.text, equals('Colored and bold text'));
    });

    test('returns null for empty text', () {
      final data = Uint8List.fromList(utf8.encode('   '));
      final result = decoder.decode(data, 0, 1000, 1000);
      expect(result, isNull);
    });

    test('handles voice spans', () {
      final text = '<v Speaker>Hello there';
      final data = Uint8List.fromList(utf8.encode(text));

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.text, contains('Hello there'));
    });
  });

  group('Tx3gDecoder style parsing', () {
    const decoder = Tx3gDecoder();

    Uint8List _buildTx3gWithStyle({
      required String text,
      int startChar = 0,
      int endChar = 0,
      int faceStyle = 0,
      int fontSize = 0,
      int r = 255,
      int g = 255,
      int b = 255,
      int a = 255,
    }) {
      final textBytes = utf8.encode(text);
      final builder = BytesBuilder();

      // Text length + text
      builder.addByte((textBytes.length >> 8) & 0xFF);
      builder.addByte(textBytes.length & 0xFF);
      builder.add(textBytes);

      // styl atom: size (4) + type (4) + count (2) + style record (12)
      const atomSize = 4 + 4 + 2 + 12;
      builder.addByte(0);
      builder.addByte(0);
      builder.addByte(0);
      builder.addByte(atomSize);
      builder.add(utf8.encode('styl'));

      // Count: 1 style run
      builder.addByte(0);
      builder.addByte(1);

      // Style record
      builder.addByte((startChar >> 8) & 0xFF);
      builder.addByte(startChar & 0xFF);
      builder.addByte((endChar >> 8) & 0xFF);
      builder.addByte(endChar & 0xFF);
      builder.addByte(0); // fontId high
      builder.addByte(1); // fontId low
      builder.addByte(faceStyle);
      builder.addByte(fontSize);
      builder.addByte(r);
      builder.addByte(g);
      builder.addByte(b);
      builder.addByte(a);

      return Uint8List.fromList(builder.toBytes());
    }

    test('parses bold style', () {
      final data = _buildTx3gWithStyle(text: 'Bold text', endChar: 9, faceStyle: 0x01);

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.styledSpans, isNotNull);
      expect(result.styledSpans!.any((s) => s.style?.isBold == true), isTrue);
    });

    test('parses italic style', () {
      final data = _buildTx3gWithStyle(text: 'Italic', endChar: 6, faceStyle: 0x02);

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.styledSpans, isNotNull);
      expect(result.styledSpans!.any((s) => s.style?.isItalic == true), isTrue);
    });

    test('parses underline style', () {
      final data = _buildTx3gWithStyle(text: 'Underlined', endChar: 10, faceStyle: 0x04);

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.styledSpans, isNotNull);
      expect(result.styledSpans!.any((s) => s.style?.isUnderline == true), isTrue);
    });

    test('parses combined styles', () {
      final data = _buildTx3gWithStyle(text: 'BoldItalic', endChar: 10, faceStyle: 0x03);

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.styledSpans, isNotNull);
      expect(result.styledSpans!.any((s) => s.style?.isBold == true && s.style?.isItalic == true), isTrue);
    });

    test('parses font size', () {
      final data = _buildTx3gWithStyle(text: 'Large', endChar: 5, fontSize: 24);

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.styledSpans, isNotNull);
      expect(result.styledSpans!.any((s) => s.style?.fontSize == 24), isTrue);
    });

    test('parses color', () {
      final data = _buildTx3gWithStyle(text: 'Red', endChar: 3, r: 255, g: 0, b: 0, a: 255);

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.styledSpans, isNotNull);
      expect(result.styledSpans!.any((s) => s.style?.color != null), isTrue);
    });

    test('handles style starting mid-text', () {
      final data = _buildTx3gWithStyle(text: 'Plain Bold', startChar: 6, endChar: 10, faceStyle: 0x01);

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.styledSpans, isNotNull);
      // Should have unstyled "Plain " and styled "Bold"
      expect(result.styledSpans!.length, greaterThanOrEqualTo(2));
    });

    test('handles hclr highlight color atom', () {
      final text = 'Highlighted';
      final textBytes = utf8.encode(text);
      final builder = BytesBuilder();

      // Text
      builder.addByte((textBytes.length >> 8) & 0xFF);
      builder.addByte(textBytes.length & 0xFF);
      builder.add(textBytes);

      // styl atom
      const stylAtomSize = 4 + 4 + 2 + 12;
      builder.addByte(0);
      builder.addByte(0);
      builder.addByte(0);
      builder.addByte(stylAtomSize);
      builder.add(utf8.encode('styl'));
      builder.addByte(0);
      builder.addByte(1);
      // Style record
      builder.addByte(0);
      builder.addByte(0);
      builder.addByte(0);
      builder.addByte(11);
      builder.addByte(0);
      builder.addByte(1);
      builder.addByte(0);
      builder.addByte(16);
      builder.addByte(255);
      builder.addByte(255);
      builder.addByte(255);
      builder.addByte(255);

      // hclr atom (highlight color)
      builder.addByte(0);
      builder.addByte(0);
      builder.addByte(0);
      builder.addByte(12); // size
      builder.add(utf8.encode('hclr'));
      builder.addByte(255); // R
      builder.addByte(255); // G
      builder.addByte(0); // B
      builder.addByte(128); // A

      final data = Uint8List.fromList(builder.toBytes());
      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.styledSpans, isNotNull);
    });
  });

  group('StppDecoder style parsing', () {
    const decoder = StppDecoder();

    test('parses #RGB color format', () {
      final ttml = '<span tts:color="#F00">Red</span>';
      final data = Uint8List.fromList(utf8.encode(ttml));

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.styledSpans, isNotNull);
    });

    test('parses #RRGGBBAA color format', () {
      final ttml = '<span tts:color="#FF0000FF">Red</span>';
      final data = Uint8List.fromList(utf8.encode(ttml));

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.styledSpans, isNotNull);
    });

    test('parses rgba() color format', () {
      final ttml = '<span tts:color="rgba(255, 0, 0, 0.5)">Semi-transparent red</span>';
      final data = Uint8List.fromList(utf8.encode(ttml));

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
    });

    test('parses all named colors', () {
      for (final color in ['white', 'black', 'red', 'green', 'blue', 'yellow', 'cyan', 'magenta']) {
        final ttml = '<span tts:color="$color">$color text</span>';
        final data = Uint8List.fromList(utf8.encode(ttml));

        final result = decoder.decode(data, 0, 1000, 1000);
        expect(result, isNotNull, reason: 'Failed for color: $color');
      }
    });

    test('handles combined TTML styles', () {
      final ttml = '<span tts:fontWeight="bold" tts:fontStyle="italic" tts:textDecoration="underline">Styled</span>';
      final data = Uint8List.fromList(utf8.encode(ttml));

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.styledSpans, isNotNull);
      final styledSpan = result.styledSpans!.firstWhere((s) => s.style != null);
      expect(styledSpan.style?.isBold, isTrue);
      expect(styledSpan.style?.isItalic, isTrue);
      expect(styledSpan.style?.isUnderline, isTrue);
    });

    test('returns null for spans with no text content', () {
      final ttml = '<span tts:fontWeight="bold"></span>';
      final data = Uint8List.fromList(utf8.encode(ttml));

      final result = decoder.decode(data, 0, 1000, 1000);
      expect(result, isNull);
    });

    test('handles nested span tags', () {
      final ttml = '<span tts:fontWeight="bold"><span>Nested</span></span>';
      final data = Uint8List.fromList(utf8.encode(ttml));

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.text, contains('Nested'));
    });
  });

  group('WvttDecoder style parsing', () {
    const decoder = WvttDecoder();

    Uint8List _buildWvtt(String text) {
      final textBytes = utf8.encode(text);
      final paylSize = 8 + textBytes.length;
      final vttcSize = 8 + paylSize;

      final data = Uint8List(vttcSize);
      var offset = 0;

      // vttc box header
      data[offset++] = (vttcSize >> 24) & 0xFF;
      data[offset++] = (vttcSize >> 16) & 0xFF;
      data[offset++] = (vttcSize >> 8) & 0xFF;
      data[offset++] = vttcSize & 0xFF;
      data.setRange(offset, offset + 4, utf8.encode('vttc'));
      offset += 4;

      // payl box header
      data[offset++] = (paylSize >> 24) & 0xFF;
      data[offset++] = (paylSize >> 16) & 0xFF;
      data[offset++] = (paylSize >> 8) & 0xFF;
      data[offset++] = paylSize & 0xFF;
      data.setRange(offset, offset + 4, utf8.encode('payl'));
      offset += 4;

      data.setRange(offset, offset + textBytes.length, textBytes);

      return data;
    }

    test('parses bold tag', () {
      final data = _buildWvtt('<b>Bold</b>');
      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.styledSpans, isNotNull);
      expect(result.styledSpans!.any((s) => s.style?.isBold == true), isTrue);
    });

    test('parses italic tag', () {
      final data = _buildWvtt('<i>Italic</i>');
      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.styledSpans, isNotNull);
      expect(result.styledSpans!.any((s) => s.style?.isItalic == true), isTrue);
    });

    test('parses underline tag', () {
      final data = _buildWvtt('<u>Underlined</u>');
      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.styledSpans, isNotNull);
      expect(result.styledSpans!.any((s) => s.style?.isUnderline == true), isTrue);
    });

    test('handles nested tags', () {
      final data = _buildWvtt('<b><i>Bold Italic</i></b>');
      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.styledSpans, isNotNull);
    });

    test('handles unclosed tag gracefully', () {
      final data = _buildWvtt('<b>Unclosed bold');
      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.text, equals('Unclosed bold'));
    });

    test('handles text before and after tags', () {
      final data = _buildWvtt('Before <b>bold</b> after');
      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.text, equals('Before bold after'));
      expect(result.styledSpans, isNotNull);
      expect(result.styledSpans!.length, greaterThanOrEqualTo(3));
    });
  });

  group('MkvAssDecoder style parsing', () {
    const decoder = MkvAssDecoder();

    test('parses 6-digit BGR color', () {
      final line = r'0,0,Default,,0,0,0,,{\c&HFF0000&}Blue text';
      final data = Uint8List.fromList(utf8.encode(line));

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.styledSpans, isNotNull);
      // ASS uses BGR, so FF0000 is blue
      expect(result.styledSpans!.any((s) => s.style?.color != null), isTrue);
    });

    test('parses 8-digit ABGR color', () {
      final line = r'0,0,Default,,0,0,0,,{\c&H80FF0000&}Semi-transparent blue';
      final data = Uint8List.fromList(utf8.encode(line));

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
    });

    test('parses 1c (primary color) tag', () {
      final line = r'0,0,Default,,0,0,0,,{\1c&HFF0000&}Primary color';
      final data = Uint8List.fromList(utf8.encode(line));

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.styledSpans, isNotNull);
    });

    test('handles multiple style changes', () {
      final line = r'0,0,Default,,0,0,0,,{\b1}Bold{\b0} {\i1}Italic{\i0}';
      final data = Uint8List.fromList(utf8.encode(line));

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.styledSpans, isNotNull);
      expect(result.styledSpans!.length, greaterThanOrEqualTo(2));
    });

    test('handles lowercase newline escape', () {
      final line = r'0,0,Default,,0,0,0,,Line 1\nLine 2';
      final data = Uint8List.fromList(utf8.encode(line));

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.text, contains('\n'));
    });

    test('ignores unknown tags', () {
      final line = r'0,0,Default,,0,0,0,,{\unknown}Text{\end}';
      final data = Uint8List.fromList(utf8.encode(line));

      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.text, equals('Text'));
    });
  });

  group('MkvVttDecoder style parsing', () {
    const decoder = MkvVttDecoder();

    test('handles class tags', () {
      final data = Uint8List.fromList(utf8.encode('<c.yellow>Yellow text</c>'));
      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.text, equals('Yellow text'));
    });

    test('handles timestamp tags', () {
      final data = Uint8List.fromList(utf8.encode('<00:00:01.000>Timed'));
      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.text, equals('Timed'));
    });

    test('preserves text with no styling', () {
      final data = Uint8List.fromList(utf8.encode('Plain text without tags'));
      final result = decoder.decode(data, 0, 1000, 1000);

      expect(result, isNotNull);
      expect(result!.text, equals('Plain text without tags'));
      expect(result.styledSpans, isNull);
    });
  });

  group('Timing edge cases', () {
    const decoder = Tx3gDecoder();

    test('handles zero timescale gracefully', () {
      final text = 'Test';
      final textBytes = utf8.encode(text);
      final data = Uint8List(2 + textBytes.length);
      data[0] = 0;
      data[1] = textBytes.length;
      data.setRange(2, 2 + textBytes.length, textBytes);

      final result = decoder.decode(data, 1000, 1000, 0);

      expect(result, isNotNull);
      expect(result!.startTime, equals(Duration.zero));
      expect(result.endTime, equals(Duration.zero));
    });

    test('handles negative timescale gracefully', () {
      final text = 'Test';
      final textBytes = utf8.encode(text);
      final data = Uint8List(2 + textBytes.length);
      data[0] = 0;
      data[1] = textBytes.length;
      data.setRange(2, 2 + textBytes.length, textBytes);

      final result = decoder.decode(data, 1000, 1000, -1);

      expect(result, isNotNull);
      expect(result!.startTime, equals(Duration.zero));
    });

    test('handles large timestamps', () {
      final text = 'Test';
      final textBytes = utf8.encode(text);
      final data = Uint8List(2 + textBytes.length);
      data[0] = 0;
      data[1] = textBytes.length;
      data.setRange(2, 2 + textBytes.length, textBytes);

      // 3 hours at 90000 timescale
      const threeHoursInTicks = 3 * 60 * 60 * 90000;
      final result = decoder.decode(data, threeHoursInTicks, 1000, 90000);

      expect(result, isNotNull);
      expect(result!.startTime, equals(const Duration(hours: 3)));
    });
  });
}
