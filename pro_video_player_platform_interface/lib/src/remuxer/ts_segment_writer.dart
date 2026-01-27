import 'dart:typed_data';

import 'sample_reader.dart';
import 'segment_writer.dart';
import 'ts_packet_writer.dart';

/// Writes MPEG-TS segments for HLS.
///
/// MPEG-TS is the legacy format for HLS segments, supported by
/// all HLS players. It's less efficient than fMP4 but has
/// broader compatibility.
class TsSegmentWriter {
  /// Creates a TS segment writer.
  const TsSegmentWriter();

  /// Writes a TS segment containing the given samples.
  ///
  /// [samples] are the media samples to include.
  /// [videoTrackId] identifies which samples are video.
  /// [audioTrackId] identifies which samples are audio.
  /// [videoCodec] is the video codec fourcc (e.g., 'avc1', 'hvc1').
  /// [audioCodec] is the audio codec fourcc (e.g., 'mp4a').
  /// [audioSampleRate] is required for AAC ADTS header generation.
  /// [audioChannelCount] is required for AAC ADTS header generation.
  /// [nalLengthSize] is the NAL length field size (typically 4 for AVC/HEVC).
  /// [segmentIndex] is used for continuity counter calculation.
  Uint8List writeSegment({
    required List<MediaSample> samples,
    required int videoTrackId,
    required String videoCodec,
    int? audioTrackId,
    String? audioCodec,
    int? audioSampleRate,
    int? audioChannelCount,
    int nalLengthSize = 4,
    int segmentIndex = 0,
  }) {
    final packets = <Uint8List>[];

    // Track continuity counters
    final patCc = (segmentIndex * 2) & 0x0F;
    final pmtCc = (segmentIndex * 2) & 0x0F;
    var videoCc = 0;
    var audioCc = 0;

    // Determine stream types
    final videoStreamType = _getVideoStreamType(videoCodec);
    final audioStreamType = audioCodec != null ? _getAudioStreamType(audioCodec) : null;

    // Write PAT
    packets.add(TsPacketWriter.writePat(continuityCounter: patCc));

    // Write PMT
    final streams = <TsStreamInfo>[TsStreamInfo(streamType: videoStreamType, pid: TsPacketWriter.videoPid)];

    if (audioTrackId != null && audioStreamType != null) {
      streams.add(TsStreamInfo(streamType: audioStreamType, pid: TsPacketWriter.audioPid));
    }

    packets.add(TsPacketWriter.writePmt(streams: streams, continuityCounter: pmtCc));

    // Process samples
    for (final sample in samples) {
      if (sample.trackId == videoTrackId) {
        // Video sample
        final pesPackets = _writeVideoSample(
          sample: sample,
          codec: videoCodec,
          nalLengthSize: nalLengthSize,
          continuityCounter: videoCc,
          isFirstInSegment: videoCc == 0,
        );
        packets.addAll(pesPackets);
        videoCc = (videoCc + pesPackets.length) & 0x0F;
      } else if (audioTrackId != null && sample.trackId == audioTrackId) {
        // Audio sample
        final pesPackets = _writeAudioSample(
          sample: sample,
          codec: audioCodec!,
          sampleRate: audioSampleRate ?? 44100,
          channelCount: audioChannelCount ?? 2,
          continuityCounter: audioCc,
        );
        packets.addAll(pesPackets);
        audioCc = (audioCc + pesPackets.length) & 0x0F;
      }
    }

    // Concatenate all packets
    final result = Uint8List(packets.length * TsPacketWriter.packetSize);
    for (var i = 0; i < packets.length; i++) {
      result.setRange(i * TsPacketWriter.packetSize, (i + 1) * TsPacketWriter.packetSize, packets[i]);
    }

    return result;
  }

  /// Generates a stream of TS segments from samples.
  ///
  /// Similar to fMP4 segment streaming but for TS output.
  Stream<MediaSegment> segmentStream({
    required Stream<MediaSample> samples,
    required int videoTrackId,
    required String videoCodec,
    int? audioTrackId,
    String? audioCodec,
    int? audioSampleRate,
    int? audioChannelCount,
    int nalLengthSize = 4,
    SegmentConfig config = const SegmentConfig(),
  }) async* {
    final segmentSamples = <MediaSample>[];
    var segmentStartTime = 0;
    var segmentIndex = 0;
    var lastKeyframeTime = 0;

    await for (final sample in samples) {
      // Only consider video samples for segmentation
      if (sample.trackId == videoTrackId) {
        final sampleTime = sample.decodeTimestamp;

        // Check if we should start a new segment
        if (segmentSamples.isNotEmpty) {
          final segmentDuration = sampleTime - segmentStartTime;

          // Start new segment if we have a keyframe at or after target duration
          final shouldSegment =
              sample.isKeyframe &&
              (config.alignToKeyframes
                  ? segmentDuration >= config.targetDuration.inMicroseconds
                  : sampleTime - lastKeyframeTime >= config.targetDuration.inMicroseconds);

          if (shouldSegment) {
            // Write current segment
            yield _createSegment(
              samples: segmentSamples,
              videoTrackId: videoTrackId,
              audioTrackId: audioTrackId,
              videoCodec: videoCodec,
              audioCodec: audioCodec,
              audioSampleRate: audioSampleRate,
              audioChannelCount: audioChannelCount,
              nalLengthSize: nalLengthSize,
              segmentIndex: segmentIndex,
              startTime: Duration(microseconds: segmentStartTime),
            );

            segmentIndex++;
            segmentSamples.clear();
            segmentStartTime = sampleTime;
          }
        }

        if (sample.isKeyframe) {
          lastKeyframeTime = sampleTime;
        }
      }

      segmentSamples.add(sample);
    }

    // Write final segment
    if (segmentSamples.isNotEmpty) {
      yield _createSegment(
        samples: segmentSamples,
        videoTrackId: videoTrackId,
        audioTrackId: audioTrackId,
        videoCodec: videoCodec,
        audioCodec: audioCodec,
        audioSampleRate: audioSampleRate,
        audioChannelCount: audioChannelCount,
        nalLengthSize: nalLengthSize,
        segmentIndex: segmentIndex,
        startTime: Duration(microseconds: segmentStartTime),
      );
    }
  }

