import 'dart:async';

import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

import 'manager_callbacks.dart';

// Alias for cleaner code
typedef _Logger = ProVideoPlayerLogger;

/// Manages track selection (subtitle, audio, video quality) for the video player.
///
/// This manager handles:
/// - Subtitle track selection and auto-selection based on preferences
/// - Audio track selection
/// - Video quality track selection for adaptive streams
/// - Subtitle render mode configuration
/// - Embedded subtitle extraction for Flutter render mode
class TrackManager with ManagerCallbacks {
  /// Creates a track manager with dependency injection via callbacks.
  TrackManager({
    required this.getValue,
    required this.setValue,
    required this.getPlayerId,
    required this.getOptions,
    required this.platform,
    required this.ensureInitialized,
    required this.getSource,
  });

  /// Gets the current video source.
  final VideoSource? Function() getSource;

  @override
  final VideoPlayerValue Function() getValue;

  @override
  final void Function(VideoPlayerValue) setValue;

  @override
  final int? Function() getPlayerId;

  @override
  final VideoPlayerOptions Function() getOptions;

  @override
  final ProVideoPlayerPlatform platform;

  @override
  final void Function() ensureInitialized;

  /// Sets the active subtitle track.
  ///
  /// Pass `null` to disable subtitles. Returns immediately without effect
  /// if subtitles are disabled via [VideoPlayerOptions.subtitlesEnabled].
  Future<void> setSubtitleTrack(SubtitleTrack? track) async {
    ensureInitialized();

    // Gracefully handle disabled subtitles
    if (!getOptions().subtitlesEnabled) {
      return;
    }

    await platform.setSubtitleTrack(getPlayerId()!, track);
    final value = getValue();
    setValue(
      value.copyWith(
        selectedSubtitleTrack: track,
        clearSelectedSubtitle: track == null,
        clearEmbeddedSubtitleCues: true, // Clear old cues when track changes
      ),
    );

    // Extract cues for embedded tracks in Flutter mode (auto defaults to flutter)
    if (track != null) {
      extractEmbeddedSubtitlesIfNeeded(track);
    }
  }

  /// Sets the subtitle rendering mode at runtime.
  ///
  /// This allows switching between native and Flutter subtitle rendering
  /// during playback without restarting the video.
  ///
  /// - [SubtitleRenderMode.native]: Native platform renders subtitles
  /// - [SubtitleRenderMode.flutter]: Flutter renders subtitles via overlay
  /// - [SubtitleRenderMode.auto]: Automatically select based on controls mode
  ///
  /// Returns immediately without effect if subtitles are disabled.
  Future<void> setSubtitleRenderMode(SubtitleRenderMode mode) async {
    ensureInitialized();

    // Gracefully handle disabled subtitles
    if (!getOptions().subtitlesEnabled) {
      return;
    }

    await platform.setSubtitleRenderMode(getPlayerId()!, mode);
    final value = getValue();
    // Only clear cues when switching to native mode (auto and flutter both use Flutter rendering)
    final shouldClearCues = mode == SubtitleRenderMode.native;
    setValue(value.copyWith(currentSubtitleRenderMode: mode, clearEmbeddedSubtitleCues: shouldClearCues));

    // Extract cues when switching to Flutter/auto mode with an embedded track selected
    if (mode == SubtitleRenderMode.flutter || mode == SubtitleRenderMode.auto) {
      final selectedTrack = getValue().selectedSubtitleTrack;
      if (selectedTrack != null) {
        extractEmbeddedSubtitlesIfNeeded(selectedTrack);
      }
    }
  }

  /// Extracts embedded subtitles for Flutter rendering if needed.
  ///
  /// Called when a subtitle track is selected (either by user or auto-selection).
  /// Only extracts if the render mode is flutter or auto (which defaults to flutter).
  void extractEmbeddedSubtitlesIfNeeded(SubtitleTrack track) {
    if (track.isExternal) return; // External tracks don't need extraction

    final renderMode = getValue().currentSubtitleRenderMode;
    // Auto mode now defaults to flutter, so extract for both
    if (renderMode == SubtitleRenderMode.flutter || renderMode == SubtitleRenderMode.auto) {
      unawaited(_extractEmbeddedSubtitleCues(track));
    }
  }

