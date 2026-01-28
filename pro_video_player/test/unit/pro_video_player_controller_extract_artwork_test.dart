import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pro_video_player/pro_video_player.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

import '../shared/mocks.dart';
import '../shared/test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockProVideoPlayerPlatform mockPlatform;

  setUpAll(registerVideoPlayerFallbackValues);

  setUp(() {
    mockPlatform = MockProVideoPlayerPlatform();
    ProVideoPlayerPlatform.instance = mockPlatform;
  });

  group('ProVideoPlayerController.extractEmbeddedArtwork', () {
    test('returns artwork bytes when available', () async {
      final expectedArtwork = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]); // JPEG magic bytes

      when(() => mockPlatform.extractEmbeddedArtwork(any())).thenAnswer((_) async => expectedArtwork);

      final result = await ProVideoPlayerController.extractEmbeddedArtwork(
        const VideoSource.file('/path/to/movie.m4v'),
      );

      expect(result, isNotNull);
      expect(result, equals(expectedArtwork));

      verify(() => mockPlatform.extractEmbeddedArtwork(any())).called(1);
    });

    test('returns null when no artwork is embedded', () async {
      when(() => mockPlatform.extractEmbeddedArtwork(any())).thenAnswer((_) async => null);

      final result = await ProVideoPlayerController.extractEmbeddedArtwork(
        const VideoSource.file('/path/to/video.mp4'),
      );

      expect(result, isNull);
    });

    test('works with network source', () async {
      final artwork = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]); // PNG magic bytes

      when(() => mockPlatform.extractEmbeddedArtwork(any())).thenAnswer((_) async => artwork);

      final result = await ProVideoPlayerController.extractEmbeddedArtwork(
        const VideoSource.network('https://example.com/movie.m4v'),
      );

      expect(result, equals(artwork));

      final captured = verify(() => mockPlatform.extractEmbeddedArtwork(captureAny())).captured;
      expect(captured.first, isA<NetworkVideoSource>());
    });

    test('works with asset source', () async {
      final artwork = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE1]);

      when(() => mockPlatform.extractEmbeddedArtwork(any())).thenAnswer((_) async => artwork);

      final result = await ProVideoPlayerController.extractEmbeddedArtwork(
        const VideoSource.asset('assets/videos/movie.m4v'),
      );

      expect(result, equals(artwork));

      final captured = verify(() => mockPlatform.extractEmbeddedArtwork(captureAny())).captured;
      expect(captured.first, isA<AssetVideoSource>());
    });

    test('propagates platform exceptions', () async {
      when(() => mockPlatform.extractEmbeddedArtwork(any())).thenAnswer((_) async => throw Exception('Platform error'));

      await expectLater(
        ProVideoPlayerController.extractEmbeddedArtwork(const VideoSource.file('/invalid/path')),
        throwsA(isA<Exception>()),
      );
    });

    test('returns null for unsupported sources gracefully', () async {
      // Some platforms return null for sources they can't process (e.g., web)
      when(() => mockPlatform.extractEmbeddedArtwork(any())).thenAnswer((_) async => null);

      final result = await ProVideoPlayerController.extractEmbeddedArtwork(
        const VideoSource.network('https://streaming.example.com/live.m3u8'),
      );

      expect(result, isNull);
    });
  });

  group('ProVideoPlayerController.extractVideoFrame', () {
    test('returns frame bytes at position', () async {
      final expectedFrame = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);

      when(
        () => mockPlatform.extractVideoFrame(
          any(),
          position: any(named: 'position'),
          maxWidth: any(named: 'maxWidth'),
          maxHeight: any(named: 'maxHeight'),
          quality: any(named: 'quality'),
        ),
      ).thenAnswer((_) async => expectedFrame);

      final result = await ProVideoPlayerController.extractVideoFrame(
        const VideoSource.file('/path/to/video.mp4'),
        position: const Duration(seconds: 5),
      );

      expect(result, equals(expectedFrame));
    });

    test('returns null when frame extraction fails', () async {
      when(
        () => mockPlatform.extractVideoFrame(
          any(),
          position: any(named: 'position'),
          maxWidth: any(named: 'maxWidth'),
          maxHeight: any(named: 'maxHeight'),
          quality: any(named: 'quality'),
        ),
      ).thenAnswer((_) async => null);

      final result = await ProVideoPlayerController.extractVideoFrame(const VideoSource.file('/invalid/video.mp4'));

      expect(result, isNull);
    });

    test('passes parameters correctly', () async {
      when(
        () => mockPlatform.extractVideoFrame(
          any(),
          position: any(named: 'position'),
          maxWidth: any(named: 'maxWidth'),
          maxHeight: any(named: 'maxHeight'),
          quality: any(named: 'quality'),
        ),
      ).thenAnswer((_) async => Uint8List(0));

      await ProVideoPlayerController.extractVideoFrame(
        const VideoSource.file('/path/to/video.mp4'),
        position: const Duration(seconds: 10),
        maxWidth: 320,
        maxHeight: 180,
        quality: 90,
      );

      verify(
        () => mockPlatform.extractVideoFrame(
          any(),
          position: const Duration(seconds: 10),
          maxWidth: 320,
          maxHeight: 180,
          quality: 90,
        ),
      ).called(1);
    });
  });

  group('ProVideoPlayerController.extractThumbnail', () {
    test('returns embedded artwork when available', () async {
      final embeddedArtwork = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);

      when(
        () => mockPlatform.extractThumbnail(
          any(),
          position: any(named: 'position'),
          maxWidth: any(named: 'maxWidth'),
          maxHeight: any(named: 'maxHeight'),
          quality: any(named: 'quality'),
        ),
      ).thenAnswer((_) async => embeddedArtwork);

      final result = await ProVideoPlayerController.extractThumbnail(const VideoSource.file('/path/to/movie.m4v'));

      expect(result, equals(embeddedArtwork));
    });

    test('returns frame when no embedded artwork', () async {
      final frameData = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE1]);

      // extractThumbnail in platform interface calls extractEmbeddedArtwork first,
      // then falls back to extractVideoFrame. We mock the combined result.
      when(
        () => mockPlatform.extractThumbnail(
          any(),
          position: any(named: 'position'),
          maxWidth: any(named: 'maxWidth'),
          maxHeight: any(named: 'maxHeight'),
          quality: any(named: 'quality'),
        ),
      ).thenAnswer((_) async => frameData);

      final result = await ProVideoPlayerController.extractThumbnail(
        const VideoSource.file('/path/to/video.mp4'),
        position: const Duration(seconds: 5),
      );

      expect(result, equals(frameData));
    });

    test('returns null when both methods fail', () async {
      when(
        () => mockPlatform.extractThumbnail(
          any(),
          position: any(named: 'position'),
          maxWidth: any(named: 'maxWidth'),
          maxHeight: any(named: 'maxHeight'),
          quality: any(named: 'quality'),
        ),
      ).thenAnswer((_) async => null);

      final result = await ProVideoPlayerController.extractThumbnail(const VideoSource.file('/invalid/video'));

      expect(result, isNull);
    });
  });
}
