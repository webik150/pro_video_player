import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pro_video_player/pro_video_player.dart';

import '../constants/video_constants.dart';
import '../test_keys.dart';
import '../widgets/responsive_video_layout.dart';

/// Demonstrates subtitle configuration options including external subtitles.
///
/// Shows how to:
/// - Enable/disable subtitles via options
/// - Auto-select subtitles by default
/// - Set preferred subtitle language
/// - Select subtitle tracks programmatically
/// - Load external subtitles from URLs (VTT, SRT, ASS, TTML)
/// - Switch between native and Flutter subtitle rendering modes
/// - Runtime subtitle mode switching without re-initialization
/// - View subtitles with Native vs Flutter controls
class SubtitleConfigScreen extends StatefulWidget {
  const SubtitleConfigScreen({super.key});

  @override
  State<SubtitleConfigScreen> createState() => _SubtitleConfigScreenState();
}

class _SubtitleConfigScreenState extends State<SubtitleConfigScreen> {
  ProVideoPlayerController? _controller;
  bool _isInitialized = false;
  String? _error;

  // Configuration options
  bool _subtitlesEnabled = true;
  bool _showByDefault = true;
  String? _preferredLanguage = 'en';
  SubtitleRenderMode _subtitleRenderMode = SubtitleRenderMode.flutter;

  // Controls mode (Native vs Flutter)
  bool _useNativeControls = false;

  // Subtitle styling (only applies to Flutter controls mode)
  SubtitleStyle _subtitleStyle = const SubtitleStyle();
  Color _textColor = Colors.white;
  double _fontSizePercent = 1; // 100% = default size
  Color _backgroundColor = Colors.transparent;
  bool _enableStroke = false;
  Color _strokeColor = Colors.black;
  double _strokeWidth = 2;
  SubtitlePosition _position = SubtitlePosition.bottom;
  SubtitleTextAlignment _textAlignment = SubtitleTextAlignment.center;
  double _borderRadius = 4;
  double _marginFromEdge = 48;

  // External subtitle state
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _labelController = TextEditingController();
  SubtitleFormat? _selectedFormat;
  String? _selectedLanguage;
  bool _isLoadingExternal = false;
  String? _externalError;
  final List<ExternalSubtitleTrack> _loadedExternalTracks = [];

  // Sample external subtitles for quick testing - demonstrates different formats
  static const _sampleSubtitles = [
    // Rich text formatted samples (asset files) - demonstrates styling features
    (label: 'Rich Text Demo (ASS)', url: SubtitleUrls.richTextAss, language: 'en', format: SubtitleFormat.ass),
    (label: 'Rich Text Demo (VTT)', url: SubtitleUrls.richTextVtt, language: 'en', format: SubtitleFormat.vtt),
    (label: 'Rich Text Demo (TTML)', url: SubtitleUrls.richTextTtml, language: 'en', format: SubtitleFormat.ttml),
    // Sintel subtitles from Bitmovin (VTT format)
    (label: 'Sintel English (VTT)', url: SubtitleUrls.sintelEnglishVtt, language: 'en', format: SubtitleFormat.vtt),
    (label: 'Sintel Spanish (VTT)', url: SubtitleUrls.sintelSpanishVtt, language: 'es', format: SubtitleFormat.vtt),
    (label: 'Sintel German (VTT)', url: SubtitleUrls.sintelGermanVtt, language: 'de', format: SubtitleFormat.vtt),
    (label: 'Sintel French (VTT)', url: SubtitleUrls.sintelFrenchVtt, language: 'fr', format: SubtitleFormat.vtt),
    // Additional format samples for testing (may not sync with current video)
    (label: 'Sample (SRT)', url: SubtitleUrls.sampleSrt, language: 'en', format: SubtitleFormat.srt),
    (label: 'Sample (ASS)', url: SubtitleUrls.sampleAss, language: 'en', format: SubtitleFormat.ass),
    (label: 'Sample (TTML)', url: SubtitleUrls.sampleTtml, language: 'en', format: SubtitleFormat.ttml),
  ];

