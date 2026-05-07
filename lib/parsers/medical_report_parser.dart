import '../models/medical_report.dart';
import '../utils/medical_dictionary.dart';
import '../utils/medical_regex.dart';

class MedicalReportParser {
  const MedicalReportParser();

  MedicalReport parse({
    required String sourceFileName,
    required String rawText,
    required DocumentType documentType,
    required double confidence,
  }) {
    final normalized = _normalizeText(rawText);
    final lines = normalized
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    final patientInfo = _extractPatientInfo(lines);
    final doctorInfo = _extractDoctorInfo(lines);
    final reportInfo = _extractReportInfo(lines);
    final labInfo = _extractLabInfo(lines);
    final sections = _extractSections(lines);

    return MedicalReport(
      documentType: documentType,
      sourceFileName: sourceFileName,
      extractedAt: DateTime.now(),
      labInfo: labInfo,
      patientInfo: patientInfo,
      doctorInfo: doctorInfo,
      reportInfo: reportInfo,
      sections: sections,
      rawText: rawText,
      confidence: confidence,
    );
  }

  String _normalizeText(String input) {
    return input
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(',', '.')
        .trim();
  }

  List<MedicalSection> _extractSections(List<String> lines) {
    final sections = <MedicalSection>[];
    var currentTitle = 'Analyses';
    final currentAnalyses = <MedicalAnalysis>[];
    final seenKeys = <String>{};

    void flushSection() {
      if (currentAnalyses.isEmpty) return;
      sections.add(MedicalSection(title: currentTitle, analyses: List<MedicalAnalysis>.from(currentAnalyses)));
      currentAnalyses.clear();
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final normalized = line.toLowerCase();
      final foundSection = MedicalDictionary.sectionTitles.firstWhere(
        (s) => normalized.contains(s),
        orElse: () => '',
      );
      if (foundSection.isNotEmpty) {
        flushSection();
        currentTitle = _pretty(foundSection);
        continue;
      }

      if (_isLikelyMetadataLine(normalized)) {
        continue;
      }
      final analysis = _parseAnalysisLine(
        line,
        i + 1 < lines.length ? lines[i + 1] : null,
        i + 2 < lines.length ? lines[i + 2] : null,
      );
      if (analysis != null) {
        final key =
            '${analysis.name.toLowerCase()}|${analysis.value ?? ''}|${analysis.unit ?? ''}';
        if (!seenKeys.contains(key)) {
          seenKeys.add(key);
          currentAnalyses.add(analysis);
        }
      }
    }
    flushSection();
    return sections;
  }

  MedicalAnalysis? _parseAnalysisLine(String line, String? nextLine, String? thirdLine) {
    final normalized = line.toLowerCase();
    final isKnown = MedicalDictionary.knownAnalyses.any((k) => normalized.contains(k));
    final hasNumber = MedicalRegex.number.hasMatch(line);
    final hasUnit = MedicalRegex.unit.hasMatch(normalized);
    final next = nextLine ?? '';
    final nextNormalized = next.toLowerCase();
    final nextHasNumber = MedicalRegex.number.hasMatch(next);
    final nextHasUnit = MedicalRegex.unit.hasMatch(nextNormalized);
    final third = thirdLine ?? '';
    final thirdNormalized = third.toLowerCase();
    final thirdHasNumber = MedicalRegex.number.hasMatch(third);
    final thirdHasUnit = MedicalRegex.unit.hasMatch(thirdNormalized);
    if (!isKnown &&
        !(hasNumber && hasUnit) &&
        !(nextHasNumber && nextHasUnit) &&
        !(thirdHasNumber && thirdHasUnit)) {
      return null;
    }

    final parseLine = (hasNumber || hasUnit)
        ? line
        : (nextHasNumber || nextHasUnit)
            ? next
            : third;
    final parseLineNormalized = parseLine.toLowerCase();
    final unitMatch = MedicalRegex.unit.firstMatch(parseLineNormalized);
    final valueMatch = MedicalRegex.number.firstMatch(parseLine);
    final values = MedicalRegex.number.allMatches(parseLine).map((e) => e.group(1)!).toList(growable: false);
    final analysisName = _extractAnalysisNameFromPair(line, parseLine, next, third);
    if (!_isPlausibleAnalysisName(analysisName)) {
      return null;
    }
    final ref = _extractReference(parseLine, nextLine ?? thirdLine);
    final abnormalFlag = _detectFlag(
      rawValue: valueMatch?.group(1),
      referenceMin: ref.$1,
      referenceMax: ref.$2,
    );
    final secondaryValue = values.length >= 2 ? values[1] : null;

    return MedicalAnalysis(
      name: analysisName,
      value: valueMatch?.group(1),
      unit: unitMatch?.group(1),
      secondaryValue: secondaryValue,
      secondaryUnit: null,
      referenceText: ref.$3,
      referenceMin: ref.$1,
      referenceMax: ref.$2,
      previousValue: null,
      previousDate: null,
      technique: (nextLine != null && nextLine.toLowerCase().contains('technique')) ? nextLine : null,
      interpretation: null,
      abnormalFlag: abnormalFlag,
      confidence: isKnown
          ? 0.88
          : (nextHasNumber && nextHasUnit) || (thirdHasNumber && thirdHasUnit)
              ? 0.74
              : 0.62,
    );
  }

