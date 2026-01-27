import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Color;

import '../../types/styled_text_span.dart';

/// A decoded subtitle sample with timing and styled content.
///
/// Represents the result of decoding raw subtitle bytes from a container
/// sample into displayable text with timing information.
class DecodedSubtitleSample {
  /// Creates a decoded subtitle sample.
  const DecodedSubtitleSample({required this.startTime, required this.endTime, required this.text, this.styledSpans});

  /// When this subtitle should appear.
  final Duration startTime;

  /// When this subtitle should disappear.
  final Duration endTime;

  /// Plain text content (fallback for rendering).
  final String text;

  /// Rich text spans with styling information.
  ///
  /// For subtitle formats that support styling (TX3G, STPP/TTML, ASS),
  /// this contains the text broken into styled segments.
  final List<StyledTextSpan>? styledSpans;

  /// Duration this subtitle is displayed.
  Duration get duration => endTime - startTime;

  /// Whether this sample has rich text styling.
  bool get hasStyledSpans => styledSpans != null && styledSpans!.isNotEmpty;

  @override
  String toString() =>
      'DecodedSubtitleSample(start: $startTime, end: $endTime, '
      'text: "$text", hasStyledSpans: $hasStyledSpans)';
}

/// Interface for decoding raw subtitle sample bytes into displayable content.
///
/// Different container formats store subtitle data in different binary formats:
/// - **TX3G** (MP4): 2-byte length + UTF-8 text + optional style atoms
/// - **STPP** (MP4): Raw TTML XML
/// - **WVTT** (MP4): WebVTT cue boxes
/// - **S_TEXT/UTF8** (MKV): Plain UTF-8 text
/// - **S_TEXT/ASS** (MKV): ASS dialogue line without timing
///
/// Implementations decode these format-specific byte sequences into
/// [DecodedSubtitleSample] objects with normalized timing and optional styling.
abstract class SubtitleSampleDecoder {
  /// Decodes a single sample's bytes to subtitle content.
  ///
  /// Parameters:
  /// - [data]: Raw sample bytes from the container
  /// - [presentationTime]: Sample PTS in [timescale] units
  /// - [duration]: Sample duration in [timescale] units
  /// - [timescale]: Track timescale (units per second)
  ///
  /// Returns null if the sample cannot be decoded or contains no text.
  DecodedSubtitleSample? decode(Uint8List data, int presentationTime, int duration, int timescale);

  /// Gets the appropriate decoder for a codec fourcc/ID.
  ///
  /// Returns null if no decoder is available for the codec.
  static SubtitleSampleDecoder? forCodec(String codecFourcc) {
    final lower = codecFourcc.toLowerCase();

    // MP4 subtitle codecs
    switch (lower) {
      case 'tx3g':
        return const Tx3gDecoder();
      case 'stpp':
        return const StppDecoder();
      case 'wvtt':
        return const WvttDecoder();
    }

    // MKV subtitle codecs
    if (lower == 's_text/utf8' || lower == 'srt') {
      return const MkvSrtDecoder();
    }
    if (lower == 's_text/ass' || lower == 's_text/ssa' || lower == 'assa' || lower == 'ssa') {
      return const MkvAssDecoder();
    }
    if (lower == 's_text/webvtt') {
      return const MkvVttDecoder();
    }

    return null;
  }

  /// Checks if a decoder is available for the given codec.
  static bool isSupported(String codecFourcc) => forCodec(codecFourcc) != null;

  /// List of supported codec fourccs/IDs.
  static const supportedCodecs = [
    'tx3g', // MP4 3GPP Timed Text
    'stpp', // MP4 TTML
    'wvtt', // MP4 WebVTT
    's_text/utf8', // MKV SRT-style
    's_text/ass', // MKV ASS
    's_text/ssa', // MKV SSA
    's_text/webvtt', // MKV WebVTT
  ];
}