  // Available languages for demo
  static const _languages = ['en', 'es', 'fr', 'de', 'pt', 'ja', 'ko', 'zh'];
  static const _languageNames = {
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'pt': 'Portuguese',
    'ja': 'Japanese',
    'ko': 'Korean',
    'zh': 'Chinese',
  };

  @override
  void initState() {
    super.initState();
    unawaited(_initializePlayer());
  }

  Future<void> _initializePlayer() async {
    await _controller?.dispose();

    _controller = ProVideoPlayerController();

    try {
      await _controller!.initialize(
        // Angel One HLS has embedded subtitles and works across all platforms
        source: const VideoSource.network(VideoUrls.shakaAngelOneHls),
        options: VideoPlayerOptions(
          autoPlay: true,
          looping: true,
          subtitlesEnabled: _subtitlesEnabled,
          showSubtitlesByDefault: _showByDefault,
          preferredSubtitleLanguage: _preferredLanguage,
          subtitleRenderMode: _subtitleRenderMode,
        ),
      );

      setState(() {
        _isInitialized = true;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _reinitializeWithOptions() async {
    setState(() {
      _isInitialized = false;
      _error = null;
    });
    await _initializePlayer();
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    _urlController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  String _getSubtitleRenderModeDescription(SubtitleRenderMode mode) {
    switch (mode) {
      case SubtitleRenderMode.native:
        return 'Native (Platform renders subtitles)';
      case SubtitleRenderMode.flutter:
        return 'Flutter (Custom styling, works with all controls)';
      case SubtitleRenderMode.auto:
        return 'Auto (Defaults to Flutter rendering)';
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Subtitle Configuration')),
    body: _buildContent(),
  );

  Widget _buildContent() {
    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return ResponsiveVideoLayout(
      videoPlayer: ProVideoPlayer(
        key: ValueKey('subtitle_player_$_useNativeControls'),
        controller: _controller!,
        controlsMode: _useNativeControls ? ControlsMode.native : ControlsMode.flutter,
        subtitleStyle: _subtitleStyle,
        placeholder: const Center(child: CircularProgressIndicator(color: Colors.white)),
        // Use full controls (not compact/mini) for better subtitle demonstration
        controlsBuilder: _useNativeControls
            ? null
            : (context, controller) => VideoPlayerControls(
                key: TestKeys.subtitleConfigVideoPlayer,
                controller: controller,
                subtitleStyle: _subtitleStyle,
                compactMode: CompactMode.never,
              ),
      ),
      controls: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildControlsModeSelector(),
            const Divider(),
            _buildConfigOptions(),
            const Divider(),
            _buildSubtitleStyling(),
            const Divider(),
            _buildExternalSubtitles(),
            const Divider(),
            _buildAvailableTracks(),
            const Divider(),
            _buildSubtitleSync(),
            const Divider(),
            _buildPlaybackControls(),
          ],
        ),
      ),
      maxVideoHeightFraction: 0.30,
    );
  }

  Widget _buildErrorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $_error', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _reinitializeWithOptions, child: const Text('Retry')),
        ],
      ),
    ),
  );

  Widget _buildControlsModeSelector() => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Controls Mode', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Compare how subtitles render with different control modes',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Flutter Controls'), icon: Icon(Icons.widgets_outlined)),
            ButtonSegment(value: true, label: Text('Native Controls'), icon: Icon(Icons.phone_android_outlined)),
          ],
          selected: {_useNativeControls},
          onSelectionChanged: (selection) => setState(() => _useNativeControls = selection.first),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _useNativeControls
                      ? 'Native controls use platform subtitle rendering (AVPlayer/ExoPlayer)'
                      : 'Flutter controls render subtitles using the SubtitleOverlay widget',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildConfigOptions() => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Initialization Options', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            FilledButton.tonal(onPressed: _reinitializeWithOptions, child: const Text('Apply')),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'These options are set at initialization time',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),

        // Subtitles enabled
        SwitchListTile(
          title: const Text('Subtitles Enabled'),
          subtitle: const Text('Allow subtitle track loading'),
          secondary: const Icon(Icons.subtitles),
          value: _subtitlesEnabled,
          onChanged: (value) => setState(() => _subtitlesEnabled = value),
        ),

        // Show by default
        SwitchListTile(
          title: const Text('Show by Default'),
          subtitle: const Text('Auto-select subtitles when available'),
          secondary: const Icon(Icons.visibility),
          value: _showByDefault,
          onChanged: _subtitlesEnabled ? (value) => setState(() => _showByDefault = value) : null,
        ),

        // Subtitle Rendering Mode
        ListTile(
          leading: const Icon(Icons.layers),
          title: const Text('Subtitle Rendering Mode'),
          subtitle: Text(_getSubtitleRenderModeDescription(_subtitleRenderMode)),
          trailing: PopupMenuButton<SubtitleRenderMode>(
            initialValue: _subtitleRenderMode,
            onSelected: _subtitlesEnabled ? (value) => setState(() => _subtitleRenderMode = value) : null,
            enabled: _subtitlesEnabled,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: SubtitleRenderMode.native,
                child: ListTile(
                  title: Text('Native'),
                  subtitle: Text('Platform renders subtitles'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: SubtitleRenderMode.flutter,
                child: ListTile(
                  title: Text('Flutter'),
                  subtitle: Text('Custom styling, works with all controls'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: SubtitleRenderMode.auto,
                child: ListTile(
                  title: Text('Auto'),
                  subtitle: Text('Defaults to Flutter rendering'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),

        // Preferred language
        ListTile(
          leading: const Icon(Icons.language),
          title: const Text('Preferred Language'),
          subtitle: Text(
            _preferredLanguage != null
                ? '${_languageNames[_preferredLanguage]} ($_preferredLanguage)'
                : 'None (use default track)',
          ),
          trailing: PopupMenuButton<String?>(
            initialValue: _preferredLanguage,
            onSelected: _subtitlesEnabled ? (value) => setState(() => _preferredLanguage = value) : null,
            enabled: _subtitlesEnabled,
            itemBuilder: (context) => [
              const PopupMenuItem(child: Text('None')),
              const PopupMenuDivider(),
              ..._languages.map((code) => PopupMenuItem(value: code, child: Text('${_languageNames[code]} ($code)'))),
            ],
          ),
        ),

        const Divider(height: 32),

        // Runtime Switching Section
        Row(children: [Text('Runtime Subtitle Mode Control', style: Theme.of(context).textTheme.titleMedium)]),
        const SizedBox(height: 8),
        Text(
          'Change rendering mode during playback without re-initialization',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),

        // Runtime mode switching buttons
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _isInitialized && _subtitlesEnabled
                  ? () => _switchSubtitleMode(SubtitleRenderMode.native)
                  : null,
              icon: const Icon(Icons.phone_android),
              label: const Text('Native'),
            ),
            FilledButton.tonalIcon(
              onPressed: _isInitialized && _subtitlesEnabled
                  ? () => _switchSubtitleMode(SubtitleRenderMode.flutter)
                  : null,
              icon: const Icon(Icons.flutter_dash),
              label: const Text('Flutter'),
            ),
            FilledButton.tonalIcon(
              onPressed: _isInitialized && _subtitlesEnabled
                  ? () => _switchSubtitleMode(SubtitleRenderMode.auto)
                  : null,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Auto'),
            ),
          ],
        ),
        if (_isInitialized && _subtitlesEnabled) ...[
          const SizedBox(height: 8),
          Text(
            'Current mode: ${_controller?.value.currentSubtitleRenderMode.name ?? "unknown"}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
          ),
        ],
      ],
    ),
  );

  Future<void> _switchSubtitleMode(SubtitleRenderMode mode) async {
    try {
      await _controller?.setSubtitleRenderMode(mode);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Switched to ${mode.name} rendering mode')));
        setState(() {}); // Refresh to show current mode
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _updateSubtitleStyle() {
    setState(() {
      _subtitleStyle = SubtitleStyle(
        fontSizePercent: _fontSizePercent,
        textColor: _textColor,
        backgroundColor: _backgroundColor,
        strokeColor: _enableStroke ? _strokeColor : null,
        strokeWidth: _enableStroke ? _strokeWidth : null,
        position: _position,
        textAlignment: _textAlignment,
        containerBorderRadius: _borderRadius,
        marginFromEdge: _marginFromEdge,
      );
    });
  }

  Widget _buildSubtitleStyling() => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Subtitle Styling', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            if (_useNativeControls)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Flutter only',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Customize subtitle appearance (Flutter controls only)',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade700),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Styling applies to external subtitles only. To test styling, load an external '
                  'subtitle below (e.g., "Rich Text Demo" samples). Embedded HLS subtitles use '
                  'platform rendering and cannot be styled.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.blue.shade900),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Position selector
        Text('Position', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<SubtitlePosition>(
          key: const Key('subtitle_config_position_selector'),
          segments: const [
            ButtonSegment(value: SubtitlePosition.top, label: Text('Top')),
            ButtonSegment(value: SubtitlePosition.middle, label: Text('Middle')),
            ButtonSegment(value: SubtitlePosition.bottom, label: Text('Bottom')),
          ],
          selected: {_position},
          onSelectionChanged: _useNativeControls
              ? null
              : (selection) {
                  _position = selection.first;
                  _updateSubtitleStyle();
                },
        ),
        const SizedBox(height: 16),

        // Text alignment selector
        Text('Text Alignment', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<SubtitleTextAlignment>(
          segments: const [
            ButtonSegment(value: SubtitleTextAlignment.left, label: Text('Left')),
            ButtonSegment(value: SubtitleTextAlignment.center, label: Text('Center')),
            ButtonSegment(value: SubtitleTextAlignment.right, label: Text('Right')),
          ],
          selected: {_textAlignment},
          onSelectionChanged: _useNativeControls
              ? null
              : (selection) {
                  _textAlignment = selection.first;
                  _updateSubtitleStyle();
                },
        ),
        const SizedBox(height: 16),

        // Font size slider (percentage of default size)
        Text('Font Size: ${(_fontSizePercent * 100).toInt()}%', style: Theme.of(context).textTheme.titleSmall),
        Slider(
          key: TestKeys.subtitleConfigFontSizeSlider,
          value: _fontSizePercent,
          min: 0.5, // 50%
          max: 2, // 200%
          divisions: 15,
          label: '${(_fontSizePercent * 100).toInt()}%',
          onChanged: _useNativeControls
              ? null
              : (value) {
                  _fontSizePercent = value;
                  _updateSubtitleStyle();
                },
        ),

        // Color selectors
        Text('Colors', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ColorPickerChip(
              label: 'Text',
              color: _textColor,
              enabled: !_useNativeControls,
              onColorSelected: (color) {
                _textColor = color;
                _updateSubtitleStyle();
              },
            ),
            _ColorPickerChip(
              label: 'Background',
              color: _backgroundColor,
              enabled: !_useNativeControls,
              onColorSelected: (color) {
                _backgroundColor = color;
                _updateSubtitleStyle();
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Stroke settings
        SwitchListTile(
          title: const Text('Text Stroke'),
          subtitle: const Text('Add outline around text'),
          value: _enableStroke,
          onChanged: _useNativeControls
              ? null
              : (value) {
                  _enableStroke = value;
                  _updateSubtitleStyle();
                },
        ),
        if (_enableStroke) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stroke Width: ${_strokeWidth.toStringAsFixed(1)}', style: Theme.of(context).textTheme.bodySmall),
                Slider(
                  value: _strokeWidth,
                  min: 0.5,
                  max: 4,
                  divisions: 7,
                  onChanged: _useNativeControls
                      ? null
                      : (value) {
                          _strokeWidth = value;
                          _updateSubtitleStyle();
                        },
                ),
                _ColorPickerChip(
                  label: 'Stroke Color',
                  color: _strokeColor,
                  enabled: !_useNativeControls,
                  onColorSelected: (color) {
                    _strokeColor = color;
                    _updateSubtitleStyle();
                  },
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),

        // Border radius slider
        Text('Container Border Radius: ${_borderRadius.toInt()}', style: Theme.of(context).textTheme.titleSmall),
        Slider(
          value: _borderRadius,
          max: 16,
          divisions: 16,
          onChanged: _useNativeControls
              ? null
              : (value) {
                  _borderRadius = value;
                  _updateSubtitleStyle();
                },
        ),

        // Margin from edge slider
        Text('Margin from Edge: ${_marginFromEdge.toInt()}', style: Theme.of(context).textTheme.titleSmall),
        Slider(
          value: _marginFromEdge,
          max: 100,
          divisions: 20,
          onChanged: _useNativeControls
              ? null
              : (value) {
                  _marginFromEdge = value;
                  _updateSubtitleStyle();
                },
        ),

        // Reset button
        Center(
          child: TextButton.icon(
            onPressed: _useNativeControls
                ? null
                : () {
                    setState(() {
                      _textColor = Colors.white;
                      _fontSizePercent = 1;
                      _backgroundColor = Colors.transparent;
                      _enableStroke = false;
                      _strokeColor = Colors.black;
                      _strokeWidth = 2;
                      _position = SubtitlePosition.bottom;
                      _textAlignment = SubtitleTextAlignment.center;
                      _borderRadius = 4;
                      _marginFromEdge = 48;
                      _subtitleStyle = const SubtitleStyle();
                    });
                  },
            icon: const Icon(Icons.refresh),
            label: const Text('Reset to Defaults'),
          ),
        ),
      ],
    ),
  );

  Widget _buildExternalSubtitles() => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('External Subtitles', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Load subtitles from external URLs (VTT, SRT, ASS, TTML)',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),

        // Sample subtitles section
        Text('Quick Load Samples', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _sampleSubtitles.map((sample) {
            final isLoaded = _loadedExternalTracks.any((t) => t.path == sample.url);
            return ActionChip(
              avatar: Icon(
                isLoaded ? Icons.check_circle : Icons.subtitles,
                size: 18,
                color: isLoaded ? Colors.green : null,
              ),
              label: Text(sample.label),
              onPressed: isLoaded
                  ? null
                  : () => unawaited(
                      _loadExternalSubtitle(
                        url: sample.url,
                        label: sample.label,
                        language: sample.language,
                        format: sample.format,
                      ),
                    ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Custom URL input
        Text('Custom URL', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            labelText: 'Subtitle URL',
            hintText: 'https://example.com/subtitles.vtt',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.link),
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Label (optional)',
                  hintText: 'English Subtitles',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Language', border: OutlineInputBorder(), isDense: true),
                items: [
                  const DropdownMenuItem(child: Text('Auto')),
                  ..._languages.map((code) => DropdownMenuItem(value: code, child: Text(code.toUpperCase()))),
                ],
                onChanged: (value) => setState(() => _selectedLanguage = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<SubtitleFormat>(
                decoration: const InputDecoration(
                  labelText: 'Format (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(child: Text('Auto-detect')),
                  DropdownMenuItem(value: SubtitleFormat.vtt, child: Text('VTT')),
                  DropdownMenuItem(value: SubtitleFormat.srt, child: Text('SRT')),
                  DropdownMenuItem(value: SubtitleFormat.ass, child: Text('ASS')),
                  DropdownMenuItem(value: SubtitleFormat.ssa, child: Text('SSA')),
                  DropdownMenuItem(value: SubtitleFormat.ttml, child: Text('TTML')),
                ],
                onChanged: (value) => setState(() => _selectedFormat = value),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _isLoadingExternal || _urlController.text.isEmpty
                  ? null
                  : () => unawaited(
                      _loadExternalSubtitle(
                        url: _urlController.text,
                        label: _labelController.text.isEmpty ? null : _labelController.text,
                        language: _selectedLanguage,
                        format: _selectedFormat,
                      ),
                    ),
              icon: _isLoadingExternal
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add),
              label: const Text('Load'),
            ),
          ],
        ),

        // Error display
        if (_externalError != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_externalError!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                ),
              ],
            ),
          ),
        ],

        // Loaded external tracks
        if (_loadedExternalTracks.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Loaded External Tracks', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ..._loadedExternalTracks.map(
            (track) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.subtitles),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(track.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            '${track.format.name.toUpperCase()} • ${track.language ?? "Unknown"}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Remove',
                      onPressed: () => unawaited(_removeExternalSubtitle(track)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Future<void> _loadExternalSubtitle({
    required String url,
    String? label,
    String? language,
    SubtitleFormat? format,
  }) async {
    setState(() {
      _isLoadingExternal = true;
      _externalError = null;
    });

    try {
      final track = await _controller!.addExternalSubtitle(
        SubtitleSource.network(url, label: label, language: language, format: format),
      );

      if (track != null) {
        setState(() {
          _loadedExternalTracks.add(track);
          _urlController.clear();
          _labelController.clear();
          _selectedFormat = null;
          _selectedLanguage = null;
        });
      } else {
        setState(() => _externalError = 'Failed to load subtitle from URL');
      }
    } catch (e) {
      setState(() => _externalError = 'Error: $e');
    } finally {
      setState(() => _isLoadingExternal = false);
    }
  }

  Future<void> _removeExternalSubtitle(ExternalSubtitleTrack track) async {
    final success = await _controller!.removeExternalSubtitle(track.id);
    if (success) {
      setState(() {
        _loadedExternalTracks.removeWhere((t) => t.id == track.id);
      });
    }
  }

  Widget _buildAvailableTracks() => ValueListenableBuilder<VideoPlayerValue>(
    valueListenable: _controller!,
    builder: (context, value, child) {
      final tracks = value.subtitleTracks;
      final selected = value.selectedSubtitleTrack;

      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available Subtitle Tracks', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (!_subtitlesEnabled)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(child: Text('Subtitles are disabled in options')),
                  ],
                ),
              )
            else if (tracks.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [Icon(Icons.subtitles_off), SizedBox(width: 12), Text('No subtitle tracks available')],
                ),
              )
            else ...[
              // Off option
              _SubtitleTrackTile(
                title: 'Off',
                subtitle: 'Disable subtitles',
                isSelected: selected == null,
                onTap: () => unawaited(_controller!.setSubtitleTrack(null)),
              ),
              const SizedBox(height: 8),
              // Available tracks
              ...tracks.map(
                (track) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SubtitleTrackTile(
                    title: track.label.isNotEmpty ? track.label : 'Track ${track.id}',
                    subtitle: _buildTrackSubtitle(track),
                    isSelected: selected?.id == track.id,
                    isDefault: track.isDefault,
                    onTap: () => unawaited(_controller!.setSubtitleTrack(track)),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );

  String _buildTrackSubtitle(SubtitleTrack track) {
    final parts = <String>[];
    if (track.language != null) {
      final langName = _languageNames[track.language] ?? track.language;
      parts.add(langName!);
    }
    if (track.isDefault) {
      parts.add('Default');
    }
    return parts.isEmpty ? 'Unknown' : parts.join(' • ');
  }

  Widget _buildSubtitleSync() => ValueListenableBuilder<VideoPlayerValue>(
    valueListenable: _controller!,
    builder: (context, value, child) {
      final offsetMs = value.subtitleOffset.inMilliseconds;
      final offsetSeconds = offsetMs / 1000.0;

      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Subtitle Sync', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (offsetMs != 0)
                  TextButton.icon(
                    onPressed: () => _controller!.setSubtitleOffset(Duration.zero),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reset'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Adjust subtitle timing if they appear too early or too late',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            // Current offset display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    offsetMs < 0 ? Icons.fast_rewind : (offsetMs > 0 ? Icons.fast_forward : Icons.sync),
                    color: offsetMs != 0
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    offsetMs == 0
                        ? 'No offset'
                        : '${offsetSeconds >= 0 ? '+' : ''}${offsetSeconds.toStringAsFixed(1)}s',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: offsetMs != 0
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Explanation
            Text(
              offsetMs > 0
                  ? 'Subtitles delayed (appear later)'
                  : offsetMs < 0
                  ? 'Subtitles earlier (appear sooner)'
                  : 'Subtitles in sync',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Slider for fine adjustment
            Row(
              children: [
                const Text('-5s'),
                Expanded(
                  child: Slider(
                    value: offsetSeconds.clamp(-5.0, 5.0),
                    min: -5,
                    max: 5,
                    divisions: 100,
                    label: '${offsetSeconds >= 0 ? '+' : ''}${offsetSeconds.toStringAsFixed(1)}s',
                    onChanged: (value) {
                      _controller!.setSubtitleOffset(Duration(milliseconds: (value * 1000).round()));
                    },
                  ),
                ),
                const Text('+5s'),
              ],
            ),
            const SizedBox(height: 8),

            // Quick adjustment buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SyncButton(
                  label: '-0.5s',
                  onPressed: () => _controller!.setSubtitleOffset(Duration(milliseconds: offsetMs - 500)),
                ),
                _SyncButton(
                  label: '-0.1s',
                  onPressed: () => _controller!.setSubtitleOffset(Duration(milliseconds: offsetMs - 100)),
                ),
                _SyncButton(
                  label: '+0.1s',
                  onPressed: () => _controller!.setSubtitleOffset(Duration(milliseconds: offsetMs + 100)),
                ),
                _SyncButton(
                  label: '+0.5s',
                  onPressed: () => _controller!.setSubtitleOffset(Duration(milliseconds: offsetMs + 500)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Info box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Only affects external subtitles with Flutter controls. '
                      'Embedded/native subtitles use platform rendering.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _buildPlaybackControls() => ValueListenableBuilder<VideoPlayerValue>(
    valueListenable: _controller!,
    builder: (context, value, child) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Playback', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Slider(
            value: value.position.inMilliseconds.toDouble(),
            max: value.duration.inMilliseconds.toDouble().clamp(1, double.infinity),
            onChanged: (v) => unawaited(_controller!.seekTo(Duration(milliseconds: v.toInt()))),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(_formatDuration(value.position)), Text(_formatDuration(value.duration))],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10),
                onPressed: () => unawaited(_controller!.seekBackward(const Duration(seconds: 10))),
              ),
              const SizedBox(width: 16),
              IconButton(
                iconSize: 48,
                icon: Icon(value.isPlaying ? Icons.pause_circle : Icons.play_circle),
                onPressed: () => unawaited(_controller!.togglePlayPause()),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.forward_10),
                onPressed: () => unawaited(_controller!.seekForward(const Duration(seconds: 10))),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _SubtitleTrackTile extends StatelessWidget {
  const _SubtitleTrackTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.isDefault = false,
  });

  final String title;
  final String subtitle;
  final bool isSelected;
  final bool isDefault;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.check_circle : Icons.subtitles_outlined,
            color: isSelected ? Theme.of(context).colorScheme.primary : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Theme.of(context).colorScheme.primary : null,
                      ),
                    ),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'DEFAULT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _SyncButton extends StatelessWidget {
  const _SyncButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: Text(label, style: const TextStyle(fontSize: 13)),
  );
}

/// A simple color picker chip that shows a color and opens a color picker dialog.
class _ColorPickerChip extends StatelessWidget {
  const _ColorPickerChip({
    required this.label,
    required this.color,
    required this.onColorSelected,
    this.enabled = true,
  });

  final String label;
  final Color color;
  final ValueChanged<Color> onColorSelected;
  final bool enabled;

  static const _presetColors = [
    Colors.white,
    Colors.black,
    Colors.yellow,
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.cyan,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.transparent,
  ];

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey),
      ),
    ),
    label: Text(label),
    onPressed: enabled ? () => _showColorPicker(context) : null,
  );

  void _showColorPicker(BuildContext context) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Select $label Color'),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presetColors.map((presetColor) {
              final isSelected = presetColor == color;
              return GestureDetector(
                onTap: () {
                  onColorSelected(presetColor);
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: presetColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: presetColor == Colors.transparent
                      ? const Icon(Icons.not_interested, size: 20, color: Colors.grey)
                      : null,
                ),
              );
            }).toList(),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))],
        ),
      ),
    );
  }
}