  (double?, double?, String?) _extractReference(String line, String? nextLine) {
    final joined = '$line ${nextLine ?? ''}';
    final joinedLower = joined.toLowerCase();
    if (_isLikelyMetadataLine(joinedLower)) {
      return (null, null, null);
    }
    final range = MedicalRegex.range.firstMatch(joined);
    if (range != null) {
      return (_toDouble(range.group(1)), _toDouble(range.group(2)), range.group(0));
    }
    final lt = MedicalRegex.lowerThan.firstMatch(joined);
    if (lt != null) {
      return (null, _toDouble(lt.group(1)), lt.group(0));
    }
    final gt = MedicalRegex.greaterThan.firstMatch(joined);
    if (gt != null) {
      return (_toDouble(gt.group(1)), null, gt.group(0));
    }
    return (null, null, null);
  }

  AbnormalFlag _detectFlag({
    required String? rawValue,
    required double? referenceMin,
    required double? referenceMax,
  }) {
    final value = _toDouble(rawValue);
    if (value == null || (referenceMin == null && referenceMax == null)) {
      return AbnormalFlag.unknown;
    }
    if (referenceMin != null && value < referenceMin) return AbnormalFlag.low;
    if (referenceMax != null && value > referenceMax) return AbnormalFlag.high;
    return AbnormalFlag.normal;
  }

  String _extractAnalysisName(String line) {
    final valueMatch = MedicalRegex.number.firstMatch(line);
    if (valueMatch == null) return line.trim();
    final idx = valueMatch.start;
    if (idx <= 1) return line.trim();
    return line.substring(0, idx).replaceAll(RegExp(r'[:.\-]+$'), '').trim();
  }

  String _extractAnalysisNameFromPair(
    String originalLine,
    String parseLine,
    String? nextLine,
    String? thirdLine,
  ) {
    final baseName = _extractAnalysisName(originalLine);
    if (baseName.trim().isNotEmpty &&
        !MedicalRegex.number.hasMatch(baseName) &&
        baseName.length >= 3 &&
        !_isLikelyMetadataLine(baseName.toLowerCase())) {
      return baseName;
    }
    final next = (nextLine ?? '').trim();
    if (next.isNotEmpty &&
        !MedicalRegex.number.hasMatch(next) &&
        next.length >= 3 &&
        !_isLikelyMetadataLine(next.toLowerCase())) {
      return next;
    }
    final third = (thirdLine ?? '').trim();
    if (third.isNotEmpty &&
        !MedicalRegex.number.hasMatch(third) &&
        third.length >= 3 &&
        !_isLikelyMetadataLine(third.toLowerCase())) {
      return third;
    }
    return _extractAnalysisName(parseLine);
  }

  bool _isLikelyMetadataLine(String normalizedLine) {
    return normalizedLine.contains('patient') ||
        normalizedLine.contains('dossier') ||
        normalizedLine.contains('demand') ||
        normalizedLine.contains('medecin') ||
        normalizedLine.contains('demandeur') ||
        normalizedLine.contains('laboratoire') ||
        normalizedLine.contains('date ') ||
        normalizedLine.contains('pvt du') ||
        normalizedLine.contains('prelevement') ||
        normalizedLine.contains('page') ||
        normalizedLine.contains('code patient') ||
        normalizedLine.contains('valide biologiquement');
  }

  bool _isPlausibleAnalysisName(String name) {
    final trimmed = name.trim();
    if (trimmed.length < 3) return false;
    if (RegExp(r'^[\$\#\-/.:()]+$').hasMatch(trimmed)) return false;
    final lower = trimmed.toLowerCase();
    if (_isLikelyMetadataLine(lower)) return false;
    if (lower.contains('valeurs usuelles')) return false;
    if (lower.startsWith('s1.') || lower.startsWith(r'$1.')) return false;
    final lettersCount = RegExp(r'[a-zA-Z]').allMatches(trimmed).length;
    return lettersCount >= 3;
  }

  LabInfo _extractLabInfo(List<String> lines) {
    final labName = lines.firstWhere(
      (l) => l.toLowerCase().contains('laboratoire'),
      orElse: () => '',
    );
    final phone = lines.firstWhere(
      (l) => l.toLowerCase().contains('tel'),
      orElse: () => '',
    );
    return LabInfo(
      name: labName.isEmpty ? null : labName,
      address: null,
      phone: phone.isEmpty ? null : phone,
      email: null,
      city: null,
    );
  }

