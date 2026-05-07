import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_feedback_service.dart';
import 'core/app_localizations.dart';
import 'core/app_notification_service.dart';
import 'core/auth_service.dart';
import 'core/ocr_service.dart';
import 'core/scan_history_store.dart';
import 'core/scan_result_store.dart';
import 'features/auth/auth_screen.dart';
import 'features/auth/email_verification_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/documents/documents_screen.dart';
import 'features/history/history_screen.dart';
import 'features/home/home_screen.dart';
import 'features/result/result_screen.dart';
import 'features/scan/scan_screen.dart';
import 'features/settings/settings_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_surfaces.dart';

class SmartScanApp extends StatefulWidget {
  const SmartScanApp({super.key});

  @override
  State<SmartScanApp> createState() => _SmartScanAppState();
}

class _SmartScanAppState extends State<SmartScanApp> {
  static const String _localeKey = 'app_locale';
  static const String _themeKey = 'app_dark_mode';
  static const String _notificationsKey = 'notifications_enabled';
  static const String _soundKey = 'sound_enabled';
  static const String _vibrationKey = 'vibration_enabled';
  static const String _geminiApiKeyKey = 'gemini_api_key';

  ThemeMode _themeMode = ThemeMode.light;
  String _localeCode = 'fr';
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  String _geminiApiKey = '';
  bool _prefsReady = false;
  bool _historyLoading = true;
  String? _loadedHistoryUid;

  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final ScanHistoryStore _scanHistoryStore = ScanHistoryStore();
  final AuthService _authService = AuthService();
  final AppFeedbackService _feedbackService = AppFeedbackService.instance;
  final AppNotificationService _notificationService =
      AppNotificationService.instance;

  @override
  void initState() {
    super.initState();
    _authService.addListener(_handleAuthStateChanged);
    _loadPrefs();
    _initializeCloudServices();
  }

  @override
  void dispose() {
    _authService.removeListener(_handleAuthStateChanged);
    _authService.dispose();
    super.dispose();
  }

  Future<void> _initializeCloudServices() async {
    await _authService.initialize();
    await _loadHistoryForCurrentUser(force: true);
  }

  void _handleAuthStateChanged() {
    _loadHistoryForCurrentUser();
  }

