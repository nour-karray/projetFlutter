import 'dart:typed_data';
import 'dart:ui' as ui;

/// Miniature pour l historique (evite de saturer SharedPreferences).
Future<Uint8List?> encodeThumbnailPng(Uint8List imageBytes, {int maxWidth = 320}) async {
  try {
    final codec = await ui.instantiateImageCodec(
      imageBytes,
      targetWidth: maxWidth,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final bd = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bd?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}
