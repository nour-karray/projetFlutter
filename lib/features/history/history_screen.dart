import 'package:flutter/material.dart';

import '../../core/app_localizations.dart';
import '../../core/scan_history_store.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    required this.localeCode,
    required this.scanHistoryStore,
    required this.onOpenResultRequested,
    super.key,
  });

  final String localeCode;
  final ScanHistoryStore scanHistoryStore;
  final ValueChanged<ScanHistoryEntry> onOpenResultRequested;

  String get _lc => localeCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.t(_lc, 'history'))),
      body: AnimatedBuilder(
        animation: scanHistoryStore,
        builder: (context, _) {
          final entries = scanHistoryStore.entries;
          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history_toggle_off_outlined,
                      size: 80,
                      color: colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.t(_lc, 'historyEmpty'),
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.t(_lc, 'historyEmptySubtitle'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                child: Text(
                  AppLocalizations.t(_lc, 'historySectionTitle'),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              ),
              ...List.generate(entries.length, (index) {
                final entry = entries[index];
                final structured = entry.structuredReport;
                final preview = (entry.resultSummary ?? entry.text).replaceAll('\n', ' ');
                final createdAt = DateTime.tryParse(entry.createdAtIso);
                final displayNum = entries.length - index;

                return Dismissible(
                  key: ValueKey('${entry.createdAtIso}_$index'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                  onDismissed: (_) {
                    scanHistoryStore.removeEntryAt(index);
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isThreeLine: true,
                      leading: SizedBox(
                        width: 56,
                        height: 56,
                        child: entry.imageBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  entry.imageBytes!,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : DecoratedBox(
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: colorScheme.outline,
                                ),
                              ),
                      ),
                      title: Text(
                        '${AppLocalizations.t(_lc, 'historyItem')} #$displayNum',
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (createdAt != null)
                            Text(
                              createdAt.toLocal().toString().split('.').first,
                              style: theme.textTheme.bodySmall,
                            ),
                          const SizedBox(height: 4),
                          if (entry.detectedLanguages.isNotEmpty) ...[
                            Text(
                              '${AppLocalizations.t(_lc, 'detectedLanguages')}:',
                              style: theme.textTheme.labelSmall,
                            ),
                            const SizedBox(height: 2),
                            Wrap(
                              spacing: 4,
                              runSpacing: 2,
                              children: entry.detectedLanguages
                                  .map(
                                    (code) => Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text(
                                        AppLocalizations.detectedLanguageLabel(code),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            preview.length > 100
                                ? '${preview.substring(0, 100)}...'
                                : preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                          if (entry.resultSummary != null && entry.resultSummary!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              entry.resultSummary!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: Icon(Icons.chevron_right, color: colorScheme.outline),
                      onTap: () {
                        showDialog<void>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text(
                              '${AppLocalizations.t(_lc, 'historyItem')} #$displayNum',
                            ),
                            content: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (entry.imageBytes != null) ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        entry.imageBytes!,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  if (entry.detectedLanguages.isNotEmpty) ...[
                                    Text(
                                      AppLocalizations.t(_lc, 'detectedLanguages'),
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: entry.detectedLanguages
                                          .map(
                                            (code) => Chip(
                                              label: Text(
                                                AppLocalizations.detectedLanguageLabel(
                                                  code,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  Text(
                                    'Resultat enregistre',
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 6),
                                  if (structured != null) ...[
                                    Text(
                                      'Type: ${structured.documentType.name}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    Text(
                                      'Confiance: ${(structured.confidence * 100).toStringAsFixed(1)}%',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    Text(
                                      'Sections: ${structured.sections.length}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    Text(
                                      'Analyses: ${structured.sections.fold<int>(0, (sum, section) => sum + section.analyses.length)}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 8),
                                    ...structured.sections.expand((s) => s.analyses).take(8).map(
                                          (a) => Text(
                                            '- ${a.name}: ${a.value ?? '-'} ${a.unit ?? ''}'.trim(),
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ),
                                  ] else ...[
                                    SelectableText(
                                      entry.text,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(AppLocalizations.t(_lc, 'close')),
                              ),
                              FilledButton.icon(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  onOpenResultRequested(entry);
                                },
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('Voir resultat complet'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
