// SubtitleManager requires dynamic access for native HTML5 TextTrack API
// and HLS.js/DASH.js subtitle track properties. The external-facing API
// returns typed SubtitleTrack objects.
// ignore_for_file: avoid_dynamic_calls

import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

import '../abstractions/video_element_interface.dart';
import '../manager_callbacks.dart';
import '../verbose_logging.dart';
import 'dash_manager.dart';
import 'hls_manager.dart';

/// Manages subtitle/text track selection across HLS.js, DASH.js, and native HTML5.
///
/// This manager coordinates subtitle track selection by delegating to the
/// appropriate source (HLS.js, DASH.js, or native HTML5 TextTrackList).
/// It follows a priority system: HLS > DASH > native.
///
/// Subtitle track change events are emitted by the individual managers
/// (HlsManager, DashManager) when they detect track changes.
///
/// For native HTML5 playback, this manager handles:
/// - Detecting and notifying available text tracks
/// - Setting the active text track via TextTrack mode API
///
/// Note: This is a coordination manager. Advanced features like cue extraction,
/// render mode switching, and external subtitles are handled separately.
class SubtitleManager with WebManagerCallbacks {
  /// Creates a subtitle manager.
  SubtitleManager({required this.emitEvent, required this.videoElement});

  @override
  final EventEmitter emitEvent;

  @override
  final VideoElementInterface videoElement;

  /// HLS manager for HLS.js subtitle track handling.
  HlsManager? hlsManager;

  /// DASH manager for DASH.js text track handling.
  DashManager? dashManager;

  /// Whether an HLS manager is registered.
  bool get hasHlsManager => hlsManager != null && hlsManager!.isActive;

  /// Whether a DASH manager is registered.
  bool get hasDashManager => dashManager != null && dashManager!.isActive;

  /// Notifies about native HTML5 text tracks.
  ///
  /// Extracts text tracks from the video element's TextTrackList and
  /// emits a [SubtitleTracksChangedEvent].
  Future<void> notifyNativeTextTracks() async {
    try {
      final textTracks = videoElement.mockTextTracks;

      if (textTracks == null || textTracks.isEmpty) {
        verboseLog('No native text tracks available', tag: 'SubtitleManager');
        return;
      }

      final tracks = <SubtitleTrack>[];

      for (var i = 0; i < textTracks.length; i++) {
        // Native text tracks require dynamic access as they come from browser API
        final textTrack = textTracks[i];
        final trackId = textTrack.id as String? ?? i.toString();
        final trackLabel = textTrack.label as String?;
        final trackLanguage = textTrack.language as String?;
        tracks.add(
          SubtitleTrack(
            id: trackId,
            label: trackLabel?.isNotEmpty ?? false ? trackLabel! : 'Track ${i + 1}',
            language: trackLanguage?.isNotEmpty ?? false ? trackLanguage : null,
          ),
        );
      }

      if (tracks.isNotEmpty) {
        emitEvent(SubtitleTracksChangedEvent(tracks));
        verboseLog('Notified ${tracks.length} native text tracks', tag: 'SubtitleManager');
      }
    } catch (e) {
      verboseLog('Error notifying native text tracks: $e', tag: 'SubtitleManager');
    }
  }

  /// Sets the active subtitle track.
  ///
  /// Delegates to the appropriate source in priority order:
  /// 1. HLS.js (if active)
  /// 2. DASH.js (if active)
  /// 3. Native HTML5 TextTrackList
  ///
  /// Pass null to disable subtitles.
  ///
  /// Returns true if the track was set successfully.
  bool setSubtitleTrack(SubtitleTrack? track) {
    // Priority 1: HLS.js
    if (hasHlsManager) {
      return _setHlsSubtitleTrack(track);
    }

    // Priority 2: DASH.js
    if (hasDashManager) {
      return _setDashTextTrack(track);
    }

    // Priority 3: Native HTML5
    return setNativeTextTrack(track);
  }

  /// Sets subtitle track for HLS.js.
  bool _setHlsSubtitleTrack(SubtitleTrack? track) {
    try {
      final hlsPlayer = hlsManager!.hlsPlayer;
      if (hlsPlayer == null) return false;

      if (track == null) {
        hlsPlayer.subtitleTrack = -1; // Disable
        verboseLog('Disabled HLS subtitles', tag: 'SubtitleManager');
        return true;
      }

      final index = int.tryParse(track.id);
      if (index == null) return false;

      hlsPlayer.subtitleTrack = index;
      verboseLog('Set HLS subtitle track to $index', tag: 'SubtitleManager');
      return true;
    } catch (e) {
      verboseLog('Error setting HLS subtitle track: $e', tag: 'SubtitleManager');
      return false;
    }
  }

