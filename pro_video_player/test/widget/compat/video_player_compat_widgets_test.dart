/// Tests for video_player compatibility widgets.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player/video_player_compat.dart';

void main() {
  group('ClosedCaption', () {
    testWidgets('renders nothing when text is null', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ClosedCaption())));

      expect(find.byType(Text), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('renders nothing when text is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ClosedCaption(text: '')),
        ),
      );

      expect(find.byType(Text), findsNothing);
    });

    testWidgets('renders text when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ClosedCaption(text: 'Test caption')),
        ),
      );

      expect(find.text('Test caption'), findsOneWidget);
    });

    testWidgets('applies custom textStyle', (tester) async {
      const customStyle = TextStyle(fontSize: 24, color: Colors.yellow);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClosedCaption(text: 'Test caption', textStyle: customStyle),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('Test caption'));
      expect(textWidget.style?.fontSize, equals(24));
      expect(textWidget.style?.color, equals(Colors.yellow));
    });

    testWidgets('is aligned at bottom center', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ClosedCaption(text: 'Test caption')),
        ),
      );

      final align = tester.widget<Align>(find.byType(Align));
      expect(align.alignment, equals(Alignment.bottomCenter));
    });

    testWidgets('has dark background decoration', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ClosedCaption(text: 'Test caption')),
        ),
      );

      expect(find.byType(DecoratedBox), findsOneWidget);
    });
  });

  group('VideoProgressColors', () {
    test('has correct default colors', () {
      const colors = VideoProgressColors();

      expect(colors.playedColor, equals(const Color.fromRGBO(255, 0, 0, 0.7)));
      expect(colors.bufferedColor, equals(const Color.fromRGBO(50, 50, 200, 0.2)));
      expect(colors.backgroundColor, equals(const Color.fromRGBO(200, 200, 200, 0.5)));
    });

    test('accepts custom colors', () {
      const colors = VideoProgressColors(
        playedColor: Colors.blue,
        bufferedColor: Colors.green,
        backgroundColor: Colors.grey,
      );

      expect(colors.playedColor, equals(Colors.blue));
      expect(colors.bufferedColor, equals(Colors.green));
      expect(colors.backgroundColor, equals(Colors.grey));
    });
  });

  group('@videoPlayerCompat annotation', () {
    test('VideoPlayerCompat annotation exists', () {
      const annotation = VideoPlayerCompat();

      expect(annotation.since, isNull);
      expect(annotation.notes, isNull);
    });

    test('VideoPlayerCompat annotation accepts parameters', () {
      const annotation = VideoPlayerCompat(since: '1.0.0', notes: 'Test notes');

      expect(annotation.since, equals('1.0.0'));
      expect(annotation.notes, equals('Test notes'));
    });

    test('videoPlayerCompat constant is available', () {
      expect(videoPlayerCompat, isA<VideoPlayerCompat>());
    });
  });
}
