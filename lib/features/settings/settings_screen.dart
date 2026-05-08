import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/app_feedback_service.dart';
import '../../core/app_localizations.dart';
import '../../core/app_notification_service.dart';
import '../../core/auth_service.dart';
import '../../core/scan_history_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_surfaces.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.localeCode,
    required this.authService,
    required this.darkModeEnabled,
    required this.notificationsEnabled,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.scanHistoryStore,
    required this.geminiApiKey,
    required this.onOpenDashboard,
    required this.onThemeChanged,
    required this.onLocaleChanged,
    required this.onNotificationsChanged,
    required this.onSoundChanged,
    required this.onVibrationChanged,
    required this.onGeminiApiKeyChanged,
    super.key,
  });

  final String localeCode;
  final AuthService authService;
  final bool darkModeEnabled;
  final bool notificationsEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final ScanHistoryStore scanHistoryStore;
  final String geminiApiKey;
  final VoidCallback onOpenDashboard;
  final ValueChanged<bool> onThemeChanged;
  final ValueChanged<String> onLocaleChanged;
  final ValueChanged<bool> onNotificationsChanged;
  final ValueChanged<bool> onSoundChanged;
  final ValueChanged<bool> onVibrationChanged;
  final ValueChanged<String> onGeminiApiKeyChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _apiKeyController;

  String get _lc => widget.localeCode;

  bool get _isFrench => _lc == 'fr';

  String _heroSubtitle() {
    if (!_isFrench) {
      return 'Manage your profile, alerts, feedback and AI workspace settings.';
    }
    return 'Gerez votre profil, les alertes, les retours utilisateur et la connectivite IA.';
  }

  String _profileTitle() => !_isFrench ? 'Profile' : 'Profil';

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.geminiApiKey);
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.geminiApiKey != widget.geminiApiKey &&
        _apiKeyController.text != widget.geminiApiKey) {
      _apiKeyController.text = widget.geminiApiKey;
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _pasteApiKey() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty || !mounted) return;
      _apiKeyController.text = text;
      widget.onGeminiApiKeyChanged(text);
      setState(() {});
    } catch (e, st) {
      debugPrint('_pasteApiKey: $e\n$st');
    }
  }

  Future<void> _confirmClearHistory() async {
    final colorScheme = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.t(_lc, 'clearHistory')),
        content: Text(AppLocalizations.t(_lc, 'clearHistoryConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppLocalizations.t(_lc, 'cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(AppLocalizations.t(_lc, 'confirm')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.scanHistoryStore.clear();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.t(_lc, 'historyCleared'))),
      );
    }
  }

  Future<void> _previewFeedback() async {
    await AppFeedbackService.instance.success();
  }

  Future<void> _sendTestNotification() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await AppNotificationService.instance.showTestNotification(
      localeCode: _lc,
      soundEnabled: widget.soundEnabled,
      vibrationEnabled: widget.vibrationEnabled,
    );
    if (!mounted) return;

    if (ok) {
      await AppNotificationService.instance.syncReminder(
        enabled: widget.notificationsEnabled,
        localeCode: _lc,
        soundEnabled: widget.soundEnabled,
        vibrationEnabled: widget.vibrationEnabled,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.t(_lc, 'notificationTestSent')),
        ),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.t(_lc, 'notificationPermissionDenied')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_profileTitle())),
      body: AppBackdrop(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            children: [
              AppPanel(
                gradient: AppThemePalette.heroGradient(
                  theme.brightness == Brightness.dark,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _profileTitle(),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _heroSubtitle(),
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
                        Icons.person_outline_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              AnimatedBuilder(
                animation: widget.authService,
                builder: (context, _) {
                  return AppPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppThemePalette.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(Icons.person_rounded),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.authService.displayName,
                                    style: theme.textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.authService.email ?? '-',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Chip(
                          avatar: Icon(
                            widget.authService.isEmailVerified
                                ? Icons.verified_rounded
                                : Icons.warning_amber_rounded,
                            size: 16,
                          ),
                          label: Text(
                            widget.authService.isEmailVerified
                                ? (_isFrench
                                      ? 'Compte verifie'
                                      : 'Verified account')
                                : (_isFrench
                                      ? 'Compte a verifier'
                                      : 'Verification pending'),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: widget.onOpenDashboard,
                                icon: const Icon(Icons.insights_rounded),
                                label: Text(
                                  _isFrench ? 'Dashboard BI' : 'Open dashboard',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await widget.authService.signOut();
                                },
                                icon: const Icon(Icons.logout_rounded),
                                label: Text(
                                  _isFrench ? 'Deconnexion' : 'Sign out',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              AppSectionHeader(
                eyebrow: AppLocalizations.t(_lc, 'sectionPreferences'),
                title: AppLocalizations.t(_lc, 'sectionPreferences'),
                subtitle: AppLocalizations.t(_lc, 'homeDescription'),
              ),
              const SizedBox(height: 12),
              AppPanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      value: widget.darkModeEnabled,
                      onChanged: (value) {
                        AppFeedbackService.instance.tap();
                        widget.onThemeChanged(value);
                      },
                      secondary: const Icon(Icons.dark_mode_rounded),
                      title: Text(AppLocalizations.t(_lc, 'darkMode')),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.translate_rounded),
                      title: Text(AppLocalizations.t(_lc, 'appLanguage')),
                      trailing: DropdownButton<String>(
                        value: widget.localeCode,
                        onChanged: (value) {
                          if (value == null) return;
                          AppFeedbackService.instance.tap();
                          widget.onLocaleChanged(value);
                        },
                        items: const [
                          DropdownMenuItem(
                            value: 'fr',
                            child: Text('Francais'),
                          ),
                          DropdownMenuItem(value: 'en', child: Text('English')),
                          DropdownMenuItem(value: 'ar', child: Text('Arabic')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              AppSectionHeader(
                eyebrow: AppLocalizations.t(_lc, 'sectionNotifications'),
                title: AppLocalizations.t(_lc, 'sectionNotifications'),
                subtitle: AppLocalizations.t(_lc, 'notificationsSetupSubtitle'),
              ),
              const SizedBox(height: 12),
              AppPanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      value: widget.notificationsEnabled,
                      onChanged: (value) {
                        AppFeedbackService.instance.tap();
                        widget.onNotificationsChanged(value);
                      },
                      secondary: const Icon(Icons.notifications_active_rounded),
                      title: Text(AppLocalizations.t(_lc, 'notifications')),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      value: widget.soundEnabled,
                      onChanged: (value) {
                        AppFeedbackService.instance.tap();
                        widget.onSoundChanged(value);
                      },
                      secondary: const Icon(Icons.volume_up_rounded),
                      title: Text(AppLocalizations.t(_lc, 'sounds')),
                      subtitle: kIsWeb
                          ? Text(
                              AppLocalizations.t(_lc, 'webNoSoundVibration'),
                              style: theme.textTheme.bodySmall,
                            )
                          : null,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      value: widget.vibrationEnabled,
                      onChanged: (value) {
                        AppFeedbackService.instance.tap();
                        widget.onVibrationChanged(value);
                      },
                      secondary: const Icon(Icons.vibration_rounded),
                      title: Text(AppLocalizations.t(_lc, 'vibration')),
                      subtitle: kIsWeb
                          ? Text(
                              AppLocalizations.t(_lc, 'webNoSoundVibration'),
                              style: theme.textTheme.bodySmall,
                            )
                          : null,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      enabled:
                          !kIsWeb &&
                          (widget.soundEnabled || widget.vibrationEnabled),
                      leading: const Icon(Icons.touch_app_rounded),
                      title: Text(
                        AppLocalizations.t(_lc, 'feedbackPreviewTitle'),
                      ),
                      subtitle: Text(
                        kIsWeb
                            ? AppLocalizations.t(_lc, 'webNoSoundVibration')
                            : AppLocalizations.t(
                                _lc,
                                'feedbackPreviewSubtitle',
                              ),
                      ),
                      onTap:
                          !kIsWeb &&
                              (widget.soundEnabled || widget.vibrationEnabled)
                          ? _previewFeedback
                          : null,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      enabled: !kIsWeb && widget.notificationsEnabled,
                      leading: const Icon(Icons.notifications_rounded),
                      title: Text(
                        AppLocalizations.t(_lc, 'notificationTestActionTitle'),
                      ),
                      subtitle: Text(
                        kIsWeb
                            ? AppLocalizations.t(_lc, 'webNoSoundVibration')
                            : AppLocalizations.t(
                                _lc,
                                'notificationTestActionSubtitle',
                              ),
                      ),
                      onTap: !kIsWeb && widget.notificationsEnabled
                          ? _sendTestNotification
                          : null,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        Icons.delete_sweep_outlined,
                        color: theme.colorScheme.error,
                      ),
                      title: Text(AppLocalizations.t(_lc, 'clearHistory')),
                      subtitle: Text(
                        AppLocalizations.t(_lc, 'clearHistorySubtitle'),
                      ),
                      onTap: () {
                        AppFeedbackService.instance.tap();
                        _confirmClearHistory();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              AppSectionHeader(
                eyebrow: AppLocalizations.t(_lc, 'sectionAi'),
                title: AppLocalizations.t(_lc, 'sectionAi'),
                subtitle: AppLocalizations.t(_lc, 'geminiApiKeyHint'),
              ),
              const SizedBox(height: 12),
              AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppThemePalette.primary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.auto_awesome_rounded),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            AppLocalizations.t(_lc, 'geminiApiKey'),
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _apiKeyController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.t(_lc, 'geminiApiKey'),
                        hintText: 'AIza...',
                        helperText: AppLocalizations.t(_lc, 'geminiApiKeyHint'),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.content_paste_rounded),
                          tooltip: AppLocalizations.t(
                            _lc,
                            'pasteFromClipboard',
                          ),
                          onPressed: () {
                            AppFeedbackService.instance.tap();
                            _pasteApiKey();
                          },
                        ),
                      ),
                      onChanged: widget.onGeminiApiKeyChanged,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();
                  final info = snap.data!;
                  return AppPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppThemePalette.secondary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.info_outline_rounded),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'SmartScan v${info.version} (${info.buildNumber})',
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
