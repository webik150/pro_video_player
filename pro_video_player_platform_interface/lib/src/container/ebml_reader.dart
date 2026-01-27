import 'dart:convert';
import 'dart:typed_data';

/// Standard EBML element IDs.
///
/// These IDs are defined by the EBML specification and are common
/// to all EBML-based formats (MKV, WebM, etc.).
class EbmlIds {
  EbmlIds._();

  /// EBML header element (master).
  static const int ebml = 0x1A45DFA3;

  /// Document type string.
  static const int docType = 0x4282;

  /// Document type version.
  static const int docTypeVersion = 0x4287;

  /// Void element (padding).
  static const int void_ = 0xEC;

  /// CRC-32 element.
  static const int crc32 = 0xBF;

  /// Segment element (master) - contains all media data.
  static const int segment = 0x18538067;

  /// SeekHead element - index of other elements.
  static const int seekHead = 0x114D9B74;

  /// Info element (master) - segment metadata.
  static const int info = 0x1549A966;

  /// Tracks element (master) - track definitions.
  static const int tracks = 0x1654AE6B;

  /// Chapters element (master).
  static const int chapters = 0x1043A770;

  /// Cluster element (master) - media data.
  static const int cluster = 0x1F43B675;

  /// Cues element (master) - seeking index.
  static const int cues = 0x1C53BB6B;

  /// Attachments element (master).
  static const int attachments = 0x1941A469;

  /// Tags element (master).
  static const int tags = 0x1254C367;
}

/// Matroska-specific element IDs.
///
/// These IDs are specific to the Matroska container format (MKV/WebM).
class MatroskaIds {
  MatroskaIds._();

  // Info element children
  /// Segment UID (binary).
  static const int segmentUid = 0x73A4;

  /// Timecode scale in nanoseconds (uint, default 1000000 = 1ms).
  static const int timecodeScale = 0x2AD7B1;

  /// Duration in timecode scale units (float).
  static const int duration = 0x4489;

  /// Muxing application name (UTF-8).
  static const int muxingApp = 0x4D80;

  /// Writing application name (UTF-8).
  static const int writingApp = 0x5741;

  /// Date/time when the segment was created (int, nanoseconds since 2001-01-01).
  static const int dateUtc = 0x4461;

  /// Segment title (UTF-8).
  static const int title = 0x7BA9;

  // Track element children
  /// Track entry (master).
  static const int trackEntry = 0xAE;

  /// Track number (uint).
  static const int trackNumber = 0xD7;

  /// Track UID (uint).
  static const int trackUid = 0x73C5;

  /// Track type (uint): 1=video, 2=audio, 17=subtitle.
  static const int trackType = 0x83;

  /// Flag: track is enabled (uint, default 1).
  static const int flagEnabled = 0xB9;

  /// Flag: track is default (uint, default 1).
  static const int flagDefault = 0x88;

  /// Flag: track is forced (uint, default 0).
  static const int flagForced = 0x55AA;

  /// Flag: track is lacing (uint, default 1).
  static const int flagLacing = 0x9C;

  /// Codec ID string (e.g., "V_MPEG4/ISO/AVC").
  static const int codecId = 0x86;

  /// Codec private data (binary).
  static const int codecPrivate = 0x63A2;

  /// Codec name (UTF-8).
  static const int codecName = 0x258688;

  /// Track language (string, ISO 639-2).
  static const int language = 0x22B59C;

  /// Track language (BCP 47).
  static const int languageBcp47 = 0x22B59D;

  /// Track name (UTF-8).
  static const int name = 0x536E;

  // Video element children
  /// Video settings (master).
  static const int video = 0xE0;

  /// Pixel width (uint).
  static const int pixelWidth = 0xB0;

  /// Pixel height (uint).
  static const int pixelHeight = 0xBA;

  /// Display width (uint).
  static const int displayWidth = 0x54B0;

  /// Display height (uint).
  static const int displayHeight = 0x54BA;

  /// Display unit (uint): 0=pixels, 1=cm, 2=inches, 3=aspect ratio.
  static const int displayUnit = 0x54B2;

  /// Interlaced (uint): 0=undetermined, 1=interlaced, 2=progressive.
  static const int flagInterlaced = 0x9A;

