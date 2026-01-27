/// Video-specific track information.
///
/// Contains metadata about the video dimensions, frame rate, rotation,
/// and display parameters extracted from a container track.
///
/// Example:
/// ```dart
/// const videoInfo = VideoTrackInfo(
///   width: 1920,
///   height: 1080,
///   frameRate: 29.97,
///   rotation: 0,
/// );
///
/// print(videoInfo.resolution);    // '1920x1080'
/// print(videoInfo.isHD);          // true
/// print(videoInfo.aspectRatio);   // 1.777...
/// ```
class VideoTrackInfo {
  /// Creates video track information with required dimensions.
  const VideoTrackInfo({
    required this.width,
    required this.height,
    this.frameRate,
    this.displayWidth,
    this.displayHeight,
    this.rotation,
    this.pixelAspectRatio,
  });

  /// Creates a [VideoTrackInfo] from a map representation.
  factory VideoTrackInfo.fromMap(Map<String, dynamic> map) => VideoTrackInfo(
    width: map['width'] as int? ?? 0,
    height: map['height'] as int? ?? 0,
    frameRate: (map['frameRate'] as num?)?.toDouble(),
    displayWidth: map['displayWidth'] as int?,
    displayHeight: map['displayHeight'] as int?,
    rotation: map['rotation'] as int?,
    pixelAspectRatio: (map['pixelAspectRatio'] as num?)?.toDouble(),
  );

  /// Encoded width in pixels.
  final int width;

  /// Encoded height in pixels.
  final int height;

  /// Frame rate in frames per second.
  ///
  /// Common values: 23.976, 24.0, 25.0, 29.97, 30.0, 50.0, 59.94, 60.0
  final double? frameRate;

  /// Display width after aspect ratio correction.
  ///
  /// May differ from [width] for anamorphic video.
  final int? displayWidth;

  /// Display height after aspect ratio correction.
  ///
  /// May differ from [height] for anamorphic video.
  final int? displayHeight;

  /// Video rotation in degrees.
  ///
  /// Common values: 0, 90, 180, 270
  /// Extracted from the track's transformation matrix.
  final int? rotation;

  /// Pixel aspect ratio (width:height).
  ///
  /// For square pixels, this is 1.0.
  /// For anamorphic video, this may be different.
  final double? pixelAspectRatio;

  /// Resolution as a formatted string (e.g., "1920x1080").
  String get resolution => '${width}x$height';

  /// Encoded aspect ratio (width / height).
  double get aspectRatio => height > 0 ? width / height : 0.0;

  /// Display aspect ratio using display dimensions if available.
  ///
  /// Falls back to encoded aspect ratio if display dimensions not set.
  double get displayAspectRatio {
    final dw = displayWidth ?? width;
    final dh = displayHeight ?? height;
    return dh > 0 ? dw / dh : 0.0;
  }

  /// Whether the video is HD quality (720p or higher).
  bool get isHD => height >= 720;

  /// Whether the video is 4K quality (2160p or higher).
  bool get is4K => height >= 2160;

  /// Converts this video info to a map representation.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'width': width,
    'height': height,
    if (frameRate != null) 'frameRate': frameRate,
    if (displayWidth != null) 'displayWidth': displayWidth,
    if (displayHeight != null) 'displayHeight': displayHeight,
    if (rotation != null) 'rotation': rotation,
    if (pixelAspectRatio != null) 'pixelAspectRatio': pixelAspectRatio,
  };

  /// Creates a copy with the given fields replaced.
  VideoTrackInfo copyWith({
    int? width,
    int? height,
    double? frameRate,
    int? displayWidth,
    int? displayHeight,
    int? rotation,
    double? pixelAspectRatio,
  }) => VideoTrackInfo(
    width: width ?? this.width,
    height: height ?? this.height,
    frameRate: frameRate ?? this.frameRate,
    displayWidth: displayWidth ?? this.displayWidth,
    displayHeight: displayHeight ?? this.displayHeight,
    rotation: rotation ?? this.rotation,
    pixelAspectRatio: pixelAspectRatio ?? this.pixelAspectRatio,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! VideoTrackInfo) return false;
    return width == other.width &&
        height == other.height &&
        frameRate == other.frameRate &&
        displayWidth == other.displayWidth &&
        displayHeight == other.displayHeight &&
        rotation == other.rotation &&
        pixelAspectRatio == other.pixelAspectRatio;
  }

  @override
  int get hashCode => Object.hash(width, height, frameRate, displayWidth, displayHeight, rotation, pixelAspectRatio);

  @override
  String toString() =>
      'VideoTrackInfo(width: $width, height: $height, frameRate: $frameRate, '
      'rotation: $rotation)';
}
