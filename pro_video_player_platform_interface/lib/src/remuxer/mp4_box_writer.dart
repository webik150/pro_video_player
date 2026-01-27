import 'dart:typed_data';

/// Low-level writer for MP4/MOV box structures.
///
/// Provides methods for building boxes with big-endian primitives.
/// Handles both standard (32-bit size) and extended (64-bit size) boxes.
///
/// Example:
/// ```dart
/// final writer = Mp4BoxWriter();
/// writer.writeBox('ftyp', (w) {
///   w.writeFourCC('isom');
///   w.writeUint32(0x200); // minor version
///   w.writeFourCC('isom');
///   w.writeFourCC('mp41');
/// });
/// final bytes = writer.toBytes();
/// ```
class Mp4BoxWriter {
  /// Creates a new MP4 box writer.
  Mp4BoxWriter() : _buffer = BytesBuilder(copy: false);

  final BytesBuilder _buffer;

  /// Current size of the written data in bytes.
  int get length => _buffer.length;

  /// Writes an unsigned 8-bit integer.
  void writeUint8(int value) {
    _buffer.addByte(value & 0xFF);
  }

  /// Writes an unsigned 16-bit big-endian integer.
  void writeUint16(int value) {
    _buffer.addByte((value >> 8) & 0xFF);
    _buffer.addByte(value & 0xFF);
  }

  /// Writes an unsigned 24-bit big-endian integer.
  void writeUint24(int value) {
    _buffer.addByte((value >> 16) & 0xFF);
    _buffer.addByte((value >> 8) & 0xFF);
    _buffer.addByte(value & 0xFF);
  }

  /// Writes an unsigned 32-bit big-endian integer.
  void writeUint32(int value) {
    _buffer.addByte((value >> 24) & 0xFF);
    _buffer.addByte((value >> 16) & 0xFF);
    _buffer.addByte((value >> 8) & 0xFF);
    _buffer.addByte(value & 0xFF);
  }

  /// Writes an unsigned 64-bit big-endian integer.
  void writeUint64(int value) {
    _buffer.addByte((value >> 56) & 0xFF);
    _buffer.addByte((value >> 48) & 0xFF);
    _buffer.addByte((value >> 40) & 0xFF);
    _buffer.addByte((value >> 32) & 0xFF);
    _buffer.addByte((value >> 24) & 0xFF);
    _buffer.addByte((value >> 16) & 0xFF);
    _buffer.addByte((value >> 8) & 0xFF);
    _buffer.addByte(value & 0xFF);
  }

  /// Writes a signed 16-bit big-endian integer.
  void writeInt16(int value) {
    writeUint16(value & 0xFFFF);
  }

  /// Writes a signed 32-bit big-endian integer.
  void writeInt32(int value) {
    writeUint32(value & 0xFFFFFFFF);
  }

  /// Writes a 16.16 fixed-point number.
  void writeFixedPoint16_16(num value) {
    writeInt32((value * 65536).round());
  }

  /// Writes an 8.8 fixed-point number.
  void writeFixedPoint8_8(num value) {
    writeInt16((value * 256).round());
  }

  /// Writes a four character code (fourcc).
  void writeFourCC(String fourcc) {
    if (fourcc.length != 4) {
      throw ArgumentError('FourCC must be exactly 4 characters: $fourcc');
    }
    for (var i = 0; i < 4; i++) {
      _buffer.addByte(fourcc.codeUnitAt(i));
    }
  }

  /// Writes raw bytes.
  void writeBytes(Uint8List bytes) {
    _buffer.add(bytes);
  }

  /// Writes zero bytes for padding.
  void writeZeros(int count) {
    for (var i = 0; i < count; i++) {
      _buffer.addByte(0);
    }
  }

  /// Writes an ISO 639-2/T language code in packed 16-bit format.
  ///
  /// MP4 encodes language codes as three 5-bit values packed into
  /// 16 bits, where each value is the character minus 0x60.
  void writeLanguage(String lang) {
    if (lang.length != 3) {
      throw ArgumentError('Language code must be exactly 3 characters: $lang');
    }
    final c1 = (lang.codeUnitAt(0) - 0x60) & 0x1F;
    final c2 = (lang.codeUnitAt(1) - 0x60) & 0x1F;
    final c3 = (lang.codeUnitAt(2) - 0x60) & 0x1F;
    writeUint16((c1 << 10) | (c2 << 5) | c3);
  }

