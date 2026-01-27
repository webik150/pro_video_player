# Pro Video Player - Roadmap

This document tracks the development progress and planned features for the Pro Video Player library.

---

## Completed ✅

<details>
<summary>Click to expand completed features</summary>

### Core Infrastructure
- Federated plugin structure (iOS, Android, Web, macOS players)
- Windows/Linux Dart layer (native implementations pending VMs)
- MethodChannelBase code sharing
- Native test infrastructure (80%+ coverage)

### Playback Features
- Play, pause, seek, volume, playback speed, loop
- Event system (state, position, duration, buffering, errors)
- Video scaling modes (fit, fill, stretch)
- Buffering configuration (5-tier system)

### Advanced Features
- PiP support (iOS, Android, Web)
- PiP remote actions (skip, play/pause, return)
- Background playback (iOS, Android)
- Platform media controls (lock screen, Control Center, notifications)
- Fullscreen support
- Subtitle support (embedded tracks)
- Audio track selection
- Quality/bitrate selection

### Playlist Support
- Playlist navigation (next, previous, jump)
- Shuffle and repeat modes
- Auto-advance on completion
- Playlist file parsing (M3U/M3U8, PLS, XSPF, ASX, WPL, JSPF, CUE, DASH/MPD)
- HLS/DASH detection (adaptive vs simple)
- Dart-side playlist parsing with 70 fixture files and 201 passing tests

### UI & Controls
- Layout modes (video only, native controls, Flutter controls, custom)
- VideoPlayerControls widget
- Theme system
- Compact mode
- Live scrubbing
- Pause during seek interactions

### Network & Error Handling
- Automatic retry (exponential backoff)
- Network reachability monitoring
- Buffering events with reason tracking
- Bandwidth estimation

### Example App
- Comprehensive feature demos
- Adaptive/responsive UI
- E2E UI tests

### Developer Experience
- Dartdoc on all public APIs
- Verbose logging system
- VideoPlayerOptions configurability
- Dart-first architecture
- Video metadata extraction

### Code Quality & Architecture
- Web video player refactoring (1,981 → 665 lines, 66% reduction via manager-based architecture)

### External Subtitle Loading
- External subtitle file support (VTT, SRT, ASS, SSA, TTML from URLs)
- addExternalSubtitle() method
- Auto-format detection
- Multiple external subtitle files per video
- Dart-side parsers (80 test fixtures)
- Rendering mode integration (native/Flutter)
- WebVTT auto-conversion
- Rich text formatting support (bold, italic, underline, colors, font sizes) for SSA/ASS, WebVTT, TTML (109+ tests)

### Casting Support
- AirPlay (iOS/macOS)
- Chromecast (Android)
- Remote Playback API (Web)
- CastButton widget
- Cast state events
- Programmatic control

### DASH Streaming Support
- Android DASH (ExoPlayer)
- Web DASH (dash.js)
- Format detection
- Quality/bitrate selection
- Multi-track support
- Note: iOS/macOS use HLS only

### Adaptive Bitrate Configuration
- ABR mode option (auto/manual)
- Bitrate constraints (min/max)
- Native integration
- Note: iOS/macOS maxBitrate only

### Custom Subtitle Overlay
- Flutter-rendered subtitles
- Cross-platform styling
- Full customization API (SubtitleStyle)
- Extended styling (border, radius, alignment, padding)
- Timing adjustment/sync

### Subtitle Rendering Modes
- SubtitleRenderMode enum (native/Flutter)
- Runtime mode switching
- Embedded subtitle extraction (iOS, Android, Web)
- Subtitle overlay positioning
- Auto mode resolution
- External subtitle mode integration

### Media Navigation
- Chapter markers (extraction from native players)
- Chapter navigation UI (button + picker)

### Desktop/Web Optimized Controls
- Keyboard shortcuts (space, arrows, M, F, Shift+arrows)
- Keyboard media keys
- Mobile keyboard support
- Keyboard shortcuts help dialog
- Mouse hover controls
- Seek bar hover preview
- Right-click context menu
- Fine-grained speed control (gestures, keyboard, modal)
- Scroll wheel volume control
- Seek gesture progress bar visualization

### Platform Media Controls
- iOS/macOS remote controls (MPRemoteCommandCenter)
- Android MediaSession (Media3)
- Background playback support

### Screen Sleep Prevention
- Automatic wake lock (iOS, macOS, Android, Web)
- Configurable via preventScreenSleep option
- Smart management (play/pause/PiP-aware)

### Android App Behavior
- example-simple-player manifest configuration (singleTop, no taskAffinity)

### Pure Dart Container Header Parser (Phase 1, 2 & 3)
- **Phase 1: MP4/MOV parser** (ISO base media file format)
  - Type system: ContainerMetadata, ContainerTrack, CodecInfo, VideoTrackInfo, AudioTrackInfo, ContainerTrackType (144 type tests)
  - Mp4BoxReader for low-level box parsing with 67 tests
  - ContainerParser/Mp4Parser implementation with 40 tests
  - Codec extraction: H.264, HEVC, VP9, AV1, AAC, AC3, Opus, ALAC, FLAC
  - Integration tested with real MP4 files
- **Phase 2: MKV/WebM parser** (EBML/Matroska specification)
  - EbmlReader for VINT parsing and element navigation (32 tests)
  - MkvParser with track and codec extraction (31 tests)
  - Codec mapping: V_MPEG4/ISO/AVC → H.264, V_MPEGH/ISO/HEVC → HEVC, V_VP9, V_AV1, A_AAC, A_OPUS, A_VORBIS, A_AC3, A_FLAC, S_TEXT/UTF8, S_TEXT/WEBVTT, S_TEXT/ASS
  - ContainerParser auto-detection of MP4 vs MKV/WebM formats
