import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Content pushed into SabiCheck from another app via the share sheet.
@immutable
class SharedContent {
  const SharedContent({this.text, this.imagePath, this.imageMimeType});

  final String? text;
  final String? imagePath;
  final String? imageMimeType;

  bool get isEmpty => (text == null || text!.trim().isEmpty) && imagePath == null;

  @override
  String toString() => 'SharedContent(text: ${text?.length} chars, image: $imagePath)';
}

/// Abstraction over the platform share channel so the app can be tested and
/// so the web build (no share-sheet support) gets a no-op.
abstract class ShareReceiver {
  /// Content the app was *launched* with (cold start from the share sheet).
  Future<SharedContent?> initialContent();

  /// Content shared while the app is already running (warm share).
  Stream<SharedContent> get stream;

  /// Mark the initial content as consumed so it is not re-delivered.
  Future<void> reset();
}

class NoopShareReceiver implements ShareReceiver {
  const NoopShareReceiver();

  @override
  Future<SharedContent?> initialContent() async => null;

  @override
  Stream<SharedContent> get stream => const Stream.empty();

  @override
  Future<void> reset() async {}
}

/// Real implementation on Android/iOS via `receive_sharing_intent`.
class PlatformShareReceiver implements ShareReceiver {
  PlatformShareReceiver({ReceiveSharingIntent? plugin}) : _plugin = plugin ?? ReceiveSharingIntent.instance;

  final ReceiveSharingIntent _plugin;

  @override
  Future<SharedContent?> initialContent() async {
    try {
      final files = await _plugin.getInitialMedia();
      return fromMediaFiles(files);
    } catch (e) {
      debugPrint('share: getInitialMedia failed: $e');
      return null;
    }
  }

  @override
  Stream<SharedContent> get stream => _plugin
      .getMediaStream()
      .map(fromMediaFiles)
      .where((c) => c != null)
      .cast<SharedContent>()
      .handleError((Object e) => debugPrint('share: stream error: $e'));

  @override
  Future<void> reset() async {
    try {
      await _plugin.reset();
    } catch (_) {}
  }

  /// Merge a share payload into one [SharedContent]: all text/url items are
  /// concatenated, the first image wins (multi-image shares analyze the first).
  @visibleForTesting
  static SharedContent? fromMediaFiles(List<SharedMediaFile> files) {
    if (files.isEmpty) return null;
    final textParts = <String>[];
    String? imagePath;
    String? imageMime;
    for (final f in files) {
      switch (f.type) {
        case SharedMediaType.text:
        case SharedMediaType.url:
          if (f.path.trim().isNotEmpty) textParts.add(f.path.trim());
        case SharedMediaType.image:
          imagePath ??= f.path;
          imageMime ??= f.mimeType;
        case SharedMediaType.video:
        case SharedMediaType.file:
          // Not supported for analysis; ignore.
          break;
      }
      // iOS share extension can attach a typed caption.
      final msg = f.message;
      if (msg != null && msg.trim().isNotEmpty && !textParts.contains(msg.trim())) {
        textParts.add(msg.trim());
      }
    }
    final content = SharedContent(
      text: textParts.isEmpty ? null : textParts.join('\n'),
      imagePath: imagePath,
      imageMimeType: imageMime,
    );
    return content.isEmpty ? null : content;
  }
}
