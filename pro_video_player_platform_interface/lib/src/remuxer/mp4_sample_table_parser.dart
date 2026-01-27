import '../container/mp4_box_reader.dart';
import 'mp4_sample_table.dart';

/// Parser for MP4 sample table boxes (stbl contents).
///
/// Parses the boxes within an stbl container that are needed for
/// sample-level access:
/// - stts: Sample timing (decoding time deltas)
/// - stsc: Sample-to-chunk mapping
/// - stco/co64: Chunk byte offsets
/// - stsz/stz2: Sample sizes
/// - stss: Sync sample (keyframe) indices
/// - ctts: Composition time offsets
class Mp4SampleTableParser {
  Mp4SampleTableParser._();

  /// Parses all sample table boxes within an stbl box.
  ///
  /// The [reader] should contain the MP4 data.
  /// The [stblBox] should be the sample table box to parse.
  /// The [timescale] is the track's timescale from mdhd.
  static Mp4SampleTable? parse(Mp4BoxReader reader, Mp4Box stblBox, int timescale) {
    List<SttsEntry>? sttsEntries;
    List<StscEntry>? stscEntries;
    List<int>? chunkOffsets;
    List<int>? sampleSizes;
    List<int>? syncSamples;
    List<CttsEntry>? cttsEntries;

    reader.seek(stblBox.dataOffset);

    while (reader.position < stblBox.endOffset && reader.hasRemaining(8)) {
      final box = reader.readChildBox(stblBox);
      if (box == null) break;

      switch (box.type) {
        case 'stts':
          sttsEntries = _parseStts(reader, box);
        case 'stsc':
          stscEntries = _parseStsc(reader, box);
        case 'stco':
          chunkOffsets = _parseStco(reader, box);
        case 'co64':
          chunkOffsets = _parseCo64(reader, box);
        case 'stsz':
          sampleSizes = _parseStsz(reader, box);
        case 'stz2':
          sampleSizes = _parseStz2(reader, box);
        case 'stss':
          syncSamples = _parseStss(reader, box);
        case 'ctts':
          cttsEntries = _parseCtts(reader, box);
      }

      // Advance to end of this box
      reader.seek(box.endOffset);
    }

    // stts and stsz are required for sample-level access
    if (sttsEntries == null || sampleSizes == null) {
      return null;
    }

    return Mp4SampleTable(
      timescale: timescale,
      sttsEntries: sttsEntries,
      stscEntries: stscEntries ?? const [],
      chunkOffsets: chunkOffsets ?? const [],
      sampleSizes: sampleSizes,
      syncSamples: syncSamples ?? const [],
      cttsEntries: cttsEntries ?? const [],
    );
  }

  /// Parses stts (decoding time to sample) box.
  ///
  /// Format:
  /// - version (1 byte)
  /// - flags (3 bytes)
  /// - entry_count (4 bytes)
  /// - entries: [sample_count (4), sample_delta (4)] * entry_count
  static List<SttsEntry> _parseStts(Mp4BoxReader reader, Mp4Box box) {
    reader.enterBox(box);

    reader.skip(4); // version + flags
    final entryCount = reader.readUint32();

    final entries = <SttsEntry>[];
    for (var i = 0; i < entryCount && reader.hasRemaining(8); i++) {
      final sampleCount = reader.readUint32();
      final sampleDelta = reader.readUint32();
      entries.add(SttsEntry(sampleCount: sampleCount, sampleDelta: sampleDelta));
    }

    return entries;
  }

  /// Parses stsc (sample to chunk) box.
  ///
  /// Format:
  /// - version (1 byte)
  /// - flags (3 bytes)
  /// - entry_count (4 bytes)
  /// - entries: [first_chunk (4), samples_per_chunk (4), sample_description_index (4)] * entry_count
  static List<StscEntry> _parseStsc(Mp4BoxReader reader, Mp4Box box) {
    reader.enterBox(box);

    reader.skip(4); // version + flags
    final entryCount = reader.readUint32();

    final entries = <StscEntry>[];
    for (var i = 0; i < entryCount && reader.hasRemaining(12); i++) {
      final firstChunk = reader.readUint32();
      final samplesPerChunk = reader.readUint32();
      final sampleDescriptionIndex = reader.readUint32();
      entries.add(
        StscEntry(
          firstChunk: firstChunk,
          samplesPerChunk: samplesPerChunk,
          sampleDescriptionIndex: sampleDescriptionIndex,
        ),
      );
    }

    return entries;
  }

  /// Parses stco (32-bit chunk offset) box.
  ///
  /// Format:
  /// - version (1 byte)
  /// - flags (3 bytes)
  /// - entry_count (4 bytes)
  /// - offsets: [chunk_offset (4)] * entry_count
  static List<int> _parseStco(Mp4BoxReader reader, Mp4Box box) {
    reader.enterBox(box);

    reader.skip(4); // version + flags
    final entryCount = reader.readUint32();

    final offsets = <int>[];
    for (var i = 0; i < entryCount && reader.hasRemaining(4); i++) {
      offsets.add(reader.readUint32());
    }

    return offsets;
  }

