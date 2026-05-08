import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/medical_report.dart';

class ScanHistoryEntry {
  const ScanHistoryEntry({
    required this.text,
    required this.detectedLanguages,
    required this.createdAtIso,
    this.imageBase64,
    this.resultSummary,
    this.structuredReportJson,
    this.sourceFileName,
    this.documentTypeLabel = 'Document',
    this.status = 'extracted',
    this.folder = 'Bibliotheque generale',
    this.tags = const <String>[],
    this.targetLanguageCode,
    this.fileSizeBytes,
    this.importedBy = 'Workspace user',
    this.isArchived = false,
    this.isDeleted = false,
    this.isFavorite = false,
    this.isPinned = false,
    this.note,
    this.ocrConfidence,
    this.versionLabels = const <String>[],
    this.activityLog = const <String>[],
  });

  final String text;
  final List<String> detectedLanguages;
  final String createdAtIso;
  final String? imageBase64;
  final String? resultSummary;
  final String? structuredReportJson;
  final String? sourceFileName;
  final String documentTypeLabel;
  final String status;
  final String folder;
  final List<String> tags;
  final String? targetLanguageCode;
  final int? fileSizeBytes;
  final String importedBy;
  final bool isArchived;
  final bool isDeleted;
  final bool isFavorite;
  final bool isPinned;
  final String? note;
  final double? ocrConfidence;
  final List<String> versionLabels;
  final List<String> activityLog;

