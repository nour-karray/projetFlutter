import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Retours tactiles et sonores (mobile / desktop léger ; web limité).
class AppFeedbackService {
  AppFeedbackService._();

  static final AppFeedbackService instance = AppFeedbackService._();

  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  void configure({
    required bool soundEnabled,
    required bool vibrationEnabled,
  }) {
    _soundEnabled = soundEnabled;
    _vibrationEnabled = vibrationEnabled;
  }

  Future<void> tap() async {
    await HapticFeedback.selectionClick();
  }

  Future<void> success() async {
    await HapticFeedback.mediumImpact();
    if (_soundEnabled && !kIsWeb) {
      SystemSound.play(SystemSoundType.click);
    }
    if (_vibrationEnabled && !kIsWeb) {
      final has = await Vibration.hasVibrator();
      if (has == true) {
        await Vibration.vibrate(duration: 42);
      }
    }
  }

  Future<void> error() async {
    await HapticFeedback.heavyImpact();
    if (_soundEnabled && !kIsWeb) {
      SystemSound.play(SystemSoundType.alert);
    }
    if (_vibrationEnabled && !kIsWeb) {
      final has = await Vibration.hasVibrator();
      if (has == true) {
        await Vibration.vibrate(duration: 90);
      }
    }
  }
}