  /// Writes a full box with a nested builder.
  ///
  /// The builder callback receives a writer for the box contents.
  /// The box header (size + type) is written automatically.
  void writeBox(String type, void Function(Mp4BoxWriter) builder) {
    // Build content first to determine size
    final contentWriter = Mp4BoxWriter();
    builder(contentWriter);
    final content = contentWriter.toBytes();

    // Write header + content
    writeUint32(8 + content.length);
    writeFourCC(type);
    writeBytes(content);
  }

  /// Writes a full box version + flags header.
  ///
  /// Used at the start of "full boxes" like mvhd, tkhd, etc.
  void writeFullBoxHeader(int version, int flags) {
    writeUint8(version);
    writeUint24(flags);
  }

  /// Writes an identity 3x3 transformation matrix.
  ///
  /// Format: [a, b, u, c, d, v, tx, ty, w] where
  /// a, b, c, d, tx, ty are 16.16 fixed-point and u, v, w are 2.30 fixed-point.
  void writeIdentityMatrix() {
    // a = 1, b = 0, u = 0
    writeFixedPoint16_16(1);
    writeFixedPoint16_16(0);
    writeUint32(0);
    // c = 0, d = 1, v = 0
    writeFixedPoint16_16(0);
    writeFixedPoint16_16(1);
    writeUint32(0);
    // tx = 0, ty = 0, w = 1 (as 2.30)
    writeFixedPoint16_16(0);
    writeFixedPoint16_16(0);
    writeUint32(0x40000000); // 1.0 in 2.30 format
  }

  /// Returns the written data as a byte array.
  ///
  /// This clears the internal buffer.
  Uint8List toBytes() => _buffer.takeBytes();
}

/// Extension for building common MP4 boxes.
extension Mp4CommonBoxes on Mp4BoxWriter {
  /// Writes an ftyp (file type) box.
  ///
  /// [majorBrand] is typically 'isom', 'mp42', 'dash', etc.
  /// [minorVersion] is the brand minor version.
  /// [compatibleBrands] lists additional compatible brands.
  void writeFtyp({required String majorBrand, int minorVersion = 0, List<String> compatibleBrands = const []}) {
    writeBox('ftyp', (w) {
      w.writeFourCC(majorBrand);
      w.writeUint32(minorVersion);
      for (final brand in compatibleBrands) {
        w.writeFourCC(brand);
      }
    });
  }

  /// Writes an mvhd (movie header) box.
  ///
  /// [timescale] is the time units per second.
  /// [duration] is the total duration in timescale units.
  void writeMvhd({required int timescale, required int duration, int nextTrackId = 2}) {
    writeBox('mvhd', (w) {
      w.writeFullBoxHeader(0, 0); // version 0, flags 0

      // Creation and modification time (seconds since 1904)
      w.writeUint32(0);
      w.writeUint32(0);

      w.writeUint32(timescale);
      w.writeUint32(duration);

      w.writeFixedPoint16_16(1); // rate
      w.writeFixedPoint8_8(1); // volume

      w.writeUint16(0); // reserved
      w.writeZeros(8); // reserved

      w.writeIdentityMatrix();

      w.writeZeros(24); // pre_defined

      w.writeUint32(nextTrackId);
    });
  }