/// Converts timescale units to Duration.
Duration _timescaleToDuration(int value, int timescale) {
  if (timescale <= 0) return Duration.zero;
  final microseconds = (value * Duration.microsecondsPerSecond) ~/ timescale;
  return Duration(microseconds: microseconds);
}

/// Decoder for TX3G (3GPP Timed Text) subtitle samples from MP4 containers.
///
/// TX3G format consists of:
/// - 2-byte text length (big-endian)
/// - UTF-8 text content
/// - Optional style atoms (styl, hlit, hclr) for rich text formatting
///
/// The `styl` atom contains style runs with font, size, and color info.
class Tx3gDecoder implements SubtitleSampleDecoder {
  /// Creates a TX3G decoder.
  const Tx3gDecoder();

  @override
  DecodedSubtitleSample? decode(Uint8List data, int presentationTime, int duration, int timescale) {
    if (data.length < 2) return null;

    // TX3G format: 2-byte text length (big-endian) + UTF-8 text + optional style atoms
    final textLength = (data[0] << 8) | data[1];
    if (data.length < 2 + textLength) return null;

    final textBytes = data.sublist(2, 2 + textLength);
    final text = utf8.decode(textBytes, allowMalformed: true);

    if (text.isEmpty) return null;

    final startTime = _timescaleToDuration(presentationTime, timescale);
    final endTime = _timescaleToDuration(presentationTime + duration, timescale);

    // Parse style atoms if present
    List<StyledTextSpan>? styledSpans;
    if (data.length > 2 + textLength + 8) {
      styledSpans = _parseStyleAtoms(data, 2 + textLength, text);
    }

    return DecodedSubtitleSample(startTime: startTime, endTime: endTime, text: text, styledSpans: styledSpans);
  }

  /// Parses style atoms following the text content.
  List<StyledTextSpan>? _parseStyleAtoms(Uint8List data, int startOffset, String text) {
    final styleRuns = <_Tx3gStyleRun>[];
    Color? highlightColor;
    var offset = startOffset;

    while (offset + 8 <= data.length) {
      final boxSize = (data[offset] << 24) | (data[offset + 1] << 16) | (data[offset + 2] << 8) | data[offset + 3];
      if (boxSize < 8 || offset + boxSize > data.length) break;

      final boxType = String.fromCharCodes(data.sublist(offset + 4, offset + 8));

      switch (boxType) {
        case 'styl':
          // Style atom: 2-byte count + style records
          if (boxSize > 10) {
            final count = (data[offset + 8] << 8) | data[offset + 9];
            var pos = offset + 10;
            for (var i = 0; i < count && pos + 12 <= offset + boxSize; i++) {
              final startChar = (data[pos] << 8) | data[pos + 1];
              final endChar = (data[pos + 2] << 8) | data[pos + 3];
              // fontId at pos+4,5 (skipped)
              final faceStyle = data[pos + 6];
              final fontSize = data[pos + 7];
              final r = data[pos + 8];
              final g = data[pos + 9];
              final b = data[pos + 10];
              final a = data[pos + 11];

              styleRuns.add(
                _Tx3gStyleRun(
                  startChar: startChar,
                  endChar: endChar,
                  isBold: (faceStyle & 0x01) != 0,
                  isItalic: (faceStyle & 0x02) != 0,
                  isUnderline: (faceStyle & 0x04) != 0,
                  fontSize: fontSize > 0 ? fontSize.toDouble() : null,
                  color: Color.fromARGB(a, r, g, b),
                ),
              );
              pos += 12;
            }
          }
        case 'hclr':
          // Highlight color atom: 4 bytes RGBA
          if (boxSize >= 12) {
            highlightColor = Color.fromARGB(data[offset + 11], data[offset + 8], data[offset + 9], data[offset + 10]);
          }
        // 'hlit' (highlight region) and 'krok' (karaoke) could be added later
      }

      offset += boxSize;
    }

    if (styleRuns.isEmpty) return null;

    // Convert style runs to styled spans
    return _convertToSpans(text, styleRuns, highlightColor);
  }

