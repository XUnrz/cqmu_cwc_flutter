import 'package:flutter/material.dart';

import '../models/api_endpoint.dart';
import '../services/app_state.dart';
import '../services/cwc_client.dart';
import '../utils/format.dart';
import '../widgets/output_log.dart';

/// 单个接口的调用页：参数表单 + 结果 JSON。
class EndpointPage extends StatefulWidget {
  const EndpointPage({super.key, required this.app, required this.endpoint});

  final AppState app;
  final ApiEndpoint endpoint;

  @override
  State<EndpointPage> createState() => _EndpointPageState();
}

class _EndpointPageState extends State<EndpointPage> {
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};

  bool _loading = false;
  bool _showSecrets = false;
  String? _error;
  Map<String, dynamic>? _response;

  ApiEndpoint get endpoint => widget.endpoint;

  @override
  void initState() {
    super.initState();
    _resetTemplate();
  }

  void _resetTemplate() {
    final Map<String, String> values = endpointParams(
      endpoint,
      widget.app.session,
    );
    for (final MapEntry<String, String> e in dateRangeDefaults(
      endpoint.path,
    ).entries) {
      if (values.containsKey(e.key) && values[e.key]!.isEmpty) {
        values[e.key] = e.value;
      }
    }
    for (final MapEntry<String, String> e in values.entries) {
      _controllers.putIfAbsent(e.key, () => TextEditingController()).text =
          e.value;
    }
  }

  @override
  void dispose() {
    for (final TextEditingController c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _isSecret(String key) {
    final String k = key.toLowerCase();
    return k.contains('password') || k == 'pwd' || k == 'repwd';
  }

  Future<void> _call() async {
    if (endpoint.isUpload) return;
    if (endpoint.isWrite) {
      final bool? ok = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded),
          title: const Text('确认提交'),
          content: Text(
            '${endpoint.method} ${endpoint.path}\n\n'
            '该请求会真实提交到服务器，请确认参数无误。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('提交'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      if (!mounted) return;
    }

    FocusScope.of(context).unfocus();
    final Map<String, String> params = <String, String>{
      for (final MapEntry<String, TextEditingController> e
          in _controllers.entries)
        if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
    };
    if (endpoint.encryptPassword && (params['password'] ?? '').isNotEmpty) {
      params['password'] = encryptPassword(params['password']!);
    }

    setState(() {
      _loading = true;
      _error = null;
      _response = null;
    });
    try {
      final Map<String, dynamic> r = await widget.app.client.request(
        endpoint.method,
        endpoint.path,
        params,
        token: endpoint.requireToken ? widget.app.current.accessToken : null,
      );
      if (mounted) setState(() => _response = r);
    } on CwcException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '请求失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool ok = _response != null && isSuccess(_response!);
    return Scaffold(
      appBar: AppBar(
        title: const Text('接口调用'),
        actions: <Widget>[
          IconButton(
            tooltip: '复制路径',
            icon: const Icon(Icons.copy),
            onPressed: () => copyText(context, endpoint.path),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _Badge(
                      text: endpoint.method,
                      color: endpoint.isGet ? scheme.primary : scheme.tertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        endpoint.path,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(endpoint.description, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: <Widget>[
                    _Badge(text: endpoint.module, color: scheme.secondary),
                    _Badge(
                      text: endpoint.requireToken ? '需要 accessToken' : '公开接口',
                      color: endpoint.requireToken
                          ? scheme.primary
                          : scheme.outline,
                    ),
                    _Badge(
                      text: '${endpoint.params.length} 个参数',
                      color: scheme.outline,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (endpoint.isUpload) ...<Widget>[
            const SizedBox(height: 12),
            _Banner(
              text: '该接口为 multipart 文件上传，客户端暂不提供调用。',
              color: scheme.tertiaryContainer,
              onColor: scheme.onTertiaryContainer,
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Text('参数', style: theme.textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: _loading ? null : () => setState(_resetTemplate),
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('按会话填充'),
              ),
            ],
          ),
          if (endpoint.params.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '该接口无固定参数（可能由后端根据 token / 路径识别）。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.outline,
                ),
              ),
            )
          else
            for (final String key in endpoint.params)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: _controllers[key],
                  enabled: !_loading,
                  obscureText: _isSecret(key) && !_showSecrets,
                  decoration: InputDecoration(
                    labelText: key,
                    helperText: _hint(key),
                    border: const OutlineInputBorder(),
                    suffixIcon: _isSecret(key)
                        ? IconButton(
                            tooltip: _showSecrets ? '隐藏' : '显示',
                            icon: Icon(
                              _showSecrets
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _showSecrets = !_showSecrets),
                          )
                        : null,
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _loading || endpoint.isUpload ? null : _call,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_loading ? '请求中…' : '调用接口'),
            ),
          ),
          if (endpoint.isWrite && !endpoint.isUpload)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'POST 请求会先弹出确认框；多数只读查询也使用 POST。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.outline,
                ),
              ),
            ),
          const SizedBox(height: 20),
          if (_error != null)
            _Banner(
              text: _error!,
              color: scheme.errorContainer,
              onColor: scheme.onErrorContainer,
            ),
          if (_response != null) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ok ? scheme.primaryContainer : scheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    ok ? Icons.check_circle_outline : Icons.error_outline,
                    color: ok
                        ? scheme.onPrimaryContainer
                        : scheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_response!['status']} · ${messageOf(_response!).isEmpty ? '无 message' : messageOf(_response!)}',
                      style: TextStyle(
                        color: ok
                            ? scheme.onPrimaryContainer
                            : scheme.onErrorContainer,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '复制响应',
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () => copyText(context, prettyJson(_response)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            JsonBlock(
              title: '${endpoint.method} ${endpoint.path} · 完整响应',
              data: _response,
              isError: !ok,
            ),
          ],
        ],
      ),
    );
  }
}

String _hint(String key) {
  const Map<String, String> hints = <String, String>{
    'page': '页码，从 1 开始',
    'pagesize': '每页条数',
    'size': '每页条数',
    'empid': '人员 ID（登录返回的 userId）',
    'employeeid': '人员 ID（登录返回的 userId）',
    'userid': '用户 ID（登录返回的 userId）',
    'userno': '学号 / 工号',
    'employeeno': '学号 / 工号',
    'empno': '学号 / 工号',
    'cardno': '学号 / 工号',
    'operator': '操作人（学号 / 工号）',
    'openid': '微信 openId',
    'starttime': '开始时间',
    'endtime': '结束时间',
    'status': '状态码',
    'token': '图形验证码随机串（与 validateCode 成对）',
    'validatecode': '图形验证码内容',
    'logincode': '短信验证码',
    'password': '明文密码，提交前自动 AES 加密',
    'pwd': '密码',
  };
  return hints[key.toLowerCase()] ?? '';
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.text,
    required this.color,
    required this.onColor,
  });

  final String text;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(color: onColor)),
    );
  }
}
