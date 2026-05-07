import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_localizations.dart';
import '../../core/scan_history_store.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.localeCode,
    required this.scanHistoryStore,
    super.key,
  });

  final String localeCode;
  final ScanHistoryStore scanHistoryStore;

  static const String _assetOcr = 'assets/images/service_ocr.png';
  static const String _assetLanguage = 'assets/images/service_language.png';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.t(localeCode, 'home'))),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primaryContainer,
                    colorScheme.secondaryContainer,
                  ],
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppLocalizations.t(localeCode, 'welcome'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.t(localeCode, 'homeHeroSubtitle'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.9),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: scanHistoryStore,
                        builder: (_, _) {
                          final count = scanHistoryStore.entries.length;
                          if (count == 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Chip(
                              avatar: const Icon(Icons.history, size: 16),
                              label: Text(
                                AppLocalizations.t(localeCode, 'scanCount')
                                    .replaceAll('{n}', '$count'),
                                style: theme.textTheme.labelMedium,
                              ),
                              backgroundColor: colorScheme.surface.withValues(alpha: 0.6),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.t(localeCode, 'homeDescription'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ServiceCard(
                    imageAsset: _assetOcr,
                    title: AppLocalizations.t(localeCode, 'serviceOcrTitle'),
                    subtitle: AppLocalizations.t(localeCode, 'serviceOcrSubtitle'),
                    accentColor: colorScheme.primaryContainer,
                  ),
                  const SizedBox(height: 16),
                  _ServiceCard(
                    imageAsset: _assetLanguage,
                    title: AppLocalizations.t(localeCode, 'serviceLanguageTitle'),
                    subtitle: AppLocalizations.t(
                      localeCode,
                      'serviceLanguageSubtitle',
                    ),
                    accentColor: colorScheme.secondaryContainer,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.imageAsset,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  static const double _thumbBase = 72;

  final String imageAsset;
  final String title;
  final String subtitle;
  final Color accentColor;

  double _thumbSide(BuildContext context) {
    const requested = _thumbBase * 4;
    final screenW = MediaQuery.sizeOf(context).width;
    const scrollPadding = 40.0;
    const cardPadding = 24.0;
    const gapTexte = 14.0;
    const minPourTexte = 108.0;
    final maxThumb =
        screenW - scrollPadding - cardPadding - gapTexte - minPourTexte;
    return math.min(requested, math.max(_thumbBase, maxThumb));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final side = _thumbSide(context);
    final innerPad = side > 160 ? 10.0 : 8.0;
    final iconBroken = (side * 0.22).clamp(28.0, 80.0);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: side > 160 ? 14 : 10),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ColoredBox(
                  color: accentColor.withValues(alpha: 0.45),
                  child: SizedBox(
                    width: side,
                    height: side,
                    child: Padding(
                      padding: EdgeInsets.all(innerPad),
                      child: Image.asset(
                        imageAsset,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.broken_image_outlined,
                          size: iconBroken,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
