import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

void main() {
  group('ContentFingerprint', () {
    test('creates fingerprint with all properties', () {
      const fingerprint = ContentFingerprint(fingerprint: 'abc123def456', fileSize: 1024000);

      expect(fingerprint.fingerprint, equals('abc123def456'));
      expect(fingerprint.fileSize, equals(1024000));
    });

    test('creates fingerprint with null fileSize', () {
      const fingerprint = ContentFingerprint(fingerprint: 'abc123def456');

      expect(fingerprint.fingerprint, equals('abc123def456'));
      expect(fingerprint.fileSize, isNull);
    });

    test('equality is based on fingerprint only', () {
      const fingerprint1 = ContentFingerprint(fingerprint: 'abc123', fileSize: 1024);

      const fingerprint2 = ContentFingerprint(
        fingerprint: 'abc123',
        fileSize: 2048, // Different size
      );

      const fingerprint3 = ContentFingerprint(
        fingerprint: 'xyz789', // Different fingerprint
        fileSize: 1024,
      );

      // Same fingerprint hash means equality
      expect(fingerprint1, equals(fingerprint2));
      // Different fingerprint hash means inequality
      expect(fingerprint1, isNot(equals(fingerprint3)));
    });

    test('hashCode is based on fingerprint', () {
      const fingerprint1 = ContentFingerprint(fingerprint: 'abc123', fileSize: 1024);

      const fingerprint2 = ContentFingerprint(fingerprint: 'abc123', fileSize: 2048);

      expect(fingerprint1.hashCode, equals(fingerprint2.hashCode));
    });

    test('toString includes fingerprint and fileSize', () {
      const fingerprint = ContentFingerprint(fingerprint: 'abc123def456', fileSize: 1024000);

      final string = fingerprint.toString();
      expect(string, contains('abc123def456'));
      expect(string, contains('1024000'));
    });

    test('toString works with null fileSize', () {
      const fingerprint = ContentFingerprint(fingerprint: 'abc123def456');

      final string = fingerprint.toString();
      expect(string, contains('abc123def456'));
      expect(string, isNot(contains('fileSize')));
    });
  });
}
