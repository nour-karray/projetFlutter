import '../models/medical_report.dart';
import '../utils/medical_dictionary.dart';

class DocumentDetectionResult {
  const DocumentDetectionResult({
    required this.documentType,
    required this.medicalScore,
    required this.threshold,
  });

  final DocumentType documentType;
  final double medicalScore;
  final double threshold;
}

class DocumentClassifierService {
  const DocumentClassifierService({this.medicalThreshold = 0.20});

  final double medicalThreshold;

  DocumentDetectionResult detectDocumentType(String ocrText) {
    final normalized = _normalize(ocrText);
    if (normalized.isEmpty) {
      return DocumentDetectionResult(
        documentType: DocumentType.unknown,
        medicalScore: 0,
        threshold: medicalThreshold,
      );
    }

    var matches = 0;
    for (final keyword in MedicalDictionary.medicalKeywords) {
      if (normalized.contains(keyword)) {
        matches++;
      }
    }
    final keywordScore = matches / MedicalDictionary.medicalKeywords.length;

    // Heuristic signal: many "value + unit" patterns strongly indicate lab results.
    final numericUnitMatches = RegExp(
      r'\b\d{1,4}(?:[.,]\d{1,3})?\s*(mg/dl|g/l|g/dl|mmol/l|ui/l|mui/l|ng/ml|pg/ml|fl|/mm3|10\^?\d+/l)\b',
      caseSensitive: false,
    ).allMatches(normalized).length;
    final unitDensityScore = (numericUnitMatches / 6).clamp(0, 1).toDouble();

    final headerSignal =
        normalized.contains('resultat') ||
        normalized.contains('analyse') ||
        normalized.contains('laboratoire');
    final headerBoost = headerSignal ? 0.10 : 0.0;

    final score =
        (keywordScore * 0.75) + (unitDensityScore * 0.25) + headerBoost;

    return DocumentDetectionResult(
      documentType: score >= medicalThreshold
          ? DocumentType.medicalReport
          : DocumentType.unknown,
      medicalScore: score,
      threshold: medicalThreshold,
    );
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[àâ]'), 'a')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ûü]'), 'u')
        .replaceAll(RegExp(r'[^a-z0-9\s/-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
