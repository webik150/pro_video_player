import 'package:flutter/material.dart';

import '../test_keys.dart';

/// Home screen displaying available feature demonstrations.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? _selectedIndex;

  final List<_DemoItemData> _allDemos = [
    // Getting Started
    _DemoItemData(
      key: TestKeys.homeScreenPlatformDemoCard,
      title: 'Platform Demo',
      description: 'Platform detection and feature availability',
      icon: Icons.devices_outlined,
      color: Colors.blue,
      route: '/platform-demo',
      category: 'Getting Started',
    ),
    _DemoItemData(
      key: TestKeys.homeScreenLayoutModesCard,
      title: 'Layout Modes',
      description: 'Video only, native, Flutter & custom controls',
      icon: Icons.view_quilt_outlined,
      color: Colors.purple,
      route: '/layout-modes',
      category: 'Getting Started',
    ),
    // Playback Features
    _DemoItemData(
      key: TestKeys.homeScreenPlayerFeaturesCard,
      title: 'Player Features',
      description: 'Fullscreen, PiP, speed, volume & more',
      icon: Icons.play_circle_outline,
      color: Colors.green,
      route: '/player-features',
      category: 'Playback Features',
    ),
    _DemoItemData(
      key: TestKeys.homeScreenVideoSourcesCard,
      title: 'Video Sources',
      description: 'Network, local & asset videos',
      icon: Icons.video_library_outlined,
      color: Colors.orange,
      route: '/video-sources',
      category: 'Playback Features',
    ),
    _DemoItemData(
      key: TestKeys.homeScreenStreamSelectionCard,
      title: 'Stream Selection',
      description: 'Audio & subtitle track selection',
      icon: Icons.library_music_outlined,
      color: Colors.teal,
      route: '/stream-selection',
      category: 'Playback Features',
    ),
    _DemoItemData(
      key: TestKeys.homeScreenPlaylistCard,
      title: 'Playlist',
      description: 'Sequential playback with shuffle & repeat',
      icon: Icons.playlist_play_outlined,
      color: Colors.amber,
      route: '/playlist',
      category: 'Playback Features',
    ),
    _DemoItemData(
      key: TestKeys.homeScreenQualitySelectionCard,
      title: 'Quality Selection',
      description: 'ABR config & manual quality for HLS/DASH',
      icon: Icons.high_quality_outlined,
      color: Colors.lightBlue,
      route: '/quality-selection',
      category: 'Playback Features',
    ),
    _DemoItemData(
      key: TestKeys.homeScreenSubtitleConfigCard,
      title: 'Subtitle Config',
      description: 'Auto-selection & language preferences',
      icon: Icons.subtitles_outlined,
      color: Colors.lime,
      route: '/subtitle-config',
      category: 'Playback Features',
    ),
    // Customization
    _DemoItemData(
      key: TestKeys.homeScreenThemesGesturesCard,
      title: 'Themes & Gestures',
      description: 'Custom controls & themes',
      icon: Icons.palette_outlined,
      color: Colors.pink,
      route: '/theme-demos',
      category: 'Customization',
    ),
    _DemoItemData(
      key: TestKeys.homeScreenCustomThemesCard,
      title: 'Custom Themes',
      description: 'Learn to create your own themes',
      icon: Icons.color_lens_outlined,
      color: Colors.deepPurple,
      route: '/custom-theme-examples',
      category: 'Customization',
    ),
    _DemoItemData(
      key: TestKeys.homeScreenPlayerToolbarConfigCard,
      title: 'Player Toolbar Config',
      description: 'Configure visible actions & overflow menu',
      icon: Icons.tune_outlined,
      color: Colors.indigo,
      route: '/player-toolbar-config',
      category: 'Customization',
    ),
    // Advanced
    _DemoItemData(
      key: TestKeys.homeScreenAdvancedFeaturesCard,
      title: 'Advanced Features',
      description: 'Error handling & multiple players',
      icon: Icons.settings_applications_outlined,
      color: Colors.indigo,
      route: '/advanced-features',
      category: 'Advanced',
    ),
    _DemoItemData(
      key: TestKeys.homeScreenEventsLogCard,
      title: 'Events Log',
      description: 'Monitor player events in real-time',
      icon: Icons.event_note_outlined,
      color: Colors.cyan,
      route: '/events-log',
      category: 'Advanced',
    ),
    _DemoItemData(
      key: TestKeys.homeScreenBackgroundPlaybackCard,
      title: 'Background Playback',
      description: 'Audio continues when app is backgrounded',
      icon: Icons.music_note_outlined,
      color: Colors.deepOrange,
      route: '/background-playback',
      category: 'Advanced',
    ),
    _DemoItemData(
      key: TestKeys.homeScreenScalingModesCard,
      title: 'Scaling Modes',
      description: 'Fit, fill & stretch video scaling',
      icon: Icons.aspect_ratio_outlined,
      color: Colors.brown,
      route: '/scaling-modes',
      category: 'Advanced',
    ),
    _DemoItemData(
      key: TestKeys.homeScreenMediaControlsCard,
      title: 'Media Controls',
      description: 'Control Center & notification metadata',
      icon: Icons.queue_music_outlined,
      color: Colors.blueGrey,
      route: '/media-controls',
      category: 'Advanced',
    ),
    _DemoItemData(
      key: TestKeys.homeScreenPipActionsCard,
      title: 'PiP Actions',
      description: 'Custom buttons in PiP window',
      icon: Icons.picture_in_picture_outlined,
      color: Colors.red,
      route: '/pip-actions',
      category: 'Advanced',
    ),
    _DemoItemData(
      key: TestKeys.homeScreenNetworkResilienceCard,
      title: 'Network Resilience',
      description: 'Buffering, recovery & bandwidth',
      icon: Icons.wifi_outlined,
      color: Colors.lightGreen,
      route: '/network-resilience',
      category: 'Advanced',
    ),
    _DemoItemData(
      key: TestKeys.homeScreenVideoMetadataCard,
      title: 'Video Metadata',
      description: 'Codec, resolution, bitrate & format info',
      icon: Icons.analytics_outlined,
      color: Colors.purple,
      route: '/video-metadata',
      category: 'Advanced',
    ),
    _DemoItemData(
      key: TestKeys.homeScreenCastingCard,
      title: 'Casting',
      description: 'AirPlay, Chromecast & Remote Playback',
      icon: Icons.cast_outlined,
      color: Colors.blue,
      route: '/casting',
      category: 'Advanced',
    ),
    _DemoItemData(
      key: TestKeys.homeScreenChaptersCard,
      title: 'Chapter Navigation',
      description: 'Navigate video chapters & time markers',
      icon: Icons.bookmark_outline,
      color: Colors.teal,
      route: '/chapters',
      category: 'Playback Features',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width >= 800;

    if (isWideScreen) {
      return _buildMasterDetailLayout(context);
    } else {
      return _buildSinglePaneLayout(context);
    }
  }

  Widget _buildSinglePaneLayout(BuildContext context) {
    final scrollView = CustomScrollView(
      slivers: [
        const SliverAppBar.large(title: Text('Pro Video Player'), floating: true),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildHeader(context),
              const SizedBox(height: 24),
              ..._buildAllSections(context),
              const SizedBox(height: 16),
            ]),
          ),
        ),
      ],
    );

    return Scaffold(body: scrollView);
  }

  Widget _buildMasterDetailLayout(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pro Video Player')),
    body: Row(
      children: [
        // Master pane (list) - constrained to prevent layout overflow during disposal
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, minWidth: 360),
          child: SizedBox(
            width: 360,
            child: Column(
              children: [
                Padding(padding: const EdgeInsets.all(16), child: _buildCompactHeader(context)),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: _buildMasterList(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Divider
        const VerticalDivider(width: 1),
        // Detail pane
        Expanded(
          child: _selectedIndex == null
              ? _buildEmptyDetail(context)
              : _buildDetailPane(context, _allDemos[_selectedIndex!]),
        ),
      ],
    ),
  );

  Widget _buildCompactHeader(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Theme.of(context).colorScheme.primaryContainer, Theme.of(context).colorScheme.secondaryContainer],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(Icons.ondemand_video_rounded, size: 32, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explore Features',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Interactive demos',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  List<Widget> _buildMasterList(BuildContext context) {
    final categories = ['Getting Started', 'Playback Features', 'Customization', 'Advanced'];
    final widgets = <Widget>[];

    for (final category in categories) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            category,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
          ),
        ),
      );

      for (var i = 0; i < _allDemos.length; i++) {
        if (_allDemos[i].category == category) {
          widgets.add(_buildMasterItem(context, _allDemos[i], i));
        }
      }
    }

    return widgets;
  }

  Widget _buildMasterItem(BuildContext context, _DemoItemData demo, int index) {
    final isSelected = _selectedIndex == index;

    return Material(
      key: demo.key,
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5) : Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: demo.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(demo.icon, color: demo.color, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      demo.title,
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      demo.description,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyDetail(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.touch_app_outlined,
          size: 64,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 16),
        Text(
          'Select a demo from the list',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose any feature to see more details',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ],
    ),
  );

  Widget _buildDetailPane(BuildContext context, _DemoItemData demo) => SingleChildScrollView(
    padding: const EdgeInsets.all(32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: demo.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(demo.icon, color: demo.color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    demo.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    demo.description,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text('About', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text(_getDetailDescription(demo.title), style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 32),
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, demo.route),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Open Demo', overflow: TextOverflow.ellipsis),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
            ),
          ),
        ),
      ],
    ),
  );

  String _getDetailDescription(String title) {
    switch (title) {
      case 'Platform Demo':
        return 'Explore how the video player adapts to different platforms. See which features are available on iOS, Android, Web, macOS, Windows, and Linux. Learn about platform-specific implementations and feature support matrix.';
      case 'Layout Modes':
        return 'Discover different ways to display video controls. Compare video-only mode, native platform controls, cross-platform Flutter controls, and custom control implementations. Perfect for understanding control customization options.';
      case 'Player Features':
        return 'Test all playback controls and features including fullscreen mode, Picture-in-Picture, background playback, playback speed control, volume adjustment, loop mode, and precise seek controls. A comprehensive showcase of player capabilities.';
      case 'Video Sources':
        return 'Learn how to play videos from different sources. Test network videos (HTTP/HTTPS), local file videos, and bundled asset videos. Understand the different initialization patterns for each source type.';
      case 'Stream Selection':
        return 'Experience multi-audio and subtitle track selection. Switch between different audio languages and subtitle tracks in real-time. Learn how to handle multi-track media content effectively.';
      case 'Themes & Gestures':
        return 'Try gesture-based controls with multiple pre-built themes including dark, light, Christmas, and Halloween themes. Test intuitive gesture controls for an enhanced playback experience.';
      case 'Custom Themes':
        return 'Learn how to create your own custom themes. Explore examples including brand colors theme, minimalist theme, and gaming theme. Get code examples and complete customization guides.';
      case 'Advanced Features':
        return 'Dive into advanced functionality including error handling patterns and running multiple simultaneous video players. Perfect for complex video application requirements.';
      case 'Events Log':
        return 'Monitor all player events in real-time. Track PlaybackStateChanged, PositionChanged, DurationChanged, VolumeChanged, SpeedChanged, and error events. Essential for debugging and understanding player behavior.';
      case 'Quality Selection':
        return 'Configure Adaptive Bitrate (ABR) settings including auto/manual mode and min/max bitrate constraints. Manually select video quality for HLS and DASH adaptive streams. See available quality tracks, switch between resolutions, and monitor bandwidth estimation.';
      case 'Subtitle Config':
        return 'Configure subtitle behavior at initialization time. Enable/disable subtitles, auto-select subtitles by default, set preferred subtitle language, and select tracks programmatically. Complete subtitle customization.';
      case 'Background Playback':
        return 'Continue audio playback when the app is backgrounded. Configure background audio, auto-enter PiP on background, and mix audio with other apps (iOS). Essential for audio-focused video applications.';
      case 'Scaling Modes':
        return 'Control how video fills the player viewport. Compare fit (letterbox), fill (crop), and stretch modes. Understand platform-specific implementations and when to use each mode.';
      case 'Media Controls':
        return 'Set custom metadata for system media controls. Display title, artist, album, and artwork in Control Center (iOS) and notification shade (Android). Essential for professional media applications.';
      case 'PiP Actions':
        return 'Configure custom action buttons in the Picture-in-Picture window. Choose from preset configurations (standard, playlist, minimal) or create custom actions. Platform-specific PiP control customization.';
      case 'Network Resilience':
        return 'Handle network errors gracefully with automatic retry logic. Configure buffering tiers, monitor bandwidth estimation, and implement error recovery strategies. Essential for robust video playback.';
      case 'Playlist':
        return 'Play multiple videos sequentially. Navigate between tracks, enable shuffle and repeat modes, and load playlist files (M3U, M3U8, PLS, XSPF). Complete playlist management capabilities.';
      case 'Video Metadata':
        return 'Extract technical information from videos including video codec (H.264, HEVC), audio codec (AAC, MP3), resolution, frame rate, bitrate, and container format. Access metadata programmatically through the controller API.';
      case 'Casting':
        return 'Stream video to external devices using AirPlay (iOS/macOS), Chromecast (Android), or Remote Playback API (Web). Use the native CastButton widget for device selection, monitor cast state changes, and control casting programmatically. Supports real-time state tracking and seamless device switching.';
      case 'Chapter Navigation':
        return 'Navigate videos using chapter markers. Chapters are time-marked sections with titles, extracted from MP4 chapter atoms, MKV markers, or HLS/DASH metadata. Use the controller API to seek to chapters, navigate next/previous, and track the current chapter during playback.';
      default:
        return 'Explore this feature to learn more about the pro video player capabilities.';
    }
  }

  List<Widget> _buildAllSections(BuildContext context) {
    final categories = {
      'Getting Started': _allDemos.where((d) => d.category == 'Getting Started').toList(),
      'Playback Features': _allDemos.where((d) => d.category == 'Playback Features').toList(),
      'Customization': _allDemos.where((d) => d.category == 'Customization').toList(),
      'Advanced': _allDemos.where((d) => d.category == 'Advanced').toList(),
    };

    final widgets = <Widget>[];
    categories.forEach((title, items) {
      widgets
        ..add(_buildSection(context, title: title, items: items))
        ..add(const SizedBox(height: 24));
    });

    return widgets;
  }

  Widget _buildHeader(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Theme.of(context).colorScheme.primaryContainer, Theme.of(context).colorScheme.secondaryContainer],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.ondemand_video_rounded, size: 48, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(
          'Explore the Features',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Discover all the capabilities of this video player through interactive demos and examples.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    ),
  );

  Widget _buildSection(BuildContext context, {required String title, required List<_DemoItemData> items}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      ),
      const SizedBox(height: 8),
      ...items.map(
        (item) => _DemoItem(
          key: item.key,
          title: item.title,
          description: item.description,
          icon: item.icon,
          color: item.color,
          route: item.route,
        ),
      ),
    ],
  );
}

class _DemoItemData {
  _DemoItemData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.route,
    required this.category,
    this.key,
  });

  final Key? key;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String route;
  final String category;
}

class _DemoItem extends StatelessWidget {
  const _DemoItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.route,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String route;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, route),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 16,
                height: 16,
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
