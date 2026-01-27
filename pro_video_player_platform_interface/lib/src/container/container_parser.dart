import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../types/container_metadata.dart';
import 'avi_parser.dart';
import 'flv_parser.dart';
import 'mkv_parser.dart';
import 'mp4_box_reader.dart';
import 'mp4_parser.dart';
import 'ts_parser.dart';

/// Parser for media container formats.
///
/// Provides static methods for detecting container formats and parsing
/// metadata from container headers without decoding media content.
///
/// Currently supports:
/// - MP4 (ISO Base Media File Format)
/// - MOV (QuickTime File Format)
/// - M4A, M4V, 3GP (MP4 variants)
/// - MKV (Matroska Video)
/// - WebM (Web Video/Audio)
/// - TS (MPEG Transport Stream)
/// - FLV (Flash Video)
/// - AVI (Audio Video Interleave)
///
/// Example:
/// ```dart
/// final bytes = await File('video.mp4').readAsBytes();
///
/// // Check format
/// final format = ContainerParser.detectFormat(bytes);
/// print('Format: $format');
///
/// // Parse metadata
/// final metadata = ContainerParser.parse(bytes);
/// if (metadata != null) {
///   print('Duration: ${metadata.duration}');
///   print('Tracks: ${metadata.tracks.length}');
/// }
/// ```
class ContainerParser {
  ContainerParser._();

  /// Detects the container format from file data.
  ///
  /// Returns the format name ('mp4', 'mov', 'm4a', 'mkv', 'webm', 'ts', 'flv', 'avi', etc.)
  /// if recognized, or null if the format cannot be determined.
  ///
  /// Only requires the first few bytes to detect format.
  static String? detectFormat(Uint8List data) {
    if (data.length < 8) return null;

    // Check for EBML/MKV/WebM format first (signature: 0x1A45DFA3)
    if (MkvParser.isValidEbml(data)) {
      return MkvParser.detectFormat(data);
    }

    // Check for AVI format (RIFF/AVI signature)
    if (AviParser.isValidAvi(data)) {
      return AviParser.detectFormat(data);
    }

    // Check for FLV format ("FLV" signature)
    if (FlvParser.isValidFlv(data)) {
      return FlvParser.detectFormat(data);
    }

    // Check for TS format (sync byte 0x47)
    if (TsParser.isValidTs(data)) {
      return TsParser.detectFormat(data);
    }

    // Check for MP4/MOV format (ftyp box)
    final reader = Mp4BoxReader(data);
    final box = reader.readBox();

    if (box == null || box.type != 'ftyp') return null;

    return Mp4Parser.detectFormat(reader, box);
  }

  /// Parses container metadata from file data.
  ///
  /// Returns [ContainerMetadata] containing format, duration, tracks,
  /// and other information extracted from container headers.
  ///
  /// Returns null if the format is not supported or parsing fails.
  static ContainerMetadata? parse(Uint8List data) {
    if (data.length < 8) return null;

    // Check for EBML/MKV/WebM format first
    if (MkvParser.isValidEbml(data)) {
      return MkvParser.parse(data);
    }

    // Check for AVI format
    if (AviParser.isValidAvi(data)) {
      return AviParser.parse(data);
    }

    // Check for FLV format
    if (FlvParser.isValidFlv(data)) {
      return FlvParser.parse(data);
    }

    // Check for TS format
    if (TsParser.isValidTs(data)) {
      return TsParser.parse(data);
    }

    // Parse as MP4/MOV
    final format = detectFormat(data);
    if (format == null) return null;

    final reader = Mp4BoxReader(data);
    return Mp4Parser.parse(reader, format);
  }

  /// Returns true if the data appears to be a supported container format.
  static bool isSupportedFormat(Uint8List data) => detectFormat(data) != null;

