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
  });

  final String text;
  final List<String> detectedLanguages;
  final String createdAtIso;

  /// PNG miniature en base64 (optionnel: anciennes entrees sans photo).
  final String? imageBase64;
  final String? resultSummary;
  final String? structuredReportJson;

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

  Map<String, dynamic> toJson() => {
        'text': text,
        if (detectedLanguages.isNotEmpty) 'detectedLanguages': detectedLanguages,
        'createdAtIso': createdAtIso,
        if (imageBase64 != null && imageBase64!.isNotEmpty) 'imageBase64': imageBase64,
        if (resultSummary != null && resultSummary!.isNotEmpty) 'resultSummary': resultSummary,
        if (structuredReportJson != null && structuredReportJson!.isNotEmpty)
          'structuredReportJson': structuredReportJson,
      };

  factory ScanHistoryEntry.fromJson(Map<String, dynamic> json) {
    final raw = json['detectedLanguages'];
    return ScanHistoryEntry(
      text: (json['text'] ?? '').toString(),
      detectedLanguages: raw is List
          ? raw.map((e) => e.toString()).toList(growable: false)
          : const <String>[],
      createdAtIso: (json['createdAtIso'] ?? '').toString(),
      imageBase64: json['imageBase64']?.toString(),
      resultSummary: json['resultSummary']?.toString(),
      structuredReportJson: json['structuredReportJson']?.toString(),
    );
  }
}

class ScanHistoryStore extends ChangeNotifier {
  static const String _storageKey = 'scan_history_entries_v2';
  static const String _cloudCollection = 'scan_history';

  final List<ScanHistoryEntry> _entries = [];
  List<ScanHistoryEntry> get entries => List.unmodifiable(_entries);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    var raw = prefs.getString(_storageKey);
    var migratedFromV1 = false;
    if (raw == null || raw.isEmpty) {
      raw = prefs.getString('scan_history_entries_v1');
      migratedFromV1 = raw != null && raw.isNotEmpty;
    }
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _entries
          ..clear()
          ..addAll(
            decoded
                .whereType<Map>()
                .map((e) => ScanHistoryEntry.fromJson(Map<String, dynamic>.from(e))),
          );
        notifyListeners();
        if (migratedFromV1) {
          await _save();
        }
      }
    } catch (_) {
      // Keep history empty if parsing fails.
    }

    await refreshFromCloud();
  }

  /// Historique léger : [texte OCR brut] + [miniature photo] uniquement
  /// (pas de langues ni métadonnées — les anciennes entrées avec `detectedLanguages` restent lisibles).
  Future<void> addEntry({
    required String text,
    List<String> detectedLanguages = const <String>[],
    String? imageBase64,
    MedicalReport? structuredReport,
  }) async {
    final clientText = structuredReport == null ? text : _buildClientResultText(structuredReport);
    final resultSummary = structuredReport == null
        ? null
        : 'type=${structuredReport.documentType.name}; '
            'sections=${structuredReport.sections.length}; '
            'analyses=${structuredReport.sections.fold<int>(0, (acc, section) => acc + section.analyses.length)}; '
            'confidence=${(structuredReport.confidence * 100).toStringAsFixed(1)}%';
    final newEntry = ScanHistoryEntry(
      text: clientText,
      detectedLanguages: detectedLanguages,
      createdAtIso: DateTime.now().toIso8601String(),
      imageBase64: imageBase64,
      resultSummary: resultSummary,
      structuredReportJson: structuredReport == null ? null : jsonEncode(structuredReport.toJson()),
    );

    _entries.insert(
      0,
      newEntry,
    );
    if (_entries.length > 50) {
      _entries.removeRange(50, _entries.length);
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

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, payload);
  }

  Future<void> _saveToCloud(ScanHistoryEntry entry) async {
    final collection = _userCollection();
    if (collection == null) return;
    try {
      await collection.add({
        'text': entry.text,
        if (entry.detectedLanguages.isNotEmpty) 'detectedLanguages': entry.detectedLanguages,
        'createdAtIso': entry.createdAtIso,
        'imageBase64': entry.imageBase64,
        'resultSummary': entry.resultSummary,
        'structuredReportJson': entry.structuredReportJson,
      });
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
          .limit(50)
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
                '${entry.createdAtIso}|${entry.text}|${entry.detectedLanguages.join(',')}',
          )
          .toSet();

      var changed = false;
      for (final cloudEntry in cloudEntries) {
        final key =
            '${cloudEntry.createdAtIso}|${cloudEntry.text}|${cloudEntry.detectedLanguages.join(',')}';
        if (existingKeys.add(key)) {
          _entries.add(cloudEntry);
          changed = true;
        }
      }

      if (!changed) return;

      _entries.sort((a, b) => b.createdAtIso.compareTo(a.createdAtIso));
      if (_entries.length > 50) {
        _entries.removeRange(50, _entries.length);
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

  String _buildClientResultText(MedicalReport report) {
    final buffer = StringBuffer();
    buffer.writeln('Type: ${report.documentType.name}');
    buffer.writeln('Confiance: ${(report.confidence * 100).toStringAsFixed(1)}%');
    if ((report.patientInfo.fullName ?? '').trim().isNotEmpty) {
      buffer.writeln('Patient: ${report.patientInfo.fullName}');
    }
    if ((report.labInfo.name ?? '').trim().isNotEmpty) {
      buffer.writeln('Laboratoire: ${report.labInfo.name}');
    }
    final analyses = report.sections.expand((s) => s.analyses).take(6);
    for (final analysis in analyses) {
      buffer.writeln(
        '- ${analysis.name}: ${analysis.value ?? '-'} ${analysis.unit ?? ''}'.trim(),
      );
    }
    return buffer.toString().trim();
  }
}
