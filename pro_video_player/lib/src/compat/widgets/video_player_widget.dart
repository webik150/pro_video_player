/// VideoPlayer widget for video_player API compatibility.
///
/// This widget provides the exact video_player API signature for compatibility.
/// Import via `package:pro_video_player/video_player_compat.dart` for drop-in replacement.
library;

import 'package:flutter/material.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

import '../compat_annotation.dart';
import '../video_player_controller.dart';

/// Widget that displays the video controlled by [controller].
///
/// [video_player compatibility] This widget matches the video_player API exactly.
/// It takes only a controller, unlike pro_video_player's ProVideoPlayer which
/// has additional options.
@videoPlayerCompat
class VideoPlayer extends StatelessWidget {
  /// Creates a video player widget.
  ///
  /// [video_player compatibility] This constructor matches video_player exactly.
  const VideoPlayer(this.controller, {super.key});

  /// The controller for the video being rendered.
  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: controller,
    builder: (context, value, child) {
      final playerId = controller.proController.playerId;
      if (playerId == null || !value.isInitialized) {
        return const SizedBox.shrink();
      }

      return ProVideoPlayerPlatform.instance.buildView(playerId);
    },
  );
}
