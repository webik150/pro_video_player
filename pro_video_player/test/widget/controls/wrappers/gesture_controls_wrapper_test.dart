import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pro_video_player/pro_video_player.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

import '../../../shared/test_constants.dart';
import '../../../shared/test_helpers.dart';

class MockProVideoPlayerPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements ProVideoPlayerPlatform {}

class MockVideoControlsController extends Mock
    implements VideoControlsController {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockProVideoPlayerPlatform mockPlatform;
  late StreamController<VideoPlayerEvent> eventController;
  late MockVideoControlsController mockControlsController;

  setUpAll(() {
    registerFallbackValue(const VideoSource.network('https://example.com'));
    registerFallbackValue(const VideoPlayerOptions());
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    mockPlatform = MockProVideoPlayerPlatform();
    eventController = StreamController<VideoPlayerEvent>.broadcast();
    mockControlsController = MockVideoControlsController();
    ProVideoPlayerPlatform.instance = mockPlatform;

    when(
      () => mockPlatform.create(
        source: any(named: 'source'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => 1);

    when(
      () => mockPlatform.events(any()),
    ).thenAnswer((_) => eventController.stream);
    when(() => mockPlatform.dispose(any())).thenAnswer((_) async {});

    // Mock controls controller
    when(
      () => mockControlsController.controlsState,
    ).thenReturn(VideoControlsState()..showControls());
    when(() => mockControlsController.showControls()).thenReturn(null);
    when(() => mockControlsController.hideControls()).thenReturn(null);
    when(() => mockControlsController.resetHideTimer()).thenReturn(null);
    when(
      () => mockControlsController.gestureSeekPositionValue = any(),
    ).thenReturn(null);
  });

  tearDown(() async {
    await eventController.close();
    ProVideoPlayerPlatform.instance = MockProVideoPlayerPlatform();
  });

  group('GestureControlsWrapper', () {
    testWidgets('renders child widget', (tester) async {
      final controller = ProVideoPlayerController();
      await controller.initialize(
        source: const VideoSource.network(TestMedia.networkUrl),
      );

      await tester.pumpWidget(
        buildTestWidget(
          GestureControlsWrapper(
            controller: controller,
            controlsController: mockControlsController,
            enableDoubleTapSeek: true,
            enableVolumeGesture: true,
            enableBrightnessGesture: true,
            enableSeekGesture: true,
            skipDuration: const Duration(seconds: 10),
            seekSecondsPerInch: 10,
            autoHide: true,
            autoHideDuration: const Duration(seconds: 3),
            enablePlaybackSpeedGesture: true,
            onBrightnessChanged: null,
            child: const Center(child: Text('Test Child')),
          ),
        ),
      );

      expect(find.text('Test Child'), findsOneWidget);
    });

    testWidgets('wraps child with VideoPlayerGestureDetector', (tester) async {
      final controller = ProVideoPlayerController();
      await controller.initialize(
        source: const VideoSource.network(TestMedia.networkUrl),
      );

      await tester.pumpWidget(
        buildTestWidget(
          GestureControlsWrapper(
            controller: controller,
            controlsController: mockControlsController,
            enableDoubleTapSeek: true,
            enableVolumeGesture: true,
            enableBrightnessGesture: true,
            enableSeekGesture: true,
            skipDuration: const Duration(seconds: 10),
            seekSecondsPerInch: 10,
            autoHide: true,
            autoHideDuration: const Duration(seconds: 3),
            enablePlaybackSpeedGesture: true,
            onBrightnessChanged: null,
            child: const Center(child: Text('Video')),
          ),
        ),
      );

      expect(find.byType(VideoPlayerGestureDetector), findsOneWidget);
    });

    testWidgets('shows controls when navigating with the keyboard', (
      tester,
    ) async {
      final controller = ProVideoPlayerController();
      await controller.initialize(
        source: const VideoSource.network(TestMedia.networkUrl),
      );

      await tester.pumpWidget(
        buildTestWidget(
          GestureControlsWrapper(
            controller: controller,
            controlsController: mockControlsController,
            enableDoubleTapSeek: true,
            enableVolumeGesture: true,
            enableBrightnessGesture: true,
            enableSeekGesture: true,
            skipDuration: const Duration(seconds: 10),
            seekSecondsPerInch: 10,
            autoHide: true,
            autoHideDuration: const Duration(seconds: 3),
            enablePlaybackSpeedGesture: true,
            onBrightnessChanged: null,
            child: const Center(child: Text('Video')),
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);

      verify(() => mockControlsController.showControls()).called(1);
      verify(() => mockControlsController.resetHideTimer()).called(1);
    });

    testWidgets('passes correct skip duration to gesture detector', (
      tester,
    ) async {
      final controller = ProVideoPlayerController();
      await controller.initialize(
        source: const VideoSource.network(TestMedia.networkUrl),
      );

      const testSkipDuration = Duration(seconds: 15);

      await tester.pumpWidget(
        buildTestWidget(
          GestureControlsWrapper(
            controller: controller,
            controlsController: mockControlsController,
            enableDoubleTapSeek: true,
            enableVolumeGesture: true,
            enableBrightnessGesture: true,
            enableSeekGesture: true,
            skipDuration: testSkipDuration,
            seekSecondsPerInch: 10,
            autoHide: true,
            autoHideDuration: const Duration(seconds: 3),
            enablePlaybackSpeedGesture: true,
            onBrightnessChanged: null,
            child: const Center(child: Text('Video')),
          ),
        ),
      );

      final gestureDetector = tester.widget<VideoPlayerGestureDetector>(
        find.byType(VideoPlayerGestureDetector),
      );

      expect(gestureDetector.seekDuration, equals(testSkipDuration));
    });

    testWidgets('passes enable flags to gesture detector', (tester) async {
      final controller = ProVideoPlayerController();
      await controller.initialize(
        source: const VideoSource.network(TestMedia.networkUrl),
      );

      await tester.pumpWidget(
        buildTestWidget(
          GestureControlsWrapper(
            controller: controller,
            controlsController: mockControlsController,
            enableDoubleTapSeek: false,
            enableVolumeGesture: false,
            enableBrightnessGesture: true,
            enableSeekGesture: true,
            skipDuration: const Duration(seconds: 10),
            seekSecondsPerInch: 10,
            autoHide: true,
            autoHideDuration: const Duration(seconds: 3),
            enablePlaybackSpeedGesture: true,
            onBrightnessChanged: null,
            child: const Center(child: Text('Video')),
          ),
        ),
      );

      final gestureDetector = tester.widget<VideoPlayerGestureDetector>(
        find.byType(VideoPlayerGestureDetector),
      );

      expect(gestureDetector.enableDoubleTapSeek, isFalse);
      expect(gestureDetector.enableVolumeGesture, isFalse);
      expect(gestureDetector.enableBrightnessGesture, isTrue);
      expect(gestureDetector.enableSeekGesture, isTrue);
    });

    testWidgets('shows controls when visibility callback is true', (
      tester,
    ) async {
      final controller = ProVideoPlayerController();
      await controller.initialize(
        source: const VideoSource.network(TestMedia.networkUrl),
      );

      await tester.pumpWidget(
        buildTestWidget(
          GestureControlsWrapper(
            controller: controller,
            controlsController: mockControlsController,
            enableDoubleTapSeek: true,
            enableVolumeGesture: true,
            enableBrightnessGesture: true,
            enableSeekGesture: true,
            skipDuration: const Duration(seconds: 10),
            seekSecondsPerInch: 10,
            autoHide: true,
            autoHideDuration: const Duration(seconds: 3),
            enablePlaybackSpeedGesture: true,
            onBrightnessChanged: null,
            child: const Center(child: Text('Video')),
          ),
        ),
      );

      // Get the gesture detector widget and trigger the callback
      final gestureDetector = tester.widget<VideoPlayerGestureDetector>(
        find.byType(VideoPlayerGestureDetector),
      );

      // Simulate the callback
      gestureDetector.onControlsVisibilityChanged?.call(true);
      await tester.pump();

      verify(() => mockControlsController.showControls()).called(1);
    });

    testWidgets('hides controls when visibility callback is false', (
      tester,
    ) async {
      final controller = ProVideoPlayerController();
      await controller.initialize(
        source: const VideoSource.network(TestMedia.networkUrl),
      );

      await tester.pumpWidget(
        buildTestWidget(
          GestureControlsWrapper(
            controller: controller,
            controlsController: mockControlsController,
            enableDoubleTapSeek: true,
            enableVolumeGesture: true,
            enableBrightnessGesture: true,
            enableSeekGesture: true,
            skipDuration: const Duration(seconds: 10),
            seekSecondsPerInch: 10,
            autoHide: true,
            autoHideDuration: const Duration(seconds: 3),
            enablePlaybackSpeedGesture: true,
            onBrightnessChanged: null,
            child: const Center(child: Text('Video')),
          ),
        ),
      );

      // Get the gesture detector widget and trigger the callback
      final gestureDetector = tester.widget<VideoPlayerGestureDetector>(
        find.byType(VideoPlayerGestureDetector),
      );

      // Simulate the callback
      gestureDetector.onControlsVisibilityChanged?.call(false);
      await tester.pump();

      verify(() => mockControlsController.hideControls()).called(1);
    });

    testWidgets('updates gesture seek position when callback is triggered', (
      tester,
    ) async {
      final controller = ProVideoPlayerController();
      await controller.initialize(
        source: const VideoSource.network(TestMedia.networkUrl),
      );

      await tester.pumpWidget(
        buildTestWidget(
          GestureControlsWrapper(
            controller: controller,
            controlsController: mockControlsController,
            enableDoubleTapSeek: true,
            enableVolumeGesture: true,
            enableBrightnessGesture: true,
            enableSeekGesture: true,
            skipDuration: const Duration(seconds: 10),
            seekSecondsPerInch: 10,
            autoHide: true,
            autoHideDuration: const Duration(seconds: 3),
            enablePlaybackSpeedGesture: true,
            onBrightnessChanged: null,
            child: const Center(child: Text('Video')),
          ),
        ),
      );

      // Get the gesture detector widget and trigger the callback
      final gestureDetector = tester.widget<VideoPlayerGestureDetector>(
        find.byType(VideoPlayerGestureDetector),
      );

      // Simulate the seek gesture update callback
      const testPosition = Duration(seconds: 30);
      gestureDetector.onSeekGestureUpdate?.call(testPosition);
      await tester.pump();

      verify(
        () => mockControlsController.gestureSeekPositionValue = testPosition,
      ).called(1);
    });

    testWidgets('all enable flags default to their values', (tester) async {
      final controller = ProVideoPlayerController();
      await controller.initialize(
        source: const VideoSource.network(TestMedia.networkUrl),
      );

      // Test with all enabled
      await tester.pumpWidget(
        buildTestWidget(
          GestureControlsWrapper(
            controller: controller,
            controlsController: mockControlsController,
            enableDoubleTapSeek: true,
            enableVolumeGesture: true,
            enableBrightnessGesture: true,
            enableSeekGesture: true,
            skipDuration: const Duration(seconds: 10),
            seekSecondsPerInch: 10,
            autoHide: true,
            autoHideDuration: const Duration(seconds: 3),
            enablePlaybackSpeedGesture: true,
            onBrightnessChanged: null,
            child: const Center(child: Text('Video')),
          ),
        ),
      );

      var gestureDetector = tester.widget<VideoPlayerGestureDetector>(
        find.byType(VideoPlayerGestureDetector),
      );

      expect(gestureDetector.enableDoubleTapSeek, isTrue);
      expect(gestureDetector.enableVolumeGesture, isTrue);
      expect(gestureDetector.enableBrightnessGesture, isTrue);
      expect(gestureDetector.enableSeekGesture, isTrue);

      // Test with all disabled
      await tester.pumpWidget(
        buildTestWidget(
          GestureControlsWrapper(
            controller: controller,
            controlsController: mockControlsController,
            enableDoubleTapSeek: false,
            enableVolumeGesture: false,
            enableBrightnessGesture: false,
            enableSeekGesture: false,
            skipDuration: const Duration(seconds: 10),
            seekSecondsPerInch: 10,
            autoHide: true,
            autoHideDuration: const Duration(seconds: 3),
            enablePlaybackSpeedGesture: true,
            onBrightnessChanged: null,
            child: const Center(child: Text('Video')),
          ),
        ),
      );

      gestureDetector = tester.widget<VideoPlayerGestureDetector>(
        find.byType(VideoPlayerGestureDetector),
      );

      expect(gestureDetector.enableDoubleTapSeek, isFalse);
      expect(gestureDetector.enableVolumeGesture, isFalse);
      expect(gestureDetector.enableBrightnessGesture, isFalse);
      expect(gestureDetector.enableSeekGesture, isFalse);
    });
  });
}
