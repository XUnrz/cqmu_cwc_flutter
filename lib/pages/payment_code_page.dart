import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_state.dart';
import '../services/cwc_client.dart';
import '../utils/format.dart';
import '../widgets/qr_view.dart';

/// 付款码（被扫）：本人出示二维码，由收费设备扫描完成扣款。
class PaymentCodePage extends StatefulWidget {
  const PaymentCodePage({super.key, required this.app});

  final AppState app;

  @override
  State<PaymentCodePage> createState() => _PaymentCodePageState();
}

class _PaymentCodePageState extends State<PaymentCodePage> {
  static const int _period = 60;

  int _countdown = _period;
  String? _code;
  String? _error;
  bool _loading = false;
  bool _polling = false;
  bool _finished = false;
  bool _dialogShowing = false;

  /// 每次重新取码自增，用于丢弃过期的轮询结果。
  int _generation = 0;
  Timer? _timer;

  String get _empId {
    final String emplId = widget.app.current.emplId;
    return emplId.isNotEmpty ? emplId : widget.app.current.userId;
  }
  String get _token => widget.app.current.accessToken;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (_empId.isEmpty) {
      setState(() => _error = '登录信息缺少 userId，请重新登录');
      return;
    }
    setState(() => _loading = true);
    try {
      final bool allowed = await _passLimitCheck();
      if (!mounted) return;
      if (!allowed) {
        Navigator.of(context).maybePop();
        return;
      }
      await _loadCode();
    } on CwcException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<bool> _passLimitCheck() async {
    final Map<String, dynamic> r = await widget.app.client.post(
      '/eaccount/pay/check',
      params: <String, String>{'empId': _empId},
      token: _token,
    );
    if (!isSuccess(r)) throw CwcException(messageOf(r).isEmpty ? '消费校验失败' : messageOf(r));
    final Object? data = dataOf(r);
    final Object? over = data is Map ? data['over'] : null;
    final String overText = '$over';
    if (over != true && over != 1 && overText != 'true' && overText != '1') {
      return true;
    }

    final String? password = await _askPassword();
    if (password == null) return false;
    final Map<String, dynamic> check = await widget.app.client.post(
      '/employee/check',
      params: <String, String>{'empId': _empId, 'pwd': password},
      token: _token,
    );
    if (!isSuccess(check)) {
      throw CwcException(messageOf(check).isEmpty ? '密码校验失败' : messageOf(check));
    }
    return true;
  }

  Future<String?> _askPassword() {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PasswordDialog(),
    );
  }

  Future<void> _loadCode() async {
    if (!mounted) return;
    _generation++;
    final int generation = _generation;
    _timer?.cancel();
    setState(() {
      _loading = true;
      _error = null;
      _finished = false;
    });
    try {
      final Map<String, dynamic> r = await widget.app.client.post(
        '/eaccount/transKey',
        params: <String, String>{'empId': _empId},
        token: _token,
      );
      if (!mounted || generation != _generation) return;
      if (!isSuccess(r)) {
        throw CwcException(messageOf(r).isEmpty ? '获取付款码失败' : messageOf(r));
      }
      final String code = '${dataOf(r) ?? ''}';
      if (code.isEmpty || code == 'null') throw CwcException('未获取到付款码');
      setState(() {
        _code = code;
        _countdown = _period;
        _loading = false;
      });
      _startPolling();
    } on CwcException catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _code = null;
        _error = e.message;
      });
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _tick() async {
    if (_polling || _finished || !mounted || _code == null) return;
    if (_countdown <= 1) {
      await _loadCode();
      return;
    }
    setState(() => _countdown--);

    _polling = true;
    final int generation = _generation;
    final String code = _code!;
    try {
      final Map<String, dynamic> r = await widget.app.client.post(
        '/eaccount/transKey/result',
        params: <String, String>{'empId': _empId, 'qrCode': code},
        token: _token,
      );
      if (!mounted || generation != _generation) return;
      if (!isSuccess(r)) return;
      final Object? data = dataOf(r);
      final String state = data is Map ? '${data['isPay'] ?? ''}'.trim() : '';
      if (state == '已使用') {
        _finished = true;
        _timer?.cancel();
        await _showPaid(
          data is Map ? data.cast<String, dynamic>() : <String, dynamic>{},
        );
        if (!mounted || generation != _generation) return;
        await _loadCode();
      } else if (state == '二维码已过期') {
        await _loadCode();
      }
    } on CwcException {
      // 网络波动不打断轮询，下一秒继续查询。
    } finally {
      _polling = false;
    }
  }

  Future<void> _showPaid(Map<String, dynamic> data) async {
    if (!mounted || _dialogShowing) return;
    _dialogShowing = true;
    final String wallet = '${data['walletId'] ?? ''}';
    final String walletLabel = switch (wallet) {
      '0' => '电子卡余额',
      '4' => '教工餐余额',
      _ => '账户余额',
    };
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => AlertDialog(
          icon: Icon(Icons.check_circle, color: Colors.green.shade600, size: 44),
          title: const Text('支付成功'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _PaidRow(label: '支付金额', value: '¥${moneyText(data['amount'])}'),
              _PaidRow(label: '商户', value: '${data['marketName'] ?? '—'}'),
              _PaidRow(label: '支付时间', value: '${data['payDate'] ?? '—'}'),
              _PaidRow(
                label: walletLabel,
                value: '¥${moneyText(data['accountValue'])}',
              ),
            ],
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('完成'),
            ),
          ],
        ),
      );
    } finally {
      _dialogShowing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('付款码'),
        actions: <Widget>[
          IconButton(
            key: const Key('payment-refresh'),
            tooltip: '刷新二维码',
            onPressed: _code == null || _loading ? null : _loadCode,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: <Widget>[
            _buildCard(theme, scheme),
            const SizedBox(height: 16),
            Text(
              '二维码约 60 秒自动刷新，请将二维码对准扫码设备。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
            ),
            const SizedBox(height: 6),
            Text(
              '仅限本人使用，请勿截图或转发。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(ThemeData theme, ColorScheme scheme) {
    final String? code = _code;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.account_balance_wallet_outlined, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.app.current.userName.isEmpty
                      ? '校园一卡通'
                      : widget.app.current.userName,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (_loading && code != null)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (code == null && _loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 72),
              child: CircularProgressIndicator(),
            )
          else if (code == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: <Widget>[
                  Icon(Icons.qr_code_2, size: 48, color: scheme.outline),
                  const SizedBox(height: 12),
                  Text(
                    _error ?? '暂时无法获取付款码',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _bootstrap,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
                  ),
                ],
              ),
            )
          else
            GestureDetector(
              key: const Key('payment-qr-tap'),
              onTap: _loading ? null : _loadCode,
              child: QrView(key: const Key('payment-qr'), data: code),
            ),
          if (code != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              '$_countdown 秒后自动刷新',
              key: const Key('payment-countdown'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '请将二维码对准扫码设备',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.lock_outline),
      title: const Text('消费超限'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text('请输入登录密码后继续。'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('payment-password'),
            controller: _controller,
            autofocus: true,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: '登录密码',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('payment-password-ok'),
          onPressed: _controller.text.trim().isEmpty ? null : _submit,
          child: const Text('确定'),
        ),
      ],
    );
  }
}

class _PaidRow extends StatelessWidget {
  const _PaidRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