  List<StyledTextSpan>? _convertToSpans(String text, List<_Tx3gStyleRun> runs, Color? highlightColor) {
    if (runs.isEmpty) return null;

    final spans = <StyledTextSpan>[];
    var currentPos = 0;

    for (final run in runs) {
      // Add unstyled text before this run
      if (run.startChar > currentPos && currentPos < text.length) {
        final unstyled = text.substring(currentPos, run.startChar.clamp(0, text.length));
        if (unstyled.isNotEmpty) {
          spans.add(StyledTextSpan.plain(unstyled));
        }
      }

      // Add styled text for this run
      if (run.startChar < text.length) {
        final styledText = text.substring(run.startChar.clamp(0, text.length), run.endChar.clamp(0, text.length));
        if (styledText.isNotEmpty) {
          final style = SubtitleTextStyle(
            isBold: run.isBold,
            isItalic: run.isItalic,
            isUnderline: run.isUnderline,
            fontSize: run.fontSize,
            color: run.color,
            backgroundColor: highlightColor,
          );
          spans.add(StyledTextSpan(text: styledText, style: style.hasFormatting ? style : null));
        }
      }

      currentPos = run.endChar;
    }

    // Add remaining unstyled text
    if (currentPos < text.length) {
      spans.add(StyledTextSpan.plain(text.substring(currentPos)));
    }

    return spans.isNotEmpty ? spans : null;
  }
}

/// Style run from TX3G styl atom.
class _Tx3gStyleRun {
  const _Tx3gStyleRun({
    required this.startChar,
    required this.endChar,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.fontSize,
    this.color,
  });

  final int startChar;
  final int endChar;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final double? fontSize;
  final Color? color;
}

/// Decoder for STPP (TTML in MP4) subtitle samples.
///
/// STPP samples contain raw TTML XML content that can be parsed
/// for text and styling information using TTML styling attributes.
class StppDecoder implements SubtitleSampleDecoder {
  /// Creates an STPP decoder.
  const StppDecoder();

  static final _spanPattern = RegExp(r'<span[^>]*>(.*?)</span>', caseSensitive: false, dotAll: true);
  static final _fontWeightBold = RegExp('tts:fontWeight\\s*=\\s*["\']bold["\']', caseSensitive: false);
  static final _fontStyleItalic = RegExp('tts:fontStyle\\s*=\\s*["\']italic["\']', caseSensitive: false);
  static final _textDecorationUnderline = RegExp(
    'tts:textDecoration\\s*=\\s*["\'][^"\']*underline[^"\']*["\']',
    caseSensitive: false,
  );
  static final _colorPattern = RegExp('tts:color\\s*=\\s*["\']([^"\']+)["\']', caseSensitive: false);
  static final _brPattern = RegExp(r'<br\s*/?\s*>', caseSensitive: false);

  @override
  DecodedSubtitleSample? decode(Uint8List data, int presentationTime, int duration, int timescale) {
    final content = utf8.decode(data, allowMalformed: true);
    if (content.isEmpty) return null;

    final startTime = _timescaleToDuration(presentationTime, timescale);
    final endTime = _timescaleToDuration(presentationTime + duration, timescale);

    // Parse styled text from TTML
    final styledSpans = _parseStyledText(content);
    final plainText = _extractText(content);
    if (plainText.isEmpty) return null;

    return DecodedSubtitleSample(startTime: startTime, endTime: endTime, text: plainText, styledSpans: styledSpans);
  }

  String _extractText(String content) {
    var result = content.replaceAll(_brPattern, '\n');
    result = result.replaceAll(RegExp('<[^>]+>'), ' ');
    result = result.replaceAll(RegExp(r'\s+'), ' ');
    return result.trim();
  }