  MedicalReport? get structuredReport {
    final raw = structuredReportJson?.trim();
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return MedicalReport.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Uint8List? get imageBytes {
    if (imageBase64 == null || imageBase64!.isEmpty) return null;
    try {
      return base64Decode(imageBase64!);
    } catch (_) {
      return null;
    }
  }

  String get displayName {
    final rawName = sourceFileName?.trim();
    if (rawName != null && rawName.isNotEmpty) return rawName;
    final reportName = structuredReport?.sourceFileName.trim();
    if (reportName != null && reportName.isNotEmpty) return reportName;
    return 'Document ${createdAtIso.split('T').first}';
  }

  ScanHistoryEntry copyWith({
    String? text,
    List<String>? detectedLanguages,
    String? createdAtIso,
    String? imageBase64,
    String? resultSummary,
    String? structuredReportJson,
    String? sourceFileName,
    String? documentTypeLabel,
    String? status,
    String? folder,
    List<String>? tags,
    String? targetLanguageCode,
    int? fileSizeBytes,
    String? importedBy,
    bool? isArchived,
    bool? isDeleted,
    bool? isFavorite,
    bool? isPinned,
    String? note,
    bool clearNote = false,
    double? ocrConfidence,
    List<String>? versionLabels,
    List<String>? activityLog,
  }) {
    return ScanHistoryEntry(
      text: text ?? this.text,
      detectedLanguages: detectedLanguages ?? this.detectedLanguages,
      createdAtIso: createdAtIso ?? this.createdAtIso,
      imageBase64: imageBase64 ?? this.imageBase64,
      resultSummary: resultSummary ?? this.resultSummary,
      structuredReportJson: structuredReportJson ?? this.structuredReportJson,
      sourceFileName: sourceFileName ?? this.sourceFileName,
      documentTypeLabel: documentTypeLabel ?? this.documentTypeLabel,
      status: status ?? this.status,
      folder: folder ?? this.folder,
      tags: tags ?? this.tags,
      targetLanguageCode: targetLanguageCode ?? this.targetLanguageCode,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      importedBy: importedBy ?? this.importedBy,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
      isFavorite: isFavorite ?? this.isFavorite,
      isPinned: isPinned ?? this.isPinned,
      note: clearNote ? null : (note ?? this.note),
      ocrConfidence: ocrConfidence ?? this.ocrConfidence,
      versionLabels: versionLabels ?? this.versionLabels,
      activityLog: activityLog ?? this.activityLog,
    );
  }

  Map<String, dynamic> toJson() => {
    'text': text,
    if (detectedLanguages.isNotEmpty) 'detectedLanguages': detectedLanguages,
    'createdAtIso': createdAtIso,
    if (imageBase64 != null && imageBase64!.isNotEmpty)
      'imageBase64': imageBase64,
    if (resultSummary != null && resultSummary!.isNotEmpty)
      'resultSummary': resultSummary,
    if (structuredReportJson != null && structuredReportJson!.isNotEmpty)
      'structuredReportJson': structuredReportJson,
    if (sourceFileName != null && sourceFileName!.isNotEmpty)
      'sourceFileName': sourceFileName,
    'documentTypeLabel': documentTypeLabel,
    'status': status,
    'folder': folder,
    if (tags.isNotEmpty) 'tags': tags,
    if (targetLanguageCode != null && targetLanguageCode!.isNotEmpty)
      'targetLanguageCode': targetLanguageCode,
    if (fileSizeBytes != null) 'fileSizeBytes': fileSizeBytes,
    'importedBy': importedBy,
    'isArchived': isArchived,
    'isDeleted': isDeleted,
    'isFavorite': isFavorite,
    'isPinned': isPinned,
    if (note != null && note!.isNotEmpty) 'note': note,
    if (ocrConfidence != null) 'ocrConfidence': ocrConfidence,
    if (versionLabels.isNotEmpty) 'versionLabels': versionLabels,
    if (activityLog.isNotEmpty) 'activityLog': activityLog,
  };

  factory ScanHistoryEntry.fromJson(Map<String, dynamic> json) {
    final rawLanguages = json['detectedLanguages'];
    final rawTags = json['tags'];
    final rawVersions = json['versionLabels'];
    final rawActivity = json['activityLog'];
    return ScanHistoryEntry(
      text: (json['text'] ?? '').toString(),
      detectedLanguages: rawLanguages is List
          ? rawLanguages.map((e) => e.toString()).toList(growable: false)
          : const <String>[],
      createdAtIso: (json['createdAtIso'] ?? '').toString(),
      imageBase64: json['imageBase64']?.toString(),
      resultSummary: json['resultSummary']?.toString(),
      structuredReportJson: json['structuredReportJson']?.toString(),
      sourceFileName: json['sourceFileName']?.toString(),
      documentTypeLabel: (json['documentTypeLabel'] ?? 'Document').toString(),
      status: (json['status'] ?? 'extracted').toString(),
      folder: (json['folder'] ?? 'Bibliotheque generale').toString(),
      tags: rawTags is List
          ? rawTags.map((e) => e.toString()).toList(growable: false)
          : const <String>[],
      targetLanguageCode: json['targetLanguageCode']?.toString(),
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt(),
      importedBy: (json['importedBy'] ?? 'Workspace user').toString(),
      isArchived: json['isArchived'] == true,
      isDeleted: json['isDeleted'] == true,
      isFavorite: json['isFavorite'] == true,
      isPinned: json['isPinned'] == true,
      note: json['note']?.toString(),
      ocrConfidence: (json['ocrConfidence'] as num?)?.toDouble(),
      versionLabels: rawVersions is List
          ? rawVersions.map((e) => e.toString()).toList(growable: false)
          : const <String>[],
      activityLog: rawActivity is List
          ? rawActivity.map((e) => e.toString()).toList(growable: false)
          : const <String>[],
    );
  }
}

class ScanHistoryStore extends ChangeNotifier {
  static const String _storageKeyBase = 'scan_history_entries_v4';
  static const String _cloudCollection = 'scan_history';

  final List<ScanHistoryEntry> _entries = [];
  List<ScanHistoryEntry> get entries => List.unmodifiable(_entries);

