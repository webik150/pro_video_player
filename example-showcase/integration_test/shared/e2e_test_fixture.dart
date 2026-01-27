import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/e2e_helpers.dart';
import '../helpers/e2e_memory_tracker.dart';
import '../helpers/e2e_navigation.dart' as nav;
import '../helpers/e2e_platform.dart';
import 'e2e_constants.dart';
import 'e2e_viewport.dart';

/// Internal class to track section timing information.
class _SectionTiming {
  _SectionTiming(this.name, this.durationMs);

  final String name;
  final int durationMs;

  double get durationSeconds => durationMs / 1000;
}

/// E2E test fixture providing common setup and utilities for integration tests.
///
/// This fixture eliminates boilerplate by providing:
/// - Viewport setup based on platform
/// - Section timing and logging
/// - Memory leak detection (optional)
/// - Convenient access to all E2E helper functions
///
/// Usage:
/// ```dart
/// testWidgets('My E2E test', (tester) async {
///   final fixture = E2ETestFixture();
///   await fixture.setUp(tester);
///
///   fixture.startSection('Test setup');
///   // ... test code ...
///   fixture.endSection('Test setup');
///
///   fixture.tearDown();
/// });
/// ```
class E2ETestFixture {
  /// Creates an E2E test fixture.
  ///
  /// Parameters:
  /// - [setViewport]: Whether to automatically set viewport size (default: true)
  /// - [customViewportSize]: Custom viewport size (overrides platform default)
  /// - [enableDetailedLogging]: Whether to log detailed platform/viewport info (default: false)
  /// - [trackMemory]: Whether to track memory usage and detect leaks (default: false)
  /// - [memoryLeakThresholdMB]: Memory growth threshold in MB to warn about leaks (default: 50.0)
  E2ETestFixture({
    this.setViewport = true,
    this.customViewportSize,
    this.enableDetailedLogging = false,
    this.trackMemory = false,
    this.memoryLeakThresholdMB = 50.0,
  });

  /// Whether to automatically set viewport size.
  final bool setViewport;

  /// Custom viewport size (overrides platform default).
  final Size? customViewportSize;

  /// Whether to log detailed platform/viewport info.
  final bool enableDetailedLogging;

  /// Whether to track memory usage and detect leaks.
  final bool trackMemory;

  /// Memory growth threshold in MB to warn about leaks.
  final double memoryLeakThresholdMB;

  // Internal state
  Stopwatch? _sectionStopwatch;
  late Stopwatch _totalStopwatch;
  Size? _actualViewportSize;
  E2EMemoryTracker? _memoryTracker;
  final List<_SectionTiming> _sectionTimings = [];

  /// The actual viewport size that was set during setUp.
  Size? get viewportSize => _actualViewportSize;

  /// Total elapsed time since setUp was called.
  Duration get totalElapsed => _totalStopwatch.elapsed;

  // ==========================================================================
  // Setup & Teardown
  // ==========================================================================

  /// Sets up the test fixture.
  ///
  /// Call this at the beginning of your test, after `pumpWidget()`.
  ///
  /// Example:
  /// ```dart
  /// testWidgets('My test', (tester) async {
  ///   final fixture = E2ETestFixture();
  ///   await tester.pumpWidget(MyApp());
  ///   await fixture.setUp(tester);
  ///   // ... test code ...
  /// });
  /// ```
  Future<void> setUp(WidgetTester tester) async {
    // Start total timer
    _totalStopwatch = Stopwatch()..start();

    // Set up viewport
    if (setViewport) {
      await _setupViewport(tester);
    }

    // Set up memory tracking
    if (trackMemory) {
      _memoryTracker = E2EMemoryTracker(leakThresholdMB: memoryLeakThresholdMB);
      await _memoryTracker!.captureBaseline('Test setUp');
    }

    // Log platform info if requested
    if (enableDetailedLogging) {
      logPlatformInfo();
      if (_actualViewportSize != null) {
        logViewportInfo(tester);
      }
    }
  }

