import 'package:flutter/material.dart';

import '../models/session.dart';
import 'cwc_client.dart';
import 'session_store.dart';
import 'settings_store.dart';

/// 全局登录态：持有 [CwcClient] 与当前 [session]。
class AppState extends ChangeNotifier {
  AppState({CwcClient? client}) : client = client ?? CwcClient();

  final CwcClient client;
  CwcSession? session;
  ThemeMode themeMode = ThemeMode.system;

  bool restoring = true;
  bool busy = false;

  bool get isLoggedIn => session != null && session!.isLoggedIn;

  CwcSession get current => session ?? CwcSession.empty;

  Future<void> restore() async {
    restoring = true;
    notifyListeners();
    session = await SessionStore.load();
    themeMode = await SettingsStore.loadThemeMode();
    restoring = false;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (themeMode == mode) return;
    themeMode = mode;
    notifyListeners();
    await SettingsStore.saveThemeMode(mode);
  }

  Future<void> signIn({
    required String userNo,
    required String password,
    required String openId,
    String loginCode = '',
    String validateCode = '',
  }) async {
    busy = true;
    notifyListeners();
    try {
      final CwcSession s = await client.login(
        userNo: userNo,
        password: password,
        openId: openId,
        loginCode: loginCode,
        validateCode: validateCode,
      );
      session = s;
      await SessionStore.save(s);
      await SessionStore.saveLoginHints(userNo, password, openId);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    session = null;
    await SessionStore.clear();
    notifyListeners();
  }
}
