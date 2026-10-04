/// video_player API compatibility layer for pro_video_player.
///
/// This library provides a drop-in replacement for Flutter's `video_player` package.
/// Simply change your import to start using pro_video_player with your existing code:
///
/// ```dart
/// // Before
/// import 'package:video_player/video_player.dart';
///
/// // After
/// import 'package:pro_video_player/video_player_compat.dart';
/// ```
///
/// ## What This Provides
///
/// All the public API from video_player, including:
/// - [VideoPlayerController] with all constructor variants
/// - [VideoPlayerValue] with all properties
/// - [VideoPlayer] widget
/// - [VideoProgressIndicator] and [VideoProgressColors]
/// - [VideoScrubber] widget
/// - [ClosedCaption] widget
/// - [Caption], [ClosedCaptionFile], [SubRipCaptionFile], [WebVTTCaptionFile]
/// - [DurationRange] with `startFraction` and `endFraction`
/// - [DataSourceType], [VideoFormat], [VideoViewType] enums
/// - [VideoPlayerOptions], [VideoPlayerWebOptions], [VideoPlayerWebOptionsControls]
///
/// ## Accessing Advanced Features
///
/// To access pro_video_player's advanced features (PiP, casting, chapters, etc.),
/// use the `proController` property:
///
/// ```dart
/// // Enable Picture-in-Picture
/// await controller.proController.enterPictureInPicture();
///
/// // Access chapter navigation
/// final chapters = controller.proController.value.chapters;
/// ```
///
/// ## For New Projects
///
/// If you're starting a new project, consider using the native pro_video_player API:
///
/// ```dart
/// import 'package:pro_video_player/pro_video_player.dart';
/// ```
///
/// The native API provides more features and a cleaner interface designed for
/// modern video playback needs.
///
/// @docImport 'package:pro_video_player/pro_video_player.dart';
library video_player_compat;

import 'video_player_compat.dart'
    show
        ClosedCaption,
        DurationRange,
        SubRipCaptionFile,
        VideoFormat,
        VideoPlayer,
        VideoPlayerController,
        VideoPlayerWebOptions,
        VideoPlayerWebOptionsControls,
        VideoProgressColors,
        VideoProgressIndicator,
        VideoScrubber,
        VideoViewType,
        WebVTTCaptionFile;

// Caption classes
export 'src/compat/caption.dart';
export 'src/compat/closed_caption_file.dart';
// Annotation for identifying compatibility code
export 'src/compat/compat_annotation.dart';
// Duration range with video_player methods
export 'src/compat/duration_range.dart';
// Enums
export 'src/compat/enums.dart';
// Controller
export 'src/compat/video_player_controller.dart';
// Options
export 'src/compat/video_player_options_compat.dart' show VideoPlayerOptions;
// Value
export 'src/compat/video_player_value.dart';
export 'src/compat/video_player_web_options.dart';
// Widgets
export 'src/compat/widgets/closed_caption_widget.dart';
export 'src/compat/widgets/video_player_widget.dart';
export 'src/compat/widgets/video_progress_colors.dart';
export 'src/compat/widgets/video_progress_indicator.dart';
