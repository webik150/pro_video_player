/// Sample timing entry from stts box.
///
/// Each entry describes a run of consecutive samples with the same duration.
class SttsEntry {
  /// Creates a sample timing entry.
  const SttsEntry({required this.sampleCount, required this.sampleDelta});

  /// Number of consecutive samples with this duration.
  final int sampleCount;

  /// Duration of each sample in timescale units.
  final int sampleDelta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SttsEntry && sampleCount == other.sampleCount && sampleDelta == other.sampleDelta;

  @override
  int get hashCode => Object.hash(sampleCount, sampleDelta);

  @override
  String toString() => 'SttsEntry(count: $sampleCount, delta: $sampleDelta)';
}

/// Sample-to-chunk entry from stsc box.
///
/// Describes how samples are grouped into chunks.
class StscEntry {
  /// Creates a sample-to-chunk entry.
  const StscEntry({required this.firstChunk, required this.samplesPerChunk, required this.sampleDescriptionIndex});

  /// Index of first chunk that uses this mapping (1-based).
  final int firstChunk;

  /// Number of samples in each chunk.
  final int samplesPerChunk;

  /// Index into the sample description table.
  final int sampleDescriptionIndex;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StscEntry &&
          firstChunk == other.firstChunk &&
          samplesPerChunk == other.samplesPerChunk &&
          sampleDescriptionIndex == other.sampleDescriptionIndex;

  @override
  int get hashCode => Object.hash(firstChunk, samplesPerChunk, sampleDescriptionIndex);

  @override
  String toString() => 'StscEntry(firstChunk: $firstChunk, samplesPerChunk: $samplesPerChunk)';
}

/// Composition time offset entry from ctts box.
///
/// Describes the difference between decode time (DTS) and composition time (PTS).
class CttsEntry {
  /// Creates a composition time offset entry.
  const CttsEntry({required this.sampleCount, required this.sampleOffset});

  /// Number of consecutive samples with this offset.
  final int sampleCount;

  /// Composition time offset in timescale units.
  /// Can be negative in version 1 ctts boxes.
  final int sampleOffset;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CttsEntry && sampleCount == other.sampleCount && sampleOffset == other.sampleOffset;

  @override
  int get hashCode => Object.hash(sampleCount, sampleOffset);

  @override
  String toString() => 'CttsEntry(count: $sampleCount, offset: $sampleOffset)';
}

/// Complete sample table data for an MP4 track.
///
/// Contains all information needed to locate and time individual samples
/// within the file. This is the foundation for sample-level access needed
/// for remuxing operations.
class Mp4SampleTable {
  /// Creates a sample table with the given data.
  const Mp4SampleTable({
    required this.timescale,
    this.sttsEntries = const [],
    this.stscEntries = const [],
    this.chunkOffsets = const [],
    this.sampleSizes = const [],
    this.syncSamples = const [],
    this.cttsEntries = const [],
  });

  /// Track timescale (samples per second).
  final int timescale;

  /// Sample timing table (stts).
  final List<SttsEntry> sttsEntries;

  /// Sample-to-chunk mapping (stsc).
  final List<StscEntry> stscEntries;

  /// Byte offsets of each chunk in the file (stco/co64).
  final List<int> chunkOffsets;

  /// Size in bytes of each sample (stsz).
  final List<int> sampleSizes;

  /// Indices of keyframe samples (stss), 1-based.
  /// If empty, all samples are sync samples.
  final List<int> syncSamples;

  /// Composition time offsets (ctts).
  final List<CttsEntry> cttsEntries;

  /// Total number of samples in this track.
  int get sampleCount => sampleSizes.length;

  /// Total number of chunks in this track.
  int get chunkCount => chunkOffsets.length;

  /// Whether this track has an stss box (explicit keyframe list).
  bool get hasExplicitSyncSamples => syncSamples.isNotEmpty;

  /// Whether sample [index] is a keyframe (0-based index).
  ///
  /// If no stss box exists, all samples are considered keyframes.
  bool isSyncSample(int index) {
    if (syncSamples.isEmpty) return true;
    // stss uses 1-based indices
    return syncSamples.contains(index + 1);
  }

  /// Gets the decode timestamp (DTS) for sample [index] in timescale units.
  ///
  /// Returns 0 if the sample index is invalid or no timing info exists.
  int getDecodingTime(int index) {
    if (index < 0 || sttsEntries.isEmpty) return 0;

    var dts = 0;
    var sampleIndex = 0;

    for (final entry in sttsEntries) {
      if (sampleIndex + entry.sampleCount > index) {
        // Sample is within this entry
        final samplesInEntry = index - sampleIndex;
        return dts + samplesInEntry * entry.sampleDelta;
      }
      dts += entry.sampleCount * entry.sampleDelta;
      sampleIndex += entry.sampleCount;
    }

    return dts; // Return last known time if index exceeds samples
  }

  /// Gets the composition timestamp (PTS) for sample [index] in timescale units.
  ///
  /// PTS = DTS + composition offset from ctts.
  int getCompositionTime(int index) {
    final dts = getDecodingTime(index);
    if (cttsEntries.isEmpty) return dts;

    var sampleIndex = 0;
    for (final entry in cttsEntries) {
      if (sampleIndex + entry.sampleCount > index) {
        return dts + entry.sampleOffset;
      }
      sampleIndex += entry.sampleCount;
    }

    return dts;
  }