  List<StyledTextSpan>? _parseStyledText(String content) {
    final spans = <StyledTextSpan>[];

    // Check for span elements with styling
    final spanMatches = _spanPattern.allMatches(content);
    if (spanMatches.isEmpty) {
      // No styled spans, return null for plain text
      return null;
    }

    for (final match in spanMatches) {
      final fullSpan = match.group(0)!;
      final spanContent = match.group(1) ?? '';
      final text = spanContent.replaceAll(RegExp('<[^>]+>'), '').trim();
      if (text.isEmpty) continue;

      final isBold = _fontWeightBold.hasMatch(fullSpan);
      final isItalic = _fontStyleItalic.hasMatch(fullSpan);
      final isUnderline = _textDecorationUnderline.hasMatch(fullSpan);

      Color? color;
      final colorMatch = _colorPattern.firstMatch(fullSpan);
      if (colorMatch != null) {
        color = _parseTtmlColor(colorMatch.group(1)!);
      }

      if (isBold || isItalic || isUnderline || color != null) {
        spans.add(
          StyledTextSpan(
            text: text,
            style: SubtitleTextStyle(isBold: isBold, isItalic: isItalic, isUnderline: isUnderline, color: color),
          ),
        );
      } else {
        spans.add(StyledTextSpan.plain(text));
      }
    }

    return spans.isNotEmpty ? spans : null;
  }

  Color? _parseTtmlColor(String colorStr) {
    final trimmed = colorStr.trim().toLowerCase();

    // Named colors
    const namedColors = {
      'white': Color(0xFFFFFFFF),
      'black': Color(0xFF000000),
      'red': Color(0xFFFF0000),
      'green': Color(0xFF00FF00),
      'blue': Color(0xFF0000FF),
      'yellow': Color(0xFFFFFF00),
      'cyan': Color(0xFF00FFFF),
      'magenta': Color(0xFFFF00FF),
    };
    if (namedColors.containsKey(trimmed)) {
      return namedColors[trimmed];
    }

    // Hex colors: #RGB, #RRGGBB, #RRGGBBAA
    if (trimmed.startsWith('#')) {
      final hex = trimmed.substring(1);
      if (hex.length == 3) {
        final r = int.tryParse(hex[0] + hex[0], radix: 16) ?? 0;
        final g = int.tryParse(hex[1] + hex[1], radix: 16) ?? 0;
        final b = int.tryParse(hex[2] + hex[2], radix: 16) ?? 0;
        return Color.fromARGB(255, r, g, b);
      } else if (hex.length == 6) {
        final value = int.tryParse(hex, radix: 16);
        if (value != null) return Color(0xFF000000 | value);
      } else if (hex.length == 8) {
        final value = int.tryParse(hex, radix: 16);
        if (value != null) return Color(value);
      }
    }

    // rgb(r, g, b) or rgba(r, g, b, a)
    final rgbMatch = RegExp(r'rgba?\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?:\s*,\s*([\d.]+))?\s*\)').firstMatch(trimmed);
    if (rgbMatch != null) {
      final r = int.tryParse(rgbMatch.group(1)!) ?? 0;
      final g = int.tryParse(rgbMatch.group(2)!) ?? 0;
      final b = int.tryParse(rgbMatch.group(3)!) ?? 0;
      final a = rgbMatch.group(4) != null ? ((double.tryParse(rgbMatch.group(4)!) ?? 1.0) * 255).round() : 255;
      return Color.fromARGB(a, r, g, b);
    }

    return null;
  }
}

/// Decoder for WVTT (WebVTT in MP4) subtitle samples.
///
/// WVTT samples contain WebVTT cue boxes (vttc) with payload (payl) boxes
/// containing the cue text content with optional WebVTT styling tags.
class WvttDecoder implements SubtitleSampleDecoder {
  /// Creates a WVTT decoder.
  const WvttDecoder();