  /// Tears down the test fixture.
  ///
  /// Call this at the end of your test to clean up resources.
  ///
  /// Example:
  /// ```dart
  /// testWidgets('My test', (tester) async {
  ///   final fixture = E2ETestFixture();
  ///   await fixture.setUp(tester);
  ///   // ... test code ...
  ///   fixture.tearDown(); // Clean up
  /// });
  /// ```
  void tearDown() {
    // Print memory report if tracking was enabled
    if (_memoryTracker != null) {
      _memoryTracker!.printReport();

      // Warn about potential leaks
      if (_memoryTracker!.hasLeak()) {
        final growth = _memoryTracker!.getMemoryGrowth();
        debugPrint('\n⚠️  WARNING: Potential memory leak detected!');
        debugPrint('   Memory grew by ${growth.toStringAsFixed(1)}MB during test execution.');
        debugPrint('   Review the memory report above for details.\n');
      }
    }

    // Stop timers
    _totalStopwatch.stop();
    _sectionStopwatch?.stop();

    // Print comprehensive timing summary
    _printTimingSummary();
  }

  void _printTimingSummary() {
    if (_sectionTimings.isEmpty) {
      return;
    }

    final totalMs = _totalStopwatch.elapsedMilliseconds;
    final totalSeconds = totalMs / 1000;

    debugPrint('\n${'=' * 80}');
    debugPrint('E2E TEST TIMING SUMMARY');
    debugPrint('=' * 80);

    // Print header
    debugPrint(
      '${'Section'.padRight(40)}${'Time (s)'.padLeft(12)}${'Time (ms)'.padLeft(12)}${'% of Total'.padLeft(12)}',
    );
    debugPrint('-' * 80);

    // Print each section
    for (final section in _sectionTimings) {
      final percentage = (section.durationMs / totalMs * 100).toStringAsFixed(1);
      final line =
          '${section.name.padRight(40)}'
          '${section.durationSeconds.toStringAsFixed(1).padLeft(12)}'
          '${section.durationMs.toString().padLeft(12)}'
          '${'$percentage%'.padLeft(12)}';
      debugPrint(line);
    }

    debugPrint('-' * 80);
    final totalLine =
        '${'TOTAL'.padRight(40)}'
        '${totalSeconds.toStringAsFixed(1).padLeft(12)}'
        '${totalMs.toString().padLeft(12)}'
        '${'100.0%'.padLeft(12)}';
    debugPrint(totalLine);
    debugPrint('${'=' * 80}\n');
  }

  Future<void> _setupViewport(WidgetTester tester) async {
    if (customViewportSize != null) {
      // Use custom size
      await tester.setViewport(customViewportSize!);
      _actualViewportSize = customViewportSize;
    } else {
      // Use platform default
      _actualViewportSize = await tester.setDefaultViewportForPlatform();
    }
  }

  // ==========================================================================
  // Section Timing
  // ==========================================================================

  /// Starts timing a test section.
  ///
  /// Call this at the beginning of a logical test section to start timing.
  /// Follow with [endSection] to log the elapsed time.
  ///
  /// If memory tracking is enabled, captures a memory snapshot.
  ///
  /// Example:
  /// ```dart
  /// fixture.startSection('Video loading');
  /// // ... video loading code ...
  /// fixture.endSection('Video loading');
  /// // Output: <<< END: Video loading (2.5s) [Total: 5.2s]
  /// ```
  void startSection(String name) {
    _sectionStopwatch = Stopwatch()..start();
    debugPrint('\n>>> START: $name');
  }