  /// Gets the duration of sample [index] in timescale units.
  int getSampleDuration(int index) {
    if (index < 0 || sttsEntries.isEmpty) return 0;

    var sampleIndex = 0;
    for (final entry in sttsEntries) {
      if (sampleIndex + entry.sampleCount > index) {
        return entry.sampleDelta;
      }
      sampleIndex += entry.sampleCount;
    }

    return 0;
  }

  /// Gets the byte offset and size of sample [index] in the file.
  ///
  /// Returns null if the sample cannot be located.
  SampleLocation? getSampleLocation(int index) {
    if (index < 0 || index >= sampleCount || chunkOffsets.isEmpty || stscEntries.isEmpty) {
      return null;
    }

    // Find which chunk contains this sample and the sample's position within the chunk
    var currentSample = 0;

    for (var i = 0; i < stscEntries.length; i++) {
      final entry = stscEntries[i];
      final nextEntry = i + 1 < stscEntries.length ? stscEntries[i + 1] : null;
      final lastChunkForEntry = nextEntry != null ? nextEntry.firstChunk - 1 : chunkCount;

      // Check each chunk in this entry range
      for (var chunk = entry.firstChunk; chunk <= lastChunkForEntry; chunk++) {
        final samplesInChunk = entry.samplesPerChunk;
        if (currentSample + samplesInChunk > index) {
          // Sample is in this chunk
          final sampleWithinChunk = index - currentSample;
          final chunkOffset = chunkOffsets[chunk - 1]; // Convert to 0-based

          // Calculate byte offset within chunk
          var offsetInChunk = 0;
          for (var s = 0; s < sampleWithinChunk; s++) {
            offsetInChunk += sampleSizes[currentSample + s];
          }

          return SampleLocation(offset: chunkOffset + offsetInChunk, size: sampleSizes[index]);
        }
        currentSample += samplesInChunk;
      }
    }

    return null;
  }

  /// Finds the sample index containing the given timestamp.
  ///
  /// The [time] is in timescale units.
  /// If [preferKeyframe] is true, returns the nearest preceding keyframe.
  int findSampleAtTime(int time, {bool preferKeyframe = false}) {
    if (sttsEntries.isEmpty) return 0;

    var currentTime = 0;
    var sampleIndex = 0;

    for (final entry in sttsEntries) {
      final entryDuration = entry.sampleCount * entry.sampleDelta;
      if (currentTime + entryDuration > time) {
        // Time falls within this entry
        final samplesIn = (time - currentTime) ~/ entry.sampleDelta;
        sampleIndex += samplesIn;
        break;
      }
      currentTime += entryDuration;
      sampleIndex += entry.sampleCount;
    }

    // Clamp to valid range
    if (sampleIndex >= sampleCount) {
      sampleIndex = sampleCount - 1;
    }

    if (preferKeyframe && hasExplicitSyncSamples) {
      // Find nearest preceding keyframe
      return findNearestSyncSample(sampleIndex);
    }

    return sampleIndex;
  }

  /// Finds the nearest sync sample to [index].
  ///
  /// If [searchBackward] is true, searches for the nearest preceding sync sample.
  /// Otherwise, searches for the nearest following sync sample.
  int findNearestSyncSample(int index, {bool searchBackward = true}) {
    if (syncSamples.isEmpty) return index;

    // Convert to 1-based for comparison with stss
    final target = index + 1;

    if (searchBackward) {
      // Find largest sync sample <= target
      var result = syncSamples.first;
      for (final sync in syncSamples) {
        if (sync <= target) {
          result = sync;
        } else {
          break;
        }
      }
      return result - 1; // Convert back to 0-based
    } else {
      // Find smallest sync sample >= target
      for (final sync in syncSamples) {
        if (sync >= target) {
          return sync - 1;
        }
      }
      return syncSamples.last - 1;
    }
  }

  /// Creates a copy with modified fields.
  Mp4SampleTable copyWith({
    int? timescale,
    List<SttsEntry>? sttsEntries,
    List<StscEntry>? stscEntries,
    List<int>? chunkOffsets,
    List<int>? sampleSizes,
    List<int>? syncSamples,
    List<CttsEntry>? cttsEntries,
  }) => Mp4SampleTable(
    timescale: timescale ?? this.timescale,
    sttsEntries: sttsEntries ?? this.sttsEntries,
    stscEntries: stscEntries ?? this.stscEntries,
    chunkOffsets: chunkOffsets ?? this.chunkOffsets,
    sampleSizes: sampleSizes ?? this.sampleSizes,
    syncSamples: syncSamples ?? this.syncSamples,
    cttsEntries: cttsEntries ?? this.cttsEntries,
  );

  @override
  String toString() => 'Mp4SampleTable(samples: $sampleCount, chunks: $chunkCount, keyframes: ${syncSamples.length})';
}

/// Location of a sample within the file.
class SampleLocation {
  /// Creates a sample location.
  const SampleLocation({required this.offset, required this.size});

  /// Byte offset in the file.
  final int offset;

  /// Size in bytes.
  final int size;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SampleLocation && offset == other.offset && size == other.size;

  @override
  int get hashCode => Object.hash(offset, size);

  @override
  String toString() => 'SampleLocation(offset: $offset, size: $size)';
}
