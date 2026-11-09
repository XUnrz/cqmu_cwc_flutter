import 'package:flutter/material.dart';

import '../../services/app_state.dart';
import '../../services/cwc_client.dart';
import '../../utils/format.dart';
import '../payment_code_page.dart';

/// 首页：电子卡余额与付款码入口。
class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.app});

  final AppState app;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _ecard;

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
        '/eaccount/info',
        <String, String>{'empId': empId},
        token: widget.app.current.accessToken,
      );
      if (!mounted) return;
      if (!isSuccess(r)) {
        setState(
          () => _error = messageOf(r).isEmpty ? '获取电子卡信息失败' : messageOf(r),
        );
      } else {
        final Object? data = dataOf(r);
        setState(
          () => _ecard = data is Map ? data.cast<String, dynamic>() : null,
        );
      }
    } on CwcException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openPaymentCode() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PaymentCodePage(app: widget.app)),
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
            ecard: _ecard,
            loading: _loading,
            error: _error,
            onRetry: _loadAccount,
          ),
          const SizedBox(height: 20),
          Text('常用功能', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: _openPaymentCode,
              icon: const Icon(Icons.qr_code_2),
              label: const Text('打开付款码'),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '用水请前往底部“水控”选项卡，扫码开阀后用完后记得关阀结算。',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
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
    final String name = app.current.userName.isEmpty
        ? '已登录用户'
        : app.current.userName;
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
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
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
    required this.ecard,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final Map<String, dynamic>? ecard;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Map<String, dynamic>? data = ecard;
    final Object? rawStatus = data?['eaccountStatus'];
    final String status = rawStatus is String ? rawStatus : '';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.wallet_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Text('电子卡余额', style: theme.textTheme.titleSmall),
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
          const SizedBox(height: 12),
          if (error != null)
            Text(error!, style: TextStyle(color: scheme.error, fontSize: 13))
          else if (data != null)
            Text(
              '¥ ${moneyText(data['eaccountValue'])}',
              style: theme.textTheme.headlineLarge?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            Text(
              '下拉刷新余额',
              style: TextStyle(color: scheme.outline, fontSize: 13),
            ),
          if (data != null) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                if (status.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '状态 $status',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                Text(
                  '账户号 ${data['eaccountId'] ?? '—'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