  /// Frame rate (float).
  static const int frameRate = 0x2383E3;

  /// Colour (master).
  static const int colour = 0x55B0;

  // Audio element children
  /// Audio settings (master).
  static const int audio = 0xE1;

  /// Sampling frequency in Hz (float, default 8000).
  static const int samplingFrequency = 0xB5;

  /// Output sampling frequency (float).
  static const int outputSamplingFrequency = 0x78B5;

  /// Number of channels (uint, default 1).
  static const int channels = 0x9F;

  /// Bit depth (uint).
  static const int bitDepth = 0x6264;

  // Content encoding
  /// Content encodings (master).
  static const int contentEncodings = 0x6D80;

  /// Content encoding (master).
  static const int contentEncoding = 0x6240;

  // Default duration
  /// Default duration per frame in nanoseconds (uint).
  static const int defaultDuration = 0x23E383;
}

/// Track types in Matroska format.
class MatroskaTrackType {
  MatroskaTrackType._();

  /// Video track.
  static const int video = 1;

  /// Audio track.
  static const int audio = 2;

  /// Complex track (combined video+audio).
  static const int complex = 3;

  /// Logo track.
  static const int logo = 16;

  /// Subtitle track.
  static const int subtitle = 17;

  /// Button track (DVD menus).
  static const int buttons = 18;

  /// Control track.
  static const int control = 32;

  /// Metadata track.
  static const int metadata = 33;
}

/// An EBML element with its ID, size, and data position.
class EbmlElement {
  /// Creates an EBML element.
  const EbmlElement({required this.id, required this.dataSize, required this.dataOffset, required this.headerSize});

  /// Element ID (with marker bit preserved for identification).
  final int id;

  /// Size of element data in bytes.
  final int dataSize;

  /// Byte offset where element data starts.
  final int dataOffset;

  /// Size of the header (ID + size fields).
  final int headerSize;

  /// Total element size including header.
  int get totalSize => headerSize + dataSize;

  /// Byte offset where element ends.
  int get endOffset => dataOffset + dataSize;

  @override
  String toString() =>
      'EbmlElement(id: 0x${id.toRadixString(16).toUpperCase()}, dataSize: $dataSize, dataOffset: $dataOffset)';
}

/// Low-level reader for EBML (Extensible Binary Meta Language) format.
///
/// EBML is a binary format similar to XML used by Matroska (MKV/WebM).
/// Elements have variable-length IDs and sizes encoded as VINTs.
///
/// Example:
/// ```dart
/// final reader = EbmlReader(bytes);
/// while (reader.hasMore) {
///   final element = reader.readElement();
///   if (element == null) break;
///
///   if (element.id == EbmlIds.segment) {
///     // Process segment contents
///   } else {
///     reader.skip(element.dataSize);
///   }
/// }
/// ```
class EbmlReader {
  /// Creates an EBML reader for the given data.
  EbmlReader(this._data) : _view = ByteData.sublistView(_data);

  final Uint8List _data;
  final ByteData _view;
  int _position = 0;

  /// Current read position in bytes.
  int get position => _position;

  /// Sets the read position.
  set position(int value) => _position = value;

  /// Total data length in bytes.
  int get length => _data.length;

  /// Number of bytes remaining to read.
  int get remaining => _data.length - _position;

  /// Whether there are more bytes to read.
  bool get hasMore => _position < _data.length;

  /// Seeks to an absolute position.
  @Deprecated('Use position setter instead')
  void seek(int offset) => _position = offset;

  /// Skips forward by the given number of bytes.
  void skip(int count) {
    _position += count;
  }

  /// Reads a VINT (variable-length integer) and returns the value.
  ///
  /// The marker bit is stripped from the result.
  /// Use [readVintRaw] to preserve the marker bit (for element IDs).
  int readVint() {
    if (_position >= _data.length) return 0;

    final firstByte = _data[_position];
    final length = _vintLength(firstByte);

    if (_position + length > _data.length) return 0;

    // Strip marker bit from first byte
    var value = firstByte & _vintMask(length);

    for (var i = 1; i < length; i++) {
      value = (value << 8) | _data[_position + i];
    }

    _position += length;
    return value;
  }

