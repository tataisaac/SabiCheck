import 'dart:convert';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'sabicheck_api.dart';

/// An image chosen by the user (gallery, camera, or share sheet), held in memory
/// so the same code path works on mobile *and* web (no dart:io).
@immutable
class PickedImage {
  const PickedImage({required this.bytes, required this.mimeType, required this.name});

  final Uint8List bytes;
  final String mimeType;
  final String name;

  int get sizeBytes => bytes.length;

  ImagePayload toPayload() => ImagePayload(mimeType: mimeType, base64Data: base64Encode(bytes));
}

class ImageTooLargeException implements Exception {
  const ImageTooLargeException(this.sizeBytes);
  final int sizeBytes;
}

class UnsupportedImageException implements Exception {
  const UnsupportedImageException(this.mimeType);
  final String? mimeType;
}

/// Reads and sanity-checks an image file. Backend accepts jpeg/png/webp/heic/heif.
class ImageLoader {
  const ImageLoader();

  static const supportedMimeTypes = {'image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif'};

  Future<PickedImage> load(XFile file, {String? mimeTypeHint}) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > AppConfig.maxImageBytes) throw ImageTooLargeException(bytes.length);
    final mime = _resolveMime(file, mimeTypeHint, bytes);
    if (!supportedMimeTypes.contains(mime)) throw UnsupportedImageException(mime);
    return PickedImage(bytes: bytes, mimeType: mime, name: file.name.isEmpty ? 'image' : file.name);
  }

  static String? _resolveMime(XFile file, String? hint, Uint8List bytes) {
    final candidates = [file.mimeType, hint];
    for (final c in candidates) {
      final n = _normalize(c);
      if (n != null && supportedMimeTypes.contains(n)) return n;
    }
    final sniffed = sniffMime(bytes);
    if (sniffed != null) return sniffed;
    return _fromExtension(file.name.isNotEmpty ? file.name : file.path);
  }

  static String? _normalize(String? mime) {
    if (mime == null) return null;
    final m = mime.toLowerCase().split(';').first.trim();
    return switch (m) {
      'image/jpg' || 'image/pjpeg' => 'image/jpeg',
      _ => m,
    };
  }

  /// Magic-number sniffing — share sheets often hand us files with no MIME type.
  @visibleForTesting
  static String? sniffMime(Uint8List b) {
    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'image/jpeg';
    if (b.length >= 8 &&
        b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47 &&
        b[4] == 0x0D && b[5] == 0x0A && b[6] == 0x1A && b[7] == 0x0A) {
      return 'image/png';
    }
    if (b.length >= 12 &&
        b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 &&
        b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) {
      return 'image/webp';
    }
    if (b.length >= 12 && b[4] == 0x66 && b[5] == 0x74 && b[6] == 0x79 && b[7] == 0x70) {
      final brand = String.fromCharCodes(b.sublist(8, 12)).toLowerCase();
      if (brand.startsWith('hei') || brand.startsWith('mif')) return 'image/heic';
    }
    return null;
  }

  static String? _fromExtension(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    return null;
  }
}
