import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

import '../pro_video_player_controller.dart';
import '../video_player_theme.dart';
import 'controls_enums.dart';
import 'widgets/progress_bar_track.dart';

/// A video player progress bar with seek functionality.
///
/// This widget provides:
/// - Visual progress indication (played, buffered, inactive)
/// - Interactive seeking via tap or drag
/// - Position indicator circle
/// - Hover preview (desktop/web)
/// - Live scrubbing support
///
/// Example:
/// ```dart
/// ProgressBar(
///   controller: videoController,
///   theme: VideoPlayerTheme.light(),
///   liveScrubbingMode: LiveScrubbingMode.adaptive,
///   enableSeekBarHoverPreview: true,
/// )
/// ```
class ProgressBar extends StatefulWidget {
  /// Creates a progress bar widget.
  ///
  /// The [controller] must be initialized before the widget is built.
  /// The [theme] defines the visual appearance.
  const ProgressBar({
    required this.controller,
    required this.theme,
    this.liveScrubbingMode = LiveScrubbingMode.adaptive,
    this.enableSeekBarHoverPreview = true,
    this.focusNode,
    this.onKeyboardInteraction,
    this.onDragStart,
    this.onDragEnd,
    super.key,
  });

  /// The video player controller.
  final ProVideoPlayerController controller;

  /// The theme for styling the progress bar.
  final VideoPlayerTheme theme;

  /// Live scrubbing mode for real-time seeking during drag.
  final LiveScrubbingMode liveScrubbingMode;

  /// Whether to show hover preview on desktop/web.
  final bool enableSeekBarHoverPreview;

  /// Optional focus node for keyboard and TV-remote seeking.
  final FocusNode? focusNode;

  /// Called when keyboard input interacts with the seek bar.
  final VoidCallback? onKeyboardInteraction;

  /// Called when drag starts (optional, for parent state coordination).
  final VoidCallback? onDragStart;

  /// Called when drag ends (optional, for parent state coordination).
  final VoidCallback? onDragEnd;

