import 'package:flutter/material.dart';

import '../services/app_state.dart';
import '../services/cwc_client.dart';
import '../services/session_store.dart';

/// 账号密码登录：学号 + AES 加密密码 + 微信 OpenID（可选短信验证码）。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.app});

  final AppState app;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _userNo = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _openId = TextEditingController();
  final TextEditingController _loginCode = TextEditingController();

  bool _obscure = true;
  bool _submitting = false;
  bool _sending = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _loadHints();
  }

  Future<void> _loadHints() async {
    final (String userNo, String openId) = await SessionStore.loadLoginHints();
    if (!mounted) return;
    setState(() {
      if (userNo.isNotEmpty) _userNo.text = userNo;
      if (openId.isNotEmpty) _openId.text = openId;
    });
  }

  @override
  void dispose() {
    _userNo.dispose();
    _password.dispose();
    _openId.dispose();
    _loginCode.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final String userNo = _userNo.text.trim();
    if (userNo.isEmpty) {
      setState(() => _error = '请先输入学号 / 工号');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
      _info = null;
    });
    try {
      final String target = await widget.app.client.sendLoginCode(userNo);
      if (!mounted) return;
      setState(() => _info = '验证码已发送${target.isEmpty ? '' : '至 $target'}');
    } on CwcException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _login() async {
    final String userNo = _userNo.text.trim();
    final String password = _password.text;
    final String openId = _openId.text.trim();
    if (userNo.isEmpty || password.isEmpty || openId.isEmpty) {
      setState(() => _error = '请填写学号、密码和微信 OpenID');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
      _info = null;
    });
    try {
      await widget.app.signIn(
        userNo: userNo,
        password: password,
        openId: openId,
        loginCode: _loginCode.text.trim(),
      );
    } on CwcException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '登录失败：$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              children: <Widget>[
                Icon(Icons.credit_card, size: 56, color: scheme.primary),
                const SizedBox(height: 12),
                Text(
                  '重医一卡通',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '校园卡 · 电子卡 · 缴费 · 全部接口',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 28),
                TextField(
                  key: const Key('login-userno'),
                  controller: _userNo,
                  decoration: const InputDecoration(
                    labelText: '学号 / 工号',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('login-password'),
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: '密码',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _obscure ? '显示密码' : '隐藏密码',
                      icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('login-openid'),
                  controller: _openId,
                  decoration: const InputDecoration(
                    labelText: '微信 OpenID',
                    prefixIcon: Icon(Icons.chat_bubble_outline),
                    helperText: '微信授权或已绑定账号的 openId，未绑定用户需填写',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _loginCode,
                        decoration: const InputDecoration(
                          labelText: '短信验证码（可选）',
                          prefixIcon: Icon(Icons.sms_outlined),
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submitting ? null : _login(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: _sending ? null : _sendCode,
                        child: Text(_sending ? '发送中…' : '发送验证码'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const Key('login-submit'),
                  onPressed: _submitting ? null : _login,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(_submitting ? '登录中…' : '登录'),
                ),
                if (_info != null) ...<Widget>[
                  const SizedBox(height: 16),
                  _Message(text: _info!, isError: false),
                ],
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 16),
                  _Message(text: _error!, isError: true),
                ],
                const SizedBox(height: 28),
                Text(
                  '接口地址：$cwcBaseUrl',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
                ),
                const SizedBox(height: 4),
                Text(
                  'Web 端受浏览器跨域限制，建议在 Android / iOS / macOS / Windows / Linux 运行。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? scheme.errorContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isError ? scheme.onErrorContainer : scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