  /// Ends timing a test section and logs the elapsed time.
  ///
  /// Must be called after [startSection].
  ///
  /// If memory tracking is enabled, captures a memory snapshot.
  ///
  /// Example:
  /// ```dart
  /// fixture.startSection('Navigation');
  /// await navigateToDemo(tester, cardKey, title);
  /// fixture.endSection('Navigation');
  /// ```
  Future<void> endSection(String name) async {
    // Capture memory snapshot before logging
    if (_memoryTracker != null) {
      await _memoryTracker!.captureSnapshot('End of $name');
    }

    _sectionStopwatch?.stop();
    final elapsed = _sectionStopwatch?.elapsedMilliseconds ?? 0;
    final totalElapsed = _totalStopwatch.elapsedMilliseconds;

    // Record section timing for summary report
    _sectionTimings.add(_SectionTiming(name, elapsed));

    debugPrint(
      '<<< END: $name (${elapsed}ms / ${(elapsed / 1000).toStringAsFixed(1)}s) '
      '[Total: ${(totalElapsed / 1000).toStringAsFixed(1)}s]',
    );
  }

  /// Times a section automatically using a callback.
  ///
  /// Convenience method that calls [startSection] before the callback and
  /// [endSection] after.
  ///
  /// Example:
  /// ```dart
  /// await fixture.timedSection('Video loading', () async {
  ///   await waitForVideoInitialization(tester, durationFinder);
  /// });
  /// ```
  Future<void> timedSection(String name, Future<void> Function() callback) async {
    startSection(name);
    try {
      await callback();
    } finally {
      await endSection(name);
    }
  }

  // ==========================================================================
  // Memory Tracking
  // ==========================================================================

  /// Captures a memory snapshot at the current point.
  ///
  /// Only works if memory tracking is enabled (trackMemory=true).
  ///
  /// Example:
  /// ```dart
  /// await fixture.captureMemorySnapshot('After video initialization');
  /// ```
  Future<void> captureMemorySnapshot(String label) async {
    if (_memoryTracker != null) {
      await _memoryTracker!.captureSnapshot(label);
    }
  }

  /// Gets the current memory tracker (if enabled).
  E2EMemoryTracker? get memoryTracker => _memoryTracker;

  // ==========================================================================
  // Video State Logging
  // ==========================================================================

  /// Logs current video state for debugging.
  ///
  /// Convenience wrapper around the global [logVideoState] function.
  ///
  /// Example:
  /// ```dart
  /// fixture.logVideoState(
  ///   positionStr: '02:30',
  ///   durationStr: '10:00',
  ///   state: 'playing',
  /// );
  /// ```
  void logVideoState({String? positionStr, String? durationStr, String? state, Map<String, dynamic>? extra}) {
    // Delegate to global helper
    logVideoState(positionStr: positionStr, durationStr: durationStr, state: state, extra: extra);
  }

  // ==========================================================================
  // Platform & Viewport Info
  // ==========================================================================

  /// Returns true if current viewport uses master-detail layout.
  bool get isMasterDetailLayout => _actualViewportSize != null && _actualViewportSize!.width >= 600;

  /// Returns true if current viewport uses single-pane layout.
  bool get isSinglePaneLayout => !isMasterDetailLayout;

  /// Returns true if platform has autoplay restrictions (web/macOS).
  bool get hasAutoplayRestrictions => E2EPlatform.hasAutoplayRestrictions;

  /// Returns true if platform needs longer timeouts (mobile).
  bool get needsLongerTimeouts => E2EPlatform.needsLongerTimeouts;

  /// Logs current platform and viewport info.
  void logEnvironmentInfo(WidgetTester tester) {
    logPlatformInfo();
    logViewportInfo(tester);
  }
}

