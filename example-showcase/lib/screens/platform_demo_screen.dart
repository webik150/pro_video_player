import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pro_video_player/pro_video_player.dart';

import '../constants/video_constants.dart';
import '../widgets/responsive_video_layout.dart';

/// Screen demonstrating platform-specific features and detection.
class PlatformDemoScreen extends StatefulWidget {
  const PlatformDemoScreen({super.key});

  @override
  State<PlatformDemoScreen> createState() => _PlatformDemoScreenState();
}

class _PlatformDemoScreenState extends State<PlatformDemoScreen> {
  late ProVideoPlayerController _controller;
  String _currentPlatform = '';
  bool _pipSupported = false;

  @override
  void initState() {
    super.initState();

    // Enable verbose logging to debug initialization timing
    unawaited(ProVideoPlayerLogger.setVerboseLogging(enabled: true));

    _controller = ProVideoPlayerController();
    _detectPlatform();

    // Defer until after first frame to avoid blocking the screen transition
    // Native iOS AVPlayer initialization now runs on a background thread
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        debugPrint('🎬 [Flutter] Starting PiP check and player initialization');
        unawaited(_checkPipSupport());
        unawaited(_initializePlayer());
      }
    });
  }

  void _detectPlatform() {
    if (kIsWeb) {
      _currentPlatform = 'Web';
    } else if (Platform.isIOS) {
      _currentPlatform = 'iOS';
    } else if (Platform.isAndroid) {
      _currentPlatform = 'Android';
    } else if (Platform.isMacOS) {
      _currentPlatform = 'macOS';
    } else if (Platform.isWindows) {
      _currentPlatform = 'Windows';
    } else if (Platform.isLinux) {
      _currentPlatform = 'Linux';
    } else {
      _currentPlatform = 'Unknown';
    }
  }

  Future<void> _checkPipSupport() async {
    try {
      final supported = await _controller.isPipSupported();
      if (mounted) {
        setState(() => _pipSupported = supported);
      }
    } catch (e) {
      // PiP support check failed
      if (mounted) {
        setState(() => _pipSupported = false);
      }
    }
  }

  Future<void> _initializePlayer() async {
    try {
      await _controller.initialize(
        source: const VideoSource.network(VideoUrls.bigBuckBunny),
        options: const VideoPlayerOptions(autoPlay: true, looping: true),
      );
    } catch (e) {
      debugPrint('Failed to initialize player: $e');
    }
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Platform Demo')),
    body: ResponsiveVideoLayout(
      videoPlayer: ProVideoPlayer(
        controller: _controller,
        controlsBuilder: (context, controller) =>
            VideoPlayerControls(controller: controller, theme: VideoPlayerTheme.dark()),
      ),
      controls: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Platform Information
          _buildInfoCard('Platform Information', [
            _buildInfoRow('Current Platform', _currentPlatform, _getPlatformIcon()),
            _buildInfoRow('Web Platform', kIsWeb ? 'Yes' : 'No', kIsWeb ? Icons.check_circle : Icons.cancel),
            _buildInfoRow(
              'Mobile Platform',
              _isMobile() ? 'Yes' : 'No',
              _isMobile() ? Icons.check_circle : Icons.cancel,
            ),
            _buildInfoRow(
              'Desktop Platform',
              _isDesktop() ? 'Yes' : 'No',
              _isDesktop() ? Icons.check_circle : Icons.cancel,
            ),
          ]),

          // Feature Support
          _buildInfoCard('Feature Support', [
            _buildInfoRow(
              'Picture-in-Picture',
              _pipSupported ? 'Supported' : 'Not Supported',
              _pipSupported ? Icons.check_circle : Icons.cancel,
            ),
            _buildInfoRow(
              'Background Playback',
              _supportsBackgroundPlayback() ? 'Supported' : 'Not Supported',
              _supportsBackgroundPlayback() ? Icons.check_circle : Icons.cancel,
            ),
            _buildInfoRow('Fullscreen', 'Supported', Icons.check_circle),
            _buildInfoRow('Subtitles', 'Supported', Icons.check_circle),
            _buildInfoRow('Playback Speed', 'Supported', Icons.check_circle),
          ]),

          // Platform-Specific Notes
          _buildNotesCard(),
        ],
      ),
    ),
  );

  Widget _buildInfoCard(String title, List<Widget> children) => Card(
    margin: const EdgeInsets.all(16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
          ...children,
        ],
      ),
    ),
  );

  Widget _buildInfoRow(String label, String value, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(icon, size: 20, color: icon == Icons.check_circle ? Colors.green : Colors.red),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
        Text(value, style: const TextStyle(color: Colors.grey)),
      ],
    ),
  );

  Widget _buildNotesCard() {
    final notes = _getPlatformNotes();
    if (notes.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Platform Notes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...notes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(left: 28, top: 4),
                child: Text('• $note', style: TextStyle(color: Colors.blue[900])),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPlatformIcon() {
    if (kIsWeb) return Icons.language;
    if (!kIsWeb && Platform.isIOS) return Icons.phone_iphone;
    if (!kIsWeb && Platform.isAndroid) return Icons.phone_android;
    if (!kIsWeb && Platform.isMacOS) return Icons.laptop_mac;
    if (!kIsWeb && Platform.isWindows) return Icons.desktop_windows;
    if (!kIsWeb && Platform.isLinux) return Icons.computer;
    return Icons.device_unknown;
  }

  bool _isMobile() {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isAndroid;
  }

  bool _isDesktop() {
    if (kIsWeb) return false;
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }

  bool _supportsBackgroundPlayback() {
    if (kIsWeb) return false;
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid || Platform.isMacOS)) return true;
    return false;
  }

  List<String> _getPlatformNotes() {
    if (kIsWeb) {
      return [
        'HTML5 VideoElement used for playback',
        'PiP supported in compatible browsers (Chrome, Edge, Safari)',
        'Background playback not supported (browser limitation)',
        'Video format support depends on browser',
      ];
    } else if (!kIsWeb && Platform.isIOS) {
      return [
        'Uses AVPlayer for native playback',
        'True video-only PiP (video floats independently)',
        'Background playback requires audio background mode',
      ];
    } else if (!kIsWeb && Platform.isAndroid) {
      return [
        'Uses ExoPlayer for native playback',
        'Activity-level PiP mode',
        'Background playback with foreground service notification',
      ];
    } else if (!kIsWeb && Platform.isMacOS) {
      return ['Uses AVPlayer (same as iOS)', 'PiP supported on macOS 10.12+', 'Full feature parity with iOS'];
    } else if (!kIsWeb && Platform.isWindows) {
      return [
        'Uses Media Foundation (native implementation in progress)',
        'Dart-side implementation complete',
        'Native C++ code needed for full functionality',
        'PiP not supported on Windows',
      ];
    } else if (!kIsWeb && Platform.isLinux) {
      return [
        'Uses GStreamer (native implementation in progress)',
        'Dart-side implementation complete',
        'Native C++ code needed for full functionality',
        'PiP not typically supported on Linux',
      ];
    }
    return [];
  }
}
