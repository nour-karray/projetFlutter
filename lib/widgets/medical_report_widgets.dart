import 'package:flutter/material.dart';

import '../models/medical_report.dart';
import '../theme/app_theme.dart';
import 'app_surfaces.dart';

class MedicalSummaryCard extends StatelessWidget {
  const MedicalSummaryCard({required this.report, super.key});

  final MedicalReport report;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resume general', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _FactChip(label: 'Type', value: report.documentType.name),
              _FactChip(
                label: 'Confiance',
                value: '${(report.confidence * 100).toStringAsFixed(1)} %',
              ),
              _FactChip(label: 'Sections', value: '${report.sections.length}'),
              _FactChip(
                label: 'Analyses',
                value:
                    '${report.sections.fold<int>(0, (sum, section) => sum + section.analyses.length)}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MedicalInfoCard extends StatelessWidget {
  const MedicalInfoCard({required this.title, required this.lines, super.key});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(line, style: theme.textTheme.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}

class MedicalSectionCard extends StatelessWidget {
  const MedicalSectionCard({required this.section, super.key});

  final MedicalSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 14),
          if (section.analyses.isEmpty)
            Text('Aucune analyse detectee.', style: theme.textTheme.bodyMedium),
          ...section.analyses.map(
            (analysis) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.52,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          analysis.name,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 10),
                      StatusBadge(flag: analysis.abnormalFlag),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _FactChip(
                        label: 'Valeur',
                        value: '${analysis.value ?? '-'} ${analysis.unit ?? ''}'
                            .trim(),
                      ),
                      if (analysis.secondaryValue != null)
                        _FactChip(
                          label: 'Valeur secondaire',
                          value:
                              '${analysis.secondaryValue} ${analysis.secondaryUnit ?? ''}'
                                  .trim(),
                        ),
                      _FactChip(
                        label: 'Reference',
                        value: analysis.referenceText ?? '-',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.flag, super.key});

  final AbnormalFlag flag;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (flag) {
      AbnormalFlag.low => ('Bas', AppThemePalette.warning),
      AbnormalFlag.high => ('Haut', AppThemePalette.danger),
      AbnormalFlag.normal => ('Normal', AppThemePalette.success),
      AbnormalFlag.unknown => ('Inconnu', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 110),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.52,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.labelLarge),
        ],
      ),
    );
  }
}