  Future<void> load() async {
    _entries.clear();
    final prefs = await SharedPreferences.getInstance();
    final localStorageKey = _localStorageKey();
    var raw = prefs.getString(localStorageKey);
    var migratedFromLegacy = false;
    if (raw == null || raw.isEmpty) {
      for (final legacyKey in const <String>[
        'scan_history_entries_v3',
        'scan_history_entries_v2',
        'scan_history_entries_v1',
      ]) {
        raw = prefs.getString(legacyKey);
        migratedFromLegacy = raw != null && raw.isNotEmpty;
        if (migratedFromLegacy) {
          break;
        }
      }
    }
    if (raw == null || raw.isEmpty) {
      notifyListeners();
      await refreshFromCloud();
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _entries
          ..clear()
          ..addAll(
            decoded.whereType<Map>().map(
              (e) => ScanHistoryEntry.fromJson(Map<String, dynamic>.from(e)),
            ),
          );
        notifyListeners();
        if (migratedFromLegacy) {
          await _save();
        }
      }
    } catch (_) {
      // Keep history empty if parsing fails.
    }

    await refreshFromCloud();
  }

  Future<void> addEntry({
    required String text,
    List<String> detectedLanguages = const <String>[],
    String? imageBase64,
    MedicalReport? structuredReport,
    String? sourceFileName,
    int? fileSizeBytes,
    String? importedBy,
  }) async {
    final clientText = structuredReport == null
        ? text
        : _buildClientResultText(structuredReport);
    final resultSummary = structuredReport == null
        ? null
        : 'type=${structuredReport.documentType.name}; '
              'sections=${structuredReport.sections.length}; '
              'analyses=${structuredReport.sections.fold<int>(0, (acc, section) => acc + section.analyses.length)}; '
              'confidence=${(structuredReport.confidence * 100).toStringAsFixed(1)}%';
    final fileName = sourceFileName ?? structuredReport?.sourceFileName;
    final documentTypeLabel = _inferDocumentTypeLabel(
      structuredReport: structuredReport,
      sourceFileName: fileName,
      text: clientText,
    );
    final tags = _buildTags(
      detectedLanguages: detectedLanguages,
      structuredReport: structuredReport,
      sourceFileName: fileName,
    );
    final folder = _inferFolder(documentTypeLabel);
    final confidence = structuredReport?.confidence;

    final newEntry = ScanHistoryEntry(
      text: clientText,
      detectedLanguages: detectedLanguages,
      createdAtIso: DateTime.now().toIso8601String(),
      imageBase64: imageBase64,
      resultSummary: resultSummary,
      structuredReportJson: structuredReport == null
          ? null
          : jsonEncode(structuredReport.toJson()),
      sourceFileName: fileName,
      documentTypeLabel: documentTypeLabel,
      status: structuredReport == null ? 'extracted' : 'validated',
      folder: folder,
      tags: tags,
      fileSizeBytes: fileSizeBytes,
      importedBy: _resolvedImportedBy(importedBy),
      ocrConfidence: confidence,
      versionLabels: _buildVersionLabels(structuredReport),
      activityLog: _buildActivityLog(fileName, structuredReport),
    );

    _entries.insert(0, newEntry);
    if (_entries.length > 80) {
      _entries.removeRange(80, _entries.length);
    }
    notifyListeners();
    await _save();
    await _saveToCloud(newEntry);
  }

  Future<void> clear() async {
    _entries.clear();
    notifyListeners();
    await _save();
  }

  Future<void> removeEntryAt(int index) async {
    if (index < 0 || index >= _entries.length) return;
    _entries.removeAt(index);
    notifyListeners();
    await _save();
  }

  Future<void> toggleFavoriteAt(int index) async {
    if (index < 0 || index >= _entries.length) return;
    final current = _entries[index];
    _entries[index] = current.copyWith(
      isFavorite: !current.isFavorite,
      activityLog: _prependLog(
        current.activityLog,
        current.isFavorite ? 'Retire des favoris.' : 'Ajoute aux favoris.',
      ),
    );
    notifyListeners();
    await _save();
  }

  Future<void> togglePinnedAt(int index) async {
    if (index < 0 || index >= _entries.length) return;
    final current = _entries[index];
    _entries[index] = current.copyWith(
      isPinned: !current.isPinned,
      activityLog: _prependLog(
        current.activityLog,
        current.isPinned ? 'Document desepinglé.' : 'Document epingle.',
      ),
    );
    notifyListeners();
    await _save();
  }

