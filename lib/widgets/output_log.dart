import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/format.dart';

/// 单条输出记录（接口路径 + 响应体）。
class OutputEntry {
  OutputEntry({required this.header, required this.body, this.isError = false});

  final String header;
  final String body;
  final bool isError;
}

class OutputLogController extends ChangeNotifier {
  final List<OutputEntry> _entries = <OutputEntry>[];
  static const int maxEntries = 50;

  List<OutputEntry> get entries => List<OutputEntry>.unmodifiable(_entries);
  bool get isEmpty => _entries.isEmpty;

  void append(OutputEntry entry) {
    _entries.add(entry);
    while (_entries.length > maxEntries) {
      _entries.removeAt(0);
    }
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}

/// 响应输出面板：最近若干条请求，支持清空与复制。
class OutputLog extends StatefulWidget {
  const OutputLog({super.key, required this.controller});

  final OutputLogController controller;

  @override
  State<OutputLog> createState() => _OutputLogState();
}

class _OutputLogState extends State<OutputLog> {
  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
              color: scheme.surfaceContainerHigh,
              child: Row(
                children: <Widget>[
                  Text(
                    '响应输出',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '清空',
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: widget.controller.clear,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (BuildContext context, _) {
                  if (widget.controller.isEmpty) {
                    return Center(
                      child: Text(
                        '（暂无输出）',
                        style: TextStyle(color: scheme.outline),
                      ),
                    );
                  }
                  final List<OutputEntry> entries = widget.controller.entries;
                  return ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: entries.length,
                    itemBuilder: (BuildContext context, int i) {
                      final OutputEntry entry = entries[i];
                      return _OutputCard(entry: entry);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutputCard extends StatelessWidget {
  const _OutputCard({required this.entry});

  final OutputEntry entry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color accent = entry.isError ? scheme.error : scheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(left: BorderSide(color: accent, width: 3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            color: scheme.surfaceContainerHigh,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    entry.header,
                    style: TextStyle(
                      fontSize: 12,
                      color: entry.isError ? scheme.error : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: '复制',
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () => copyText(context, entry.body),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: SelectableText(
              entry.body,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> copyText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
}

/// 美化 JSON 的只读卡片。
class JsonBlock extends StatelessWidget {
  const JsonBlock({
    super.key,
    required this.title,
    required this.data,
    this.isError = false,
  });

  final String title;
  final Object? data;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String text = data is String ? '$data' : prettyJson(data);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: isError
                ? scheme.errorContainer.withValues(alpha: 0.4)
                : scheme.surfaceContainerHigh,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: isError ? scheme.error : scheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: SelectableText(
              text,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
