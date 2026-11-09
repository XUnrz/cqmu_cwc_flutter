import 'package:flutter/material.dart';

import '../../data/catalog_index.dart';
import '../../services/app_state.dart';
import '../../services/cwc_client.dart';
import '../../utils/format.dart';
import '../../widgets/filter_pill.dart';
import '../data_calls_page.dart';
import '../payment_code_page.dart';

/// 首页：账户余额 + 常用接口快捷入口 + 模块浏览。
class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.app, required this.onOpenCatalog});

  final AppState app;
  final void Function([String? module]) onOpenCatalog;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _account;

  static const List<(IconData, String, String)> _quickActions =
      <(IconData, String, String)>[
    (Icons.credit_card, '校园卡信息', '/card/info/get'),
    (Icons.wallet_outlined, '电子卡信息', '/eaccount/info'),
    (Icons.receipt_long_outlined, '交易流水', '/card/transaction/page'),
    (Icons.qr_code_2, '付款码', '/eaccount/transKey'),
    (Icons.apps, '我的菜单', '/baseconfig/v2/menus'),
    (Icons.pie_chart_outline, '消费统计', '/market/transaction/sum/page'),
    (Icons.notifications_outlined, '通知', '/notice/tops'),
    (Icons.savings_outlined, '充值记录', '/fee/balance/queryRechargePage'),
  ];

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    final String empId = widget.app.current.userId;
    if (empId.isEmpty) {
      setState(() => _error = '登录信息缺少 userId');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final Map<String, dynamic> r = await widget.app.client.request(
        'POST',
        '/employee/account',
        <String, String>{'empId': empId},
        token: widget.app.current.accessToken,
      );
      if (!mounted) return;
      if (!isSuccess(r)) {
        setState(() => _error = messageOf(r).isEmpty ? '获取账户信息失败' : messageOf(r));
      } else {
        final Object? data = dataOf(r);
        setState(() => _account = data is Map ? data.cast<String, dynamic>() : null);
      }
    } on CwcException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openCalls(String title, String path) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DataCallsPage(
          app: widget.app,
          title: title,
          calls: <ApiCall>[ApiCall(path)],
        ),
      ),
    );
  }

  void _openPaymentCode() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PaymentCodePage(app: widget.app),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return RefreshIndicator(
      onRefresh: _loadAccount,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          _ProfileCard(app: widget.app),
          const SizedBox(height: 12),
          _BalanceCard(
            account: _account,
            loading: _loading,
            error: _error,
            onRetry: _loadAccount,
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Text('常用功能', style: theme.textTheme.titleMedium),
              const Spacer(),
              TextButton(
                onPressed: () => widget.onOpenCatalog(),
                child: const Text('全部接口'),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final int columns =
                  (constraints.maxWidth / 96).floor().clamp(4, 8);
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.1,
                children: <Widget>[
                  for (final (IconData icon, String label, String path)
                      in _quickActions)
                    _QuickTile(
                      icon: icon,
                      label: label,
                      onTap: () => path == '/eaccount/transKey'
                          ? _openPaymentCode()
                          : _openCalls(label, path),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text('按模块浏览', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '共 ${moduleCounts.values.fold<int>(0, (int a, int b) => a + b)} 个接口 · '
            '${moduleCounts.length} 个模块',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String module in catalogModules)
                FilterPill(
                  label: '$module ${moduleCounts[module]}',
                  selected: false,
                  onTap: () => widget.onOpenCatalog(module),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String name = app.current.userName.isEmpty ? '已登录用户' : app.current.userName;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 26,
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            child: Text(
              name.characters.first,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  <String?>[
                    app.current.userNo.isEmpty ? null : app.current.userNo,
                    app.current.departmentName.isEmpty
                        ? null
                        : app.current.departmentName,
                  ].whereType<String>().join(' · '),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
          Icon(Icons.verified_user_outlined, color: scheme.onPrimaryContainer),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.account,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final Map<String, dynamic>? account;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Map<String, dynamic>? data = account;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('账户余额', style: theme.textTheme.titleSmall),
              const Spacer(),
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (error != null)
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('重试'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (error != null)
            Text(error!, style: TextStyle(color: scheme.error, fontSize: 13))
          else if (data != null)
            Row(
              children: <Widget>[
                Expanded(
                  child: _Amount(
                    label: '校园卡',
                    value: moneyText(data['cardValue']),
                    color: scheme.onSurface,
                  ),
                ),
                Expanded(
                  child: _Amount(
                    label: '电子卡',
                    value: moneyText(data['eaccountValue']),
                    color: scheme.onSurface,
                  ),
                ),
              ],
            )
          else
            Text(
              '下拉刷新余额',
              style: TextStyle(color: scheme.outline, fontSize: 13),
            ),
          if (data != null && data['cardStatus'] != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              '卡状态：${data['cardStatus']}',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(
          '¥ $value',
          style: theme.textTheme.headlineSmall
              ?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: scheme.primary),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
