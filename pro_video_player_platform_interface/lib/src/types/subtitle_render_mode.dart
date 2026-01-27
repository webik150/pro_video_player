/// The rendering mode for subtitle display.
///
/// Controls whether subtitles are rendered by the native platform or by Flutter.
enum SubtitleRenderMode {
  /// Native platform renders subtitles.
  ///
  /// - **iOS/macOS**: AVPlayer renders **embedded** subtitles with platform styling
  /// - **Android**: ExoPlayer renders both embedded and external subtitles
  /// - **Web**: Browser's TextTrack API renders both embedded and external subtitles
  ///
  /// **External subtitle behavior varies by platform:**
  /// - **Android/Web**: External subtitles added via `addExternalSubtitle()` are
  ///   automatically converted to WebVTT and rendered natively with platform styling.
  /// - **iOS/macOS**: External subtitles use Flutter rendering (falls back to `flutter` mode).
  ///   This is intentional - AVPlayer doesn't support adding subtitle tracks programmatically
  ///   to existing videos. Industry-standard iOS players (VLC, Infuse, mpv) also render
  ///   external subtitles via custom overlays rather than through AVPlayer's native system.
  ///
  /// **Embedded subtitles** (already in the video file) always use native rendering
  /// on all platforms when this mode is active.
  native,

  /// Flutter renders all subtitles via SubtitleOverlay.
  ///
  /// Subtitle text is extracted from the native player and streamed to Flutter
  /// for rendering. This enables customizable styling via `SubtitleStyle` for
  /// ALL subtitles (embedded and external).
  ///
  /// This mode allows subtitles to appear on top of native controls and persist
  /// across all layout modes (native, flutter, none, custom).
  flutter,

  /// Automatic selection - defaults to Flutter rendering.
  ///
  /// In auto mode, subtitles are rendered by Flutter's SubtitleOverlay widget,
  /// enabling customizable styling via `SubtitleStyle` and consistent appearance
  /// across all platforms and layout modes.
  ///
  /// Users can opt-in to native subtitle rendering (for platform-specific styling)
  /// by explicitly calling:
  /// ```dart
  /// await controller.setSubtitleRenderMode(SubtitleRenderMode.native);
  /// ```
  ///
  /// This is the default mode providing cross-platform consistency out of the box.
  auto,
}

/// Extension methods for [SubtitleRenderMode] serialization.
extension SubtitleRenderModeExtension on SubtitleRenderMode {
  /// Serializes this [SubtitleRenderMode] to a JSON string.
  String toJson() => name;

  /// Deserializes a [SubtitleRenderMode] from a JSON string.
  ///
  /// Returns [SubtitleRenderMode.auto] if the value is null or unknown.
  static SubtitleRenderMode fromJson(String? value) {
    if (value == null) return SubtitleRenderMode.auto;
    return SubtitleRenderMode.values.firstWhere((mode) => mode.name == value, orElse: () => SubtitleRenderMode.auto);
  }
}
