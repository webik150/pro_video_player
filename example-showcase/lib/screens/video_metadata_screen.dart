import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pro_video_player/pro_video_player.dart';

import '../constants/video_constants.dart';
import '../test_keys.dart';
import '../widgets/responsive_video_layout.dart';

class VideoMetadataScreen extends StatefulWidget {
  const VideoMetadataScreen({super.key});
  @override
  State<VideoMetadataScreen> createState() => _VideoMetadataScreenState();
}

class _VideoMetadataScreenState extends State<VideoMetadataScreen> {
  late ProVideoPlayerController _controller;
  bool _isInitialized = false;
  String? _error;
  String? _fingerprintResult;
  bool _isExtractingFingerprint = false;

  @override
  void initState() {
    super.initState();
    _controller = ProVideoPlayerController();
    unawaited(_initializePlayer());
  }

  Future<void> _initializePlayer() async {
    try {
      await _controller.initialize(
        source: const VideoSource.network(VideoUrls.bitmovinSintelHls),
        options: const VideoPlayerOptions(autoPlay: true),
      );
      _controller.addListener(_onUpdate);
      setState(() => _isInitialized = true);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _extractFingerprint() async {
    setState(() {
      _isExtractingFingerprint = true;
      _fingerprintResult = null;
    });

    try {
      const source = VideoSource.network(VideoUrls.bitmovinSintelHls);
      final stopwatch = Stopwatch()..start();
      final fingerprint = await ProVideoPlayerController.extractContentFingerprint(source);
      stopwatch.stop();

      setState(() {
        _fingerprintResult =
            'Fingerprint: ${fingerprint.fingerprint.substring(0, 16)}...\n'
            'File size: ${fingerprint.fileSize != null ? "${(fingerprint.fileSize! / 1024 / 1024).toStringAsFixed(2)} MB" : "Unknown"}\n'
            'Time: ${stopwatch.elapsedMilliseconds}ms';
        _isExtractingFingerprint = false;
      });
    } on ContentFingerprintException catch (e) {
      setState(() {
        _fingerprintResult = 'Error: ${e.code} - ${e.message}';
        _isExtractingFingerprint = false;
      });
    } catch (e) {
      setState(() {
        _fingerprintResult = 'Error: $e';
        _isExtractingFingerprint = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onUpdate);
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Video Metadata')),
    body: _error != null
        ? Center(child: Text('Error: $_error'))
        : !_isInitialized
        ? const Center(child: CircularProgressIndicator())
        : _buildContent(),
  );

  Widget _buildContent() => ResponsiveVideoLayout(
    videoPlayer: ProVideoPlayer(key: TestKeys.videoMetadataVideoPlayer, controller: _controller),
    controls: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_buildMetadataSection(), _buildFingerprintSection()],
      ),
    ),
    maxVideoHeightFraction: 0.35,
  );

  Widget _buildMetadataSection() => Padding(
    key: TestKeys.videoMetadataInfoSection,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Video Metadata', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        if (_controller.videoMetadata == null) const Text('Waiting...') else _buildMetadataGrid(),
      ],
    ),
  );

  Widget _buildMetadataGrid() {
    final m = _controller.videoMetadata!;
    return Column(
      children: [
        _MetadataRow(icon: Icons.videocam, label: 'Video Codec', value: m.videoCodec ?? 'Unknown'),
        _MetadataRow(icon: Icons.audiotrack, label: 'Audio Codec', value: m.audioCodec ?? 'Unknown'),
        _MetadataRow(icon: Icons.aspect_ratio, label: 'Resolution', value: m.resolution ?? 'Unknown'),
        _MetadataRow(icon: Icons.folder, label: 'Container', value: m.containerFormat ?? 'Unknown'),
        _MetadataRow(icon: Icons.high_quality, label: 'Quality', value: m.isHD ? 'HD' : 'SD'),
      ],
    );
  }

  Widget _buildFingerprintSection() => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Text('Content Fingerprint Benchmark', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
          'Extracts 8KB samples from 3 positions (start, middle, end) and computes SHA-256 hash.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _isExtractingFingerprint ? null : _extractFingerprint,
          icon: _isExtractingFingerprint
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.fingerprint),
          label: Text(_isExtractingFingerprint ? 'Extracting...' : 'Extract Fingerprint'),
        ),
        if (_fingerprintResult != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_fingerprintResult!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
        ],
      ],
    ),
  );
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        Text(value),
      ],
    ),
  );
}
