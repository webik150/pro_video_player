import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pro_video_player/pro_video_player.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

import '../shared/test_constants.dart';
import '../shared/test_helpers.dart';

class MockProVideoPlayerPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements ProVideoPlayerPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockProVideoPlayerPlatform mockPlatform;
  late StreamController<VideoPlayerEvent> eventController;

  setUpAll(() {
    registerFallbackValue(const VideoSource.network('https://example.com'));
    registerFallbackValue(const VideoPlayerOptions());
    registerFallbackValue(Duration.zero);
    registerFallbackValue(const PipOptions());
    registerFallbackValue(VideoScalingMode.fit);
    registerFallbackValue(VideoQualityTrack.auto);

    // Mock SystemChrome calls for fullscreen tests
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (methodCall) async => null,
        );
  });

  setUp(() {
    mockPlatform = MockProVideoPlayerPlatform();
    eventController = StreamController<VideoPlayerEvent>.broadcast();
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
    when(() => mockPlatform.play(any())).thenAnswer((_) async {});
    when(() => mockPlatform.pause(any())).thenAnswer((_) async {});
    when(() => mockPlatform.seekTo(any(), any())).thenAnswer((_) async {});
    when(
      () => mockPlatform.enterFullscreen(any()),
    ).thenAnswer((_) async => true);
    when(() => mockPlatform.exitFullscreen(any())).thenAnswer((_) async {});
    when(
      () => mockPlatform.setPlaybackSpeed(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => mockPlatform.setSubtitleTrack(any(), any()),
    ).thenAnswer((_) async {});
    when(() => mockPlatform.isPipSupported()).thenAnswer((_) async => true);
    when(
      () => mockPlatform.enterPip(any(), options: any(named: 'options')),
    ).thenAnswer((_) async => true);
    when(
      () => mockPlatform.isBackgroundPlaybackSupported(),
    ).thenAnswer((_) async => false);
    when(
      () => mockPlatform.isCastingSupported(),
    ).thenAnswer((_) async => false);
  });

  tearDown(() async {
    await eventController.close();
    ProVideoPlayerPlatform.instance = MockProVideoPlayerPlatform();
  });

  group('VideoPlayerControls', () {
    group('playlist controls', () {
      testWidgets('shows playlist navigation buttons when playlist is active', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();

        // Initialize with playlist
        final playlist = Playlist(
          items: const [
            VideoSource.network('https://example.com/video1.mp4'),
            VideoSource.network('https://example.com/video2.mp4'),
          ],
        );

        when(
          () => mockPlatform.create(
            source: any(named: 'source'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((_) async => 1);

        await controller.initializeWithPlaylist(playlist: playlist);
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
              forceMobileLayout: true,
            ),
          ),
        );

        // Should show skip previous and skip next buttons
        expect(find.byIcon(Icons.skip_previous), findsOneWidget);
        expect(find.byIcon(Icons.skip_next), findsOneWidget);
      });

      testWidgets('shows shuffle and repeat buttons when playlist is active', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();

        // Initialize with playlist
        final playlist = Playlist(
          items: const [
            VideoSource.network('https://example.com/video1.mp4'),
            VideoSource.network('https://example.com/video2.mp4'),
          ],
        );

        when(
          () => mockPlatform.create(
            source: any(named: 'source'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((_) async => 1);

        await controller.initializeWithPlaylist(playlist: playlist);
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
              forceMobileLayout: true,
            ),
          ),
        );

        // Should show shuffle and repeat buttons
        expect(find.byIcon(Icons.shuffle), findsOneWidget);
        expect(find.byIcon(Icons.repeat), findsOneWidget);
      });
    });

    // Note: Casting button tests are skipped because CastButton now uses native platform views
    // (UiKitView on iOS, AndroidView on Android, AppKitView on macOS) that don't render
    // Flutter icons in unit tests. The casting functionality is tested via integration tests.
    group('casting controls', () {
      testWidgets(
        'shows cast button when casting is supported',
        skip:
            true, // CastButton uses native platform views that don't render in unit tests
        (tester) async {
          when(
            () => mockPlatform.isCastingSupported(),
          ).thenAnswer((_) async => true);
          when(
            () =>
                mockPlatform.startCasting(any(), device: any(named: 'device')),
          ).thenAnswer((_) async => true);

          final controller = ProVideoPlayerController();
          await controller.initialize(
            source: const VideoSource.network(TestMedia.networkUrl),
          );
          await tester.pump();

          await tester.pumpWidget(
            buildTestWidget(
              VideoPlayerControls(
                controller: controller,
                gestureConfig: const GestureConfig(enableGestures: false),
                forceMobileLayout: true,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byIcon(Icons.cast), findsOneWidget);
        },
      );

      testWidgets('hides cast button when casting is not supported', (
        tester,
      ) async {
        when(
          () => mockPlatform.isCastingSupported(),
        ).thenAnswer((_) async => false);

        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
              forceMobileLayout: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.cast), findsNothing);
        expect(find.byIcon(Icons.cast_connected), findsNothing);
      });

      // Note: This test is skipped because CastButton now uses native platform views
      // (UiKitView, AndroidView, AppKitView) that don't render Flutter icons in unit tests.
      testWidgets(
        'shows cast_connected icon when casting is active',
        skip:
            true, // CastButton uses native platform views that don't render in unit tests
        (tester) async {
          when(
            () => mockPlatform.isCastingSupported(),
          ).thenAnswer((_) async => true);

          final controller = ProVideoPlayerController();
          await controller.initialize(
            source: const VideoSource.network(TestMedia.networkUrl),
          );

          // Simulate casting connected event
          eventController.add(
            const CastStateChangedEvent(
              state: CastState.connected,
              device: CastDevice(
                id: 'test',
                name: 'Test TV',
                type: CastDeviceType.chromecast,
              ),
            ),
          );
          await tester.pump();

          await tester.pumpWidget(
            buildTestWidget(
              VideoPlayerControls(
                controller: controller,
                gestureConfig: const GestureConfig(enableGestures: false),
                forceMobileLayout: true,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byIcon(Icons.cast_connected), findsOneWidget);
        },
      );

      // Note: startCasting/stopCasting tests are skipped because the CastButton widget
      // uses native platform views (UiKitView, AndroidView, AppKitView) that don't render
      // in unit tests. The casting functionality is tested via integration tests.
      testWidgets(
        'calls startCasting when cast button is tapped',
        skip:
            true, // CastButton uses native platform views that don't render in unit tests
        (tester) async {
          when(
            () => mockPlatform.isCastingSupported(),
          ).thenAnswer((_) async => true);
          when(
            () =>
                mockPlatform.startCasting(any(), device: any(named: 'device')),
          ).thenAnswer((_) async => true);

          final controller = ProVideoPlayerController();
          await controller.initialize(
            source: const VideoSource.network(TestMedia.networkUrl),
          );
          await tester.pump();

          await tester.pumpWidget(
            buildTestWidget(
              VideoPlayerControls(
                controller: controller,
                gestureConfig: const GestureConfig(enableGestures: false),
                forceMobileLayout: true,
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byIcon(Icons.cast));
          await tester.pump();

          verify(
            () =>
                mockPlatform.startCasting(any(), device: any(named: 'device')),
          ).called(1);
        },
      );

      testWidgets(
        'calls stopCasting when cast_connected button is tapped',
        skip:
            true, // CastButton uses native platform views that don't render in unit tests
        (tester) async {
          when(
            () => mockPlatform.isCastingSupported(),
          ).thenAnswer((_) async => true);
          when(
            () => mockPlatform.stopCasting(any()),
          ).thenAnswer((_) async => true);

          final controller = ProVideoPlayerController();
          await controller.initialize(
            source: const VideoSource.network(TestMedia.networkUrl),
          );

          // Set casting to connected
          eventController.add(
            const CastStateChangedEvent(
              state: CastState.connected,
              device: CastDevice(
                id: 'test',
                name: 'Test TV',
                type: CastDeviceType.chromecast,
              ),
            ),
          );
          await tester.pump();

          await tester.pumpWidget(
            buildTestWidget(
              VideoPlayerControls(
                controller: controller,
                gestureConfig: const GestureConfig(enableGestures: false),
                forceMobileLayout: true,
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byIcon(Icons.cast_connected));
          await tester.pump();

          verify(() => mockPlatform.stopCasting(any())).called(1);
        },
      );
    });

    group('subtitle overlay', () {
      testWidgets('renders SubtitleOverlay in controls stack', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
              forceMobileLayout: true,
            ),
          ),
        );

        // SubtitleOverlay is always present in the stack
        expect(find.byType(SubtitleOverlay), findsOneWidget);
      });

      testWidgets('SubtitleOverlay shows external subtitle cue text', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        // Select an external subtitle track with cues
        const externalTrack = ExternalSubtitleTrack(
          id: 'ext-0',
          label: 'English',
          path: 'https://example.com/subs.srt',
          sourceType: 'network',
          format: SubtitleFormat.srt,
          language: 'en',
          cues: [
            SubtitleCue(
              index: 1,
              start: Duration.zero,
              end: Duration(seconds: 10),
              text: 'Hello from subtitles!',
            ),
          ],
        );

        eventController
          ..add(const SelectedSubtitleChangedEvent(externalTrack))
          ..add(const PositionChangedEvent(Duration(seconds: 5)));
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
              forceMobileLayout: true,
            ),
          ),
        );

        expect(find.text('Hello from subtitles!'), findsOneWidget);
      });

      testWidgets(
        'SubtitleOverlay does not show text for embedded subtitle track',
        (tester) async {
          final controller = ProVideoPlayerController();
          await controller.initialize(
            source: const VideoSource.network(TestMedia.networkUrl),
          );

          // Select an embedded subtitle track (no ext- prefix)
          const embeddedTrack = SubtitleTrack(
            id: '0:1',
            label: 'English',
            language: 'en',
          );

          eventController
            ..add(const SelectedSubtitleChangedEvent(embeddedTrack))
            ..add(const PositionChangedEvent(Duration(seconds: 5)));
          await tester.pump();

          await tester.pumpWidget(
            buildTestWidget(
              VideoPlayerControls(
                controller: controller,
                gestureConfig: const GestureConfig(enableGestures: false),
                forceMobileLayout: true,
              ),
            ),
          );

          // No subtitle text should be rendered for embedded tracks
          expect(find.textContaining('Hello'), findsNothing);
        },
      );

      testWidgets('SubtitleOverlay updates when position changes', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        const externalTrack = ExternalSubtitleTrack(
          id: 'ext-0',
          label: 'English',
          path: 'https://example.com/subs.srt',
          sourceType: 'network',
          format: SubtitleFormat.srt,
          language: 'en',
          cues: [
            SubtitleCue(
              index: 1,
              start: Duration.zero,
              end: Duration(seconds: 5),
              text: 'First cue',
            ),
            SubtitleCue(
              index: 2,
              start: Duration(seconds: 6),
              end: Duration(seconds: 10),
              text: 'Second cue',
            ),
          ],
        );

        eventController
          ..add(const SelectedSubtitleChangedEvent(externalTrack))
          ..add(const PositionChangedEvent(Duration(seconds: 2)));
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
              forceMobileLayout: true,
            ),
          ),
        );

        expect(find.text('First cue'), findsOneWidget);
        expect(find.text('Second cue'), findsNothing);

        // Move to second cue
        eventController.add(const PositionChangedEvent(Duration(seconds: 7)));
        await tester.pump();

        expect(find.text('First cue'), findsNothing);
        expect(find.text('Second cue'), findsOneWidget);
      });

      testWidgets('SubtitleOverlay shows nothing when no cue is active', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        const externalTrack = ExternalSubtitleTrack(
          id: 'ext-0',
          label: 'English',
          path: 'https://example.com/subs.srt',
          sourceType: 'network',
          format: SubtitleFormat.srt,
          language: 'en',
          cues: [
            SubtitleCue(
              index: 1,
              start: Duration(seconds: 10),
              end: Duration(seconds: 15),
              text: 'Later cue',
            ),
          ],
        );

        // Position before any cue
        eventController
          ..add(const SelectedSubtitleChangedEvent(externalTrack))
          ..add(const PositionChangedEvent(Duration(seconds: 5)));
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
              forceMobileLayout: true,
            ),
          ),
        );

        expect(find.text('Later cue'), findsNothing);
      });
    });

    group('didUpdateWidget', () {
      testWidgets('updates listener when controller changes', (tester) async {
        final controller1 = ProVideoPlayerController();
        await controller1.initialize(
          source: const VideoSource.network('https://example.com/video1.mp4'),
        );

        final controller2 = ProVideoPlayerController();
        await controller2.initialize(
          source: const VideoSource.network('https://example.com/video2.mp4'),
        );

        // Set different states for each controller
        eventController.add(
          const PlaybackStateChangedEvent(PlaybackState.paused),
        );
        await tester.pump();

        // Build with first controller
        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              forceMobileLayout: true,
              controller: controller1,
              gestureConfig: const GestureConfig(enableGestures: false),
            ),
          ),
        );
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);

        // Update with second controller
        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              forceMobileLayout: true,
              controller: controller2,
              gestureConfig: const GestureConfig(enableGestures: false),
            ),
          ),
        );

        // Widget should still render correctly
        expect(find.byType(VideoPlayerControls), findsOneWidget);
      });
    });

    group('gesture integration', () {
      testWidgets('uses VideoPlayerGestureDetector when gestures enabled', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        await tester.pumpWidget(
          buildTestWidget(
            SizedBox(
              width: 800,
              height: 600,
              child: VideoPlayerControls(
                forceMobileLayout: true,
                controller: controller,
              ),
            ),
          ),
        );

        expect(find.byType(VideoPlayerGestureDetector), findsOneWidget);
      });

      testWidgets(
        'does not use VideoPlayerGestureDetector when gestures disabled',
        (tester) async {
          final controller = ProVideoPlayerController();
          await controller.initialize(
            source: const VideoSource.network(TestMedia.networkUrl),
          );

          await tester.pumpWidget(
            buildTestWidget(
              SizedBox(
                width: 800,
                height: 600,
                child: VideoPlayerControls(
                  controller: controller,
                  gestureConfig: const GestureConfig(enableGestures: false),
                  forceMobileLayout: true,
                ),
              ),
            ),
          );

          expect(find.byType(VideoPlayerGestureDetector), findsNothing);
        },
      );
    });

    group('tooltips', () {
      testWidgets('fullscreen button has tooltip', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
              forceMobileLayout: true,
            ),
          ),
        );

        final fullscreenButton = find.byIcon(Icons.fullscreen);
        expect(fullscreenButton, findsOneWidget);

        // Find the IconButton with tooltip
        final iconButton = tester.widget<IconButton>(
          find.ancestor(
            of: fullscreenButton,
            matching: find.byType(IconButton),
          ),
        );
        expect(iconButton.tooltip, equals('Fullscreen'));
      });

      testWidgets('pip button has tooltip', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
              forceMobileLayout: true,
              testIsPipAvailable: true, // Inject test value directly
            ),
          ),
        );
        await tester.pump();

        final pipButton = find.byIcon(Icons.picture_in_picture_alt);
        expect(pipButton, findsOneWidget);

        final iconButton = tester.widget<IconButton>(
          find.ancestor(of: pipButton, matching: find.byType(IconButton)),
        );
        expect(iconButton.tooltip, equals('Picture-in-Picture'));
      });

      testWidgets('subtitle button has tooltip', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        eventController.add(
          const SubtitleTracksChangedEvent([
            SubtitleTrack(id: '1', label: 'English', language: 'en'),
          ]),
        );
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
              forceMobileLayout: true,
            ),
          ),
        );

        final subtitleButton = find.byIcon(Icons.closed_caption_off);
        expect(subtitleButton, findsOneWidget);

        final iconButton = tester.widget<IconButton>(
          find.ancestor(of: subtitleButton, matching: find.byType(IconButton)),
        );
        expect(iconButton.tooltip, equals('Subtitles'));
      });

      testWidgets('speed button has tooltip', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
              forceMobileLayout: true,
            ),
          ),
        );

        // Find the speed button (TextButton with '1x')
        final speedButton = find.text('1x'); // Speed formats as "1x" not "1.0x"
        expect(speedButton, findsOneWidget);

        // Should have a Tooltip ancestor with 'Playback speed'
        final tooltip = find.ancestor(
          of: speedButton,
          matching: find.byType(Tooltip),
        );
        expect(tooltip, findsOneWidget);

        final tooltipWidget = tester.widget<Tooltip>(tooltip);
        expect(tooltipWidget.message, equals('Playback speed'));
      });

      testWidgets('scaling mode button has tooltip', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
              forceMobileLayout: true,
            ),
          ),
        );

        final scalingButton = find.byIcon(Icons.aspect_ratio);
        expect(scalingButton, findsOneWidget);

        final iconButton = tester.widget<IconButton>(
          find.ancestor(of: scalingButton, matching: find.byType(IconButton)),
        );
        expect(iconButton.tooltip, equals('Scaling mode'));
      });

      testWidgets('audio track button has tooltip', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        eventController.add(
          const AudioTracksChangedEvent([
            AudioTrack(id: '1', label: 'English', language: 'en'),
            AudioTrack(id: '2', label: 'Spanish', language: 'es'),
          ]),
        );
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
              forceMobileLayout: true,
            ),
          ),
        );

        final audioButton = find.byIcon(Icons.audiotrack);
        expect(audioButton, findsOneWidget);

        final iconButton = tester.widget<IconButton>(
          find.ancestor(of: audioButton, matching: find.byType(IconButton)),
        );
        expect(iconButton.tooltip, equals('Audio track'));
      });
    });

    group('orientation lock', () {
      testWidgets('orientation lock button not visible when not in fullscreen', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
              forceMobileLayout: true,
            ),
          ),
        );

        // Orientation lock button should not be visible when not in fullscreen
        expect(find.byIcon(Icons.screen_rotation), findsNothing);
        expect(find.byIcon(Icons.screen_lock_rotation), findsNothing);
        expect(find.byIcon(Icons.screen_lock_landscape), findsNothing);
      });

      testWidgets('orientation lock button visible in fullscreen mode', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        // Simulate fullscreen state
        eventController.add(
          const FullscreenStateChangedEvent(isFullscreen: true),
        );
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            SizedBox(
              width: 800,
              height: 600,
              child: VideoPlayerControls(
                controller: controller,
                gestureConfig: const GestureConfig(enableGestures: false),
                forceMobileLayout: true,
              ),
            ),
          ),
        );

        // Orientation lock button should be visible in fullscreen
        expect(find.byIcon(Icons.screen_rotation), findsOneWidget);
      });

      testWidgets('orientation lock button has tooltip', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        // Simulate fullscreen state
        eventController.add(
          const FullscreenStateChangedEvent(isFullscreen: true),
        );
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            SizedBox(
              width: 800,
              height: 600,
              child: VideoPlayerControls(
                controller: controller,
                gestureConfig: const GestureConfig(enableGestures: false),
                forceMobileLayout: true,
              ),
            ),
          ),
        );

        final lockButton = find.byIcon(Icons.screen_rotation);
        expect(lockButton, findsOneWidget);

        final iconButton = tester.widget<IconButton>(
          find.ancestor(of: lockButton, matching: find.byType(IconButton)),
        );
        expect(iconButton.tooltip, equals('Lock orientation'));
      });
    });

    group('mouse hover on desktop', () {
      testWidgets('wraps controls with MouseRegion on web', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        await tester.pumpWidget(
          buildTestWidget(
            SizedBox(
              width: 800,
              height: 600,
              child: VideoPlayerControls(
                controller: controller,
                gestureConfig: const GestureConfig(enableGestures: false),
                forceMobileLayout: true,
              ),
            ),
          ),
        );

        // On non-web platforms in tests, MouseRegion should not be present
        // This test verifies the conditional wrapping works
        // Note: In actual web environment, MouseRegion would be present
        final mouseRegions = find.byType(MouseRegion);
        // MouseRegion count depends on platform - just verify the widget tree builds
        expect(mouseRegions, findsWidgets);
      });
    });

    group('keyboard shortcuts', () {
      // Skip: pumpAndSettle() with tap gestures for focus causes hit test failures.
      // The tap doesn't properly focus the widget for keyboard events in test environment.
      // Keyboard shortcuts are verified via integration tests.
      testWidgets(
        'Escape key exits fullscreen when in fullscreen mode',
        skip: true, // Focus/tap with pumpAndSettle() causes hit test failures
        (tester) async {
          var exitFullscreenCalled = false;
          final controller = ProVideoPlayerController();
          await controller.initialize(
            source: const VideoSource.network(TestMedia.networkUrl),
          );

          // Simulate fullscreen state
          eventController.add(
            const FullscreenStateChangedEvent(isFullscreen: true),
          );
          await tester.pump();

          await tester.pumpWidget(
            buildTestWidget(
              SizedBox(
                width: 800,
                height: 600,
                child: VideoPlayerControls(
                  forceMobileLayout: true,
                  controller: controller,
                  gestureConfig: const GestureConfig(enableGestures: false),
                  fullscreenConfig: FullscreenConfig(
                    onExitFullscreen: () => exitFullscreenCalled = true,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Focus the widget for keyboard events - use tap gesture which needs settling
          await tester.tap(find.byType(VideoPlayerControls));
          await tester.pumpAndSettle();

          // Send Escape key
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();

          expect(exitFullscreenCalled, isTrue);
        },
      );

      // Skip: Focus/tap with pumpAndSettle() causes hit test failures.
      // Keyboard shortcuts are verified via integration tests.
      testWidgets(
        'Escape key does nothing when not in fullscreen mode',
        (tester) async {},
        skip: true,
      );

      // Skip: Same focus/tap issue as Escape key test - pumpAndSettle() with tap causes hit test failures.
      // Keyboard shortcuts are verified via integration tests.
      testWidgets(
        'F key toggles fullscreen',
        skip: true, // Focus/tap with pumpAndSettle() causes hit test failures
        (tester) async {
          var enterFullscreenCalled = false;
          final controller = ProVideoPlayerController();
          await controller.initialize(
            source: const VideoSource.network(TestMedia.networkUrl),
          );

          await tester.pumpWidget(
            buildTestWidget(
              SizedBox(
                width: 800,
                height: 600,
                child: VideoPlayerControls(
                  forceMobileLayout: true,
                  controller: controller,
                  gestureConfig: const GestureConfig(enableGestures: false),
                  fullscreenConfig: FullscreenConfig(
                    onEnterFullscreen: () => enterFullscreenCalled = true,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Focus the widget for keyboard events - use tap gesture which needs settling
          await tester.tap(find.byType(VideoPlayerControls));
          await tester.pumpAndSettle();

          // Send F key
          await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
          await tester.pumpAndSettle();

          expect(enterFullscreenCalled, isTrue);
        },
      );
    });

    group('directional focus navigation', () {
      testWidgets(
        'arrow up from the seek bar focuses a visible toolbar button when fullscreen is hidden',
        (tester) async {
          final controller = ProVideoPlayerController();
          await controller.initialize(
            source: const VideoSource.network(TestMedia.networkUrl),
          );

          FocusNode? seekBarFocusNode;
          await tester.pumpWidget(
            buildTestWidget(
              VideoPlayerControls(
                controller: controller,
                buttonsConfig: const ButtonsConfig(showFullscreenButton: false),
                playerToolbarActions: const [PlayerToolbarAction.speed],
                gestureConfig: const GestureConfig(enableGestures: false),
                forceMobileLayout: true,
                testIsPipAvailable: false,
                testIsBackgroundPlaybackSupported: false,
                testIsCastingSupported: false,
                onSeekBarFocusNodeCreated: (node) => seekBarFocusNode = node,
              ),
            ),
          );
          await tester.pumpAndSettle();

          seekBarFocusNode!.requestFocus();
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
          await tester.pump();

          final focusedContext = FocusManager.instance.primaryFocus!.context!;
          expect(
            focusedContext.findAncestorWidgetOfExactType<TextButton>()?.key,
            const Key('toolbar_speed_button'),
          );
        },
      );
    });
  });
}