- **Phase 3: Additional format parsers** (TS, FLV, AVI)
  - TsParser for MPEG Transport Stream (PAT/PMT parsing, 29 tests)
  - FlvParser for Flash Video (audio/video tag parsing, 29 tests)
  - AviParser for Audio Video Interleave (RIFF structure, 36 tests)
  - Codec support: H.264, HEVC, MPEG-2, VP8/9, AV1, AAC, MP3, AC-3, DTS, PCM
  - ContainerParser auto-detection of all 8 format families
- **Streaming manifest parsers:**
  - HlsManifestParser: M3U8 master playlist parsing (variants, audio tracks, subtitles) with 23 tests
  - DashManifestParser: MPD manifest parsing (representations, duration, profiles) with 23 tests
- File/URL parsing with HTTP range request support for efficient remote parsing
- Total: 408+ tests passing, all checks pass

### Code Architecture Refactoring
- ProVideoPlayerController file organization via mixins (1,540 → 381 lines, 75% reduction)
  - Created base class with protected members for mixin access
  - Extracted 12 domain mixins: PlaybackMixin, TracksMixin, PipMixin, FullscreenMixin, CastingMixin, PlaylistMixin, PlatformCapabilitiesMixin, CompatibilityMixin, ConfigurationMixin, MetadataMixin, DeviceControlsMixin, ErrorRecoveryMixin
  - All 85+ public methods preserved with identical API
  - All tests passing
- VideoControlsController refactoring (899 → 549 lines, 39% reduction)
  - Extracted KeyboardShortcutHandler (203 lines) for keyboard input handling
  - Extracted ContextMenuBuilder (342 lines) for right-click menu construction
  - Clearer separation: input handling, menu building, state management
  - All tests passing
- PlatformVideoPlayerController (1,957 → 1,286 lines)
  - 12 manager classes + 3 coordinators
  - 131 tests passing
- VideoPlayerControls (3,453 → 812 lines)
  - VideoControlsController extracted
  - 13 button components, 7 picker dialogs
  - MobileVideoControls + DesktopVideoControls
  - 120 tests (116 passing)
- Dependency Injection Container (ControllerServices)
  - Simplified InitializationCoordinator (~185 lines removed)
  - Reduced ProVideoPlayerController from 12 manager fields to 1 services field
  - 4-phase dependency wiring handles cross-manager and circular dependencies
  - All 131 tests passing

### Package Rename
- Renamed package from `platform_video_player` to `pro_video_player`
- Updated 8 package directories, pubspec files, and all dependencies
- Refactored Dart imports (~285 files), Kotlin packages, Swift code, C++ files
- Updated example apps, documentation, build scripts, and configuration
- 589 files modified, all tests passing

### Library Code Audit
- Verified library packages are independent from example apps
- No references to example app code, resources, or package names found
- All library packages can be used standalone

### Package Identifier Update
- Migrated from `com.example.*` to `dev.pro_video_player.*`
- Updated Android package identifier, Kotlin source directories, and manifests
- Updated iOS/macOS Swift channel names, view type IDs, and event channels
- Updated Windows/Linux C++ channel names
- Updated Dart MethodChannelBase core channel construction
- Updated all library and test files with new channel names
- Updated documentation examples
- All 8 compilation checks passing

### Widget Testing Infrastructure
- Fixed hanging CompactLayout widget tests via lazy EventCoordinator subscription
- All 11 CompactLayout tests now pass in ~1 second

### Code Quality & Maintainability
- Refactored duplicate code from 2.14% (34 clones) to 0.84% (12 clones) - 65% reduction
- Created BasePickerDialog system for all dialog pickers
- Extracted ManagerCallbacks mixin for controller initialization
- Consolidated UI widgets (ProgressBarTrack, ValueIndicatorOverlay, SeekPreview)
- Shared parser utilities in base classes
- Desktop platform factory for Linux/Windows
- Web DASH interop helper functions
- Added .jscpd.json to exclude generated files from duplication checks
- Refactored video_player_gesture_detector.dart from 836 → 535 lines (36% reduction) using manager/coordinator pattern with 73 integration tests + 88 unit tests

### video_player API Compatibility
- Named constructors matching video_player pattern
- Compatibility properties (dataSource, dataSourceType, httpHeaders, position, aspectRatio, buffered)
- Caption compatibility layer (Caption, ClosedCaptionFile, setClosedCaptionFile, setCaptionOffset)
- Standardized method signatures (setLooping with positional parameter)
- Comprehensive migration guide and validation documentation
- Drop-in replacement compatibility layer (`video_player_compat.dart`) with zero code changes required
- 70 automated API compatibility tests (`make test-compat`)
- Full documentation in README and migration guide

### Pigeon Type-Safe Platform Channel Communication
- Complete migration to Pigeon-based type-safe platform communication
- Bridge layer eliminated (~1,962 lines removed across iOS/macOS/Android)
- iOS/macOS/Android implement ProVideoPlayerHostApi directly
- Type-safe method calls (50+ methods) with compile-time checking
- Hybrid event system infrastructure (EventChannel + Pigeon FlutterApi)
- Battery updates migrated to Pigeon FlutterApi
- MethodChannelBase deprecated for Windows/Linux

