import 'dart:typed_data';

import 'mp4_box_writer.dart';
import 'sample_reader.dart';
import 'segment_writer.dart';

/// Fragmented MP4 (fMP4) segment writer for HLS.
///
/// Generates init segments (ftyp + moov) and media segments (moof + mdat)
/// compatible with HLS fMP4 byte range or discrete segment modes.
///
/// Example:
/// ```dart
/// final writer = Fmp4SegmentWriter();
/// final init = writer.writeInitSegment(tracks);
/// final segment = writer.writeMediaSegment(
///   samples: samples,
///   sequenceNumber: 1,
///   baseDecodeTime: 0,
///   timescale: 90000,
/// );
/// ```
class Fmp4SegmentWriter implements SegmentWriter {
  /// Creates an fMP4 segment writer.
  const Fmp4SegmentWriter();

  @override
  Uint8List writeInitSegment(List<TrackCodecInfo> tracks) {
    final writer = Mp4BoxWriter();

    // ftyp box
    writer.writeFtyp(majorBrand: 'isom', minorVersion: 0x200, compatibleBrands: ['isom', 'iso6', 'mp41', 'dash']);

    // moov box
    writer.writeBox('moov', (moov) {
      // mvhd - movie header
      // Duration 0 for fragmented MP4 (duration in fragments)
      moov.writeMvhd(
        timescale: tracks.isNotEmpty ? tracks.first.timescale : 1000,
        duration: 0,
        nextTrackId: tracks.length + 1,
      );

      // Track boxes
      for (var i = 0; i < tracks.length; i++) {
        _writeTrack(moov, tracks[i]);
      }

      // mvex - movie extends (signals fragmentation)
      moov.writeBox('mvex', (mvex) {
        for (final track in tracks) {
          mvex.writeTrex(trackId: track.trackId);
        }
      });
    });

    return writer.toBytes();
  }

  void _writeTrack(Mp4BoxWriter moov, TrackCodecInfo track) {
    moov.writeBox('trak', (trak) {
      // tkhd - track header
      trak.writeTkhd(
        trackId: track.trackId,
        duration: 0, // Duration in fragments
        width: track.width,
        height: track.height,
        isAudio: track.isAudio,
      );

      // mdia - media container
      trak.writeBox('mdia', (mdia) {
        // mdhd - media header
        mdia.writeMdhd(timescale: track.timescale, duration: 0);

        // hdlr - handler reference
        mdia.writeHdlr(
          handlerType: track.isVideo ? 'vide' : (track.isAudio ? 'soun' : 'meta'),
          name: track.isVideo ? 'VideoHandler' : (track.isAudio ? 'SoundHandler' : 'DataHandler'),
        );

        // minf - media information
        mdia.writeBox('minf', (minf) {
          // Media header (vmhd for video, smhd for audio)
          if (track.isVideo) {
            minf.writeVmhd();
          } else if (track.isAudio) {
            minf.writeSmhd();
          }

          // dinf - data information
          minf.writeDinf();

          // stbl - sample table (empty for fMP4)
          minf.writeEmptyStbl(stsdContent: _buildSampleDescription(track));
        });
      });
    });
  }

  Uint8List _buildSampleDescription(TrackCodecInfo track) {
    final writer = Mp4BoxWriter();

    if (track.isVideo) {
      _writeVideoSampleEntry(writer, track);
    } else if (track.isAudio) {
      _writeAudioSampleEntry(writer, track);
    }

    return writer.toBytes();
  }

