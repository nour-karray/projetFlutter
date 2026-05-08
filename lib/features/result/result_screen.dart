import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_feedback_service.dart';
import '../../core/app_localizations.dart';
import '../../core/medical_ai_service.dart';
import '../../core/mlkit_language_service.dart';
import '../../core/medical_report_pdf_service.dart';
import '../../core/scan_result_store.dart';
import '../../models/medical_report.dart';
import '../../widgets/app_surfaces.dart';
import '../../widgets/medical_report_widgets.dart';

const Object _resultImageHeroTag = 'smartscan_result_preview';

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    required this.localeCode,
    required this.scanResultStore,
    required this.geminiApiKey,
    super.key,
  });

  final String localeCode;
  final ScanResultStore scanResultStore;
  final String geminiApiKey;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _GeminiAnalysisCards extends StatelessWidget {
  const _GeminiAnalysisCards({
    required this.localeCode,
    required this.analysis,
  });

  final String localeCode;
  final MedicalAnalysisResult analysis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodyMedium;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPanel(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.summarize_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.t(localeCode, 'resultAiSummary'),
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SelectableText(analysis.summary, style: bodyStyle),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        AppPanel(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.recommend_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.t(localeCode, 'resultAiRecommendations'),
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SelectableText(analysis.recommendations, style: bodyStyle),
              ],
            ),
          ),
        ),
        if (analysis.importantFindings.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppPanel(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_outlined,
                        color: theme.colorScheme.tertiary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.t(localeCode, 'resultAiImportant'),
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...analysis.importantFindings.map(
                    (finding) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SelectableText(
                        '- ${finding.testName}: ${finding.value} ${finding.unit} (${finding.status})',
                        style: bodyStyle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ResultScreenState extends State<ResultScreen> {
  static const bool _showAiOptionalSection = false;
  final MedicalReportPdfService _pdfService = MedicalReportPdfService();
  final MlKitLanguageService _mlKitLanguageService = MlKitLanguageService();
  bool _isAnalyzing = false;
  bool _isTranslating = false;
  MedicalAnalysisResult? _analysisResult;
  String? _lastPdfPath;
  String? _translatedText;
  String? _translatedTo;
  bool _useTranslatedForGemini = false;
  MedicalReport? _translatedReport;

  String get _lc => widget.localeCode;

  String _shareSubject() => AppLocalizations.t(_lc, 'medicalPdfShareSubject');

  String _medicalOnlyMessage() {
    switch (_lc) {
      case 'en':
        return 'This action is available only for detected medical analysis reports.';
      case 'ar':
        return 'هذا الإجراء متاح فقط عندما يتم اكتشاف أن المستند تحليل طبي.';
      default:
        return 'Cette action est disponible uniquement si le document est detecte comme analyse medicale.';
    }
  }

  void _showPdfReadySnack(String messageKey) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.t(_lc, messageKey)),
        action: SnackBarAction(
          label: AppLocalizations.t(_lc, 'shareAgain'),
          onPressed: () => _sharePdfAgain(),
        ),
      ),
    );
  }

  Future<void> _sharePdfAgain() async {
    AppFeedbackService.instance.tap();
    final path = _lastPdfPath;
    if (path == null) return;
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path)], subject: _shareSubject()),
      );
    } catch (e, st) {
      debugPrint('_sharePdfAgain failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.t(_lc, 'errorPdfExport')}: $e'),
        ),
      );
    }
  }

  Future<void> _analyzeAndGeneratePdf() async {
    AppFeedbackService.instance.tap();
    final report = widget.scanResultStore.medicalReport;
    if (report == null || report.documentType != DocumentType.medicalReport) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_medicalOnlyMessage())));
      return;
    }

    if (widget.geminiApiKey.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t(_lc, 'addGeminiKeyFirst'))),
      );
      return;
    }

    final rawText = widget.scanResultStore.extractedText?.trim() ?? '';
    final translated = _translatedText?.trim() ?? '';
    final text = (_useTranslatedForGemini && translated.isNotEmpty)
        ? translated
        : rawText;
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t(_lc, 'noOcrText'))),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisResult = null;
      _lastPdfPath = null;
    });
    try {
      final medicalAiService = MedicalAiService(apiKey: widget.geminiApiKey);
      final analysis = await medicalAiService.analyzeMedicalText(text);
      if (!mounted) return;
      final extractedEntities = await medicalAiService
          .extractMedicalReportEntities(text);
      if (!mounted) return;
      final existingReport = widget.scanResultStore.medicalReport;
      if (existingReport != null) {
        final updatedReport = existingReport.copyWith(
          patientInfo: existingReport.patientInfo.copyWith(
            fullName:
                extractedEntities.patientName ??
                existingReport.patientInfo.fullName,
            codePatient:
                extractedEntities.codePatient ??
                existingReport.patientInfo.codePatient,
            organism:
                extractedEntities.organism ??
                existingReport.patientInfo.organism,
          ),
          doctorInfo: existingReport.doctorInfo.copyWith(
            requesterName:
                extractedEntities.requesterDoctor ??
                existingReport.doctorInfo.requesterName,
            validatorName:
                extractedEntities.validatorDoctor ??
                existingReport.doctorInfo.validatorName,
          ),
          confidence:
              (existingReport.confidence + extractedEntities.confidence) / 2,
        );
        widget.scanResultStore.updateMedicalReport(updatedReport);
      }
      final snippet = text.length > 1200
          ? '${text.substring(0, 1200)}...'
          : text;
      final pdfPath = await _pdfService.generateAnalysisPdf(
        analysis: analysis,
        sourceSnippet: snippet,
        shareSubject: _shareSubject(),
      );
      if (!mounted) return;
      setState(() {
        _analysisResult = analysis;
        _lastPdfPath = pdfPath;
      });
      _showPdfReadySnack('analysisDonePdfGenerated');
    } catch (e, st) {
      debugPrint('_analyzeAndGeneratePdf: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.t(_lc, 'errorGeminiAnalysis')}: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  Future<void> _translateOcrText(String targetLanguageCode) async {
    AppFeedbackService.instance.tap();
    final sourceText = widget.scanResultStore.extractedText?.trim() ?? '';
    if (sourceText.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t(_lc, 'noOcrText'))),
      );
      return;
    }
    final sourceCode = widget.scanResultStore.detectedLanguageCode;
    if (sourceCode == targetLanguageCode) {
      setState(() {
        _translatedText = sourceText;
        _translatedTo = targetLanguageCode;
        _translatedReport = widget.scanResultStore.medicalReport;
      });
      return;
    }

    setState(() {
      _isTranslating = true;
    });
    try {
      final translated = await _mlKitLanguageService.translateTo(
        text: sourceText,
        sourceLanguageCode: sourceCode == 'unknown' ? 'en' : sourceCode,
        targetLanguageCode: targetLanguageCode,
      );
      if (!mounted) return;
      setState(() {
        _translatedText = translated;
        _translatedTo = targetLanguageCode;
      });
      final report = widget.scanResultStore.medicalReport;
      if (report != null) {
        final translatedReport = await _translateStructuredReport(
          report: report,
          sourceLanguageCode: sourceCode == 'unknown' ? 'en' : sourceCode,
          targetLanguageCode: targetLanguageCode,
        );
        if (!mounted) return;
        setState(() {
          _translatedReport = translatedReport;
        });
      } else {
        setState(() {
          _translatedReport = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur traduction: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
      }
    }
  }

  Future<MedicalReport> _translateStructuredReport({
    required MedicalReport report,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) async {
    final texts = <String>[
      report.labInfo.name ?? '',
      report.labInfo.address ?? '',
      report.labInfo.city ?? '',
      report.patientInfo.organism ?? '',
      report.doctorInfo.validatorName ?? '',
      ...report.sections.map((s) => s.title),
      ...report.sections.expand((s) => s.analyses).map((a) => a.name),
      ...report.sections
          .expand((s) => s.analyses)
          .map((a) => a.referenceText ?? ''),
      ...report.sections
          .expand((s) => s.analyses)
          .map((a) => a.technique ?? ''),
      ...report.sections
          .expand((s) => s.analyses)
          .map((a) => a.interpretation ?? ''),
    ];

    final translated = await _mlKitLanguageService.translateBatch(
      texts: texts,
      sourceLanguageCode: sourceLanguageCode,
      targetLanguageCode: targetLanguageCode,
    );
    var i = 0;
    String next() => translated[i++];

    final translatedLab = report.labInfo.copyWith(
      name: next(),
      address: next(),
      city: next(),
    );
    final translatedPatient = report.patientInfo.copyWith(organism: next());
    final translatedDoctor = report.doctorInfo.copyWith(validatorName: next());

    final translatedSections = <MedicalSection>[];
    for (final section in report.sections) {
      final translatedTitle = next();
      final translatedAnalyses = <MedicalAnalysis>[];
      for (final analysis in section.analyses) {
        translatedAnalyses.add(
          analysis.copyWith(
            name: next(),
            referenceText: next(),
            technique: next(),
            interpretation: next(),
          ),
        );
      }
      translatedSections.add(
        section.copyWith(title: translatedTitle, analyses: translatedAnalyses),
      );
    }

    return report.copyWith(
      labInfo: translatedLab,
      patientInfo: translatedPatient,
      doctorInfo: translatedDoctor,
      sections: translatedSections,
    );
  }

  Future<void> _exportStructuredPdf() async {
    AppFeedbackService.instance.tap();
    final report = _translatedReport ?? widget.scanResultStore.medicalReport;
    if (report == null) return;
    try {
      final path = await _pdfService.generateStructuredReportPdf(
        report: report,
        includeRawText: true,
        includeRawJson: false,
        shareSubject: _shareSubject(),
      );
      if (!mounted) return;
      setState(() => _lastPdfPath = path);
      _showPdfReadySnack('structuredPdfExported');
    } catch (e, st) {
      debugPrint('_exportStructuredPdf: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.t(_lc, 'errorPdfExport')}: $e'),
        ),
      );
    }
  }

  void _openFullscreenImage() {
    AppFeedbackService.instance.tap();
    final bytes = widget.scanResultStore.imageBytes;
    if (bytes == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 6,
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton.filled(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRawOcr() {
    AppFeedbackService.instance.tap();
    final raw = widget.scanResultStore.extractedText ?? '';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.t(_lc, 'rawOcrDialogTitle')),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: SelectableText(
              raw,
              style: Theme.of(dialogContext).textTheme.bodyMedium,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppLocalizations.t(_lc, 'close')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.t(_lc, 'result'))),
      body: AppBackdrop(
        child: AnimatedBuilder(
          animation: widget.scanResultStore,
          builder: (context, _) {
            final report = widget.scanResultStore.medicalReport;
            final viewReport = _translatedReport ?? report;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.scanResultStore.isProcessing)
                  const LinearProgressIndicator(minHeight: 3),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                    children: [
                      if (widget.scanResultStore.imageBytes != null) ...[
                        Hero(
                          tag: _resultImageHeroTag,
                          child: Material(
                            color: Colors.transparent,
                            child: GestureDetector(
                              onTap: _openFullscreenImage,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.shadow.withValues(
                                        alpha: 0.12,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: SizedBox(
                                    height: 220,
                                    width: double.infinity,
                                    child: Image.memory(
                                      widget.scanResultStore.imageBytes!,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.t(_lc, 'detectedText'),
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '${AppLocalizations.t(_lc, 'detectedLanguage')}: ',
                          ),
                          Chip(
                            label: Text(
                              AppLocalizations.detectedLanguageLabel(
                                widget.scanResultStore.detectedLanguageCode,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(AppLocalizations.t(_lc, 'detectedLanguages')),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.scanResultStore.detectedLanguageCodes
                            .map(
                              (code) => Chip(
                                label: Text(
                                  AppLocalizations.detectedLanguageLabel(code),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Traduction OCR (ML Kit)',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton.tonal(
                                    onPressed: _isTranslating
                                        ? null
                                        : () => _translateOcrText('fr'),
                                    child: const Text('FR'),
                                  ),
                                  FilledButton.tonal(
                                    onPressed: _isTranslating
                                        ? null
                                        : () => _translateOcrText('en'),
                                    child: const Text('EN'),
                                  ),
                                  FilledButton.tonal(
                                    onPressed: _isTranslating
                                        ? null
                                        : () => _translateOcrText('ar'),
                                    child: const Text('AR'),
                                  ),
                                ],
                              ),
                              if (_isTranslating) ...[
                                const SizedBox(height: 12),
                                const LinearProgressIndicator(),
                              ],
                              if (_translatedText != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Texte traduit (${_translatedTo ?? '-'})',
                                  style: theme.textTheme.titleSmall,
                                ),
                                const SizedBox(height: 8),
                                SelectableText(
                                  _translatedText!,
                                  style: theme.textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        final messenger = ScaffoldMessenger.of(
                                          context,
                                        );
                                        await Clipboard.setData(
                                          ClipboardData(text: _translatedText!),
                                        );
                                        if (!mounted) return;
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text('Traduction copiee.'),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.copy_outlined),
                                      label: const Text('Copier'),
                                    ),
                                    FilterChip(
                                      label: const Text('Utiliser pour Gemini'),
                                      selected: _useTranslatedForGemini,
                                      onSelected: (value) {
                                        setState(() {
                                          _useTranslatedForGemini = value;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (viewReport == null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: SelectableText(
                              widget.scanResultStore.isProcessing
                                  ? AppLocalizations.t(_lc, 'ocrProcessing')
                                  : widget.scanResultStore.extractedText ??
                                        widget.scanResultStore.errorMessage ??
                                        AppLocalizations.t(_lc, 'noResult'),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ),
                      if (viewReport != null) ...[
                        MedicalSummaryCard(report: viewReport),
                        MedicalInfoCard(
                          title: AppLocalizations.t(
                            _lc,
                            'medicalPatientInfoTitle',
                          ),
                          lines: [
                            '${AppLocalizations.t(_lc, 'labelPatient')}: ${viewReport.patientInfo.fullName ?? '-'}',
                            '${AppLocalizations.t(_lc, 'labelDossier')}: ${viewReport.patientInfo.dossierNumber ?? '-'}',
                            '${AppLocalizations.t(_lc, 'labelOrganisme')}: ${viewReport.patientInfo.organism ?? '-'}',
                          ],
                        ),
                        MedicalInfoCard(
                          title: AppLocalizations.t(_lc, 'medicalDocInfoTitle'),
                          lines: [
                            '${AppLocalizations.t(_lc, 'labelLaboratoire')}: ${viewReport.labInfo.name ?? '-'}',
                            '${AppLocalizations.t(_lc, 'labelRequester')}: ${viewReport.doctorInfo.requesterName ?? '-'}',
                            '${AppLocalizations.t(_lc, 'labelValidator')}: ${viewReport.doctorInfo.validatorName ?? '-'}',
                            '${AppLocalizations.t(_lc, 'labelReportDate')}: ${viewReport.reportInfo.reportDate ?? '-'}',
                            '${AppLocalizations.t(_lc, 'labelSampleDate')}: ${viewReport.reportInfo.sampleDate ?? '-'}',
                            '${AppLocalizations.t(_lc, 'labelExamNumber')}: ${viewReport.reportInfo.examNumber ?? '-'}',
                          ],
                        ),
                        ...viewReport.sections.map(
                          (section) => MedicalSectionCard(section: section),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _exportStructuredPdf,
                                    icon: const Icon(Icons.picture_as_pdf),
                                    label: Text(
                                      AppLocalizations.t(_lc, 'exportPdf'),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _showRawOcr,
                                    icon: const Icon(
                                      Icons.text_snippet_outlined,
                                    ),
                                    label: Text(
                                      AppLocalizations.t(_lc, 'viewRawOcr'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      if (_showAiOptionalSection)
                        Card(
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          child: ExpansionTile(
                            leading: Icon(
                              Icons.auto_awesome_outlined,
                              color: colorScheme.primary,
                            ),
                            title: Text(
                              AppLocalizations.t(
                                _lc,
                                'geminiOptionalSectionTitle',
                              ),
                            ),
                            subtitle: Text(
                              AppLocalizations.t(
                                _lc,
                                'geminiOptionalSectionSubtitle',
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            initiallyExpanded: false,
                            childrenPadding: const EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              16,
                            ),
                            children: [
                              if (widget.geminiApiKey.trim().isEmpty)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    Icons.info_outline,
                                    color: colorScheme.primary,
                                  ),
                                  title: Text(
                                    AppLocalizations.t(
                                      _lc,
                                      'geminiKeyRequiredTitle',
                                    ),
                                  ),
                                  subtitle: Text(
                                    AppLocalizations.t(
                                      _lc,
                                      'geminiKeyRequiredSubtitle',
                                    ),
                                  ),
                                ),
                              if (_isAnalyzing) const LinearProgressIndicator(),
                              if (widget.geminiApiKey.trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                if (viewReport == null ||
                                    viewReport.documentType !=
                                        DocumentType.medicalReport)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      Icons.info_outline,
                                      color: colorScheme.primary,
                                    ),
                                    title: Text(_medicalOnlyMessage()),
                                  ),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        _isAnalyzing ||
                                            viewReport == null ||
                                            viewReport.documentType !=
                                                DocumentType.medicalReport
                                        ? null
                                        : _analyzeAndGeneratePdf,
                                    icon: const Icon(
                                      Icons.health_and_safety_outlined,
                                    ),
                                    label: Text(
                                      _isAnalyzing
                                          ? AppLocalizations.t(
                                              _lc,
                                              'analyzingGemini',
                                            )
                                          : AppLocalizations.t(
                                              _lc,
                                              'analyzeGeminiPdf',
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                              if (_analysisResult != null) ...[
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 8),
                                _GeminiAnalysisCards(
                                  localeCode: _lc,
                                  analysis: _analysisResult!,
                                ),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
