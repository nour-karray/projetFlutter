import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/app_localizations.dart';
import '../../core/scan_history_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.localeCode,
    required this.darkModeEnabled,
    required this.notificationsEnabled,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.scanHistoryStore,
    required this.geminiApiKey,
    required this.onThemeChanged,
    required this.onLocaleChanged,
    required this.onNotificationsChanged,
    required this.onSoundChanged,
    required this.onVibrationChanged,
    required this.onGeminiApiKeyChanged,
    super.key,
  });

  final String localeCode;
  final bool darkModeEnabled;
  final bool notificationsEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final ScanHistoryStore scanHistoryStore;
  final String geminiApiKey;
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

  Widget _sectionTitle(BuildContext context, String key) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        AppLocalizations.t(_lc, key),
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
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
        title: Text(AppLocalizations.t(_lc, 'settings')),
      ),
      body: ListView(
        children: [
          _sectionTitle(context, 'sectionPreferences'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                SwitchListTile(
                  value: widget.darkModeEnabled,
                  onChanged: widget.onThemeChanged,
                  secondary: const Icon(Icons.dark_mode),
                  title: Text(AppLocalizations.t(_lc, 'darkMode')),
                ),
                ListTile(
                  leading: const Icon(Icons.translate),
                  title: Text(AppLocalizations.t(_lc, 'appLanguage')),
                  trailing: DropdownButton<String>(
                    value: widget.localeCode,
                    onChanged: (value) {
                      if (value != null) widget.onLocaleChanged(value);
                    },
                    items: const [
                      DropdownMenuItem(value: 'fr', child: Text('Francais')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'ar', child: Text('العربية')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _sectionTitle(context, 'sectionNotifications'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                SwitchListTile(
                  value: widget.notificationsEnabled,
                  onChanged: widget.onNotificationsChanged,
                  title: Text(AppLocalizations.t(_lc, 'notifications')),
                ),
                SwitchListTile(
                  value: widget.soundEnabled,
                  onChanged: widget.onSoundChanged,
                  title: Text(AppLocalizations.t(_lc, 'sounds')),
                  subtitle: kIsWeb
                      ? Text(
                          AppLocalizations.t(_lc, 'webNoSoundVibration'),
                          style: theme.textTheme.bodySmall,
                        )
                      : null,
                ),
                SwitchListTile(
                  value: widget.vibrationEnabled,
                  onChanged: widget.onVibrationChanged,
                  title: Text(AppLocalizations.t(_lc, 'vibration')),
                  subtitle: kIsWeb
                      ? Text(
                          AppLocalizations.t(_lc, 'webNoSoundVibration'),
                          style: theme.textTheme.bodySmall,
                        )
                      : null,
                ),
                ListTile(
                  leading: Icon(Icons.delete_sweep_outlined, color: colorScheme.error),
                  title: Text(AppLocalizations.t(_lc, 'clearHistory')),
                  subtitle: Text(AppLocalizations.t(_lc, 'clearHistorySubtitle')),
                  onTap: _confirmClearHistory,
                ),
              ],
            ),
          ),
          _sectionTitle(context, 'sectionAi'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: TextField(
                controller: _apiKeyController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: AppLocalizations.t(_lc, 'geminiApiKey'),
                  hintText: 'AIza...',
                  helperText: AppLocalizations.t(_lc, 'geminiApiKeyHint'),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste),
                    tooltip: AppLocalizations.t(_lc, 'pasteFromClipboard'),
                    onPressed: _pasteApiKey,
                  ),
                ),
                onChanged: widget.onGeminiApiKeyChanged,
              ),
            ),
          ),
          const SizedBox(height: 24),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              final info = snap.data!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  'SmartScan v${info.version} (${info.buildNumber})',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
