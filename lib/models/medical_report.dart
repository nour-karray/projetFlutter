enum DocumentType { medicalReport, unknown }

enum AbnormalFlag { low, high, normal, unknown }

class MedicalReport {
  const MedicalReport({
    required this.documentType,
    required this.sourceFileName,
    required this.extractedAt,
    required this.labInfo,
    required this.patientInfo,
    required this.doctorInfo,
    required this.reportInfo,
    required this.sections,
    required this.rawText,
    required this.confidence,
  });

  final DocumentType documentType;
  final String sourceFileName;
  final DateTime extractedAt;
  final LabInfo labInfo;
  final PatientInfo patientInfo;
  final DoctorInfo doctorInfo;
  final ReportInfo reportInfo;
  final List<MedicalSection> sections;
  final String rawText;
  final double confidence;

  MedicalReport copyWith({
    DocumentType? documentType,
    String? sourceFileName,
    DateTime? extractedAt,
    LabInfo? labInfo,
    PatientInfo? patientInfo,
    DoctorInfo? doctorInfo,
    ReportInfo? reportInfo,
    List<MedicalSection>? sections,
    String? rawText,
    double? confidence,
  }) {
    return MedicalReport(
      documentType: documentType ?? this.documentType,
      sourceFileName: sourceFileName ?? this.sourceFileName,
      extractedAt: extractedAt ?? this.extractedAt,
      labInfo: labInfo ?? this.labInfo,
      patientInfo: patientInfo ?? this.patientInfo,
      doctorInfo: doctorInfo ?? this.doctorInfo,
      reportInfo: reportInfo ?? this.reportInfo,
      sections: sections ?? this.sections,
      rawText: rawText ?? this.rawText,
      confidence: confidence ?? this.confidence,
    );
  }

  Map<String, dynamic> toJson() => {
    'documentType': documentType.name,
    'sourceFileName': sourceFileName,
    'extractedAt': extractedAt.toIso8601String(),
    'labInfo': labInfo.toJson(),
    'patientInfo': patientInfo.toJson(),
    'doctorInfo': doctorInfo.toJson(),
    'reportInfo': reportInfo.toJson(),
    'sections': sections.map((e) => e.toJson()).toList(),
    'rawText': rawText,
    'confidence': confidence,
  };

  factory MedicalReport.fromJson(Map<String, dynamic> json) {
    final type = (json['documentType'] ?? '').toString();
    return MedicalReport(
      documentType: type == DocumentType.medicalReport.name
          ? DocumentType.medicalReport
          : DocumentType.unknown,
      sourceFileName: (json['sourceFileName'] ?? '').toString(),
      extractedAt:
          DateTime.tryParse((json['extractedAt'] ?? '').toString()) ??
          DateTime.now(),
      labInfo: LabInfo.fromJson(
        Map<String, dynamic>.from(json['labInfo'] ?? const {}),
      ),
      patientInfo: PatientInfo.fromJson(
        Map<String, dynamic>.from(json['patientInfo'] ?? const {}),
      ),
      doctorInfo: DoctorInfo.fromJson(
        Map<String, dynamic>.from(json['doctorInfo'] ?? const {}),
      ),
      reportInfo: ReportInfo.fromJson(
        Map<String, dynamic>.from(json['reportInfo'] ?? const {}),
      ),
      sections: (json['sections'] is List)
          ? (json['sections'] as List)
                .whereType<Map>()
                .map(
                  (e) => MedicalSection.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList(growable: false)
          : const <MedicalSection>[],
      rawText: (json['rawText'] ?? '').toString(),
      confidence: ((json['confidence'] ?? 0.0) as num).toDouble(),
    );
  }
}

class LabInfo {
  const LabInfo({this.name, this.address, this.phone, this.email, this.city});

  final String? name;
  final String? address;
  final String? phone;
  final String? email;
  final String? city;

  LabInfo copyWith({
    String? name,
    String? address,
    String? phone,
    String? email,
    String? city,
  }) {
    return LabInfo(
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      city: city ?? this.city,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'address': address,
    'phone': phone,
    'email': email,
    'city': city,
  };

  factory LabInfo.fromJson(Map<String, dynamic> json) => LabInfo(
    name: json['name']?.toString(),
    address: json['address']?.toString(),
    phone: json['phone']?.toString(),
    email: json['email']?.toString(),
    city: json['city']?.toString(),
  );
}

class PatientInfo {
  const PatientInfo({
    this.fullName,
    this.codePatient,
    this.dossierNumber,
    this.organism,
  });

  final String? fullName;
  final String? codePatient;
  final String? dossierNumber;
  final String? organism;

  PatientInfo copyWith({
    String? fullName,
    String? codePatient,
    String? dossierNumber,
    String? organism,
  }) {
    return PatientInfo(
      fullName: fullName ?? this.fullName,
      codePatient: codePatient ?? this.codePatient,
      dossierNumber: dossierNumber ?? this.dossierNumber,
      organism: organism ?? this.organism,
    );
  }

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'codePatient': codePatient,
    'dossierNumber': dossierNumber,
    'organism': organism,
  };

  factory PatientInfo.fromJson(Map<String, dynamic> json) => PatientInfo(
    fullName: json['fullName']?.toString(),
    codePatient: json['codePatient']?.toString(),
    dossierNumber: json['dossierNumber']?.toString(),
    organism: json['organism']?.toString(),
  );
}

class DoctorInfo {
  const DoctorInfo({this.requesterName, this.validatorName});

  final String? requesterName;
  final String? validatorName;

  DoctorInfo copyWith({String? requesterName, String? validatorName}) {
    return DoctorInfo(
      requesterName: requesterName ?? this.requesterName,
      validatorName: validatorName ?? this.validatorName,
    );
  }