/// E2E test fixture with convenience methods for common test patterns.
///
/// This extended fixture adds higher-level helpers that combine multiple
/// low-level operations into common test patterns.
///
/// Usage:
/// ```dart
/// testWidgets('My test', (tester) async {
///   final fixture = E2ETestFixtureWithHelpers();
///   await fixture.setUp(tester);
///
///   // Navigate with automatic timing
///   await fixture.navigateToDemo(tester, cardKey, 'Screen Title');
///
///   fixture.tearDown();
/// });
/// ```
class E2ETestFixtureWithHelpers extends E2ETestFixture {
  /// Creates an extended E2E test fixture with convenience helpers.
  E2ETestFixtureWithHelpers({
    super.setViewport,
    super.customViewportSize,
    super.enableDetailedLogging,
    super.trackMemory,
    super.memoryLeakThresholdMB,
  });

  // ==========================================================================
  // Navigation Helpers with Automatic Timing
  // ==========================================================================

  /// Navigates to a demo screen with automatic section timing.
  ///
  /// Combines [navigateToDemo] with [timedSection] for convenience.
  ///
  /// Example:
  /// ```dart
  /// await fixture.navigateToDemo(tester, TestKeys.playerFeaturesCard, 'Player Features');
  /// ```
  Future<void> navigateToDemo(WidgetTester tester, Key cardKey, String screenTitle, {bool scrollToCard = true}) async {
    await timedSection('Navigate to $screenTitle', () async {
      await nav.navigateToDemo(tester, cardKey, screenTitle, scrollToCard: scrollToCard);
    });
  }

  /// Navigates back to home screen with automatic section timing.
  ///
  /// Example:
  /// ```dart
  /// await fixture.goHome(tester);
  /// ```
  Future<void> goHome(WidgetTester tester, {Key? homeCardKey}) async {
    await timedSection('Navigate to home', () async {
      await nav.goHome(tester, homeCardKey: homeCardKey);
    });
  }

  // ==========================================================================
  // Video Testing Helpers
  // ==========================================================================

  /// Waits for video initialization with automatic timing and logging.
  ///
  /// Example:
  /// ```dart
  /// final duration = await fixture.waitForVideoInitialization(tester, durationFinder);
  /// expect(duration, isNotNull);
  /// ```
  Future<String?> waitForVideoInitialization(WidgetTester tester, Finder durationFinder, {Duration? timeout}) async {
    startSection('Wait for video initialization');

    final duration = await waitForVideoInitialization(tester, durationFinder, timeout: timeout);

    if (duration != null) {
      debugPrint('✓ Video initialized with duration: $duration');
    } else {
      debugPrint('⚠️ Video initialization timeout');
    }

    await endSection('Wait for video initialization');
    return duration;
  }

  /// Waits for playback position to advance with automatic timing.
  ///
  /// Example:
  /// ```dart
  /// final position = await fixture.waitForPlaybackPosition(
  ///   tester,
  ///   positionFinder,
  ///   minSeconds: 2,
  /// );
  /// ```
  Future<String?> waitForPlaybackPosition(
    WidgetTester tester,
    Finder positionFinder, {
    required int minSeconds,
    Duration? timeout,
  }) async {
    startSection('Wait for playback to advance');

    final position = await waitForPlaybackPosition(tester, positionFinder, minSeconds: minSeconds, timeout: timeout);

    await endSection('Wait for playback to advance');
    return position;
  }

  // ==========================================================================
  // Conditional Execution
  // ==========================================================================

  /// Executes callback only if playback tests should run (no autoplay restrictions).
  ///
  /// Example:
  /// ```dart
  /// await fixture.ifPlaybackAllowed(tester, () async {
  ///   await tester.tap(find.byKey(TestKeys.playButton));
  ///   await fixture.waitForPlaybackPosition(tester, positionFinder, minSeconds: 2);
  /// });
  /// ```
  Future<void> ifPlaybackAllowed(WidgetTester tester, Future<void> Function() callback) async {
    final playbackAllowed = !E2EPlatform.hasAutoplayRestrictions;
    await executeIf(
      condition: playbackAllowed,
      callback: callback,
      skipMessage: '⊗ Skipping playback test (autoplay restrictions on ${E2EPlatform.isWeb ? 'web' : 'macOS'})',
    );
  }
}