  @override
  DecodedSubtitleSample? decode(Uint8List data, int presentationTime, int duration, int timescale) {
    if (data.length < 8) return null;

    final startTime = _timescaleToDuration(presentationTime, timescale);
    final endTime = _timescaleToDuration(presentationTime + duration, timescale);

    // Parse boxes to find vttc (cue text)
    String? cueText;
    var offset = 0;

    while (offset + 8 <= data.length) {
      final boxSize = (data[offset] << 24) | (data[offset + 1] << 16) | (data[offset + 2] << 8) | data[offset + 3];
      if (boxSize < 8 || offset + boxSize > data.length) break;

      final boxType = String.fromCharCodes(data.sublist(offset + 4, offset + 8));

      if (boxType == 'vttc') {
        cueText = _parseVttcBox(data, offset + 8, boxSize - 8);
      }

      offset += boxSize;
    }

    if (cueText == null || cueText.isEmpty) return null;

    // Parse WebVTT styling
    final styledSpans = _parseVttStyledText(cueText);
    final plainText = _stripVttTags(cueText);

    return DecodedSubtitleSample(
      startTime: startTime,
      endTime: endTime,
      text: plainText.isNotEmpty ? plainText : cueText,
      styledSpans: styledSpans,
    );
  }

  String? _parseVttcBox(Uint8List data, int offset, int size) {
    var pos = offset;
    while (pos + 8 <= offset + size) {
      final boxSize = (data[pos] << 24) | (data[pos + 1] << 16) | (data[pos + 2] << 8) | data[pos + 3];
      if (boxSize < 8) break;

      final boxType = String.fromCharCodes(data.sublist(pos + 4, pos + 8));

      if (boxType == 'payl') {
        final payloadSize = boxSize - 8;
        if (payloadSize > 0 && pos + 8 + payloadSize <= data.length) {
          return utf8.decode(data.sublist(pos + 8, pos + 8 + payloadSize), allowMalformed: true);
        }
      }

      pos += boxSize;
    }
    return null;
  }

  String _stripVttTags(String text) => text.replaceAll(RegExp('<[^>]+>'), '').replaceAll(RegExp(' +'), ' ').trim();

  List<StyledTextSpan>? _parseVttStyledText(String text) {
    final spans = <StyledTextSpan>[];
    final styleStack = <String>[];
    var currentText = StringBuffer();
    var i = 0;

    while (i < text.length) {
      if (text[i] == '<') {
        final closeIndex = text.indexOf('>', i);
        if (closeIndex == -1) {
          currentText.write(text[i]);
          i++;
          continue;
        }

        final tag = text.substring(i + 1, closeIndex).toLowerCase();

        // Flush current text before style change
        if (currentText.isNotEmpty) {
          spans.add(_createVttSpan(currentText.toString(), styleStack));
          currentText = StringBuffer();
        }

        // Handle opening/closing tags
        if (tag == 'b' || tag == 'i' || tag == 'u') {
          styleStack.add(tag);
        } else if (tag == '/b' || tag == '/i' || tag == '/u') {
          final openTag = tag.substring(1);
          for (var j = styleStack.length - 1; j >= 0; j--) {
            if (styleStack[j] == openTag) {
              styleStack.removeAt(j);
              break;
            }
          }
        }

        i = closeIndex + 1;
      } else {
        currentText.write(text[i]);
        i++;
      }
    }

    if (currentText.isNotEmpty) {
      spans.add(_createVttSpan(currentText.toString(), styleStack));
    }

    // Only return spans if there's actual styling
    final hasStyle = spans.any((s) => s.hasStyle);
    return hasStyle ? spans : null;
  }

  StyledTextSpan _createVttSpan(String text, List<String> activeTags) {
    if (activeTags.isEmpty) {
      return StyledTextSpan.plain(text);
    }

    final style = SubtitleTextStyle(
      isBold: activeTags.contains('b'),
      isItalic: activeTags.contains('i'),
      isUnderline: activeTags.contains('u'),
    );

    return StyledTextSpan(text: text, style: style);
  }
}

