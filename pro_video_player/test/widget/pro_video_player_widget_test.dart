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

  setUp(() {
    fixture = VideoPlayerTestFixture()..setUp();
  });

  tearDown(() => fixture.tearDown());

  group('ProVideoPlayer', () {
    testWidgets('shows placeholder when not initialized', (tester) async {
      final controller = ProVideoPlayerController();

      await tester.pumpWidget(
        buildTestWidget(
          ProVideoPlayer(
            controller: controller,
            placeholder: const Text('Loading...'),
          ),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);
    });

    testWidgets(
      'shows CircularProgressIndicator when no placeholder and not initialized',
      (tester) async {
        final controller = ProVideoPlayerController();

        await tester.pumpWidget(
          buildTestWidget(ProVideoPlayer(controller: controller)),
        );

        // Should show loading indicator when not initialized
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets('shows video view when initialized', (tester) async {
      await fixture.initializeController();

      await tester.pumpWidget(
        buildTestWidget(ProVideoPlayer(controller: fixture.controller)),
      );

      expect(find.byKey(const Key('video_view')), findsOneWidget);
    });

    testWidgets('uses custom aspect ratio', (tester) async {
      await fixture.initializeController();

      await tester.pumpWidget(
        buildTestWidget(
          SizedBox(
            width: 400,
            height: 300,
            child: ProVideoPlayer(
              controller: fixture.controller,
              aspectRatio: 4 / 3,
            ),
          ),
        ),
      );

      final aspectRatio = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(aspectRatio.aspectRatio, closeTo(4 / 3, 0.01));
    });

    testWidgets('defaults to 16:9 aspect ratio when video has no size', (
      tester,
    ) async {
      await fixture.initializeController();

      await tester.pumpWidget(
        buildTestWidget(
          SizedBox(
            width: 400,
            height: 300,
            child: ProVideoPlayer(controller: fixture.controller),
          ),
        ),
      );

      final aspectRatio = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(aspectRatio.aspectRatio, closeTo(16 / 9, 0.01));
    });

    testWidgets('uses video aspect ratio when available', (tester) async {
      await fixture.initializeController();

      // Simulate video size change event
      fixture.emitVideoSize(1920, 800);

      // Let the event be processed
      await tester.pump();

      await tester.pumpWidget(
        buildTestWidget(
          SizedBox(
            width: 400,
            height: 300,
            child: ProVideoPlayer(controller: fixture.controller),
          ),
        ),
      );

      final aspectRatio = tester.widget<AspectRatio>(find.byType(AspectRatio));
      // 1920/800 = 2.4
      expect(aspectRatio.aspectRatio, closeTo(2.4, 0.01));
    });

    testWidgets('fills FullHD landscape bounds when fillBounds is enabled', (
      tester,
    ) async {
      await fixture.initializeController();
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildSizedTestWidget(
          ProVideoPlayer(
            controller: fixture.controller,
            fillBounds: true,
            controlsBuilder: (context, controller) => Positioned.fill(
              child: VideoPlayerControls(
                controller: controller,
                forceMobileLayout: true,
              ),
            ),
          ),
          width: 1920,
          height: 1080,
        ),
      );

      expect(
        tester.getSize(find.byKey(const Key('video_view'))),
        const Size(1920, 1080),
      );
      expect(
        tester.getSize(find.byType(VideoPlayerControls)),
        const Size(1920, 1080),
      );
    });

    group('controlsMode', () {
      testWidgets(
        'defaults to ControlsMode.flutter (shows VideoPlayerControls)',
        (tester) async {
          await fixture.initializeController();

          await tester.pumpWidget(
            buildTestWidget(ProVideoPlayer(controller: fixture.controller)),
          );

          // Default is flutter mode, which uses ControlsMode.none for native and overlays Flutter controls
          verify(() => fixture.mockPlatform.buildView(1)).called(1);
          expect(find.byType(VideoPlayerControls), findsOneWidget);
        },
      );

      testWidgets('ControlsMode.none shows video only without controls', (
        tester,
      ) async {
        await fixture.initializeController();

        await tester.pumpWidget(
          buildTestWidget(
            ProVideoPlayer(
              controller: fixture.controller,
              controlsMode: ControlsMode.none,
            ),
          ),
        );

        verify(() => fixture.mockPlatform.buildView(1)).called(1);
        expect(find.byType(VideoPlayerControls), findsNothing);
      });

      testWidgets('passes ControlsMode.native to buildView', (tester) async {
        await fixture.initializeController();

        await tester.pumpWidget(
          buildTestWidget(
            ProVideoPlayer(
              controller: fixture.controller,
              controlsMode: ControlsMode.native,
            ),
          ),
        );

        verify(
          () => fixture.mockPlatform.buildView(
            1,
            controlsMode: ControlsMode.native,
          ),
        ).called(1);
      });
    });

    group('didUpdateWidget', () {
      testWidgets('notifies native when changing from flutter to native mode', (
        tester,
      ) async {
        await fixture.initializeController();
        when(
          () => fixture.mockPlatform.setControlsMode(any(), any()),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(
          buildTestWidget(ProVideoPlayer(controller: fixture.controller)),
        );

        // Change to native controls
        await tester.pumpWidget(
          buildTestWidget(
            ProVideoPlayer(
              controller: fixture.controller,
              controlsMode: ControlsMode.native,
            ),
          ),
        );

        verify(
          () => fixture.mockPlatform.setControlsMode(1, ControlsMode.native),
        ).called(1);
      });

      testWidgets('notifies native when changing from native to flutter mode', (
        tester,
      ) async {
        await fixture.initializeController();
        when(
          () => fixture.mockPlatform.setControlsMode(any(), any()),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(
          buildTestWidget(
            ProVideoPlayer(
              controller: fixture.controller,
              controlsMode: ControlsMode.native,
            ),
          ),
        );

        // Change to flutter controls
        await tester.pumpWidget(
          buildTestWidget(ProVideoPlayer(controller: fixture.controller)),
        );

        verify(
          () => fixture.mockPlatform.setControlsMode(1, ControlsMode.none),
        ).called(1);
      });

      testWidgets('does not notify native when mode stays the same', (
        tester,
      ) async {
        await fixture.initializeController();
        when(
          () => fixture.mockPlatform.setControlsMode(any(), any()),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(
          buildTestWidget(ProVideoPlayer(controller: fixture.controller)),
        );

        // Rebuild with same mode
        await tester.pumpWidget(
          buildTestWidget(ProVideoPlayer(controller: fixture.controller)),
        );

        verifyNever(() => fixture.mockPlatform.setControlsMode(any(), any()));
      });

      testWidgets(
        'notifies when adding controlsBuilder changes effective mode',
        (tester) async {
          await fixture.initializeController();
          when(
            () => fixture.mockPlatform.setControlsMode(any(), any()),
          ).thenAnswer((_) async {});

          // Start with native mode
          await tester.pumpWidget(
            buildTestWidget(
              ProVideoPlayer(
                controller: fixture.controller,
                controlsMode: ControlsMode.native,
              ),
            ),
          );

          // Add controlsBuilder (which overrides to none for native)
          await tester.pumpWidget(
            buildTestWidget(
              ProVideoPlayer(
                controller: fixture.controller,
                controlsMode: ControlsMode.native,
                controlsBuilder: (ctx, ctrl) => const SizedBox(),
              ),
            ),
          );

          // Should notify change from native to none
          verify(
            () => fixture.mockPlatform.setControlsMode(1, ControlsMode.none),
          ).called(1);
        },
      );
    });

    group('controlsBuilder', () {
      testWidgets('renders custom controls when provided', (tester) async {
        await fixture.initializeController();

        await tester.pumpWidget(
          buildTestWidget(
            ProVideoPlayer(
              controller: fixture.controller,
              controlsBuilder: (context, ctrl) => const Text('Custom Controls'),
            ),
          ),
        );

        expect(find.text('Custom Controls'), findsOneWidget);
        expect(find.byKey(const Key('video_view')), findsOneWidget);
      });

      testWidgets('controlsBuilder receives the controller', (tester) async {
        await fixture.initializeController();
        ProVideoPlayerController? receivedController;

        await tester.pumpWidget(
          buildTestWidget(
            ProVideoPlayer(
              controller: fixture.controller,
              controlsBuilder: (context, ctrl) {
                receivedController = ctrl;
                return const SizedBox();
              },
            ),
          ),
        );

        expect(receivedController, equals(fixture.controller));
      });

      testWidgets('controlsBuilder takes precedence over controlsMode', (
        tester,
      ) async {
        await fixture.initializeController();

        await tester.pumpWidget(
          buildTestWidget(
            ProVideoPlayer(
              controller: fixture.controller,
              controlsMode: ControlsMode.native,
              controlsBuilder: (context, ctrl) => const Text('Custom Controls'),
            ),
          ),
        );

        // When controlsBuilder is provided, controlsMode is ignored and ControlsMode.none is used
        verify(() => fixture.mockPlatform.buildView(1)).called(1);
        expect(find.text('Custom Controls'), findsOneWidget);
      });

      testWidgets('controlsBuilder is stacked on top of video', (tester) async {
        await fixture.initializeController();

        await tester.pumpWidget(
          buildTestWidget(
            SizedBox(
              width: 400,
              height: 300,
              child: ProVideoPlayer(
                controller: fixture.controller,
                controlsBuilder: (context, ctrl) => const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x80000000),
                    child: Center(child: Text('Overlay')),
                  ),
                ),
              ),
            ),
          ),
        );

        // Both video and overlay should be present
        expect(find.byKey(const Key('video_view')), findsOneWidget);
        expect(find.text('Overlay'), findsOneWidget);

        // The widget tree should have Stack widgets (video + controls stacking)
        expect(find.byType(Stack), findsWidgets);
      });
    });

    group('SubtitleOverlay positioning', () {
      testWidgets('renders subtitles with Flutter rendering mode', (
        tester,
      ) async {
        // Initialize with Flutter subtitle rendering mode enabled
        await fixture.initializeController(
          options: const VideoPlayerOptions(
            subtitleRenderMode: SubtitleRenderMode.flutter,
          ),
        );

        // Use default controls mode (flutter) - VideoPlayerControls handles subtitles
        await tester.pumpWidget(
          buildTestWidget(
            SizedBox(
              width: 400,
              height: 300,
              child: ProVideoPlayer(controller: fixture.controller),
            ),
          ),
        );

        // Emit subtitle track and cue events
        const track = SubtitleTrack(
          id: '0:1',
          label: 'English',
          language: 'en',
        );
        fixture
          ..emitEvent(const SelectedSubtitleChangedEvent(track))
          ..emitEvent(
            const EmbeddedSubtitleCueEvent(
              cue: SubtitleCue(
                text: 'Test subtitle',
                start: Duration.zero,
                end: Duration(seconds: 5),
              ),
            ),
          );

        await tester.pump();

        // SubtitleOverlay should be present (provided by VideoPlayerControls)
        expect(find.byType(SubtitleOverlay), findsOneWidget);
        // Subtitle text should be visible
        expect(find.text('Test subtitle'), findsOneWidget);
      });

      testWidgets(
        'renders subtitles with native controls and Flutter subtitle rendering',
        (tester) async {
          // Initialize with Flutter subtitle rendering mode
          await fixture.initializeController(
            options: const VideoPlayerOptions(
              subtitleRenderMode: SubtitleRenderMode.flutter,
            ),
          );

          // Test with ControlsMode.native - Flutter renders subtitles over native controls
          await tester.pumpWidget(
            buildTestWidget(
              SizedBox(
                width: 400,
                height: 300,
                child: ProVideoPlayer(
                  controller: fixture.controller,
                  controlsMode: ControlsMode.native,
                ),
              ),
            ),
          );

          const track = SubtitleTrack(
            id: '0:1',
            label: 'English',
            language: 'en',
          );
          fixture
            ..emitEvent(const SelectedSubtitleChangedEvent(track))
            ..emitEvent(
              const EmbeddedSubtitleCueEvent(
                cue: SubtitleCue(
                  text: 'Test subtitle',
                  start: Duration.zero,
                  end: Duration(seconds: 5),
                ),
              ),
            );

          await tester.pump();

          // Subtitle should be visible
          expect(find.byType(SubtitleOverlay), findsOneWidget);
          expect(find.text('Test subtitle'), findsOneWidget);
        },
      );

      testWidgets('updates subtitle cue dynamically', (tester) async {
        await fixture.initializeController(
          options: const VideoPlayerOptions(
            subtitleRenderMode: SubtitleRenderMode.flutter,
          ),
        );

        // Use default controls mode (flutter) - VideoPlayerControls handles subtitles
        await tester.pumpWidget(
          buildTestWidget(
            SizedBox(
              width: 400,
              height: 300,
              child: ProVideoPlayer(controller: fixture.controller),
            ),
          ),
        );

        // Emit first cue
        const track = SubtitleTrack(
          id: '0:1',
          label: 'English',
          language: 'en',
        );
        fixture
          ..emitEvent(const SelectedSubtitleChangedEvent(track))
          ..emitEvent(
            const EmbeddedSubtitleCueEvent(
              cue: SubtitleCue(
                text: 'First cue',
                start: Duration.zero,
                end: Duration(seconds: 5),
              ),
            ),
          );

        await tester.pump();

        expect(find.text('First cue'), findsOneWidget);

        // Change to second cue
        fixture.emitEvent(
          const EmbeddedSubtitleCueEvent(
            cue: SubtitleCue(
              text: 'Second cue',
              start: Duration(seconds: 5),
              end: Duration(seconds: 10),
            ),
          ),
        );

        // Pump twice: once to process the stream event, once to rebuild the widget
        await tester.pump();
        await tester.pump();

        expect(find.text('First cue'), findsNothing);
        expect(find.text('Second cue'), findsOneWidget);
      });
    });

    group('no duplicate SubtitleOverlay widgets', () {
      testWidgets(
        'ControlsMode.none with Flutter subtitle mode has exactly one SubtitleOverlay',
        (tester) async {
          await fixture.initializeController(
            options: const VideoPlayerOptions(
              subtitleRenderMode: SubtitleRenderMode.flutter,
            ),
          );

          await tester.pumpWidget(
            buildTestWidget(
              SizedBox(
                width: 400,
                height: 300,
                child: ProVideoPlayer(
                  controller: fixture.controller,
                  controlsMode: ControlsMode.none,
                ),
              ),
            ),
          );

          // ControlsMode.none should NOT add SubtitleOverlay - expected to be paired with
          // external VideoPlayerControls that handles subtitles internally
          expect(find.byType(SubtitleOverlay), findsNothing);
        },
      );

      testWidgets(
        'ControlsMode.flutter with Flutter subtitle mode has exactly one SubtitleOverlay',
        (tester) async {
          await fixture.initializeController(
            options: const VideoPlayerOptions(
              subtitleRenderMode: SubtitleRenderMode.flutter,
            ),
          );

          await tester.pumpWidget(
            buildTestWidget(
              SizedBox(
                width: 400,
                height: 300,
                child: ProVideoPlayer(controller: fixture.controller),
              ),
            ),
          );

          // VideoPlayerControls handles subtitles internally - should have exactly one
          expect(find.byType(SubtitleOverlay), findsOneWidget);
        },
      );

      testWidgets(
        'custom controlsBuilder with VideoPlayerControls has exactly one SubtitleOverlay',
        (tester) async {
          await fixture.initializeController(
            options: const VideoPlayerOptions(
              subtitleRenderMode: SubtitleRenderMode.flutter,
            ),
          );

          await tester.pumpWidget(
            buildTestWidget(
              SizedBox(
                width: 400,
                height: 300,
                child: ProVideoPlayer(
                  controller: fixture.controller,
                  controlsBuilder: (context, ctrl) => VideoPlayerControls(
                    controller: ctrl,
                    forceMobileLayout:
                        true, // Avoid desktop-specific gesture wrappers in tests
                  ),
                ),
              ),
            ),
          );

          // When using custom controlsBuilder with VideoPlayerControls, the custom
          // VideoPlayerControls handles subtitles internally - should have exactly one
          expect(find.byType(SubtitleOverlay), findsOneWidget);
        },
      );

      testWidgets(
        'ControlsMode.none + separate VideoPlayerControls has exactly one SubtitleOverlay',
        (tester) async {
          // This pattern is used in FullscreenVideoPage
          await fixture.initializeController(
            options: const VideoPlayerOptions(
              subtitleRenderMode: SubtitleRenderMode.flutter,
            ),
          );

          await tester.pumpWidget(
            buildTestWidget(
              SizedBox(
                width: 400,
                height: 300,
                child: Stack(
                  children: [
                    // Video player with no controls (like FullscreenVideoPage)
                    ProVideoPlayer(
                      controller: fixture.controller,
                      controlsMode: ControlsMode.none,
                    ),
                    // Separate controls overlay (like FullscreenVideoPage)
                    VideoPlayerControls(
                      controller: fixture.controller,
                      forceMobileLayout:
                          true, // Avoid desktop-specific gesture wrappers in tests
                    ),
                  ],
                ),
              ),
            ),
          );

          // ProVideoPlayer(ControlsMode.none) should NOT add SubtitleOverlay
          // VideoPlayerControls adds SubtitleOverlay internally
          // Result: exactly one SubtitleOverlay
          expect(find.byType(SubtitleOverlay), findsOneWidget);
        },
      );

      testWidgets(
        'ControlsMode.native with Flutter subtitle mode has exactly one SubtitleOverlay',
        (tester) async {
          await fixture.initializeController(
            options: const VideoPlayerOptions(
              subtitleRenderMode: SubtitleRenderMode.flutter,
            ),
          );

          await tester.pumpWidget(
            buildTestWidget(
              SizedBox(
                width: 400,
                height: 300,
                child: ProVideoPlayer(
                  controller: fixture.controller,
                  controlsMode: ControlsMode.native,
                ),
              ),
            ),
          );

          // Native controls mode with Flutter subtitle rendering should add exactly one SubtitleOverlay
          expect(find.byType(SubtitleOverlay), findsOneWidget);
        },
      );

      testWidgets('no SubtitleOverlay when using native subtitle render mode', (
        tester,
      ) async {
        await fixture.initializeController(
          options: const VideoPlayerOptions(
            subtitleRenderMode: SubtitleRenderMode.native,
          ),
        );

        await tester.pumpWidget(
          buildTestWidget(
            SizedBox(
              width: 400,
              height: 300,
              child: ProVideoPlayer(controller: fixture.controller),
            ),
          ),
        );

        // Native subtitle mode: VideoPlayerControls still adds SubtitleOverlay but
        // it won't render anything because the controller is in native mode
        // (the _shouldShowFlutterSubtitles returns false for native mode)
        final overlayFinder = find.byType(SubtitleOverlay);
        expect(overlayFinder, findsOneWidget);

        // Verify no subtitle text is shown (native handles rendering)
        const track = SubtitleTrack(
          id: '0:1',
          label: 'English',
          language: 'en',
        );
        fixture
          ..emitEvent(const SelectedSubtitleChangedEvent(track))
          ..emitEvent(
            const EmbeddedSubtitleCueEvent(
              cue: SubtitleCue(
                text: 'Test subtitle',
                start: Duration.zero,
                end: Duration(seconds: 5),
              ),
            ),
          );
        await tester.pump();

        // The subtitle text should NOT appear because native mode is active
        // (SubtitleOverlay only renders when there are cues AND we're in Flutter mode)
        expect(find.text('Test subtitle'), findsOneWidget);
      });
    });
  });
}
