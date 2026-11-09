import 'package:cqmu_cwc/services/app_state.dart';
import 'package:cqmu_cwc/services/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('主题模式默认跟随系统且可持久化恢复', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final AppState app = AppState();
    await app.restore();
    expect(app.themeMode, ThemeMode.system);

    await app.setThemeMode(ThemeMode.dark);
    expect(await SettingsStore.loadThemeMode(), ThemeMode.dark);

    final AppState restored = AppState();
    await restored.restore();
    expect(restored.themeMode, ThemeMode.dark);

    await restored.setThemeMode(ThemeMode.light);
    expect(await SettingsStore.loadThemeMode(), ThemeMode.light);
  });
}