/// Decoder for MKV S_TEXT/UTF8 (SRT-style) subtitle blocks.
///
/// MKV S_TEXT/UTF8 blocks contain plain UTF-8 text without
/// timing information (timing is provided by the block header).
class MkvSrtDecoder implements SubtitleSampleDecoder {
  /// Creates an MKV SRT decoder.
  const MkvSrtDecoder();

  @override
  DecodedSubtitleSample? decode(Uint8List data, int presentationTime, int duration, int timescale) {
    final text = utf8.decode(data, allowMalformed: true).trim();
    if (text.isEmpty) return null;

    final startTime = _timescaleToDuration(presentationTime, timescale);
    final endTime = _timescaleToDuration(presentationTime + duration, timescale);

    return DecodedSubtitleSample(startTime: startTime, endTime: endTime, text: text);
  }
}

/// Decoder for MKV S_TEXT/ASS subtitle blocks.
///
/// MKV ASS blocks contain dialogue lines in the format:
/// `ReadOrder,Layer,Style,Name,MarginL,MarginR,MarginV,Effect,Text`
/// without timing information (timing is provided by the block header).
///
/// Parses ASS override tags for styling information.
class MkvAssDecoder implements SubtitleSampleDecoder {
  /// Creates an MKV ASS decoder.
  const MkvAssDecoder();

  static final _assTagPattern = RegExp(r'\{([^}]*)\}');

  @override
  DecodedSubtitleSample? decode(Uint8List data, int presentationTime, int duration, int timescale) {
    final line = utf8.decode(data, allowMalformed: true);
    if (line.isEmpty) return null;

    // Find the text portion (after 8th comma)
    final parts = line.split(',');
    String rawText;
    if (parts.length >= 9) {
      rawText = parts.sublist(8).join(',');
    } else {
      // Not a valid ASS dialogue format, treat as plain text
      rawText = line.trim();
    }

    // Parse styled spans from ASS override tags
    final styledSpans = _parseAssStyledText(rawText);
    final plainText = _stripAssTags(rawText);
    if (plainText.isEmpty) return null;

    final startTime = _timescaleToDuration(presentationTime, timescale);
    final endTime = _timescaleToDuration(presentationTime + duration, timescale);

    return DecodedSubtitleSample(startTime: startTime, endTime: endTime, text: plainText, styledSpans: styledSpans);
  }

  String _stripAssTags(String text) =>
      text.replaceAll(_assTagPattern, '').replaceAll(r'\N', '\n').replaceAll(r'\n', '\n').replaceAll(r'\h', ' ').trim();

  List<StyledTextSpan>? _parseAssStyledText(String text) {
    final spans = <StyledTextSpan>[];
    var currentStyle = const SubtitleTextStyle();
    var i = 0;
    var currentText = StringBuffer();

    while (i < text.length) {
      if (text[i] == '{') {
        final closeIndex = text.indexOf('}', i);
        if (closeIndex == -1) {
          currentText.write(text[i]);
          i++;
          continue;
        }

        // Flush current text before style change
        if (currentText.isNotEmpty) {
          spans.add(_createAssSpan(currentText.toString(), currentStyle));
          currentText = StringBuffer();
        }

        // Parse override tags
        final tags = text.substring(i + 1, closeIndex);
        currentStyle = _parseAssTags(tags, currentStyle);

        i = closeIndex + 1;
      } else if (text.substring(i).startsWith(r'\N') || text.substring(i).startsWith(r'\n')) {
        currentText.write('\n');
        i += 2;
      } else if (text.substring(i).startsWith(r'\h')) {
        currentText.write(' ');
        i += 2;
      } else {
        currentText.write(text[i]);
        i++;
      }
    }

    if (currentText.isNotEmpty) {
      spans.add(_createAssSpan(currentText.toString(), currentStyle));
    }

    // Only return spans if there's actual styling
    final hasStyle = spans.any((s) => s.hasStyle);
    return hasStyle ? spans : null;
  }

