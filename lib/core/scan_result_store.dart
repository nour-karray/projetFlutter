import 'package:flutter/foundation.dart';
import '../models/medical_report.dart';

class ScanResultStore extends ChangeNotifier {
  String? imagePath;
  Uint8List? imageBytes;
  String? extractedText;
  MedicalReport? medicalReport;
  String detectedLanguageCode = 'unknown';
  List<String> detectedLanguageCodes = const ['unknown'];
  bool isProcessing = false;
  String? errorMessage;

  bool get hasResult => extractedText != null && extractedText!.trim().isNotEmpty;

  void startProcessing(String path, {required Uint8List bytes}) {
    imagePath = path;
    imageBytes = bytes;
    extractedText = null;
    medicalReport = null;
    detectedLanguageCode = 'unknown';
    detectedLanguageCodes = const ['unknown'];
    isProcessing = true;
    errorMessage = null;
    notifyListeners();
  }

  void complete(
    String text, {
    required String languageCode,
    required List<String> languageCodes,
    MedicalReport? report,
  }) {
    extractedText = text;
    medicalReport = report;
    detectedLanguageCode = languageCode;
    detectedLanguageCodes = languageCodes.isEmpty ? const ['unknown'] : languageCodes;
    isProcessing = false;
    errorMessage = null;
    notifyListeners();
  }

  void fail(String message) {
    extractedText = null;
    medicalReport = null;
    detectedLanguageCode = 'unknown';
    detectedLanguageCodes = const ['unknown'];
    isProcessing = false;
    errorMessage = message;
    notifyListeners();
  }

  void updateMedicalReport(MedicalReport report) {
    medicalReport = report;
    notifyListeners();
  }

  void loadFromHistory({
    required String text,
    required List<String> languageCodes,
    MedicalReport? report,
    Uint8List? bytes,
  }) {
    imagePath = null;
    imageBytes = bytes;
    extractedText = text;
    medicalReport = report;
    final langs = languageCodes.isEmpty ? const ['unknown'] : languageCodes;
    detectedLanguageCodes = langs;
    detectedLanguageCode = langs.first;
    isProcessing = false;
    errorMessage = null;
    notifyListeners();
  }
}
