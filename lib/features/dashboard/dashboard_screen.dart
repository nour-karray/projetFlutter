import 'package:flutter/material.dart';

import '../../core/app_localizations.dart';
import '../../core/scan_history_store.dart';
import '../../models/medical_report.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_surfaces.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    required this.localeCode,
    required this.scanHistoryStore,
    required this.userName,
    required this.onOpenDocuments,
    required this.onOpenHistory,
    required this.onOpenScanner,
    super.key,
  });

  final String localeCode;
  final ScanHistoryStore scanHistoryStore;
  final String userName;
  final VoidCallback onOpenDocuments;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenScanner;

  String get _lc => localeCode;

  bool get _fr => _lc != 'en' && _lc != 'ar';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_fr ? 'Tableau BI' : 'Analytics'),
      ),
      body: AppBackdrop(
        child: AnimatedBuilder(
          animation: scanHistoryStore,
          builder: (_, __) {
            final entries = scanHistoryStore.entries.where((e) => !e.isDeleted).toList();
            final pdfs =
                entries.where((e) => e.displayName.toLowerCase().endsWith('.pdf')).length;
            final langs = entries
                .expand((e) => e.detectedLanguages)
                .where((c) => c.trim().isNotEmpty && c != 'unknown')
                .toSet()
                .length;
            final double? avgOcr = _avgOcr(entries);

            int reportSections(MedicalReport? report) =>
                report == null ? 0 : report.sections.length;

            final structCount = entries.fold<int>(
              0,
              (acc, e) => acc + reportSections(e.structuredReport),
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                AppPanel(
                  gradient: AppThemePalette.heroGradient(
                    theme.brightness == Brightness.dark,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_fr ? 'Bonjour' : 'Hello'} $userName',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.t(_lc, 'homeDescription'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              onOpenScanner();
                            },
                            icon: const Icon(Icons.camera_alt_rounded),
                            label: Text(_fr ? 'Scanner' : 'Scan'),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              onOpenDocuments();
                            },
                            icon: const Icon(Icons.folder_copy_rounded),
                            label: Text(
                              AppLocalizations.t(_lc, 'documents'),
                            ),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              onOpenHistory();
                            },
                            icon: const Icon(Icons.history_rounded),
                            label: Text(
                              AppLocalizations.t(_lc, 'history'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: AppStatTile(
                        icon: Icons.description_rounded,
                        value: '${entries.length}',
                        label: AppLocalizations.t(_lc, 'documents'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppStatTile(
                        icon: Icons.picture_as_pdf_rounded,
                        value: '$pdfs',
                        label: _fr ? 'Fichiers PDF' : 'PDF files',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: AppStatTile(
                        icon: Icons.language_rounded,
                        value: '${langs}',
                        label: _fr ? 'Langues OCR' : 'OCR langs',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppStatTile(
                        icon: Icons.folder_special_rounded,
                        value: '$structCount',
                        label: _fr ? 'Sections struct.' : 'Struct. secs',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                AppPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fr ? 'Qualite OCR estimee' : 'Estimated OCR quality',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        avgOcr == null
                            ? (_fr
                                ? 'Importez vos premiers fichiers.'
                                : 'Import your first files.')
                            : '${(avgOcr * 100).toStringAsFixed(1)}%',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: AppThemePalette.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
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

  double? _avgOcr(List<ScanHistoryEntry> entries) {
    final vals =
        entries.map((e) => e.ocrConfidence).whereType<double>().toList();
    if (vals.isEmpty) return null;
    return vals.fold<double>(0, (a, b) => a + b) / vals.length;
  }
}
