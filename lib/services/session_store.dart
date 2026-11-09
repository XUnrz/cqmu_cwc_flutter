import 'package:shared_preferences/shared_preferences.dart';

import '../models/session.dart';

/// 会话与登录表单缓存（全部平台由 shared_preferences 实现）。
///
/// 保存 accessToken、账号资料和上次登录的学号 / 密码 / openId，用于自动填充。
class SessionStore {
  static const String _kSession = 'cwc_session';
  static const String _kUserNo = 'cwc_last_userno';
  static const String _kPassword = 'cwc_last_password';
  static const String _kOpenId = 'cwc_last_openid';

  static Future<CwcSession?> load() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    return CwcSession.tryDecode(p.getString(_kSession));
  }

  static Future<void> save(CwcSession session) async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setString(_kSession, session.encode());
  }

  static Future<void> clear() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.remove(_kSession);
  }

  static Future<(String, String, String)> loadLoginHints() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    return (
      p.getString(_kUserNo) ?? '',
      p.getString(_kPassword) ?? '',
      p.getString(_kOpenId) ?? '',
    );
  }

  static Future<void> saveLoginHints(
    String userNo,
    String password,
    String openId,
  ) async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setString(_kUserNo, userNo);
    await p.setString(_kPassword, password);
    await p.setString(_kOpenId, openId);
  }
}