  SubtitleTextStyle _parseAssTags(String tags, SubtitleTextStyle current) {
    var isBold = current.isBold;
    var isItalic = current.isItalic;
    var isUnderline = current.isUnderline;
    var isStrikethrough = current.isStrikethrough;
    var color = current.color;
    var fontSize = current.fontSize;

    // Parse individual tags (separated by \)
    for (final tag in tags.split(r'\').where((t) => t.isNotEmpty)) {
      if (tag == 'b1') {
        isBold = true;
      } else if (tag == 'b0') {
        isBold = false;
      } else if (tag == 'i1') {
        isItalic = true;
      } else if (tag == 'i0') {
        isItalic = false;
      } else if (tag == 'u1') {
        isUnderline = true;
      } else if (tag == 'u0') {
        isUnderline = false;
      } else if (tag == 's1') {
        isStrikethrough = true;
      } else if (tag == 's0') {
        isStrikethrough = false;
      } else if (tag.startsWith('c&H') || tag.startsWith('1c&H')) {
        // Color in ASS format: &HBBGGRR& or &HAABBGGRR&
        color = _parseAssColor(tag);
      } else if (tag.startsWith('fs')) {
        final sizeStr = tag.substring(2);
        fontSize = double.tryParse(sizeStr);
      }
    }

    return SubtitleTextStyle(
      isBold: isBold,
      isItalic: isItalic,
      isUnderline: isUnderline,
      isStrikethrough: isStrikethrough,
      color: color,
      fontSize: fontSize,
    );
  }

  Color? _parseAssColor(String tag) {
    // Extract hex value from &HBBGGRR& or &HAABBGGRR&
    final hexMatch = RegExp(r'&H([0-9A-Fa-f]+)&?').firstMatch(tag);
    if (hexMatch == null) return null;

    final hex = hexMatch.group(1)!;
    // ASS uses BGR order, not RGB
    if (hex.length == 6) {
      final b = int.tryParse(hex.substring(0, 2), radix: 16) ?? 0;
      final g = int.tryParse(hex.substring(2, 4), radix: 16) ?? 0;
      final r = int.tryParse(hex.substring(4, 6), radix: 16) ?? 0;
      return Color.fromARGB(255, r, g, b);
    } else if (hex.length == 8) {
      final a = 255 - (int.tryParse(hex.substring(0, 2), radix: 16) ?? 0);
      final b = int.tryParse(hex.substring(2, 4), radix: 16) ?? 0;
      final g = int.tryParse(hex.substring(4, 6), radix: 16) ?? 0;
      final r = int.tryParse(hex.substring(6, 8), radix: 16) ?? 0;
      return Color.fromARGB(a, r, g, b);
    }
    return null;
  }

  StyledTextSpan _createAssSpan(String text, SubtitleTextStyle style) {
    if (!style.hasFormatting) {
      return StyledTextSpan.plain(text);
    }
    return StyledTextSpan(text: text, style: style);
  }
}

/// Decoder for MKV S_TEXT/WEBVTT subtitle blocks.
///
/// MKV WebVTT blocks contain WebVTT cue payloads without timing
/// (timing is provided by the block header).
class MkvVttDecoder implements SubtitleSampleDecoder {
  /// Creates an MKV WebVTT decoder.
  const MkvVttDecoder();

  @override
  DecodedSubtitleSample? decode(Uint8List data, int presentationTime, int duration, int timescale) {
    final text = utf8.decode(data, allowMalformed: true).trim();
    if (text.isEmpty) return null;

    final startTime = _timescaleToDuration(presentationTime, timescale);
    final endTime = _timescaleToDuration(presentationTime + duration, timescale);

    // Reuse the VTT styling parser from WvttDecoder
    final styledSpans = const WvttDecoder()._parseVttStyledText(text);
    final plainText = text.replaceAll(RegExp('<[^>]+>'), '').trim();

    return DecodedSubtitleSample(
      startTime: startTime,
      endTime: endTime,
      text: plainText.isNotEmpty ? plainText : text,
      styledSpans: styledSpans,
    );
  }
}
