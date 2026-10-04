import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pro_video_player/pro_video_player.dart';

import '../shared/test_helpers.dart';
import '../shared/test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VideoPlayerTestFixture fixture;

  setUpAll(registerVideoPlayerFallbackValues);

  setUp(() async {
    fixture = VideoPlayerTestFixture()..setUp();
    await fixture.initializeController();
  });

  tearDown(() => fixture.tearDown());

  group('ProVideoPlayerBuilder', () {
    testWidgets('builds normal view by default', (tester) async {
      await tester.pumpWidget(
        ProVideoPlayerBuilder(
          controller: fixture.controller,
          builder: (context, controller, child) =>
              const Text('Normal View', textDirection: TextDirection.ltr),
        ),
      );

      expect(find.text('Normal View'), findsOneWidget);
    });

    testWidgets('passes controller to builder', (tester) async {
      ProVideoPlayerController? receivedController;

      await tester.pumpWidget(
        ProVideoPlayerBuilder(
          controller: fixture.controller,
          builder: (context, ctrl, child) {
            receivedController = ctrl;
            return const SizedBox();
          },
        ),
      );

      expect(receivedController, equals(fixture.controller));
    });

    testWidgets('passes child to builder', (tester) async {
      Widget? receivedChild;
      const childWidget = Text('Child', textDirection: TextDirection.ltr);

      await tester.pumpWidget(
        ProVideoPlayerBuilder(
          controller: fixture.controller,
          child: childWidget,
          builder: (context, controller, child) {
            receivedChild = child;
            return child ?? const SizedBox();
          },
        ),
      );

      expect(receivedChild, isNotNull);
      expect(find.text('Child'), findsOneWidget);
    });

    testWidgets('uses fullscreenBuilder when isFullscreen is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProVideoPlayerBuilder(
          controller: fixture.controller,
          builder: (context, controller, child) =>
              const Text('Normal View', textDirection: TextDirection.ltr),
          fullscreenBuilder: (context, controller, child) =>
              const Text('Fullscreen View', textDirection: TextDirection.ltr),
        ),
      );

      expect(find.text('Normal View'), findsOneWidget);
      expect(find.text('Fullscreen View'), findsNothing);

      // Trigger fullscreen state change
      fixture.eventController.add(
        const FullscreenStateChangedEvent(isFullscreen: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('Normal View'), findsNothing);
      expect(find.text('Fullscreen View'), findsOneWidget);
    });

    testWidgets(
      'uses default fullscreen when fullscreenBuilder is null and useDefaultFullscreen is true',
      (tester) async {
        when(
          () => fixture.mockPlatform.buildView(
            any(),
            controlsMode: any(named: 'controlsMode'),
          ),
        ).thenReturn(
          const Text('Video View', textDirection: TextDirection.ltr),
        );

        await tester.pumpWidget(
          buildTestWidget(
            ProVideoPlayerBuilder(
              controller: fixture.controller,
              builder: (context, controller, child) =>
                  const Text('Normal View'),
              // No fullscreenBuilder provided, useDefaultFullscreen defaults to true
            ),
          ),
        );

        // Trigger fullscreen state change
        fixture.eventController.add(
          const FullscreenStateChangedEvent(isFullscreen: true),
        );
        await tester.pumpAndSettle();

        // Should show default fullscreen view (with video player)
        expect(find.text('Normal View'), findsNothing);
        expect(find.byType(ProVideoPlayer), findsOneWidget);
      },
    );

    testWidgets(
      'fullscreen controls fill the screen independently of the video aspect ratio',
      (tester) async {
        const controlsKey = ValueKey('fullscreen-controls');
        when(
          () => fixture.mockPlatform.buildView(
            any(),
            controlsMode: any(named: 'controlsMode'),
          ),
        ).thenReturn(
          const Text('Video View', textDirection: TextDirection.ltr),
        );

        await tester.pumpWidget(
          buildTestWidget(
            ProVideoPlayerBuilder(
              controller: fixture.controller,
              builder: (context, controller, child) =>
                  const Text('Normal View'),
              controlsBuilder: (context, controller) =>
                  const SizedBox.expand(key: controlsKey),
            ),
          ),
        );

        fixture.eventController.add(
          const FullscreenStateChangedEvent(isFullscreen: true),
        );
        await tester.pumpAndSettle();

        final screenSize = tester.getSize(find.byType(Scaffold).first);
        expect(tester.getSize(find.byKey(controlsKey)), screenSize);
        expect(
          tester.getSize(find.byType(ProVideoPlayer).last).height,
          lessThan(screenSize.height),
        );
      },
    );

    testWidgets('uses normal builder when useDefaultFullscreen is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProVideoPlayerBuilder(
          controller: fixture.controller,
          useDefaultFullscreen: false,
          builder: (context, controller, child) =>
              const Text('Normal View', textDirection: TextDirection.ltr),
          // No fullscreenBuilder provided
        ),
      );

      // Trigger fullscreen state change
      fixture.eventController.add(
        const FullscreenStateChangedEvent(isFullscreen: true),
      );
      await tester.pumpAndSettle();

      // Should still show normal view since useDefaultFullscreen is false
      expect(find.text('Normal View'), findsOneWidget);
    });

    testWidgets('fullscreen takes priority over PiP', (tester) async {
      await tester.pumpWidget(
        ProVideoPlayerBuilder(
          controller: fixture.controller,
          builder: (context, controller, child) =>
              const Text('Normal View', textDirection: TextDirection.ltr),
          fullscreenBuilder: (context, controller, child) =>
              const Text('Fullscreen View', textDirection: TextDirection.ltr),
          pipBuilder: (context, controller, child) =>
              const Text('PiP View', textDirection: TextDirection.ltr),
        ),
      );

      // Trigger both fullscreen and PiP
      fixture.eventController
        ..add(const FullscreenStateChangedEvent(isFullscreen: true))
        ..add(const PipStateChangedEvent(isActive: true));
      await tester.pumpAndSettle();

      // Fullscreen should take priority
      expect(find.text('Fullscreen View'), findsOneWidget);
      expect(find.text('PiP View'), findsNothing);
    });

    testWidgets('passes child to fullscreenBuilder', (tester) async {
      Widget? receivedChild;
      const childWidget = Text('Child', textDirection: TextDirection.ltr);

      await tester.pumpWidget(
        ProVideoPlayerBuilder(
          controller: fixture.controller,
          child: childWidget,
          builder: (context, controller, child) => const SizedBox(),
          fullscreenBuilder: (context, controller, child) {
            receivedChild = child;
            return child ?? const SizedBox();
          },
        ),
      );

      fixture.eventController.add(
        const FullscreenStateChangedEvent(isFullscreen: true),
      );
      await tester.pumpAndSettle();

      expect(receivedChild, isNotNull);
      expect(find.text('Child'), findsOneWidget);
    });

    testWidgets('rebuilds when controller value changes', (tester) async {
      var buildCount = 0;

      await tester.pumpWidget(
        ProVideoPlayerBuilder(
          controller: fixture.controller,
          builder: (context, controller, child) {
            buildCount++;
            return Text('Build $buildCount', textDirection: TextDirection.ltr);
          },
        ),
      );

      expect(buildCount, 1);

      // Trigger a value change
      fixture.eventController.add(
        const PositionChangedEvent(Duration(seconds: 10)),
      );
      await tester.pumpAndSettle();

      expect(buildCount, 2);
    });

    testWidgets(
      'uses normal builder when PiP is active but useDefaultPip is false',
      (tester) async {
        await tester.pumpWidget(
          ProVideoPlayerBuilder(
            controller: fixture.controller,
            useDefaultPip: false,
            builder: (context, controller, child) =>
                const Text('Normal View', textDirection: TextDirection.ltr),
            // No pipBuilder provided
          ),
        );

        // Trigger PiP state change
        fixture.eventController.add(const PipStateChangedEvent(isActive: true));
        await tester.pumpAndSettle();

        // Should still show normal view since useDefaultPip is false
        // (On non-Android platforms this would also show normal view)
        expect(find.text('Normal View'), findsOneWidget);
      },
    );

    testWidgets('exits fullscreen mode when isFullscreen becomes false', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProVideoPlayerBuilder(
          controller: fixture.controller,
          builder: (context, controller, child) =>
              const Text('Normal View', textDirection: TextDirection.ltr),
          fullscreenBuilder: (context, controller, child) =>
              const Text('Fullscreen View', textDirection: TextDirection.ltr),
        ),
      );

      // Enter fullscreen
      fixture.eventController.add(
        const FullscreenStateChangedEvent(isFullscreen: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fullscreen View'), findsOneWidget);

      // Exit fullscreen
      fixture.eventController.add(
        const FullscreenStateChangedEvent(isFullscreen: false),
      );
      await tester.pumpAndSettle();
      expect(find.text('Normal View'), findsOneWidget);
    });

    // Note: PiP Android-specific behavior (pipBuilder usage) cannot be reliably
    // tested in unit tests as it depends on Platform.isAndroid which is determined
    // at compile time. The behavior is:
    // - Android: Uses pipBuilder when isPipActive is true (whole app in PiP window)
    // - iOS: Uses normal builder even when isPipActive is true (video floats independently)
    //
    // This is tested through integration tests on real devices.

    testWidgets('pipBuilder has correct signature', (tester) async {
      // This test verifies pipBuilder receives correct parameters when it would be called
      // The actual platform check (Android vs iOS) is tested via integration tests

      // Create the widget - pipBuilder will only be called on Android
      // but we can verify the builder signature is correct
      await tester.pumpWidget(
        ProVideoPlayerBuilder(
          controller: fixture.controller,
          child: const Text('Child', textDirection: TextDirection.ltr),
          builder: (context, ctrl, child) =>
              const Text('Normal', textDirection: TextDirection.ltr),
          pipBuilder: (context, ctrl, child) {
            // Verify parameters are passed correctly
            expect(ctrl, isA<ProVideoPlayerController>());
            return const Text('PiP', textDirection: TextDirection.ltr);
          },
        ),
      );

      // The widget builds successfully - platform-specific behavior tested in integration tests
      expect(find.text('Normal'), findsOneWidget);
    });

    group('default fullscreen behavior', () {
      testWidgets('uses 16:9 aspect ratio when video size is unknown', (
        tester,
      ) async {
        when(
          () => fixture.mockPlatform.buildView(
            any(),
            controlsMode: any(named: 'controlsMode'),
          ),
        ).thenReturn(const Text('Video', textDirection: TextDirection.ltr));

        await tester.pumpWidget(
          buildTestWidget(
            ProVideoPlayerBuilder(
              controller: fixture.controller,
              builder: (context, controller, child) =>
                  const Text('Normal View'),
            ),
          ),
        );

        // Don't send video size event - size will be null

        // Trigger fullscreen
        fixture.eventController.add(
          const FullscreenStateChangedEvent(isFullscreen: true),
        );
        await tester.pumpAndSettle();

        // Should have AspectRatio widget with default 16:9 ratio
        final aspectRatioFinder = find.byType(AspectRatio);
        expect(aspectRatioFinder, findsWidgets);

        // The first AspectRatio should be the one from _buildDefaultFullscreen
        final aspectRatios = tester
            .widgetList<AspectRatio>(aspectRatioFinder)
            .toList();
        // 16/9 ≈ 1.778
        final hasExpectedRatio = aspectRatios.any(
          (ar) => (ar.aspectRatio - 16 / 9).abs() < 0.01,
        );
        expect(hasExpectedRatio, isTrue);
      });

      testWidgets('wraps video in SafeArea', (tester) async {
        when(
          () => fixture.mockPlatform.buildView(
            any(),
            controlsMode: any(named: 'controlsMode'),
          ),
        ).thenReturn(const Text('Video', textDirection: TextDirection.ltr));

        await tester.pumpWidget(
          buildTestWidget(
            ProVideoPlayerBuilder(
              controller: fixture.controller,
              builder: (context, controller, child) =>
                  const Text('Normal View'),
            ),
          ),
        );

        // Trigger fullscreen
        fixture.eventController.add(
          const FullscreenStateChangedEvent(isFullscreen: true),
        );
        await tester.pumpAndSettle();

        // Should have SafeArea in the fullscreen view
        expect(find.byType(SafeArea), findsOneWidget);
      });

      testWidgets('uses black background', (tester) async {
        when(
          () => fixture.mockPlatform.buildView(
            any(),
            controlsMode: any(named: 'controlsMode'),
          ),
        ).thenReturn(const Text('Video', textDirection: TextDirection.ltr));

        await tester.pumpWidget(
          buildTestWidget(
            ProVideoPlayerBuilder(
              controller: fixture.controller,
              builder: (context, controller, child) =>
                  const Text('Normal View'),
            ),
          ),
        );

        // Trigger fullscreen
        fixture.eventController.add(
          const FullscreenStateChangedEvent(isFullscreen: true),
        );
        await tester.pumpAndSettle();

        // Should have at least one ColoredBox with black color
        final coloredBoxFinder = find.byType(ColoredBox);
        expect(coloredBoxFinder, findsWidgets);

        // Check that at least one ColoredBox has black background
        final coloredBoxes = tester
            .widgetList<ColoredBox>(coloredBoxFinder)
            .toList();
        final hasBlackBackground = coloredBoxes.any(
          (box) => box.color == const Color(0xFF000000),
        );
        expect(hasBlackBackground, isTrue);
      });
    });

    group('control mode preservation', () {
      testWidgets('default fullscreen view uses the same controlsMode', (
        tester,
      ) async {
        when(
          () => fixture.mockPlatform.buildView(
            any(),
            controlsMode: any(named: 'controlsMode'),
          ),
        ).thenReturn(const Text('Video', textDirection: TextDirection.ltr));

        await tester.pumpWidget(
          buildTestWidget(
            ProVideoPlayerBuilder(
              controller: fixture.controller,
              controlsMode: ControlsMode.none,
              builder: (context, controller, child) =>
                  const Text('Normal View'),
            ),
          ),
        );

        // Trigger fullscreen
        fixture.eventController.add(
          const FullscreenStateChangedEvent(isFullscreen: true),
        );
        await tester.pumpAndSettle();

        // Should show ProVideoPlayer with ControlsMode.none
        final playerFinder = find.byType(ProVideoPlayer);
        expect(playerFinder, findsOneWidget);

        final player = tester.widget<ProVideoPlayer>(playerFinder);
        expect(player.controlsMode, ControlsMode.none);
      });

      testWidgets('default fullscreen view uses the provided controlsBuilder', (
        tester,
      ) async {
        when(
          () => fixture.mockPlatform.buildView(
            any(),
            controlsMode: any(named: 'controlsMode'),
          ),
        ).thenReturn(const Text('Video', textDirection: TextDirection.ltr));

        var builderCalled = false;

        await tester.pumpWidget(
          buildTestWidget(
            ProVideoPlayerBuilder(
              controller: fixture.controller,
              controlsBuilder: (context, ctrl) {
                builderCalled = true;
                return const Text('Custom Controls');
              },
              builder: (context, controller, child) =>
                  const Text('Normal View'),
            ),
          ),
        );

        // Trigger fullscreen
        fixture.eventController.add(
          const FullscreenStateChangedEvent(isFullscreen: true),
        );
        await tester.pumpAndSettle();

        // The video remains separate from the controls overlay so the
        // controls can use the full fullscreen bounds.
        final playerFinder = find.byType(ProVideoPlayer);
        expect(playerFinder, findsOneWidget);

        final player = tester.widget<ProVideoPlayer>(playerFinder);
        expect(player.controlsBuilder, isNull);
        expect(player.controlsMode, ControlsMode.none);

        // The builder should be called during build
        expect(builderCalled, isTrue);
        expect(find.text('Custom Controls'), findsOneWidget);
      });

      testWidgets('default fullscreen maintains aspect ratio from video', (
        tester,
      ) async {
        when(
          () => fixture.mockPlatform.buildView(
            any(),
            controlsMode: any(named: 'controlsMode'),
          ),
        ).thenReturn(const Text('Video', textDirection: TextDirection.ltr));

        await tester.pumpWidget(
          buildTestWidget(
            ProVideoPlayerBuilder(
              controller: fixture.controller,
              builder: (context, controller, child) =>
                  const Text('Normal View'),
            ),
          ),
        );

        // Send video size event
        fixture.eventController.add(
          const VideoSizeChangedEvent(width: 1920, height: 1080),
        );
        await tester.pumpAndSettle();

        // Trigger fullscreen
        fixture.eventController.add(
          const FullscreenStateChangedEvent(isFullscreen: true),
        );
        await tester.pumpAndSettle();

        // Should have AspectRatio widget with 16:9 ratio
        final aspectRatioFinder = find.byType(AspectRatio);
        expect(aspectRatioFinder, findsWidgets);
      });
    });
  });
}