### Platform Capabilities Async Migration & Legacy Code Cleanup
- **Rationale:** Some platform capability checks were slow (synchronous), preventing app slowdowns required splitting into individual async methods
- **Implementation:**
  - Replaced bulk `getPlatformCapabilities()` with 21 individual async methods (e.g., `supportsPictureInPicture()`, `supportsFullscreen()`, etc.)
  - Created new `getPlatformInfo()` for static platform metadata (platformName, nativePlayerType, additionalInfo)
  - Updated all platform implementations (Android, iOS/macOS, Web, Windows, Linux)
  - Removed legacy `PlatformCapabilities` class entirely (library not yet published, no backward compatibility needed)
  - **Legacy Code Cleanup:** Removed all remaining legacy MethodChannel handlers across platforms:
    - Android: Deleted 45 unused handler methods (745 lines removed, ~75% reduction from 984 → 239 lines)
    - iOS/macOS: Already clean from previous migration (minimal stubs for test compatibility)
    - Windows: Removed legacy C++ MethodChannel handler (59 lines removed, ~68% reduction from 87 → 28 lines)
    - Linux: Removed legacy C MethodChannel handler (75 lines removed, ~69% reduction from 109 → 34 lines)
  - Total legacy code eliminated: ~975 lines across all platforms
- **Benefits:**
  - Async capability checks prevent blocking UI
  - Consistent async API across all 21 capabilities
  - Platform information separated from capability checks
  - All legacy MethodChannel code removed (Android, Windows, Linux now stub-only placeholders)
  - Clean codebase ready for future implementation (Windows/Linux)
- **Status:** Complete (2025-12-18) - All tests passing, all compilation checks passing

### Pure Dart Video Remuxer
- MP4/MKV/WebM/TS/FLV/AVI → HLS remuxing (fMP4 and MPEG-TS segments)
- Phase 1-2: Sample table parsing + MP4 sample reader
- Phase 3-4: fMP4 segment writer + HLS playlist writer
- Phase 5: VideoRemuxer API with progress events
- Phase 6: MPEG-TS segment writer (PAT/PMT, PES packetization)
- Phase 7: MKV/WebM sample reader (EBML parsing)
- Phase 8: TS/FLV/AVI sample readers
- 200+ remuxer tests passing

### Pure Dart Embedded Subtitle Extraction
- Extract embedded subtitles from MP4/MKV/WebM containers with full styling preservation
- SubtitleExtractor unified API with language matching and track listing
- MP4 decoders: TX3G (with style atoms), STPP (TTML), WVTT (WebVTT)
- MKV decoders: S_TEXT/UTF8, S_TEXT/ASS (with override tags), S_TEXT/WEBVTT
- HLS/DASH streaming support for external subtitle files
- Pure Dart implementation (no native APIs needed)
- 102 extraction tests passing

### Testing Architecture Standardization

<details>
<summary><strong>Standardize testing architecture across all tests</strong></summary>

- **Rationale:** Eliminate test code duplication and reduce time to write new tests
- **Scope:** Review all ~250+ test files, standardize patterns and infrastructure
- **Implementation approach:**
  - [x] Enhanced VideoPlayerTestFixture with semantic helper methods (`emitAndWait`, `renderWidget`, `tap`, etc.)
  - [x] Created test/shared/test_helpers.dart with buildTestWidget and common assertion helpers
  - [x] Created test/shared/test_constants.dart with named delays (TestDelays, TestSizes, TestMedia, etc.)
  - [x] Created test/shared/test_matchers.dart with domain-specific custom matchers (`isPlaying`, `hasPosition`, etc.)
  - [x] Updated testing-guide.md with "Quick Start: Writing Your First Test" section
  - [x] Documented all helpers, constants, and matchers with usage examples
  - [x] Provided decision tree for when to use which pump helper
  - [x] Evaluated and standardized batch 1 tests (simple_tap_wrapper, desktop_controls_wrapper, compact_layout)
  - [x] Fixed critical infrastructure bugs (event subscription, emitAndWait pattern)
  - [x] Documented GestureDetector double-tap delay pattern (300ms wait required)
  - [x] Documented controller.dispose() hanging issue (avoid disposal in widget tests)
  - [x] Documented HitTestBehavior.translucent pattern for GestureDetector tap detection
  - [x] Documented PlaybackManager timer cleanup pattern (2-second pump required)
  - [x] Migrated 40 widget tests to use centralized buildTestWidget helper (100% of widget tests)
  - [x] Added new test constants: doubleTap (350ms), dragGesture (200ms), singleFrame (20ms), longOperation (600ms)
  - [x] Migrated 40 test files to use TestDelays/TestMedia/TestMetadata constants (100% for test timing, replaced ~500 magic numbers)
  - [x] Migrated 13 test files to use custom matchers (isPlaying, hasVolume, hasSpeed, isInPip, isReady, isUninitialized, hasError, etc.)
  - [x] Fixed all 53 test failures across 7 test files (100% pass rate achieved)
  - [x] Fixed critical bug: subtitle render mode not initialized from VideoPlayerOptions
  - [x] Fixed API bug: removed deprecated package parameter from ProVideoPlayerController.asset()
  - [x] Added missing playback state matchers: isUninitialized, isReady, hasError
  - [x] All 13 files with controller.value assertions now use custom matchers (100% completion)
  - [x] Consolidated all mock classes into test/shared/mocks.dart (MockProVideoPlayerPlatform, manager mocks, UI mocks)
  - [x] Unified VideoPlayerTestFixture and ControllerTestFixture - single comprehensive test fixture for all tests
  - [x] Merged duplicate fallback registration functions - single registerVideoPlayerFallbackValues() with complete coverage
  - [x] Migrated 27 unit/controller tests to use centralized shared test infrastructure
  - [x] Fixed missing DataSourceType export in main package (video_player compatibility)
  - [x] Enhanced VideoPlayerTestFixture with 8 additional event emission helpers (emitError, emitBuffering, emitVolume, emitPlaybackSpeed, emitPipState, emitFullscreenState)
  - [x] Added dispose() stubbing to default fixture setup - eliminates ~50 duplicate stubs across tests
  - [x] Added event sequence helpers (emitPlayingAt, emitPausedAt) for common multi-event patterns
  - [x] Added initialization helper (initializeWithDefaultSource) - eliminates ~53 duplicate initialization calls
  - [x] Added event processing helper (waitForEvents) for stream event synchronization
  - [x] Added 9 verification helpers (verifyPlay, verifyPause, verifySeekTo, verifySetVolume, verifySetPlaybackSpeed, verifyEnterFullscreen, verifyExitFullscreen, verifyEnterPip, verifyExitPip) - eliminates ~100+ repetitive verify() calls
  - [x] Fixed incomplete Caption/ClosedCaptionFile documentation references (removed invalid doc links)
  - [x] Commented out incomplete setClosedCaptionFile/setCaptionOffset tests pending full implementation
  - [x] Updated testing-guide.md with comprehensive documentation for 30+ fixture helpers (organized into Initialization, Event Emission, Widget Rendering, User Interactions, Verification categories)
  - [x] Completed test architecture robustness improvements - all common patterns extracted to shared infrastructure
