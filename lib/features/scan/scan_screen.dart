import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_feedback_service.dart';
import '../../core/app_localizations.dart';
import '../../core/guided_photo_preprocessor.dart';
import '../../core/image_thumbnail.dart';
import '../../core/language_detector.dart';
import '../../core/medical_ocr_postprocessor.dart';
import '../../core/mlkit_language_service.dart';
import '../../core/ocr_service.dart';
import '../../core/scan_history_store.dart';
import '../../core/scan_result_store.dart';
import '../../services/medical_report_pipeline_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_surfaces.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({
    required this.localeCode,
    required this.scanResultStore,
    required this.scanHistoryStore,
    required this.ocrService,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.onResultReady,
    super.key,
  });

  final String localeCode;
  final ScanResultStore scanResultStore;
  final ScanHistoryStore scanHistoryStore;
  final OcrService ocrService;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final VoidCallback onResultReady;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ImagePicker _picker = ImagePicker();
  final MedicalReportPipelineService _pipelineService =
      MedicalReportPipelineService();
  final MlKitLanguageService _mlKitLanguageService = MlKitLanguageService();
  final GuidedPhotoPreprocessor _guidedPhotoPreprocessor =
      GuidedPhotoPreprocessor();
  String? _selectedFileName;
  bool _isBusy = false;
  bool _guidedPhotoEnabled = true;

  String get _lc => widget.localeCode;

  String _pdfUnsupportedMessage(String locale) {
    switch (locale) {
      case 'en':
        return 'PDF import is not supported on this device in local mode. '
            'Take a photo of the document instead.';
      case 'ar':
        return 'Ø§Ø³ØªÙŠØ±Ø§Ø¯ PDF ØºÙŠØ± Ù…Ø¯Ø¹ÙˆÙ… Ø¹Ù„Ù‰ Ù‡Ø°Ø§ Ø§Ù„Ø¬Ù‡Ø§Ø² ÙÙŠ Ø§Ù„ÙˆØ¶Ø¹ Ø§Ù„Ù…Ø­Ù„ÙŠ. Ø§Ù„ØªÙ‚Ø· ØµÙˆØ±Ø© Ù„Ù„Ù…Ø³ØªÙ†Ø¯ Ø¨Ø¯Ù„Ø§Ù‹ Ù…Ù† Ø°Ù„Ùƒ.';
      default:
        return 'Import PDF non supporte sur Android en mode local. '
            'Prenez une photo du document a la place.';
    }
  }

  String _captureSubtitle() {
    switch (_lc) {
      case 'en':
        return 'Use a guided capture flow for cleaner OCR and easier translation.';
      case 'ar':
        return 'استخدم تدفق التقاط موجه للحصول على OCR أوضح وترجمة أسهل.';
      default:
        return 'Utilisez un flux de capture guide pour un OCR plus propre et une traduction plus fluide.';
    }
  }

  String _progressTitle() {
    switch (_lc) {
      case 'en':
        return 'Processing pipeline active';
      case 'ar':
        return 'مسار المعالجة نشط';
      default:
        return 'Pipeline de traitement actif';
    }
  }

  Future<void> _feedback({required bool success}) {
    return success
        ? AppFeedbackService.instance.success()
        : AppFeedbackService.instance.error();
  }

  Future<void> _runOcrFromImageSource(ImageSource source) async {
    if (_isBusy) return;

    setState(() {
      _isBusy = true;
    });

    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (!mounted) return;

      if (image == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.t(_lc, 'scanCancelled'))),
        );
      } else {
        var imageBytes = await image.readAsBytes();
        var imagePath = image.path;
        if (_guidedPhotoEnabled) {
          final guided = await _guidedPhotoPreprocessor.process(
            bytes: imageBytes,
            originalPath: image.path,
            fileName: image.name,
          );
          imageBytes = guided.bytes;
          imagePath = guided.path;
          if (mounted) {
            final notes = <String>[];
            if (guided.wasCropped) {
              notes.add(AppLocalizations.t(_lc, 'guidedCropApplied'));
            }
            if (guided.hasWarning) {
              notes.add(guided.qualityWarnings.join(' - '));
            }
            if (notes.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${AppLocalizations.t(_lc, 'guidedPhotoReport')}: ${notes.join(' | ')}',
                  ),
                ),
              );
            }
          }
        }
        if (!mounted) return;

        setState(() {
          _selectedFileName = image.name;
        });

        await _processBytes(
          bytes: imageBytes,
          path: imagePath,
          fileName: image.name,
        );
      }
    } catch (e, st) {
      debugPrint('Scan error: $e\n$st');
      widget.scanResultStore.fail(
        '${AppLocalizations.t(_lc, 'scanErrorImage')}: $e',
      );
      widget.onResultReady();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.t(_lc, 'scanError')}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _processBytes({
    required Uint8List bytes,
    required String path,
    required String fileName,
  }) async {
    widget.scanResultStore.startProcessing(path, bytes: bytes);
    if (!mounted) return;

    final isPdf =
        path.toLowerCase().endsWith('.pdf') ||
        fileName.toLowerCase().endsWith('.pdf');
    if (isPdf) {
      final msg = _pdfUnsupportedMessage(_lc);
      widget.scanResultStore.fail(msg);
      widget.onResultReady();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    final result = await widget.ocrService.extractText(
      imagePath: path,
      imageBytes: bytes,
      sourceFileName: fileName,
    );
    if (!mounted) return;

    if (result.success && result.text != null) {
      final cleanedText = MedicalOcrPostprocessor.normalize(result.text!);
      final fallbackDetection = LanguageDetector.detectLanguages(cleanedText);
      final mlKitDetection = await _mlKitLanguageService.detect(cleanedText);
      final primaryCode =
          mlKitDetection?.primaryCode ?? fallbackDetection.primaryCode;
      final rankedCodes =
          mlKitDetection?.rankedCodes ?? fallbackDetection.rankedCodes;
      final report = _pipelineService.parseFromRawText(
        sourceFileName: fileName,
        rawOcrText: cleanedText,
      );
      widget.scanResultStore.complete(
        cleanedText,
        languageCode: primaryCode,
        languageCodes: rankedCodes,
        report: report,
      );
      try {
        final rawHistoryText = result.text!.trim();
        if (rawHistoryText.isNotEmpty) {
          String? thumbB64;
          if (!fileName.toLowerCase().endsWith('.pdf')) {
            final thumb = await encodeThumbnailPng(bytes);
            if (thumb != null && thumb.length < 900000) {
              thumbB64 = base64Encode(thumb);
            }
          }
          await widget.scanHistoryStore.addEntry(
            text: rawHistoryText,
            detectedLanguages: rankedCodes,
            imageBase64: thumbB64,
            structuredReport: report,
            sourceFileName: fileName,
            fileSizeBytes: bytes.lengthInBytes,
          );
        }
      } catch (e, st) {
        debugPrint('scanHistoryStore.addEntry: $e\n$st');
      }
      widget.onResultReady();
      await _feedback(success: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t(_lc, 'ocrSuccess'))),
      );
      return;
    }

    widget.scanResultStore.fail(
      result.errorMessage ?? AppLocalizations.t(_lc, 'ocrUnknownError'),
    );
    widget.onResultReady();
    await _feedback(success: false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.errorMessage ?? AppLocalizations.t(_lc, 'ocrUnknownError'),
        ),
      ),
    );
  }

  void _showPdfUnavailable() {
    final message = _pdfUnsupportedMessage(_lc);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showComingSoon() {
    final message = _lc == 'en'
        ? 'This import source will be available in the next iteration.'
        : 'Cette source d import sera disponible dans la prochaine iteration.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t(_lc, 'scan')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Chip(
              label: Text(_guidedPhotoEnabled ? 'OCR Ready' : 'Manual'),
              avatar: Icon(
                _guidedPhotoEnabled
                    ? Icons.auto_fix_high_rounded
                    : Icons.tune_rounded,
                size: 16,
              ),
            ),
          ),
        ],
      ),
      body: AppBackdrop(
        child: SafeArea(
          top: false,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppPanel(
                      gradient: AppThemePalette.heroGradient(
                        theme.brightness == Brightness.dark,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.document_scanner_rounded,
                                  size: 28,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppLocalizations.t(
                                        _lc,
                                        'captureDocument',
                                      ),
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(color: Colors.white),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _captureSubtitle(),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: Colors.white.withValues(
                                              alpha: 0.86,
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: const [
                              _HeroStep(label: '1. Capture'),
                              _HeroStep(label: '2. OCR'),
                              _HeroStep(label: '3. Langue'),
                              _HeroStep(label: '4. Export'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    AppPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      child: SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _guidedPhotoEnabled,
                        onChanged: _isBusy
                            ? null
                            : (value) {
                                setState(() {
                                  _guidedPhotoEnabled = value;
                                });
                              },
                        title: Text(
                          AppLocalizations.t(_lc, 'guidedPhotoModeTitle'),
                        ),
                        subtitle: Text(
                          AppLocalizations.t(_lc, 'guidedPhotoModeSubtitle'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.12,
                      children: [
                        _ImportOptionCard(
                          icon: Icons.camera_alt_rounded,
                          accent: AppThemePalette.primary,
                          title: _lc == 'en'
                              ? 'Scanner'
                              : 'Scanner un document',
                          subtitle: _lc == 'en'
                              ? 'Use the camera'
                              : 'Prenez une photo avec votre appareil',
                          onTap: _isBusy
                              ? null
                              : () =>
                                    _runOcrFromImageSource(ImageSource.camera),
                        ),
                        _ImportOptionCard(
                          icon: Icons.photo_library_rounded,
                          accent: AppThemePalette.secondary,
                          title: _lc == 'en'
                              ? 'Gallery'
                              : 'Importer de la galerie',
                          subtitle: _lc == 'en'
                              ? 'Select an image'
                              : 'Selectionnez une image ou un document',
                          onTap: _isBusy
                              ? null
                              : () =>
                                    _runOcrFromImageSource(ImageSource.gallery),
                        ),
                        _ImportOptionCard(
                          icon: Icons.picture_as_pdf_rounded,
                          accent: AppThemePalette.danger,
                          title: 'PDF',
                          subtitle: _lc == 'en'
                              ? 'Import a PDF file'
                              : 'Importer un PDF',
                          onTap: _showPdfUnavailable,
                        ),
                        _ImportOptionCard(
                          icon: Icons.cloud_upload_rounded,
                          accent: AppThemePalette.tertiary,
                          title: _lc == 'en' ? 'Cloud' : 'Glisser-deposer',
                          subtitle: _lc == 'en'
                              ? 'Coming soon'
                              : 'Bientot disponible',
                          dashed: true,
                          onTap: _showComingSoon,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_selectedFileName != null)
                      AppPanel(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: AppThemePalette.primary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.insert_drive_file_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocalizations.t(_lc, 'selectedImage'),
                                    style: theme.textTheme.labelLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _selectedFileName!,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      AppEmptyState(
                        icon: Icons.photo_camera_back_rounded,
                        title: AppLocalizations.t(_lc, 'scanEmptyHint'),
                        subtitle: AppLocalizations.t(_lc, 'homeHeroSubtitle'),
                      ),
                    const SizedBox(height: 16),
                    AppPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppSectionHeader(
                            eyebrow: _lc == 'en'
                                ? 'Recent sources'
                                : 'Sources recentes',
                            title: _lc == 'en'
                                ? 'Recent sources'
                                : 'Sources recentes',
                          ),
                          const SizedBox(height: 12),
                          if (widget.scanHistoryStore.entries.isEmpty)
                            Text(
                              _lc == 'en'
                                  ? 'Your latest files will appear here after the first import.'
                                  : 'Vos derniers fichiers apparaitront ici apres le premier import.',
                              style: theme.textTheme.bodyMedium,
                            )
                          else
                            ...widget.scanHistoryStore.entries
                                .where((entry) => !entry.isDeleted)
                                .take(3)
                                .map(
                                  (entry) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: theme
                                                .colorScheme
                                                .surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: Icon(
                                            entry.displayName
                                                    .toLowerCase()
                                                    .endsWith('.pdf')
                                                ? Icons.picture_as_pdf_rounded
                                                : Icons.image_rounded,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                entry.displayName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style:
                                                    theme.textTheme.titleSmall,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${entry.documentTypeLabel} · ${entry.fileSizeBytes == null ? '-' : '${(entry.fileSizeBytes! / 1024).toStringAsFixed(0)} Ko'}',
                                                style:
                                                    theme.textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.more_vert_rounded,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _lc == 'en'
                                ? 'Supported formats'
                                : 'Formats pris en charge',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: const [
                              _FormatChip(label: 'PDF'),
                              _FormatChip(label: 'JPG'),
                              _FormatChip(label: 'PNG'),
                              _FormatChip(label: 'HEIC'),
                              _FormatChip(label: 'DOCX'),
                              _FormatChip(label: '+3'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _lc == 'en'
                                ? 'Quality tips'
                                : 'Conseils pour un scan de qualite',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          ...(_lc == 'en'
                                  ? const <String>[
                                      'Use bright lighting and avoid shadows.',
                                      'Keep the document flat and fully visible.',
                                      'Avoid motion blur and reflective surfaces.',
                                    ]
                                  : const <String>[
                                      'Assurez-vous d avoir une bonne luminosite.',
                                      'Placez le document a plat et entierement visible.',
                                      'Evitez le flou et les reflets pour une meilleure lisibilite.',
                                    ])
                              .map(
                                (tip) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 18,
                                        color: AppThemePalette.success,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          tip,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                    if (_isBusy) ...[
                      const SizedBox(height: 16),
                      AppPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _progressTitle(),
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 14),
                            const LinearProgressIndicator(minHeight: 8),
                            const SizedBox(height: 14),
                            const _ProgressLine(
                              icon: Icons.photo_filter_rounded,
                              text: 'Pre-traitement et controle qualite',
                            ),
                            const SizedBox(height: 10),
                            const _ProgressLine(
                              icon: Icons.text_snippet_rounded,
                              text: 'Extraction OCR en cours',
                            ),
                            const SizedBox(height: 10),
                            const _ProgressLine(
                              icon: Icons.language_rounded,
                              text: 'Detection de langue et structuration',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroStep extends StatelessWidget {
  const _HeroStep({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      backgroundColor: Colors.white.withValues(alpha: 0.12),
      labelStyle: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: Colors.white),
      label: Text(label),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
      ],
    );
  }
}

class _ImportOptionCard extends StatelessWidget {
  const _ImportOptionCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.dashed = false,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppPanel(
      onTap: onTap,
      border: dashed
          ? BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
              width: 1.2,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: accent, size: 28),
          ),
          const Spacer(),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(subtitle, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(label, style: theme.textTheme.labelLarge),
    );
  }
}