  void _writeVideoSampleEntry(Mp4BoxWriter writer, TrackCodecInfo track) {
    // avc1, hvc1, etc. sample entry
    writer.writeBox(track.codecFourcc, (entry) {
      entry.writeZeros(6); // reserved
      entry.writeUint16(1); // data_reference_index

      entry.writeUint16(0); // pre_defined
      entry.writeUint16(0); // reserved
      entry.writeZeros(12); // pre_defined

      entry.writeUint16(track.width ?? 0);
      entry.writeUint16(track.height ?? 0);

      entry.writeFixedPoint16_16(72); // horizresolution (72 dpi)
      entry.writeFixedPoint16_16(72); // vertresolution (72 dpi)

      entry.writeUint32(0); // reserved
      entry.writeUint16(1); // frame_count

      // Compressor name (32 bytes, first byte is length)
      entry.writeUint8(0); // empty compressor name
      entry.writeZeros(31);

      entry.writeUint16(0x0018); // depth (24-bit color)
      entry.writeInt16(-1); // pre_defined

      // Codec-specific box (avcC, hvcC, etc.)
      if (track.codecPrivateData != null && track.codecPrivateData!.isNotEmpty) {
        // The codecPrivateData should contain the complete box (avcC, hvcC, etc.)
        entry.writeBytes(track.codecPrivateData!);
      }
    });
  }

  void _writeAudioSampleEntry(Mp4BoxWriter writer, TrackCodecInfo track) {
    // mp4a sample entry
    writer.writeBox(track.codecFourcc, (entry) {
      entry.writeZeros(6); // reserved
      entry.writeUint16(1); // data_reference_index

      entry.writeUint32(0); // reserved
      entry.writeUint32(0); // reserved

      entry.writeUint16(track.channelCount ?? 2);
      entry.writeUint16(16); // sample_size (16-bit)
      entry.writeUint16(0); // pre_defined
      entry.writeUint16(0); // reserved

      // sample_rate as 16.16 fixed-point (only integer part used)
      entry.writeUint32((track.sampleRate ?? 44100) << 16);

      // esds or codec-specific box
      if (track.codecPrivateData != null && track.codecPrivateData!.isNotEmpty) {
        entry.writeBytes(track.codecPrivateData!);
      }
    });
  }

  @override
  Uint8List writeMediaSegment({
    required List<MediaSample> samples,
    required int sequenceNumber,
    required int baseDecodeTime,
    required int timescale,
  }) {
    if (samples.isEmpty) {
      return Uint8List(0);
    }

    // Group samples by track
    final samplesByTrack = <int, List<MediaSample>>{};
    for (final sample in samples) {
      samplesByTrack.putIfAbsent(sample.trackId, () => []).add(sample);
    }

    final writer = Mp4BoxWriter();

    // Build moof first to calculate data offset
    final moofWriter = Mp4BoxWriter();
    _writeMoof(moofWriter, samplesByTrack, sequenceNumber, baseDecodeTime);
    final moofBytes = moofWriter.toBytes();

    // Calculate data offset (from start of moof to start of mdat data)
    // moof size + mdat header (8 bytes)
    final dataOffset = moofBytes.length + 8;

    // Rebuild moof with correct data offset
    final finalMoofWriter = Mp4BoxWriter();
    _writeMoof(finalMoofWriter, samplesByTrack, sequenceNumber, baseDecodeTime, dataOffset: dataOffset);

    writer.writeBytes(finalMoofWriter.toBytes());

    // mdat box
    writer.writeBox('mdat', (mdat) {
      for (final sample in samples) {
        mdat.writeBytes(sample.data);
      }
    });

    return writer.toBytes();
  }

  void _writeMoof(
    Mp4BoxWriter writer,
    Map<int, List<MediaSample>> samplesByTrack,
    int sequenceNumber,
    int baseDecodeTime, {
    int? dataOffset,
  }) {
    writer.writeBox('moof', (moof) {
      moof.writeMfhd(sequenceNumber: sequenceNumber);

      var currentDataOffset = dataOffset;

      for (final entry in samplesByTrack.entries) {
        final trackId = entry.key;
        final trackSamples = entry.value;

        _writeTraf(moof, trackId, trackSamples, baseDecodeTime, currentDataOffset);

        // Update data offset for next track
        if (currentDataOffset != null) {
          var trackDataSize = 0;
          for (final sample in trackSamples) {
            trackDataSize += sample.size;
          }
          currentDataOffset += trackDataSize;
        }
      }
    });
  }