  /// Parses container metadata from a file path.
  ///
  /// Convenience method that opens the file, parses it, and closes it.
  /// For multiple operations on the same file, prefer using [parseFile]
  /// with a manually managed [RandomAccessFile].
  ///
  /// Example:
  /// ```dart
  /// final metadata = await ContainerParser.parseFilePath('/path/to/video.mp4');
  /// if (metadata != null) {
  ///   print('Duration: ${metadata.duration}');
  /// }
  /// ```
  static Future<ContainerMetadata?> parseFilePath(String path) async {
    final file = File(path);
    if (!file.existsSync()) return null;

    final raf = await file.open();
    try {
      return await parseFile(raf);
    } finally {
      await raf.close();
    }
  }

  /// Parses container metadata from a URL using HTTP range requests.
  ///
  /// Efficiently fetches only the necessary bytes (ftyp and moov boxes)
  /// rather than downloading the entire file. Handles both fast-start
  /// MP4s (moov at beginning) and standard MP4s (moov at end).
  ///
  /// Requires the server to support:
  /// - HEAD requests (to get file size)
  /// - Range requests (to fetch specific byte ranges)
  ///
  /// Parameters:
  /// - [url]: The URL of the MP4/MOV file
  /// - [client]: Optional HTTP client (uses default if not provided)
  /// - [initialChunkSize]: Size of initial fetch (default 256KB)
  /// - [headers]: Additional HTTP headers to include in requests
  ///
  /// Returns null if:
  /// - The URL is not accessible
  /// - The server doesn't support range requests
  /// - The file is not a valid MP4/MOV container
  ///
  /// Example:
  /// ```dart
  /// final metadata = await ContainerParser.parseUrl(
  ///   Uri.parse('https://example.com/video.mp4'),
  /// );
  /// if (metadata != null) {
  ///   print('Duration: ${metadata.duration}');
  ///   print('Video codec: ${metadata.primaryVideoTrack?.codec.name}');
  /// }
  /// ```
  static Future<ContainerMetadata?> parseUrl(
    Uri url, {
    http.Client? client,
    int initialChunkSize = 256 * 1024,
    Map<String, String>? headers,
  }) async {
    final httpClient = client ?? http.Client();
    final shouldCloseClient = client == null;

    try {
      // Get file size with HEAD request
      final headResponse = await httpClient.head(url, headers: headers);
      if (headResponse.statusCode != 200) return null;

      final contentLength = int.tryParse(headResponse.headers['content-length'] ?? '');
      if (contentLength == null || contentLength < 8) return null;

      // Check if server supports range requests
      final acceptRanges = headResponse.headers['accept-ranges'];
      if (acceptRanges != 'bytes') {
        // Server doesn't support range requests, try fetching entire file
        // Only for small files to avoid memory issues
        if (contentLength > 10 * 1024 * 1024) return null; // 10MB limit

        final response = await httpClient.get(url, headers: headers);
        if (response.statusCode != 200) return null;
        return parse(response.bodyBytes);
      }

      // Fetch initial chunk (should contain ftyp, may contain moov)
      final chunkSize = initialChunkSize.clamp(64 * 1024, contentLength);
      final initialBytes = await _fetchRange(httpClient, url, 0, chunkSize - 1, headers);
      if (initialBytes == null) return null;

      // Check for ftyp
      if (initialBytes.length < 8) return null;
      final ftypSize = (initialBytes[0] << 24) | (initialBytes[1] << 16) | (initialBytes[2] << 8) | initialBytes[3];
      final ftypType = String.fromCharCodes(initialBytes.sublist(4, 8));
      if (ftypType != 'ftyp') return null;

      // Try to find moov in initial chunk
      final moovOffset = _findBoxInBytes(initialBytes, 'moov', ftypSize);
      if (moovOffset != null) {
        // moov is in initial chunk - check if we have the complete box
        final moovSize =
            (initialBytes[moovOffset] << 24) |
            (initialBytes[moovOffset + 1] << 16) |
            (initialBytes[moovOffset + 2] << 8) |
            initialBytes[moovOffset + 3];

        if (moovOffset + moovSize <= initialBytes.length) {
          // Complete moov in initial chunk
          return parse(Uint8List.fromList(initialBytes));
        }

        // Need to fetch more bytes to complete moov
        final neededEnd = moovOffset + moovSize;
        if (neededEnd <= contentLength) {
          final moreBytes = await _fetchRange(httpClient, url, initialBytes.length, neededEnd - 1, headers);
          if (moreBytes != null) {
            final combined = Uint8List(initialBytes.length + moreBytes.length);
            combined.setRange(0, initialBytes.length, initialBytes);
            combined.setRange(initialBytes.length, combined.length, moreBytes);
            return parse(combined);
          }
        }
      }

      // moov not at start - scan from end
      return _parseUrlMoovAtEnd(httpClient, url, contentLength, initialBytes, headers);
    } finally {
      if (shouldCloseClient) {
        httpClient.close();
      }
    }
  }