  Future<void> archiveEntryAt(int index, {required bool archived}) async {
    if (index < 0 || index >= _entries.length) return;
    final current = _entries[index];
    _entries[index] = current.copyWith(
      isArchived: archived,
      status: archived
          ? 'archived'
          : (current.structuredReport != null ? 'validated' : 'extracted'),
      activityLog: _prependLog(
        current.activityLog,
        archived ? 'Document archive.' : 'Document restaure.',
      ),
    );
    notifyListeners();
    await _save();
  }

  Future<void> setDeletedAt(int index, {required bool deleted}) async {
    if (index < 0 || index >= _entries.length) return;
    final current = _entries[index];
    _entries[index] = current.copyWith(
      isDeleted: deleted,
      activityLog: _prependLog(
        current.activityLog,
        deleted
            ? 'Document envoye vers la corbeille.'
            : 'Document restaure depuis la corbeille.',
      ),
    );
    notifyListeners();
    await _save();
  }

  Future<void> updateFolderAt(int index, String folder) async {
    if (index < 0 || index >= _entries.length) return;
    final current = _entries[index];
    _entries[index] = current.copyWith(
      folder: folder,
      activityLog: _prependLog(current.activityLog, 'Classe dans $folder.'),
    );
    notifyListeners();
    await _save();
  }

  Future<void> updateTagsAt(int index, List<String> tags) async {
    if (index < 0 || index >= _entries.length) return;
    final current = _entries[index];
    _entries[index] = current.copyWith(
      tags: tags,
      activityLog: _prependLog(current.activityLog, 'Etiquettes mises a jour.'),
    );
    notifyListeners();
    await _save();
  }

  Future<void> updateNoteAt(int index, String note) async {
    if (index < 0 || index >= _entries.length) return;
    final current = _entries[index];
    _entries[index] = current.copyWith(
      note: note.trim(),
      activityLog: _prependLog(
        current.activityLog,
        'Note ajoutee ou modifiee.',
      ),
    );
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await prefs.setString(_localStorageKey(), payload);
  }

  Future<void> _saveToCloud(ScanHistoryEntry entry) async {
    final collection = _userCollection();
    if (collection == null) return;
    try {
      await collection.add(entry.toJson());
    } catch (_) {
      // Cloud sync failure should never break local history.
    }
  }

  Future<void> refreshFromCloud() async {
    final collection = _userCollection();
    if (collection == null) return;
    try {
      final snapshot = await collection
          .orderBy('createdAtIso', descending: true)
          .limit(80)
          .get();

      if (snapshot.docs.isEmpty) return;

      final cloudEntries = snapshot.docs
          .map((doc) => ScanHistoryEntry.fromJson(doc.data()))
          .where((entry) => entry.text.trim().isNotEmpty)
          .toList(growable: false);

      if (cloudEntries.isEmpty) return;

      final existingKeys = _entries
          .map(
            (entry) =>
                '${entry.createdAtIso}|${entry.displayName}|${entry.detectedLanguages.join(',')}',
          )
          .toSet();

      var changed = false;
      for (final cloudEntry in cloudEntries) {
        final key =
            '${cloudEntry.createdAtIso}|${cloudEntry.displayName}|${cloudEntry.detectedLanguages.join(',')}';
        if (existingKeys.add(key)) {
          _entries.add(cloudEntry);
          changed = true;
        }
      }

      if (!changed) return;

      _entries.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.createdAtIso.compareTo(a.createdAtIso);
      });
      if (_entries.length > 80) {
        _entries.removeRange(80, _entries.length);
      }

