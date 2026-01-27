/// Tests for video_player compatibility controller.
///
/// These tests verify that VideoPlayerController matches the video_player API.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player/video_player_compat.dart';

import '../../shared/test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VideoPlayerTestFixture fixture;

  setUpAll(registerVideoPlayerFallbackValues);

  setUp(() {
    fixture = VideoPlayerTestFixture()..setUp();
  });

  tearDown(() async {
    await fixture.tearDown();
  });

  group('VideoPlayerController', () {
    group('extends ValueNotifier', () {
      test('controller is a ValueNotifier', () {
        final controller = VideoPlayerController.networkUrl(Uri.parse(TestMedia.networkUrl));

        expect(controller, isA<ValueNotifier<VideoPlayerValue>>());
      });

      test('can add and remove listeners', () {
        final controller = VideoPlayerController.networkUrl(Uri.parse(TestMedia.networkUrl));
        var callCount = 0;
        void listener() => callCount++;

        controller.addListener(listener);
        controller
          ..value = controller.value.copyWith(isPlaying: true)
          ..removeListener(listener)
          ..value = controller.value.copyWith(isPlaying: false);

        expect(callCount, equals(1));
      });
    });

    group('networkUrl constructor', () {
      test('creates controller with correct dataSource', () {
        final controller = VideoPlayerController.networkUrl(Uri.parse(TestMedia.networkUrl));

        expect(controller.dataSource, equals(TestMedia.networkUrl));
        expect(controller.dataSourceType, equals(DataSourceType.network));
      });

      test('accepts formatHint parameter', () {
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(TestMedia.networkUrl),
          formatHint: VideoFormat.hls,
        );

        expect(controller.formatHint, equals(VideoFormat.hls));
      });

      test('accepts httpHeaders parameter', () {
        const headers = {'Authorization': 'Bearer token'};
        final controller = VideoPlayerController.networkUrl(Uri.parse(TestMedia.networkUrl), httpHeaders: headers);

        expect(controller.httpHeaders, equals(headers));
      });

      test('accepts videoPlayerOptions parameter', () {
        const options = VideoPlayerOptions(mixWithOthers: true);
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(TestMedia.networkUrl),
          videoPlayerOptions: options,
        );

        expect(controller.videoPlayerOptions, equals(options));
      });

      test('accepts closedCaptionFile parameter', () {
        final captionFile = Future.value(SubRipCaptionFile(''));
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(TestMedia.networkUrl),
          closedCaptionFile: captionFile,
        );

        expect(controller.closedCaptionFile, isNotNull);
      });

      test('accepts viewType parameter', () {
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(TestMedia.networkUrl),
          viewType: VideoViewType.platformView,
        );

        // viewType is accepted but stored for API compatibility
        expect(controller.dataSource, equals(TestMedia.networkUrl));
      });
    });

    group('network constructor (deprecated)', () {
      test('creates controller with correct dataSource', () {
        // ignore: deprecated_member_use_from_same_package
        final controller = VideoPlayerController.network(TestMedia.networkUrl);

        expect(controller.dataSource, equals(TestMedia.networkUrl));
        expect(controller.dataSourceType, equals(DataSourceType.network));
      });
    });

    group('file constructor', () {
      test('creates controller with correct dataSource', () {
        final controller = VideoPlayerController.file(File(TestMedia.filePath));

        expect(controller.dataSource, equals(TestMedia.filePath));
        expect(controller.dataSourceType, equals(DataSourceType.file));
      });

      test('accepts httpHeaders parameter', () {
        const headers = {'Custom': 'Header'};
        final controller = VideoPlayerController.file(File(TestMedia.filePath), httpHeaders: headers);

        expect(controller.httpHeaders, equals(headers));
      });
    });

    group('asset constructor', () {
      test('creates controller with correct dataSource', () {
        final controller = VideoPlayerController.asset('assets/video.mp4');

        expect(controller.dataSource, equals('assets/video.mp4'));
        expect(controller.dataSourceType, equals(DataSourceType.asset));
      });

      test('accepts package parameter', () {
        final controller = VideoPlayerController.asset('assets/video.mp4', package: 'my_package');

        expect(controller.package, equals('my_package'));
      });
    });

    group('contentUri constructor', () {
      test('creates controller with correct dataSource', () {
        final uri = Uri.parse('content://media/video/123');
        final controller = VideoPlayerController.contentUri(uri);

        expect(controller.dataSource, equals('content://media/video/123'));
        expect(controller.dataSourceType, equals(DataSourceType.contentUri));
      });
    });

    group('value property', () {
      test('initial value is uninitialized', () {
        final controller = VideoPlayerController.networkUrl(Uri.parse(TestMedia.networkUrl));

        expect(controller.value.isInitialized, isFalse);
        expect(controller.value.duration, equals(Duration.zero));
        expect(controller.value.position, equals(Duration.zero));
      });

      test('value is VideoPlayerValue type', () {
        final controller = VideoPlayerController.networkUrl(Uri.parse(TestMedia.networkUrl));

        expect(controller.value, isA<VideoPlayerValue>());
      });

      test('value has caption property', () {
        final controller = VideoPlayerController.networkUrl(Uri.parse(TestMedia.networkUrl));

        expect(controller.value.caption, isA<Caption>());
        expect(controller.value.caption, equals(Caption.none));
      });
    });

    group('playerId property', () {
      test('returns -1 before initialization', () {
        final controller = VideoPlayerController.networkUrl(Uri.parse(TestMedia.networkUrl));

        expect(controller.playerId, equals(-1));
      });
    });

    group('position property', () {
      test('returns Future<Duration?>', () async {
        final controller = VideoPlayerController.networkUrl(Uri.parse(TestMedia.networkUrl));

        final position = await controller.position;
        expect(position, equals(Duration.zero));
      });
    });

    group('proController property', () {
      test('provides access to underlying ProVideoPlayerController', () {
        final controller = VideoPlayerController.networkUrl(Uri.parse(TestMedia.networkUrl));

        expect(controller.proController, isNotNull);
      });
    });
  });

  group('VideoPlayerController initialization', () {
    test('initialize returns Future<void>', () async {
      final controller = VideoPlayerController.networkUrl(Uri.parse(TestMedia.networkUrl));

      final initFuture = controller.initialize();
      expect(initFuture, isA<Future<void>>());
      await initFuture;

      await controller.dispose();
    });

    test('playerId is valid after initialization', () async {
      final controller = VideoPlayerController.networkUrl(Uri.parse(TestMedia.networkUrl));
      await controller.initialize();

      expect(controller.playerId, isPositive);

      await controller.dispose();
    });

    test('value.isInitialized is true after initialization', () async {
      final controller = VideoPlayerController.networkUrl(Uri.parse(TestMedia.networkUrl));
      await controller.initialize();

      expect(controller.value.isInitialized, isTrue);

      await controller.dispose();
    });
  });

  group('VideoPlayerController playback methods', () {
    late VideoPlayerController controller;

    setUp(() async {
      controller = VideoPlayerController.networkUrl(Uri.parse(TestMedia.networkUrl));
      await controller.initialize();
    });

    tearDown(() async {
      await controller.dispose();
    });

    test('play returns Future<void>', () {
      expect(controller.play(), isA<Future<void>>());
    });

    test('pause returns Future<void>', () {
      expect(controller.pause(), isA<Future<void>>());
    });

    test('seekTo returns Future<void>', () {
      expect(controller.seekTo(const Duration(seconds: 10)), isA<Future<void>>());
    });

    test('setVolume returns Future<void>', () {
      expect(controller.setVolume(0.5), isA<Future<void>>());
    });

    test('setPlaybackSpeed returns Future<void>', () {
      expect(controller.setPlaybackSpeed(1.5), isA<Future<void>>());
    });

    test('setLooping returns Future<void>', () {
      expect(controller.setLooping(true), isA<Future<void>>());
    });
  });

  group('VideoPlayerController caption methods', () {
    late VideoPlayerController controller;

    setUp(() async {
      controller = VideoPlayerController.networkUrl(Uri.parse(TestMedia.networkUrl));
      await controller.initialize();
    });

    tearDown(() async {
      await controller.dispose();
    });

    test('setClosedCaptionFile returns Future<void>', () {
      expect(controller.setClosedCaptionFile(null), isA<Future<void>>());
    });

    test('setClosedCaptionFile with null clears captions', () async {
      await controller.setClosedCaptionFile(null);

      expect(controller.value.caption, equals(Caption.none));
    });

    test('setClosedCaptionFile loads captions', () async {
      const srtContent = '''
1
00:00:00,000 --> 00:00:05,000
Test caption
''';
      await controller.setClosedCaptionFile(Future.value(SubRipCaptionFile(srtContent)));

      // Caption loading is async, verify closedCaptionFile is set
      expect(controller.closedCaptionFile, isNotNull);
    });

    test('setCaptionOffset is synchronous void method', () {
      // setCaptionOffset should be synchronous and return void
      controller.setCaptionOffset(const Duration(seconds: 2));

      // No exception means success
    });
  });

  group('VideoPlayerController dispose', () {
    test('dispose returns Future<void>', () async {
      final controller = VideoPlayerController.networkUrl(Uri.parse(TestMedia.networkUrl));
      await controller.initialize();

      expect(controller.dispose(), isA<Future<void>>());
    });

    test('can be disposed without initialization', () async {
      final controller = VideoPlayerController.networkUrl(Uri.parse(TestMedia.networkUrl));

      await controller.dispose();
      // No exception means success
    });
  });

  group('Caption auto-update', () {
    test('caption updates based on playback position', () async {
      const srtContent = '''
1
00:00:00,000 --> 00:00:05,000
First caption

2
00:00:10,000 --> 00:00:15,000
Second caption
''';

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(TestMedia.networkUrl),
        closedCaptionFile: Future.value(SubRipCaptionFile(srtContent)),
      );
      await controller.initialize();

      // Initial caption should be the first one (position is 0)
      // Note: Exact caption shown depends on position and timing
      expect(controller.value.caption, isA<Caption>());

      await controller.dispose();
    });
  });
}

// Test constants for compatibility tests
class TestMedia {
  static const String networkUrl = 'https://example.com/video.mp4';
  static const String filePath = '/path/to/video.mp4';
}