  /// Fetches a byte range from URL.
  static Future<Uint8List?> _fetchRange(
    http.Client client,
    Uri url,
    int start,
    int end,
    Map<String, String>? baseHeaders,
  ) async {
    final headers = <String, String>{...?baseHeaders, 'Range': 'bytes=$start-$end'};

    final response = await client.get(url, headers: headers);
    if (response.statusCode != 206 && response.statusCode != 200) return null;

    return response.bodyBytes;
  }

  /// Finds a box type in bytes, starting from offset.
  static int? _findBoxInBytes(Uint8List bytes, String boxType, int startOffset) {
    final target = boxType.codeUnits;
    var offset = startOffset;

    while (offset + 8 <= bytes.length) {
      var size = (bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3];

      if (size == 0) size = bytes.length - offset;
      if (size < 8) return null;

      // Check box type
      if (bytes[offset + 4] == target[0] &&
          bytes[offset + 5] == target[1] &&
          bytes[offset + 6] == target[2] &&
          bytes[offset + 7] == target[3]) {
        return offset;
      }

      offset += size;
    }

    return null;
  }

  /// Handles parsing when moov is at end of file.
  static Future<ContainerMetadata?> _parseUrlMoovAtEnd(
    http.Client client,
    Uri url,
    int fileSize,
    Uint8List initialBytes,
    Map<String, String>? headers,
  ) async {
    // Fetch last 64KB to scan for moov
    const scanSize = 64 * 1024;
    final scanStart = (fileSize - scanSize).clamp(0, fileSize);

    final endBytes = await _fetchRange(client, url, scanStart, fileSize - 1, headers);
    if (endBytes == null) return null;

    // Look for moov signature
    for (var i = 0; i < endBytes.length - 8; i++) {
      if (endBytes[i + 4] == 0x6D && // 'm'
          endBytes[i + 5] == 0x6F && // 'o'
          endBytes[i + 6] == 0x6F && // 'o'
          endBytes[i + 7] == 0x76) {
        // 'v'

        final moovSize = (endBytes[i] << 24) | (endBytes[i + 1] << 16) | (endBytes[i + 2] << 8) | endBytes[i + 3];
        final moovOffset = scanStart + i;

        // Validate size
        if (moovSize < 8 || moovOffset + moovSize > fileSize) continue;

        // Check if we have complete moov
        if (i + moovSize <= endBytes.length) {
          // Combine ftyp (from initial) + moov (from end)
          final ftypSize = (initialBytes[0] << 24) | (initialBytes[1] << 16) | (initialBytes[2] << 8) | initialBytes[3];
          final ftypBytes = initialBytes.sublist(0, ftypSize.clamp(0, initialBytes.length));
          final moovBytes = endBytes.sublist(i, (i + moovSize).clamp(0, endBytes.length));

          final combined = Uint8List(ftypBytes.length + moovBytes.length);
          combined.setRange(0, ftypBytes.length, ftypBytes);
          combined.setRange(ftypBytes.length, combined.length, moovBytes);

          return parse(combined);
        }

        // Need to fetch complete moov
        final moovEnd = moovOffset + moovSize;
        final completeBytes = await _fetchRange(client, url, moovOffset, moovEnd - 1, headers);
        if (completeBytes == null) return null;

        // Combine ftyp + moov
        final ftypSize = (initialBytes[0] << 24) | (initialBytes[1] << 16) | (initialBytes[2] << 8) | initialBytes[3];
        final ftypBytes = initialBytes.sublist(0, ftypSize.clamp(0, initialBytes.length));

        final combined = Uint8List(ftypBytes.length + completeBytes.length);
        combined.setRange(0, ftypBytes.length, ftypBytes);
        combined.setRange(ftypBytes.length, combined.length, completeBytes);

        return parse(combined);
      }
    }

    // Try larger scan if file is big enough
    if (scanStart > 0) {
      const largeScanSize = 1024 * 1024; // 1MB
      final largeScanStart = (fileSize - largeScanSize).clamp(0, fileSize);

      if (largeScanStart < scanStart) {
        final largeBytes = await _fetchRange(client, url, largeScanStart, scanStart - 1, headers);
        if (largeBytes == null) return null;

        for (var i = 0; i < largeBytes.length - 8; i++) {
          if (largeBytes[i + 4] == 0x6D &&
              largeBytes[i + 5] == 0x6F &&
              largeBytes[i + 6] == 0x6F &&
              largeBytes[i + 7] == 0x76) {
            final moovSize =
                (largeBytes[i] << 24) | (largeBytes[i + 1] << 16) | (largeBytes[i + 2] << 8) | largeBytes[i + 3];
            final moovOffset = largeScanStart + i;

            if (moovSize >= 8 && moovOffset + moovSize <= fileSize) {
              final moovEnd = moovOffset + moovSize;
              final completeBytes = await _fetchRange(client, url, moovOffset, moovEnd - 1, headers);
              if (completeBytes == null) return null;

              final ftypSize =
                  (initialBytes[0] << 24) | (initialBytes[1] << 16) | (initialBytes[2] << 8) | initialBytes[3];
              final ftypBytes = initialBytes.sublist(0, ftypSize.clamp(0, initialBytes.length));

              final combined = Uint8List(ftypBytes.length + completeBytes.length);
              combined.setRange(0, ftypBytes.length, ftypBytes);
              combined.setRange(ftypBytes.length, combined.length, completeBytes);

              return parse(combined);
            }
          }
        }
      }
    }

    return null;
  }

