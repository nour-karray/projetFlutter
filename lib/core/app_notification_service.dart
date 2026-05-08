import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notifications locales (rappels / tests). Sans effet notable sur Web ou Windows.
class AppNotificationService {
  AppNotificationService._();

  static final AppNotificationService instance =
      AppNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const int _reminderNotificationId = 91001;
  static const String _channelId = 'smartscan_reminders';

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _ensureAndroidChannel();
    _initialized = true;
  }

  Future<void> _ensureAndroidChannel() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        'Rappels',
        description: 'Notifications de test et rappels SmartScan',
        importance: Importance.defaultImportance,
      ),
    );
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await initialize();

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? true;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final mac = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      final bool? r = await ios?.requestPermissions(
            alert: true,
            sound: true,
            badge: true,
          ) ??
          await mac?.requestPermissions(
            alert: true,
            sound: true,
            badge: true,
          );
      return r ?? true;
    }

    return true;
  }

  NotificationDetails _details({
    required bool soundEnabled,
    required bool vibrationEnabled,
    bool highPriority = false,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Rappels',
        importance: highPriority ? Importance.high : Importance.defaultImportance,
        priority: highPriority ? Priority.high : Priority.defaultPriority,
        playSound: soundEnabled,
        enableVibration: vibrationEnabled,
      ),
      iOS: DarwinNotificationDetails(
        presentSound: soundEnabled,
      ),
    );
  }

  Future<void> syncReminder({
    required bool enabled,
    required String localeCode,
    required bool soundEnabled,
    required bool vibrationEnabled,
    bool requestPermissionIfNeeded = false,
  }) async {
    if (kIsWeb) return;
    await initialize();

    if (defaultTargetPlatform == TargetPlatform.windows) {
      return;
    }

    if (requestPermissionIfNeeded && enabled) {
      await requestPermission();
    }

    await _plugin.cancel(id: _reminderNotificationId);
    if (!enabled) return;

    final english = localeCode == 'en';

    try {
      await _plugin.periodicallyShow(
        id: _reminderNotificationId,
        repeatInterval: RepeatInterval.daily,
        notificationDetails: _details(
          soundEnabled: soundEnabled,
          vibrationEnabled: vibrationEnabled,
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title:
            english ? 'Document reminder' : 'Rappel documentaire',
        body: english
            ? 'Open SmartScan to review pending files.'
            : 'Ouvrez SmartScan pour vos documents en attente.',
      );
    } catch (_) {
      // iOS planification / canaux indisponibles : ignorer silencieusement.
    }
  }

  Future<bool> showTestNotification({
    required String localeCode,
    required bool soundEnabled,
    required bool vibrationEnabled,
  }) async {
    if (kIsWeb) return false;
    await initialize();

    if (defaultTargetPlatform == TargetPlatform.windows) {
      return false;
    }

    try {
      final english = localeCode == 'en';
      await _plugin.show(
        id: 482901,
        title: english ? 'Test notification' : 'Notification de test',
        body: english
            ? 'Alerts are working on this device.'
            : 'Les alertes fonctionnent sur cet appareil.',
        notificationDetails: _details(
          soundEnabled: soundEnabled,
          vibrationEnabled: vibrationEnabled,
          highPriority: true,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