  /// Writes a tkhd (track header) box.
  void writeTkhd({
    required int trackId,
    required int duration,
    int? width,
    int? height,
    bool isEnabled = true,
    bool isInMovie = true,
    bool isInPreview = true,
    bool isAudio = false,
  }) {
    writeBox('tkhd', (w) {
      var flags = 0;
      if (isEnabled) flags |= 0x01;
      if (isInMovie) flags |= 0x02;
      if (isInPreview) flags |= 0x04;
      w.writeFullBoxHeader(0, flags);

      // Creation and modification time
      w.writeUint32(0);
      w.writeUint32(0);

      w.writeUint32(trackId);
      w.writeUint32(0); // reserved

      w.writeUint32(duration);

      w.writeZeros(8); // reserved

      w.writeInt16(0); // layer
      w.writeInt16(isAudio ? 1 : 0); // alternate_group

      // Volume: 0x0100 for audio, 0 for video
      w.writeFixedPoint8_8(isAudio ? 1.0 : 0.0);

      w.writeUint16(0); // reserved

      w.writeIdentityMatrix();

      // Width and height as 16.16 fixed-point
      w.writeFixedPoint16_16((width ?? 0).toDouble());
      w.writeFixedPoint16_16((height ?? 0).toDouble());
    });
  }

  /// Writes an mdhd (media header) box.
  void writeMdhd({required int timescale, required int duration, String language = 'und'}) {
    writeBox('mdhd', (w) {
      w.writeFullBoxHeader(0, 0);

      // Creation and modification time
      w.writeUint32(0);
      w.writeUint32(0);

      w.writeUint32(timescale);
      w.writeUint32(duration);

      w.writeLanguage(language);
      w.writeUint16(0); // pre_defined
    });
  }

  /// Writes an hdlr (handler reference) box.
  void writeHdlr({required String handlerType, String name = ''}) {
    writeBox('hdlr', (w) {
      w.writeFullBoxHeader(0, 0);

      w.writeUint32(0); // pre_defined
      w.writeFourCC(handlerType);
      w.writeZeros(12); // reserved

      // Null-terminated name
      for (var i = 0; i < name.length; i++) {
        w.writeUint8(name.codeUnitAt(i));
      }
      w.writeUint8(0);
    });
  }

  /// Writes a vmhd (video media header) box.
  void writeVmhd() {
    writeBox('vmhd', (w) {
      w.writeFullBoxHeader(0, 1); // flags = 1 for vmhd

      w.writeUint16(0); // graphicsmode
      w.writeUint16(0); // opcolor[0]
      w.writeUint16(0); // opcolor[1]
      w.writeUint16(0); // opcolor[2]
    });
  }

  /// Writes an smhd (sound media header) box.
  void writeSmhd() {
    writeBox('smhd', (w) {
      w.writeFullBoxHeader(0, 0);

      w.writeInt16(0); // balance
      w.writeUint16(0); // reserved
    });
  }

  /// Writes a dinf (data information) box with a dref.
  void writeDinf() {
    writeBox('dinf', (w) {
      w.writeBox('dref', (dref) {
        dref.writeFullBoxHeader(0, 0);
        dref.writeUint32(1); // entry_count

        dref.writeBox('url ', (url) {
          url.writeFullBoxHeader(0, 1); // flags = 1 means data is in same file
        });
      });
    });
  }

  /// Writes an empty stbl (sample table) for fragmented MP4.
  ///
  /// In fMP4, sample data is in fragments, but stbl must exist with
  /// empty tables. The stsd (sample description) contains codec config.
  void writeEmptyStbl({required Uint8List stsdContent}) {
    writeBox('stbl', (w) {
      // Sample description with codec-specific content
      w.writeBox('stsd', (stsd) {
        stsd.writeFullBoxHeader(0, 0);
        stsd.writeUint32(1); // entry_count
        stsd.writeBytes(stsdContent);
      });

      // Empty time-to-sample
      w.writeBox('stts', (stts) {
        stts.writeFullBoxHeader(0, 0);
        stts.writeUint32(0); // entry_count
      });

      // Empty sample-to-chunk
      w.writeBox('stsc', (stsc) {
        stsc.writeFullBoxHeader(0, 0);
        stsc.writeUint32(0); // entry_count
      });

      // Empty sample size
      w.writeBox('stsz', (stsz) {
        stsz.writeFullBoxHeader(0, 0);
        stsz.writeUint32(0); // sample_size
        stsz.writeUint32(0); // sample_count
      });

      // Empty chunk offset
      w.writeBox('stco', (stco) {
        stco.writeFullBoxHeader(0, 0);
        stco.writeUint32(0); // entry_count
      });
    });
  }