  /// Detects the container format from a file.
  ///
  /// More efficient than [detectFormat] for large files as it only
  /// reads the first bytes from the file to determine format.
  ///
  /// The file position is not preserved after this call.
  static Future<String?> detectFormatFile(RandomAccessFile file) async {
    final length = await file.length();
    if (length < 8) return null;

    await file.setPosition(0);
    final header = await file.read(12); // Read enough for RIFF/AVI detection
    if (header.length < 8) return null;

    // Check for EBML/MKV/WebM format first
    if (header[0] == 0x1A && header[1] == 0x45 && header[2] == 0xDF && header[3] == 0xA3) {
      // Read enough for EBML header (typically < 64 bytes)
      await file.setPosition(0);
      final ebmlBytes = await file.read(256.clamp(0, length));
      return MkvParser.detectFormat(Uint8List.fromList(ebmlBytes));
    }

    // Check for AVI format (RIFF/AVI signature)
    if (header.length >= 12 &&
        header[0] == 0x52 &&
        header[1] == 0x49 &&
        header[2] == 0x46 &&
        header[3] == 0x46 && // "RIFF"
        header[8] == 0x41 &&
        header[9] == 0x56 &&
        header[10] == 0x49 &&
        header[11] == 0x20) {
      // "AVI "
      return 'avi';
    }

    // Check for FLV format ("FLV" signature)
    if (header[0] == 0x46 && header[1] == 0x4C && header[2] == 0x56 && header[3] == 0x01) {
      return 'flv';
    }

    // Check for TS format (sync byte 0x47 at regular intervals)
    if (header[0] == 0x47) {
      // Read more to verify TS format
      await file.setPosition(0);
      final tsBytes = await file.read(TsParser.packetSize * 2.clamp(0, length));
      if (TsParser.isValidTs(Uint8List.fromList(tsBytes))) {
        return 'ts';
      }
    }

    // Check for TS with timestamp prefix (sync at offset 4)
    if (header.length >= 5 && header[4] == 0x47) {
      await file.setPosition(0);
      final tsBytes = await file.read(TsParser.packetSizeWithTimestamp * 2.clamp(0, length));
      if (TsParser.isValidTs(Uint8List.fromList(tsBytes))) {
        return 'ts';
      }
    }

    // Check for MP4/MOV format
    // Get ftyp box size
    final size = (header[0] << 24) | (header[1] << 16) | (header[2] << 8) | header[3];
    final type = String.fromCharCodes(header.sublist(4, 8));

    if (type != 'ftyp') return null;
    if (size < 16 || size > length) return null;

    // Read full ftyp box
    await file.setPosition(0);
    final ftypBytes = await file.read(size);

    final reader = Mp4BoxReader(Uint8List.fromList(ftypBytes));
    final ftypBox = reader.readBox();

    if (ftypBox == null || ftypBox.type != 'ftyp') return null;

    return Mp4Parser.detectFormat(reader, ftypBox);
  }