  /// Sets text track for DASH.js.
  bool _setDashTextTrack(SubtitleTrack? track) {
    try {
      final dashPlayer = dashManager!.dashPlayer;
      if (dashPlayer == null) return false;

      if (track == null) {
        dashPlayer.setTextTrackVisibility(visible: false);
        verboseLog('Disabled DASH text tracks', tag: 'SubtitleManager');
        return true;
      }

      final index = int.tryParse(track.id);
      if (index == null) return false;

      dashPlayer.setTextTrack(index);
      dashPlayer.setTextTrackVisibility(visible: true);
      verboseLog('Set DASH text track to $index', tag: 'SubtitleManager');
      return true;
    } catch (e) {
      verboseLog('Error setting DASH text track: $e', tag: 'SubtitleManager');
      return false;
    }
  }

  /// Sets text track for native HTML5 TextTrackList.
  ///
  /// Uses the TextTrack mode API: 'showing', 'hidden', or 'disabled'.
  bool setNativeTextTrack(SubtitleTrack? track) {
    try {
      final textTracks = videoElement.mockTextTracks;

      if (textTracks == null || textTracks.isEmpty) {
        verboseLog('Native text tracks not available', tag: 'SubtitleManager');
        return false;
      }

      if (track == null) {
        // Disable all tracks
        for (var i = 0; i < textTracks.length; i++) {
          final textTrack = textTracks[i];
          textTrack.mode = 'disabled';
        }
        verboseLog('Disabled all native text tracks', tag: 'SubtitleManager');
        return true;
      }

      // Enable the selected track, disable others
      for (var i = 0; i < textTracks.length; i++) {
        final textTrack = textTracks[i];
        final trackId = textTrack.id as String? ?? i.toString();
        textTrack.mode = trackId == track.id ? 'showing' : 'disabled';
      }

      verboseLog('Set native text track to ${track.id}', tag: 'SubtitleManager');
      return true;
    } catch (e) {
      verboseLog('Error setting native text track: $e', tag: 'SubtitleManager');
      return false;
    }
  }

  /// Gets native subtitle tracks from HTML5 TextTrackList.
  List<SubtitleTrack> getNativeSubtitleTracks() {
    try {
      final textTracks = videoElement.mockTextTracks;

      if (textTracks == null || textTracks.isEmpty) {
        return [];
      }

      final tracks = <SubtitleTrack>[];
      for (var i = 0; i < textTracks.length; i++) {
        final textTrack = textTracks[i] as dynamic;
        tracks.add(
          SubtitleTrack(
            id: textTrack.id as String? ?? i.toString(),
            label: (textTrack.label as String?)?.isNotEmpty ?? false ? textTrack.label as String : 'Track ${i + 1}',
            language: (textTrack.language as String?)?.isNotEmpty ?? false ? textTrack.language as String? : null,
          ),
        );
      }

      return tracks;
    } catch (e) {
      verboseLog('Error getting native subtitle tracks: $e', tag: 'SubtitleManager');
      return [];
    }
  }

  /// Gets HLS.js subtitle tracks.
  List<SubtitleTrack> getHlsSubtitleTracks() {
    try {
      final hlsPlayer = hlsManager?.hlsPlayer;
      if (hlsPlayer == null) return [];

      final hlsTracks = hlsPlayer.subtitleTracks as List;
      final tracks = <SubtitleTrack>[];
      for (final t in hlsTracks) {
        tracks.add(
          SubtitleTrack(
            id: (t.index as int).toString(),
            label: t.label as String,
            language: t.lang as String?,
            isDefault: t.isDefault as bool,
          ),
        );
      }
      return tracks;
    } catch (e) {
      verboseLog('Error getting HLS subtitle tracks: $e', tag: 'SubtitleManager');
      return [];
    }
  }

  /// Gets DASH.js text tracks.
  List<SubtitleTrack> getDashSubtitleTracks() {
    try {
      final dashPlayer = dashManager?.dashPlayer;
      if (dashPlayer == null) return [];

      final dashTracks = dashPlayer.getTextTracks() as List;
      final tracks = <SubtitleTrack>[];
      for (final t in dashTracks) {
        tracks.add(
          SubtitleTrack(
            id: (t.index as int).toString(),
            label: t.label as String,
            language: t.lang as String?,
            isDefault: t.isDefault as bool,
          ),
        );
      }
      return tracks;
    } catch (e) {
      verboseLog('Error getting DASH subtitle tracks: $e', tag: 'SubtitleManager');
      return [];
    }
  }

