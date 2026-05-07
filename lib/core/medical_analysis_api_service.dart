import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

String? _cleanNullable(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
    return null;
  }
  return text;
}

class MedicalAnalysisRow {
  const MedicalAnalysisRow({
    required this.analyse,
    required this.valeur,
    required this.unite,
  });

  final String analyse;
  final String? valeur;
  final String? unite;

  factory MedicalAnalysisRow.fromJson(Map<String, dynamic> json) {
    return MedicalAnalysisRow(
      analyse: (json['analyse'] ?? '').toString(),
      valeur: _cleanNullable(json['valeur']),
      unite: _cleanNullable(json['unite']),
    );
  }
}

class PatientMedecinInfo {
  const PatientMedecinInfo({
    required this.nomPatient,
    required this.nomMedecinDemandeur,
    required this.date,
  });

  final String? nomPatient;
  final String? nomMedecinDemandeur;
  final String? date;

  factory PatientMedecinInfo.fromJson(Map<String, dynamic> json) {
    return PatientMedecinInfo(
      nomPatient: _cleanNullable(json['nom_patient']),
      nomMedecinDemandeur: _cleanNullable(json['nom_medecin_demandeur']),
      date: _cleanNullable(json['date']),
    );
  }
}

class MedicalStructuredExtractionResult {
  const MedicalStructuredExtractionResult({
    required this.documentType,
    required this.patientMedecin,
    required this.resultatsAnalyses,
  });

  final String documentType;
  final PatientMedecinInfo patientMedecin;
  final List<MedicalAnalysisRow> resultatsAnalyses;

  factory MedicalStructuredExtractionResult.fromJson(Map<String, dynamic> json) {
    final patientRaw = json['patient_medecin'];
    final rowsRaw = json['resultats_analyses'];
    final rows = rowsRaw is List
        ? rowsRaw
              .whereType<Map>()
              .map((row) => MedicalAnalysisRow.fromJson(Map<String, dynamic>.from(row)))
              .where((row) => row.analyse.trim().isNotEmpty)
              .toList(growable: false)
        : const <MedicalAnalysisRow>[];

    return MedicalStructuredExtractionResult(
      documentType: (json['document_type'] ?? 'analyse_medicale').toString(),
      patientMedecin: PatientMedecinInfo.fromJson(
        patientRaw is Map<String, dynamic> ? patientRaw : const <String, dynamic>{},
      ),
      resultatsAnalyses: rows,
    );
  }
}

class MedicalAnalysisApiService {
  MedicalAnalysisApiService({
    required String geminiApiKey,
    String? backendBaseUrl,
  })  : _geminiApiKey = geminiApiKey.trim(),
        _backendBaseUrl = (backendBaseUrl ?? _defaultBackendBaseUrl()).trim();

  final String _geminiApiKey;
  final String _backendBaseUrl;

  bool get isConfigured => _geminiApiKey.isNotEmpty;

  Future<MedicalStructuredExtractionResult> extractMedicalAnalysisWithGemini({
    required String ocrText,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    if (!isConfigured) {
      throw Exception('Cle API Gemini manquante. Ajoute-la dans Parametres.');
    }
    if (ocrText.trim().isEmpty && (fileBytes == null || fileBytes.isEmpty)) {
      throw Exception('Aucune donnee exploitable envoyee au backend.');
    }

    final uri = Uri.parse('$_backendBaseUrl/api/extract-medical-analysis');
    final request = http.MultipartRequest('POST', uri)
      ..headers['X-Gemini-Api-Key'] = _geminiApiKey
      ..fields['ocr_text'] = ocrText;

    if (fileBytes != null && fileBytes.isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName ?? 'document.bin',
        ),
      );
    }

    final streamed = await request.send().timeout(const Duration(seconds: 70));
    final response = await http.Response.fromStream(streamed);
    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw Exception('Reponse backend invalide.');
    }
    if (response.statusCode != 200 || payload['success'] != true) {
      throw Exception((payload['error'] ?? 'Echec extraction medicale.').toString());
    }
    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Structure JSON de sortie invalide.');
    }
    return MedicalStructuredExtractionResult.fromJson(data);
  }

  static String _defaultBackendBaseUrl() {
    if (kIsWeb) return 'http://localhost:5000';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:5000';
      default:
        return 'http://localhost:5000';
    }
  }
}
