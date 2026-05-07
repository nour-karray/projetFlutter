import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vibration/vibration.dart';

import '../../core/app_localizations.dart';
import '../../core/guided_photo_preprocessor.dart';
import '../../core/image_thumbnail.dart';
import '../../core/language_detector.dart';
import '../../core/mlkit_language_service.dart';
import '../../core/medical_ocr_postprocessor.dart';
import '../../core/ocr_service.dart';
import '../../core/scan_history_store.dart';
import '../../core/scan_result_store.dart';
import '../../services/medical_report_pipeline_service.dart';

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
  final MedicalReportPipelineService _pipelineService = MedicalReportPipelineService();
  final MlKitLanguageService _mlKitLanguageService = MlKitLanguageService();
  final GuidedPhotoPreprocessor _guidedPhotoPreprocessor = GuidedPhotoPreprocessor();
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
        return 'استيراد PDF غير مدعوم على هذا الجهاز في الوضع المحلي. التقط صورة للمستند بدلاً من ذلك.';
      default:
        return 'Import PDF non supporté sur Android en mode local. '
            'Prenez une photo du document à la place.';
    }
  }

  Future<void> _feedback({required bool success}) async {
    if (kIsWeb) return;
    try {
      if (widget.soundEnabled) {
        await SystemSound.play(SystemSoundType.click);
      }
      if (widget.vibrationEnabled) {
        final hasVibrator = await Vibration.hasVibrator();
        if (hasVibrator) {
          if (success) {
            await Vibration.vibrate(duration: 80, amplitude: 128);
          } else {
            await Vibration.vibrate(
              pattern: [0, 100, 100, 200],
              intensities: [0, 80, 0, 180],
            );
          }
        } else {
          if (success) {
            await HapticFeedback.lightImpact();
          } else {
            await HapticFeedback.heavyImpact();
          }
        }
      }
    } catch (e, st) {
      debugPrint('_feedback failed: $e\n$st');
    }
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
          SnackBar(
            content: Text(
              AppLocalizations.t(_lc, 'scanCancelled'),
            ),
          ),
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
                SnackBar(content: Text('${AppLocalizations.t(_lc, 'guidedPhotoReport')}: ${notes.join(' | ')}')),
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
        SnackBar(
          content: Text('${AppLocalizations.t(_lc, 'scanError')}: $e'),
        ),
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
        path.toLowerCase().endsWith('.pdf') || fileName.toLowerCase().endsWith('.pdf');
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
      final primaryCode = mlKitDetection?.primaryCode ?? fallbackDetection.primaryCode;
      final rankedCodes = mlKitDetection?.rankedCodes ?? fallbackDetection.rankedCodes;
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
        if (rawHistoryText.isEmpty) {
          // Rien à persister sans texte brut.
        } else {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t(_lc, 'scan')),
        bottom: _isBusy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(minHeight: 4),
              )
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.document_scanner_outlined,
                    size: 80,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppLocalizations.t(_lc, 'captureDocument'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.t(_lc, 'scanStep'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 28),
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _guidedPhotoEnabled,
                          onChanged: _isBusy
                              ? null
                              : (value) {
                                  setState(() {
                                    _guidedPhotoEnabled = value;
                                  });
                                },
                          title: Text(AppLocalizations.t(_lc, 'guidedPhotoModeTitle')),
                          subtitle: Text(AppLocalizations.t(_lc, 'guidedPhotoModeSubtitle')),
                        ),
                      ],
                    ),
                  ),
                  if (!_isBusy && _selectedFileName == null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 32),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.document_scanner_outlined,
                            size: 72,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            AppLocalizations.t(_lc, 'scanEmptyHint'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isBusy ? null : () => _runOcrFromImageSource(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: Text(
                        _isBusy
                            ? AppLocalizations.t(_lc, 'processing')
                            : AppLocalizations.t(_lc, 'takePhoto'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isBusy ? null : () => _runOcrFromImageSource(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: Text(
                        _isBusy
                            ? AppLocalizations.t(_lc, 'processing')
                            : AppLocalizations.t(_lc, 'pickGallery'),
                      ),
                    ),
                  ),
                  if (_selectedFileName != null) ...[
                    const SizedBox(height: 20),
                    Align(
                      child: Chip(
                        avatar: const Icon(Icons.image_outlined, size: 18),
                        label: Text(
                          _selectedFileName!,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