  /// Extracts embedded subtitle cues from HLS/DASH streams for Flutter rendering.
  ///
  /// This fetches all cues upfront so the SubtitleOverlay can render them
  /// with custom styling instead of relying on native platform rendering.
  Future<void> _extractEmbeddedSubtitleCues(SubtitleTrack track) async {
    final source = getSource();
    if (source == null) {
      _Logger.log('Cannot extract embedded subtitles: no video source', tag: 'TrackManager');
      return;
    }

    // Get the source URL
    final sourceUrl = switch (source) {
      NetworkVideoSource(:final url) => url,
      _ => null,
    };

    if (sourceUrl == null) {
      _Logger.log('Cannot extract embedded subtitles: source is not a network URL', tag: 'TrackManager');
      return;
    }

    // Check if it's an HLS stream
    if (!sourceUrl.contains('.m3u8')) {
      _Logger.log('Cannot extract embedded subtitles: not an HLS stream', tag: 'TrackManager');
      return;
    }

    try {
      _Logger.log('Extracting embedded subtitles from HLS: $sourceUrl', tag: 'TrackManager');

      final extractor = HlsSubtitleExtractor();
      final hlsTracks = await extractor.listTracks(Uri.parse(sourceUrl));

      if (hlsTracks.isEmpty) {
        _Logger.log('No HLS subtitle tracks found', tag: 'TrackManager');
        return;
      }

      // Match the track by index (track.id format is "0:index")
      final parts = track.id.split(':');
      final trackIndex = parts.length == 2 ? int.tryParse(parts[1]) : null;

      if (trackIndex == null || trackIndex >= hlsTracks.length) {
        // Try matching by language
        final matchingTrack = hlsTracks.where((t) => t.language == track.language).firstOrNull;
        if (matchingTrack != null) {
          final cues = await extractor.extractFromTrack(Uri.parse(sourceUrl), matchingTrack);
          _Logger.log('Extracted ${cues.length} cues for track ${track.label} (by language)', tag: 'TrackManager');
          setValue(getValue().copyWith(embeddedSubtitleCues: cues));
          return;
        }
        _Logger.log('Could not match HLS track for: ${track.id}', tag: 'TrackManager');
        return;
      }

      final hlsTrack = hlsTracks[trackIndex];
      final cues = await extractor.extractFromTrack(Uri.parse(sourceUrl), hlsTrack);
      _Logger.log('Extracted ${cues.length} cues for track ${track.label}', tag: 'TrackManager');
      setValue(getValue().copyWith(embeddedSubtitleCues: cues));
    } catch (e) {
      _Logger.error('Failed to extract embedded subtitles', tag: 'TrackManager', error: e);
    }
  }

  /// Sets the active audio track.
  ///
  /// Pass `null` to use the default audio track.
  Future<void> setAudioTrack(AudioTrack? track) async {
    ensureInitialized();
    await platform.setAudioTrack(getPlayerId()!, track);
    final value = getValue();
    setValue(value.copyWith(selectedAudioTrack: track, clearSelectedAudio: track == null));
  }

  /// Sets the video quality for adaptive streams.
  ///
  /// Pass [VideoQualityTrack.auto] to enable automatic quality selection (ABR).
  /// Pass a specific track to lock to that quality level.
  ///
  /// This only has effect for adaptive streaming content (HLS, DASH).
  /// For non-adaptive content, this method has no effect.
  ///
  /// Returns `true` if the quality was successfully set.
  Future<bool> setVideoQuality(VideoQualityTrack track) async {
    ensureInitialized();
    final success = await platform.setVideoQuality(getPlayerId()!, track);
    if (success) {
      final value = getValue();
      setValue(value.copyWith(selectedQualityTrack: track, clearSelectedQuality: track.isAuto));
    }
    return success;
  }

  /// Returns the available video quality tracks.
  ///
  /// For adaptive streaming content (HLS, DASH), this returns a list of
  /// available quality options. The list always includes [VideoQualityTrack.auto]
  /// as the first option.
  ///
  /// For non-adaptive content, returns a list with only [VideoQualityTrack.auto].
  Future<List<VideoQualityTrack>> getVideoQualities() async {
    ensureInitialized();
    return platform.getVideoQualities(getPlayerId()!);
  }

  /// Returns the currently selected video quality track.
  ///
  /// Returns [VideoQualityTrack.auto] if automatic quality selection is active.
  Future<VideoQualityTrack> getCurrentVideoQuality() async {
    ensureInitialized();
    return platform.getCurrentVideoQuality(getPlayerId()!);
  }

  /// Returns whether manual quality selection is supported for the current content.
  ///
  /// This returns `true` for adaptive streaming content (HLS, DASH) where
  /// multiple quality levels are available.
  Future<bool> isQualitySelectionSupported() async {
    ensureInitialized();
    return platform.isQualitySelectionSupported(getPlayerId()!);
  }

  /// Auto-selects a subtitle track based on configuration preferences.
  ///
  /// Selection priority:
  /// 1. Track matching [VideoPlayerOptions.preferredSubtitleLanguage]
  /// 2. Track marked as default
  /// 3. First available track
  ///
  /// Called automatically when subtitle tracks become available and
  /// [VideoPlayerOptions.showSubtitlesByDefault] is true.
  void autoSelectSubtitle(List<SubtitleTrack> tracks) {
    SubtitleTrack? trackToSelect;

    final options = getOptions();

    // Try to find track matching preferred language
    if (options.preferredSubtitleLanguage != null) {
      trackToSelect = tracks.where((t) => t.language == options.preferredSubtitleLanguage).firstOrNull;
    }

    // Fall back to default track
    trackToSelect ??= tracks.where((t) => t.isDefault).firstOrNull;

    // Fall back to first track
    trackToSelect ??= tracks.firstOrNull;

    if (trackToSelect != null) {
      // Fire and forget for auto-selection - explicitly discard the future
      unawaited(setSubtitleTrack(trackToSelect));
    }
  }
}
