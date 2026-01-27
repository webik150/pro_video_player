/// Phase of the remuxing operation.
enum RemuxPhase {
  /// Parsing the input file to extract metadata.
  parsing,

  /// Reading and processing samples from the input.
  reading,

  /// Writing segments to the output.
  writing,

  /// Generating playlists.
  generatingPlaylists,

  /// Operation complete.
  complete,
}

/// Progress information for a remuxing operation.
class RemuxProgress {
  /// Creates progress information.
  const RemuxProgress({
    required this.phase,
    required this.progress,
    this.currentSegment,
    this.totalSegments,
    this.bytesProcessed = 0,
    this.totalBytes,
    this.message,
  });

  /// Creates progress for the parsing phase.
  const RemuxProgress.parsing({this.progress = 0, this.message})
    : phase = RemuxPhase.parsing,
      currentSegment = null,
      totalSegments = null,
      bytesProcessed = 0,
      totalBytes = null;

  /// Creates progress for the reading phase.
  const RemuxProgress.reading({required this.progress, required this.bytesProcessed, this.totalBytes, this.message})
    : phase = RemuxPhase.reading,
      currentSegment = null,
      totalSegments = null;

  /// Creates progress for the writing phase.
  const RemuxProgress.writing({required this.progress, required this.currentSegment, this.totalSegments, this.message})
    : phase = RemuxPhase.writing,
      bytesProcessed = 0,
      totalBytes = null;

  /// Creates progress for playlist generation.
  const RemuxProgress.generatingPlaylists({this.message})
    : phase = RemuxPhase.generatingPlaylists,
      progress = 0.95,
      currentSegment = null,
      totalSegments = null,
      bytesProcessed = 0,
      totalBytes = null;

  /// Creates progress for completion.
  const RemuxProgress.complete({this.message})
    : phase = RemuxPhase.complete,
      progress = 1.0,
      currentSegment = null,
      totalSegments = null,
      bytesProcessed = 0,
      totalBytes = null;

  /// Current phase of the operation.
  final RemuxPhase phase;

  /// Overall progress from 0.0 to 1.0.
  final double progress;

  /// Current segment being processed (during writing phase).
  final int? currentSegment;

  /// Estimated total number of segments.
  final int? totalSegments;

  /// Number of bytes processed so far.
  final int bytesProcessed;

  /// Total bytes to process (if known).
  final int? totalBytes;

  /// Optional status message.
  final String? message;

  /// Progress as a percentage (0-100).
  int get progressPercent => (progress * 100).round();

  /// Whether the operation is complete.
  bool get isComplete => phase == RemuxPhase.complete;

  @override
  String toString() {
    final segmentInfo = currentSegment != null
        ? ', segment: $currentSegment${totalSegments != null ? '/$totalSegments' : ''}'
        : '';
    return 'RemuxProgress(phase: $phase, progress: $progressPercent%$segmentInfo)';
  }
}

/// Result of a remuxing operation.
class RemuxResult {
  /// Creates a successful result.
  const RemuxResult.success({
    required this.outputDirectory,
    required this.masterPlaylistPath,
    required this.mediaPlaylistPaths,
    required this.segmentPaths,
    required this.initSegmentPath,
    required this.totalDuration,
    required this.segmentCount,
  }) : isSuccess = true,
       error = null;

  /// Creates a failed result.
  const RemuxResult.failure({required String this.error})
    : isSuccess = false,
      outputDirectory = null,
      masterPlaylistPath = null,
      mediaPlaylistPaths = const [],
      segmentPaths = const [],
      initSegmentPath = null,
      totalDuration = Duration.zero,
      segmentCount = 0;

  /// Whether the operation was successful.
  final bool isSuccess;

  /// Output directory containing all generated files.
  final String? outputDirectory;

  /// Path to the master playlist (null if not generated).
  final String? masterPlaylistPath;

  /// Paths to the media playlists.
  final List<String> mediaPlaylistPaths;

  /// Paths to all generated segment files.
  final List<String> segmentPaths;

  /// Path to the initialization segment (for fMP4).
  final String? initSegmentPath;

  /// Total duration of the output.
  final Duration totalDuration;

  /// Number of segments generated.
  final int segmentCount;

  /// Error message (if failed).
  final String? error;

  @override
  String toString() {
    if (isSuccess) {
      return 'RemuxResult.success(segments: $segmentCount, duration: $totalDuration)';
    }
    return 'RemuxResult.failure(error: $error)';
  }
}
