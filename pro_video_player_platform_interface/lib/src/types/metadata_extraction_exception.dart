/// Exception thrown when video metadata extraction fails.
///
/// This exception is thrown by `ProVideoPlayerController.extractMetadata` when
/// the metadata extraction operation fails for any reason, such as:
/// - Invalid video source (malformed URL, file not found)
/// - Network error (timeout, connection refused)
/// - Unsupported format (codec not recognized)
/// - Platform-specific errors
///
/// Example:
/// ```dart
/// try {
///   final metadata = await ProVideoPlayerController.extractMetadata(
///     VideoSource.file('/path/to/video.mp4'),
///   );
/// } on MetadataExtractionException catch (e) {
///   print('Error: ${e.code} - ${e.message}');
/// }
/// ```
class MetadataExtractionException implements Exception {
  /// Creates a metadata extraction exception.
  const MetadataExtractionException(this.code, this.message);

  /// Error code identifying the failure type.
  ///
  /// Common error codes:
  /// - `INVALID_SOURCE` - The video source is invalid or malformed
  /// - `FILE_NOT_FOUND` - The local file does not exist
  /// - `NETWORK_ERROR` - Network connection failed
  /// - `TIMEOUT` - Operation timed out
  /// - `UNSUPPORTED_FORMAT` - Video format not supported
  /// - `EXTRACTION_FAILED` - General extraction failure
  final String code;

  /// Human-readable error message describing the failure.
  final String message;

  @override
  String toString() => 'MetadataExtractionException($code): $message';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MetadataExtractionException) return false;
    return code == other.code && message == other.message;
  }

  @override
  int get hashCode => Object.hash(code, message);
}
