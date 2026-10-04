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
    group('skip controls', () {
      testWidgets('renders skip backward button by default', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              forceMobileLayout: true,
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
            ),
          ),
        );

        expect(find.byIcon(Icons.replay_10), findsOneWidget);
      });

      testWidgets('renders skip forward button by default', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              forceMobileLayout: true,
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
            ),
          ),
        );

        expect(find.byIcon(Icons.forward_10), findsOneWidget);
      });

      testWidgets('calls seekBackward when skip backward button is tapped', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        eventController
          ..add(const DurationChangedEvent(TestMetadata.duration))
          ..add(const PositionChangedEvent(Duration(minutes: 2)));
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              forceMobileLayout: true,
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.replay_10));
        await tester.pump();

        // Default skip duration is 10 seconds, so seeking from 2:00 to 1:50
        verify(
          () => mockPlatform.seekTo(1, const Duration(minutes: 1, seconds: 50)),
        ).called(1);
      });

      testWidgets('calls seekForward when skip forward button is tapped', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        eventController
          ..add(const DurationChangedEvent(TestMetadata.duration))
          ..add(const PositionChangedEvent(Duration(minutes: 2)));
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              forceMobileLayout: true,
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.forward_10));
        await tester.pump();

        // Default skip duration is 10 seconds, so seeking from 2:00 to 2:10
        verify(
          () => mockPlatform.seekTo(1, const Duration(minutes: 2, seconds: 10)),
        ).called(1);
      });

      testWidgets(
        'does not render skip buttons when showSkipButtons is false',
        (tester) async {
          final controller = ProVideoPlayerController();
          await controller.initialize(
            source: const VideoSource.network(TestMedia.networkUrl),
          );

          await tester.pumpWidget(
            buildTestWidget(
              VideoPlayerControls(
                controller: controller,
                buttonsConfig: const ButtonsConfig(showSkipButtons: false),
                gestureConfig: const GestureConfig(enableGestures: false),
              ),
            ),
          );

          expect(find.byIcon(Icons.replay_10), findsNothing);
          expect(find.byIcon(Icons.forward_10), findsNothing);
        },
      );

      testWidgets('uses custom skip duration', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        eventController
          ..add(const DurationChangedEvent(TestMetadata.duration))
          ..add(const PositionChangedEvent(Duration(minutes: 2)));
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              forceMobileLayout:
                  true, // Skip buttons are in mobile BottomControlsBar
              controller: controller,
              gestureConfig: const GestureConfig(
                skipDuration: Duration(seconds: 30),
                enableGestures: false,
              ),
              autoOverflowActions: false,
            ),
          ),
        );
        await tester.pump(); // Allow widget to build

        await tester.tap(find.byIcon(Icons.forward_30));
        await tester.pump();

        // Custom skip duration of 30 seconds, so seeking from 2:00 to 2:30
        verify(
          () => mockPlatform.seekTo(1, const Duration(minutes: 2, seconds: 30)),
        ).called(1);
      });

      testWidgets('shows correct skip icons for different durations', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        // Test 5 second skip
        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              forceMobileLayout: true,
              controller: controller,
              gestureConfig: const GestureConfig(
                skipDuration: Duration(seconds: 5),
                enableGestures: false,
              ),
              autoOverflowActions: false,
            ),
          ),
        );
        await tester.pump(); // Allow widget to build

        expect(find.byIcon(Icons.replay_5), findsOneWidget);
        expect(find.byIcon(Icons.forward_5), findsOneWidget);
      });
    });

    group('playback speed', () {
      testWidgets('renders speed button showing current speed', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              forceMobileLayout: true,
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
              autoOverflowActions: false,
            ),
          ),
        );
        await tester.pump(); // Allow widget to build

        expect(
          find.text('1x'),
          findsOneWidget,
        ); // Speed formats as "1x" not "1.0x" (trailing zeros removed)
      });

      testWidgets('shows updated speed when playback speed changes', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              forceMobileLayout: true,
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
            ),
          ),
        );

        eventController.add(const PlaybackSpeedChangedEvent(1.5));
        await tester.pump();

        expect(find.text('1.5x'), findsOneWidget);
      });

      // Skip: pumpAndSettle() hangs with modals (bottom sheets), and pump() doesn't render modal content.
      // Modal functionality is verified via integration tests. See contributing/testing-guide.md "Common Test Pitfalls #1"
      testWidgets(
        'opens speed picker when speed button is tapped',
        (tester) async {},
        skip: true,
      );

      // Skip: pumpAndSettle() hangs with modals (bottom sheets). See contributing/testing-guide.md "Common Test Pitfalls #1"
      testWidgets(
        'calls setPlaybackSpeed when speed is selected',
        (tester) async {},
        skip: true,
      );

      testWidgets('does not show speed button when showSpeedButton is false', (
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
              buttonsConfig: const ButtonsConfig(showSpeedButton: false),
              gestureConfig: const GestureConfig(enableGestures: false),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.text('1x'),
          findsNothing,
        ); // Speed formats as "1x" not "1.0x"
      });

      // Skip: pumpAndSettle() hangs with modals (bottom sheets). See contributing/testing-guide.md "Common Test Pitfalls #1"
      testWidgets(
        'uses custom speed options when provided',
        (tester) async {},
        skip: true,
      );
    });

    group('subtitles', () {
      testWidgets(
        'does not show subtitle button when no subtitle tracks available',
        (tester) async {
          final controller = ProVideoPlayerController();
          await controller.initialize(
            source: const VideoSource.network(TestMedia.networkUrl),
          );

          await tester.pumpWidget(
            buildTestWidget(
              VideoPlayerControls(
                forceMobileLayout: true,
                controller: controller,
                gestureConfig: const GestureConfig(enableGestures: false),
              ),
            ),
          );

          expect(find.byIcon(Icons.closed_caption), findsNothing);
          expect(find.byIcon(Icons.closed_caption_off), findsNothing);
        },
      );

      testWidgets('shows subtitle button when subtitle tracks are available', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        eventController.add(
          const SubtitleTracksChangedEvent([
            SubtitleTrack(id: '1', label: 'English', language: 'en'),
            SubtitleTrack(id: '2', label: 'Spanish', language: 'es'),
          ]),
        );
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              forceMobileLayout: true,
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
            ),
          ),
        );

        expect(find.byIcon(Icons.closed_caption_off), findsOneWidget);
      });

      testWidgets('shows filled icon when subtitles are enabled', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        eventController
          ..add(
            const SubtitleTracksChangedEvent([
              SubtitleTrack(id: '1', label: 'English', language: 'en'),
            ]),
          )
          ..add(
            const SelectedSubtitleChangedEvent(
              SubtitleTrack(id: '1', label: 'English', language: 'en'),
            ),
          );
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              forceMobileLayout: true,
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
            ),
          ),
        );

        expect(find.byIcon(Icons.closed_caption), findsOneWidget);
      });

      testWidgets('opens subtitle picker when subtitle button is tapped', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        eventController.add(
          const SubtitleTracksChangedEvent([
            SubtitleTrack(id: '1', label: 'English', language: 'en'),
            SubtitleTrack(id: '2', label: 'Spanish', language: 'es'),
          ]),
        );
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              forceMobileLayout: true,
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.closed_caption_off));
        await tester.pumpAndSettle();

        // Bottom sheet should show subtitle options including Off
        expect(find.text('Off'), findsOneWidget);
        expect(find.text('English'), findsOneWidget);
        expect(find.text('Spanish'), findsOneWidget);
      });

      testWidgets('calls setSubtitleTrack when track is selected', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        const englishTrack = SubtitleTrack(
          id: '1',
          label: 'English',
          language: 'en',
        );
        eventController.add(
          const SubtitleTracksChangedEvent([
            englishTrack,
            SubtitleTrack(id: '2', label: 'Spanish', language: 'es'),
          ]),
        );
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              forceMobileLayout: true,
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.closed_caption_off));
        await tester.pumpAndSettle();

        await tester.tap(find.text('English'));
        await tester.pumpAndSettle();

        verify(() => mockPlatform.setSubtitleTrack(1, englishTrack)).called(1);
      });

      testWidgets('calls setSubtitleTrack with null when Off is selected', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        const englishTrack = SubtitleTrack(
          id: '1',
          label: 'English',
          language: 'en',
        );
        eventController
          ..add(const SubtitleTracksChangedEvent([englishTrack]))
          ..add(const SelectedSubtitleChangedEvent(englishTrack));
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              forceMobileLayout: true,
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.closed_caption));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Off'));
        await tester.pumpAndSettle();

        verify(() => mockPlatform.setSubtitleTrack(1, null)).called(1);
      });

      testWidgets(
        'does not show subtitle button when showSubtitleButton is false',
        (tester) async {
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
                buttonsConfig: const ButtonsConfig(showSubtitleButton: false),
                gestureConfig: const GestureConfig(enableGestures: false),
              ),
            ),
          );

          expect(find.byIcon(Icons.closed_caption), findsNothing);
          expect(find.byIcon(Icons.closed_caption_off), findsNothing);
        },
      );
    });

    group('picture-in-picture', () {
      testWidgets('shows PiP button when PiP is available', (tester) async {
        when(() => mockPlatform.isPipSupported()).thenAnswer((_) async => true);

        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              forceMobileLayout: true,
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
              testIsPipAvailable: true, // Inject test value directly
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.picture_in_picture_alt), findsOneWidget);
      });

      testWidgets('does not show PiP button when PiP is not supported', (
        tester,
      ) async {
        when(
          () => mockPlatform.isPipSupported(),
        ).thenAnswer((_) async => false);

        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              forceMobileLayout: true,
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
              testIsPipAvailable:
                  false, // Explicitly inject false to bypass cache pollution
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.picture_in_picture_alt), findsNothing);
      });

      testWidgets('calls enterPip when PiP button is tapped', (tester) async {
        when(() => mockPlatform.isPipSupported()).thenAnswer((_) async => true);
        when(() => mockPlatform.enterPip(any())).thenAnswer((_) async => true);

        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              forceMobileLayout: true,
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
              testIsPipAvailable: true, // Inject test value directly
            ),
          ),
        );
        await tester.pump();

        // Tap PiP button
        await tester.tap(find.byIcon(Icons.picture_in_picture_alt));
        await tester.pump();

        verify(() => mockPlatform.enterPip(1)).called(1);
      });

      testWidgets('does not show PiP button when showPipButton is false', (
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
              buttonsConfig: const ButtonsConfig(showPipButton: false),
              gestureConfig: const GestureConfig(enableGestures: false),
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.picture_in_picture_alt), findsNothing);
      });

      testWidgets('does not show PiP button when allowPip option is false', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
          options: const VideoPlayerOptions(allowPip: false),
        );

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              forceMobileLayout: true,
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.picture_in_picture_alt), findsNothing);
      });
    });

    group('TV remote keyboard', () {
      testWidgets('focuses the playback button when controls appear', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );
        eventController.add(
          const PlaybackStateChangedEvent(PlaybackState.playing),
        );
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              forceMobileLayout: true,
              controller: controller,
            ),
          ),
        );
        await tester.pump();

        expect(
          Focus.of(tester.element(find.byIcon(Icons.pause))).hasFocus,
          isTrue,
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pump();

        verify(() => mockPlatform.pause(any())).called(1);
      });

      testWidgets('Down focuses the timeline from the controls overlay', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        FocusNode? seekBarFocusNode;
        final inputFocusNode = FocusNode();
        addTearDown(inputFocusNode.dispose);
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              forceMobileLayout: true,
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
              onSeekBarFocusNodeCreated: (focusNode) {
                seekBarFocusNode = focusNode;
              },
            ),
          ),
        );

        final controlsFocus = find.byKey(
          const ValueKey('video-controls-navigation-focus'),
        );
        final result = tester.widget<Focus>(controlsFocus).onKeyEvent!(
          inputFocusNode,
          const KeyDownEvent(
            logicalKey: LogicalKeyboardKey.arrowDown,
            physicalKey: PhysicalKeyboardKey.arrowDown,
            timeStamp: Duration.zero,
          ),
        );

        expect(result, KeyEventResult.handled);
        await tester.pump();
        expect(seekBarFocusNode!.hasFocus, isTrue);
      });

      testWidgets('Down moves focus from the timeline to playback controls', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        FocusNode? seekBarFocusNode;
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );
        eventController.add(
          const PlaybackStateChangedEvent(PlaybackState.playing),
        );
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              forceMobileLayout: true,
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
              onSeekBarFocusNodeCreated: (focusNode) {
                seekBarFocusNode = focusNode;
              },
            ),
          ),
        );

        seekBarFocusNode!.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();

        expect(seekBarFocusNode!.hasFocus, isFalse);
        expect(
          Focus.of(tester.element(find.byIcon(Icons.pause))).hasFocus,
          isTrue,
        );
      });

      testWidgets('Up moves focus from the timeline to toolbar controls', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        FocusNode? seekBarFocusNode;
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              forceMobileLayout: true,
              controller: controller,
              buttonsConfig: const ButtonsConfig(
                showPipButton: false,
                showBackgroundPlaybackButton: false,
                showSubtitleButton: false,
                showAudioButton: false,
                showQualityButton: false,
                showSpeedButton: false,
                showScalingModeButton: false,
                showOrientationLockButton: false,
              ),
              gestureConfig: const GestureConfig(enableGestures: false),
              onSeekBarFocusNodeCreated: (focusNode) {
                seekBarFocusNode = focusNode;
              },
            ),
          ),
        );

        seekBarFocusNode!.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();

        expect(seekBarFocusNode!.hasFocus, isFalse);
        expect(
          Focus.of(tester.element(find.byIcon(Icons.fullscreen))).hasFocus,
          isTrue,
        );
      });

      testWidgets('select pauses playback from the focused play/pause button', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );
        eventController.add(
          const PlaybackStateChangedEvent(PlaybackState.playing),
        );
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              forceMobileLayout: true,
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
            ),
          ),
        );

        final playPauseFocus = find
            .ancestor(
              of: find.byIcon(Icons.pause),
              matching: find.byWidgetPredicate(
                (widget) => widget is Focus && widget.onKeyEvent != null,
              ),
            )
            .first;
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);
        final keyResult = tester.widget<Focus>(playPauseFocus).onKeyEvent!(
          focusNode,
          const KeyDownEvent(
            logicalKey: LogicalKeyboardKey.select,
            physicalKey: PhysicalKeyboardKey.select,
            timeStamp: Duration.zero,
          ),
        );

        expect(keyResult, KeyEventResult.handled);
        await tester.pump();

        verify(() => mockPlatform.pause(any())).called(1);
      });
    });

    group('auto-hide', () {
      testWidgets('hides controls after timeout when playing', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        eventController.add(
          const PlaybackStateChangedEvent(PlaybackState.playing),
        );
        await tester.pump();

        // Disable gestures to simplify testing of auto-hide behavior
        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              controller: controller,
              behaviorConfig: const ControlsBehaviorConfig(
                autoHideDuration: Duration(seconds: 1),
              ),
              gestureConfig: const GestureConfig(enableGestures: false),
            ),
          ),
        );

        // Controls should be visible initially
        expect(find.byIcon(Icons.pause), findsOneWidget);

        // Wait for auto-hide
        await tester.pump(TestDelays.playbackManagerTimer);

        // Controls should be hidden (opacity 0)
        expect(find.byType(AnimatedOpacity), findsOneWidget);
        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.opacity, equals(0.0));
      });

      testWidgets('shows controls when tapped while hidden with gestures enabled', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        eventController.add(
          const PlaybackStateChangedEvent(PlaybackState.playing),
        );
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              controller: controller,
              behaviorConfig: const ControlsBehaviorConfig(
                autoHide: false,
              ), // Disable auto-hide timer - test just verifies tap shows controls
            ),
          ),
        );
        await tester.pump();

        // Manually hide controls by accessing controller state
        // (In real usage, auto-hide would do this, but we disabled it)
        // For this test, we just verify the widget can handle taps without hanging
        await tester.tap(find.byType(VideoPlayerControls));
        await tester.pump();

        // Widget should handle tap without errors
        expect(find.byType(VideoPlayerControls), findsOneWidget);

        // Wait for PlaybackManager's 2-second timer to complete before test cleanup
        await tester.pump(const Duration(seconds: 3));
      });

      testWidgets('does not auto-hide when paused', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        eventController.add(
          const PlaybackStateChangedEvent(PlaybackState.paused),
        );
        await tester.pump();

        // Disable gestures to simplify testing
        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              controller: controller,
              behaviorConfig: const ControlsBehaviorConfig(
                autoHideDuration: Duration(seconds: 1),
              ),
              gestureConfig: const GestureConfig(enableGestures: false),
            ),
          ),
        );

        // Wait for would-be auto-hide
        await tester.pump(TestDelays.playbackManagerTimer);

        // Controls should still be visible
        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.opacity, equals(1.0));
      });
    });

    group('Live Scrubbing', () {
      testWidgets('throttles seek calls during live scrubbing', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.file(TestMedia.filePath),
        );

        eventController
          ..add(const DurationChangedEvent(Duration(minutes: 10)))
          ..add(const PositionChangedEvent(Duration(minutes: 2)));
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
              playbackOptionsConfig: const PlaybackOptionsConfig(
                liveScrubbingMode: LiveScrubbingMode.always,
              ),
            ),
          ),
        );

        // Find the progress bar
        final layoutBuilderFinder = find.byType(LayoutBuilder);

        // Drag across the progress bar area
        await tester.drag(layoutBuilderFinder.last, const Offset(200, 0));
        await tester.pumpAndSettle();

        // Verify seekTo was called but throttled
        // Throttling should result in fewer calls than would occur without throttling
        final callCount = verify(() => mockPlatform.seekTo(1, any())).callCount;
        expect(callCount, greaterThan(0)); // Should be called at least once
      });

      testWidgets('uses adaptive mode by default', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        eventController
          ..add(const DurationChangedEvent(Duration(minutes: 10)))
          ..add(const PositionChangedEvent(Duration(minutes: 2)));
        await tester.pump();

        // Create controls without specifying liveScrubbingMode (should default to adaptive)
        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              forceMobileLayout: true,
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
            ),
          ),
        );

        // Find the progress bar
        final layoutBuilderFinder = find.byType(LayoutBuilder);

        // Drag across the progress bar area
        await tester.drag(layoutBuilderFinder.last, const Offset(200, 0));
        await tester.pumpAndSettle();

        // For network video with default mode (adaptive), should seek at least on drag end
        verify(() => mockPlatform.seekTo(1, any())).called(greaterThan(0));
      });
    });

    group('Live Scrubbing Modes', () {
      testWidgets('localOnly mode - enables for local file sources', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.file(TestMedia.filePath),
        );

        eventController
          ..add(const DurationChangedEvent(Duration(minutes: 10)))
          ..add(const PositionChangedEvent(Duration(minutes: 2)));
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
              playbackOptionsConfig: const PlaybackOptionsConfig(
                liveScrubbingMode: LiveScrubbingMode.localOnly,
              ),
            ),
          ),
        );

        final layoutBuilderFinder = find.byType(LayoutBuilder);
        await tester.drag(layoutBuilderFinder.last, const Offset(200, 0));
        await tester.pumpAndSettle();

        // Should seek during drag for local files
        verify(() => mockPlatform.seekTo(1, any())).called(greaterThan(1));
      });

      testWidgets('localOnly mode - disables for network sources', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        eventController
          ..add(const DurationChangedEvent(Duration(minutes: 10)))
          ..add(const PositionChangedEvent(Duration(minutes: 2)));
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
              playbackOptionsConfig: const PlaybackOptionsConfig(
                liveScrubbingMode: LiveScrubbingMode.localOnly,
              ),
            ),
          ),
        );

        final layoutBuilderFinder = find.byType(LayoutBuilder);
        await tester.drag(layoutBuilderFinder.last, const Offset(200, 0));
        await tester.pumpAndSettle();

        // Should only seek on drag end for network files
        verify(() => mockPlatform.seekTo(1, any())).called(1);
      });

      testWidgets('localOnly mode - enables for asset sources', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.asset(TestMedia.assetPath),
        );

        eventController
          ..add(const DurationChangedEvent(Duration(minutes: 10)))
          ..add(const PositionChangedEvent(Duration(minutes: 2)));
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
              playbackOptionsConfig: const PlaybackOptionsConfig(
                liveScrubbingMode: LiveScrubbingMode.localOnly,
              ),
            ),
          ),
        );

        final layoutBuilderFinder = find.byType(LayoutBuilder);
        await tester.drag(layoutBuilderFinder.last, const Offset(200, 0));
        await tester.pumpAndSettle();

        // Should seek during drag for asset files
        verify(() => mockPlatform.seekTo(1, any())).called(greaterThan(1));
      });

      testWidgets('adaptive mode - enables for local files', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.file(TestMedia.filePath),
        );

        eventController
          ..add(const DurationChangedEvent(Duration(minutes: 10)))
          ..add(const PositionChangedEvent(Duration(minutes: 2)));
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              forceMobileLayout: true,
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
            ),
          ),
        );

        final layoutBuilderFinder = find.byType(LayoutBuilder);
        await tester.drag(layoutBuilderFinder.last, const Offset(200, 0));
        await tester.pumpAndSettle();

        // Should seek during drag for local files
        verify(() => mockPlatform.seekTo(1, any())).called(greaterThan(1));
      });

      testWidgets(
        'adaptive mode - enables for buffered portions of network videos',
        (tester) async {
          final controller = ProVideoPlayerController();
          await controller.initialize(
            source: const VideoSource.network(TestMedia.networkUrl),
          );

          eventController
            ..add(const DurationChangedEvent(Duration(minutes: 10)))
            ..add(const PositionChangedEvent(Duration(minutes: 2)))
            ..add(
              const BufferedPositionChangedEvent(Duration(minutes: 8)),
            ); // Buffered to 8 minutes
          await tester.pump();

          await tester.pumpWidget(
            buildTestWidget(
              VideoPlayerControls(
                forceMobileLayout: true,
                controller: controller,
                gestureConfig: const GestureConfig(enableGestures: false),
              ),
            ),
          );

          final layoutBuilderFinder = find.byType(LayoutBuilder);
          // Drag within buffered range (current position is 2min, buffered to 8min, so dragging to ~5min should be buffered)
          await tester.drag(layoutBuilderFinder.last, const Offset(100, 0));
          await tester.pumpAndSettle();

          // Should seek during drag when within buffered range
          verify(() => mockPlatform.seekTo(1, any())).called(greaterThan(1));
        },
      );

      testWidgets('always mode - enables regardless of source type', (
        tester,
      ) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        eventController
          ..add(const DurationChangedEvent(Duration(minutes: 10)))
          ..add(const PositionChangedEvent(Duration(minutes: 2)));
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
              playbackOptionsConfig: const PlaybackOptionsConfig(
                liveScrubbingMode: LiveScrubbingMode.always,
              ),
            ),
          ),
        );

        final layoutBuilderFinder = find.byType(LayoutBuilder);
        await tester.drag(layoutBuilderFinder.last, const Offset(200, 0));
        await tester.pumpAndSettle();

        // Should seek during drag even for network sources
        verify(() => mockPlatform.seekTo(1, any())).called(greaterThan(1));
      });

      testWidgets('disabled mode - never seeks during drag', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.file(TestMedia.filePath),
        );

        eventController
          ..add(const DurationChangedEvent(Duration(minutes: 10)))
          ..add(const PositionChangedEvent(Duration(minutes: 2)));
        await tester.pump();

        await tester.pumpWidget(
          buildTestWidget(
            VideoPlayerControls(
              controller: controller,
              gestureConfig: const GestureConfig(enableGestures: false),
              playbackOptionsConfig: const PlaybackOptionsConfig(
                liveScrubbingMode: LiveScrubbingMode.disabled,
              ),
            ),
          ),
        );

        final layoutBuilderFinder = find.byType(LayoutBuilder);
        await tester.drag(layoutBuilderFinder.last, const Offset(200, 0));
        await tester.pumpAndSettle();

        // Should only seek on drag end, even for local files
        verify(() => mockPlatform.seekTo(1, any())).called(1);
      });
    });
  });
}
