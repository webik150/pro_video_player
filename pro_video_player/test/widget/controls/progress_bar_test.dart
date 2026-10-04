import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pro_video_player/pro_video_player.dart';

import '../../shared/test_constants.dart';
import '../../shared/test_helpers.dart';
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

  group('ProgressBar', () {
    group('basic rendering', () {
      testWidgets('renders progress bar with correct structure', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        fixture
          ..emitDuration(TestMetadata.duration)
          ..emitPosition(const Duration(minutes: 2));
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            ProgressBar(
              controller: controller,
              theme: VideoPlayerTheme.light(),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(ProgressBar), findsOneWidget);
        expect(find.byType(GestureDetector), findsOneWidget);
        expect(
          find.byType(FractionallySizedBox),
          findsNWidgets(2),
        ); // Buffered + played
      });

      testWidgets('handles zero duration gracefully', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        fixture.emitDuration(Duration.zero);
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            ProgressBar(
              controller: controller,
              theme: VideoPlayerTheme.light(),
            ),
          ),
        );
        await tester.pump();

        // Should render without errors
        expect(find.byType(ProgressBar), findsOneWidget);
      });

      testWidgets('renders position indicator circle', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        fixture
          ..emitDuration(TestMetadata.duration)
          ..emitPosition(const Duration(minutes: 2));
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            ProgressBar(
              controller: controller,
              theme: VideoPlayerTheme.light(),
            ),
          ),
        );
        await tester.pump();

        // Find the indicator circle (Container with BoxDecoration)
        final containers = tester.widgetList<Container>(find.byType(Container));
        final indicatorCircle = containers.firstWhere(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration! as BoxDecoration).shape == BoxShape.circle,
        );

        expect(indicatorCircle, isNotNull);
        expect(
          (indicatorCircle.decoration! as BoxDecoration).boxShadow,
          isNotEmpty,
        );
      });
    });

    group('tap to seek', () {
      testWidgets('seeks with arrow keys while focused', (tester) async {
        final controller = ProVideoPlayerController();
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        fixture
          ..emitDuration(const Duration(seconds: 100))
          ..emitPosition(const Duration(seconds: 50));
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            SizedBox(
              width: 400,
              child: ProgressBar(
                controller: controller,
                theme: VideoPlayerTheme.light(),
                focusNode: focusNode,
              ),
            ),
          ),
        );
        focusNode.requestFocus();
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);

        verify(
          () => fixture.mockPlatform.seekTo(any(), const Duration(seconds: 60)),
        ).called(1);
      });

      testWidgets('seeks when tapped', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        fixture
          ..emitDuration(const Duration(seconds: 100))
          ..emitPosition(const Duration(seconds: 10));
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            SizedBox(
              width: 400,
              height: 20,
              child: ProgressBar(
                controller: controller,
                theme: VideoPlayerTheme.light(),
              ),
            ),
          ),
        );
        await tester.pump();

        // Tap at 50% of the bar
        final progressBar = find.byType(GestureDetector);
        await tester.tapAt(tester.getCenter(progressBar));
        await tester.pump();

        // Verify seek was called (approximately 50 seconds)
        verify(() => fixture.mockPlatform.seekTo(any(), any())).called(1);
      });

      testWidgets('does not seek when duration is zero', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        fixture.emitDuration(Duration.zero);
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            ProgressBar(
              controller: controller,
              theme: VideoPlayerTheme.light(),
            ),
          ),
        );
        await tester.pump();

        // Tap the bar
        final progressBar = find.byType(GestureDetector);
        await tester.tap(progressBar);
        await tester.pump();

        // Verify seek was NOT called
        verifyNever(() => fixture.mockPlatform.seekTo(any(), any()));
      });
    });

    group('drag to seek', () {
      testWidgets('starts drag and calls onDragStart callback', (tester) async {
        var dragStartCalled = false;
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        fixture.emitDuration(const Duration(seconds: 100));
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            SizedBox(
              width: 400,
              height: 20,
              child: ProgressBar(
                controller: controller,
                theme: VideoPlayerTheme.light(),
                onDragStart: () => dragStartCalled = true,
              ),
            ),
          ),
        );
        await tester.pump();

        // Start drag
        final progressBar = find.byType(GestureDetector);
        await tester.drag(progressBar, const Offset(100, 0));
        await tester.pump();

        expect(dragStartCalled, isTrue);
      });

      testWidgets('ends drag and calls onDragEnd callback', (tester) async {
        var dragEndCalled = false;
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        fixture.emitDuration(const Duration(seconds: 100));
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            SizedBox(
              width: 400,
              height: 20,
              child: ProgressBar(
                controller: controller,
                theme: VideoPlayerTheme.light(),
                onDragEnd: () => dragEndCalled = true,
              ),
            ),
          ),
        );
        await tester.pump();

        // Drag
        final progressBar = find.byType(GestureDetector);
        await tester.drag(progressBar, const Offset(100, 0));
        await tester.pumpAndSettle();

        expect(dragEndCalled, isTrue);
      });

      testWidgets('seeks when drag ends', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        fixture.emitDuration(const Duration(seconds: 100));
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            SizedBox(
              width: 400,
              height: 20,
              child: ProgressBar(
                controller: controller,
                theme: VideoPlayerTheme.light(),
              ),
            ),
          ),
        );
        await tester.pump();

        // Drag to the right
        final progressBar = find.byType(GestureDetector);
        await tester.drag(progressBar, const Offset(200, 0));
        await tester.pumpAndSettle();

        // Verify seek was called at least once (final seek on drag end)
        verify(
          () => fixture.mockPlatform.seekTo(any(), any()),
        ).called(greaterThanOrEqualTo(1));
      });

      testWidgets('does not start drag when duration is zero', (tester) async {
        var dragStartCalled = false;
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        fixture.emitDuration(Duration.zero);
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            ProgressBar(
              controller: controller,
              theme: VideoPlayerTheme.light(),
              onDragStart: () => dragStartCalled = true,
            ),
          ),
        );
        await tester.pump();

        // Try to drag
        final progressBar = find.byType(GestureDetector);
        await tester.drag(progressBar, const Offset(100, 0));
        await tester.pump();

        expect(dragStartCalled, isFalse);
      });
    });

    group('live scrubbing modes', () {
      testWidgets('disabled mode never live scrubs during drag', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        await tester.pumpWidget(
          buildTestWidget(
            SizedBox(
              width: 400,
              height: 20,
              child: ProgressBar(
                controller: controller,
                theme: VideoPlayerTheme.light(),
                liveScrubbingMode: LiveScrubbingMode.disabled,
              ),
            ),
          ),
        );
        await tester.pump();

        // Set duration AFTER widget is built
        fixture.emitDuration(const Duration(seconds: 100));
        await tester.pump();

        // Drag slowly to give time for live scrubbing
        final progressBar = find.byType(GestureDetector);
        final startLocation = tester.getCenter(progressBar);
        final gesture = await tester.startGesture(startLocation);
        await gesture.moveBy(const Offset(50, 0));
        await tester.pump(TestDelays.stateUpdate);
        await gesture.moveBy(const Offset(50, 0));
        await tester.pump(TestDelays.stateUpdate);
        await gesture.up();
        await tester.pumpAndSettle();

        // Only one seek call on drag end, no live scrubbing during drag
        verify(() => fixture.mockPlatform.seekTo(any(), any())).called(1);
      });

      testWidgets('always mode live scrubs for all sources', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        await tester.pumpWidget(
          buildTestWidget(
            SizedBox(
              width: 400,
              height: 20,
              child: ProgressBar(
                controller: controller,
                theme: VideoPlayerTheme.light(),
                liveScrubbingMode: LiveScrubbingMode.always,
              ),
            ),
          ),
        );
        await tester.pump();

        // Set duration and state AFTER widget is built
        fixture
          ..emitDuration(const Duration(seconds: 100))
          ..emitPlaybackState(PlaybackState.playing);
        await tester.pump();

        // Drag slowly to give time for live scrubbing
        final progressBar = find.byType(GestureDetector);
        final startLocation = tester.getCenter(progressBar);
        final gesture = await tester.startGesture(startLocation);
        await gesture.moveBy(const Offset(50, 0));
        await tester.pump(const Duration(milliseconds: 60));
        await gesture.moveBy(const Offset(50, 0));
        await tester.pump(const Duration(milliseconds: 60));
        await gesture.up();
        await tester.pumpAndSettle();

        // Multiple seek calls (live scrubbing + final seek)
        verify(
          () => fixture.mockPlatform.seekTo(any(), any()),
        ).called(greaterThan(1));
      });

      testWidgets('localOnly mode live scrubs for file sources', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.file(TestMedia.filePath),
        );

        await tester.pumpWidget(
          buildTestWidget(
            SizedBox(
              width: 400,
              height: 20,
              child: ProgressBar(
                controller: controller,
                theme: VideoPlayerTheme.light(),
                liveScrubbingMode: LiveScrubbingMode.localOnly,
              ),
            ),
          ),
        );
        await tester.pump();

        // Set duration AFTER widget is built
        fixture.emitDuration(const Duration(seconds: 100));
        await tester.pump();

        // Drag slowly
        final progressBar = find.byType(GestureDetector);
        final startLocation = tester.getCenter(progressBar);
        final gesture = await tester.startGesture(startLocation);
        await gesture.moveBy(const Offset(50, 0));
        await tester.pump(const Duration(milliseconds: 60));
        await gesture.moveBy(const Offset(50, 0));
        await tester.pump(const Duration(milliseconds: 60));
        await gesture.up();
        await tester.pumpAndSettle();

        // Multiple seek calls (live scrubbing for local file)
        verify(
          () => fixture.mockPlatform.seekTo(any(), any()),
        ).called(greaterThan(1));
      });

      testWidgets('localOnly mode does not live scrub for network sources', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        await tester.pumpWidget(
          buildTestWidget(
            SizedBox(
              width: 400,
              height: 20,
              child: ProgressBar(
                controller: controller,
                theme: VideoPlayerTheme.light(),
                liveScrubbingMode: LiveScrubbingMode.localOnly,
              ),
            ),
          ),
        );
        await tester.pump();

        // Set duration AFTER widget is built
        fixture.emitDuration(const Duration(seconds: 100));
        await tester.pump();

        // Drag slowly
        final progressBar = find.byType(GestureDetector);
        final startLocation = tester.getCenter(progressBar);
        final gesture = await tester.startGesture(startLocation);
        await gesture.moveBy(const Offset(50, 0));
        await tester.pump(const Duration(milliseconds: 60));
        await gesture.moveBy(const Offset(50, 0));
        await tester.pump(const Duration(milliseconds: 60));
        await gesture.up();
        await tester.pumpAndSettle();

        // Only one seek call on drag end, no live scrubbing
        verify(() => fixture.mockPlatform.seekTo(any(), any())).called(1);
      });

      testWidgets('adaptive mode live scrubs for local sources', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.asset(TestMedia.assetPath),
        );

        await tester.pumpWidget(
          buildTestWidget(
            SizedBox(
              width: 400,
              height: 20,
              child: ProgressBar(
                controller: controller,
                theme: VideoPlayerTheme.light(),
              ),
            ),
          ),
        );
        await tester.pump();

        // Set duration and state AFTER widget is built
        fixture
          ..emitDuration(const Duration(seconds: 100))
          ..emitPlaybackState(PlaybackState.playing);
        await tester.pump();

        // Drag slowly
        final progressBar = find.byType(GestureDetector);
        final startLocation = tester.getCenter(progressBar);
        final gesture = await tester.startGesture(startLocation);
        await gesture.moveBy(const Offset(50, 0));
        await tester.pump(const Duration(milliseconds: 60));
        await gesture.moveBy(const Offset(50, 0));
        await tester.pump(const Duration(milliseconds: 60));
        await gesture.up();
        await tester.pumpAndSettle();

        // Multiple seek calls for asset source
        verify(
          () => fixture.mockPlatform.seekTo(any(), any()),
        ).called(greaterThan(1));
      });

      testWidgets(
        'adaptive mode does not live scrub for buffering network sources',
        (tester) async {
          final controller = ProVideoPlayerController();
          await controller.initialize(
            source: const VideoSource.network(TestMedia.networkUrl),
          );

          await tester.pumpWidget(
            buildTestWidget(
              SizedBox(
                width: 400,
                height: 20,
                child: ProgressBar(
                  controller: controller,
                  theme: VideoPlayerTheme.light(),
                ),
              ),
            ),
          );
          await tester.pump();

          // Set duration and state AFTER widget is built
          fixture
            ..emitDuration(const Duration(seconds: 100))
            ..emitPlaybackState(PlaybackState.buffering);
          await tester.pump();

          // Drag slowly
          final progressBar = find.byType(GestureDetector);
          final startLocation = tester.getCenter(progressBar);
          final gesture = await tester.startGesture(startLocation);
          await gesture.moveBy(const Offset(50, 0));
          await tester.pump(const Duration(milliseconds: 60));
          await gesture.moveBy(const Offset(50, 0));
          await tester.pump(const Duration(milliseconds: 60));
          await gesture.up();
          await tester.pumpAndSettle();

          // Only one seek call, no live scrubbing during buffering
          verify(() => fixture.mockPlatform.seekTo(any(), any())).called(1);
        },
      );

      testWidgets(
        'adaptive mode live scrubs for non-buffering network sources',
        (tester) async {
          final controller = ProVideoPlayerController();
          await controller.initialize(
            source: const VideoSource.network(TestMedia.networkUrl),
          );

          await tester.pumpWidget(
            buildTestWidget(
              SizedBox(
                width: 400,
                height: 20,
                child: ProgressBar(
                  controller: controller,
                  theme: VideoPlayerTheme.light(),
                ),
              ),
            ),
          );
          await tester.pump();

          // Set duration and state AFTER widget is built
          fixture
            ..emitDuration(const Duration(seconds: 100))
            ..emitPlaybackState(PlaybackState.playing);
          await tester.pump();

          // Drag slowly
          final progressBar = find.byType(GestureDetector);
          final startLocation = tester.getCenter(progressBar);
          final gesture = await tester.startGesture(startLocation);
          await gesture.moveBy(const Offset(50, 0));
          await tester.pump(const Duration(milliseconds: 60));
          await gesture.moveBy(const Offset(50, 0));
          await tester.pump(const Duration(milliseconds: 60));
          await gesture.up();
          await tester.pumpAndSettle();

          // Multiple seek calls for non-buffering network source
          verify(
            () => fixture.mockPlatform.seekTo(any(), any()),
          ).called(greaterThan(1));
        },
      );
    });

    group('theme and styling', () {
      testWidgets('uses theme colors for progress bar', (tester) async {
        final customTheme = VideoPlayerTheme.light().copyWith(
          progressBarActiveColor: Colors.red,
          progressBarInactiveColor: Colors.grey,
          progressBarBufferedColor: Colors.blue,
        );

        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        fixture
          ..emitDuration(TestMetadata.duration)
          ..emitPosition(const Duration(minutes: 2));
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            ProgressBar(controller: controller, theme: customTheme),
          ),
        );
        await tester.pump();

        // Find the containers with colors
        final containers = tester.widgetList<Container>(find.byType(Container));

        // Verify colors are used (checking BoxDecoration color)
        final coloredContainers = containers.where((c) {
          final decoration = c.decoration;
          return decoration is BoxDecoration && decoration.color != null;
        });

        expect(coloredContainers.length, greaterThan(0));
      });
    });
  });
}