  /// Parses container metadata from a file.
  ///
  /// More efficient than [parse] for large files as it only reads
  /// the necessary portions rather than the entire file.
  ///
  /// For MP4/MOV: handles both "fast-start" (moov at beginning) and
  /// standard MP4s (moov at end, after mdat).
  ///
  /// For MKV/WebM: reads EBML header and metadata segments.
  ///
  /// For TS/FLV/AVI: reads header and initial packets/tags.
  ///
  /// The file position is not preserved after this call.
  static Future<ContainerMetadata?> parseFile(RandomAccessFile file) async {
    final length = await file.length();
    if (length < 8) return null;

    // Read initial bytes to detect format
    await file.setPosition(0);
    final header = await file.read(12);
    if (header.length < 8) return null;

    // Check for EBML/MKV/WebM format
    if (header[0] == 0x1A && header[1] == 0x45 && header[2] == 0xDF && header[3] == 0xA3) {
      // For MKV, we need to read enough to get the header and track info
      // In most MKV files, Tracks element is within the first few MB
      await file.setPosition(0);
      final readSize = length.clamp(0, 2 * 1024 * 1024); // Read up to 2MB
      final mkvBytes = await file.read(readSize);
      return MkvParser.parse(Uint8List.fromList(mkvBytes));
    }

    // Check for AVI format (RIFF/AVI)
    if (header.length >= 12 &&
        header[0] == 0x52 &&
        header[1] == 0x49 &&
        header[2] == 0x46 &&
        header[3] == 0x46 && // "RIFF"
        header[8] == 0x41 &&
        header[9] == 0x56 &&
        header[10] == 0x49 &&
        header[11] == 0x20) {
      // "AVI "
      // For AVI, read enough to get all stream headers (typically < 1MB)
      await file.setPosition(0);
      final readSize = length.clamp(0, 1024 * 1024); // Read up to 1MB
      final aviBytes = await file.read(readSize);
      return AviParser.parse(Uint8List.fromList(aviBytes));
    }

    // Check for FLV format
    if (header[0] == 0x46 && header[1] == 0x4C && header[2] == 0x56 && header[3] == 0x01) {
      // For FLV, read enough to find first video/audio tags (typically < 64KB)
      await file.setPosition(0);
      final readSize = length.clamp(0, 64 * 1024); // Read up to 64KB
      final flvBytes = await file.read(readSize);
      return FlvParser.parse(Uint8List.fromList(flvBytes));
    }

    // Check for TS format
    if (header[0] == 0x47 || (header.length >= 5 && header[4] == 0x47)) {
      // For TS, read enough to find PAT/PMT (typically < 64KB)
      await file.setPosition(0);
      final readSize = length.clamp(0, 64 * 1024); // Read up to 64KB
      final tsBytes = await file.read(readSize);
      final tsBytesTyped = Uint8List.fromList(tsBytes);
      if (TsParser.isValidTs(tsBytesTyped)) {
        return TsParser.parse(tsBytesTyped);
      }
    }

    // Parse as MP4/MOV
    // Read ftyp box
    await file.setPosition(0);
    final ftypResult = await _readBoxFromFile(file, length);
    if (ftypResult == null || ftypResult.type != 'ftyp') return null;

    final ftypBytes = ftypResult.bytes;

    // Detect format
    final format = detectFormat(Uint8List.fromList(ftypBytes));
    if (format == null) return null;

    // Find moov box
    final moovLocation = await _findMoovBox(file, length);
    if (moovLocation == null) return null;

    // Read moov box
    await file.setPosition(moovLocation.offset);
    final moovBytes = await file.read(moovLocation.size);
    if (moovBytes.length != moovLocation.size) return null;

    // Combine ftyp + moov into a single buffer for parsing
    // We place them contiguously so the existing parser can work with offsets
    final combinedBytes = Uint8List(ftypBytes.length + moovBytes.length);
    combinedBytes.setRange(0, ftypBytes.length, ftypBytes);
    combinedBytes.setRange(ftypBytes.length, combinedBytes.length, moovBytes);

    // Parse with existing parser
    final reader = Mp4BoxReader(combinedBytes);
    return Mp4Parser.parse(reader, format);
  }