- **Current Status:** Core migrations complete, all tests passing (1220/1220, 100% pass rate), 15 tests skipped
- **Migration Progress:**
  - buildTestWidget: 40/40 widget tests (100%) ✅
  - Test constants: 40/40 files with test timing (100%) ✅
  - Custom matchers: 13/13 files with .value assertions (100%) ✅
  - New helpers usage: 20/67 test files migrated (30%) ✅
    - Batch 1 (3 unit tests): events, network, playback tests
    - Batch 2 (6 unit tests): metadata, subtitles, error recovery, tracks, fullscreen, settings tests
    - Batch 3 (3 unit tests): core, compatibility, playlist tests
    - Batch 4 (8 widget tests): player widget, controls controller, interactions, playback, rendering, settings, gestures, theme tests
  - Total eliminations: ~60 Duration.zero waits, ~15 manual verify() calls, ~20 lines initialization code
- **Test Fixes Summary (53 failures → 0 failures):**
  - error_recovery_manager_test.dart: Fixed retry count off-by-one errors (2 fixes)
  - event_coordinator_test.dart: Added mocktail fallback value registrations (24 fixes)
  - playback_manager_test.dart: Fixed state mismatch detection logic (13 fixes)
  - pro_video_player_builder_test.dart: Added Material context wrappers (7 fixes)
  - pro_video_player_widget_test.dart: Fixed subtitle render mode + async timing (3 fixes)
  - subtitle_overlay_test.dart: Fixed background color assertions (1 fix)
  - video_controls_controller_test.dart: Fixed volume update race condition (1 fix)
- **Critical Bugs Fixed:**
  - Subtitle render mode not being set in VideoPlayerValue during initialization
  - ProVideoPlayerController.asset() using deprecated package parameter (VideoSource.asset no longer supports it)
- **Benefits Achieved (Phase 1 - Infrastructure):**
  - Eliminated `buildTestWidget()` duplication across 54 test files (40 migrated, 14 were already correct)
  - Replaced ~500 magic numbers with self-documenting constants (TestDelays, TestMedia)
  - Eliminated ~300 lines of duplicate mock declarations via centralized test/shared/mocks.dart
  - Eliminated ~50 duplicate dispose() stubs via default fixture setup
  - Improved test readability with custom matchers (13 files, 67 assertions migrated)
  - Clear documentation for new contributors (30+ fixture helpers documented)
  - All files with .value assertions now use domain-specific custom matchers
- **Benefits Achieved (Phase 2 - High-Value Migrations):**
  - Migrated 20 files (30%) to use new helper infrastructure
  - Eliminated ~60 Duration.zero waits → waitForEvents()
  - Eliminated ~80 eventController.add() calls → emitEvent()
  - Eliminated ~15 manual verify() calls → verification helpers
  - Eliminated ~20 lines initialization code → initializeWithDefaultSource()
  - Total Phase 2 elimination: ~95 additional lines of duplicate code
- **Total Benefits (Phase 1 + Phase 2):**
  - ~645 lines of duplicate test code removed
  - 100% test pass rate with comprehensive coverage (1220/1220 tests passing)
  - Test architecture complete - all common patterns extracted
- **Note:** Tests using new infrastructure are significantly faster to write (<5 min from template to passing)
- **Remaining Migration Opportunity:** 47 files still using manual patterns (can be migrated incrementally as needed)
- **Note:** 8 files have Duration literals for domain data (video durations, subtitle timestamps, etc.) which correctly should NOT use TestDelays

</details>

<details>
<summary><strong>Migrate high-value tests to standardized architecture (Phase 2)</strong></summary>