  /// Reads a VINT with the marker bit preserved (for element IDs).
  int readVintRaw() {
    if (_position >= _data.length) return 0;

    final firstByte = _data[_position];
    final length = _vintLength(firstByte);

    if (_position + length > _data.length) return 0;

    var value = firstByte;
    for (var i = 1; i < length; i++) {
      value = (value << 8) | _data[_position + i];
    }

    _position += length;
    return value;
  }

  /// Reads an EBML element header and returns the element info.
  ///
  /// Returns null if at end of data or data is invalid.
  /// After reading, position is at start of element data.
  EbmlElement? readElement() {
    if (_position >= _data.length) return null;

    final startOffset = _position;

    // Read element ID (VINT with marker preserved)
    final firstByte = _data[_position];
    if (firstByte == 0) return null;

    final idLength = _vintLength(firstByte);
    if (_position + idLength > _data.length) return null;

    var id = firstByte;
    for (var i = 1; i < idLength; i++) {
      id = (id << 8) | _data[_position + i];
    }
    _position += idLength;

    // Read element size (VINT with marker stripped)
    if (_position >= _data.length) return null;
    final dataSize = readVint();

    final headerSize = _position - startOffset;

    return EbmlElement(id: id, dataSize: dataSize, dataOffset: _position, headerSize: headerSize);
  }

  /// Reads an unsigned integer of the given byte length.
  int readUint(int length) {
    if (_position + length > _data.length) return 0;

    var value = 0;
    for (var i = 0; i < length; i++) {
      value = (value << 8) | _data[_position + i];
    }
    _position += length;
    return value;
  }

  /// Reads a floating-point number (4 or 8 bytes, big-endian IEEE 754).
  double readFloat(int length) {
    if (_position + length > _data.length) return 0;

    double value;
    if (length == 4) {
      value = _view.getFloat32(_position);
    } else if (length == 8) {
      value = _view.getFloat64(_position);
    } else {
      return 0;
    }
    _position += length;
    return value;
  }

  /// Reads an ASCII string of the given byte length.
  String readString(int length) {
    if (_position + length > _data.length) return '';

    final bytes = _data.sublist(_position, _position + length);
    _position += length;

    // Remove null terminators
    var end = bytes.length;
    while (end > 0 && bytes[end - 1] == 0) {
      end--;
    }

    return ascii.decode(bytes.sublist(0, end));
  }

  /// Reads a UTF-8 string of the given byte length.
  String readUtf8(int length) {
    if (_position + length > _data.length) return '';

    final bytes = _data.sublist(_position, _position + length);
    _position += length;

    // Remove null terminators
    var end = bytes.length;
    while (end > 0 && bytes[end - 1] == 0) {
      end--;
    }

    return utf8.decode(bytes.sublist(0, end), allowMalformed: true);
  }

  /// Reads binary data of the given byte length.
  Uint8List readBinary(int length) {
    if (_position + length > _data.length) {
      return Uint8List(0);
    }

    final bytes = _data.sublist(_position, _position + length);
    _position += length;
    return bytes;
  }

  /// Returns the VINT length based on the first byte.
  static int _vintLength(int firstByte) {
    if (firstByte & 0x80 != 0) return 1;
    if (firstByte & 0x40 != 0) return 2;
    if (firstByte & 0x20 != 0) return 3;
    if (firstByte & 0x10 != 0) return 4;
    if (firstByte & 0x08 != 0) return 5;
    if (firstByte & 0x04 != 0) return 6;
    if (firstByte & 0x02 != 0) return 7;
    if (firstByte & 0x01 != 0) return 8;
    return 1; // Invalid, but handle gracefully
  }

  /// Returns the mask to strip the marker bit for a given VINT length.
  static int _vintMask(int length) {
    switch (length) {
      case 1:
        return 0x7F;
      case 2:
        return 0x3F;
      case 3:
        return 0x1F;
      case 4:
        return 0x0F;
      case 5:
        return 0x07;
      case 6:
        return 0x03;
      case 7:
        return 0x01;
      case 8:
        return 0x00;
      default:
        return 0x7F;
    }
  }
}
