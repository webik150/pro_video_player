/// Tests for video_player compatibility types.
///
/// These tests verify that the compatibility layer types match the
/// video_player API exactly.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player/video_player_compat.dart';

void main() {
  group('Caption', () {
    test('has required number property', () {
      const caption = Caption(number: 1, start: Duration(seconds: 1), end: Duration(seconds: 2), text: 'Hello');

      expect(caption.number, equals(1));
      expect(caption.start, equals(const Duration(seconds: 1)));
      expect(caption.end, equals(const Duration(seconds: 2)));
      expect(caption.text, equals('Hello'));
    });

    test('Caption.none is empty with number 0', () {
      expect(Caption.none.number, equals(0));
      expect(Caption.none.start, equals(Duration.zero));
      expect(Caption.none.end, equals(Duration.zero));
      expect(Caption.none.text, isEmpty);
    });

    test('equality works correctly', () {
      const caption1 = Caption(number: 1, start: Duration(seconds: 1), end: Duration(seconds: 2), text: 'Hello');
      const caption2 = Caption(number: 1, start: Duration(seconds: 1), end: Duration(seconds: 2), text: 'Hello');
      const caption3 = Caption(number: 2, start: Duration(seconds: 1), end: Duration(seconds: 2), text: 'Hello');

      expect(caption1, equals(caption2));
      expect(caption1, isNot(equals(caption3)));
    });

    test('hashCode is consistent with equality', () {
      const caption1 = Caption(number: 1, start: Duration(seconds: 1), end: Duration(seconds: 2), text: 'Hello');
      const caption2 = Caption(number: 1, start: Duration(seconds: 1), end: Duration(seconds: 2), text: 'Hello');

      expect(caption1.hashCode, equals(caption2.hashCode));
    });
  });

  group('DurationRange', () {
    test('creates range with start and end', () {
      const range = DurationRange(Duration(seconds: 10), Duration(seconds: 30));

      expect(range.start, equals(const Duration(seconds: 10)));
      expect(range.end, equals(const Duration(seconds: 30)));
    });

    test('startFraction calculates correct percentage', () {
      const range = DurationRange(Duration(seconds: 30), Duration(seconds: 60));
      const duration = Duration(seconds: 120);

      expect(range.startFraction(duration), equals(0.25));
    });

    test('endFraction calculates correct percentage', () {
      const range = DurationRange(Duration(seconds: 30), Duration(seconds: 60));
      const duration = Duration(seconds: 120);

      expect(range.endFraction(duration), equals(0.5));
    });

    test('startFraction returns 0 for zero duration', () {
      const range = DurationRange(Duration(seconds: 30), Duration(seconds: 60));

      expect(range.startFraction(Duration.zero), equals(0.0));
    });

    test('endFraction returns 0 for zero duration', () {
      const range = DurationRange(Duration(seconds: 30), Duration(seconds: 60));

      expect(range.endFraction(Duration.zero), equals(0.0));
    });

    test('equality works correctly', () {
      const range1 = DurationRange(Duration(seconds: 10), Duration(seconds: 20));
      const range2 = DurationRange(Duration(seconds: 10), Duration(seconds: 20));
      const range3 = DurationRange(Duration(seconds: 10), Duration(seconds: 30));

      expect(range1, equals(range2));
      expect(range1, isNot(equals(range3)));
    });
  });

  group('VideoPlayerValue', () {
    test('uninitialized constructor creates correct state', () {
      const value = VideoPlayerValue.uninitialized();

      expect(value.duration, equals(Duration.zero));
      expect(value.position, equals(Duration.zero));
      expect(value.size, equals(Size.zero));
      expect(value.isInitialized, isFalse);
      expect(value.isPlaying, isFalse);
      expect(value.isLooping, isFalse);
      expect(value.isBuffering, isFalse);
      expect(value.volume, equals(1.0));
      expect(value.playbackSpeed, equals(1.0));
      expect(value.rotationCorrection, equals(0));
      expect(value.errorDescription, isNull);
      expect(value.hasError, isFalse);
      expect(value.caption, equals(Caption.none));
      expect(value.captionOffset, equals(Duration.zero));
      expect(value.buffered, isEmpty);
    });

    test('erroneous constructor creates error state', () {
      const value = VideoPlayerValue.erroneous('Test error');

      expect(value.errorDescription, equals('Test error'));
      expect(value.hasError, isTrue);
      expect(value.isInitialized, isFalse);
    });

    test('aspectRatio returns 1.0 for zero height', () {
      const value = VideoPlayerValue(duration: Duration(seconds: 60));

      expect(value.aspectRatio, equals(1.0));
    });

    test('aspectRatio calculates correctly', () {
      const value = VideoPlayerValue(duration: Duration(seconds: 60), size: Size(1920, 1080));

      expect(value.aspectRatio, closeTo(16 / 9, 0.01));
    });

    test('isCompleted is true when position >= duration', () {
      const value = VideoPlayerValue(
        duration: Duration(seconds: 60),
        position: Duration(seconds: 60),
        isInitialized: true,
      );

      expect(value.isCompleted, isTrue);
    });

    test('isCompleted is false when duration is zero', () {
      const value = VideoPlayerValue(duration: Duration.zero, isInitialized: true);

      expect(value.isCompleted, isFalse);
    });

    test('copyWith creates modified copy', () {
      const original = VideoPlayerValue.uninitialized();
      final modified = original.copyWith(duration: const Duration(seconds: 60), isInitialized: true, isPlaying: true);

      expect(modified.duration, equals(const Duration(seconds: 60)));
      expect(modified.isInitialized, isTrue);
      expect(modified.isPlaying, isTrue);
      expect(modified.volume, equals(original.volume)); // Unchanged
    });

    test('equality works correctly', () {
      const value1 = VideoPlayerValue(duration: Duration(seconds: 60), isInitialized: true);
      const value2 = VideoPlayerValue(duration: Duration(seconds: 60), isInitialized: true);
      const value3 = VideoPlayerValue(duration: Duration(seconds: 90), isInitialized: true);

      expect(value1, equals(value2));
      expect(value1, isNot(equals(value3)));
    });
  });

  group('VideoPlayerOptions', () {
    test('has correct defaults', () {
      const options = VideoPlayerOptions();

      expect(options.mixWithOthers, isFalse);
      expect(options.allowBackgroundPlayback, isFalse);
      expect(options.webOptions, isNull);
    });

    test('accepts all parameters', () {
      const webOptions = VideoPlayerWebOptions();
      const options = VideoPlayerOptions(mixWithOthers: true, allowBackgroundPlayback: true, webOptions: webOptions);

      expect(options.mixWithOthers, isTrue);
      expect(options.allowBackgroundPlayback, isTrue);
      expect(options.webOptions, equals(webOptions));
    });

    test('equality works correctly', () {
      const options1 = VideoPlayerOptions(mixWithOthers: true);
      const options2 = VideoPlayerOptions(mixWithOthers: true);
      const options3 = VideoPlayerOptions();

      expect(options1, equals(options2));
      expect(options1, isNot(equals(options3)));
    });
  });

  group('VideoPlayerWebOptions', () {
    test('has correct defaults', () {
      const options = VideoPlayerWebOptions();

      expect(options.controls, isA<VideoPlayerWebOptionsControls>());
      expect(options.controls.enabled, isFalse);
      expect(options.allowContextMenu, isTrue);
      expect(options.allowRemotePlayback, isTrue);
      expect(options.poster, isNull);
    });

    test('accepts all parameters', () {
      const controls = VideoPlayerWebOptionsControls.enabled();
      final options = VideoPlayerWebOptions(
        controls: controls,
        allowContextMenu: false,
        allowRemotePlayback: false,
        poster: Uri.parse('https://example.com/poster.jpg'),
      );

      expect(options.controls.enabled, isTrue);
      expect(options.allowContextMenu, isFalse);
      expect(options.allowRemotePlayback, isFalse);
      expect(options.poster, equals(Uri.parse('https://example.com/poster.jpg')));
    });
  });

  group('VideoPlayerWebOptionsControls', () {
    test('disabled() has correct values', () {
      const controls = VideoPlayerWebOptionsControls.disabled();

      expect(controls.enabled, isFalse);
      expect(controls.allowDownload, isFalse);
      expect(controls.allowFullscreen, isFalse);
      expect(controls.allowPlaybackRate, isFalse);
      expect(controls.allowPictureInPicture, isFalse);
    });

    test('enabled() has correct defaults', () {
      const controls = VideoPlayerWebOptionsControls.enabled();

      expect(controls.enabled, isTrue);
      expect(controls.allowDownload, isTrue);
      expect(controls.allowFullscreen, isTrue);
      expect(controls.allowPlaybackRate, isTrue);
      expect(controls.allowPictureInPicture, isTrue);
    });

    test('enabled() allows customization', () {
      const controls = VideoPlayerWebOptionsControls.enabled(allowDownload: false, allowFullscreen: false);

      expect(controls.enabled, isTrue);
      expect(controls.allowDownload, isFalse);
      expect(controls.allowFullscreen, isFalse);
      expect(controls.allowPlaybackRate, isTrue);
      expect(controls.allowPictureInPicture, isTrue);
    });

    test('controlsList generates correct string', () {
      const controls = VideoPlayerWebOptionsControls.enabled(allowDownload: false, allowFullscreen: false);

      expect(controls.controlsList, equals('nodownload nofullscreen'));
    });

    test('controlsList is empty when disabled', () {
      const controls = VideoPlayerWebOptionsControls.disabled();

      expect(controls.controlsList, isEmpty);
    });
  });

  group('DataSourceType enum', () {
    test('has all required values', () {
      expect(DataSourceType.values, hasLength(4));
      expect(DataSourceType.values, contains(DataSourceType.asset));
      expect(DataSourceType.values, contains(DataSourceType.network));
      expect(DataSourceType.values, contains(DataSourceType.file));
      expect(DataSourceType.values, contains(DataSourceType.contentUri));
    });
  });

  group('VideoFormat enum', () {
    test('has all required values', () {
      expect(VideoFormat.values, hasLength(4));
      expect(VideoFormat.values, contains(VideoFormat.dash));
      expect(VideoFormat.values, contains(VideoFormat.hls));
      expect(VideoFormat.values, contains(VideoFormat.ss));
      expect(VideoFormat.values, contains(VideoFormat.other));
    });
  });

  group('VideoViewType enum', () {
    test('has all required values', () {
      expect(VideoViewType.values, hasLength(2));
      expect(VideoViewType.values, contains(VideoViewType.textureView));
      expect(VideoViewType.values, contains(VideoViewType.platformView));
    });
  });

  group('VideoProgressColors', () {
    test('has correct defaults', () {
      const colors = VideoProgressColors();

      expect(colors.playedColor, equals(const Color.fromRGBO(255, 0, 0, 0.7)));
      expect(colors.bufferedColor, equals(const Color.fromRGBO(50, 50, 200, 0.2)));
      expect(colors.backgroundColor, equals(const Color.fromRGBO(200, 200, 200, 0.5)));
    });

    test('accepts custom colors', () {
      const colors = VideoProgressColors(
        playedColor: Colors.blue,
        bufferedColor: Colors.green,
        backgroundColor: Colors.grey,
      );

      expect(colors.playedColor, equals(Colors.blue));
      expect(colors.bufferedColor, equals(Colors.green));
      expect(colors.backgroundColor, equals(Colors.grey));
    });

    test('equality works correctly', () {
      const colors1 = VideoProgressColors(playedColor: Colors.red);
      const colors2 = VideoProgressColors(playedColor: Colors.red);
      const colors3 = VideoProgressColors(playedColor: Colors.blue);

      expect(colors1, equals(colors2));
      expect(colors1, isNot(equals(colors3)));
    });
  });
}
