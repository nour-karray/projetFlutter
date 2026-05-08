import 'package:flutter/foundation.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class MlKitLanguageResult {
  const MlKitLanguageResult({
    required this.primaryCode,
    required this.rankedCodes,
  });

  final String primaryCode;
  final List<String> rankedCodes;
}

class MlKitLanguageService {
  bool get isSupportedPlatform => !kIsWeb;

  Future<MlKitLanguageResult?> detect(String text) async {
    final input = text.trim();
    if (input.isEmpty || !isSupportedPlatform) return null;

    final languageIdentifier = LanguageIdentifier(confidenceThreshold: 0.35);
    try {
      final ranked = await languageIdentifier.identifyPossibleLanguages(input);
      final normalized = ranked
          .map((e) => e.languageTag.toLowerCase())
          .where((code) => code != 'und')
          .map(_normalizeCode)
          .where((code) => code.isNotEmpty)
          .toSet()
          .toList(growable: false);

      if (normalized.isEmpty) return null;
      return MlKitLanguageResult(
        primaryCode: normalized.first,
        rankedCodes: normalized,
      );
    } catch (_) {
      return null;
    } finally {
      await languageIdentifier.close();
    }
  }

  Future<String> translateTo({
    required String text,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) async {
    if (!isSupportedPlatform) return text;
    final source = TranslateLanguage.values.firstWhere(
      (l) => l.bcpCode == sourceLanguageCode,
      orElse: () => TranslateLanguage.english,
    );
    final target = TranslateLanguage.values.firstWhere(
      (l) => l.bcpCode == targetLanguageCode,
      orElse: () => TranslateLanguage.french,
    );
    final translator = OnDeviceTranslator(
      sourceLanguage: source,
      targetLanguage: target,
    );
    try {
      return await translator.translateText(text);
    } finally {
      await translator.close();
    }
  }

  Future<List<String>> translateBatch({
    required List<String> texts,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) async {
    if (!isSupportedPlatform || texts.isEmpty) return texts;
    final source = TranslateLanguage.values.firstWhere(
      (l) => l.bcpCode == sourceLanguageCode,
      orElse: () => TranslateLanguage.english,
    );
    final target = TranslateLanguage.values.firstWhere(
      (l) => l.bcpCode == targetLanguageCode,
      orElse: () => TranslateLanguage.french,
    );
    final translator = OnDeviceTranslator(
      sourceLanguage: source,
      targetLanguage: target,
    );
    try {
      final out = <String>[];
      for (final text in texts) {
        if (text.trim().isEmpty) {
          out.add(text);
        } else {
          out.add(await translator.translateText(text));
        }
      }
      return out;
    } finally {
      await translator.close();
    }
  }

  String _normalizeCode(String rawCode) {
    if (rawCode.startsWith('fr')) return 'fr';
    if (rawCode.startsWith('en')) return 'en';
    if (rawCode.startsWith('ar')) return 'ar';
    return rawCode.split('-').first;
  }
}
