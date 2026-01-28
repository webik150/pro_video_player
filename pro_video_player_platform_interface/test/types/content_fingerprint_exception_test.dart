import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

void main() {
  group('ContentFingerprintException', () {
    test('creates exception with code and message', () {
      const exception = ContentFingerprintException('FILE_NOT_FOUND', 'File does not exist');

      expect(exception.code, equals('FILE_NOT_FOUND'));
      expect(exception.message, equals('File does not exist'));
    });

    test('implements Exception interface', () {
      const exception = ContentFingerprintException('EXTRACTION_FAILED', 'Failed to extract fingerprint');

      expect(exception, isA<Exception>());
    });

    test('can be thrown and caught', () {
      expect(
        () => throw const ContentFingerprintException('TEST_ERROR', 'Test message'),
        throwsA(isA<ContentFingerprintException>()),
      );
    });

    test('toString includes code and message', () {
      const exception = ContentFingerprintException('NETWORK_ERROR', 'Connection refused');

      final string = exception.toString();
      expect(string, contains('NETWORK_ERROR'));
      expect(string, contains('Connection refused'));
    });

    test('equality works correctly', () {
      const exception1 = ContentFingerprintException('CODE', 'message');
      const exception2 = ContentFingerprintException('CODE', 'message');
      const exception3 = ContentFingerprintException('OTHER', 'message');

      expect(exception1, equals(exception2));
      expect(exception1, isNot(equals(exception3)));
    });

    test('hashCode works correctly', () {
      const exception1 = ContentFingerprintException('CODE', 'message');
      const exception2 = ContentFingerprintException('CODE', 'message');

      expect(exception1.hashCode, equals(exception2.hashCode));
    });

    test('common error codes', () {
      // Document common error codes through tests
      const invalidSource = ContentFingerprintException('INVALID_SOURCE', 'The video source is invalid');
      expect(invalidSource.code, equals('INVALID_SOURCE'));

      const fileNotFound = ContentFingerprintException('FILE_NOT_FOUND', 'File does not exist');
      expect(fileNotFound.code, equals('FILE_NOT_FOUND'));

      const networkError = ContentFingerprintException('NETWORK_ERROR', 'Network connection failed');
      expect(networkError.code, equals('NETWORK_ERROR'));

      const rangeNotSupported = ContentFingerprintException(
        'RANGE_NOT_SUPPORTED',
        'Server does not support Range requests',
      );
      expect(rangeNotSupported.code, equals('RANGE_NOT_SUPPORTED'));

      const fileTooSmall = ContentFingerprintException('FILE_TOO_SMALL', 'File is too small for sampling');
      expect(fileTooSmall.code, equals('FILE_TOO_SMALL'));

      const extractionFailed = ContentFingerprintException('EXTRACTION_FAILED', 'General extraction failure');
      expect(extractionFailed.code, equals('EXTRACTION_FAILED'));
    });
  });
}
