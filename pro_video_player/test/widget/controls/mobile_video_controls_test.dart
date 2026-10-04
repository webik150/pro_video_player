import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player/pro_video_player.dart';

import '../../shared/test_constants.dart';
import '../../shared/test_helpers.dart';
import '../../shared/test_setup.dart';

// Mock for VideoControlsState
class MockVideoControlsState {
  bool get visible => true;
  bool get isFullyVisible => true;
  bool get hideInstantly => false;
  Timer? get hideTimer => null;
  bool? get isPipAvailable => null;
  bool? get isBackgroundPlaybackSupported => null;
  bool? get isCastingSupported => null;
  bool get showRemainingTime => false;
  bool get isDragging => false;
  double? get dragProgress => null;
  bool get isMouseOverControls => false;
  Timer? get keyboardOverlayTimer => null;
  KeyboardOverlayType? get keyboardOverlayType => null;
  double? get keyboardOverlayValue => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VideoPlayerTestFixture fixture;
  late MockVideoControlsState mockControlsState;

  setUpAll(registerVideoPlayerFallbackValues);

  setUp(() {
    fixture = VideoPlayerTestFixture()..setUp();
    mockControlsState = MockVideoControlsState();
  });

  tearDown(() async {
    await fixture.tearDown();
  });

  MobileVideoControls buildMobileControls({
    required ProVideoPlayerController controller,
    VideoPlayerTheme? theme,
    Duration? gestureSeekPosition,
    bool showSkipButtons = true,
    Duration skipDuration = const Duration(seconds: 10),
    LiveScrubbingMode liveScrubbingMode = LiveScrubbingMode.adaptive,
    bool showSeekBarHoverPreview = false,
    FocusNode? seekBarFocusNode,
    bool showSubtitleButton = true,
    bool showAudioButton = false,
    bool showQualityButton = false,
    bool showSpeedButton = true,
    bool showScalingModeButton = false,
    bool showBackgroundPlaybackButton = false,
    bool showPipButton = true,
    bool showOrientationLockButton = false,
    bool showFullscreenButton = true,
    List<PlayerToolbarAction>? playerToolbarActions,
    int? maxPlayerToolbarActions,
    bool autoOverflowActions = true,
    VoidCallback? onDismiss,
    bool isDesktopPlatform = false,
    Widget? centerControls,
  }) => MobileVideoControls(
    controller: controller,
    theme: theme ?? VideoPlayerTheme.light(),
    controlsState: mockControlsState,
    gestureSeekPosition: gestureSeekPosition,
    showSkipButtons: showSkipButtons,
    skipDuration: skipDuration,
    liveScrubbingMode: liveScrubbingMode,
    showSeekBarHoverPreview: showSeekBarHoverPreview,
    seekBarFocusNode: seekBarFocusNode,
    showSubtitleButton: showSubtitleButton,
    showAudioButton: showAudioButton,
    showQualityButton: showQualityButton,
    showSpeedButton: showSpeedButton,
    showScalingModeButton: showScalingModeButton,
    showBackgroundPlaybackButton: showBackgroundPlaybackButton,
    showPipButton: showPipButton,
    showOrientationLockButton: showOrientationLockButton,
    showFullscreenButton: showFullscreenButton,
    playerToolbarActions: playerToolbarActions,
    maxPlayerToolbarActions: maxPlayerToolbarActions,
    autoOverflowActions: autoOverflowActions,
    onDismiss: onDismiss,
    isDesktopPlatform: isDesktopPlatform,
    onDragStart: () {},
    onDragEnd: () {},
    onToggleTimeDisplay: () {},
    onShowQualityPicker: (_, __) {},
    onShowSubtitlePicker: (_, __) {},
    onShowAudioPicker: (_, __) {},
    onShowChaptersPicker: (_, __) {},
    onShowSpeedPicker: (_, __) {},
    onShowScalingModePicker: (_) {},
    onShowOrientationLockPicker: (_) {},
    onFullscreenEnter: () {},
    onFullscreenExit: () {},
    centerControls: centerControls ?? const SizedBox(),
  );

