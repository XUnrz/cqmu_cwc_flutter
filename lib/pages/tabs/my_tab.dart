import 'package:flutter/material.dart';

import '../../data/api_catalog.dart';
import '../../data/catalog_index.dart';
import '../../services/app_state.dart';
import '../../services/cwc_client.dart';
import '../../utils/format.dart';
import '../../widgets/output_log.dart';

/// 我的：会话信息、接口地址、退出登录。
class MyTab extends StatelessWidget {
  const MyTab({super.key, required this.app});

  final AppState app;

  Future<void> _logout(BuildContext context) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        icon: const Icon(Icons.logout),
        title: const Text('退出登录'),
        content: const Text('将清除本地会话，需要重新输入账号密码。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (ok == true) await app.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String token = app.current.accessToken;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        Card(
          elevation: 0,
          color: scheme.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('当前会话', style: theme.textTheme.titleMedium),
                const Divider(height: 20),
                _InfoRow(label: '姓名', value: app.current.userName),
                _InfoRow(label: '学号 / 工号', value: app.current.userNo),
                _InfoRow(label: 'userId', value: app.current.userId),
                _InfoRow(label: '部门', value: app.current.departmentName),
                _InfoRow(label: 'OpenID', value: app.current.openId),
                _InfoRow(label: 'accessToken', value: maskToken(token)),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: () => copyText(context, token),
                      icon: const Icon(Icons.copy_all_outlined, size: 18),
                      label: const Text('复制 token'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: scheme.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('接口信息', style: theme.textTheme.titleMedium),
                const Divider(height: 20),
                _InfoRow(label: '接口地址', value: cwcBaseUrl),
                _InfoRow(label: '接口总数', value: '${apiCatalog.length} 个'),
                _InfoRow(label: '模块数', value: '${catalogModules.length} 个'),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => copyText(context, cwcBaseUrl),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('复制接口地址'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: scheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('说明', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                _Note(text: '密码在客户端用 AES-128-ECB 加密后提交，本地不保存密码。'),
                _Note(text: '所有接口按 API抓取.md 收录，可在「接口」页搜索、填参并调用。'),
                _Note(text: 'POST 多为写操作，目录页调用前会二次确认。'),
                _Note(text: 'Web 端可能被浏览器跨域（CORS）拦截，建议使用原生端。'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.tonalIcon(
          onPressed: () => _logout(context),
          icon: const Icon(Icons.logout),
          label: const Text('退出登录'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '—' : value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('· '),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
