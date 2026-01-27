/// Container and manifest parsing library for media files and streams.
///
/// This library provides pure Dart parsing of:
/// - MP4/MOV container headers (extract metadata without decoding)
/// - MKV/WebM container headers (Matroska format)
/// - TS (MPEG Transport Stream) headers
/// - FLV (Flash Video) headers
/// - AVI (Audio Video Interleave) headers
/// - HLS manifests (M3U8 master playlists)
/// - DASH manifests (MPD files)
///
/// Example - Container parsing (MP4, MKV, TS, FLV, AVI):
/// ```dart
/// import 'package:pro_video_player_platform_interface/container.dart';
///
/// final metadata = await ContainerParser.parseFilePath('video.mp4');
/// // Also works with: .mkv, .webm, .ts, .flv, .avi
/// if (metadata != null) {
///   print('Format: ${metadata.format}');
///   print('Duration: ${metadata.duration}');
///   for (final track in metadata.tracks) {
///     print('Track ${track.id}: ${track.type.displayName} - ${track.codec.name}');
///   }
/// }
/// ```
///
/// Example - HLS manifest:
/// ```dart
/// final hls = await HlsManifestParser.parseUrl(Uri.parse('https://example.com/master.m3u8'));
/// if (hls != null) {
///   for (final variant in hls.variants) {
///     print('${variant.qualityLabel}: ${variant.codecs}');
///   }
/// }
/// ```
///
/// Example - DASH manifest:
/// ```dart
/// final dash = await DashManifestParser.parseUrl(Uri.parse('https://example.com/manifest.mpd'));
/// if (dash != null) {
///   for (final rep in dash.videoRepresentations) {
///     print('${rep.qualityLabel}: ${rep.codecs}');
///   }
/// }
/// ```
library;

export 'avi_parser.dart' show AviAudioFormat, AviParser, AviStreamType;
export 'container_parser.dart';
export 'dash_manifest_parser.dart';
export 'ebml_reader.dart' show EbmlElement, EbmlIds, EbmlReader, MatroskaIds;
export 'flv_parser.dart' show FlvAudioCodec, FlvParser, FlvTagType, FlvVideoCodec;
export 'hls_manifest_parser.dart';
export 'mkv_parser.dart' show MkvParser;
export 'mp4_box_reader.dart' show Mp4Box, Mp4BoxReader;
export 'ts_parser.dart' show TsParser, TsStreamType;
