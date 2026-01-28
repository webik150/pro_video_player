import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pro_video_player/pro_video_player.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

import '../shared/mocks.dart';
import '../shared/test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockProVideoPlayerPlatform mockPlatform;
  late StreamController<VideoPlayerEvent> eventController;

  setUpAll(registerVideoPlayerFallbackValues);

  setUp(() {
    mockPlatform = MockProVideoPlayerPlatform();
    eventController = StreamController<VideoPlayerEvent>.broadcast();
    ProVideoPlayerPlatform.instance = mockPlatform;

    // Default stubs for player lifecycle
    when(
      () => mockPlatform.create(
        source: any(named: 'source'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => 1);
    when(() => mockPlatform.events(any())).thenAnswer((_) => eventController.stream);
    when(() => mockPlatform.dispose(any())).thenAnswer((_) async {});
    when(() => mockPlatform.getVideoMetadata(any())).thenAnswer((_) async => null);

    // Stub extractMetadata to call the real implementation via the underlying methods
    when(() => mockPlatform.extractMetadata(any(), timeout: any(named: 'timeout'))).thenAnswer((invocation) async {
      final source = invocation.positionalArguments[0] as VideoSource;
      final timeout = invocation.namedArguments[#timeout] as Duration? ?? const Duration(seconds: 30);

      // Create player
      final playerId = await mockPlatform.create(source: source);

      StreamSubscription<VideoPlayerEvent>? subscription;
      try {
        final completer = Completer<VideoMetadata>();

        subscription = mockPlatform.events(playerId).listen((event) {
          if (event is VideoMetadataExtractedEvent) {
            if (!completer.isCompleted) {
              completer.complete(event.metadata);
            }
          } else if (event is ErrorEvent) {
            if (!completer.isCompleted) {
              completer.completeError(MetadataExtractionException(event.code ?? 'ERROR', event.message));
            }
          }
        });

        // Check for existing metadata
        final existingMetadata = await mockPlatform.getVideoMetadata(playerId);
        if (existingMetadata != null && existingMetadata.isNotEmpty && !completer.isCompleted) {
          completer.complete(existingMetadata);
        }

        return await completer.future.timeout(
          timeout,
          onTimeout: () => throw MetadataExtractionException(
            'TIMEOUT',
            'Metadata extraction timed out after ${timeout.inSeconds} seconds',
          ),
        );
      } finally {
        await subscription?.cancel();
        await mockPlatform.dispose(playerId);
      }
    });
  });

  tearDown(() async {
    await eventController.close();
  });

  group('ProVideoPlayerController.extractMetadata', () {
    test('returns metadata when VideoMetadataExtractedEvent is received', () async {
      const expectedMetadata = VideoMetadata(
        width: 1920,
        height: 1080,
        duration: Duration(minutes: 5),
        videoCodec: 'h264',
        audioCodec: 'aac',
        videoBitrate: 5000000,
        frameRate: 30,
      );

      // Emit metadata event after a short delay (simulating async native extraction)
      Future.delayed(const Duration(milliseconds: 10), () {
        if (!eventController.isClosed) {
          eventController.add(const VideoMetadataExtractedEvent(expectedMetadata));
        }
      });

      final result = await ProVideoPlayerController.extractMetadata(
        const VideoSource.network('https://example.com/video.mp4'),
      );

      expect(result.width, equals(1920));
      expect(result.height, equals(1080));
      expect(result.duration, equals(const Duration(minutes: 5)));
      expect(result.videoCodec, equals('h264'));
      expect(result.audioCodec, equals('aac'));
      expect(result.videoBitrate, equals(5000000));
      expect(result.frameRate, equals(30.0));

      // Verify player was created and disposed
      verify(
        () => mockPlatform.create(
          source: any(named: 'source'),
          options: any(named: 'options'),
        ),
      ).called(1);
      verify(() => mockPlatform.dispose(1)).called(1);
    });

    test('returns metadata from getVideoMetadata if already available', () async {
      const existingMetadata = VideoMetadata(
        width: 1280,
        height: 720,
        duration: Duration(seconds: 30),
        videoCodec: 'hevc',
      );

      when(() => mockPlatform.getVideoMetadata(any())).thenAnswer((_) async => existingMetadata);

      final result = await ProVideoPlayerController.extractMetadata(const VideoSource.file('/path/to/video.mp4'));

      expect(result.width, equals(1280));
      expect(result.height, equals(720));
      expect(result.videoCodec, equals('hevc'));

      // Verify player was disposed
      verify(() => mockPlatform.dispose(1)).called(1);
    });

    test('throws MetadataExtractionException on timeout', () async {
      // Don't emit any events - should timeout
      await expectLater(
        ProVideoPlayerController.extractMetadata(
          const VideoSource.network('https://example.com/video.mp4'),
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(
          isA<MetadataExtractionException>()
              .having((e) => e.code, 'code', equals('TIMEOUT'))
              .having((e) => e.message, 'message', contains('timed out')),
        ),
      );

      // Verify cleanup happened
      verify(() => mockPlatform.dispose(1)).called(1);
    });

    test('throws MetadataExtractionException on ErrorEvent', () async {
      // Emit error event after a short delay
      Future.delayed(const Duration(milliseconds: 10), () {
        if (!eventController.isClosed) {
          eventController.add(ErrorEvent('Video format not supported', code: 'UNSUPPORTED_FORMAT'));
        }
      });

      await expectLater(
        ProVideoPlayerController.extractMetadata(const VideoSource.network('https://example.com/video.mp4')),
        throwsA(
          isA<MetadataExtractionException>()
              .having((e) => e.code, 'code', equals('UNSUPPORTED_FORMAT'))
              .having((e) => e.message, 'message', equals('Video format not supported')),
        ),
      );

      // Verify cleanup happened
      verify(() => mockPlatform.dispose(1)).called(1);
    });

    test('throws MetadataExtractionException when player creation fails', () async {
      when(
        () => mockPlatform.create(
          source: any(named: 'source'),
          options: any(named: 'options'),
        ),
      ).thenThrow(Exception('Failed to create player'));

      // Need to re-stub extractMetadata to propagate the error
      when(() => mockPlatform.extractMetadata(any(), timeout: any(named: 'timeout'))).thenAnswer((invocation) async {
        final source = invocation.positionalArguments[0] as VideoSource;
        try {
          await mockPlatform.create(source: source);
          throw StateError('Should not reach here');
        } catch (e) {
          throw MetadataExtractionException('EXTRACTION_FAILED', 'Failed to extract metadata: $e');
        }
      });

      await expectLater(
        ProVideoPlayerController.extractMetadata(const VideoSource.network('https://invalid-url')),
        throwsA(isA<MetadataExtractionException>().having((e) => e.code, 'code', equals('EXTRACTION_FAILED'))),
      );
    });

    test('works with file source', () async {
      const metadata = VideoMetadata(width: 1920, height: 1080);

      Future.delayed(const Duration(milliseconds: 10), () {
        if (!eventController.isClosed) {
          eventController.add(const VideoMetadataExtractedEvent(metadata));
        }
      });

      final result = await ProVideoPlayerController.extractMetadata(const VideoSource.file('/path/to/local/video.mp4'));

      expect(result.width, equals(1920));

      // Verify correct source type was passed
      final captured = verify(
        () => mockPlatform.create(
          source: captureAny(named: 'source'),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured.first, isA<FileVideoSource>());
    });

    test('works with asset source', () async {
      const metadata = VideoMetadata(width: 640, height: 480);

      Future.delayed(const Duration(milliseconds: 10), () {
        if (!eventController.isClosed) {
          eventController.add(const VideoMetadataExtractedEvent(metadata));
        }
      });

      final result = await ProVideoPlayerController.extractMetadata(
        const VideoSource.asset('assets/videos/sample.mp4'),
      );

      expect(result.width, equals(640));

      // Verify correct source type was passed
      final captured = verify(
        () => mockPlatform.create(
          source: captureAny(named: 'source'),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured.first, isA<AssetVideoSource>());
    });

    test('uses custom timeout parameter', () async {
      // This test verifies the timeout parameter is respected
      // We set a very short timeout and expect it to fail quickly
      final stopwatch = Stopwatch()..start();

      try {
        await ProVideoPlayerController.extractMetadata(
          const VideoSource.network('https://example.com/video.mp4'),
          timeout: const Duration(milliseconds: 30),
        );
        fail('Should have thrown');
      } on MetadataExtractionException catch (e) {
        stopwatch.stop();
        expect(e.code, equals('TIMEOUT'));
        // Should timeout around 30ms, allow some margin
        expect(stopwatch.elapsedMilliseconds, lessThan(200));
      }
    });
  });

  group('MetadataExtractionException', () {
    test('has correct toString format', () {
      const exception = MetadataExtractionException('TEST_CODE', 'Test message');
      expect(exception.toString(), equals('MetadataExtractionException(TEST_CODE): Test message'));
    });

    test('equality works correctly', () {
      const e1 = MetadataExtractionException('CODE', 'message');
      const e2 = MetadataExtractionException('CODE', 'message');
      const e3 = MetadataExtractionException('OTHER', 'message');

      expect(e1, equals(e2));
      expect(e1, isNot(equals(e3)));
      expect(e1.hashCode, equals(e2.hashCode));
    });
  });
}