  /// Auto-selects an HLS subtitle track based on preferred language.
  ///
  /// Returns the selected track, or null if no selection was made.
  SubtitleTrack? autoSelectHlsSubtitle(String? preferredLanguage) {
    try {
      final hlsPlayer = hlsManager?.hlsPlayer;
      if (hlsPlayer == null) return null;

      final tracks = hlsPlayer.subtitleTracks as List;
      if (tracks.isEmpty) return null;

      var selectedIndex = -1;

      // Try to find track matching preferred language
      if (preferredLanguage != null) {
        for (final track in tracks) {
          if ((track.lang as String?) == preferredLanguage) {
            selectedIndex = track.index as int;
            break;
          }
        }
      }

      // Fall back to first or default track
      if (selectedIndex == -1) {
        for (final track in tracks) {
          if ((track.isDefault as bool?) ?? false) {
            selectedIndex = track.index as int;
            break;
          }
        }
        if (selectedIndex == -1 && tracks.isNotEmpty) {
          selectedIndex = 0;
        }
      }

      if (selectedIndex >= 0) {
        hlsPlayer.subtitleTrack = selectedIndex;
        final track = tracks.firstWhere((t) => (t.index as int) == selectedIndex);
        verboseLog('Auto-selected HLS subtitle: ${track.label}', tag: 'SubtitleManager');
        return SubtitleTrack(
          id: (track.index as int).toString(),
          label: track.label as String,
          language: track.lang as String?,
          isDefault: true,
        );
      }

      return null;
    } catch (e) {
      verboseLog('Error auto-selecting HLS subtitle: $e', tag: 'SubtitleManager');
      return null;
    }
  }

  /// Auto-selects a native subtitle track based on preferred language.
  ///
  /// Returns the selected track, or null if no selection was made.
  SubtitleTrack? autoSelectNativeSubtitle(String? preferredLanguage) {
    try {
      final textTracks = videoElement.mockTextTracks;

      if (textTracks == null || textTracks.isEmpty) return null;

      var selectedIndex = -1;

      // Try to find track matching preferred language
      if (preferredLanguage != null) {
        for (var i = 0; i < textTracks.length; i++) {
          final textTrack = textTracks[i] as dynamic;
          if (textTrack.language == preferredLanguage) {
            selectedIndex = i;
            break;
          }
        }
      }

      // Fall back to first track
      if (selectedIndex == -1 && textTracks.isNotEmpty) {
        selectedIndex = 0;
      }

      // Enable the selected track
      if (selectedIndex >= 0) {
        for (var i = 0; i < textTracks.length; i++) {
          final textTrack = textTracks[i] as dynamic;
          textTrack.mode = i == selectedIndex ? 'showing' : 'hidden';
        }

        final selectedTrack = textTracks[selectedIndex] as dynamic;
        verboseLog('Auto-selected native subtitle: ${selectedTrack.label}', tag: 'SubtitleManager');
        return SubtitleTrack(
          id: selectedIndex.toString(),
          label: (selectedTrack.label as String?)?.isNotEmpty ?? false
              ? selectedTrack.label as String
              : 'Track ${selectedIndex + 1}',
          language: (selectedTrack.language as String?)?.isNotEmpty ?? false ? selectedTrack.language as String? : null,
          isDefault: true,
        );
      }

      return null;
    } catch (e) {
      verboseLog('Error auto-selecting native subtitle: $e', tag: 'SubtitleManager');
      return null;
    }
  }

  /// Sets the subtitle rendering mode.
  ///
  /// - 'native': Browser renders subtitles
  /// - 'flutter': Extract cues and send to Flutter
  /// - 'auto': Defaults to Flutter rendering
  void setRenderMode(String mode) {
    verboseLog('Subtitle render mode set to: $mode', tag: 'SubtitleManager');

    final textTracks = videoElement.mockTextTracks;
    if (textTracks == null) return;

    // Auto mode defaults to flutter rendering
    final effectiveMode = (mode == 'auto') ? 'flutter' : mode;
    final shouldUseFlutterRendering = (effectiveMode == 'flutter');

    if (shouldUseFlutterRendering) {
      // Set all tracks to 'hidden' mode for Flutter rendering
      for (var i = 0; i < textTracks.length; i++) {
        final textTrack = textTracks[i] as dynamic;
        textTrack.mode = 'hidden';
      }
      verboseLog('Set tracks to hidden mode for Flutter rendering', tag: 'SubtitleManager');
    } else {
      // Restore to 'showing' or 'disabled' based on selection
      // Note: The actual track selection should be handled by setSubtitleTrack
      verboseLog('Using native subtitle rendering', tag: 'SubtitleManager');
    }
  }

  /// Disposes the manager and cleans up resources.
  void dispose() {
    hlsManager = null;
    dashManager = null;

    verboseLog('Subtitle manager disposed', tag: 'SubtitleManager');
  }
}