  MediaSegment _createSegment({
    required List<MediaSample> samples,
    required int videoTrackId,
    required String videoCodec,
    required int nalLengthSize,
    required int segmentIndex,
    required Duration startTime,
    int? audioTrackId,
    String? audioCodec,
    int? audioSampleRate,
    int? audioChannelCount,
  }) {
    final data = writeSegment(
      samples: samples,
      videoTrackId: videoTrackId,
      audioTrackId: audioTrackId,
      videoCodec: videoCodec,
      audioCodec: audioCodec,
      audioSampleRate: audioSampleRate,
      audioChannelCount: audioChannelCount,
      nalLengthSize: nalLengthSize,
      segmentIndex: segmentIndex,
    );

    // Calculate duration from samples
    final videoSamples = samples.where((s) => s.trackId == videoTrackId).toList();
    Duration duration;
    if (videoSamples.isNotEmpty) {
      final lastSample = videoSamples.last;
      final firstTime = videoSamples.first.decodeTimestamp;
      final lastTime = lastSample.decodeTimestamp + lastSample.duration;
      duration = Duration(microseconds: lastTime - firstTime);
    } else {
      duration = Duration.zero;
    }

    return MediaSegment(
      index: segmentIndex + 1, // 1-based index
      data: data,
      duration: duration.inMicroseconds / 1000000.0,
      startTime: startTime.inMicroseconds / 1000000.0,
      isInitSegment: false,
    );
  }

  List<Uint8List> _writeVideoSample({
    required MediaSample sample,
    required String codec,
    required int nalLengthSize,
    required int continuityCounter,
    required bool isFirstInSegment,
  }) {
    // Convert sample data to Annex B format
    final annexBData = TsPacketWriter.convertAvcToAnnexB(sample.data, nalLengthSize);

    // Convert timestamps to 90kHz PTS/DTS
    // Assuming timescale is in microseconds, convert to 90kHz
    final pts = (sample.compositionTimestamp * 90) ~/ 1000;
    final dts = (sample.decodeTimestamp * 90) ~/ 1000;

    // Create PES header
    final pesHeader = TsPacketWriter.writePesHeader(
      streamId: PesStreamId.video(0),
      dataLength: annexBData.length,
      pts: pts,
      dts: pts != dts ? dts : null,
    );

    // Combine PES header and data
    final pesPacket = Uint8List(pesHeader.length + annexBData.length);
    pesPacket.setRange(0, pesHeader.length, pesHeader);
    pesPacket.setRange(pesHeader.length, pesPacket.length, annexBData);

    // Packetize into TS packets
    return TsPacketWriter.packetize(
      pid: TsPacketWriter.videoPid,
      data: pesPacket,
      isPayloadStart: true,
      continuityCounter: continuityCounter,
      pcr: isFirstInSegment && sample.isKeyframe ? dts : null,
    );
  }

  List<Uint8List> _writeAudioSample({
    required MediaSample sample,
    required String codec,
    required int sampleRate,
    required int channelCount,
    required int continuityCounter,
  }) {
    Uint8List audioData;

    // Add ADTS header for AAC
    if (codec == 'mp4a') {
      final adtsHeader = TsPacketWriter.createAdtsHeader(
        sampleRate: sampleRate,
        channelCount: channelCount,
        frameLength: sample.data.length,
      );
      audioData = Uint8List(adtsHeader.length + sample.data.length);
      audioData.setRange(0, adtsHeader.length, adtsHeader);
      audioData.setRange(adtsHeader.length, audioData.length, sample.data);
    } else {
      // For AC-3/E-AC-3, use raw data
      audioData = sample.data;
    }

    // Convert timestamps to 90kHz
    final pts = (sample.compositionTimestamp * 90) ~/ 1000;

    // Create PES header
    final pesHeader = TsPacketWriter.writePesHeader(
      streamId: codec == 'ac-3' || codec == 'ec-3' ? PesStreamId.privateStream1 : PesStreamId.audio(0),
      dataLength: audioData.length,
      pts: pts,
    );

    // Combine PES header and data
    final pesPacket = Uint8List(pesHeader.length + audioData.length);
    pesPacket.setRange(0, pesHeader.length, pesHeader);
    pesPacket.setRange(pesHeader.length, pesPacket.length, audioData);

    // Packetize into TS packets
    return TsPacketWriter.packetize(
      pid: TsPacketWriter.audioPid,
      data: pesPacket,
      isPayloadStart: true,
      continuityCounter: continuityCounter,
    );
  }

  int _getVideoStreamType(String codec) {
    switch (codec) {
      case 'avc1':
      case 'avc3':
        return TsPacketWriter.streamTypeAvc;
      case 'hvc1':
      case 'hev1':
        return TsPacketWriter.streamTypeHevc;
      default:
        return TsPacketWriter.streamTypeAvc; // Default to AVC
    }
  }

  int _getAudioStreamType(String codec) {
    switch (codec) {
      case 'mp4a':
        return TsPacketWriter.streamTypeAacAdts;
      case 'ac-3':
      case 'ec-3':
        return TsPacketWriter.streamTypeAc3;
      default:
        return TsPacketWriter.streamTypeAacAdts; // Default to AAC
    }
  }
}
