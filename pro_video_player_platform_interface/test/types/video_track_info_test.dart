import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_player_platform_interface/pro_video_player_platform_interface.dart';

void main() {
  group('VideoTrackInfo', () {
    group('constructor', () {
      test('creates with required fields only', () {
        const info = VideoTrackInfo(width: 1920, height: 1080);

        expect(info.width, equals(1920));
        expect(info.height, equals(1080));
        expect(info.frameRate, isNull);
        expect(info.displayWidth, isNull);
        expect(info.displayHeight, isNull);
        expect(info.rotation, isNull);
        expect(info.pixelAspectRatio, isNull);
      });

      test('creates with all fields', () {
        const info = VideoTrackInfo(
          width: 1920,
          height: 1080,
          frameRate: 29.97,
          displayWidth: 1920,
          displayHeight: 1080,
          rotation: 90,
          pixelAspectRatio: 1,
        );

        expect(info.width, equals(1920));
        expect(info.height, equals(1080));
        expect(info.frameRate, equals(29.97));
        expect(info.displayWidth, equals(1920));
        expect(info.displayHeight, equals(1080));
        expect(info.rotation, equals(90));
        expect(info.pixelAspectRatio, equals(1.0));
      });
    });

    group('resolution', () {
      test('returns formatted resolution string', () {
        const info = VideoTrackInfo(width: 1920, height: 1080);
        expect(info.resolution, equals('1920x1080'));
      });

      test('returns resolution for 4K', () {
        const info = VideoTrackInfo(width: 3840, height: 2160);
        expect(info.resolution, equals('3840x2160'));
      });

      test('returns resolution for vertical video', () {
        const info = VideoTrackInfo(width: 1080, height: 1920);
        expect(info.resolution, equals('1080x1920'));
      });
    });

    group('aspectRatio', () {
      test('returns 16:9 ratio for 1920x1080', () {
        const info = VideoTrackInfo(width: 1920, height: 1080);
        expect(info.aspectRatio, closeTo(16 / 9, 0.01));
      });

      test('returns 4:3 ratio for 640x480', () {
        const info = VideoTrackInfo(width: 640, height: 480);
        expect(info.aspectRatio, closeTo(4 / 3, 0.01));
      });

      test('uses display dimensions when available', () {
        const info = VideoTrackInfo(width: 1440, height: 1080, displayWidth: 1920, displayHeight: 1080);
        // Display aspect ratio should be used
        expect(info.displayAspectRatio, closeTo(16 / 9, 0.01));
      });
    });

    group('isHD', () {
      test('returns true for 1080p', () {
        const info = VideoTrackInfo(width: 1920, height: 1080);
        expect(info.isHD, isTrue);
      });

      test('returns true for 720p', () {
        const info = VideoTrackInfo(width: 1280, height: 720);
        expect(info.isHD, isTrue);
      });

      test('returns false for 480p', () {
        const info = VideoTrackInfo(width: 854, height: 480);
        expect(info.isHD, isFalse);
      });
    });

    group('is4K', () {
      test('returns true for 2160p', () {
        const info = VideoTrackInfo(width: 3840, height: 2160);
        expect(info.is4K, isTrue);
      });

      test('returns false for 1080p', () {
        const info = VideoTrackInfo(width: 1920, height: 1080);
        expect(info.is4K, isFalse);
      });
    });

    group('fromMap', () {
      test('creates from complete map', () {
        final info = VideoTrackInfo.fromMap({
          'width': 1920,
          'height': 1080,
          'frameRate': 29.97,
          'displayWidth': 1920,
          'displayHeight': 1080,
          'rotation': 90,
          'pixelAspectRatio': 1.0,
        });

        expect(info.width, equals(1920));
        expect(info.height, equals(1080));
        expect(info.frameRate, equals(29.97));
        expect(info.rotation, equals(90));
      });

      test('handles missing optional fields', () {
        final info = VideoTrackInfo.fromMap({'width': 1920, 'height': 1080});

        expect(info.width, equals(1920));
        expect(info.height, equals(1080));
        expect(info.frameRate, isNull);
        expect(info.rotation, isNull);
      });

      test('handles integer frameRate', () {
        final info = VideoTrackInfo.fromMap({'width': 1920, 'height': 1080, 'frameRate': 30});

        expect(info.frameRate, equals(30.0));
      });
    });

    group('toMap', () {
      test('converts all fields to map', () {
        const info = VideoTrackInfo(width: 1920, height: 1080, frameRate: 29.97, rotation: 90);

        final map = info.toMap();

        expect(map['width'], equals(1920));
        expect(map['height'], equals(1080));
        expect(map['frameRate'], equals(29.97));
        expect(map['rotation'], equals(90));
      });

      test('excludes null fields', () {
        const info = VideoTrackInfo(width: 1920, height: 1080);

        final map = info.toMap();

        expect(map.containsKey('width'), isTrue);
        expect(map.containsKey('height'), isTrue);
        expect(map.containsKey('frameRate'), isFalse);
        expect(map.containsKey('rotation'), isFalse);
      });
    });

    group('copyWith', () {
      test('creates copy with same values', () {
        const original = VideoTrackInfo(width: 1920, height: 1080, frameRate: 29.97);

        final copy = original.copyWith();

        expect(copy, equals(original));
      });

      test('updates specific fields', () {
        const original = VideoTrackInfo(width: 1920, height: 1080);

        final updated = original.copyWith(frameRate: 60, rotation: 180);

        expect(updated.width, equals(1920));
        expect(updated.height, equals(1080));
        expect(updated.frameRate, equals(60.0));
        expect(updated.rotation, equals(180));
      });
    });

    group('equality', () {
      test('equal instances are equal', () {
        const a = VideoTrackInfo(width: 1920, height: 1080, frameRate: 30);
        const b = VideoTrackInfo(width: 1920, height: 1080, frameRate: 30);

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different width makes inequality', () {
        const a = VideoTrackInfo(width: 1920, height: 1080);
        const b = VideoTrackInfo(width: 1280, height: 1080);

        expect(a, isNot(equals(b)));
      });

      test('different height makes inequality', () {
        const a = VideoTrackInfo(width: 1920, height: 1080);
        const b = VideoTrackInfo(width: 1920, height: 720);

        expect(a, isNot(equals(b)));
      });
    });

    group('toString', () {
      test('returns readable representation', () {
        const info = VideoTrackInfo(width: 1920, height: 1080, frameRate: 30);

        expect(info.toString(), contains('VideoTrackInfo'));
        expect(info.toString(), contains('1920'));
        expect(info.toString(), contains('1080'));
      });
    });
  });
}