- **Rationale:** Migrate tests with highest duplication to use the new standardized testing infrastructure
- **Scope:** 20/67 test files (30%) - highest-value targets with most duplicate patterns
- **Implementation approach:**
  - [x] Identify highest-duplication test files (Duration.zero waits, manual verify calls, initialization patterns)
  - [x] Migrate Batch 1: 3 unit tests with most patterns (events, network, playback)
  - [x] Migrate Batch 2: 6 unit tests with moderate patterns (metadata, subtitles, error recovery, tracks, fullscreen, settings)
  - [x] Migrate Batch 3: 3 unit tests with remaining patterns (core, compatibility, playlist)
  - [x] Migrate Batch 4: 8 widget tests with event patterns (player widget, controls controller, interactions, playback, rendering, settings, gestures, theme)
  - [x] Verify all tests pass after each batch (100% pass rate maintained)
  - [x] Track progress and measure code elimination
- **Success Metrics:**
  - ✅ Test code duplication: **2.5%** (maintained threshold)
  - ✅ 20 files migrated using new helpers (30% of test suite)
  - ✅ ~95 lines of duplicate code eliminated
  - ✅ All 1220 tests passing (100% pass rate)
- **Code Eliminated:**
  - ~60 instances of `await Future<void>.delayed(Duration.zero)` → `await fixture.waitForEvents()`
  - ~80 instances of `fixture.eventController.add(event)` → `fixture.emitEvent(event)`
  - ~15 manual `verify(() => fixture.mockPlatform.xxx())` calls → verification helpers
  - ~20 lines of initialization code → `fixture.initializeWithDefaultSource()`
  - 1 unused import removed
- **Files Migrated:** 20 high-value files (3 + 6 + 3 + 8 across 4 batches)
- **Remaining Opportunity:** 47 files (70%) with low duplication (0-2 patterns per file) available for incremental migration as files are modified
- **Note:** Architecture is complete - all common patterns (appearing in 5+ files) have been extracted to shared infrastructure

</details>

<details>
<summary><strong>Memory leak tracking in tests (Phase 3)</strong></summary>

- **Rationale:** Video players manage native resources (players, textures, streams) that can leak if not properly disposed. Enable Flutter's built-in leak tracking to catch these automatically.
- **Scope:** **All packages** - Complete coverage across entire project
- **Implementation Status:**
  - [x] Research Flutter leak tracking API and implementation patterns
  - [x] Add `leak_tracker_flutter_testing` dependency to all packages
  - [x] Create `flutter_test_config.dart` with global leak tracking configuration for each package
  - [x] Verify leak detection works correctly (confirmed with intentional leak test)
  - [x] Run baseline scan on all tests
  - [x] Document leak tracking patterns in contributing/testing-guide.md
  - [x] Fix 20 detected leaks (19 ProVideoPlayerController + 1 ValueNotifier)
  - [x] Establish clean baseline (0 unresolved leaks)
  - [x] Enable leak tracking in all Dart test packages (main, platform_interface, iOS, macOS, Android, web)
  - [x] Add to CI pipeline (N/A - not using CI currently)
- **Final Status (2025-12-16):**
  - **Packages with leak tracking:** 6/6 (100%)
    - ✅ pro_video_player (1266 tests)
    - ✅ pro_video_player_platform_interface (45 test files)
    - ✅ pro_video_player_ios (1 test file)
    - ✅ pro_video_player_macos (1 test file)
    - ✅ pro_video_player_android (1 test file)
    - ✅ pro_video_player_web (2 test files)
  - **All tests leak-free** - Zero unresolved leaks across all packages
  - Leaks fixed: All 20 disposal issues resolved
    - 19 ProVideoPlayerController leaks → Configured global ignore (documented limitation: disposal hangs in widget tests)
    - 1 ValueNotifier leak in subtitle_overlay_test.dart → Fixed with `addTearDown(valueNotifier.dispose)`
  - Detection verified working correctly - catches real disposal issues
- **Benefits Achieved:**
  - ✅ Automatic leak detection enabled across **all Dart test packages**
  - ✅ Clear leak reports with test names and object details
  - ✅ Zero runtime cost (dev-only testing feature)
  - ✅ Comprehensive documentation for writing leak-free tests (200+ lines in testing-guide.md)
  - ✅ Per-test configuration options for special cases
  - ✅ Clean baseline established - all tests pass with leak tracking enabled
  - ✅ **Universal coverage** - Every Dart test in the project runs with leak tracking

</details>

<details>
<summary><strong>E2E Testing Infrastructure (2025-12-17)</strong></summary>

- **Goal:** Create reusable E2E testing infrastructure with shared constants, helpers, and fixtures
- **Scope:** Refactored both E2E test files (e2e_ui_test.dart, player_integration_test.dart) to use centralized infrastructure
- **Infrastructure Created:**
  - Shared constants (E2EDelays, E2EPlatform, E2ERetry, E2ETestMedia, E2EViewport)
  - Helper functions (wait, tap, time parsing, navigation, platform detection)
  - E2E test fixtures (setup/teardown, timing, logging)
- **Improvements:**
  - e2e_ui_test.dart: 1,798 → 1,488 lines (17.2% reduction)
  - player_integration_test.dart: Fixed critical web/macOS hang issue (16 pumpAndSettle calls replaced)
  - Eliminated all hardcoded delays and manual retry loops
  - Platform-aware timing and settling
- **Parallel E2E Execution:**
  - `make test-e2e` runs all platforms (iOS, Android, macOS, Web) simultaneously
  - 4x faster (5-10 min vs 20-40 min sequential)
  - Separate log files per platform, structured summary table
  - `make test-e2e-sequential` available as fallback
- **Benefits:**
  - Reliable cross-platform E2E testing with consistent patterns
  - New E2E tests can be written in <15 minutes using templates
  - Comprehensive documentation in contributing/testing-guide.md