  PatientInfo _extractPatientInfo(List<String> lines) {
    String? patient;
    String? organism;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();
      if (patient == null) {
        final candidate = _extractPatientNameCandidate(line);
        if (candidate != null) {
          patient = candidate;
        } else if (lower.contains('patient') && i + 1 < lines.length) {
          final next = _extractPatientNameCandidate(lines[i + 1]);
          if (next != null) {
            patient = next;
          }
        }
      }
      if (organism == null && lower.contains('organisme')) {
        organism = _extractValueAfterColon(line) ?? line;
      }
    }
    return PatientInfo(
      fullName: patient,
      codePatient: _capture(lines, MedicalRegex.codePatient),
      dossierNumber: _capture(lines, MedicalRegex.dossier),
      organism: organism,
    );
  }

  DoctorInfo _extractDoctorInfo(List<String> lines) {
    String? requester;
    String? validator;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();
      if (requester == null && lower.contains('demandeur')) {
        requester = _extractValueAfterColon(line);
        if ((requester == null || requester.isEmpty) && i > 0) {
          final prev = lines[i - 1];
          if (_isDoctorLine(prev)) {
            requester = prev;
          }
        }
        if ((requester == null || requester.isEmpty) && i + 1 < lines.length) {
          final next = lines[i + 1];
          if (_isDoctorLine(next)) {
            requester = next;
          }
        }
      }
      if (validator == null && (lower.contains('valide') || lower.contains('biologiste'))) {
        validator = _extractDoctorFromLine(line) ?? line;
      }
    }

    requester ??= lines.firstWhere(
      (l) => _isDoctorLine(l) && !l.toLowerCase().contains('biologiste'),
      orElse: () => '',
    );
    validator ??= lines.firstWhere(
      (l) => l.toLowerCase().contains('valide biologiquement'),
      orElse: () => '',
    );

    return DoctorInfo(
      requesterName: requester.isEmpty ? null : requester,
      validatorName: validator.isEmpty ? null : validator,
    );
  }

  ReportInfo _extractReportInfo(List<String> lines) {
    final allText = lines.join('\n');
    final dates = MedicalRegex.date.allMatches(allText).map((e) => e.group(0)!).toList(growable: false);
    return ReportInfo(
      reportDate: dates.isNotEmpty ? dates.first : null,
      sampleDate: dates.length > 1 ? dates[1] : null,
      examNumber: _capture(lines, MedicalRegex.examNumber),
      pageNumber: _capture(lines, MedicalRegex.pageNumber),
    );
  }

  String? _capture(List<String> lines, RegExp pattern) {
    for (final line in lines) {
      final match = pattern.firstMatch(line);
      if (match != null) return match.group(1);
    }
    return null;
  }

  double? _toDouble(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return double.tryParse(value.replaceAll(',', '.'));
  }

  String _pretty(String input) {
    if (input.isEmpty) return input;
    return '${input[0].toUpperCase()}${input.substring(1)}';
  }

  String? _extractPatientNameCandidate(String line) {
    final trimmed = line.trim();
    final lower = trimmed.toLowerCase();
    if (trimmed.length < 4) return null;
    if (lower.contains('code patient')) return null;
    if (lower.contains('organisme') ||
        lower.contains('demandeur') ||
        lower.contains('date') ||
        lower.contains('examen') ||
        lower.contains('page')) {
      return null;
    }

    final titled = RegExp(r'\b(mme|mr|m\.|mlle)\b\.?\s+([a-z][a-z\s\-]{2,})', caseSensitive: false)
        .firstMatch(trimmed);
    if (titled != null) {
      final prefix = titled.group(1)!.trim();
      final name = titled.group(2)!.trim();
      return '$prefix $name'.trim();
    }

    final colonValue = _extractValueAfterColon(trimmed);
    if (lower.contains('patient') && colonValue != null) {
      return colonValue;
    }
    return null;
  }

  String? _extractValueAfterColon(String line) {
    final idx = line.indexOf(':');
    if (idx == -1 || idx >= line.length - 1) return null;
    final value = line.substring(idx + 1).trim();
    return value.isEmpty ? null : value;
  }

  bool _isDoctorLine(String line) {
    final lower = line.toLowerCase();
    return lower.contains('dr ') || lower.startsWith('dr.') || lower.startsWith('dr ');
  }

  String? _extractDoctorFromLine(String line) {
    final match = RegExp(r'(dr\.?\s+[a-z][a-z\s\-]+)', caseSensitive: false).firstMatch(line);
    return match?.group(1)?.trim();
  }
}
