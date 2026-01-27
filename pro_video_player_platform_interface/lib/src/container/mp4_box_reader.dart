import 'dart:typed_data';

/// Represents an MP4/MOV box (atom) with its location and size.
///
/// MP4 files consist of nested boxes, each with a type (fourcc),
/// size, and optional content. This class represents a single box's
/// metadata without holding its content.
class Mp4Box {
  /// Creates an MP4 box descriptor.
  const Mp4Box({required this.type, required this.offset, required this.size, required this.headerSize});

  /// Four character code identifying the box type (e.g., 'ftyp', 'moov').
  final String type;

  /// Byte offset of the box start in the file.
  final int offset;

  /// Total size of the box including header.
  final int size;

  /// Size of the box header (8 for standard, 16 for extended).
  final int headerSize;

  /// Byte offset where box data begins.
  int get dataOffset => offset + headerSize;

  /// Size of the box data (excluding header).
  int get dataSize => size - headerSize;

  /// Byte offset immediately after this box.
  int get endOffset => offset + size;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Mp4Box) return false;
    return type == other.type && offset == other.offset && size == other.size && headerSize == other.headerSize;
  }

  @override
  int get hashCode => Object.hash(type, offset, size, headerSize);

  @override
  String toString() => 'Mp4Box($type, offset: $offset, size: $size)';
}

/// Low-level reader for MP4/MOV box structures.
///
/// Provides methods for navigating the box hierarchy and reading
/// primitive types in big-endian format (as used by MP4).
///
/// Example:
/// ```dart
/// final reader = Mp4BoxReader(fileBytes);
/// while (true) {
///   final box = reader.readBox();
///   if (box == null) break;
///   if (box.type == 'moov') {
///     reader.enterBox(box);
///     // Parse moov contents...
///   }
/// }
/// ```
class Mp4BoxReader {
  /// Creates a reader for the given byte data.
  ///
  /// The optional [offset] parameter sets the initial read position.
  Mp4BoxReader(Uint8List data, {int offset = 0})
    : _data = data,
      _view = ByteData.view(data.buffer, data.offsetInBytes, data.length),
      _position = offset;

  final Uint8List _data;
  final ByteData _view;
  int _position;

  /// Current read position in bytes.
  int get position => _position;

  /// Total length of the data in bytes.
  int get length => _data.length;

  /// Number of bytes remaining from current position.
  int get remaining => _data.length - _position;

  /// Reads the next box header and returns box metadata.
  ///
  /// Returns null if there are not enough bytes for a box header.
  /// After reading, the position is advanced past the entire box.
  Mp4Box? readBox() {
    if (!hasRemaining(8)) return null;

    final offset = _position;
    var size = readUint32();
    final type = readFourCC();
    var headerSize = 8;

    if (size == 1) {
      // Extended size (64-bit)
      if (!hasRemaining(8)) return null;
      size = readUint64();
      headerSize = 16;
    } else if (size == 0) {
      // Box extends to end of file
      size = _data.length - offset;
    }

    // Position at end of box for sequential reading
    _position = offset + size;
    if (_position > _data.length) _position = _data.length;

    return Mp4Box(type: type, offset: offset, size: size, headerSize: headerSize);
  }

  /// Reads a child box within the bounds of a parent box.
  ///
  /// Returns null if the current position is outside the parent
  /// or there are not enough bytes for a box header.
  Mp4Box? readChildBox(Mp4Box parent) {
    if (_position < parent.dataOffset || _position >= parent.endOffset) {
      return null;
    }
    if (_position + 8 > parent.endOffset) {
      return null;
    }

    final box = readBox();
    if (box == null) return null;

    // Ensure child doesn't exceed parent bounds
    if (box.endOffset > parent.endOffset) {
      return null;
    }

    return box;
  }

  /// Moves the read position to an absolute offset.
  void seek(int offset) {
    _position = offset.clamp(0, _data.length);
  }

  /// Moves the read position by a relative amount.
  void skip(int bytes) {
    seek(_position + bytes);
  }

  /// Positions the reader at the start of a box's data.
  void enterBox(Mp4Box box) {
    _position = box.dataOffset;
  }

  /// Finds a box with the given type starting from current position.
  ///
  /// Returns the first matching box, or null if not found.
  /// The position is left at the start of the found box's data,
  /// or at the end of the data if not found.
  Mp4Box? findBox(String type) {
    while (hasRemaining(8)) {
      final box = readBox();
      if (box == null) break;
      if (box.type == type) {
        return box;
      }
    }
    return null;
  }