  /// Reads a single box from the file at the current position.
  static Future<_BoxReadResult?> _readBoxFromFile(RandomAccessFile file, int fileLength) async {
    final startPos = await file.position();
    if (startPos + 8 > fileLength) return null;

    final header = await file.read(8);
    if (header.length < 8) return null;

    var size = (header[0] << 24) | (header[1] << 16) | (header[2] << 8) | header[3];
    final type = String.fromCharCodes(header.sublist(4, 8));
    var headerSize = 8;

    if (size == 1) {
      // Extended size (64-bit)
      final extHeader = await file.read(8);
      if (extHeader.length < 8) return null;
      size =
          (extHeader[0] << 56) |
          (extHeader[1] << 48) |
          (extHeader[2] << 40) |
          (extHeader[3] << 32) |
          (extHeader[4] << 24) |
          (extHeader[5] << 16) |
          (extHeader[6] << 8) |
          extHeader[7];
      headerSize = 16;
    } else if (size == 0) {
      // Box extends to end of file
      size = fileLength - startPos;
    }

    if (size < headerSize || startPos + size > fileLength) return null;

    // Read full box
    await file.setPosition(startPos);
    final bytes = await file.read(size);
    if (bytes.length != size) return null;

    return _BoxReadResult(type: type, bytes: bytes, offset: startPos, size: size, headerSize: headerSize);
  }

