import 'package:flutter/material.dart';

import '../../core/app_localizations.dart';
import '../../core/scan_history_store.dart';
import '../../models/medical_report.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_surfaces.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    required this.localeCode,
    required this.scanHistoryStore,
    required this.onOpenResultRequested,
    super.key,
  });

  final String localeCode;
  final ScanHistoryStore scanHistoryStore;
  final ValueChanged<ScanHistoryEntry> onOpenResultRequested;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _typeFilter = 'all';

  String get _lc => widget.localeCode;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _subtitle() {
    switch (_lc) {
      case 'en':
        return 'Reopen, review and export your latest processing history.';
      case 'ar':
        return 'أعد فتح ومراجعة وتصدير آخر سجل للمعالجة.';
      default:
        return 'Rouvrez, relisez et exportez rapidement votre historique recent.';
    }
  }

  List<MapEntry<int, ScanHistoryEntry>> _filteredEntries(
    List<ScanHistoryEntry> entries,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    return entries
        .asMap()
        .entries
        .where((entry) {
          final item = entry.value;
          if (item.isDeleted) {
            return false;
          }
          if (_typeFilter == 'pdf' &&
              !item.displayName.toLowerCase().endsWith('.pdf')) {
            return false;
          }
          if (_typeFilter == 'image') {
            final lower = item.displayName.toLowerCase();
            if (!lower.endsWith('.jpg') &&
                !lower.endsWith('.jpeg') &&
                !lower.endsWith('.png')) {
              return false;
            }
          }
          if (_typeFilter == 'translated' && item.status != 'translated') {
            return false;
          }
          if (query.isEmpty) return true;
          final haystack = <String>[
            item.displayName,
            item.documentTypeLabel,
            item.folder,
            item.tags.join(' '),
            item.text,
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.t(_lc, 'history'))),
      body: AppBackdrop(
        child: SafeArea(
          top: false,
          child: AnimatedBuilder(
            animation: widget.scanHistoryStore,
            builder: (context, _) {
              final entries = widget.scanHistoryStore.entries;
              final filtered = _filteredEntries(entries);
              if (filtered.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                  children: [
                    AppSectionHeader(
                      eyebrow: AppLocalizations.t(_lc, 'history'),
                      title: AppLocalizations.t(_lc, 'historyEmpty'),
                      subtitle: AppLocalizations.t(_lc, 'historyEmptySubtitle'),
                    ),
                    const SizedBox(height: 18),
                    AppEmptyState(
                      icon: Icons.history_toggle_off_rounded,
                      title: AppLocalizations.t(_lc, 'historyEmpty'),
                      subtitle: AppLocalizations.t(_lc, 'historyEmptySubtitle'),
                    ),
                  ],
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                children: [
                  AppPanel(
                    gradient: AppThemePalette.heroGradient(
                      theme.brightness == Brightness.dark,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.t(_lc, 'historySectionTitle'),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _subtitle(),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.86),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(
                            Icons.history_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: _lc == 'en'
                          ? 'Search a document'
                          : _lc == 'ar'
                          ? 'ابحث عن مستند'
                          : 'Rechercher un document',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.tune_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _HistoryFilterChip(
                          label: _lc == 'en'
                              ? 'All'
                              : _lc == 'ar'
                              ? 'الكل'
                              : 'Tous',
                          selected: _typeFilter == 'all',
                          onTap: () => setState(() => _typeFilter = 'all'),
                        ),
                        _HistoryFilterChip(
                          label: 'PDF',
                          selected: _typeFilter == 'pdf',
                          onTap: () => setState(() => _typeFilter = 'pdf'),
                        ),
                        _HistoryFilterChip(
                          label: _lc == 'en'
                              ? 'Images'
                              : _lc == 'ar'
                              ? 'صور'
                              : 'Images',
                          selected: _typeFilter == 'image',
                          onTap: () => setState(() => _typeFilter = 'image'),
                        ),
                        _HistoryFilterChip(
                          label: _lc == 'en'
                              ? 'Translated'
                              : _lc == 'ar'
                              ? 'مترجم'
                              : 'Traduits',
                          selected: _typeFilter == 'translated',
                          onTap: () =>
                              setState(() => _typeFilter = 'translated'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  ...filtered.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _HistoryEntryCard(
                        localeCode: _lc,
                        entry: entry.value,
                        onTap: () => _showEntryDialog(
                          context: context,
                          index: entry.key,
                          entry: entry.value,
                          structured: entry.value.structuredReport,
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showEntryDialog({
    required BuildContext context,
    required int index,
    required ScanHistoryEntry entry,
    required MedicalReport? structured,
  }) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: AppPanel(
          radius: 30,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(entry.displayName, style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              if (entry.imageBytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.memory(entry.imageBytes!, fit: BoxFit.contain),
                ),
                const SizedBox(height: 14),
              ],
              Text(entry.documentTypeLabel, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Text(
                structured != null
                    ? 'Confiance ${(structured.confidence * 100).toStringAsFixed(1)}% • ${structured.sections.length} section(s)'
                    : entry.resultSummary ?? entry.text,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onOpenResultRequested(entry);
                },
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(
                  _lc == 'en'
                      ? 'Open detailed result'
                      : _lc == 'ar'
                      ? 'فتح النتيجة التفصيلية'
                      : 'Voir resultat complet',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryFilterChip extends StatelessWidget {
  const _HistoryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _HistoryEntryCard extends StatelessWidget {
  const _HistoryEntryCard({
    required this.localeCode,
    required this.entry,
    required this.onTap,
  });

  final String localeCode;
  final ScanHistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final createdAt = DateTime.tryParse(entry.createdAtIso);

    return AppPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      radius: 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
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
          const SizedBox(width: 12),
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
                  '${entry.detectedLanguages.isEmpty ? '--' : entry.detectedLanguages.join(' / ').toUpperCase()} • ${entry.documentTypeLabel}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  createdAt?.toLocal().toString().split('.').first ??
                      entry.createdAtIso,
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.more_vert_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
