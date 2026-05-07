import 'package:flutter/material.dart';

import '../models/medical_report.dart';

class MedicalSummaryCard extends StatelessWidget {
  const MedicalSummaryCard({required this.report, super.key});

  final MedicalReport report;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resume general', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Type: ${report.documentType.name}'),
            Text('Confiance: ${(report.confidence * 100).toStringAsFixed(1)} %'),
            Text('Sections detectees: ${report.sections.length}'),
            Text('Analyses detectees: ${report.sections.fold<int>(0, (p, e) => p + e.analyses.length)}'),
          ],
        ),
      ),
    );
  }
}

class MedicalInfoCard extends StatelessWidget {
  const MedicalInfoCard({
    required this.title,
    required this.lines,
    super.key,
  });

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            ...lines.map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(line),
                )),
          ],
        ),
      ),
    );
  }
}

class MedicalSectionCard extends StatelessWidget {
  const MedicalSectionCard({
    required this.section,
    super.key,
  });

  final MedicalSection section;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(section.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            if (section.analyses.isEmpty) const Text('Aucune analyse detectee.'),
            ...section.analyses.map(
              (analysis) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            analysis.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        StatusBadge(flag: analysis.abnormalFlag),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Valeur: ${analysis.value ?? '-'} ${analysis.unit ?? ''}'),
                    if (analysis.secondaryValue != null)
                      Text('Valeur secondaire: ${analysis.secondaryValue} ${analysis.secondaryUnit ?? ''}'),
                    Text('Reference: ${analysis.referenceText ?? '-'}'),
                  ],
                ),
              ),
            ),
          ],
        ),
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
      AbnormalFlag.low => ('Bas', Colors.orange),
      AbnormalFlag.high => ('Haut', Colors.red),
      AbnormalFlag.normal => ('Normal', Colors.green),
      AbnormalFlag.unknown => ('Inconnu', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
