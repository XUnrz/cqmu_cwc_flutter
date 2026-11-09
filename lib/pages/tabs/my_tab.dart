import 'package:flutter/material.dart';

import '../../services/app_state.dart';
import '../../theme/accent_theme.dart';

/// 我的：账号信息、主题与退出登录。
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
                _InfoRow(label: '部门', value: app.current.departmentName),
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
                Text('外观', style: theme.textTheme.titleMedium),
                const Divider(height: 20),
                SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const <ButtonSegment<ThemeMode>>[
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      label: Text('跟随系统'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      label: Text('浅色'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      label: Text('深色'),
                    ),
                  ],
                  selected: <ThemeMode>{app.themeMode},
                  onSelectionChanged: (Set<ThemeMode> selected) =>
                      app.setThemeMode(selected.first),
                ),
                const SizedBox(height: 16),
                Text(
                  '主题色',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    for (final AccentTheme accent in AccentTheme.values)
                      _AccentDot(
                        accent: accent,
                        selected: app.accent == accent,
                        onTap: () => app.setAccent(accent),
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
          color: scheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('说明', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                _Note(text: '账号、密码仅保存在本机，用于登录自动填充与自动获取验证码。'),
                _Note(text: '开阀会暂扣押金，用完请及时在水控页关阀结算。'),
                _Note(text: '遇到账务异常，请以学校一卡通系统记录为准。'),
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

class _AccentDot extends StatelessWidget {
  const _AccentDot({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final AccentTheme accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: accent.label,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? scheme.onSurface : scheme.outlineVariant,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: accent.seed,
              shape: BoxShape.circle,
            ),
            child: selected
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : null,
          ),
        ),
      ),
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
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
