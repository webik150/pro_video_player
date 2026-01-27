import 'package:flutter/material.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

import 'pro_video_player_controller.dart';

/// A widget that renders subtitle text over the video player.
///
/// This overlay displays subtitle cues synchronized with the current playback
/// position. It supports two subtitle sources:
///
/// 1. **External subtitles** - Loaded from external URLs (SRT, VTT, etc.)
/// 2. **Embedded subtitles** - When subtitle render mode is set to [SubtitleRenderMode.flutter],
///    embedded subtitle cues are streamed from the native player
///    and rendered here instead of by the native platform.
///
/// The overlay uses [SubtitleStyle] for customizable appearance.
///
/// Example:
/// ```dart
/// Stack(
///   children: [
///     VideoPlayerView(controller: controller),
///     SubtitleOverlay(
///       controller: controller,
///       style: SubtitleStyle(
///         fontSize: 20.0,
///         textColor: Colors.yellow,
///         position: SubtitlePosition.bottom,
///         strokeColor: Colors.black,
///         strokeWidth: 2.0,
///       ),
///     ),
///   ],
/// )
/// ```
class SubtitleOverlay extends StatefulWidget {
  /// Creates a subtitle overlay widget.
  ///
  /// The [controller] is used to access the selected subtitle track
  /// and current playback position.
  ///
  /// The [style] parameter allows comprehensive customization of subtitle
  /// appearance including text styling, positioning, and container styling.
  const SubtitleOverlay({required this.controller, super.key, this.style});

  /// The video player controller.
  final ProVideoPlayerController controller;

  /// The subtitle styling configuration.
  ///
  /// See [SubtitleStyle] for available customization options.
  final SubtitleStyle? style;

  @override
  State<SubtitleOverlay> createState() => _SubtitleOverlayState();
}