  Future<void> _loadHistoryForCurrentUser({bool force = false}) async {
    if (!_authService.isReady) return;
    final uidKey = _authService.uid ?? 'signed_out';
    if (!force && _loadedHistoryUid == uidKey) return;

    if (mounted) {
      setState(() {
        _historyLoading = true;
      });
    }

    _loadedHistoryUid = uidKey;
    await _scanHistoryStore.load();

    if (!mounted) return;
    setState(() {
      _historyLoading = false;
    });
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _localeCode = prefs.getString(_localeKey) ?? 'fr';
      _themeMode = (prefs.getBool(_themeKey) ?? false)
          ? ThemeMode.dark
          : ThemeMode.light;
      _notificationsEnabled = prefs.getBool(_notificationsKey) ?? true;
      _soundEnabled = prefs.getBool(_soundKey) ?? true;
      _vibrationEnabled = prefs.getBool(_vibrationKey) ?? true;
      _geminiApiKey = prefs.getString(_geminiApiKeyKey) ?? '';
      _prefsReady = true;
    });
    _syncPlatformServices();
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveLocale(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, value);
  }

  Future<void> _saveGeminiApiKey(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_geminiApiKeyKey, value.trim());
  }

  Future<void> _syncPlatformServices({
    bool requestNotificationPermissionIfNeeded = false,
  }) async {
    _feedbackService.configure(
      soundEnabled: _soundEnabled,
      vibrationEnabled: _vibrationEnabled,
    );
    if (kIsWeb) return;
    await _notificationService.initialize();
    await _notificationService.syncReminder(
      enabled: _notificationsEnabled,
      localeCode: _localeCode,
      soundEnabled: _soundEnabled,
      vibrationEnabled: _vibrationEnabled,
      requestPermissionIfNeeded: requestNotificationPermissionIfNeeded,
    );
  }

  Future<void> _handleLocaleChanged(String value) async {
    setState(() {
      _localeCode = value;
    });
    await _saveLocale(value);
    await _syncPlatformServices();
  }

  Future<void> _handleNotificationsChanged(bool enabled) async {
    if (enabled && !kIsWeb) {
      final granted = await _notificationService.requestPermission();
      if (!granted) {
        if (!mounted) return;
        setState(() {
          _notificationsEnabled = false;
        });
        await _saveBool(_notificationsKey, false);
        _messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.t(_localeCode, 'notificationPermissionDenied'),
            ),
          ),
        );
        return;
      }
    }

    setState(() {
      _notificationsEnabled = enabled;
    });
    await _saveBool(_notificationsKey, enabled);
    await _syncPlatformServices();
  }

  Future<void> _handleSoundChanged(bool enabled) async {
    setState(() {
      _soundEnabled = enabled;
    });
    await _saveBool(_soundKey, enabled);
    await _syncPlatformServices();
  }

  Future<void> _handleVibrationChanged(bool enabled) async {
    setState(() {
      _vibrationEnabled = enabled;
    });
    await _saveBool(_vibrationKey, enabled);
    await _syncPlatformServices();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SmartScan ML Kit',
      locale: Locale(_localeCode),
      supportedLocales: const [Locale('fr'), Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      scaffoldMessengerKey: _messengerKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (!_prefsReady || !_authService.isReady || _historyLoading) {
      return const _AppBootLoader();
    }

    if (!_authService.isSignedIn) {
      return AuthScreen(localeCode: _localeCode, authService: _authService);
    }

    if (!_authService.isEmailVerified) {
      return EmailVerificationScreen(
        localeCode: _localeCode,
        authService: _authService,
      );
    }

    return MainNavigation(
      authService: _authService,
      scanHistoryStore: _scanHistoryStore,
      geminiApiKey: _geminiApiKey,
      localeCode: _localeCode,
      isDarkMode: _themeMode == ThemeMode.dark,
      notificationsEnabled: _notificationsEnabled,
      soundEnabled: _soundEnabled,
      vibrationEnabled: _vibrationEnabled,
      onThemeChanged: (enabled) {
        setState(() {
          _themeMode = enabled ? ThemeMode.dark : ThemeMode.light;
        });
        _saveBool(_themeKey, enabled);
      },
      onLocaleChanged: (value) {
        _handleLocaleChanged(value);
      },
      onNotificationsChanged: (enabled) {
        _handleNotificationsChanged(enabled);
      },
      onSoundChanged: (enabled) {
        _handleSoundChanged(enabled);
      },
      onVibrationChanged: (enabled) {
        _handleVibrationChanged(enabled);
      },
      onGeminiApiKeyChanged: (value) {
        setState(() {
          _geminiApiKey = value.trim();
        });
        _saveGeminiApiKey(value);
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({
    required this.authService,
    required this.scanHistoryStore,
    required this.geminiApiKey,
    required this.localeCode,
    required this.isDarkMode,
    required this.notificationsEnabled,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.onThemeChanged,
    required this.onLocaleChanged,
    required this.onNotificationsChanged,
    required this.onSoundChanged,
    required this.onVibrationChanged,
    required this.onGeminiApiKeyChanged,
    super.key,
  });

  final AuthService authService;
  final ScanHistoryStore scanHistoryStore;
  final String geminiApiKey;
  final String localeCode;
  final bool isDarkMode;
  final bool notificationsEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final ValueChanged<bool> onThemeChanged;
  final ValueChanged<String> onLocaleChanged;
  final ValueChanged<bool> onNotificationsChanged;
  final ValueChanged<bool> onSoundChanged;
  final ValueChanged<bool> onVibrationChanged;
  final ValueChanged<String> onGeminiApiKeyChanged;

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final ScanResultStore _scanResultStore = ScanResultStore();
  final OcrService _ocrService = OcrService();

  void _openResultScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(
          localeCode: widget.localeCode,
          scanResultStore: _scanResultStore,
          geminiApiKey: widget.geminiApiKey,
        ),
      ),
    );
  }

  void _openEntryResult(ScanHistoryEntry entry) {
    _scanResultStore.loadFromHistory(
      text: entry.text,
      languageCodes: entry.detectedLanguages,
      report: entry.structuredReport,
      bytes: entry.imageBytes,
    );
    _openResultScreen();
  }

  void _openDashboard() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DashboardScreen(
          localeCode: widget.localeCode,
          scanHistoryStore: widget.scanHistoryStore,
          userName: widget.authService.displayName,
          onOpenDocuments: () {
            Navigator.of(context).pop();
            setState(() {
              _currentIndex = 1;
            });
          },
          onOpenHistory: () {
            Navigator.of(context).pop();
            setState(() {
              _currentIndex = 3;
            });
          },
          onOpenScanner: () {
            Navigator.of(context).pop();
            setState(() {
              _currentIndex = 2;
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pages = [
      HomeScreen(
        localeCode: widget.localeCode,
        userName: widget.authService.displayName,
        scanHistoryStore: widget.scanHistoryStore,
        onOpenScanner: () {
          setState(() {
            _currentIndex = 2;
          });
        },
        onOpenDocuments: () {
          setState(() {
            _currentIndex = 1;
          });
        },
        onOpenHistory: () {
          setState(() {
            _currentIndex = 3;
          });
        },
        onOpenDashboard: _openDashboard,
      ),
      DocumentsScreen(
        localeCode: widget.localeCode,
        scanHistoryStore: widget.scanHistoryStore,
        onOpenScanner: () {
          setState(() {
            _currentIndex = 2;
          });
        },
        onOpenResultRequested: _openEntryResult,
      ),
      ScanScreen(
        localeCode: widget.localeCode,
        scanResultStore: _scanResultStore,
        scanHistoryStore: widget.scanHistoryStore,
        ocrService: _ocrService,
        soundEnabled: widget.soundEnabled,
        vibrationEnabled: widget.vibrationEnabled,
        onResultReady: _openResultScreen,
      ),
      HistoryScreen(
        localeCode: widget.localeCode,
        scanHistoryStore: widget.scanHistoryStore,
        onOpenResultRequested: _openEntryResult,
      ),
      SettingsScreen(
        localeCode: widget.localeCode,
        authService: widget.authService,
        darkModeEnabled: widget.isDarkMode,
        notificationsEnabled: widget.notificationsEnabled,
        soundEnabled: widget.soundEnabled,
        vibrationEnabled: widget.vibrationEnabled,
        scanHistoryStore: widget.scanHistoryStore,
        geminiApiKey: widget.geminiApiKey,
        onOpenDashboard: _openDashboard,
        onGeminiApiKeyChanged: widget.onGeminiApiKeyChanged,
        onThemeChanged: widget.onThemeChanged,
        onLocaleChanged: widget.onLocaleChanged,
        onNotificationsChanged: widget.onNotificationsChanged,
        onSoundChanged: widget.onSoundChanged,
        onVibrationChanged: widget.onVibrationChanged,
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(
                  alpha: isDark ? 0.94 : 0.92,
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: theme.colorScheme.outlineVariant),
                boxShadow: AppThemePalette.softShadow(isDark),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _BottomNavItem(
                        icon: Icons.home_rounded,
                        label: AppLocalizations.t(widget.localeCode, 'home'),
                        selected: _currentIndex == 0,
                        onTap: () => _selectTab(0),
                      ),
                    ),
                    Expanded(
                      child: _BottomNavItem(
                        icon: Icons.folder_copy_rounded,
                        label: AppLocalizations.t(
                          widget.localeCode,
                          'documents',
                        ),
                        selected: _currentIndex == 1,
                        onTap: () => _selectTab(1),
                      ),
                    ),
                    const SizedBox(width: 76),
                    Expanded(
                      child: _BottomNavItem(
                        icon: Icons.history_rounded,
                        label: AppLocalizations.t(widget.localeCode, 'history'),
                        selected: _currentIndex == 3,
                        onTap: () => _selectTab(3),
                      ),
                    ),
                    Expanded(
                      child: _BottomNavItem(
                        icon: Icons.person_outline_rounded,
                        label: widget.localeCode == 'en' ? 'Profile' : 'Profil',
                        selected: _currentIndex == 4,
                        onTap: () => _selectTab(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -18,
              child: GestureDetector(
                onTap: () => _selectTab(2),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: AppThemePalette.heroGradient(isDark),
                    shape: BoxShape.circle,
                    boxShadow: AppThemePalette.softShadow(isDark),
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 4,
                    ),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectTab(int index) {
    AppFeedbackService.instance.tap();
    setState(() {
      _currentIndex = index;
    });
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppBootLoader extends StatelessWidget {
  const _AppBootLoader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: AppBackdrop(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AppPanel(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        gradient: AppThemePalette.heroGradient(
                          theme.brightness == Brightness.dark,
                        ),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: const Icon(
                        Icons.translate_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'DocTranslate',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Initialisation de votre espace documentaire securise...',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(),
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
