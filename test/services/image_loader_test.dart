import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabicheck/services/image_loader.dart';

Uint8List _png() => Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3, 4]);
Uint8List _jpeg() => Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0]);
Uint8List _webp() => Uint8List.fromList([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, 0]);
Uint8List _heic() => Uint8List.fromList([0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63, 0]);

void main() {
  const loader = ImageLoader();

  group('ImageLoader.sniffMime', () {
    test('detects png / jpeg / webp / heic by magic bytes', () {
      expect(ImageLoader.sniffMime(_png()), 'image/png');
      expect(ImageLoader.sniffMime(_jpeg()), 'image/jpeg');
      expect(ImageLoader.sniffMime(_webp()), 'image/webp');
      expect(ImageLoader.sniffMime(_heic()), 'image/heic');
      expect(ImageLoader.sniffMime(Uint8List.fromList([1, 2, 3])), isNull);
    });
  });

  group('ImageLoader.load', () {
    test('uses the declared mime type when supported', () async {
      final img = await loader.load(XFile.fromData(_png(), mimeType: 'image/png', name: 'shot.png'));
      expect(img.mimeType, 'image/png');
      expect(img.name, 'shot.png');
      expect(img.sizeBytes, 12);
    });

    test('normalises image/jpg to image/jpeg', () async {
      final img = await loader.load(XFile.fromData(_jpeg(), mimeType: 'image/jpg', name: 'a.jpg'));
      expect(img.mimeType, 'image/jpeg');
    });

    test('falls back to sniffing when the mime type is missing (share sheet case)', () async {
      final img = await loader.load(XFile.fromData(_jpeg(), name: 'whatever'));
      expect(img.mimeType, 'image/jpeg');
    });

    test('honours a hint from the share receiver', () async {
      final img = await loader.load(XFile.fromData(Uint8List.fromList([9, 9, 9]), name: 'x'), mimeTypeHint: 'image/webp');
      expect(img.mimeType, 'image/webp');
    });

    test('falls back to the file extension as a last resort', () async {
      final img = await loader.load(XFile.fromData(Uint8List.fromList([9, 9, 9]), name: 'photo.PNG'));
      expect(img.mimeType, 'image/png');
    });

    test('rejects unsupported types', () async {
      await expectLater(
        loader.load(XFile.fromData(Uint8List.fromList([0x47, 0x49, 0x46]), mimeType: 'image/gif', name: 'a.gif')),
        throwsA(isA<UnsupportedImageException>()),
      );
    });

    test('rejects files over the size cap', () async {
      final big = Uint8List(5 * 1024 * 1024 + 1);
      big.setRange(0, 8, _png());
      await expectLater(
        loader.load(XFile.fromData(big, mimeType: 'image/png', name: 'big.png')),
        throwsA(isA<ImageTooLargeException>()),
      );
    });

    test('toPayload base64-encodes the bytes', () async {
      final img = await loader.load(XFile.fromData(_png(), mimeType: 'image/png', name: 'p.png'));
      final payload = img.toPayload();
      expect(payload.mimeType, 'image/png');
      expect(payload.base64Data, 'iVBORw0KGgoBAgME');
    });
  });
}