  void _writeTraf(Mp4BoxWriter moof, int trackId, List<MediaSample> samples, int baseDecodeTime, int? dataOffset) {
    moof.writeBox('traf', (traf) {
      // tfhd - track fragment header
      traf.writeTfhd(trackId: trackId);

      // tfdt - track fragment decode time
      traf.writeTfdt(baseMediaDecodeTime: baseDecodeTime);

      // trun - track fragment run
      final trunSamples = samples
          .map(
            (s) => TrunSample(
              duration: s.duration,
              size: s.size,
              flags: _getSampleFlags(s),
              compositionOffset: s.compositionTimestamp - s.decodeTimestamp,
            ),
          )
          .toList();

      traf.writeTrun(samples: trunSamples, dataOffset: dataOffset);
    });
  }

  int _getSampleFlags(MediaSample sample) {
    // ISO 14496-12 sample flags:
    // Bits 0-1: reserved
    // Bits 2-3: is_leading (0 = unknown)
    // Bits 4-5: sample_depends_on (1 = depends on others, 2 = does NOT depend)
    // Bits 6-7: sample_is_depended_on (0 = unknown)
    // Bits 8-9: sample_has_redundancy (0 = unknown)
    // Bits 10-15: sample_padding_value
    // Bit 16: sample_is_non_sync_sample
    // Bits 17-31: sample_degradation_priority

    if (sample.isKeyframe) {
      // Keyframe: does NOT depend on other samples, is sync sample
      return 0x02000000; // sample_depends_on = 2 (independent)
    } else {
      // Non-keyframe: depends on other samples, is NOT sync
      return 0x01010000; // sample_depends_on = 1, is_non_sync = 1
    }
  }

  @override
  Stream<MediaSegment> segmentStream({
    required Stream<MediaSample> samples,
    required List<TrackCodecInfo> tracks,
    required SegmentConfig config,
  }) async* {
    // Yield init segment first
    yield MediaSegment(data: writeInitSegment(tracks), index: 0, startTime: 0, duration: 0, isInitSegment: true);

    if (tracks.isEmpty) return;

    final timescale = tracks.first.timescale;
    final targetDurationUnits = (config.targetDuration.inMicroseconds / 1000000.0 * timescale).round();

    var segmentSamples = <MediaSample>[];
    var segmentIndex = 1;
    var segmentStartTime = 0;
    var segmentDuration = 0;
    var currentTime = 0;

    await for (final sample in samples) {
      final shouldStartNewSegment =
          segmentSamples.isNotEmpty &&
          segmentDuration >= targetDurationUnits &&
          (!config.alignToKeyframes || sample.isKeyframe);

      if (shouldStartNewSegment) {
        // Emit current segment
        yield MediaSegment(
          data: writeMediaSegment(
            samples: segmentSamples,
            sequenceNumber: segmentIndex,
            baseDecodeTime: segmentStartTime,
            timescale: timescale,
          ),
          index: segmentIndex,
          startTime: segmentStartTime / timescale,
          duration: segmentDuration / timescale,
          isInitSegment: false,
        );

        segmentIndex++;
        segmentSamples = [];
        segmentStartTime = currentTime;
        segmentDuration = 0;
      }

      segmentSamples.add(sample);
      segmentDuration += sample.duration;
      currentTime = sample.decodeTimestamp + sample.duration;
    }

    // Emit final segment
    if (segmentSamples.isNotEmpty) {
      yield MediaSegment(
        data: writeMediaSegment(
          samples: segmentSamples,
          sequenceNumber: segmentIndex,
          baseDecodeTime: segmentStartTime,
          timescale: timescale,
        ),
        index: segmentIndex,
        startTime: segmentStartTime / timescale,
        duration: segmentDuration / timescale,
        isInitSegment: false,
      );
    }
  }
}