  @override
  State<ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<ProgressBar> {
  // Drag state
  bool _isDragging = false;
  double? _dragProgress;
  DateTime? _lastLiveSeekTime;
  bool _hasFocus = false;

  // Hover state (desktop/web)
  double? _seekBarHoverProgress;

  bool get _isDesktopPlatform =>
      !kIsWeb &&
          (Theme.of(context).platform == TargetPlatform.macOS ||
              Theme.of(context).platform == TargetPlatform.windows ||
              Theme.of(context).platform == TargetPlatform.linux) ||
      kIsWeb;

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
        (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
            event.logicalKey == LogicalKeyboardKey.arrowRight)) {
      widget.onKeyboardInteraction?.call();
      final currentPosition = widget.controller.value.position;
      final duration = widget.controller.value.duration;
      final offset = event.logicalKey == LogicalKeyboardKey.arrowLeft
          ? const Duration(seconds: -10)
          : const Duration(seconds: 10);
      final targetPosition = currentPosition + offset;
      unawaited(
        widget.controller.seekTo(
          targetPosition < Duration.zero
              ? Duration.zero
              : targetPosition > duration
              ? duration
              : targetPosition,
        ),
      );
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// Determines whether live scrubbing should be enabled based on the current mode,
  /// video source type, and target position.
  bool _shouldLiveScrub(Duration targetPosition) {
    final mode = widget.liveScrubbingMode;

    // Disabled mode: never live scrub
    if (mode == LiveScrubbingMode.disabled) {
      return false;
    }

    // Always mode: always live scrub regardless of source
    if (mode == LiveScrubbingMode.always) {
      return true;
    }

    // For localOnly and adaptive modes, check if source is local
    final source = widget.controller.source;
    if (source == null) return false;

    final isLocal = source is FileVideoSource || source is AssetVideoSource;

    // LocalOnly mode: only scrub for local files
    if (mode == LiveScrubbingMode.localOnly) {
      return isLocal;
    }

    // Adaptive mode: local files always scrub, network files only if not buffering
    if (mode == LiveScrubbingMode.adaptive) {
      if (isLocal) return true;

      // For network sources, only live scrub if not buffering
      // This avoids excessive seeking that could cause rebuffering
      return widget.controller.value.playbackState != PlaybackState.buffering;
    }

    return false;
  }

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<VideoPlayerValue>(
    valueListenable: widget.controller,
    builder: (context, value, child) {
      final position = value.position;
      final duration = value.duration;
      final progress = duration.inMilliseconds > 0
          ? position.inMilliseconds / duration.inMilliseconds
          : 0.0;
      final bufferedProgress = duration.inMilliseconds > 0
          ? value.bufferedPosition.inMilliseconds / duration.inMilliseconds
          : 0.0;
      final displayProgress = _isDragging && _dragProgress != null
          ? _dragProgress!
          : progress;

      return Focus(
        focusNode: widget.focusNode,
        onFocusChange: (hasFocus) {
          if (_hasFocus != hasFocus) {
            setState(() => _hasFocus = hasFocus);
          }
        },
        onKeyEvent: _handleKeyEvent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: 20,
          decoration: BoxDecoration(
            border: _hasFocus
                ? Border.all(color: widget.theme.progressBarActiveColor)
                : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = constraints.maxWidth;
              // Calculate indicator position, clamping to keep circle fully visible
              // Circle is 12px wide, so valid range is 0 to (barWidth - 12)
              final rawPosition =
                  displayProgress.clamp(0.0, 1.0) * barWidth - 6;
              final indicatorPosition = rawPosition.clamp(0.0, barWidth - 12);

              return Stack(
                alignment: Alignment.center,
                children: [
                  // Progress bar container
                  ProgressBarTrack(
                    theme: widget.theme,
                    bufferedProgress: bufferedProgress,
                    displayProgress: displayProgress,
                  ),
                  // Position indicator circle
                  Positioned(
                    left: indicatorPosition,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: widget.theme.progressBarActiveColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Hover preview tooltip (desktop/web only, not while dragging)
                  if (_isDesktopPlatform &&
                      widget.enableSeekBarHoverPreview &&
                      _seekBarHoverProgress != null &&
                      !_isDragging)
                    Positioned(
                      left: (_seekBarHoverProgress! * barWidth - 30).clamp(
                        0.0,
                        barWidth - 60,
                      ),
                      bottom: 24,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatDuration(
                            Duration(
                              milliseconds:
                                  (_seekBarHoverProgress! *
                                          duration.inMilliseconds)
                                      .round(),
                            ),
                          ),
                          style: TextStyle(
                            color: widget.theme.primaryColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  // Drag preview tooltip (shown during seek gesture)
                  if (_isDragging && _dragProgress != null)
                    Positioned(
                      left: (_dragProgress! * barWidth - 30).clamp(
                        0.0,
                        barWidth - 60,
                      ),
                      bottom: 24,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: widget.theme.progressBarActiveColor,
                          ),
                        ),
                        child: Text(
                          _formatDuration(
                            Duration(
                              milliseconds:
                                  (_dragProgress! * duration.inMilliseconds)
                                      .round(),
                            ),
                          ),
                          style: TextStyle(
                            color: widget.theme.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // Interactive overlay for seeking
                  Positioned.fill(
                    child: MouseRegion(
                      onHover:
                          _isDesktopPlatform && widget.enableSeekBarHoverPreview
                          ? (event) {
                              setState(() {
                                _seekBarHoverProgress =
                                    (event.localPosition.dx / barWidth).clamp(
                                      0.0,
                                      1.0,
                                    );
                              });
                            }
                          : null,
                      onExit:
                          _isDesktopPlatform && widget.enableSeekBarHoverPreview
                          ? (_) {
                              setState(() {
                                _seekBarHoverProgress = null;
                              });
                            }
                          : null,
                      child: GestureDetector(
                        onTapDown: (details) {
                          if (duration.inMilliseconds <= 0) return;
                          final localX = details.localPosition.dx;
                          final newProgress = (localX / barWidth).clamp(
                            0.0,
                            1.0,
                          );
                          final newPosition = Duration(
                            milliseconds:
                                (newProgress * duration.inMilliseconds).round(),
                          );
                          unawaited(widget.controller.seekTo(newPosition));
                        },
                        onHorizontalDragStart: (details) {
                          if (duration.inMilliseconds <= 0) return;
                          setState(() {
                            _isDragging = true;
                            final localX = details.localPosition.dx;
                            _dragProgress = (localX / barWidth).clamp(0.0, 1.0);
                          });
                          widget.onDragStart?.call();
                        },
                        onHorizontalDragUpdate: (details) {
                          if (duration.inMilliseconds <= 0) return;
                          setState(() {
                            final localX = details.localPosition.dx;
                            _dragProgress = (localX / barWidth).clamp(0.0, 1.0);
                          });

                          // Live scrubbing: seek during drag based on mode
                          if (_dragProgress != null) {
                            final newPosition = Duration(
                              milliseconds:
                                  (_dragProgress! * duration.inMilliseconds)
                                      .round(),
                            );

                            if (_shouldLiveScrub(newPosition)) {
                              final now = DateTime.now();
                              // Throttle to ~50ms to avoid excessive seek calls
                              if (_lastLiveSeekTime == null ||
                                  now
                                          .difference(_lastLiveSeekTime!)
                                          .inMilliseconds >=
                                      50) {
                                unawaited(
                                  widget.controller.seekTo(newPosition),
                                );
                                _lastLiveSeekTime = now;
                              }
                            }
                          }
                        },
                        onHorizontalDragEnd: (details) {
                          if (_dragProgress != null &&
                              duration.inMilliseconds > 0) {
                            final newPosition = Duration(
                              milliseconds:
                                  (_dragProgress! * duration.inMilliseconds)
                                      .round(),
                            );
                            unawaited(widget.controller.seekTo(newPosition));
                          }
                          setState(() {
                            _isDragging = false;
                            _dragProgress = null;
                            _lastLiveSeekTime = null;
                          });
                          widget.onDragEnd?.call();
                        },
                        onHorizontalDragCancel: () {
                          setState(() {
                            _isDragging = false;
                            _dragProgress = null;
                            _lastLiveSeekTime = null;
                          });
                          widget.onDragEnd?.call();
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );

  /// Formats a duration as MM:SS or HH:MM:SS.
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(1, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
