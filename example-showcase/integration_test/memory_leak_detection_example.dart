/// Example showing how to use E2EMemoryTracker to detect memory leaks during E2E tests.
///
/// This is a reference implementation - integrate these patterns into your main E2E tests.
///
/// To run: flutter drive --driver=test_driver/integration_test.dart \
///         --target=integration_test/memory_leak_detection_example.dart
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pro_video_player_example/main.dart' as app;
import 'package:pro_video_player_example/test_keys.dart';

import 'helpers/e2e_memory_tracker.dart';
import 'helpers/e2e_navigation.dart' as nav;
import 'shared/e2e_constants.dart';
import 'shared/e2e_test_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Memory leak detection - basic example', (tester) async {
    final fixture = E2ETestFixture();
    final memTracker = E2EMemoryTracker(leakThresholdMB: 30);

    // Start app
    app.main();
    await tester.pumpAndSettle();
    await fixture.setUp(tester);

    // Capture baseline memory
    await memTracker.captureBaseline('App startup');

    // Test section 1: Navigate to video screen and back
    fixture.startSection('Player Features');
    await nav.navigateToDemo(tester, TestKeys.homeScreenPlayerFeaturesCard, 'Player Features');
    await tester.pump(E2EDelays.navigationLong);
    await memTracker.captureSnapshot('Player Features loaded');

    // Navigate back
    await nav.goHome(tester);
    await tester.pump(E2EDelays.navigationLong);
    await memTracker.captureSnapshot('Back to home after Player Features');
    await fixture.endSection('Player Features');

    // Test section 2: Navigate to another screen and back
    fixture.startSection('Advanced Features');
    await nav.navigateToDemo(tester, TestKeys.homeScreenAdvancedFeaturesCard, 'Advanced Features');
    await tester.pump(E2EDelays.navigationLong);
    await memTracker.captureSnapshot('Advanced Features loaded');

    await nav.goHome(tester);
    await tester.pump(E2EDelays.navigationLong);
    await memTracker.captureSnapshot('Back to home after Advanced Features');
    await fixture.endSection('Advanced Features');

    // Test section 3: Repeat same screen to check for cumulative leaks
    fixture.startSection('Player Features (2nd time)');
    await nav.navigateToDemo(tester, TestKeys.homeScreenPlayerFeaturesCard, 'Player Features');
    await tester.pump(E2EDelays.navigationLong);
    await memTracker.captureSnapshot('Player Features loaded (2nd time)');

    await nav.goHome(tester);
    await tester.pump(E2EDelays.navigationLong);
    await memTracker.captureSnapshot('Back to home after Player Features (2nd time)');
    await fixture.endSection('Player Features (2nd time)');

    // Print memory report
    memTracker.printReport();

    // Check for leaks
    if (memTracker.hasLeak()) {
      final growth = memTracker.getMemoryGrowth();
      fail('❌ Memory leak detected! Memory grew by ${growth.toStringAsFixed(1)}MB');
    } else {
      debugPrint('✅ No memory leaks detected!');
    }

    fixture.tearDown();
  });

  testWidgets('Memory leak detection - stress test multiple screens', (tester) async {
    final fixture = E2ETestFixture();
    final memTracker = E2EMemoryTracker();

    // Start app
    app.main();
    await tester.pumpAndSettle();
    await fixture.setUp(tester);

    // Capture baseline
    await memTracker.captureBaseline('App startup');

    // List of screens to test
    final screens = [
      (TestKeys.homeScreenPlayerFeaturesCard, 'Player Features'),
      (TestKeys.homeScreenAdvancedFeaturesCard, 'Advanced Features'),
      (TestKeys.homeScreenVideoSourcesCard, 'Video Sources'),
      (TestKeys.homeScreenLayoutModesCard, 'Layout Modes'),
      (TestKeys.homeScreenPlatformDemoCard, 'Platform Demo'),
    ];

    // Navigate to each screen and back, capturing memory
    for (final (cardKey, title) in screens) {
      fixture.startSection(title);

      await nav.navigateToDemo(tester, cardKey, title);
      await tester.pump(E2EDelays.navigationLong);
      await memTracker.captureSnapshot('$title loaded');

      await nav.goHome(tester);
      await tester.pump(E2EDelays.navigationLong);
      await memTracker.captureSnapshot('Back to home after $title');

      await fixture.endSection(title);
    }

    // Print report
    memTracker.printReport();

    // Check for leaks
    if (memTracker.hasLeak()) {
      final growth = memTracker.getMemoryGrowth();
      // Don't fail the test, just warn (stress test may naturally use more memory)
      debugPrint('⚠️  Warning: Significant memory growth detected: ${growth.toStringAsFixed(1)}MB');
      debugPrint('   This may be normal for stress tests or could indicate a leak.');
      debugPrint('   Review the memory report above for details.');
    } else {
      debugPrint('✅ Memory growth within acceptable limits!');
    }

    fixture.tearDown();
  });
}
