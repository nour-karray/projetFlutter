import 'dart:convert';

import 'package:http/http.dart' as http;

import 'medical_ocr_postprocessor.dart';

class MedicalFinding {
  const MedicalFinding({
    required this.testName,
    required this.value,
    required this.unit,
    required this.reference,
    required this.status,
    required this.notes,
  });

  final String testName;
  final String value;
  final String unit;
  final String reference;
  final String status;
  final String notes;

  factory MedicalFinding.fromJson(Map<String, dynamic> json) {
    return MedicalFinding(
      testName: (json['testName'] ?? '').toString(),
      value: (json['value'] ?? '').toString(),
      unit: (json['unit'] ?? '').toString(),
      reference: (json['reference'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
    );
  }
}

class MedicalAnalysisResult {
  const MedicalAnalysisResult({
    required this.summary,
    required this.importantFindings,
    required this.recommendations,
    required this.disclaimer,
  });

  final String summary;
  final List<MedicalFinding> importantFindings;
  final String recommendations;
  final String disclaimer;

  factory MedicalAnalysisResult.fromJson(Map<String, dynamic> json) {
    final findingsRaw = json['importantFindings'];
    final findings = findingsRaw is List
        ? findingsRaw
              .whereType<Map>()
              .map((e) => MedicalFinding.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false)
        : const <MedicalFinding>[];

    return MedicalAnalysisResult(
      summary: (json['summary'] ?? '').toString(),
      importantFindings: findings,
      recommendations: (json['recommendations'] ?? '').toString(),
      disclaimer: (json['disclaimer'] ?? '').toString(),
    );
  }
}

class MedicalReportAiExtraction {
  const MedicalReportAiExtraction({
    required this.patientName,
    required this.requesterDoctor,
    required this.validatorDoctor,
    required this.codePatient,
    required this.organism,
    required this.confidence,
  });

  final String? patientName;
  final String? requesterDoctor;
  final String? validatorDoctor;
  final String? codePatient;
  final String? organism;
  final double confidence;

  factory MedicalReportAiExtraction.fromJson(Map<String, dynamic> json) {
    return MedicalReportAiExtraction(
      patientName: MedicalAiService._cleanNullable(json['patientName']),
      requesterDoctor: MedicalAiService._cleanNullable(json['requesterDoctor']),
      validatorDoctor: MedicalAiService._cleanNullable(json['validatorDoctor']),
      codePatient: MedicalAiService._cleanNullable(json['codePatient']),
      organism: MedicalAiService._cleanNullable(json['organism']),
      confidence: ((json['confidence'] ?? 0.0) as num).toDouble(),
    );
  }
}

class MedicalAiService {
  MedicalAiService({required String apiKey, String model = 'gemini-2.5-flash'})
    : _apiKey = apiKey.trim(),
      _model = model;

  final String _apiKey;
  final String _model;
  static const List<String> _fallbackModels = <String>[
    'gemini-2.5-flash',
    'gemini-2.0-flash',
  ];

  bool get isConfigured => _apiKey.trim().isNotEmpty;

  Future<MedicalAnalysisResult> analyzeMedicalText(String reportText) async {
    if (!isConfigured) {
      throw Exception('Cle API Gemini manquante. Ajoute-la dans Parametres.');
    }
    final preparedText = MedicalOcrPostprocessor.normalizeForAi(reportText);
    if (preparedText.trim().isEmpty) {
      throw Exception('Aucun texte a analyser.');
    }

    final prompt =
        '''
Tu es un assistant d extraction d informations medicales.
Analyse le texte OCR d un bilan medical et retourne UNIQUEMENT un JSON valide sans markdown.
Ignore les artefacts OCR evidents (espaces parasites, O/0, I/1, erreurs ponctuation), mais n invente aucune valeur.

Format JSON attendu:
{
  "summary": "resume en 3-5 lignes",
  "importantFindings": [
    {
      "testName": "nom du test",
      "value": "valeur",
      "unit": "unite",
      "reference": "intervalle/borne de reference",
      "status": "normal|low|high|unknown",
      "notes": "commentaire court"
    }
  ],
  "recommendations": "conseils de suivi non diagnostiques",
  "disclaimer": "ceci n est pas un diagnostic medical"
}

Texte OCR du rapport:
$preparedText
''';

    final modelsToTry = <String>{_model, ..._fallbackModels};
    Object? lastError;

    for (final model in modelsToTry) {
      try {
        return await _requestWithRetry(model: model, prompt: prompt);
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception(
      'Echec analyse Gemini (modeles testes: ${modelsToTry.join(', ')}). '
      'Details: $lastError',
    );
  }

  Future<MedicalReportAiExtraction> extractMedicalReportEntities(
    String reportText,
  ) async {
    if (!isConfigured) {
      throw Exception('Cle API Gemini manquante. Ajoute-la dans Parametres.');
    }
    final preparedText = MedicalOcrPostprocessor.normalizeForAi(reportText);
    if (preparedText.trim().isEmpty) {
      throw Exception('Aucun texte a analyser.');
    }

    final prompt =
        '''
Tu es un extracteur d informations medicales.
Tu recois un texte OCR d'un bilan biologique et tu dois extraire les champs suivants.
Retourne UNIQUEMENT un JSON valide, sans markdown.

JSON attendu:
{
  "patientName": "nom complet patient ou null",
  "requesterDoctor": "medecin demandeur ou null",
  "validatorDoctor": "medecin validateur/biologiste ou null",
  "codePatient": "code patient ou null",
  "organism": "organisme/assurance ou null",
  "confidence": 0.0
}

Regles:
- si champ absent, mets null
- n'invente rien
- confidence entre 0 et 1
- Corrige uniquement les erreurs OCR evidentes (O/0, I/1, espaces coupes).
- Si plusieurs candidats existent, choisis la valeur la plus explicite.

Texte OCR:
$preparedText
''';

    final modelsToTry = <String>{_model, ..._fallbackModels};
    Object? lastError;
    for (final model in modelsToTry) {
      try {
        final response = await _requestJsonWithRetry(
          model: model,
          prompt: prompt,
        );
        return MedicalReportAiExtraction.fromJson(response);
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception(
      'Echec extraction Gemini (modeles testes: ${modelsToTry.join(', ')}). Details: $lastError',
    );
  }

  Future<MedicalAnalysisResult> _requestWithRetry({
    required String model,
    required String prompt,
  }) async {
    const maxAttempts = 3;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final response = await _postGenerateContent(model: model, prompt: prompt);

      if (response.statusCode == 200) {
        return _parseResponse(response.body);
      }

      final isRetriable =
          response.statusCode == 429 ||
          response.statusCode == 500 ||
          response.statusCode == 503;

      if (!isRetriable || attempt == maxAttempts) {
        throw Exception(
          'Erreur Gemini HTTP ${response.statusCode} (model=$model): ${response.body}',
        );
      }

      final delayMs = attempt * 1200;
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }

    throw Exception('Echec inattendu lors de la requete Gemini.');
  }

  Future<Map<String, dynamic>> _requestJsonWithRetry({
    required String model,
    required String prompt,
  }) async {
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final response = await _postGenerateContent(model: model, prompt: prompt);
      if (response.statusCode == 200) {
        return _parseJsonMap(response.body);
      }
      final isRetriable =
          response.statusCode == 429 ||
          response.statusCode == 500 ||
          response.statusCode == 503;
      if (!isRetriable || attempt == maxAttempts) {
        throw Exception(
          'Erreur Gemini HTTP ${response.statusCode} (model=$model): ${response.body}',
        );
      }
      await Future<void>.delayed(Duration(milliseconds: attempt * 1200));
    }
    throw Exception('Echec inattendu lors de la requete Gemini.');
  }

  Future<http.Response> _postGenerateContent({
    required String model,
    required String prompt,
  }) {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_apiKey',
    );

    return http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt},
                ],
              },
            ],
            'generationConfig': {
              'temperature': 0.1,
              'responseMimeType': 'application/json',
            },
          }),
        )
        .timeout(const Duration(seconds: 35));
  }

  MedicalAnalysisResult _parseResponse(String responseBody) {
    final parsed = _parseJsonMap(responseBody);
    return MedicalAnalysisResult.fromJson(parsed);
  }

  Map<String, dynamic> _parseJsonMap(String responseBody) {
    final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw Exception('Reponse Gemini invalide: aucun candidat.');
    }
    final first = candidates.first;
    if (first is! Map<String, dynamic>) {
      throw Exception('Reponse Gemini invalide.');
    }
    final content = first['content'];
    if (content is! Map<String, dynamic>) {
      throw Exception('Reponse Gemini invalide (content).');
    }
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) {
      throw Exception('Reponse Gemini invalide (parts).');
    }

    final rawText = parts
        .whereType<Map>()
        .map((part) => (part['text'] ?? '').toString())
        .join('\n')
        .trim();
    if (rawText.isEmpty) {
      throw Exception('Reponse vide de Gemini.');
    }

    final parsed = jsonDecode(_extractJsonPayload(rawText));
    if (parsed is! Map<String, dynamic>) {
      throw Exception('JSON Gemini invalide.');
    }
    return parsed;
  }

  String _extractJsonPayload(String rawText) {
    final cleaned = rawText
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
    final firstBrace = cleaned.indexOf('{');
    final lastBrace = cleaned.lastIndexOf('}');
    if (firstBrace == -1 || lastBrace == -1 || lastBrace <= firstBrace) {
      throw Exception('JSON introuvable dans la reponse Gemini.');
    }
    return cleaned.substring(firstBrace, lastBrace + 1);
  }

  static String? _cleanNullable(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }
}