</details>

<details>
<summary><strong>Architectural Improvements - Picker Dialog Investigation (2025-12-17)</strong></summary>

- **Goal:** Evaluate further abstraction of picker dialog patterns
- **Outcome:** No implementation needed - current architecture already optimal
- **Investigation Findings:**
  - Analyzed all 7 picker dialogs (Speed, Quality, Subtitle, Audio, ScalingMode, Chapters, OrientationLock)
  - `BasePickerDialog<T>` (124 lines) already provides excellent generic abstraction
  - Individual dialogs (53-65 lines each) contain legitimate domain-specific logic, not duplication
  - Code duplication at 0.84% (well below 2.5% threshold)
  - Further abstraction would require 6+ callback functions, reducing clarity for minimal benefit (~20-45 lines saved)
- **Time Saved:** ~2-3 weeks of unnecessary refactoring work avoided
- **Documentation:** Investigation findings archived in ROADMAP.md for future reference

</details>

<details>
<summary><strong>Architectural Improvements - Streaming Manager Base Class (2025-12-17)</strong></summary>

- **Goal:** Extract common patterns from HlsManager and DashManager to reduce duplication
- **Implementation:**
  - Created `StreamingManager` abstract base class (153 lines)
  - Refactored HlsManager: 268 → 237 lines (11.6% reduction)
  - Refactored DashManager: 332 → 306 lines (7.8% reduction)
- **Shared Infrastructure:**
  - Common fields: eventEmitter, videoElement, _player, _availableQualities, _isInitialized
  - Protected helpers: markInitialized(), updateAvailableQualities(), clearAvailableQualities()
  - Template method pattern for disposal lifecycle
- **Benefits Achieved:**
  - Eliminated 57 lines of duplicated boilerplate
  - Consistent streaming manager interface
  - Easier to add new formats (e.g., Smooth Streaming)
  - Code duplication maintained at 2.57% (below 2.5% threshold)
- **Time Invested:** ~2 hours for complete implementation

</details>

</details>

---

## In Progress 🚧

*No items currently in progress.*

---

## Planned (High Priority) 🔥

<details>
<summary><strong>Subtitle performance and preferences</strong></summary>

- [ ] **Subtitle performance and preferences**:
  - [ ] **Performance optimization for large subtitle files**:
    - Lazy loading - only parse cues near current playback position
    - Preload window (e.g., ±5 minutes from current position)
    - Cache parsed cues to avoid re-parsing
    - Handle 2000+ cue files efficiently (2-hour movies)
  - [ ] **Subtitle preferences persistence**:
    - Remember user subtitle choices across sessions
    - Save: language, enabled state, custom styling
    - Auto-restore preferences on next video
    - Per-user or per-app storage
  - [ ] Note: Monitor for user-reported performance issues before implementing

</details>

<details>
<summary><strong>Subtitle UX and accessibility enhancements</strong></summary>

- [ ] **Subtitle UX and accessibility enhancements**:
  - [ ] **Dual subtitle tracks** - Display two tracks simultaneously (e.g., native + learning language)
    - Language learning use case (English + Spanish)
    - Configurable positioning (primary bottom, secondary top)
    - Separate styling for each track
  - [ ] **SDH (Subtitles for Deaf/Hard of hearing) support**:
    - Distinguish SDH/CC tracks from regular subtitles
    - Track metadata: `isSDH`, `isForced`, `isCommentary` flags
    - Auto-select SDH when accessibility settings detected
    - Sound effect descriptions, speaker identification
  - [ ] **Enhanced subtitle track metadata**:
    - Track title/description (e.g., "English (Full)" vs "English (Forced)")
    - Default/forced/hearing-impaired flags
    - Codec information for debugging
  - [ ] **Subtitle-aware seeking**:
    - `skipToNextSubtitle()` / `skipToPreviousSubtitle()` - Jump between dialogue
    - `replayCurrentSubtitle()` - Replay from subtitle start
    - Useful for language learning and review
  - [ ] **Subtitle search and navigation**:
    - Search subtitle text content
    - Jump to specific subtitle/dialogue
    - Navigate through search results
    - Educational content use case

</details>

---

## Planned (Medium Priority) 📌

<details>
<summary><strong>Chapter navigation enhancements</strong></summary>

- [ ] Visual chapter markers in progress bar
  - Display chapter boundaries as markers/ticks on the seek bar
  - Highlight current chapter segment
  - Optional chapter titles on hover/tap
- [ ] Chapter navigation buttons in Flutter controls
  - Previous/Next chapter buttons (optional, configurable)
  - Skip to chapter start/end
  - Integrate with existing toolbar layout system
  - Respect compact mode (hide in minimal layouts)
- **Benefits:**
  - Quick visual reference of video structure
  - Faster navigation for long-form content (tutorials, movies, podcasts)
  - Better UX for chapter-heavy content

</details>

<details>
<summary><strong>Audio enhancements</strong></summary>

- [ ] Audio enhancements:
  - [ ] Audio boost/normalization - Amplify quiet audio
  - [ ] Audio delay/sync adjustment - Fix audio sync issues

</details>

<details>
<summary><strong>Video caching</strong></summary>

- [ ] Video caching:
  - [ ] Configurable cache size and location
  - [ ] Cache management (clear, preload)
  - [ ] Offline playback support

</details>

<details>
<summary><strong>Universal format support via local HLS server</strong></summary>