  /// Parses co64 (64-bit chunk offset) box.
  ///
  /// Format:
  /// - version (1 byte)
  /// - flags (3 bytes)
  /// - entry_count (4 bytes)
  /// - offsets: [chunk_offset (8)] * entry_count
  static List<int> _parseCo64(Mp4BoxReader reader, Mp4Box box) {
    reader.enterBox(box);

    reader.skip(4); // version + flags
    final entryCount = reader.readUint32();

    final offsets = <int>[];
    for (var i = 0; i < entryCount && reader.hasRemaining(8); i++) {
      offsets.add(reader.readUint64());
    }

    return offsets;
  }

  /// Parses stsz (sample size) box.
  ///
  /// Format:
  /// - version (1 byte)
  /// - flags (3 bytes)
  /// - sample_size (4 bytes) - if non-zero, all samples have this size
  /// - sample_count (4 bytes)
  /// - entries: [entry_size (4)] * sample_count (only if sample_size == 0)
  static List<int> _parseStsz(Mp4BoxReader reader, Mp4Box box) {
    reader.enterBox(box);

    reader.skip(4); // version + flags
    final uniformSize = reader.readUint32();
    final sampleCount = reader.readUint32();

    if (uniformSize > 0) {
      // All samples have the same size
      return List<int>.filled(sampleCount, uniformSize);
    }

    // Variable size samples
    final sizes = <int>[];
    for (var i = 0; i < sampleCount && reader.hasRemaining(4); i++) {
      sizes.add(reader.readUint32());
    }

    return sizes;
  }

  /// Parses stz2 (compact sample size) box.
  ///
  /// This is an alternative to stsz with packed sample sizes.
  /// Format:
  /// - version (1 byte)
  /// - flags (3 bytes)
  /// - reserved (3 bytes)
  /// - field_size (1 byte) - 4, 8, or 16 bits per entry
  /// - sample_count (4 bytes)
  /// - entries: packed according to field_size
  static List<int> _parseStz2(Mp4BoxReader reader, Mp4Box box) {
    reader.enterBox(box);

    reader.skip(4); // version + flags
    reader.skip(3); // reserved
    final fieldSize = reader.readUint8();
    final sampleCount = reader.readUint32();

    final sizes = <int>[];

    switch (fieldSize) {
      case 4:
        // 4-bit entries, 2 per byte
        for (var i = 0; i < sampleCount; i += 2) {
          if (!reader.hasRemaining(1)) break;
          final byte = reader.readUint8();
          sizes.add((byte >> 4) & 0x0F);
          if (i + 1 < sampleCount) {
            sizes.add(byte & 0x0F);
          }
        }
      case 8:
        // 8-bit entries
        for (var i = 0; i < sampleCount && reader.hasRemaining(1); i++) {
          sizes.add(reader.readUint8());
        }
      case 16:
        // 16-bit entries
        for (var i = 0; i < sampleCount && reader.hasRemaining(2); i++) {
          sizes.add(reader.readUint16());
        }
      default:
        // Unknown field size, return empty
        return [];
    }

    return sizes;
  }

  /// Parses stss (sync sample) box.
  ///
  /// Contains indices (1-based) of keyframes.
  /// Format:
  /// - version (1 byte)
  /// - flags (3 bytes)
  /// - entry_count (4 bytes)
  /// - entries: [sample_number (4)] * entry_count
  static List<int> _parseStss(Mp4BoxReader reader, Mp4Box box) {
    reader.enterBox(box);

    reader.skip(4); // version + flags
    final entryCount = reader.readUint32();

    final syncSamples = <int>[];
    for (var i = 0; i < entryCount && reader.hasRemaining(4); i++) {
      syncSamples.add(reader.readUint32());
    }

    return syncSamples;
  }

  /// Parses ctts (composition time to sample) box.
  ///
  /// Contains composition time offsets (PTS - DTS).
  /// Format:
  /// - version (1 byte)
  /// - flags (3 bytes)
  /// - entry_count (4 bytes)
  /// - entries: [sample_count (4), sample_offset (4)] * entry_count
  ///
  /// Version 0 has unsigned offsets, version 1 has signed offsets.
  static List<CttsEntry> _parseCtts(Mp4BoxReader reader, Mp4Box box) {
    reader.enterBox(box);

    final version = reader.readUint8();
    reader.skip(3); // flags
    final entryCount = reader.readUint32();

    final entries = <CttsEntry>[];
    for (var i = 0; i < entryCount && reader.hasRemaining(8); i++) {
      final sampleCount = reader.readUint32();
      final sampleOffset = version == 0 ? reader.readUint32() : reader.readInt32();
      entries.add(CttsEntry(sampleCount: sampleCount, sampleOffset: sampleOffset));
    }

    return entries;
  }
}
