import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 本地偏好：主题模式等。
class SettingsStore {
  static const String _kThemeMode = 'cwc_theme_mode';

  static Future<ThemeMode> loadThemeMode() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    switch (p.getString(_kThemeMode)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    final String value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await p.setString(_kThemeMode, value);
  }
}
