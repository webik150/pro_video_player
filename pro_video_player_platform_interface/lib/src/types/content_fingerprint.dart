/// Content fingerprint for video deduplication.
///
/// Contains a hash computed from multi-position content samples,
/// useful for video deduplication that can distinguish edited versions
/// (e.g., trimmed videos) that would have identical metadata.
///
/// The fingerprint is computed from 8KB samples at three positions:
/// - Beginning: First 8KB of the file
/// - Middle: 8KB at the 50% position
/// - End: Last 8KB of the file
///
/// Example:
/// ```dart
/// final fingerprint = await controller.extractContentFingerprint(source);
/// print('Fingerprint: ${fingerprint.fingerprint}');
/// print('File size: ${fingerprint.fileSize} bytes');
///
/// // Combine with metadata fingerprint for robust deduplication
/// final metadata = await controller.extractMetadata(source);
/// final combined = '${metadata.metadataFingerprint}-${fingerprint.fingerprint}';
/// ```
class ContentFingerprint {
  /// Creates a content fingerprint.
  const ContentFingerprint({required this.fingerprint, this.fileSize});

  /// SHA-256 hash of the content samples as a hex string.
  ///
  /// This is a 64-character lowercase hex string representing the
  /// 256-bit hash of the concatenated content samples.
  final String fingerprint;

  /// File size in bytes.
  ///
  /// Available for local files and network sources that provide Content-Length.
  /// May be null for streams or sources that don't report size.
  final int? fileSize;

  /// Returns `true` if this fingerprint equals another.
  ///
  /// Two fingerprints are equal if they have the same hash.
  /// File size is not considered for equality since it's included
  /// in the hash computation.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ContentFingerprint) return false;
    return fingerprint == other.fingerprint;
  }

  @override
  int get hashCode => fingerprint.hashCode;

  @override
  String toString() {
    final parts = <String>['fingerprint: $fingerprint'];
    if (fileSize != null) parts.add('fileSize: $fileSize');
    return 'ContentFingerprint(${parts.join(', ')})';
  }
}
