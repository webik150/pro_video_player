/// Exception thrown when content fingerprint extraction fails.
///
/// This exception is thrown by `extractContentFingerprint` when the
/// fingerprint extraction operation fails for any reason, such as:
/// - Invalid video source (malformed URL, file not found)
/// - Network error (timeout, connection refused)
/// - Server doesn't support HTTP Range requests (for network sources)
/// - File too small for multi-position sampling
/// - Platform-specific errors
///
/// Example:
/// ```dart
/// try {
///   final fingerprint = await controller.extractContentFingerprint(
///     VideoSource.file('/path/to/video.mp4'),
///   );
/// } on ContentFingerprintException catch (e) {
///   print('Error: ${e.code} - ${e.message}');
/// }
/// ```
class ContentFingerprintException implements Exception {
  /// Creates a content fingerprint exception.
  const ContentFingerprintException(this.code, this.message);

  /// Error code identifying the failure type.
  ///
  /// Common error codes:
  /// - `INVALID_SOURCE` - The video source is invalid or malformed
  /// - `FILE_NOT_FOUND` - The local file does not exist
  /// - `NETWORK_ERROR` - Network connection failed
  /// - `RANGE_NOT_SUPPORTED` - Server doesn't support HTTP Range requests
  /// - `FILE_TOO_SMALL` - File is too small for multi-position sampling
  /// - `TIMEOUT` - Operation timed out
  /// - `EXTRACTION_FAILED` - General extraction failure
  final String code;

  /// Human-readable error message describing the failure.
  final String message;

  @override
  String toString() => 'ContentFingerprintException($code): $message';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ContentFingerprintException) return false;
    return code == other.code && message == other.message;
  }

  @override
  int get hashCode => Object.hash(code, message);
}