  Map<String, dynamic> toJson() => {
    'requesterName': requesterName,
    'validatorName': validatorName,
  };

  factory DoctorInfo.fromJson(Map<String, dynamic> json) => DoctorInfo(
    requesterName: json['requesterName']?.toString(),
    validatorName: json['validatorName']?.toString(),
  );
}

class ReportInfo {
  const ReportInfo({
    this.reportDate,
    this.sampleDate,
    this.examNumber,
    this.pageNumber,
  });

  final String? reportDate;
  final String? sampleDate;
  final String? examNumber;
  final String? pageNumber;

  ReportInfo copyWith({
    String? reportDate,
    String? sampleDate,
    String? examNumber,
    String? pageNumber,
  }) {
    return ReportInfo(
      reportDate: reportDate ?? this.reportDate,
      sampleDate: sampleDate ?? this.sampleDate,
      examNumber: examNumber ?? this.examNumber,
      pageNumber: pageNumber ?? this.pageNumber,
    );
  }

  Map<String, dynamic> toJson() => {
    'reportDate': reportDate,
    'sampleDate': sampleDate,
    'examNumber': examNumber,
    'pageNumber': pageNumber,
  };

  factory ReportInfo.fromJson(Map<String, dynamic> json) => ReportInfo(
    reportDate: json['reportDate']?.toString(),
    sampleDate: json['sampleDate']?.toString(),
    examNumber: json['examNumber']?.toString(),
    pageNumber: json['pageNumber']?.toString(),
  );
}

class MedicalSection {
  const MedicalSection({required this.title, required this.analyses});

  final String title;
  final List<MedicalAnalysis> analyses;

  MedicalSection copyWith({String? title, List<MedicalAnalysis>? analyses}) {
    return MedicalSection(
      title: title ?? this.title,
      analyses: analyses ?? this.analyses,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'analyses': analyses.map((e) => e.toJson()).toList(),
  };

  factory MedicalSection.fromJson(Map<String, dynamic> json) => MedicalSection(
    title: (json['title'] ?? '').toString(),
    analyses: (json['analyses'] is List)
        ? (json['analyses'] as List)
              .whereType<Map>()
              .map(
                (e) => MedicalAnalysis.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList(growable: false)
        : const <MedicalAnalysis>[],
  );
}

class MedicalAnalysis {
  const MedicalAnalysis({
    required this.name,
    this.value,
    this.unit,
    this.secondaryValue,
    this.secondaryUnit,
    this.referenceText,
    this.referenceMin,
    this.referenceMax,
    this.previousValue,
    this.previousDate,
    this.technique,
    this.interpretation,
    required this.abnormalFlag,
    required this.confidence,
  });

  final String name;
  final String? value;
  final String? unit;
  final String? secondaryValue;
  final String? secondaryUnit;
  final String? referenceText;
  final double? referenceMin;
  final double? referenceMax;
  final String? previousValue;
  final String? previousDate;
  final String? technique;
  final String? interpretation;
  final AbnormalFlag abnormalFlag;
  final double confidence;

  MedicalAnalysis copyWith({
    String? name,
    String? value,
    String? unit,
    String? secondaryValue,
    String? secondaryUnit,
    String? referenceText,
    double? referenceMin,
    double? referenceMax,
    String? previousValue,
    String? previousDate,
    String? technique,
    String? interpretation,
    AbnormalFlag? abnormalFlag,
    double? confidence,
  }) {
    return MedicalAnalysis(
      name: name ?? this.name,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      secondaryValue: secondaryValue ?? this.secondaryValue,
      secondaryUnit: secondaryUnit ?? this.secondaryUnit,
      referenceText: referenceText ?? this.referenceText,
      referenceMin: referenceMin ?? this.referenceMin,
      referenceMax: referenceMax ?? this.referenceMax,
      previousValue: previousValue ?? this.previousValue,
      previousDate: previousDate ?? this.previousDate,
      technique: technique ?? this.technique,
      interpretation: interpretation ?? this.interpretation,
      abnormalFlag: abnormalFlag ?? this.abnormalFlag,
      confidence: confidence ?? this.confidence,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'value': value,
    'unit': unit,
    'secondaryValue': secondaryValue,
    'secondaryUnit': secondaryUnit,
    'referenceText': referenceText,
    'referenceMin': referenceMin,
    'referenceMax': referenceMax,
    'previousValue': previousValue,
    'previousDate': previousDate,
    'technique': technique,
    'interpretation': interpretation,
    'abnormalFlag': abnormalFlag.name,
    'confidence': confidence,
  };

  factory MedicalAnalysis.fromJson(Map<String, dynamic> json) {
    final rawFlag = (json['abnormalFlag'] ?? '').toString();
    final abnormalFlag = AbnormalFlag.values.firstWhere(
      (e) => e.name == rawFlag,
      orElse: () => AbnormalFlag.unknown,
    );
    return MedicalAnalysis(
      name: (json['name'] ?? '').toString(),
      value: json['value']?.toString(),
      unit: json['unit']?.toString(),
      secondaryValue: json['secondaryValue']?.toString(),
      secondaryUnit: json['secondaryUnit']?.toString(),
      referenceText: json['referenceText']?.toString(),
      referenceMin: (json['referenceMin'] as num?)?.toDouble(),
      referenceMax: (json['referenceMax'] as num?)?.toDouble(),
      previousValue: json['previousValue']?.toString(),
      previousDate: json['previousDate']?.toString(),
      technique: json['technique']?.toString(),
      interpretation: json['interpretation']?.toString(),
      abnormalFlag: abnormalFlag,
      confidence: ((json['confidence'] ?? 0.0) as num).toDouble(),
    );
  }
}