  /// Finds a child box with the given type within a parent box.
  ///
  /// Positions the reader at the parent's data start, then searches
  /// for the first matching child box.
  Mp4Box? findChildBox(Mp4Box parent, String type) {
    _position = parent.dataOffset;

    while (_position < parent.endOffset && hasRemaining(8)) {
      final savedPos = _position;
      final box = readBox();
      if (box == null) break;
      if (box.endOffset > parent.endOffset) break;
      if (box.type == type) {
        return box;
      }
      // readBox already advanced position to end of box
      if (_position <= savedPos) break; // Safety: prevent infinite loop
    }
    return null;
  }

  /// Returns true if at least [bytes] remain from current position.
  bool hasRemaining(int bytes) => remaining >= bytes;

  /// Reads an unsigned 8-bit integer.
  int readUint8() => _data[_position++];

  /// Reads an unsigned 16-bit big-endian integer.
  int readUint16() {
    final value = _view.getUint16(_position);
    _position += 2;
    return value;
  }

  /// Reads an unsigned 32-bit big-endian integer.
  int readUint32() {
    final value = _view.getUint32(_position);
    _position += 4;
    return value;
  }

  /// Reads an unsigned 64-bit big-endian integer.
  int readUint64() {
    final value = _view.getUint64(_position);
    _position += 8;
    return value;
  }

  /// Reads a signed 16-bit big-endian integer.
  int readInt16() {
    final value = _view.getInt16(_position);
    _position += 2;
    return value;
  }

  /// Reads a signed 32-bit big-endian integer.
  int readInt32() {
    final value = _view.getInt32(_position);
    _position += 4;
    return value;
  }

  /// Reads a 16.16 fixed-point number as a double.
  double readFixedPoint16_16() {
    final raw = readInt32();
    return raw / 65536.0;
  }

  /// Reads an 8.8 fixed-point number as a double.
  double readFixedPoint8_8() {
    final raw = readInt16();
    return raw / 256.0;
  }

  /// Reads a four character code (fourcc).
  String readFourCC() => String.fromCharCodes(_data.sublist(_position, _position += 4));

  /// Reads an ASCII string of the given length.
  ///
  /// Stops at null terminator if encountered.
  String readString(int length) {
    final bytes = _data.sublist(_position, _position + length);
    _position += length;

    // Find null terminator
    var end = bytes.length;
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] == 0) {
        end = i;
        break;
      }
    }

    return String.fromCharCodes(bytes.sublist(0, end));
  }

  /// Reads the specified number of bytes.
  Uint8List readBytes(int count) {
    final bytes = _data.sublist(_position, _position + count);
    _position += count;
    return bytes;
  }

  /// Reads an ISO 639-2/T language code from packed 16-bit format.
  ///
  /// MP4 encodes language codes as three 5-bit values packed into
  /// 16 bits, where each value is the character minus 0x60.
  String readLanguage() {
    final packed = readUint16();
    final c1 = ((packed >> 10) & 0x1F) + 0x60;
    final c2 = ((packed >> 5) & 0x1F) + 0x60;
    final c3 = (packed & 0x1F) + 0x60;
    return String.fromCharCodes([c1, c2, c3]);
  }

  /// Reads a 3x3 transformation matrix and extracts the rotation angle.
  ///
  /// The matrix is stored as 9 values: a, b, u, c, d, v, tx, ty, w
  /// where a, b, c, d are 16.16 fixed-point and u, v, w are 2.30 fixed-point.
  ///
  /// Returns rotation in degrees (0, 90, 180, 270).
  int readRotationFromMatrix() {
    // Read matrix values
    final a = readFixedPoint16_16();
    final b = readFixedPoint16_16();
    skip(4); // u (2.30)
    final c = readFixedPoint16_16();
    final d = readFixedPoint16_16();
    skip(4); // v (2.30)
    skip(4); // tx
    skip(4); // ty
    skip(4); // w

    // Determine rotation from matrix values
    // Identity (0°):   a=1, b=0, c=0, d=1
    // 90° CW:          a=0, b=1, c=-1, d=0
    // 180°:            a=-1, b=0, c=0, d=-1
    // 270° CW (90° CCW): a=0, b=-1, c=1, d=0

    const tolerance = 0.1;

    if (_near(a, 1, tolerance) && _near(d, 1, tolerance) && _near(b, 0, tolerance) && _near(c, 0, tolerance)) {
      return 0;
    }
    if (_near(a, 0, tolerance) && _near(b, 1, tolerance) && _near(c, -1, tolerance) && _near(d, 0, tolerance)) {
      return 90;
    }
    if (_near(a, -1, tolerance) && _near(d, -1, tolerance) && _near(b, 0, tolerance) && _near(c, 0, tolerance)) {
      return 180;
    }
    if (_near(a, 0, tolerance) && _near(b, -1, tolerance) && _near(c, 1, tolerance) && _near(d, 0, tolerance)) {
      return 270;
    }

    return 0; // Default for non-standard matrices
  }

  bool _near(double value, double target, double tolerance) => (value - target).abs() < tolerance;
}
