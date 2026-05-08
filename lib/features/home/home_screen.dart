import 'package:flutter/material.dart';

import '../../core/scan_history_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_surfaces.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.localeCode,
    required this.userName,
    required this.scanHistoryStore,
    required this.onOpenScanner,
    required this.onOpenDocuments,
    required this.onOpenHistory,
    required this.onOpenDashboard,
    super.key,
  });

  final String localeCode;
  final String userName;
  final ScanHistoryStore scanHistoryStore;
  final VoidCallback onOpenScanner;
  final VoidCallback onOpenDocuments;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenDashboard;

  bool get _isFrench => localeCode == 'fr';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isFrench ? 'Accueil' : 'Home'),
        actions: [
          IconButton(
            onPressed: onOpenDashboard,
            icon: const Icon(Icons.insights_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AppBackdrop(
        child: SafeArea(
          top: false,
          child: AnimatedBuilder(
            animation: scanHistoryStore,
            builder: (context, _) {
              final entries = scanHistoryStore.entries
                  .where((entry) => !entry.isDeleted)
                  .toList(growable: false);
              final recentEntries = entries.take(3).toList(growable: false);
              final languages = entries
                  .expand((entry) => entry.detectedLanguages)
                  .where(
                    (code) =>
                        code.trim().isNotEmpty && code.trim() != 'unknown',
                  )
                  .toSet();
              final averageConfidence = _averageConfidence(entries);

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                children: [
                  Text(
                    _isFrench ? 'Bonjour $userName !' : 'Hello $userName!',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isFrench
                        ? 'Que souhaitez-vous faire aujourd hui ?'
                        : 'What would you like to do today?',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 18),
                  _HomeActionCard(
                    title: _isFrench
                        ? 'Scanner un document'
                        : 'Scan a document',
                    subtitle: _isFrench
                        ? 'Utiliser la camera pour numeriser un document'
                        : 'Use the camera to digitize a document',
                    icon: Icons.document_scanner_rounded,
                    accent: AppThemePalette.primary,
                    onTap: onOpenScanner,
                  ),
                  const SizedBox(height: 12),
                  _HomeActionCard(
                    title: _isFrench
                        ? 'Importer PDF / Image'
                        : 'Import PDF / Image',
                    subtitle: _isFrench
                        ? 'Retrouver tous vos dossiers, tags et statuts'
                        : 'Access folders, tags and status tracking',
                    icon: Icons.folder_copy_rounded,
                    accent: AppThemePalette.secondary,
                    onTap: onOpenDocuments,
                    secondary: true,
                  ),
                  const SizedBox(height: 12),
                  _HomeActionCard(
                    title: _isFrench ? 'Dashboard BI' : 'BI Dashboard',
                    subtitle: _isFrench
                        ? 'Suivre KPI, activite recente et qualite OCR'
                        : 'Track KPI, recent activity and OCR quality',
                    icon: Icons.insights_rounded,
                    accent: AppThemePalette.tertiary,
                    onTap: onOpenDashboard,
                  ),
                  const SizedBox(height: 22),
                  AppSectionHeader(
                    eyebrow: _isFrench ? 'Apercu rapide' : 'Quick overview',
                    title: _isFrench ? 'Apercu rapide' : 'Quick overview',
                    trailing: TextButton(
                      onPressed: onOpenDashboard,
                      child: Text(_isFrench ? 'Voir BI' : 'Open BI'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppStatTile(
                          icon: Icons.description_outlined,
                          value: '${entries.length}',
                          label: _isFrench ? 'Documents traites' : 'Documents',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppStatTile(
                          icon: Icons.language_rounded,
                          value: '${languages.length}',
                          label: _isFrench ? 'Langues' : 'Languages',
                          hint: languages.isEmpty
                              ? 'FR / EN / AR'
                              : languages.join(' / ').toUpperCase(),
                          accent: AppThemePalette.secondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppStatTile(
                          icon: Icons.verified_rounded,
                          value: averageConfidence == null
                              ? '95%'
                              : '${(averageConfidence * 100).toStringAsFixed(0)}%',
                          label: _isFrench ? 'Precision OCR' : 'OCR quality',
                          accent: AppThemePalette.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  AppSectionHeader(
                    eyebrow: _isFrench
                        ? 'Documents recents'
                        : 'Recent documents',
                    title: _isFrench ? 'Documents recents' : 'Recent documents',
                    trailing: TextButton(
                      onPressed: onOpenHistory,
                      child: Text(_isFrench ? 'Voir tout' : 'View all'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (recentEntries.isEmpty)
                    AppEmptyState(
                      icon: Icons.description_outlined,
                      title: _isFrench
                          ? 'Aucun document traite pour le moment'
                          : 'No processed document yet',
                      subtitle: _isFrench
                          ? 'Scannez ou importez un premier document pour alimenter votre espace.'
                          : 'Scan or import your first document to start your workspace.',
                      action: FilledButton.icon(
                        onPressed: onOpenScanner,
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: Text(_isFrench ? 'Commencer' : 'Start'),
                      ),
                    )
                  else
                    ...recentEntries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppPanel(
                          onTap: onOpenDocuments,
                          padding: const EdgeInsets.all(16),
                          radius: 24,
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  entry.displayName.toLowerCase().endsWith(
                                        '.pdf',
                                      )
                                      ? Icons.picture_as_pdf_rounded
                                      : Icons.image_rounded,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${entry.documentTypeLabel} · ${entry.detectedLanguages.join(' / ').toUpperCase()}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(entry.createdAtIso),
                                style: theme.textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  double? _averageConfidence(List<ScanHistoryEntry> entries) {
    final values = entries
        .map((entry) => entry.ocrConfidence)
        .whereType<double>()
        .toList(growable: false);
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  String _formatDate(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) return iso;
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month';
  }
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.secondary = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      onTap: onTap,
      radius: 26,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: secondary
            ? <Color>[
                const Color(0xFFF3FFFD),
                AppThemePalette.secondary.withValues(alpha: 0.12),
              ]
            : <Color>[const Color(0xFFF3F7FF), accent.withValues(alpha: 0.12)],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 18,
          ),
        ],
      ),
    );
  }
}
