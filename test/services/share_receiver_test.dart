import 'package:flutter_test/flutter_test.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:sabicheck/services/share_receiver.dart';

void main() {
  group('PlatformShareReceiver.fromMediaFiles', () {
    test('returns null for an empty share', () {
      expect(PlatformShareReceiver.fromMediaFiles(const []), isNull);
    });

    test('maps shared text', () {
      final c = PlatformShareReceiver.fromMediaFiles([
        SharedMediaFile(path: '  Congratulations you won  ', type: SharedMediaType.text, mimeType: 'text/plain'),
      ]);
      expect(c!.text, 'Congratulations you won');
      expect(c.imagePath, isNull);
    });

    test('maps a shared URL as text', () {
      final c = PlatformShareReceiver.fromMediaFiles([
        SharedMediaFile(path: 'https://bit.ly/claim-prize', type: SharedMediaType.url),
      ]);
      expect(c!.text, 'https://bit.ly/claim-prize');
    });

    test('first image wins; text items are concatenated; videos ignored', () {
      final c = PlatformShareReceiver.fromMediaFiles([
        SharedMediaFile(path: '/tmp/vid.mp4', type: SharedMediaType.video, mimeType: 'video/mp4'),
        SharedMediaFile(path: '/tmp/one.jpg', type: SharedMediaType.image, mimeType: 'image/jpeg'),
        SharedMediaFile(path: '/tmp/two.png', type: SharedMediaType.image, mimeType: 'image/png'),
        SharedMediaFile(path: 'line one', type: SharedMediaType.text),
        SharedMediaFile(path: 'line two', type: SharedMediaType.text),
      ]);
      expect(c!.imagePath, '/tmp/one.jpg');
      expect(c.imageMimeType, 'image/jpeg');
      expect(c.text, 'line one\nline two');
    });

    test('includes an iOS caption once', () {
      final c = PlatformShareReceiver.fromMediaFiles([
        SharedMediaFile(path: '/tmp/shot.png', type: SharedMediaType.image, mimeType: 'image/png', message: 'is this real?'),
        SharedMediaFile(path: 'is this real?', type: SharedMediaType.text, message: 'is this real?'),
      ]);
      expect(c!.text, 'is this real?');
      expect(c.imagePath, '/tmp/shot.png');
    });

    test('a share with only unsupported files is treated as empty', () {
      final c = PlatformShareReceiver.fromMediaFiles([
        SharedMediaFile(path: '/tmp/doc.pdf', type: SharedMediaType.file, mimeType: 'application/pdf'),
      ]);
      expect(c, isNull);
    });
  });

  test('NoopShareReceiver never yields content', () async {
    const r = NoopShareReceiver();
    expect(await r.initialContent(), isNull);
    expect(await r.stream.isEmpty, isTrue);
  });
}