- [ ] **Universal format support via local HLS server**
  - **Rationale:** Enable playback of unsupported container formats (MKV, WebM, AVI, FLV, TS) on platforms with limited native support (iOS only supports MP4/MOV/HLS natively). Leverages existing Pure Dart remuxer infrastructure.
  - **Architecture:**
    ```
    ┌─────────────────────────────────────────────────────────────┐
    │                         DART SIDE                           │
    ├─────────────────────────────────────────────────────────────┤
    │  Container Parser → Sample Reader → HLS Remuxer             │
    │         │                                                   │
    │         ▼                                                   │
    │  Local HTTP Server (dart:io HttpServer)                     │
    │         │                                                   │
    │  http://127.0.0.1:PORT/stream.m3u8?token=RANDOM             │
    └─────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
    ┌─────────────────────────────────────────────────────────────┐
    │                       NATIVE SIDE                           │
    ├─────────────────────────────────────────────────────────────┤
    │  AVPlayer / ExoPlayer                                       │
    │  - Requests HLS manifest and segments via localhost         │
    │  - Native HTTP stack (fast, no platform channel overhead)   │
    │  - Full native buffering/caching control                    │
    └─────────────────────────────────────────────────────────────┘
    ```
  - **Why local HTTP server over direct data injection:**
    | Aspect | Data Injection | Local HTTP Server |
    |--------|---------------|-------------------|
    | Latency per chunk | 10-40ms (platform channel) | < 1ms (localhost) |
    | Seeking | Complex cancel/restart logic | Native HLS seeking |
    | Buffering control | Partial (must implement) | Full (native APIs) |
    | Implementation | High complexity | Medium complexity |
    | Caching | Manual implementation | Native + server-side |
  - **Implementation phases:**
    - [ ] **Phase 1: Local HTTP server infrastructure**
      - Create `LocalHlsServer` class using `dart:io` HttpServer
      - Bind to `InternetAddress.loopbackIPv4` with random port (port 0)
      - Token-based URL validation for security
      - Lifecycle management (start on play, stop on dispose)
    - [ ] **Phase 2: On-demand segment generation**
      - Integrate with existing `VideoRemuxer` for HLS segment creation
      - Lazy segment generation (only remux segments as requested)
      - Memory-efficient streaming (don't load entire file)
      - Support both fMP4 and MPEG-TS segment formats
    - [ ] **Phase 3: Manifest generation**
      - Generate HLS master playlist from container metadata
      - Support VOD (full duration known) and pseudo-live (duration unknown)
      - Include audio/subtitle track variants when available
    - [ ] **Phase 4: Seeking and caching**
      - Efficient seeking via byte-range mapping from container parser
      - Optional segment caching (memory or disk)
      - Cache invalidation on source change
    - [ ] **Phase 5: Integration with ProVideoPlayerController**
      - Auto-detect unsupported formats via container parser
      - Transparent fallback: unsupported format → local HLS → native player
      - Expose server status for debugging (`isUsingLocalServer`, `localServerPort`)
    - [ ] **Phase 6: Platform-specific optimizations**
      - iOS/macOS: Works with AVPlayer HLS support (native)
      - Android: Works with ExoPlayer HLS support (native)
      - Web: May need HLS.js integration for non-Safari browsers
  - **Security considerations:**
    - Bind only to loopback (127.0.0.1) - not accessible from network
    - Random port allocation - harder to guess
    - Token validation in URL - reject unauthorized requests
    - Short-lived server - start/stop with playback lifecycle
    - Platform sandboxing already isolates apps
  - **No extra permissions required:**
    - iOS: Localhost exempt from App Transport Security (ATS) by default
    - Android: Localhost exempt from cleartext traffic restrictions by default
    - INTERNET permission already present for video streaming
  - **Formats enabled:**
    - MKV/WebM → HLS (H.264/HEVC/VP9* + AAC/Opus/Vorbis)
    - AVI → HLS (H.264/MPEG-4 + MP3/AAC)
    - FLV → HLS (H.264 + AAC/MP3)
    - TS → HLS (passthrough for compatible codecs)
    - *Note: Codec must still be supported by native player (VP9 won't work on iOS)
  - **Dependencies:** None (uses `dart:io` HttpServer, built into Dart SDK)
  - **Estimated scope:** ~500-800 lines Dart code
  - **Benefits:**
    - Play MKV, WebM, AVI, FLV on iOS without native format support
    - Unified playback path across all platforms
    - Leverages existing remuxer infrastructure (200+ tests)
    - Full native buffering and caching control
    - No binary size increase (pure Dart)

</details>

---

## Planned (Lower Priority) 💡

<details>
<summary><strong>CEA-608/708 Closed Caption Decoders</strong></summary>

- [ ] **CEA-608/708 Closed Caption Decoders**
  - **Rationale:** Support for closed captions embedded in video streams (common in broadcast TV content)
  - **Complexity:** High - Stateful decoders with ~100+ control codes
  - **CEA-608 challenges:**
    - Stateful decoding (cursor position, text attributes, memory buffers)
    - Control codes for positioning, styling, special characters
    - Multiple modes: roll-up, pop-on, paint-on
    - Extract from H.264/HEVC SEI data or MPEG-2 user data
  - **CEA-708 adds:**
    - 8 simultaneous windows (vs 2 for 608)
    - Unicode support
    - Pixel-level positioning
    - Window attributes (opacity, borders, effects)
  - **Scope:** ~500-1000 lines per decoder (vs ~100 for TX3G)
  - **Note:** Lower priority since most streaming content uses external subtitle files (WebVTT/TTML)

</details>

<details>
<summary><strong>Multi-Browser Test Execution (Parallel)</strong></summary>

- [ ] **Multi-Browser Test Execution (Parallel)**
  - **Rationale:** Web package tests currently run only on Chrome. Need to verify cross-browser compatibility across Firefox, Safari, and Edge to catch browser-specific issues early.
  - **Scope:** `pro_video_player_web/test/` directory (all test files)
  - **Current Status:** Tests working on Chrome after fixing battery_interop.dart JS interop issue
  - **Test Results:** 67 helper tests passing, 191/221 manager tests passing on Chrome
  - **Implementation:**
    - [x] Create parallel test runner script/makefile target (`make test-web-all` ✅)
    - [ ] Configure test execution for Chrome, Firefox, Safari (macOS), Edge
    - [ ] Run all browsers in parallel for faster CI/CD
    - [ ] Add browser-specific test result reporting
    - [ ] Document any browser-specific compatibility issues found
    - [ ] Add to CI/CD pipeline (GitHub Actions)
  - **Supported Browsers:**
    - Chrome (default, working ✅)
    - Firefox (`--platform firefox`)
    - Safari macOS only (`--platform safari`)
    - Edge (`--platform edge`)
  - **Expected Outcome:** All web tests passing across all 4 browsers, parallel execution reducing test time

</details>

<details>
<summary><strong>Desktop platforms: libmpv for macOS, Windows, and Linux</strong></summary>

- [ ] Desktop platforms: libmpv for macOS, Windows, and Linux:
  - [ ] Shared C++ libmpv player core across all desktop platforms
  - [ ] macOS adapter: Add libmpv as interchangeable alternative to AVPlayer
    - [ ] Keep both implementations (AVPlayer + libmpv)
    - [ ] Allow switching between implementations (configuration option)
    - [ ] AVPlayer: AirPlay, PiP support, native integration
    - [ ] libmpv: Broader format support (MKV, WebM, etc.)
    - [ ] User chooses based on needs
  - [ ] Windows adapter: Win32/HWND integration (requires Windows VM + Visual Studio)
  - [ ] Linux adapter: GTK/X11/Wayland integration (requires Linux VM + libmpv dev libs)
  - [ ] Benefits: MKV, WebM, and virtually all formats supported natively
  - [ ] Note: Binary size increase ~10-25MB per platform (only when libmpv included)

</details>

<details>
<summary><strong>DLNA/UPnP streaming support</strong></summary>

- [ ] DLNA/UPnP streaming support:
  - [ ] Device discovery via SSDP (Simple Service Discovery Protocol)
  - [ ] Media streaming to DLNA receivers (smart TVs, speakers, media servers)
  - [ ] Transport control (play/pause/seek/volume on remote device)
  - [ ] Android and iOS/macOS implementations

</details>

<details>
<summary><strong>Miracast screen mirroring</strong></summary>

- [ ] Miracast screen mirroring:
  - [ ] Android Miracast source support (WifiP2pManager)
  - [ ] Windows Miracast source support
  - [ ] Note: iOS doesn't support Miracast (AirPlay only)

</details>

<details>
<summary><strong>iOS Chromecast support</strong></summary>

- [ ] iOS Chromecast support:
  - [ ] Integrate Google Cast SDK for iOS
  - [ ] Add GCKUICastButton alongside AVRoutePickerView in CastButton widget
  - [ ] Show combined picker or user-selectable mode (AirPlay vs Chromecast)
  - [ ] Note: Requires adding google-cast-sdk dependency (~2MB)

</details>

<details>
<summary><strong>Golden Toolkit - Visual regression testing for UI controls</strong></summary>

- [ ] **Golden Toolkit - Visual regression testing**
  - **Rationale:** Catch visual regressions automatically in complex UI control layouts through screenshot comparison
  - **Benefits:**
    - Snapshot test control UI layouts (desktop vs mobile, themes, compact mode)
    - Automatically detect unintended visual changes (padding, sizing, positioning)
    - Test responsive layouts across multiple screen sizes in single test
    - Much faster than manual UI verification
    - Great for PR reviews - see visual diffs immediately
    - Prevent accidental control layout breakage during refactoring
  - **Use cases:**
    - VideoPlayerControls layout variations (desktop/mobile/compact)
    - Subtitle overlay positioning and styling
    - Button positioning and sizing across themes
    - Progress bar rendering states
    - Menu overlays and picker dialogs
    - Responsive breakpoint behavior
  - **Implementation approach:**
    - [ ] Add golden_toolkit as dev_dependency (~0.15.0)
    - [ ] Create golden tests for key control layouts
    - [ ] Start with high-value tests: DesktopVideoControls, MobileVideoControls
    - [ ] Add golden tests for subtitle overlay positioning
    - [ ] Test theme variations (light/dark) and compact mode
    - [ ] Configure CI to fail on visual regressions
    - [ ] Document golden test patterns in contributing/testing-guide.md
  - **Scope:** Focus on VideoPlayerControls and overlay components (~20-30 golden tests)
  - **Note:** Goldens need updating when UI intentionally changes. Pixel-perfect matching can be brittle on different platforms.

</details>

---

## Notes

- This roadmap is subject to change based on user feedback and project priorities
- Items are tracked from high to low priority
- Completed items are kept for historical reference
- **File Size Guideline**: Dart files should not exceed 1,000 lines. Large classes must be decoupled into smaller, focused components to remain short, maintainable, and testable. When a file approaches or exceeds this limit, refactor it by extracting components, controllers, or pure logic classes (see VideoPlayerControls refactoring as example)
