import 'package:flutter/material.dart';

import '../../core/app_localizations.dart';
import '../../core/scan_history_store.dart';
import '../../widgets/app_surfaces.dart';

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({
    required this.localeCode,
    required this.scanHistoryStore,
    required this.onOpenScanner,
    required this.onOpenResultRequested,
    super.key,
  });

  final String localeCode;
  final ScanHistoryStore scanHistoryStore;
  final VoidCallback onOpenScanner;
  final ValueChanged<ScanHistoryEntry> onOpenResultRequested;

  String get _lc => localeCode;
  bool get _fr => _lc != 'en' && _lc != 'ar';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.t(_lc, 'documents'))),
      body: AppBackdrop(
        child: SafeArea(
          top: false,
          child: AnimatedBuilder(
            animation: scanHistoryStore,
            builder: (_, __) {
              final entries = scanHistoryStore.entries
                  .where((e) => !e.isDeleted)
                  .toList(growable: false);
              if (entries.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
                  children: [
                    AppEmptyState(
                      icon: Icons.folder_open_rounded,
                      title: _fr
                          ? 'Aucun document dans votre espace.'
                          : 'No documents yet.',
                      subtitle: _fr
                          ? AppLocalizations.t(_lc, 'homeHeroSubtitle')
                          : AppLocalizations.t(_lc, 'homeHeroSubtitle'),
                      action: FilledButton.icon(
                        onPressed: onOpenScanner,
                        icon: const Icon(Icons.photo_camera_rounded),
                        label: Text(_fr ? 'Scanner ou importer' : 'Scan / import'),
                      ),
                    ),
                  ],
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final entry = entries[i];
                  return AppPanel(
                    onTap: () => onOpenResultRequested(entry),
                    padding: const EdgeInsets.all(14),
                    radius: 22,
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            entry.displayName.toLowerCase().endsWith('.pdf')
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
                                '${entry.documentTypeLabel} · ${entry.folder}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