      notifyListeners();
      await _save();
    } catch (_) {
      // Ignore cloud read errors and keep local history.
    }
  }

  CollectionReference<Map<String, dynamic>>? _userCollection() {
    if (Firebase.apps.isEmpty) return null;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection(_cloudCollection);
  }

  String suggestedImportedBy() => _resolvedImportedBy(null);

  String _localStorageKey() {
    final uid = FirebaseAuth.instance.currentUser?.uid.trim();
    if (uid == null || uid.isEmpty) {
      return '${_storageKeyBase}_local';
    }
    return '${_storageKeyBase}_$uid';
  }

  String _resolvedImportedBy(String? importedBy) {
    final provided = importedBy?.trim();
    if (provided != null && provided.isNotEmpty) return provided;

    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;

    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) return email;

    return 'Workspace user';
  }

  String _buildClientResultText(MedicalReport report) {
    final buffer = StringBuffer();
    buffer.writeln('Type: ${report.documentType.name}');
    buffer.writeln(
      'Confiance: ${(report.confidence * 100).toStringAsFixed(1)}%',
    );
    if ((report.patientInfo.fullName ?? '').trim().isNotEmpty) {
      buffer.writeln('Patient: ${report.patientInfo.fullName}');
    }
    if ((report.labInfo.name ?? '').trim().isNotEmpty) {
      buffer.writeln('Laboratoire: ${report.labInfo.name}');
    }
    final analyses = report.sections.expand((s) => s.analyses).take(6);
    for (final analysis in analyses) {
      buffer.writeln(
        '- ${analysis.name}: ${analysis.value ?? '-'} ${analysis.unit ?? ''}'
            .trim(),
      );
    }
    return buffer.toString().trim();
  }

  String _inferDocumentTypeLabel({
    required MedicalReport? structuredReport,
    required String? sourceFileName,
    required String text,
  }) {
    if (structuredReport != null) {
      return 'Analyse medicale';
    }
    final name = (sourceFileName ?? '').toLowerCase();
    final raw = text.toLowerCase();
    if (name.contains('facture') ||
        raw.contains('facture') ||
        raw.contains('invoice')) {
      return 'Facture';
    }
    if (name.contains('contrat') ||
        raw.contains('contrat') ||
        raw.contains('contract')) {
      return 'Contrat';
    }
    if (name.contains('passport') ||
        name.contains('passeport') ||
        raw.contains('passeport')) {
      return 'Passeport';
    }
    if (name.endsWith('.pdf')) return 'Document PDF';
    if (name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png')) {
      return 'Image document';
    }
    return 'Document';
  }

  String _inferFolder(String documentTypeLabel) {
    switch (documentTypeLabel) {
      case 'Analyse medicale':
        return 'Rapports medicaux';
      case 'Facture':
        return 'Factures';
      case 'Contrat':
        return 'Contrats';
      case 'Passeport':
        return 'Identite';
      default:
        return 'Bibliotheque generale';
    }
  }

  List<String> _buildTags({
    required List<String> detectedLanguages,
    required MedicalReport? structuredReport,
    required String? sourceFileName,
  }) {
    final tags = <String>{
      if (structuredReport != null) 'valide',
      if (structuredReport != null) 'medical',
      if (detectedLanguages.length > 1) 'multilingue',
      if (sourceFileName?.toLowerCase().endsWith('.pdf') == true) 'pdf',
      if (sourceFileName?.toLowerCase().endsWith('.jpg') == true ||
          sourceFileName?.toLowerCase().endsWith('.jpeg') == true ||
          sourceFileName?.toLowerCase().endsWith('.png') == true)
        'image',
    };
    final confidence = structuredReport?.confidence;
    if (confidence != null && confidence < 0.7) {
      tags.add('a verifier');
    }
    return tags.toList(growable: false);
  }

  List<String> _buildVersionLabels(MedicalReport? structuredReport) {
    return <String>[
      'V1 Import original',
      'V2 OCR extrait',
      if (structuredReport != null) 'V3 Rapport structure',
    ];
  }

  List<String> _buildActivityLog(
    String? fileName,
    MedicalReport? structuredReport,
  ) {
    return <String>[
      'OCR extrait avec succes.',
      if (structuredReport != null) 'Document structure et valide.',
      if (fileName != null && fileName.trim().isNotEmpty)
        'Import depuis $fileName.',
    ];
  }

  List<String> _prependLog(List<String> existing, String next) {
    return <String>[next, ...existing].take(12).toList(growable: false);
  }
}
