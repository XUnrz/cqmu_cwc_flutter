import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/accent_theme.dart';

/// 本地偏好：主题模式与主题色。
class SettingsStore {
  static const String _kThemeMode = 'cwc_theme_mode';
  static const String _kAccent = 'cwc_theme_accent';

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

  static Future<AccentTheme> loadAccent() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    return AccentTheme.fromName(p.getString(_kAccent));
  }

  static Future<void> saveAccent(AccentTheme accent) async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setString(_kAccent, accent.name);
  }
}
