import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class GuidedPhotoResult {
  const GuidedPhotoResult({
    required this.bytes,
    required this.path,
    required this.brightnessScore,
    required this.focusScore,
    required this.wasCropped,
    required this.qualityWarnings,
  });

  final Uint8List bytes;
  final String path;
  final double brightnessScore;
  final double focusScore;
  final bool wasCropped;
  final List<String> qualityWarnings;

  bool get hasWarning => qualityWarnings.isNotEmpty;
}

class GuidedPhotoPreprocessor {
  Future<GuidedPhotoResult> process({
    required Uint8List bytes,
    required String originalPath,
    required String fileName,
  }) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return GuidedPhotoResult(
        bytes: bytes,
        path: originalPath,
        brightnessScore: 0,
        focusScore: 0,
        wasCropped: false,
        qualityWarnings: const ['Image illisible'],
      );
    }

    final brightness = _estimateBrightness(decoded);
    final focus = _estimateFocus(decoded);
    final warnings = <String>[];
    if (brightness < 75) warnings.add('Image trop sombre');
    if (brightness > 205) warnings.add('Image surexposee');
    if (focus < 18) warnings.add('Image floue');

    var working = decoded;
    var cropped = false;
    final cropRect = _detectDocumentRect(decoded);
    if (cropRect != null) {
      final w = cropRect[2];
      final h = cropRect[3];
      if (w > 100 && h > 100) {
        working = img.copyCrop(decoded, x: cropRect[0], y: cropRect[1], width: w, height: h);
        cropped = true;
      }
    }

    final encoded = Uint8List.fromList(img.encodeJpg(working, quality: 92));
    final outPath = await _persistTempJpg(encoded, fileName);
    return GuidedPhotoResult(
      bytes: encoded,
      path: outPath ?? originalPath,
      brightnessScore: brightness,
      focusScore: focus,
      wasCropped: cropped,
      qualityWarnings: warnings,
    );
  }

  double _estimateBrightness(img.Image image) {
    final stepX = math.max(1, image.width ~/ 120);
    final stepY = math.max(1, image.height ~/ 120);
    var total = 0.0;
    var count = 0;
    for (var y = 0; y < image.height; y += stepY) {
      for (var x = 0; x < image.width; x += stepX) {
        final p = image.getPixel(x, y);
        final lum = (0.2126 * p.r) + (0.7152 * p.g) + (0.0722 * p.b);
        total += lum;
        count++;
      }
    }
    if (count == 0) return 0;
    return total / count;
  }

  double _estimateFocus(img.Image image) {
    final gray = img.grayscale(image);
    if (gray.width < 3 || gray.height < 3) return 0;

    final stepX = math.max(1, gray.width ~/ 220);
    final stepY = math.max(1, gray.height ~/ 220);
    var sum = 0.0;
    var count = 0;

    for (var y = 1; y < gray.height - 1; y += stepY) {
      for (var x = 1; x < gray.width - 1; x += stepX) {
        final left = gray.getPixel(x - 1, y).r;
        final right = gray.getPixel(x + 1, y).r;
        final up = gray.getPixel(x, y - 1).r;
        final down = gray.getPixel(x, y + 1).r;
        final gx = (right - left).abs();
        final gy = (down - up).abs();
        sum += (gx + gy) * 0.5;
        count++;
      }
    }
    if (count == 0) return 0;
    return sum / count;
  }

  List<int>? _detectDocumentRect(img.Image image) {
    final stepX = math.max(1, image.width ~/ 300);
    final stepY = math.max(1, image.height ~/ 300);
    var minX = image.width;
    var minY = image.height;
    var maxX = 0;
    var maxY = 0;
    var hitCount = 0;

    for (var y = 0; y < image.height; y += stepY) {
      for (var x = 0; x < image.width; x += stepX) {
        final p = image.getPixel(x, y);
        final lum = (0.2126 * p.r) + (0.7152 * p.g) + (0.0722 * p.b);
        if (lum < 240) {
          hitCount++;
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
        }
      }
    }

    if (hitCount < 200) return null;
    if (maxX <= minX || maxY <= minY) return null;

    final width = maxX - minX;
    final height = maxY - minY;
    final areaRatio = (width * height) / (image.width * image.height);
    if (areaRatio > 0.95) return null;
    if (areaRatio < 0.15) return null;

    final padX = math.max(4, (width * 0.04).round());
    final padY = math.max(4, (height * 0.04).round());

    final x = math.max(0, minX - padX);
    final y = math.max(0, minY - padY);
    final w = math.min(image.width - x, width + (padX * 2));
    final h = math.min(image.height - y, height + (padY * 2));
    return [x, y, w, h];
  }

  Future<String?> _persistTempJpg(Uint8List bytes, String fileName) async {
    try {
      final dir = await getTemporaryDirectory();
      final stem = p.basenameWithoutExtension(fileName).replaceAll(RegExp(r'\s+'), '_');
      final outputName = '${stem}_guided_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final outFile = File(p.join(dir.path, outputName));
      await outFile.writeAsBytes(bytes, flush: true);
      return outFile.path;
    } catch (_) {
      return null;
    }
  }
}