  group('MobileVideoControls', () {
    testWidgets('fills the available video bounds', (tester) async {
      final controller = ProVideoPlayerController();
      await controller.initialize(
        source: const VideoSource.network(TestMedia.networkUrl),
      );

      await tester.pumpWidget(
        buildTestWidget(
          SizedBox(
            width: 640,
            height: 360,
            child: buildMobileControls(controller: controller),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(MobileVideoControls)),
        const Size(640, 360),
      );
    });

    group('basic rendering', () {
      testWidgets('renders with correct layout structure', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        await tester.pumpWidget(
          buildTestWidget(buildMobileControls(controller: controller)),
        );
        await tester.pump();

        // Verify basic structure
        expect(find.byType(MobileVideoControls), findsOneWidget);
        expect(find.byType(ClipRect), findsOneWidget);
        expect(find.byType(Column), findsWidgets);
      });

      testWidgets('shows three main sections', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        await tester.pumpWidget(
          buildTestWidget(buildMobileControls(controller: controller)),
        );
        await tester.pump();

        // Should have: top toolbar, center controls, bottom bar
        expect(find.byType(PlayerToolbar), findsOneWidget);
        expect(find.byType(BottomControlsBar), findsOneWidget);
      });
    });

    group('gradient overlays', () {
      testWidgets('shows two gradient overlays', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        await tester.pumpWidget(
          buildTestWidget(buildMobileControls(controller: controller)),
        );
        await tester.pump();

        // Find gradient decorations
        final decoratedBoxes = tester.widgetList<DecoratedBox>(
          find.byType(DecoratedBox),
        );
        final gradients = decoratedBoxes
            .where((box) => box.decoration is BoxDecoration)
            .map((box) => (box.decoration as BoxDecoration).gradient)
            .whereType<LinearGradient>()
            .toList();

        // Should have 2 gradients
        expect(gradients.length, 2);

        // Top gradient: black → transparent
        expect(gradients[0].colors[0], Colors.black.withValues(alpha: 0.7));
        expect(gradients[0].colors[1], Colors.transparent);

        // Bottom gradient: transparent → black
        expect(gradients[1].colors[0], Colors.transparent);
        expect(gradients[1].colors[1], Colors.black.withValues(alpha: 0.7));
      });

      testWidgets('gradients are aligned top to bottom', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        await tester.pumpWidget(
          buildTestWidget(buildMobileControls(controller: controller)),
        );
        await tester.pump();

        final decoratedBoxes = tester.widgetList<DecoratedBox>(
          find.byType(DecoratedBox),
        );
        final gradients = decoratedBoxes
            .where((box) => box.decoration is BoxDecoration)
            .map((box) => (box.decoration as BoxDecoration).gradient)
            .whereType<LinearGradient>()
            .toList();

        for (final gradient in gradients) {
          expect(gradient.begin, Alignment.topCenter);
          expect(gradient.end, Alignment.bottomCenter);
        }
      });
    });

    group('fullscreen padding', () {
      testWidgets(
        'adds padding when in fullscreen',
        (tester) async {
          final controller = ProVideoPlayerController();
          await controller.initialize(
            source: const VideoSource.network(TestMedia.networkUrl),
          );

          // Enter fullscreen
          fixture.eventController.add(
            const FullscreenStateChangedEvent(isFullscreen: true),
          );
          await tester.pump(TestDelays.eventPropagation);

          await tester.pumpWidget(
            buildTestWidget(buildMobileControls(controller: controller)),
          );
          await tester.pump();

          // Find paddings in the widget tree
          final paddings = tester.widgetList<Padding>(find.byType(Padding));

          // Should have top padding (24) and bottom padding (44)
          final topPadding = paddings.firstWhere(
            (p) => p.padding == const EdgeInsets.only(top: 24),
          );
          final bottomPadding = paddings.firstWhere(
            (p) => p.padding == const EdgeInsets.only(bottom: 44),
          );

          expect(topPadding, isNotNull);
          expect(bottomPadding, isNotNull);
        },
        skip: true,
      ); // TODO: This test hangs indefinitely - needs investigation

      testWidgets('has no padding when not in fullscreen', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        // Not in fullscreen (default - no need to emit event)

        await tester.pumpWidget(
          buildTestWidget(buildMobileControls(controller: controller)),
        );
        await tester.pump();

        final paddings = tester.widgetList<Padding>(find.byType(Padding));

        // Should have zero padding
        final topPadding = paddings.firstWhere(
          (p) => p.padding == EdgeInsets.zero,
        );
        final bottomPadding = paddings.firstWhere(
          (p) => p.padding == EdgeInsets.zero,
        );

        expect(topPadding, isNotNull);
        expect(bottomPadding, isNotNull);
      });
    });

    group('child widget integration', () {
      testWidgets('shows PlayerToolbar in top section', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        await tester.pumpWidget(
          buildTestWidget(buildMobileControls(controller: controller)),
        );
        await tester.pump();

        expect(find.byType(PlayerToolbar), findsOneWidget);
      });

      testWidgets('shows BottomControlsBar in bottom section', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        await tester.pumpWidget(
          buildTestWidget(buildMobileControls(controller: controller)),
        );
        await tester.pump();

        expect(find.byType(BottomControlsBar), findsOneWidget);
      });

      testWidgets('shows provided center controls', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        final centerWidget = Container(
          key: const Key('custom-center'),
          child: const Text('Center Controls'),
        );

        await tester.pumpWidget(
          buildTestWidget(
            buildMobileControls(
              controller: controller,
              centerControls: centerWidget,
            ),
          ),
        );
        await tester.pump();

        expect(find.byKey(const Key('custom-center')), findsOneWidget);
        expect(find.text('Center Controls'), findsOneWidget);
      });
    });

    group('callback propagation', () {
      testWidgets('passes callbacks to PlayerToolbar', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        await tester.pumpWidget(
          buildTestWidget(buildMobileControls(controller: controller)),
        );
        await tester.pump();

        // Verify PlayerToolbar receives configuration
        final toolbar = tester.widget<PlayerToolbar>(
          find.byType(PlayerToolbar),
        );
        expect(toolbar.showSubtitleButton, isTrue);
        expect(toolbar.showSpeedButton, isTrue);
      });

      testWidgets('passes callbacks to BottomControlsBar', (tester) async {
        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        await tester.pumpWidget(
          buildTestWidget(
            buildMobileControls(
              controller: controller,
              showSkipButtons: false,
              skipDuration: const Duration(seconds: 15),
            ),
          ),
        );
        await tester.pump();

        // Verify BottomControlsBar receives configuration
        final bottomBar = tester.widget<BottomControlsBar>(
          find.byType(BottomControlsBar),
        );
        expect(bottomBar.showSkipButtons, isFalse);
        expect(bottomBar.skipDuration, const Duration(seconds: 15));
      });
    });

    group('theme styling', () {
      testWidgets('passes theme to child widgets', (tester) async {
        final theme = VideoPlayerTheme.light().copyWith(
          primaryColor: Colors.red,
          backgroundColor: Colors.black,
        );

        final controller = ProVideoPlayerController();
        await controller.initialize(
          source: const VideoSource.network(TestMedia.networkUrl),
        );

        await tester.pumpWidget(
          buildTestWidget(
            buildMobileControls(controller: controller, theme: theme),
          ),
        );
        await tester.pump();

        // Verify theme is passed to child widgets
        final toolbar = tester.widget<PlayerToolbar>(
          find.byType(PlayerToolbar),
        );
        expect(toolbar.theme.primaryColor, Colors.red);

        final bottomBar = tester.widget<BottomControlsBar>(
          find.byType(BottomControlsBar),
        );
        expect(bottomBar.theme.primaryColor, Colors.red);
      });
    });
  });
}
