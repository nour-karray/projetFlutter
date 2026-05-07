import '../core/medical_ocr_postprocessor.dart';
import '../models/medical_report.dart';
import '../parsers/medical_report_parser.dart';
import 'document_classifier_service.dart';

class MedicalReportPipelineService {
  MedicalReportPipelineService({
    DocumentClassifierService? classifier,
    MedicalReportParser? parser,
  })  : _classifier = classifier ?? const DocumentClassifierService(),
        _parser = parser ?? const MedicalReportParser();

  final DocumentClassifierService _classifier;
  final MedicalReportParser _parser;

  MedicalReport parseFromRawText({
    required String sourceFileName,
    required String rawOcrText,
  }) {
    final normalizedText = MedicalOcrPostprocessor.normalizeForAi(rawOcrText);
    final detection = _classifier.detectDocumentType(normalizedText);
    final parsed = _parser.parse(
      sourceFileName: sourceFileName,
      rawText: normalizedText,
      documentType: detection.documentType,
      confidence: detection.medicalScore,
    );
    final totalAnalyses = parsed.sections.fold<int>(0, (sum, section) => sum + section.analyses.length);
    if (parsed.documentType == DocumentType.unknown && totalAnalyses >= 2) {
      // Parser evidence is strong enough to reclassify as medical.
      return parsed.copyWith(
        documentType: DocumentType.medicalReport,
        confidence: parsed.confidence < 0.35 ? 0.35 : parsed.confidence,
      );
    }
    return parsed;
  }
}