class _SubtitleOverlayState extends State<SubtitleOverlay> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(SubtitleOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;
    final selectedTrack = value.selectedSubtitleTrack;

    // No subtitle track selected
    if (selectedTrack == null) {
      return const SizedBox.shrink();
    }

    // Use LayoutBuilder to get player dimensions for responsive font sizing
    return LayoutBuilder(
      builder: (context, constraints) {
        final playerHeight = constraints.maxHeight;

        // Check if this is an embedded track with a current cue to render
        if (selectedTrack is! ExternalSubtitleTrack) {
          // For embedded tracks in Flutter mode, use extracted cues if available
          final extractedCues = value.embeddedSubtitleCues;
          if (extractedCues != null && extractedCues.isNotEmpty) {
            // Use extracted cues (same logic as external tracks)
            final position = value.position + value.subtitleOffset;
            final activeCues = _findActiveCues(extractedCues, position);
            if (activeCues.isEmpty) {
              return const SizedBox.shrink();
            }
            return _buildSubtitlesWidget(activeCues, playerHeight);
          }

          // Fall back to currentEmbeddedCue (native-pushed cue)
          // This is populated when native player streams cues to Flutter
          final embeddedCue = value.currentEmbeddedCue;
          if (embeddedCue == null) {
            return const SizedBox.shrink();
          }
          // Apply subtitle offset for embedded subtitles (only when offset is non-zero)
          // When offset is 0, trust the native player's timing decision
          if (value.subtitleOffset != Duration.zero) {
            final adjustedPosition = value.position + value.subtitleOffset;
            if (!embeddedCue.isActiveAt(adjustedPosition)) {
              return const SizedBox.shrink();
            }
          }
          return _buildSubtitleWidget(embeddedCue, playerHeight);
        }

        // Handle external subtitle tracks
        final cues = selectedTrack.cues;

        // Cues not loaded yet
        if (cues == null || cues.isEmpty) {
          return const SizedBox.shrink();
        }

        // Find active cues for current position, applying subtitle offset
        // Positive offset = delay subtitles (add to position)
        // Negative offset = show subtitles earlier (subtract from position)
        final position = value.position + value.subtitleOffset;
        final activeCues = _findActiveCues(cues, position);

        // No active cues at current position
        if (activeCues.isEmpty) {
          return const SizedBox.shrink();
        }

        return _buildSubtitlesWidget(activeCues, playerHeight);
      },
    );
  }

  /// Base font size as a percentage of player height.
  /// This is the "100%" reference size that [SubtitleStyle.fontSizePercent] scales from.
  static const _baseFontSizePercent = 0.04;

  /// Builds the positioned subtitle widget.
  Widget _buildSubtitleWidget(SubtitleCue cue, double playerHeight) {
    // Don't show empty subtitles (avoids showing empty background box)
    if (cue.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final style = widget.style ?? const SubtitleStyle();
    // Calculate font size: base size (4% of height) * user's percentage multiplier
    final calculatedFontSize = playerHeight * _baseFontSizePercent * style.fontSizePercent;

    final marginFromEdge = style.marginFromEdge;
    final horizontalMargin = style.horizontalMargin;
    final backgroundColor = style.backgroundColor;
    final containerPadding = style.containerPadding;
    final borderRadius = style.containerBorderRadius;

    // Build the subtitle text widget (with optional stroke)
    final textWidget = _buildTextWidget(cue, style, calculatedFontSize);

    // Wrap in container with background
    final container = Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
      padding: containerPadding,
      decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(borderRadius)),
      child: textWidget,
    );

    // Apply horizontal alignment
    Widget alignedContainer;
    switch (style.textAlignment) {
      case SubtitleTextAlignment.left:
        alignedContainer = Align(alignment: Alignment.centerLeft, child: container);
      case SubtitleTextAlignment.center:
        alignedContainer = Center(child: container);
      case SubtitleTextAlignment.right:
        alignedContainer = Align(alignment: Alignment.centerRight, child: container);
    }

    // Position based on vertical position setting
    return Stack(children: [_buildPositioned(alignedContainer, style.position, marginFromEdge)]);
  }

  /// Builds the positioned subtitle widget for multiple overlapping cues.
  ///
  /// Stacks multiple cues vertically when there are overlapping subtitles.
  Widget _buildSubtitlesWidget(List<SubtitleCue> cues, double playerHeight) {
    // Filter out empty cues
    final nonEmptyCues = cues.where((cue) => cue.text.trim().isNotEmpty).toList();
    if (nonEmptyCues.isEmpty) {
      return const SizedBox.shrink();
    }

    // Single cue - use the regular method
    if (nonEmptyCues.length == 1) {
      return _buildSubtitleWidget(nonEmptyCues.first, playerHeight);
    }

    // Multiple cues - stack them vertically
    final style = widget.style ?? const SubtitleStyle();
    final calculatedFontSize = playerHeight * _baseFontSizePercent * style.fontSizePercent;

    final marginFromEdge = style.marginFromEdge;
    final horizontalMargin = style.horizontalMargin;
    final backgroundColor = style.backgroundColor;
    final containerPadding = style.containerPadding;
    final borderRadius = style.containerBorderRadius;

    // Build a column of subtitle containers
    final subtitleWidgets = nonEmptyCues.map((cue) {
      final textWidget = _buildTextWidget(cue, style, calculatedFontSize);
      return Container(
        margin: EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: 2),
        padding: containerPadding,
        decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(borderRadius)),
        child: textWidget,
      );
    }).toList();

    // Apply horizontal alignment
    Widget alignedColumn;
    switch (style.textAlignment) {
      case SubtitleTextAlignment.left:
        alignedColumn = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: subtitleWidgets,
        );
      case SubtitleTextAlignment.center:
        alignedColumn = Column(mainAxisSize: MainAxisSize.min, children: subtitleWidgets);
      case SubtitleTextAlignment.right:
        alignedColumn = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: subtitleWidgets,
        );
    }

    // Position based on vertical position setting
    return Stack(children: [_buildPositioned(alignedColumn, style.position, marginFromEdge)]);
  }

  /// Builds the positioned wrapper based on subtitle position.
  Widget _buildPositioned(Widget child, SubtitlePosition position, double margin) {
    switch (position) {
      case SubtitlePosition.top:
        return Positioned(left: 0, right: 0, top: margin, child: child);
      case SubtitlePosition.middle:
        return Positioned.fill(child: Center(child: child));
      case SubtitlePosition.bottom:
        return Positioned(left: 0, right: 0, bottom: margin, child: child);
    }
  }

  /// Builds the text widget with optional stroke/outline and rich text.
  Widget _buildTextWidget(SubtitleCue cue, SubtitleStyle style, double fontSize) {
    final baseTextStyle = _buildTextStyle(style, fontSize);
    final textAlign = style.toTextAlign();

    // Check if cue has styled spans for rich text rendering
    final hasStyledSpans = cue.hasStyledSpans;

    // If no stroke and no styled spans, just return simple text
    if (!style.hasStroke && !hasStyledSpans) {
      return Text(cue.text, style: baseTextStyle, textAlign: textAlign);
    }

    // Build text spans if cue has styling
    final textSpans = hasStyledSpans
        ? _buildTextSpans(cue.styledSpans!, baseTextStyle)
        : [TextSpan(text: cue.text, style: baseTextStyle)];

    // If no stroke, just return rich text
    if (!style.hasStroke) {
      return Text.rich(TextSpan(children: textSpans), textAlign: textAlign);
    }

    // With stroke: stack a stroked version behind the filled version
    final strokeTextSpans = hasStyledSpans
        ? _buildTextSpans(cue.styledSpans!, baseTextStyle, strokeStyle: style)
        : [
            TextSpan(
              text: cue.text,
              style: baseTextStyle.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = style.strokeWidth!
                  ..color = style.strokeColor!,
              ),
            ),
          ];

    return Stack(
      children: [
        // Stroke layer (behind)
        Text.rich(TextSpan(children: strokeTextSpans), textAlign: textAlign),
        // Fill layer (in front)
        Text.rich(TextSpan(children: textSpans), textAlign: textAlign),
      ],
    );
  }

  /// Builds Flutter TextSpan list from StyledTextSpan list.
  List<TextSpan> _buildTextSpans(List<StyledTextSpan> styledSpans, TextStyle baseStyle, {SubtitleStyle? strokeStyle}) =>
      styledSpans.map((span) {
        var spanStyle = baseStyle;

        // Apply span-specific styling
        if (span.hasStyle) {
          final subtitleTextStyle = span.style!;
          spanStyle = spanStyle.copyWith(
            fontWeight: subtitleTextStyle.isBold ? FontWeight.bold : null,
            fontStyle: subtitleTextStyle.isItalic ? FontStyle.italic : null,
            decoration: _buildTextDecoration(subtitleTextStyle),
            color: subtitleTextStyle.color ?? spanStyle.color,
            backgroundColor: subtitleTextStyle.backgroundColor,
            fontSize: subtitleTextStyle.fontSize ?? spanStyle.fontSize,
            fontFamily: subtitleTextStyle.fontFamily ?? spanStyle.fontFamily,
          );
        }

        // Apply stroke if provided
        if (strokeStyle != null && strokeStyle.hasStroke) {
          spanStyle = spanStyle.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeStyle.strokeWidth!
              ..color = strokeStyle.strokeColor!,
          );
        }

        return TextSpan(text: span.text, style: spanStyle);
      }).toList();

  /// Builds TextDecoration from SubtitleTextStyle.
  TextDecoration? _buildTextDecoration(SubtitleTextStyle style) {
    final decorations = <TextDecoration>[];

    if (style.isUnderline) decorations.add(TextDecoration.underline);
    if (style.isStrikethrough) decorations.add(TextDecoration.lineThrough);

    if (decorations.isEmpty) return null;
    if (decorations.length == 1) return decorations.first;
    return TextDecoration.combine(decorations);
  }

  /// Finds all active cues for the given position.
  ///
  /// Returns all cues that are active at the given [position], enabling
  /// support for overlapping subtitles (e.g., karaoke, multi-speaker).
  List<SubtitleCue> _findActiveCues(List<SubtitleCue> cues, Duration position) {
    final activeCues = <SubtitleCue>[];
    for (final cue in cues) {
      if (cue.isActiveAt(position)) {
        activeCues.add(cue);
      }
    }
    return activeCues;
  }

  /// Builds the text style for subtitles.
  ///
  /// The [fontSize] is calculated from the player height and [SubtitleStyle.fontSizePercent].
  TextStyle _buildTextStyle(SubtitleStyle style, double fontSize) {
    // Default shadows for readability
    const defaultShadows = [Shadow(blurRadius: 4, offset: Offset(1, 1)), Shadow(blurRadius: 8)];

    // Build base style from SubtitleStyle with calculated font size
    final baseStyle = TextStyle(
      color: style.textColor ?? Colors.white,
      fontSize: fontSize,
      fontFamily: style.fontFamily,
      fontWeight: style.fontWeight ?? FontWeight.w500,
      shadows: style.hasStroke ? null : defaultShadows, // No shadows when using stroke
    );

    return baseStyle;
  }
}