  /// Finds the moov box location in the file.
  ///
  /// First scans forward from the start (fast-start MP4s).
  /// If not found, scans backwards from the end (standard MP4s).
  static Future<_BoxLocation?> _findMoovBox(RandomAccessFile file, int fileLength) async {
    // First, scan forward from start
    await file.setPosition(0);
    var offset = 0;

    while (offset + 8 <= fileLength) {
      await file.setPosition(offset);
      final header = await file.read(8);
      if (header.length < 8) break;

      var size = (header[0] << 24) | (header[1] << 16) | (header[2] << 8) | header[3];
      final type = String.fromCharCodes(header.sublist(4, 8));
      var headerSize = 8;

      if (size == 1) {
        // Extended size
        final extHeader = await file.read(8);
        if (extHeader.length < 8) break;
        size =
            (extHeader[0] << 56) |
            (extHeader[1] << 48) |
            (extHeader[2] << 40) |
            (extHeader[3] << 32) |
            (extHeader[4] << 24) |
            (extHeader[5] << 16) |
            (extHeader[6] << 8) |
            extHeader[7];
        headerSize = 16;
      } else if (size == 0) {
        size = fileLength - offset;
      }

      if (size < headerSize) break;

      if (type == 'moov') {
        return _BoxLocation(offset: offset, size: size, headerSize: headerSize);
      }

      // Skip large mdat boxes quickly
      if (type == 'mdat' && size > 1024 * 1024) {
        // For very large mdat, try scanning from end
        break;
      }

      offset += size;
    }

    // If moov not found, scan backwards from end
    return _findMoovBoxFromEnd(file, fileLength);
  }

  /// Scans backwards from file end to find moov box.
  ///
  /// This handles the common case of moov at end (after large mdat).
  static Future<_BoxLocation?> _findMoovBoxFromEnd(RandomAccessFile file, int fileLength) async {
    // Read last 64KB to scan for moov
    // Most moov boxes are under 1MB, but we start with a smaller chunk
    const scanSize = 64 * 1024;
    final scanStart = (fileLength - scanSize).clamp(0, fileLength);

    if (scanStart >= fileLength) return null;

    await file.setPosition(scanStart);
    final chunk = await file.read(fileLength - scanStart);

    // Look for 'moov' signature
    for (var i = 0; i < chunk.length - 8; i++) {
      if (chunk[i + 4] == 0x6D && // 'm'
          chunk[i + 5] == 0x6F && // 'o'
          chunk[i + 6] == 0x6F && // 'o'
          chunk[i + 7] == 0x76) {
        // 'v'

        final size = (chunk[i] << 24) | (chunk[i + 1] << 16) | (chunk[i + 2] << 8) | chunk[i + 3];
        final offset = scanStart + i;

        // Validate size
        if (size >= 8 && offset + size <= fileLength) {
          return _BoxLocation(offset: offset, size: size, headerSize: 8);
        }
      }
    }

    // If still not found and file is larger, try a bigger scan
    if (scanStart > 0) {
      const largeScanSize = 1024 * 1024; // 1MB
      final largeScanStart = (fileLength - largeScanSize).clamp(0, fileLength);

      if (largeScanStart < scanStart) {
        await file.setPosition(largeScanStart);
        final largeChunk = await file.read(scanStart - largeScanStart);

        for (var i = 0; i < largeChunk.length - 8; i++) {
          if (largeChunk[i + 4] == 0x6D && // 'm'
              largeChunk[i + 5] == 0x6F && // 'o'
              largeChunk[i + 6] == 0x6F && // 'o'
              largeChunk[i + 7] == 0x76) {
            // 'v'

            final size =
                (largeChunk[i] << 24) | (largeChunk[i + 1] << 16) | (largeChunk[i + 2] << 8) | largeChunk[i + 3];
            final offset = largeScanStart + i;

            if (size >= 8 && offset + size <= fileLength) {
              return _BoxLocation(offset: offset, size: size, headerSize: 8);
            }
          }
        }
      }
    }

    return null;
  }
}

/// Internal result type for box reading.
class _BoxReadResult {
  const _BoxReadResult({
    required this.type,
    required this.bytes,
    required this.offset,
    required this.size,
    required this.headerSize,
  });

  final String type;
  final List<int> bytes;
  final int offset;
  final int size;
  final int headerSize;
}

/// Internal type for box location.
class _BoxLocation {
  const _BoxLocation({required this.offset, required this.size, required this.headerSize});

  final int offset;
  final int size;
  final int headerSize;
}
