import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'dart:async';
import 'core/app_localizations.dart';
import 'core/auth_service.dart';
import 'core/ocr_service.dart';
import 'core/scan_history_store.dart';
import 'core/scan_result_store.dart';
import 'features/history/history_screen.dart';
import 'features/home/home_screen.dart';
import 'features/result/result_screen.dart';
import 'features/scan/scan_screen.dart';
import 'features/settings/settings_screen.dart';

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
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  Timer? _reminderTimer;
  final ScanHistoryStore _scanHistoryStore = ScanHistoryStore();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _initializeCloudServices();
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    _authService.dispose();
    super.dispose();
  }

  Future<void> _initializeCloudServices() async {
    await _authService.initialize();
    await _scanHistoryStore.load();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _localeCode = prefs.getString(_localeKey) ?? 'fr';
      _themeMode =
          (prefs.getBool(_themeKey) ?? false) ? ThemeMode.dark : ThemeMode.light;
      _notificationsEnabled = prefs.getBool(_notificationsKey) ?? true;
      _soundEnabled = prefs.getBool(_soundKey) ?? true;
      _vibrationEnabled = prefs.getBool(_vibrationKey) ?? true;
      _geminiApiKey = prefs.getString(_geminiApiKeyKey) ?? '';
    });
    _restartReminderTimer();
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

  void _restartReminderTimer() {
    _reminderTimer?.cancel();
    if (!_notificationsEnabled) return;
    _reminderTimer = Timer.periodic(const Duration(minutes: 3), (_) async {
      _messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            _localeCode == 'ar'
                ? 'تذكير: استعمل التطبيق بانتظام.'
                : _localeCode == 'en'
                    ? 'Reminder: use the app regularly.'
                    : 'Rappel: utilise l application regulierement.',
          ),
        ),
      );
      if (!kIsWeb) {
        try {
          if (_soundEnabled) {
            await SystemSound.play(SystemSoundType.click);
          }
          if (_vibrationEnabled) {
            final hasVibrator = await Vibration.hasVibrator();
            if (hasVibrator) {
              await Vibration.vibrate(duration: 110, amplitude: 160);
            } else {
              await HapticFeedback.lightImpact();
            }
          }
        } catch (_) {}
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SmartScan ML Kit',
      locale: Locale(_localeCode),
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      scaffoldMessengerKey: _messengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: _themeMode,
      home: MainNavigation(
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
          setState(() {
            _localeCode = value;
          });
          _saveLocale(value);
        },
        onNotificationsChanged: (enabled) {
          setState(() {
            _notificationsEnabled = enabled;
          });
          _saveBool(_notificationsKey, enabled);
          _restartReminderTimer();
        },
        onSoundChanged: (enabled) {
          setState(() {
            _soundEnabled = enabled;
          });
          _saveBool(_soundKey, enabled);
        },
        onVibrationChanged: (enabled) {
          setState(() {
            _vibrationEnabled = enabled;
          });
          _saveBool(_vibrationKey, enabled);
        },
        onGeminiApiKeyChanged: (value) {
          setState(() {
            _geminiApiKey = value.trim();
          });
          _saveGeminiApiKey(value);
        },
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({
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

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        localeCode: widget.localeCode,
        scanHistoryStore: widget.scanHistoryStore,
      ),
      ScanScreen(
        localeCode: widget.localeCode,
        scanResultStore: _scanResultStore,
        scanHistoryStore: widget.scanHistoryStore,
        ocrService: _ocrService,
        soundEnabled: widget.soundEnabled,
        vibrationEnabled: widget.vibrationEnabled,
        onResultReady: () {
          setState(() {
            _currentIndex = 2;
          });
        },
      ),
      ResultScreen(
        localeCode: widget.localeCode,
        scanResultStore: _scanResultStore,
        geminiApiKey: widget.geminiApiKey,
      ),
      HistoryScreen(
        localeCode: widget.localeCode,
        scanHistoryStore: widget.scanHistoryStore,
        onOpenResultRequested: (entry) {
          _scanResultStore.loadFromHistory(
            text: entry.text,
            languageCodes: entry.detectedLanguages,
            report: entry.structuredReport,
            bytes: entry.imageBytes,
          );
          setState(() {
            _currentIndex = 2;
          });
        },
      ),
      SettingsScreen(
        localeCode: widget.localeCode,
        darkModeEnabled: widget.isDarkMode,
        notificationsEnabled: widget.notificationsEnabled,
        soundEnabled: widget.soundEnabled,
        vibrationEnabled: widget.vibrationEnabled,
        scanHistoryStore: widget.scanHistoryStore,
        geminiApiKey: widget.geminiApiKey,
        onGeminiApiKeyChanged: widget.onGeminiApiKeyChanged,
        onThemeChanged: widget.onThemeChanged,
        onLocaleChanged: widget.onLocaleChanged,
        onNotificationsChanged: widget.onNotificationsChanged,
        onSoundChanged: widget.onSoundChanged,
        onVibrationChanged: widget.onVibrationChanged,
      ),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home),
            label: AppLocalizations.t(widget.localeCode, 'home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.camera_alt),
            label: AppLocalizations.t(widget.localeCode, 'scan'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights),
            label: AppLocalizations.t(widget.localeCode, 'result'),
          ),
          NavigationDestination(
            icon: AnimatedBuilder(
              animation: widget.scanHistoryStore,
              builder: (_, _) {
                final count = widget.scanHistoryStore.entries.length;
                if (count == 0) return const Icon(Icons.history);
                return Badge(
                  label: Text('$count'),
                  child: const Icon(Icons.history),
                );
              },
            ),
            label: AppLocalizations.t(widget.localeCode, 'history'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings),
            label: AppLocalizations.t(widget.localeCode, 'settings'),
          ),
        ],
      ),
    );
  }
}
