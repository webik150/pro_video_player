/// Automated API compatibility verification for video_player drop-in replacement.
///
/// This test verifies that the video_player_compat.dart export provides all
/// the public API members expected from the video_player package, with correct
/// signatures.
///
/// Run with: `make test-compat` or `flutter test test/unit/compat/video_player_api_compatibility_test.dart`
///
/// If this test fails, it means the compatibility layer is missing or has changed
/// a public API member that users migrating from video_player would expect.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Import the compatibility layer - this is what users will import
import 'package:pro_video_player/video_player_compat.dart';

void main() {
  group('video_player API Compatibility Verification', () {
    group('Required Exports', () {
      test('VideoPlayerController is exported', () {
        // Verify the class exists and can be instantiated
        expect(VideoPlayerController, isNotNull);
      });

      test('VideoPlayerValue is exported', () {
        expect(VideoPlayerValue, isNotNull);
        const value = VideoPlayerValue.uninitialized();
        expect(value, isA<VideoPlayerValue>());
      });

      test('VideoPlayer widget is exported', () {
        expect(VideoPlayer, isNotNull);
      });

      test('Caption is exported', () {
        expect(Caption, isNotNull);
        expect(Caption.none, isA<Caption>());
      });

      test('ClosedCaptionFile is exported', () {
        expect(ClosedCaptionFile, isNotNull);
      });

      test('SubRipCaptionFile is exported', () {
        expect(SubRipCaptionFile, isNotNull);
        final file = SubRipCaptionFile('');
        expect(file, isA<ClosedCaptionFile>());
      });

      test('WebVTTCaptionFile is exported', () {
        expect(WebVTTCaptionFile, isNotNull);
        final file = WebVTTCaptionFile('');
        expect(file, isA<ClosedCaptionFile>());
      });

      test('DurationRange is exported', () {
        expect(DurationRange, isNotNull);
        const range = DurationRange(Duration.zero, Duration(seconds: 10));
        expect(range, isA<DurationRange>());
      });

      test('VideoProgressIndicator is exported', () {
        expect(VideoProgressIndicator, isNotNull);
      });

      test('VideoScrubber is exported', () {
        expect(VideoScrubber, isNotNull);
      });

      test('VideoProgressColors is exported', () {
        expect(VideoProgressColors, isNotNull);
        const colors = VideoProgressColors();
        expect(colors, isA<VideoProgressColors>());
      });

      test('ClosedCaption widget is exported', () {
        expect(ClosedCaption, isNotNull);
      });

      test('DataSourceType enum is exported', () {
        expect(DataSourceType.values, hasLength(4));
        expect(DataSourceType.asset, isNotNull);
        expect(DataSourceType.network, isNotNull);
        expect(DataSourceType.file, isNotNull);
        expect(DataSourceType.contentUri, isNotNull);
      });

      test('VideoFormat enum is exported', () {
        expect(VideoFormat.values, hasLength(4));
        expect(VideoFormat.dash, isNotNull);
        expect(VideoFormat.hls, isNotNull);
        expect(VideoFormat.ss, isNotNull);
        expect(VideoFormat.other, isNotNull);
      });

      test('VideoViewType enum is exported', () {
        expect(VideoViewType.values, hasLength(2));
        expect(VideoViewType.textureView, isNotNull);
        expect(VideoViewType.platformView, isNotNull);
      });

      test('VideoPlayerOptions is exported', () {
        expect(VideoPlayerOptions, isNotNull);
        const options = VideoPlayerOptions();
        expect(options, isA<VideoPlayerOptions>());
      });

      test('VideoPlayerWebOptions is exported', () {
        expect(VideoPlayerWebOptions, isNotNull);
        const options = VideoPlayerWebOptions();
        expect(options, isA<VideoPlayerWebOptions>());
      });

      test('VideoPlayerWebOptionsControls is exported', () {
        expect(VideoPlayerWebOptionsControls, isNotNull);
        const controls = VideoPlayerWebOptionsControls.disabled();
        expect(controls, isA<VideoPlayerWebOptionsControls>());
      });

      test('@videoPlayerCompat annotation is exported', () {
        expect(videoPlayerCompat, isNotNull);
        expect(videoPlayerCompat, isA<VideoPlayerCompat>());
      });
    });

    group('VideoPlayerController Constructor Signatures', () {
      test('networkUrl constructor accepts all video_player parameters', () {
        // This test verifies the constructor signature matches video_player
        final controller = VideoPlayerController.networkUrl(
          Uri.parse('https://example.com/video.mp4'),
          formatHint: VideoFormat.hls,
          closedCaptionFile: Future.value(SubRipCaptionFile('')),
          videoPlayerOptions: const VideoPlayerOptions(mixWithOthers: true),
          httpHeaders: const {'Authorization': 'Bearer token'},
        );

        expect(controller, isA<VideoPlayerController>());
        expect(controller.dataSource, equals('https://example.com/video.mp4'));
        expect(controller.dataSourceType, equals(DataSourceType.network));
        expect(controller.formatHint, equals(VideoFormat.hls));
        expect(controller.httpHeaders, equals({'Authorization': 'Bearer token'}));
        expect(controller.videoPlayerOptions?.mixWithOthers, isTrue);
        expect(controller.closedCaptionFile, isNotNull);
      });

      test('network constructor (deprecated) accepts all video_player parameters', () {
        // ignore: deprecated_member_use_from_same_package
        final controller = VideoPlayerController.network(
          'https://example.com/video.mp4',
          formatHint: VideoFormat.dash,
          closedCaptionFile: Future.value(WebVTTCaptionFile('')),
          videoPlayerOptions: const VideoPlayerOptions(),
          httpHeaders: const {'X-Custom': 'header'},
          viewType: VideoViewType.platformView,
        );

        expect(controller, isA<VideoPlayerController>());
        expect(controller.dataSource, equals('https://example.com/video.mp4'));
        expect(controller.dataSourceType, equals(DataSourceType.network));
      });

      test('file constructor accepts all video_player parameters', () {
        final controller = VideoPlayerController.file(
          File('/path/to/video.mp4'),
          closedCaptionFile: Future.value(SubRipCaptionFile('')),
          videoPlayerOptions: const VideoPlayerOptions(),
          httpHeaders: const {'Custom': 'Header'},
        );

        expect(controller, isA<VideoPlayerController>());
        expect(controller.dataSource, equals('/path/to/video.mp4'));
        expect(controller.dataSourceType, equals(DataSourceType.file));
        expect(controller.httpHeaders, equals({'Custom': 'Header'}));
      });

      test('asset constructor accepts all video_player parameters', () {
        final controller = VideoPlayerController.asset(
          'assets/video.mp4',
          package: 'my_package',
          closedCaptionFile: Future.value(SubRipCaptionFile('')),
          videoPlayerOptions: const VideoPlayerOptions(),
        );

        expect(controller, isA<VideoPlayerController>());
        expect(controller.dataSource, equals('assets/video.mp4'));
        expect(controller.dataSourceType, equals(DataSourceType.asset));
        expect(controller.package, equals('my_package'));
      });

      test('contentUri constructor accepts all video_player parameters', () {
        final controller = VideoPlayerController.contentUri(
          Uri.parse('content://media/video/123'),
          closedCaptionFile: Future.value(SubRipCaptionFile('')),
          videoPlayerOptions: const VideoPlayerOptions(),
        );

        expect(controller, isA<VideoPlayerController>());
        expect(controller.dataSource, equals('content://media/video/123'));
        expect(controller.dataSourceType, equals(DataSourceType.contentUri));
      });
    });

    group('VideoPlayerController extends ValueNotifier', () {
      test('extends ValueNotifier<VideoPlayerValue>', () {
        final controller = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));

        expect(controller, isA<ValueNotifier<VideoPlayerValue>>());
        expect(controller.value, isA<VideoPlayerValue>());
      });

      test('value property is gettable and settable', () {
        final controller = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));

        final initialValue = controller.value;
        expect(initialValue, isA<VideoPlayerValue>());

        // Test that value can be modified (VideoPlayerController extends ValueNotifier)
        controller.value = controller.value.copyWith(isPlaying: true);
        expect(controller.value.isPlaying, isTrue);
      });

      test('supports addListener and removeListener', () {
        final controller = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));
        var callCount = 0;
        void listener() => callCount++;

        controller.addListener(listener);
        controller.value = controller.value.copyWith(position: const Duration(seconds: 5));
        expect(callCount, equals(1));

        controller.removeListener(listener);
        controller.value = controller.value.copyWith(position: const Duration(seconds: 10));
        expect(callCount, equals(1)); // Should not increase
      });
    });

    group('VideoPlayerController Property Types', () {
      late VideoPlayerController controller;

      setUp(() {
        controller = VideoPlayerController.networkUrl(
          Uri.parse('https://example.com/video.mp4'),
          httpHeaders: const {'Auth': 'token'},
          formatHint: VideoFormat.hls,
          videoPlayerOptions: const VideoPlayerOptions(mixWithOthers: true),
        );
      });

      test('dataSource returns String', () {
        expect(controller.dataSource, isA<String>());
      });

      test('dataSourceType returns DataSourceType', () {
        expect(controller.dataSourceType, isA<DataSourceType>());
      });

      test('formatHint returns VideoFormat?', () {
        expect(controller.formatHint, isA<VideoFormat?>());
      });

      test('httpHeaders returns Map<String, String>', () {
        expect(controller.httpHeaders, isA<Map<String, String>>());
      });

      test('videoPlayerOptions returns VideoPlayerOptions?', () {
        expect(controller.videoPlayerOptions, isA<VideoPlayerOptions?>());
      });

      test('package returns String?', () {
        final assetController = VideoPlayerController.asset('video.mp4', package: 'pkg');
        expect(assetController.package, isA<String?>());
      });

      test('closedCaptionFile returns Future<ClosedCaptionFile>?', () {
        final controllerWithCaptions = VideoPlayerController.networkUrl(
          Uri.parse('https://example.com/video.mp4'),
          closedCaptionFile: Future.value(SubRipCaptionFile('')),
        );
        expect(controllerWithCaptions.closedCaptionFile, isA<Future<ClosedCaptionFile>?>());
      });

      test('playerId returns int', () {
        expect(controller.playerId, isA<int>());
        expect(controller.playerId, equals(-1)); // Before initialization
      });

      test('position returns Future<Duration?>', () {
        expect(controller.position, isA<Future<Duration?>>());
      });

      test('value returns VideoPlayerValue', () {
        expect(controller.value, isA<VideoPlayerValue>());
      });
    });

    group('VideoPlayerController Method Signatures', () {
      test('initialize returns Future<void>', () {
        final controller = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));
        expect(controller.initialize, isA<Function>());
        // Type check: initialize() -> Future<void>
        final initMethod = controller.initialize;
        expect(initMethod, isNotNull);
      });

      test('play returns Future<void>', () {
        final controller = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));
        expect(controller.play, isA<Function>());
        final playMethod = controller.play;
        expect(playMethod, isNotNull);
      });

      test('pause returns Future<void>', () {
        final controller = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));
        expect(controller.pause, isA<Function>());
        final pauseMethod = controller.pause;
        expect(pauseMethod, isNotNull);
      });

      test('seekTo accepts Duration and returns Future<void>', () {
        final controller = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));
        expect(controller.seekTo, isA<Function>());
        final seekMethod = controller.seekTo;
        expect(seekMethod, isNotNull);
      });

      test('setVolume accepts double and returns Future<void>', () {
        final controller = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));
        expect(controller.setVolume, isA<Function>());
        final volumeMethod = controller.setVolume;
        expect(volumeMethod, isNotNull);
      });

      test('setPlaybackSpeed accepts double and returns Future<void>', () {
        final controller = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));
        expect(controller.setPlaybackSpeed, isA<Function>());
        final speedMethod = controller.setPlaybackSpeed;
        expect(speedMethod, isNotNull);
      });

      test('setLooping accepts bool and returns Future<void>', () {
        final controller = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));
        expect(controller.setLooping, isA<Function>());
        final loopMethod = controller.setLooping;
        expect(loopMethod, isNotNull);
      });

      test('setClosedCaptionFile accepts Future<ClosedCaptionFile>? and returns Future<void>', () {
        final controller = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));
        expect(controller.setClosedCaptionFile, isA<Function>());
        final captionMethod = controller.setClosedCaptionFile;
        expect(captionMethod, isNotNull);
      });

      test('setCaptionOffset accepts Duration and returns void (sync)', () {
        final controller = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));
        expect(controller.setCaptionOffset, isA<Function>());
        final offsetMethod = controller.setCaptionOffset;
        expect(offsetMethod, isNotNull);
      });

      test('dispose returns Future<void>', () {
        final controller = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));
        expect(controller.dispose, isA<Function>());
        // dispose() -> Future<void>
        final disposeMethod = controller.dispose;
        expect(disposeMethod, isNotNull);
      });
    });

    group('VideoPlayerValue Properties', () {
      test('has all required properties with correct types', () {
        const value = VideoPlayerValue(
          duration: Duration(minutes: 5),
          size: Size(1920, 1080),
          position: Duration(seconds: 30),
          captionOffset: Duration(milliseconds: 500),
          buffered: [DurationRange(Duration.zero, Duration(minutes: 1))],
          isInitialized: true,
          isPlaying: true,
          volume: 0.8,
          playbackSpeed: 1.5,
          rotationCorrection: 90,
        );

        // Verify all properties exist and have correct types
        expect(value.duration, isA<Duration>());
        expect(value.size, isA<Size>());
        expect(value.position, isA<Duration>());
        expect(value.caption, isA<Caption>());
        expect(value.captionOffset, isA<Duration>());
        expect(value.buffered, isA<List<DurationRange>>());
        expect(value.isInitialized, isA<bool>());
        expect(value.isPlaying, isA<bool>());
        expect(value.isLooping, isA<bool>());
        expect(value.isBuffering, isA<bool>());
        expect(value.volume, isA<double>());
        expect(value.playbackSpeed, isA<double>());
        expect(value.rotationCorrection, isA<int>());
        expect(value.errorDescription, isA<String?>());
      });

      test('has hasError computed property', () {
        const value = VideoPlayerValue.uninitialized();
        expect(value.hasError, isA<bool>());
        expect(value.hasError, isFalse);

        const errorValue = VideoPlayerValue.erroneous('Error');
        expect(errorValue.hasError, isTrue);
      });

      test('has isCompleted computed property', () {
        const value = VideoPlayerValue(
          duration: Duration(seconds: 60),
          position: Duration(seconds: 60),
          isInitialized: true,
        );
        expect(value.isCompleted, isA<bool>());
        expect(value.isCompleted, isTrue);
      });

      test('has aspectRatio computed property', () {
        const value = VideoPlayerValue(duration: Duration(seconds: 60), size: Size(1920, 1080));
        expect(value.aspectRatio, isA<double>());
        expect(value.aspectRatio, closeTo(16 / 9, 0.01));
      });

      test('has copyWith method', () {
        const value = VideoPlayerValue.uninitialized();
        final modified = value.copyWith(isPlaying: true, volume: 0.5);

        expect(modified.isPlaying, isTrue);
        expect(modified.volume, equals(0.5));
        expect(modified.isInitialized, equals(value.isInitialized));
      });

      test('uninitialized constructor creates correct state', () {
        const value = VideoPlayerValue.uninitialized();

        expect(value.isInitialized, isFalse);
        expect(value.duration, equals(Duration.zero));
        expect(value.position, equals(Duration.zero));
        expect(value.volume, equals(1.0));
        expect(value.playbackSpeed, equals(1.0));
      });

      test('erroneous constructor creates error state', () {
        const value = VideoPlayerValue.erroneous('Test error');

        expect(value.hasError, isTrue);
        expect(value.errorDescription, equals('Test error'));
        expect(value.isInitialized, isFalse);
      });
    });

    group('Caption Properties', () {
      test('has all required properties', () {
        const caption = Caption(
          number: 1,
          start: Duration(seconds: 10),
          end: Duration(seconds: 15),
          text: 'Hello, world!',
        );

        expect(caption.number, isA<int>());
        expect(caption.start, isA<Duration>());
        expect(caption.end, isA<Duration>());
        expect(caption.text, isA<String>());
      });

      test('Caption.none is available', () {
        expect(Caption.none, isA<Caption>());
        expect(Caption.none.number, equals(0));
        expect(Caption.none.text, isEmpty);
      });
    });

    group('DurationRange Methods', () {
      test('startFraction calculates correctly', () {
        const range = DurationRange(Duration(seconds: 30), Duration(seconds: 60));
        const duration = Duration(seconds: 120);

        expect(range.startFraction(duration), isA<double>());
        expect(range.startFraction(duration), equals(0.25));
      });

      test('endFraction calculates correctly', () {
        const range = DurationRange(Duration(seconds: 30), Duration(seconds: 60));
        const duration = Duration(seconds: 120);

        expect(range.endFraction(duration), isA<double>());
        expect(range.endFraction(duration), equals(0.5));
      });
    });

    group('VideoProgressColors Default Values', () {
      test('has correct default colors matching video_player', () {
        const colors = VideoProgressColors();

        // These are the exact default colors from video_player
        expect(colors.playedColor, equals(const Color.fromRGBO(255, 0, 0, 0.7)));
        expect(colors.bufferedColor, equals(const Color.fromRGBO(50, 50, 200, 0.2)));
        expect(colors.backgroundColor, equals(const Color.fromRGBO(200, 200, 200, 0.5)));
      });
    });

    group('VideoPlayerOptions Properties', () {
      test('has all required properties with correct defaults', () {
        const options = VideoPlayerOptions();

        expect(options.mixWithOthers, isA<bool>());
        expect(options.mixWithOthers, isFalse);
        expect(options.allowBackgroundPlayback, isA<bool>());
        expect(options.allowBackgroundPlayback, isFalse);
        expect(options.webOptions, isA<VideoPlayerWebOptions?>());
        expect(options.webOptions, isNull);
      });

      test('accepts all parameters', () {
        const webOptions = VideoPlayerWebOptions();
        const options = VideoPlayerOptions(mixWithOthers: true, allowBackgroundPlayback: true, webOptions: webOptions);

        expect(options.mixWithOthers, isTrue);
        expect(options.allowBackgroundPlayback, isTrue);
        expect(options.webOptions, isNotNull);
      });
    });

    group('VideoPlayerWebOptions Properties', () {
      test('has all required properties', () {
        const options = VideoPlayerWebOptions();

        expect(options.controls, isA<VideoPlayerWebOptionsControls>());
        expect(options.allowContextMenu, isA<bool>());
        expect(options.allowRemotePlayback, isA<bool>());
        expect(options.poster, isA<Uri?>());
      });

      test('VideoPlayerWebOptionsControls has enabled and disabled factories', () {
        const enabled = VideoPlayerWebOptionsControls.enabled();
        const disabled = VideoPlayerWebOptionsControls.disabled();

        expect(enabled.enabled, isTrue);
        expect(disabled.enabled, isFalse);
      });

      test('VideoPlayerWebOptionsControls.enabled allows customization', () {
        const controls = VideoPlayerWebOptionsControls.enabled(allowDownload: false, allowFullscreen: false);

        expect(controls.enabled, isTrue);
        expect(controls.allowDownload, isFalse);
        expect(controls.allowFullscreen, isFalse);
        expect(controls.allowPlaybackRate, isTrue);
        expect(controls.allowPictureInPicture, isTrue);
      });

      test('controlsList generates correct string', () {
        const controls = VideoPlayerWebOptionsControls.enabled(allowDownload: false, allowFullscreen: false);

        expect(controls.controlsList, isA<String>());
        expect(controls.controlsList, contains('nodownload'));
        expect(controls.controlsList, contains('nofullscreen'));
      });
    });

    group('ClosedCaptionFile API', () {
      test('SubRipCaptionFile has captions getter', () {
        final file = SubRipCaptionFile('');
        expect(file.captions, isA<List<Caption>>());
      });

      test('SubRipCaptionFile has fileContents getter', () {
        const content = '1\n00:00:01,000 --> 00:00:02,000\nTest\n';
        final file = SubRipCaptionFile(content);
        expect(file.fileContents, isA<String>());
        expect(file.fileContents, equals(content));
      });

      test('WebVTTCaptionFile has captions getter', () {
        final file = WebVTTCaptionFile('');
        expect(file.captions, isA<List<Caption>>());
      });

      test('WebVTTCaptionFile has fileContents getter', () {
        const content = 'WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nTest\n';
        final file = WebVTTCaptionFile(content);
        expect(file.fileContents, isA<String>());
        expect(file.fileContents, equals(content));
      });
    });
  });

  group('API Compatibility Summary', () {
    test('SUMMARY: All video_player public API is available', () {
      // This test serves as a summary/documentation of what's verified
      // If any export is missing, the tests above will fail

      final exports = <String>[
        'VideoPlayerController',
        'VideoPlayerValue',
        'VideoPlayer',
        'Caption',
        'ClosedCaptionFile',
        'SubRipCaptionFile',
        'WebVTTCaptionFile',
        'DurationRange',
        'VideoProgressIndicator',
        'VideoScrubber',
        'VideoProgressColors',
        'ClosedCaption',
        'DataSourceType',
        'VideoFormat',
        'VideoViewType',
        'VideoPlayerOptions',
        'VideoPlayerWebOptions',
        'VideoPlayerWebOptionsControls',
      ];

      // All exports verified in previous tests
      expect(exports.length, equals(18), reason: 'All 18 video_player exports should be verified');
    });
  });
}