  /// Writes a trex (track extends) box for fragmented MP4.
  void writeTrex({required int trackId}) {
    writeBox('trex', (w) {
      w.writeFullBoxHeader(0, 0);

      w.writeUint32(trackId);
      w.writeUint32(1); // default_sample_description_index
      w.writeUint32(0); // default_sample_duration
      w.writeUint32(0); // default_sample_size
      w.writeUint32(0); // default_sample_flags
    });
  }

  /// Writes an mfhd (movie fragment header) box.
  void writeMfhd({required int sequenceNumber}) {
    writeBox('mfhd', (w) {
      w.writeFullBoxHeader(0, 0);
      w.writeUint32(sequenceNumber);
    });
  }

  /// Writes a tfhd (track fragment header) box.
  void writeTfhd({
    required int trackId,
    int? baseDataOffset,
    int? defaultSampleDuration,
    int? defaultSampleSize,
    int? defaultSampleFlags,
  }) {
    writeBox('tfhd', (w) {
      var flags = 0;
      if (baseDataOffset != null) flags |= 0x000001;
      if (defaultSampleDuration != null) flags |= 0x000008;
      if (defaultSampleSize != null) flags |= 0x000010;
      if (defaultSampleFlags != null) flags |= 0x000020;

      w.writeFullBoxHeader(0, flags);

      w.writeUint32(trackId);
      if (baseDataOffset != null) w.writeUint64(baseDataOffset);
      if (defaultSampleDuration != null) w.writeUint32(defaultSampleDuration);
      if (defaultSampleSize != null) w.writeUint32(defaultSampleSize);
      if (defaultSampleFlags != null) w.writeUint32(defaultSampleFlags);
    });
  }

  /// Writes a tfdt (track fragment decode time) box.
  void writeTfdt({required int baseMediaDecodeTime, bool version1 = false}) {
    writeBox('tfdt', (w) {
      w.writeFullBoxHeader(version1 ? 1 : 0, 0);

      if (version1) {
        w.writeUint64(baseMediaDecodeTime);
      } else {
        w.writeUint32(baseMediaDecodeTime);
      }
    });
  }

  /// Writes a trun (track run) box.
  ///
  /// [samples] is a list of sample info tuples.
  /// [dataOffset] is the offset from the start of moof to the sample data.
  void writeTrun({required List<TrunSample> samples, int? dataOffset, int? firstSampleFlags}) {
    writeBox('trun', (w) {
      // Determine which fields are present
      var flags = 0;
      if (dataOffset != null) flags |= 0x000001;
      if (firstSampleFlags != null) flags |= 0x000004;

      // Check what sample fields we need
      final hasDuration = samples.any((s) => s.duration != null);
      final hasSize = samples.any((s) => s.size != null);
      final hasFlags = samples.any((s) => s.flags != null);
      final hasCompositionOffset = samples.any((s) => s.compositionOffset != null);

      if (hasDuration) flags |= 0x000100;
      if (hasSize) flags |= 0x000200;
      if (hasFlags) flags |= 0x000400;
      if (hasCompositionOffset) flags |= 0x000800;

      w.writeFullBoxHeader(0, flags);

      w.writeUint32(samples.length);
      if (dataOffset != null) w.writeInt32(dataOffset);
      if (firstSampleFlags != null) w.writeUint32(firstSampleFlags);

      for (final sample in samples) {
        if (hasDuration) w.writeUint32(sample.duration ?? 0);
        if (hasSize) w.writeUint32(sample.size ?? 0);
        if (hasFlags) w.writeUint32(sample.flags ?? 0);
        if (hasCompositionOffset) w.writeInt32(sample.compositionOffset ?? 0);
      }
    });
  }
}

/// Sample information for trun box.
class TrunSample {
  /// Creates a trun sample entry.
  const TrunSample({this.duration, this.size, this.flags, this.compositionOffset});

  /// Sample duration in timescale units.
  final int? duration;

  /// Sample size in bytes.
  final int? size;

  /// Sample flags (keyframe, depends-on, etc.).
  final int? flags;

  /// Composition time offset (PTS - DTS) in timescale units.
  final int? compositionOffset;
}
