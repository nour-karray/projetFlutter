import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/medical_report.dart';
import 'medical_ai_service.dart';

/// Helvetica encodes text as Latin-1; [latin1.encode] throws on Unicode > U+00FF
/// (Arabic, emoji, typographic dash `—`, ellipsis `…`, etc.).
String _latin1ForPdf(String input) {
  final out = StringBuffer();
  for (final r in input.runes) {
    if (r <= 0xFF) {
      out.writeCharCode(r);
    } else {
      out.write(' ');
    }
  }
  return out.toString();
}

class MedicalReportPdfService {
  Future<void> _sharePdfFile(String path, String subject) async {
    if (kIsWeb) return;
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          subject: subject,
        ),
      );
    } catch (e, st) {
      debugPrint('MedicalReportPdfService._sharePdfFile failed: $e\n$st');
    }
  }

  Future<String> generateAnalysisPdf({
    required MedicalAnalysisResult analysis,
    required String sourceSnippet,
    String shareSubject = 'SmartScan - Rapport medical',
  }) async {
    final doc = pw.Document();
    final now = DateTime.now();

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(24),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
          ),
        ),
        build: (context) => [
          pw.Text(
            'SmartScan - Rapport medical (infos importantes)',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Date: ${now.toIso8601String()}'),
          pw.SizedBox(height: 16),
          pw.Text(
            'Resume',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          ),
          pw.SizedBox(height: 4),
          pw.Text(_latin1ForPdf(analysis.summary)),
          pw.SizedBox(height: 14),
          pw.Text(
            'Elements importants',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          ),
          pw.SizedBox(height: 8),
          if (analysis.importantFindings.isEmpty)
            pw.Text('Aucun element structure detecte.')
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Test', 'Valeur', 'Unite', 'Reference', 'Statut'],
              data: analysis.importantFindings
                  .map(
                    (f) => [
                      _safeCell(f.testName),
                      _safeCell(f.value),
                      _safeCell(f.unit),
                      _safeCell(f.reference),
                      _safeCell(f.status),
                    ],
                  )
                  .toList(growable: false),
              cellAlignment: pw.Alignment.centerLeft,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Recommandations',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          ),
          pw.SizedBox(height: 4),
          pw.Text(_latin1ForPdf(analysis.recommendations)),
          pw.SizedBox(height: 14),
          pw.Text(
            'Avertissement',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          ),
          pw.SizedBox(height: 4),
          pw.Text(_latin1ForPdf(analysis.disclaimer)),
          pw.SizedBox(height: 14),
          pw.Text(
            'Extrait du texte source (OCR)',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          ),
          pw.SizedBox(height: 4),
          pw.Text(_latin1ForPdf(sourceSnippet)),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final safeTimestamp = now.toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/medical_summary_$safeTimestamp.pdf');
    await file.writeAsBytes(await doc.save(), flush: true);
    await _sharePdfFile(file.path, shareSubject);
    return file.path;
  }

  Future<String> generateStructuredReportPdf({
    required MedicalReport report,
    bool includeRawText = true,
    bool includeRawJson = false,
    String shareSubject = 'SmartScan - Rapport medical',
  }) async {
    final doc = pw.Document();
    final now = DateTime.now();
    doc.addPage(
      pw.MultiPage(
        pageTheme: _defaultPageTheme(),
        build: (context) => [
          _buildLabHeader(report, now),
          pw.SizedBox(height: 12),
          _buildPatientSummary(report),
          pw.SizedBox(height: 12),
          _buildSummaryStats(report),
          pw.SizedBox(height: 12),
          pw.Text(
            'Resultats principaux',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColors.blue800),
          ),
          pw.SizedBox(height: 6),
          _buildMainResultsTable(report),
          pw.SizedBox(height: 10),
          pw.Text(
            'Document genere automatiquement par SmartScan ML Kit.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageTheme: _defaultPageTheme(),
        build: (context) => [
          pw.Text(
            'Annexe detaillee par section',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
          ),
          pw.SizedBox(height: 8),
          ...report.sections.expand((section) => _buildDetailedSection(section)),
        ],
      ),
    );

    if (includeRawText) {
      doc.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Text('Annexe - Texte OCR brut', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 8),
            ..._buildChunkedText(report.rawText),
          ],
        ),
      );
    }

    if (includeRawJson) {
      final prettyJson = const JsonEncoder.withIndent('  ').convert(report.toJson());
      doc.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Text('Annexe - JSON brut', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 8),
            ..._buildChunkedText(prettyJson),
          ],
        ),
      );
    }

    final dir = await getTemporaryDirectory();
    final safeTimestamp = now.toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/medical_report_$safeTimestamp.pdf');
    await file.writeAsBytes(await doc.save(), flush: true);
    await _sharePdfFile(file.path, shareSubject);
    return file.path;
  }

  pw.PageTheme _defaultPageTheme() {
    return pw.PageTheme(
      margin: const pw.EdgeInsets.all(24),
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
    );
  }

  pw.Widget _buildLabHeader(MedicalReport report, DateTime now) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blue700, width: 1.2),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                _latin1ForPdf(report.labInfo.name ?? 'Laboratoire'),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
              ),
              pw.Text(_latin1ForPdf(report.labInfo.address ?? '-'), style: const pw.TextStyle(fontSize: 10)),
              pw.Text(
                _latin1ForPdf('Tel: ${report.labInfo.phone ?? '-'} | Email: ${report.labInfo.email ?? '-'}'),
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('COMPTE-RENDU LABORATOIRE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Genere le: ${now.toIso8601String().substring(0, 19)}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text(_latin1ForPdf('Source: ${report.sourceFileName}'), style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPatientSummary(MedicalReport report) {
    pw.Widget row(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          children: [
            pw.SizedBox(
              width: 120,
              child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            ),
            pw.Expanded(child: pw.Text(_latin1ForPdf(value), style: const pw.TextStyle(fontSize: 10))),
          ],
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Resume patient', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
          pw.SizedBox(height: 6),
          row('Patient', report.patientInfo.fullName ?? '-'),
          row('Code patient', report.patientInfo.codePatient ?? '-'),
          row('Dossier', report.patientInfo.dossierNumber ?? '-'),
          row('Demandeur', report.doctorInfo.requesterName ?? '-'),
          row('Validateur', report.doctorInfo.validatorName ?? '-'),
          row('Date rapport', report.reportInfo.reportDate ?? '-'),
          row('Date prelevement', report.reportInfo.sampleDate ?? '-'),
          row('Numero examen', report.reportInfo.examNumber ?? '-'),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryStats(MedicalReport report) {
    final all = report.sections.expand((s) => s.analyses).where((a) => _isPdfSafeAnalysisName(a.name)).toList();
    final abnormal = all.where((a) => a.abnormalFlag == AbnormalFlag.high || a.abnormalFlag == AbnormalFlag.low).length;
    return pw.Row(
      children: [
        _metricCard('Sections', '${report.sections.length}'),
        pw.SizedBox(width: 8),
        _metricCard('Analyses', '${all.length}'),
        pw.SizedBox(width: 8),
        _metricCard('Anormales', '$abnormal'),
        pw.SizedBox(width: 8),
        _metricCard('Confiance', '${(report.confidence * 100).toStringAsFixed(1)} %'),
      ],
    );
  }

  pw.Widget _metricCard(String title, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          children: [
            pw.Text(title, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 2),
            pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildMainResultsTable(MedicalReport report) {
    final topRows = report.sections
        .expand((s) => s.analyses.map((a) => (section: s.title, analysis: a)))
        .where((item) => _isPdfSafeAnalysisName(item.analysis.name))
        .take(18)
        .map(
          (item) => [
            _safeCell(item.section),
            _safeCell(item.analysis.name),
            _safeCell(item.analysis.value ?? '-'),
            _safeCell(item.analysis.unit ?? '-'),
            _safeCell(item.analysis.referenceText ?? '-'),
            _safeCell(item.analysis.abnormalFlag.name),
          ],
        )
        .toList(growable: false);

    if (topRows.isEmpty) {
      return pw.Text('Aucune analyse detectee.');
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.1),
        1: pw.FlexColumnWidth(2.8),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.2),
        4: pw.FlexColumnWidth(2.1),
        5: pw.FlexColumnWidth(1.1),
      },
      children: [
        _tableHeader(['Section', 'Analyse', 'Valeur', 'Unite', 'Reference', 'Statut']),
        ...topRows.map(_tableRow),
      ],
    );
  }

  List<pw.Widget> _buildDetailedSection(MedicalSection section) {
    final filtered = section.analyses
        .where((a) => _isPdfSafeAnalysisName(a.name))
        .toList(growable: false);
    final rows = filtered
        .map(
          (a) => <String>[
            _safeCell(a.name),
            _safeCell(a.value ?? '-'),
            _safeCell(a.unit ?? '-'),
            _safeCell(a.referenceText ?? '-'),
            _safeCell(a.previousValue ?? '-'),
            _safeCell(a.interpretation ?? a.abnormalFlag.name),
          ],
        )
        .toList(growable: false);

    final out = <pw.Widget>[
      pw.Text(_latin1ForPdf(section.title), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
      pw.SizedBox(height: 6),
    ];
    if (rows.isEmpty) {
      out.add(pw.Text('Aucune analyse detectee.'));
      out.add(pw.SizedBox(height: 12));
      return out;
    }

    const chunkSize = 10;
    for (var i = 0; i < rows.length; i += chunkSize) {
      final end = (i + chunkSize < rows.length) ? i + chunkSize : rows.length;
      out.add(
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(2.5),
            1: pw.FlexColumnWidth(1.2),
            2: pw.FlexColumnWidth(1.1),
            3: pw.FlexColumnWidth(2.0),
            4: pw.FlexColumnWidth(1.3),
            5: pw.FlexColumnWidth(1.9),
          },
          children: [
            _tableHeader(['Analyse', 'Valeur', 'Unite', 'Reference', 'Anterio', 'Interpretation']),
            ...rows.sublist(i, end).map(_tableRow),
          ],
        ),
      );
      out.add(pw.SizedBox(height: 8));
    }
    out.add(pw.SizedBox(height: 4));
    return out;
  }

  pw.TableRow _tableHeader(List<String> values) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.blue50),
      children: values
          .map(
            (v) => pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                _latin1ForPdf(v),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  pw.TableRow _tableRow(List<String> values) {
    return pw.TableRow(
      children: values
          .map(
            (v) => pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(_latin1ForPdf(v), style: const pw.TextStyle(fontSize: 8.7)),
            ),
          )
          .toList(growable: false),
    );
  }

  List<pw.Widget> _buildChunkedText(String rawText) {
    final normalized = rawText.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) {
      return [pw.Text('-')];
    }

    const maxChunkChars = 1800;
    final chunks = <String>[];
    final lines = normalized.split('\n');
    final buffer = StringBuffer();

    for (final line in lines) {
      final safeLine = line.trimRight();
      if ((buffer.length + safeLine.length + 1) > maxChunkChars && buffer.isNotEmpty) {
        chunks.add(buffer.toString());
        buffer.clear();
      }
      buffer.writeln(safeLine);
    }
    if (buffer.isNotEmpty) {
      chunks.add(buffer.toString());
    }

    return chunks
        .map(
          (chunk) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Text(_latin1ForPdf(chunk), style: const pw.TextStyle(fontSize: 10)),
          ),
        )
        .toList(growable: false);
  }

  String _safeCell(String text) {
    final normalized = text.replaceAll('\n', ' ').trim();
    if (normalized.isEmpty) return '-';
    const maxLen = 90;
    final truncated =
        normalized.length <= maxLen ? normalized : '${normalized.substring(0, maxLen - 1)}...';
    return _latin1ForPdf(truncated);
  }

  bool _isPdfSafeAnalysisName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    final letters = RegExp(r'[a-zA-Z]').allMatches(trimmed).length;
    if (letters < 3) return false;
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('s1.') || lower.startsWith(r'$1.')) return false;
    return true;
  }
}
